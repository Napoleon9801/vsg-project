"""
VSG Project — Stage 2 post-processing.

Reads `matlab/vsg_stage2_out.mat` written by `phase2_power_angle.m`,
extracts damped-oscillation metrics (period, damping ratio via log
decrement, overshoot) and compares them against the small-signal
analytical prediction. Writes a PNG to `python/plots/phase2_swing.png`.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.io as sio
from scipy.signal import find_peaks


HERE      = Path(__file__).resolve().parent
DATA_PATH = HERE.parents[1] / "matlab" / "vsg_stage2_out.mat"
PLOT_DIR  = HERE.parent / "plots"
PLOT_DIR.mkdir(exist_ok=True)


def load(path: Path) -> dict:
    raw = sio.loadmat(path, squeeze_me=True)
    out: dict = {}
    for k, v in raw.items():
        if k.startswith("__"):
            continue
        arr = np.asarray(v)
        out[k] = arr.flatten() if arr.ndim > 0 else float(arr)
    return out


def measure(d: dict) -> dict:
    """Pull damped-oscillation metrics from the rotor-angle waveform."""
    t      = d["t"]
    delta  = d["delta"]
    d_eq_n = float(d["delta_eq_new"])
    d_eq_i = float(d["delta_init"])
    t_step = float(d["Pm_step_time"])

    mask = t >= t_step
    tw   = t[mask]
    dw   = delta[mask]

    peaks, _ = find_peaks(dw)

    if len(peaks) >= 2:
        T_d_sim = float(tw[peaks[1]] - tw[peaks[0]])
        fd_sim  = 1.0 / T_d_sim
        A1 = float(dw[peaks[0]] - d_eq_n)
        A2 = float(dw[peaks[1]] - d_eq_n)
        if A1 > 0 and A2 > 0:
            ldec     = np.log(A1 / A2)
            zeta_sim = ldec / np.sqrt(4 * np.pi**2 + ldec**2)
        else:
            zeta_sim = float("nan")
    else:
        T_d_sim  = float("nan")
        fd_sim   = float("nan")
        zeta_sim = float("nan")

    delta_swing_ss = d_eq_n - d_eq_i
    if delta_swing_ss != 0:
        M_p_sim = float((dw.max() - d_eq_n) / delta_swing_ss)
    else:
        M_p_sim = float("nan")

    return {
        "T_d_sim":         T_d_sim,
        "fd_sim":          fd_sim,
        "zeta_sim":        zeta_sim,
        "M_p_sim":         M_p_sim,
        "delta_peak_deg":  float(np.degrees(dw.max())),
        "delta_final_deg": float(np.degrees(dw[-1])),
        "n_peaks":         int(len(peaks)),
    }


def report(d: dict, m: dict) -> None:
    omega_n  = float(d["omega_n"])
    zeta_lin = float(d["zeta_lin"])
    print("Stage 2 — analytical vs simulated")
    print(f"  omega_n  (analytical) = {omega_n:.3f} rad/s   f_d ~ {omega_n/(2*np.pi):.3f} Hz")
    print(f"  zeta     (analytical) = {zeta_lin:.3f}        zeta (sim, log-dec) = {m['zeta_sim']:.3f}")
    print(f"  T_d      (sim, peaks) = {m['T_d_sim']:.3f} s  f_d  (sim)          = {m['fd_sim']:.3f} Hz")
    print(f"  delta_eq_init         = {np.degrees(float(d['delta_init'])):.3f} deg")
    print(f"  delta_eq_new          = {np.degrees(float(d['delta_eq_new'])):.3f} deg")
    print(f"  delta_peak  (sim)     = {m['delta_peak_deg']:.3f} deg  overshoot = {m['M_p_sim']*100:.2f} %")
    print(f"  delta_final (sim)     = {m['delta_final_deg']:.3f} deg")
    print(f"  peaks detected        = {m['n_peaks']}")


def plot_results(d: dict, m: dict) -> Path:
    f_base = float(d["f_base"])
    t_step = float(d["Pm_step_time"])
    d_eq_i = float(d["delta_init"])
    d_eq_n = float(d["delta_eq_new"])
    Pm_i   = float(d["Pm_initial"])
    Pm_n   = Pm_i + float(d["Pm_step"])

    fig, axes = plt.subplots(3, 1, figsize=(10, 9), sharex=True)
    fig.suptitle(
        f"VSG Stage 2 — Power-Angle Swing  "
        f"[H={float(d['H']):g}s, D={float(d['D']):g}, X={float(d['X_pu']):g}, "
        f"Pmax={float(d['Pmax']):.2f}, zeta_lin~{float(d['zeta_lin']):.2f}]",
        fontsize=12, fontweight="bold",
    )

    ax = axes[0]
    ax.plot(d["t"], d["freq"], color="steelblue", linewidth=1.6)
    ax.axhline(f_base, color="red",  linestyle="--", linewidth=1)
    ax.axvline(t_step, color="gray", linestyle=":",  linewidth=1)
    ax.set_ylabel("Frequency (Hz)")
    ax.grid(True, alpha=0.4)
    ax.set_title("Frequency response")

    ax = axes[1]
    ax.plot(d["t"], np.degrees(d["delta"]), color="mediumpurple", linewidth=1.6)
    ax.axhline(np.degrees(d_eq_i), color="green", linestyle="--", linewidth=1,
               label=f"delta_eq_init = {np.degrees(d_eq_i):.2f} deg")
    ax.axhline(np.degrees(d_eq_n), color="red",   linestyle="--", linewidth=1,
               label=f"delta_eq_new = {np.degrees(d_eq_n):.2f} deg")
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_ylabel("delta (deg)")
    ax.legend(loc="best", fontsize=9)
    ax.grid(True, alpha=0.4)
    ax.set_title(
        f"Rotor angle  -  sim: T_d={m['T_d_sim']:.3f}s, "
        f"zeta_sim={m['zeta_sim']:.3f}, overshoot={m['M_p_sim']*100:.1f}%"
    )

    ax = axes[2]
    ax.plot(d["t"], d["Pe"], color="darkgreen", linewidth=1.6, label="P_e(t)")
    ax.axhline(Pm_i, color="green", linestyle="--", linewidth=1, label=f"P_m_init = {Pm_i:.2f} pu")
    ax.axhline(Pm_n, color="red",   linestyle="--", linewidth=1, label=f"P_m_new  = {Pm_n:.2f} pu")
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("Power (pu)")
    ax.legend(loc="best", fontsize=9)
    ax.grid(True, alpha=0.4)
    ax.set_title("Electrical power output  P_e = Pmax * sin(delta)")

    plt.tight_layout()
    out = PLOT_DIR / "phase2_swing.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Plot saved : {out}")
    return out


if __name__ == "__main__":
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"{DATA_PATH} not found - run matlab/phase2_power_angle.m first."
        )
    data    = load(DATA_PATH)
    metrics = measure(data)
    report(data, metrics)
    plot_results(data, metrics)
