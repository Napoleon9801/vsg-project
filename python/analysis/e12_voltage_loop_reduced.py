"""E1.2 — reduced d-axis model of the outer voltage loop under resistive load steps.

Purpose: test the hypothesis that the Stage 5i load-cycle Vrms dip/overshoot is
caused by the outer voltage PI being tuned for a pure-Cf plant (Kp_v = 2*zeta*wv*Cf,
Ki_v = wv^2*Cf) while the 2-3 ohm load conductance (0.34-0.49 S) dominates Cf
(10 uF, ~318 ohm at 50 Hz) by ~100x, and there is no load-current feedforward.

Model (per-phase, d-axis, peak volts; cross-coupling and the 1 mH load inductor
neglected, which the Simulink plant includes):
    inner current loop  : first-order lag, w_i = 2*pi*1000 rad/s (firmware design BW)
    outer voltage PI    : firmware gains Kp_v, Ki_v (continuous equivalent)
    plant               : Cf dv/dt = i_L - v/R(t)
    optional feedforward: i_ref += F * i_o,  i_o = v/R (ideal load-current measurement)

Predictions to compare with the Simulink run (analysis_nominal.json):
    dip after step-up  ~ V*G1/G2, recovery tau ~ (Kp_v+G2)/Ki_v
    rise after removal ~ V*G2/G1, recovery tau ~ (Kp_v+G1)/Ki_v

This is a hypothesis check on a reduced model, NOT a replacement for the
switching Simulink model and NOT a hardware result.

Run:  python D:\\workspace\\engineering\\vsg-project\\python\\analysis\\e12_voltage_loop_reduced.py
"""
import json
import math
from pathlib import Path

import numpy as np

# ---- firmware constants (hardware/esp32/vsg_controller/vsg_controller.ino) ----
CF = 10e-6
KP_V = 0.00887592            # A/V
KI_V = 0.000394384 / 1e-4    # Ki_v_Ts / Ts  -> 3.94384 A/(V*s)
W_I = 2 * math.pi * 1000.0   # inner current-loop design bandwidth (rad/s)
V_SET_PK = 14.0
R1, R2 = 2.94, 2.059         # per-phase load before/after the step (Stage 5i load cycle)
T_UP, T_DOWN, T_END = 0.2, 0.6, 1.0
DT = 1e-6
RMS_WIN = 0.02               # same trailing 20 ms window as the Simulink analysis

OUT = Path(r"D:\workspace\engineering\vsg-project\python\analysis\e12_voltage_loop_reduced_results.json")


def simulate(ff_gain: float, kp_v: float = KP_V, ki_v: float = KI_V):
    n = int(T_END / DT) + 1
    t = np.arange(n) * DT
    R = np.where((t >= T_UP) & (t < T_DOWN), R2, R1)
    # start at steady state for R1 with this controller
    v = V_SET_PK
    i_l = v / R1
    integ = i_l * (1 - ff_gain)          # integrator holds the non-feedforward share
    vd = np.empty(n)
    for k in range(n):
        g = 1.0 / R[k]
        e = V_SET_PK - v
        i_ref = kp_v * e + integ + ff_gain * v * g
        integ += ki_v * e * DT
        i_l += W_I * (i_ref - i_l) * DT
        v += (i_l - v * g) / CF * DT
        vd[k] = v
    return t, vd


LF, RF = 1.2e-3, 0.05
KP_I = 7.5396
KI_I = 0.0314150 / 1e-4      # Ki_i_Ts / Ts


def simulate_pi(ff_mode: str, ff_gain: float = 1.0, f_lpf_hz: float = 500.0):
    """Explicit inner current PI + Lf/Rf plant + load-voltage FF (as firmware).

    ff_mode: 'none' | 'ideal_io' (v/R, needs load-side sensors) |
             'il_est' (first-order LPF of measured i_L minus Cf*dv/dt; no new hardware).
    A measured-i_L feedforward closes an extra loop through the inner current
    controller, so it must be checked with the real PI, not a first-order lag.
    """
    n = int(T_END / DT) + 1
    t = np.arange(n) * DT
    R = np.where((t >= T_UP) & (t < T_DOWN), R2, R1)
    v = V_SET_PK
    i_l = v / R1
    io_hat = i_l
    v_prev = v
    integ_v = i_l * (1 - ff_gain) if ff_mode != "none" else i_l
    integ_i = RF * i_l
    a = 2 * math.pi * f_lpf_hz * DT
    vd = np.empty(n)
    for k in range(n):
        g = 1.0 / R[k]
        dvdt = (v - v_prev) / DT
        v_prev = v
        if ff_mode == "ideal_io":
            ff = ff_gain * v * g
        elif ff_mode == "il_est":
            io_hat += a * ((i_l - CF * dvdt) - io_hat)
            ff = ff_gain * io_hat
        else:
            ff = 0.0
        e_v = V_SET_PK - v
        i_ref = KP_V * e_v + integ_v + ff
        integ_v += KI_V * e_v * DT
        e_i = i_ref - i_l
        u = KP_I * e_i + integ_i + v          # load-voltage FF as in firmware
        integ_i += KI_I * e_i * DT
        i_l += (u - v - RF * i_l) / LF * DT
        v += (i_l - v * g) / CF * DT
        vd[k] = v
        if not math.isfinite(v) or abs(v) > 1e3:
            vd[k:] = np.nan
            break
    return t, vd


