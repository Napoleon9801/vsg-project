"""Stiff-source inertia test analysis (simulation-only extension).

P_vsg (power the VSG delivers at the PCC) = sum(v*i_load) - sum(v*i_grid),
where i_grid is measured from the source line INTO the PCC.

During a constant grid RoCoF r (pu/s) after the electromechanical transient,
the swing equation with a P-measurement LPF (tf) gives
    dP_vsg = -(2H + K*tf) * r - K * dw_g      (pu)
so a regression dP = a + b*dw_g over the late part of the ramp yields
    H_eff = -a / (2 r)   (expected H + K*tf/2),   K = -b.
After the ramp (constant dw_g): K_hold = -dP/dw_g.
Both sides of the regression use the same 20 ms trailing mean.

Usage:
  python ...\\vsg_stiff_source_analysis.py summary <label> [<label> ...]
  python ...\\vsg_stiff_source_analysis.py fit <label> [<label> ...]
"""
from pathlib import Path
import json
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import plot_stage5i_load_cycle as lc  # noqa: E402
import h5py  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

FOLDER = lc.ROOT / 'matlab/validation_outputs/vsg_stiff_source'
FIG = lc.ROOT / 'docs/figures/vsg_stiff_source_inertia_2026-11-10.png'
WIN = 0.02
K_CFG = 1 / 0.05 + 0.5 * 2 * np.pi * 50
TF_CFG = 1e-4 * (1 - 0.00313176) / 0.00313176


def load(label):
    rep = json.loads((FOLDER / f'report_{label}.json').read_text(encoding='utf-8'))
    with h5py.File(FOLDER / f'results_{label}.mat', 'r') as h:
        t = lc.times(h, 'Vload_abc')
        n = len(t)
        v = lc.samples(h['signals/Vload_abc/data'], 0, n, n)
        il = lc.samples(h['signals/iload_abc/data'], 0, n, n)
        tg = lc.times(h, 'igrid_abc')
        assert np.array_equal(t, tg)
        ig = lc.samples(h['signals/igrid_abc/data'], 0, n, n)
        p_load = np.sum(v * il, axis=1)
        p_grid_in = np.sum(v * ig, axis=1)
        i_grid_sq = np.sum(ig * ig, axis=1) / 3
        v_sq = np.sum(v * v, axis=1) / 3
        ft, fy = lc.scalar(h, 'freq')
        gt, gy = lc.scalar(h, 'grid_f')
        mt, my = lc.scalar(h, 'P_meas')
    grid = np.arange(WIN, t[-1] + 1e-12, 1e-3)

    def trailing(x):
        c = np.concatenate(([0.0], np.cumsum(x[1:] * np.diff(t))))
        return (np.interp(grid, t, c) - np.interp(grid - WIN, t, c)) / WIN

    d = {'t': grid, 'P_vsg': trailing(p_load - p_grid_in), 'P_load': trailing(p_load),
         'P_from_grid': trailing(p_grid_in), 'I_grid_rms': np.sqrt(trailing(i_grid_sq)),
         'V_rms': np.sqrt(trailing(v_sq)), 'f_vsg': np.interp(grid, ft, fy),
         'f_grid': np.interp(grid, gt, gy), 'P_meas': np.interp(grid, mt, my)}
    # grid frequency through the same 20 ms trailing mean (for the regression)
    cg = np.concatenate(([0.0], np.cumsum(gy[1:] * np.diff(gt))))
    d['f_grid_win'] = (np.interp(grid, gt, cg) - np.interp(grid - WIN, gt, cg)) / WIN
    return rep, d


def summary(label):
    rep, d = load(label)
    print(f"== {label}: H={rep['H_s']} ff={rep['ff_gain']} Lline={rep['line_L_H']} wall={rep['wall_seconds']:.0f}s")
    for a in np.arange(0.1, d['t'][-1] + 1e-9, 0.1):
        k = np.searchsorted(d['t'], a)
        s = slice(max(k - 100, 0), k)
        print('  t=%.1f  P_vsg %7.1f [%7.1f..%7.1f]  Igrid %5.2f  Vrms %5.2f  f_vsg %.4f  f_g %.4f' % (
            a, d['P_vsg'][k - 1], d['P_vsg'][s].min(), d['P_vsg'][s].max(), d['I_grid_rms'][k - 1],
            d['V_rms'][k - 1], d['f_vsg'][k - 1], d['f_grid'][k - 1]))


