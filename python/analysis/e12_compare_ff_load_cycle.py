"""E1.2 — compare the Stage 5i load cycle with/without estimated load-current FF.

Steps
  1. Equivalence: ff_gain=0 smoke (0.1 s) must reproduce the original Stage 5i
     smoke run (same source model, FF path present but multiplied by zero).
  2. Re-use the exact Stage 5i RMS/power pipeline (plot_stage5i_load_cycle.main)
     on the FF nominal run by redirecting its FOLDER/DATE globals; this writes
     analysis_<label>.json, curves_<label>.csv/.mat and figures.
  3. Compare against the saved baseline analysis and the proposed criteria
     (docs/notes/e12_voltage_loop_analysis_th_2026-11-10.md section 5) and draw
     an overlay figure.

Run (MATLAB job must have finished):
  python D:\\workspace\\engineering\\vsg-project\\python\\analysis\\e12_compare_ff_load_cycle.py
"""
from pathlib import Path
import json
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import plot_stage5i_load_cycle as lc  # noqa: E402  (also puts .deps_stage5h on sys.path)
import h5py  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402

ROOT = lc.ROOT
BASE = ROOT / 'matlab/validation_outputs/stage5i_load_cycle'
NEW = ROOT / 'matlab/validation_outputs/e12_ff_load_cycle'
FIG = ROOT / 'docs/figures'
LABEL = 'nominal_ff1'
DATE = '2026-11-10'
V_NOM = 14 / np.sqrt(2)          # 9.8995 V RMS phase
OUT = NEW / 'e12_comparison.json'


def equivalence():
    with h5py.File(BASE / 'results_smoke.mat', 'r') as a, h5py.File(NEW / 'results_smoke_ff0.mat', 'r') as b:
        ta, tb = lc.times(a, 'Vload_abc'), lc.times(b, 'Vload_abc')
        res = {'baseline_samples': int(len(ta)), 'ff0_samples': int(len(tb)),
               'time_axes_identical': bool(len(ta) == len(tb) and np.array_equal(ta, tb))}
        if res['time_axes_identical']:
            n = len(ta)
            va = lc.samples(a['signals/Vload_abc/data'], 0, n, n)
            vb = lc.samples(b['signals/Vload_abc/data'], 0, n, n)
            res['max_abs_Vload_diff_V'] = float(np.max(np.abs(va - vb)))
        else:
            # different solver step sequence: compare on a common grid
            grid = np.arange(0.0, min(ta[-1], tb[-1]), 5e-6)
            va = lc.samples(a['signals/Vload_abc/data'], 0, len(ta), len(ta))
            vb = lc.samples(b['signals/Vload_abc/data'], 0, len(tb), len(tb))
            d = [np.max(np.abs(np.interp(grid, ta, va[:, k]) - np.interp(grid, tb, vb[:, k]))) for k in range(3)]
            res['max_abs_Vload_diff_V_interp'] = float(max(d))
        diff = res.get('max_abs_Vload_diff_V', res.get('max_abs_Vload_diff_V_interp'))
        vmax = float(np.max(np.abs(va)))
        res['max_abs_Vload_V'] = vmax
        res['relative_max_diff'] = diff / vmax
        # Not bit-exact: added blocks change the ode23tb state ordering/step path.
        # Accept solver-level agreement (relative < 1e-4, bounded, 37 uA current diff observed).
        res['tolerance'] = 'relative max |dV| < 1e-4 of max |V| (variable-step solver path, not bit-exact)'
        res['pass'] = bool(diff / vmax < 1e-4)
    return res


def recovery_time(t, v, event, band):
    """First time after which all phases stay within +/-band of V_NOM until event+0.5 s."""
    sel = (t >= event) & (t <= event + 0.5)
    ts, vs = t[sel], v[sel]
    outside = np.flatnonzero(np.any(np.abs(vs - V_NOM) > band * V_NOM, axis=1))
    if not len(outside):
        return 0.0
    k = outside[-1] + 1
    return None if k >= len(ts) else float(ts[k] - event)


