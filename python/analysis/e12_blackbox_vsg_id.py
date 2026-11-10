"""VSG black-box identification from TERMINAL quantities only (E1.2 FF run).

Question: would an outside observer who only measures the load-terminal voltages
and currents conclude that this inverter behaves like a synchronous machine with
the configured parameters (H = 5 s, K = 1/Rp + D*ws = 177.08 pu, P-LPF 5 Hz,
secondary Ki = 4 pu/(Hz*s))?

Terminal estimators (independent of every controller state):
  f_term : angle of the Clarke space vector theta = atan2(v_beta, v_alpha);
           f = [theta(t) - theta(t-20 ms)] / (2*pi*20 ms)  (one-cycle average,
           cancels 100 Hz ripple from negative sequence and zero-sequence free)
  P_term : sum(v_x * i_x) at the load terminals, 0.5 ms bin means

Black-box model (synchronous machine + governor droop + AGC-like integral):
  2H dw/dt   = Pm - pf - K*w           w = (omega - ws)/ws
  tf dpf/dt  = P_term/100 - pf          (electrical power seen through a lag)
  dPm/dt     = -Ki * 50 * w             (secondary / AGC, f error in Hz)
  Initialised in equilibrium at the start of each window.
  Prediction f = 50(1+w) passed through the SAME 20 ms average as f_term.

Code check (tautological, validates the fitter only): fit the same structure to the
controller's own internal omega and filtered P_meas -> must return the configured
values.  Black-box results are what matter.

Symmetry note: without secondary, P->w is -1/(K(1+tm s)(1+tf s)) with tm = 2H/K,
symmetric in tm and tf.  The secondary loop encloses tm only, so the swap is only
weakly broken.  The script fits from two starts (H=5/tf=32 ms and the swapped
H=K*0.0318/2/tf=56 ms) and reports both costs.

Run: python D:\\workspace\\engineering\\vsg-project\\python\\analysis\\e12_blackbox_vsg_id.py
"""
from pathlib import Path
import json
import sys

import numpy as np
from scipy.optimize import least_squares
from scipy.linalg import expm

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import plot_stage5i_load_cycle as lc  # noqa: E402
import h5py  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

ROOT = lc.ROOT
SRC = ROOT / 'matlab/validation_outputs/e12_ff_load_cycle/results_nominal_ff1.mat'
OUT = ROOT / 'matlab/validation_outputs/e12_ff_load_cycle/e12_blackbox_id.json'
FIG = ROOT / 'docs/figures/e12_blackbox_vsg_id_2026-11-10.png'
DT = 5e-4
WIN = 0.02
TRUE = {'H_s': 5.0, 'K_pu': 1 / 0.05 + 0.5 * 2 * np.pi * 50, 'tf_s': 1e-4 * (1 - 0.00313176) / 0.00313176,
        'Ki_pu_per_Hz_s': 4.0}
FIT_WINDOWS = {'event1_fit': (2.5, 6.9), 'event2_validate': (6.9, 11.0), 'both': (2.5, 11.0)}
EVENTS = (3.0, 7.0)
MASK_S = 0.150   # after each load step the terminal voltage angle rings (~25 Hz, +/-1 Hz apparent
                 # frequency, ~120 ms; voltage-loop dynamics, not rotor motion) -> excluded from residuals


def weights(t):
    w = np.ones(len(t))
    for ev in EVENTS:
        w[(t >= ev) & (t < ev + MASK_S)] = 0.0
    return w


# ------------------------------------------------------------------ data
def terminal_signals():
    with h5py.File(SRC, 'r') as h:
        t = lc.times(h, 'Vload_abc')
        n = len(t)
        v = lc.samples(h['signals/Vload_abc/data'], 0, n, n)
        i = lc.samples(h['signals/iload_abc/data'], 0, n, n)
        p = np.sum(v * i, axis=1)
        va, vb, vc = v.T
        alpha = (2 / 3) * (va - 0.5 * vb - 0.5 * vc)
        beta = (2 / 3) * (np.sqrt(3) / 2) * (vb - vc)
        theta = np.unwrap(np.arctan2(beta, alpha))
        del v, i, va, vb, vc, alpha, beta
        grid = np.arange(0.05, 11.0 + 1e-9, DT)
        f_term = (np.interp(grid, t, theta) - np.interp(grid - WIN, t, theta)) / (2 * np.pi * WIN)
        # P bin means over (grid-DT, grid]
        cp = np.concatenate(([0.0], np.cumsum(p[1:] * np.diff(t))))
        p_term = (np.interp(grid, t, cp) - np.interp(grid - DT, t, cp)) / DT
        ft, fy = lc.scalar(h, 'freq')
        pt, py = lc.scalar(h, 'P_meas')
        f_int = np.interp(grid, ft, fy)
        p_int = np.interp(grid, pt, py)
    return grid, f_term, p_term, f_int, p_int