def trailing_rms_of_envelope(t, vd_pk):
    # d-axis peak -> phase RMS; trailing 20 ms mean of the RMS envelope
    # (the Simulink metric integrates v^2 over 20 ms; for a slowly varying
    # sinusoid amplitude this is sqrt(mean(Vpk^2)/2)).
    w = int(RMS_WIN / DT)
    sq = (vd_pk ** 2) / 2.0
    c = np.concatenate(([0.0], np.cumsum(sq)))
    out = np.full_like(vd_pk, np.nan)
    out[w:] = np.sqrt((c[w + 1:] - c[1:-w]) / w)
    return out


def event_metrics(t, vrms, vinst_rms, t_ev, kind):
    m = (t >= t_ev) & (t < t_ev + 0.3)
    target = vrms[(t > t_ev - 0.05) & (t < t_ev)].mean()
    seg, segi, ts = vrms[m], vinst_rms[m], t[m]
    ext = seg.min() if kind == "min" else seg.max()
    ext_i = segi.min() if kind == "min" else segi.max()
    # recovery time constant from the instantaneous envelope: time to recover 63 %
    final = vinst_rms[(t > t_ev + 0.35) & (t < t_ev + 0.39)].mean()
    dev0 = ext_i - final
    idx = np.where(np.abs(segi - final) <= abs(dev0) * math.exp(-1))[0]
    k0 = np.argmin(segi) if kind == "min" else np.argmax(segi)
    idx = idx[idx > k0]
    tau = float(ts[idx[0]] - ts[k0]) if idx.size else float("nan")
    return {
        "pre_event_Vrms": float(target),
        "extremum_20ms_Vrms": float(ext),
        "extremum_instantaneous_envelope_Vrms": float(ext_i),
        "recovery_tau_s": tau,
    }


def main():
    g1, g2 = 1 / R1, 1 / R2
    pred = {
        "dip_envelope_Vrms_pred": V_SET_PK / math.sqrt(2) * g1 / g2,
        "rise_envelope_Vrms_pred": V_SET_PK / math.sqrt(2) * g2 / g1,
        "tau_after_step_up_pred_s": (KP_V + g2) / KI_V,
        "tau_after_removal_pred_s": (KP_V + g1) / KI_V,
    }
    cases = {}
    for name, F in [("firmware_no_feedforward", 0.0), ("ideal_load_current_ff_F0.75", 0.75),
                    ("ideal_load_current_ff_F1.0", 1.0)]:
        t, vd = simulate(F)
        vr = trailing_rms_of_envelope(t, vd)
        vi = vd / math.sqrt(2)
        cases[name] = {
            "step_up": event_metrics(t, vr, vi, T_UP, "min"),
            "removal": event_metrics(t, vr, vi, T_DOWN, "max"),
        }
    pi_cases = [("pi_none", "none", 0.0, 0), ("pi_ideal_io_F1", "ideal_io", 1.0, 0)]
    for f in (200.0, 500.0, 1000.0):
        pi_cases.append((f"pi_il_est_F1_lpf{int(f)}Hz", "il_est", 1.0, f))
        pi_cases.append((f"pi_il_est_F0.75_lpf{int(f)}Hz", "il_est", 0.75, f))
    for name, mode, F, f in pi_cases:
        t, vd = simulate_pi(mode, F, f or 500.0)
        if np.isnan(vd).any():
            cases[name] = {"unstable_or_diverged": True}
            continue
        vr = trailing_rms_of_envelope(t, vd)
        vi = vd / math.sqrt(2)
        cases[name] = {
            "step_up": event_metrics(t, vr, vi, T_UP, "min"),
            "removal": event_metrics(t, vr, vi, T_DOWN, "max"),
            "ripple_pk_pk_last_50ms_V": float(np.ptp(vd[t > T_END - 0.05])),
        }
    simulink = {
        "source": r"D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i_load_cycle\analysis_nominal.json",
        "step_up_min_20ms_Vrms_abc": [7.2188, 7.1870, 7.1542],
        "removal_max_20ms_Vrms_abc": [13.3063, 13.4516, 13.1761],
        "recovery_tau_from_csv_s": {"step_up": 0.12, "removal": 0.086},
        "note": "tau read from curves_nominal.csv deficit decay 3.02->3.12 s and 7.026->7.119 s",
    }
    result = {"model": __doc__.strip().splitlines()[0], "analytic_prediction": pred,
              "reduced_model": cases, "simulink_observed": simulink}
    OUT.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