def fit(label):
    rep, d = load(label)
    t1, T, r_hz = rep['ramp_start_s'], rep['ramp_duration_s'], rep['rocof_Hz_per_s']
    r_pu = r_hz / 50.0
    t = d['t']
    pre = (t >= t1 - 0.2) & (t < t1)
    p0 = d['P_vsg'][pre].mean()
    dP = (d['P_vsg'] - p0) / 100.0
    dw = (d['f_grid_win'] - 50.0) / 50.0
    out = {'label': label, 'H_s': rep['H_s'], 'ff_gain': rep['ff_gain'], 'line_L_H': rep['line_L_H'],
           'P_vsg_pre_W': float(p0), 'pre_ripple_pk_pk_W': float(np.ptp(d['P_vsg'][pre]))}
    for lo in (0.3, 0.4, 0.5):
        z = (t >= t1 + lo) & (t < t1 + T)
        A = np.column_stack((np.ones(z.sum()), dw[z]))
        (a, b), res, *_ = np.linalg.lstsq(A, dP[z], rcond=None)
        out[f'ramp_fit_from_{lo}s'] = {'H_eff_s': float(-a / (2 * r_pu)), 'K_pu': float(-b),
                                       'rms_resid_W': float(100 * np.sqrt(np.mean((A @ [a, b] - dP[z]) ** 2)))}
    hold = (t >= t1 + T + 0.3)
    if hold.any():
        out['K_hold_pu'] = float(-dP[hold].mean() / dw[hold].mean())
        out['f_vsg_minus_f_grid_hold_mHz'] = float(1e3 * np.mean(d['f_vsg'][hold] - d['f_grid'][hold]))
    out['peak_P_vsg_W'] = float(d['P_vsg'][t >= t1].max())
    out['expected_H_eff_s'] = float(rep['H_s'] + K_CFG * TF_CFG / 2)
    return out, d, rep


