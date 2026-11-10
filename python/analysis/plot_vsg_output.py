"""Overview of every output-side measurement of one VSG run.

Input : a decimated .mat written by matlab/vsg_output_decimate.m, either
        - matlab/validation_outputs/e12_ff_load_cycle/e12_output_decimated.mat
          (matlab/export_e12_output_overview.m, the 11 s E1.2 FF run), or
        - matlab/validation_outputs/vsg_params/results_<label>.mat (matlab/run_vsg_params.m)
Output: PNG

Run   : python -I D:/workspace/engineering/vsg-project/python/analysis/plot_vsg_output.py [in.mat out.png]
        (no arguments = the E1.2 run -> docs/figures/e12_output_overview_2026-11-10.png)
"""
from pathlib import Path
import sys

import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SRC = ROOT / 'matlab/validation_outputs/e12_ff_load_cycle/e12_output_decimated.mat'
DEFAULT_FIG = ROOT / 'docs/figures/e12_output_overview_2026-11-10.png'
PH = ('A', 'B', 'C')
COL = ('#1f77b4', '#d62728', '#2ca02c')


def scalar(d, key, default):
    return float(np.asarray(d[key]).ravel()[0]) if key in d else default


def main(src, fig_path):
    d = loadmat(src, squeeze_me=True)
    t = d['t']
    tend = float(t[-1])
    events = np.atleast_1d(np.asarray(d.get('events', []), dtype=float)).ravel()
    vnom = scalar(d, 'Vrms_set', 14 / np.sqrt(2))
    f0 = scalar(d, 'f0', 50.0)
    title = str(d['title']) if 'title' in d else Path(src).stem
    names = ['load step up', 'load step down']

    fig = plt.figure(figsize=(16, 21))
    gs = GridSpec(9, 4, figure=fig, height_ratios=[1.3, 0.6, 1.1, 1.1, 1.0, 1.1, 0.12, 0.9, 0.9],
                  hspace=0.32, wspace=0.22)
    axes = [fig.add_subplot(gs[r, :]) for r in range(6)]
    for a in axes[1:]:
        a.sharex(axes[0])

    def mark(ax, label=False):
        for k, te in enumerate(events):
            ax.axvline(te, color='0.35', ls='--', lw=0.9)
            if label:
                ax.text(te + 0.005 * tend, 0.04, names[k] if k < 2 else f'event {k + 1}',
                        transform=ax.get_xaxis_transform(), va='bottom', fontsize=9, color='0.25')

    after = t > 0.05

    ax = axes[0]
    ax.axhspan(0.9 * vnom, 1.1 * vnom, color='0.9', zorder=0, label='setpoint $\\pm$10%')
    ax.axhline(vnom, color='0.6', lw=0.8)
    for k in range(3):
        ax.plot(t, d['Vrms'][:, k], color=COL[k], lw=1.0, label=f'V{PH[k]} rms')
    ax.plot(t, d['Vpos_rms'], color='k', lw=1.3, ls='--', label='V+ (positive seq.) rms')
    ax.set_ylabel('Load voltage [V rms]')
    ax.set_ylim(0.81 * vnom, max(1.42 * vnom, 1.03 * np.max(d['Vrms'][after])))
    ax.legend(ncol=5, fontsize=9, loc='upper right')
    ax.set_title(f'{title}: all output-side measurements, 0-{tend:g} s (20 ms windows)', fontsize=12)
    mark(ax, label=True)

    ax = axes[1]
    ax.plot(t, d['V0_rms'], color='#9467bd', lw=1.0)
    ax.set_ylabel('V0 [V rms]')
    mark(ax)

    ax = axes[2]
    for k in range(3):
        ax.plot(t, d['Irms'][:, k], color=COL[k], lw=1.0, label=f'I{PH[k]} rms')
    ax.set_ylabel('Load current [A rms]')
    ax.legend(ncol=3, fontsize=9, loc='upper right')
    mark(ax)

    for ax, key, col, unit, name in ((axes[3], 'P', '#ff7f0e', 'Active power [W]', 'P'),
                                     (axes[4], 'Q', '#17becf', 'Reactive power [var]', 'Q')):
        ax.plot(t, d[f'{key}_1ms'], color=col, lw=0.5, alpha=0.45, label=f'{name} terminal, 1 ms mean')
        ax.plot(t, d[f'{key}_20ms'], color=col, lw=1.3, label=f'{name} terminal, 20 ms mean')
        ref = [d[f'{key}_20ms'][after]]
        if f'{key}_meas_int' in d:
            ax.plot(t, d[f'{key}_meas_int'], color='k', lw=1.0, ls='--', label=f'{name}_meas (controller)')
            ref.append(d[f'{key}_meas_int'][after])
        lo, hi = min(np.min(r) for r in ref), max(np.max(r) for r in ref)
        pad = 0.15 * max(hi - lo, 1.0)
        ax.set_ylim(lo - pad, hi + 2 * pad)
        ax.set_ylabel(unit)
        ax.legend(ncol=3, fontsize=9, loc='upper right')
        mark(ax)

    ax = axes[5]
    ax.plot(t, d['f_term'], color='#8c564b', lw=0.9, alpha=0.8, label='f terminal (voltage-vector angle, 20 ms)')
    span = 0.15
    if 'freq_int' in d:
        ax.plot(t, d['freq_int'], color='k', lw=1.3, label='f virtual rotor (controller)')
        span = max(span, 1.3 * np.max(np.abs(d['freq_int'][t > 0.2] - f0)))
    ax.axhline(f0, color='0.6', lw=0.8)
    ax.set_ylim(f0 - span, f0 + span)
    m = t > 0.2
    out = m & (np.abs(d['f_term'] - f0) > span)
    if np.any(out):
        ax.text(0.01, 0.04, f'terminal f off this scale for {int(out.sum())} ms in total '
                f'(voltage-angle ringing after steps): min {np.min(d["f_term"][m]):.2f} Hz, '
                f'max {np.max(d["f_term"][m]):.2f} Hz (t > 0.2 s)', transform=ax.transAxes, fontsize=9,
                color='#8c564b', bbox=dict(facecolor='white', edgecolor='none', alpha=0.85), zorder=5)
    ax.set_ylabel('Frequency [Hz]')
    ax.set_xlabel('Time [s]')
    ax.legend(ncol=2, fontsize=9, loc='upper right')
    ax.set_xlim(0, tend)
    mark(ax)
    for a in axes[:-1]:
        plt.setp(a.get_xticklabels(), visible=False)
    for a in axes:
        a.grid(alpha=0.3)

    win = np.atleast_2d(d['windows'])
    t0s = np.atleast_1d(d['window_t0']) if 'window_t0' in d else win[:, 0]
    n = min(win.shape[0], 4)
    vlim = 1.5 * vnom * np.sqrt(2)
    ilim = 1.6 * np.sqrt(2) * np.max(d['Irms'][after])
    for k in range(n):
        wt = np.atleast_1d(d[f'wt{k + 1}'])
        t0 = float(t0s[k])
        is_event = any(abs(t0 - e) < 1e-9 for e in events)
        if k == 0:
            name, xl = f'start-up 0-{1e3 * win[0, 1]:.0f} ms', 'ms'
        elif is_event:
            j = int(np.argmin(np.abs(events - t0)))
            name, xl = f'{names[j] if j < 2 else "event"} at {t0:g} s', 'ms from step'
        else:
            name, xl = f'end {win[k, 0]:g}-{win[k, 1]:g} s', f'ms from {t0:g} s'
        x = (wt - t0) * 1e3
        av = fig.add_subplot(gs[7, k])
        ai = fig.add_subplot(gs[8, k], sharex=av)
        for p in range(3):
            av.plot(x, d[f'wv{k + 1}'][:, p], color=COL[p], lw=0.8)
            ai.plot(x, d[f'wi{k + 1}'][:, p], color=COL[p], lw=0.8)
        for s in (1, -1):
            av.axhline(s * vnom * np.sqrt(2), color='0.6', lw=0.6, ls=':')
        if is_event and k > 0:
            av.axvline(0, color='0.35', ls='--', lw=0.9)
            ai.axvline(0, color='0.35', ls='--', lw=0.9)
        av.set_title(name, fontsize=10)
        av.set_ylim(-vlim, vlim)
        ai.set_ylim(-ilim, ilim)
        plt.setp(av.get_xticklabels(), visible=False)
        ai.set_xlabel(xl)
        if k == 0:
            av.set_ylabel('v_abc [V]')
            ai.set_ylabel('i_abc [A]')
        for a in (av, ai):
            a.grid(alpha=0.3)

    Path(fig_path).parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(fig_path, dpi=130, bbox_inches='tight')
    print('saved', fig_path)


if __name__ == '__main__':
    if len(sys.argv) == 3:
        main(Path(sys.argv[1]), Path(sys.argv[2]))
    elif len(sys.argv) == 1:
        main(DEFAULT_SRC, DEFAULT_FIG)
    else:
        sys.exit('usage: plot_vsg_output.py [in.mat out.png]')