def criteria(analysis, curves_csv):
    d = np.loadtxt(curves_csv, delimiter=',', skiprows=1)
    t, v = d[:, 0], d[:, 3:6]
    ss = [x for w in analysis['steady_windows'] for x in w['phase_voltage_rms_V']]
    ev = analysis['rms_events']
    vmin = min(ev[0]['Vrms_min_abc_V'])
    vmax = max(ev[1]['Vrms_max_abc_V'])
    rec = [recovery_time(t, v, 3, 0.02), recovery_time(t, v, 7, 0.02)]
    fe = analysis['frequency_events']
    return {
        'V_SS_min_max_V': [min(ss), max(ss)],
        'V_SS_pass_pm2pct': bool(all(abs(x - V_NOM) <= 0.02 * V_NOM for x in ss)),
        'V_TR_min_after_increase_V': vmin,
        'V_TR_max_after_removal_V': vmax,
        'V_TR_pass_pm10pct': bool(vmin >= 0.9 * V_NOM and vmax <= 1.1 * V_NOM),
        'V_REC_s_to_pm2pct_after_increase_removal': rec,
        'V_REC_pass_40ms': bool(all(r is not None and r <= 0.040 for r in rec)),
        'F_REC_settling_delay_s': [e['observed_settling_delay_s'] for e in fe],
        'F_min_max_Hz': [min(e['min_Hz'] for e in fe), max(e['max_Hz'] for e in fe)],
        'note': 'V_REC measured on the trailing 20 ms RMS, so it includes up to 20 ms of window lag.',
    }


def overlay(base_csv, new_csv):
    b = np.loadtxt(base_csv, delimiter=',', skiprows=1)
    n = np.loadtxt(new_csv, delimiter=',', skiprows=1)
    fig, axs = plt.subplots(2, 2, figsize=(13, 7.5), layout='constrained')
    for col, ev in enumerate([3, 7]):
        for row, (idx, ylab) in enumerate([(3, 'Vrms phase A (V)'), (2, 'f internal (Hz)')]):
            ax = axs[row, col]
            for data, name, c in [(b, 'Stage 5i baseline (no FF)', '#9b5062'), (n, 'E1.2 i_o estimate FF (F=1, 1 kHz)', '#1476b8')]:
                s = (data[:, 0] >= ev - 0.05) & (data[:, 0] <= ev + 0.5)
                ax.plot(data[s, 0], data[s, idx], color=c, linewidth=1.4, label=name)
            if idx == 3:
                for f, ls in [(1.0, ':'), (0.9, '--'), (1.1, '--'), (0.98, ':'), (1.02, ':')]:
                    ax.axhline(V_NOM * f, color='#555555', linewidth=.7, linestyle=ls)
            ax.axvline(ev, color='#555555', linewidth=.8, linestyle='--')
            ax.set(ylabel=ylab, xlabel='Time (s)',
                   title=f"{'Load increase' if ev == 3 else 'Load return'} at {ev} s")
            ax.grid(alpha=.25)
    axs[0, 0].legend(fontsize=9, loc='lower right')
    fig.suptitle('E1.2 | Stage 5i switching model | trailing 20 ms RMS | dashed = ±10 %, dotted = ±2 % of 9.90 V',
                 fontsize=13)
    path = FIG / f'e12_ff_vs_baseline_{DATE}.png'
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return str(path)


def main():
    result = {'equivalence_ff0_vs_original_smoke': equivalence()}
    lc.FOLDER, lc.DATE = NEW, DATE
    lc.main(LABEL)
    new_analysis = json.loads((NEW / f'analysis_{LABEL}.json').read_text(encoding='utf-8'))
    base_analysis = json.loads((BASE / 'analysis_nominal.json').read_text(encoding='utf-8'))
    result['baseline'] = criteria(base_analysis, BASE / 'curves_nominal.csv')
    result['e12_ff'] = criteria(new_analysis, NEW / f'curves_{LABEL}.csv')
    result['overlay_figure'] = overlay(BASE / 'curves_nominal.csv', NEW / f'curves_{LABEL}.csv')
    result['source_reports'] = {'baseline': str(BASE / 'analysis_nominal.json'),
                                'e12_ff': str(NEW / f'analysis_{LABEL}.json')}
    OUT.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print('E12_COMPARISON', json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