def energy(labels):
    """Inertial-energy difference vs the lowest-H run (LPF/droop effects cancel).

    SUPERSEDED for quantitative results by superposition(): subtracting the
    pre-event offset as a constant here gave a spurious +10 % because the
    start-up transient had not settled at the ramp start (2026-11-10).

    Rotor kinetic energy E = H*S*w^2 (pu w) -> a frequency change dw releases
    dE = 2*H*S*dw.  Between two runs that differ only in H, the extra energy the
    VSG delivers over the whole event is 2*(H - H_ref)*S*|dw_total|.
    """
    runs = [(lb,) + load(lb) for lb in labels]
    runs.sort(key=lambda r: r[1]['H_s'])
    ref_lb, ref_rep, ref = runs[0]
    t1, T = ref_rep['ramp_start_s'], ref_rep['ramp_duration_s']
    dw_total = abs(ref_rep['rocof_Hz_per_s'] * T) / 50.0
    t = ref['t']
    out = {'reference': ref_lb, 'H_ref_s': ref_rep['H_s'], 'dw_total_pu': dw_total, 'S_VA': 100.0, 'runs': []}
    fig, axs = plt.subplots(3, 1, figsize=(12, 10), sharex=True, layout='constrained')
    for (lb, rep, d), c in zip(runs, ['#888888', '#1476b8', '#df7e22']):
        assert np.array_equal(d['t'], t) and rep['ramp_start_s'] == t1
        pre = (t >= t1 - 0.5) & (t < t1)
        post = t >= t1
        diff = d['P_vsg'] - ref['P_vsg']
        diff_c = diff - diff[pre].mean()
        e_meas = float(np.sum(diff_c[post]) * 1e-3)
        e_pred = float(2 * (rep['H_s'] - ref_rep['H_s']) * 100.0 * dw_total)
        tail = t >= t[-1] - 0.3
        out['runs'].append({'label': lb, 'H_s': rep['H_s'],
                            'P_vsg_pre_W': float(d['P_vsg'][pre].mean()),
                            'P_vsg_end_W': float(d['P_vsg'][tail].mean()),
                            'f_vsg_end_minus_grid_mHz': float(1e3 * np.mean(d['f_vsg'][tail] - d['f_grid'][tail])),
                            'peak_P_vsg_W': float(d['P_vsg'][post].max()),
                            'extra_energy_vs_ref_J_measured': e_meas,
                            'extra_energy_vs_ref_J_predicted_2dH_S_dw': e_pred,
                            'ratio_measured_over_predicted': (e_meas / e_pred) if e_pred else None,
                            'residual_P_diff_at_end_W': float(diff_c[tail].mean())})
        axs[0].plot(t, d['f_vsg'], color=c, lw=1.2, label=f"VSG rotor f, H={rep['H_s']:g} s")
        axs[1].plot(t, d['P_vsg'], color=c, lw=1.2, label=f"H={rep['H_s']:g} s")
        if rep['H_s'] != ref_rep['H_s']:
            axs[2].plot(t, diff_c, color=c, lw=1.2,
                        label=f"H={rep['H_s']:g} − H={ref_rep['H_s']:g}: {e_meas:.2f} J (pred {e_pred:.2f} J)")
    axs[0].plot(t, ref['f_grid'], color='k', lw=1.0, ls='--', label='grid f')
    axs[0].set(ylabel='f (Hz)', title='Grid frequency ramp −0.25 Hz/s for 0.8 s (grey) | weak grid X = 1 pu | FF off')
    axs[1].set(ylabel='P_vsg (W)', title='VSG power at the PCC (20 ms mean)')
    axs[2].set(ylabel='ΔP vs lowest H (W)', xlabel='Time (s)',
               title='Extra power attributable to inertia (LPF and droop cancel in the difference)')
    for ax in axs:
        ax.grid(alpha=.25)
        ax.axvspan(t1, t1 + T, color='#dddddd', alpha=.5)
        ax.legend(fontsize=8)
        ax.set_xlim(t1 - 0.5, t[-1])
    fig.suptitle('Stiff-source inertia test (simulation only)', fontsize=13)
    fig.savefig(FIG, dpi=150)
    plt.close(fig)
    out['figure'] = str(FIG)
    (FOLDER / 'stiff_source_energy.json').write_text(json.dumps(out, indent=2), encoding='utf-8')
    print(json.dumps(out, indent=2))


def superposition(pairs):
    """Energy attributable to H with the start-up transient removed by superposition.

    pairs: list of (ramp_label, noramp_label), lowest H first.
    response_H(t) = P_ramp,H(t) - P_noramp,H(t)  (identical start-up -> cancels)
    E_H = integral over [t1, end] of (response_H - response_ref)
    Also reports the swing-equation closure and the residual K*int(w) term.
    """
    K = K_CFG
    rows = []
    for rl, nl in pairs:
        rep, dr = load(rl)
        _, dn = load(nl)
        assert np.array_equal(dr['t'], dn['t'])
        rows.append((rl, rep, dr, dn))
    t = rows[0][2]['t']
    t1 = rows[0][1]['ramp_start_s']
    T = rows[0][1]['ramp_duration_s']
    dw_total = abs(rows[0][1]['rocof_Hz_per_s'] * T) / 50.0
    post = t >= t1
    resp = {rl: dr['P_vsg'] - dn['P_vsg'] for rl, _, dr, dn in rows}
    wresp = {rl: (dr['f_vsg'] - dn['f_vsg']) / 50.0 for rl, _, dr, dn in rows}
    ref_l, ref_rep = rows[0][0], rows[0][1]
    out = {'method': 'superposition: (ramp - no-ramp) per H, then minus lowest-H response',
           'dw_total_pu': dw_total, 'runs': []}
    for rl, rep, dr, dn in rows:
        pre_noise = float(np.abs(resp[rl][(t >= t1 - 0.5) & (t < t1)]).max())
        e_abs = float(np.sum(resp[rl][post]) * 1e-3)
        item = {'label': rl, 'H_s': rep['H_s'], 'pre_event_|response|_max_W': pre_noise,
                'response_energy_J': e_abs}
        if rl != ref_l:
            e = float(np.sum((resp[rl] - resp[ref_l])[post]) * 1e-3)
            pred = float(2 * (rep['H_s'] - ref_rep['H_s']) * 100.0 * dw_total)
            k_leak = float(K * np.sum((wresp[rl] - wresp[ref_l])[post]) * 1e-3 * 100.0)
            item.update({'extra_energy_vs_ref_J': e, 'predicted_J': pred, 'ratio': e / pred,
                         'K_term_leak_J': k_leak, 'ratio_after_removing_K_leak': (e + k_leak) / pred})
        out['runs'].append(item)
    (FOLDER / 'stiff_source_energy_superposition.json').write_text(json.dumps(out, indent=2), encoding='utf-8')
    print(json.dumps(out, indent=2))