# ------------------------------------------------------------------ model
def simulate(params, t, p_w, with_lpf, avg_output):
    H, K, tf, Ki = params
    u = p_w / 100.0
    if with_lpf:
        A = np.array([[-K / (2 * H), -1 / (2 * H), 1 / (2 * H)],
                      [0.0, -1 / tf, 0.0],
                      [-Ki * 50.0, 0.0, 0.0]])
        B = np.array([0.0, 1 / tf, 0.0])
        x = np.array([0.0, u[0], 0.0])
    else:
        A = np.array([[-K / (2 * H), 1 / (2 * H)],
                      [-Ki * 50.0, 0.0]])
        B = np.array([-1 / (2 * H), 0.0])
        x = np.array([0.0, 0.0])
    # equilibrium start: w0 = 0 offset handled by measuring deviation from initial f
    n = A.shape[0]
    M = expm(np.block([[A, B[:, None]], [np.zeros((1, n + 1))]]) * DT)
    Ad, Bd = M[:n, :n], M[:n, n]
    if with_lpf:
        x[2] = x[1]                      # Pm0 = pf0  (dw/dt = 0 at start)
    else:
        x[1] = u[0]                      # Pm0 = Pe0
    w = np.empty(len(t))
    for k in range(len(t)):
        w[k] = x[0]
        x = Ad @ x + Bd * u[k]
    f = 50.0 * w
    if avg_output:
        m = int(round(WIN / DT))
        c = np.concatenate(([0.0], np.cumsum(f)))
        g = np.empty_like(f)
        g[m:] = (c[m + 1:] - c[1:-m]) / m
        g[:m] = f[:m]
        f = g
    return f


def fit(t, f_meas, p_w, x0, with_lpf, avg_output, fixed_tf=None, masked=True):
    f_dev = f_meas - f_meas[0]
    wt = weights(t) if masked else np.ones(len(t))

    def unpack(z):
        H, K, Ki = np.exp(z[0]), np.exp(z[1]), np.exp(z[-1])
        tf = np.exp(z[2]) if (with_lpf and fixed_tf is None) else (fixed_tf or 1.0)
        return H, K, tf, Ki

    def resid(z):
        return (simulate(unpack(z), t, p_w, with_lpf, avg_output) - f_dev) * wt

    z0 = [np.log(x0['H_s']), np.log(x0['K_pu'])]
    if with_lpf and fixed_tf is None:
        z0.append(np.log(x0['tf_s']))
    z0.append(np.log(x0['Ki_pu_per_Hz_s']))
    sol = least_squares(resid, np.array(z0), x_scale='jac', xtol=1e-12, ftol=1e-12, gtol=1e-12, max_nfev=400)
    H, K, tf, Ki = unpack(sol.x)
    r = sol.fun[wt > 0]
    dof = max(len(r) - len(sol.x), 1)
    s2 = float(r @ r) / dof
    J = sol.jac
    try:
        cov = np.linalg.inv(J.T @ J) * s2
        se_log = np.sqrt(np.diag(cov))
        corr = cov / np.outer(se_log, se_log)
    except np.linalg.LinAlgError:
        se_log, corr = np.full(len(sol.x), np.nan), None
    names = ['H_s', 'K_pu'] + (['tf_s'] if (with_lpf and fixed_tf is None) else []) + ['Ki_pu_per_Hz_s']
    est = {'H_s': H, 'K_pu': K, 'Ki_pu_per_Hz_s': Ki}
    if with_lpf:
        est['tf_s'] = tf
    out = {'estimate': {k: float(v) for k, v in est.items()},
           'relative_se_pct': {nm: float(100 * s) for nm, s in zip(names, se_log)},
           'rms_residual_mHz': float(1e3 * np.sqrt(np.mean(r ** 2))),
           'max_abs_residual_mHz': float(1e3 * np.max(np.abs(r))),
           'cost': float(sol.cost), 'nfev': int(sol.nfev), 'success': bool(sol.success)}
    if corr is not None:
        out['correlation'] = {f'{a}~{b}': float(corr[i, j]) for i, a in enumerate(names)
                              for j, b in enumerate(names) if j > i}
    if with_lpf:
        out['tau_m_s'] = float(2 * H / K)
    return out