def main():
    mode, labels = sys.argv[1], sys.argv[2:]
    if mode == 'superposition':
        superposition([tuple(x.split(':')) for x in labels])
        return
    if mode == 'summary':
        for lb in labels:
            summary(lb)
        return
    if mode == 'energy':
        energy(labels)
        return
    results, curves = [], []
    for lb in labels:
        o, d, rep = fit(lb)
        results.append(o)
        curves.append((lb, d, rep))
        print(json.dumps(o, indent=1))
    if len(results) >= 2:
        H = np.array([r['H_s'] for r in results])
        He = np.array([r['ramp_fit_from_0.4s']['H_eff_s'] for r in results])
        slope, icpt = np.polyfit(H, He, 1)
        summ = {'dHeff_dH': float(slope), 'Heff_at_H0_s': float(icpt),
                'expected_intercept_K_tf_over_2_s': float(K_CFG * TF_CFG / 2)}
        print('SWEEP', json.dumps(summ))
        (FOLDER / 'stiff_source_fit.json').write_text(json.dumps({'runs': results, 'sweep': summ}, indent=2),
                                                     encoding='utf-8')
        fig, axs = plt.subplots(3, 1, figsize=(12, 10), sharex=True, layout='constrained')
        for (lb, d, rep), c in zip(curves, lc.COLORS):
            t = d['t']
            pre = (t >= rep['ramp_start_s'] - .2) & (t < rep['ramp_start_s'])
            axs[0].plot(t, d['f_grid'], color='k', lw=.8) if lb == curves[0][0] else None
            axs[0].plot(t, d['f_vsg'], color=c, lw=1.1, label=f"VSG rotor f, H={rep['H_s']:g}")
            axs[1].plot(t, d['P_vsg'] - d['P_vsg'][pre].mean(), color=c, lw=1.2, label=f"H={rep['H_s']:g} s")
            axs[2].plot(t, d['I_grid_rms'], color=c, lw=1.0)
        axs[0].set(ylabel='f (Hz)', title='Grid frequency (black) and VSG rotor frequency')
        axs[1].set(ylabel='ΔP_vsg (W)', title='VSG power change at the PCC (20 ms mean)')
        axs[2].set(ylabel='I_grid RMS (A)', xlabel='Time (s)')
        for ax in axs:
            ax.grid(alpha=.25)
            ax.axvspan(curves[0][2]['ramp_start_s'], curves[0][2]['ramp_start_s'] + curves[0][2]['ramp_duration_s'],
                       color='#dddddd', alpha=.4)
        axs[0].legend(fontsize=8)
        axs[1].legend(fontsize=8)
        fig.suptitle('Stiff-source inertia test (sim only) | grid RoCoF ramp in grey', fontsize=13)
        fig.savefig(FIG, dpi=150)
        plt.close(fig)
        print('FIG', FIG)


if __name__ == '__main__':
    main()