def rmse(params, t, f_meas, p_w, with_lpf, avg_output):
    f = simulate(params, t, p_w, with_lpf, avg_output)
    e = (f - (f_meas - f_meas[0]))[weights(t) > 0]
    return float(1e3 * np.sqrt(np.mean(e ** 2)))


def main():
    grid, f_term, p_term, f_int, p_int = terminal_signals()
    res = {'source': str(SRC), 'configured': {k: float(v) for k, v in TRUE.items()},
           'configured_tau_m_s': float(2 * TRUE['H_s'] / TRUE['K_pu'])}

    def sel(a, b):
        return (grid >= a) & (grid < b)

    # 0. independent terminal frequency vs internal rotor frequency
    s = sel(2.5, 11.0)
    jumps = {}
    for ev in EVENTS:
        z = (grid >= ev) & (grid < ev + 0.08)
        jumps[f'{ev:g}s'] = float(np.degrees(2 * np.pi * np.sum(f_term[z] - f_int[z]) * DT))
    res['terminal_phase_jump_deg'] = jumps
    q = (grid >= 2.5) & (grid < 11.0) & (weights(grid) > 0)
    res['terminal_vs_internal_frequency_masked'] = {
        'max_abs_diff_mHz': float(1e3 * np.max(np.abs(f_term[q] - f_int[q]))),
        'rms_diff_mHz': float(1e3 * np.sqrt(np.mean((f_term[q] - f_int[q]) ** 2)))}
    res['terminal_vs_internal_frequency'] = {
        'max_abs_diff_mHz': float(1e3 * np.max(np.abs(f_term[s] - f_int[s]))),
        'rms_diff_mHz': float(1e3 * np.sqrt(np.mean((f_term[s] - f_int[s]) ** 2))),
        'note': 'f_term is a 20 ms average; f_int instantaneous, so transients differ by the averaging lag'}

    # 1. code check: internal omega + filtered P_meas (tautological)
    s = sel(*FIT_WINDOWS['both'])
    x0 = {'H_s': 3.0, 'K_pu': 120.0, 'tf_s': 0.05, 'Ki_pu_per_Hz_s': 2.0}
    res['code_check_internal'] = fit(grid[s], f_int[s], p_int[s], x0, with_lpf=False, avg_output=False, masked=False)

    # 2. black-box from terminals, two starting points, three windows
    starts = {'start_A_H5_tf32ms': {'H_s': 5.0, 'K_pu': 177.0, 'tf_s': 0.0318, 'Ki_pu_per_Hz_s': 4.0},
              'start_B_swapped_H2.8_tf56ms': {'H_s': 177.08 * 0.0318 / 2, 'K_pu': 177.0, 'tf_s': 0.0565,
                                              'Ki_pu_per_Hz_s': 4.0},
              'start_C_neutral': {'H_s': 1.5, 'K_pu': 80.0, 'tf_s': 0.01, 'Ki_pu_per_Hz_s': 1.0}}
    bb = {}
    for wname, (a, b) in FIT_WINDOWS.items():
        if wname == 'event2_validate':
            continue
        s = sel(a, b)
        bb[wname] = {sn: fit(grid[s], f_term[s], p_term[s], x0, with_lpf=True, avg_output=True)
                     for sn, x0 in starts.items()}
    res['blackbox'] = bb

    # 3. cross-validation: event-1 fit (best start) predicts event 2
    best = min(bb['event1_fit'].values(), key=lambda r: r['cost'])['estimate']
    s2 = sel(*FIT_WINDOWS['event2_validate'])
    params = (best['H_s'], best['K_pu'], best['tf_s'], best['Ki_pu_per_Hz_s'])
    true_params = (TRUE['H_s'], TRUE['K_pu'], TRUE['tf_s'], TRUE['Ki_pu_per_Hz_s'])
    swapped = (TRUE['K_pu'] * TRUE['tf_s'] / 2, TRUE['K_pu'], 2 * TRUE['H_s'] / TRUE['K_pu'], TRUE['Ki_pu_per_Hz_s'])
    res['cross_validation_event2'] = {
        'event1_fit_params': best,
        'rms_mHz_event1_fit_predicting_event2': rmse(params, grid[s2], f_term[s2], p_term[s2], True, True),
        'rms_mHz_configured_params': rmse(true_params, grid[s2], f_term[s2], p_term[s2], True, True),
        'rms_mHz_swapped_params_H2.8_tf56ms': rmse(swapped, grid[s2], f_term[s2], p_term[s2], True, True),
    }
    s = sel(*FIT_WINDOWS['both'])
    res['configured_vs_swapped_on_both_events'] = {
        'rms_mHz_configured': rmse(true_params, grid[s], f_term[s], p_term[s], True, True),
        'rms_mHz_swapped': rmse(swapped, grid[s], f_term[s], p_term[s], True, True),
        'rms_mHz_droop_only_H0.05_same_K_tf': rmse((0.05, TRUE['K_pu'], TRUE['tf_s'], TRUE['Ki_pu_per_Hz_s']),
                                                   grid[s], f_term[s], p_term[s], True, True),
    }

    # 4. profile over H: fix H, refit K, tf, Ki -> flat cost means H is not identifiable
    s = sel(*FIT_WINDOWS['both'])
    tt, fm, pm = grid[s], f_term[s] - f_term[s][0], p_term[s]
    wt = weights(tt)
    prof = []
    for Hfix in (0.05, 0.5, 1.0, 2.8, 5.0, 10.0, 20.0):
        def r_h(z, Hfix=Hfix):
            return (simulate((Hfix, np.exp(z[0]), np.exp(z[1]), np.exp(z[2])), tt, pm, True, True) - fm) * wt
        sol = least_squares(r_h, np.log([177.0, 0.0318, 4.0]), x_scale='jac', max_nfev=300)
        e = sol.fun[wt > 0]
        prof.append({'H_fixed_s': Hfix, 'K_pu': float(np.exp(sol.x[0])), 'tf_s': float(np.exp(sol.x[1])),
                     'Ki': float(np.exp(sol.x[2])), 'rms_mHz': float(1e3 * np.sqrt(np.mean(e ** 2)))})
    res['profile_H'] = prof
    res['mask_after_event_s'] = MASK_S

    # figure
    fig, axs = plt.subplots(2, 2, figsize=(13, 7.5), layout='constrained')
    for col, (a, b) in enumerate([(2.9, 3.6), (6.9, 7.6)]):
        ss = sel(2.5, 11.0)
        tt, fm, pm = grid[ss], f_term[ss], p_term[ss]
        z = (tt >= a) & (tt < b)
        for prm, name, c, ls in [(true_params, 'model, configured H=5 / tf=32 ms', '#1476b8', '-'),
                                 (swapped, 'model, swapped H=2.8 / tf=56 ms', '#df7e22', '--'),
                                 ((0.05, TRUE['K_pu'], TRUE['tf_s'], TRUE['Ki_pu_per_Hz_s']),
                                  'model, droop-like H=0.05', '#888888', ':')]:
            fsim = simulate(prm, tt, pm, True, True) + fm[0]
            axs[0, col].plot(tt[z], fsim[z], color=c, ls=ls, lw=1.4, label=name)
        axs[0, col].plot(tt[z], fm[z], color='k', lw=1.0, alpha=.7, label='terminal f (measured, 20 ms)')
        axs[0, col].plot(tt[z], f_int[ss][z], color='#9b5062', lw=.8, alpha=.7, label='internal rotor f')
        axs[1, col].plot(tt[z], pm[z], color='#259660', lw=1.0, label='terminal P (0.5 ms bins)')
        axs[0, col].set(ylabel='f (Hz)', title=f'Event at {int(round(a + .1))} s')
        axs[1, col].set(ylabel='P (W)', xlabel='Time (s)')
        for ax in axs[:, col]:
            ax.grid(alpha=.25)
    axs[0, 0].legend(fontsize=8)
    axs[1, 0].legend(fontsize=8)
    fig.suptitle('Black-box VSG identification from terminal V, I only (E1.2 FF run, secondary ON)', fontsize=13)
    fig.savefig(FIG, dpi=150)
    plt.close(fig)
    res['figure'] = str(FIG)
    OUT.write_text(json.dumps(res, indent=2), encoding='utf-8')
    print(json.dumps(res, indent=2))


if __name__ == '__main__':
    main()
