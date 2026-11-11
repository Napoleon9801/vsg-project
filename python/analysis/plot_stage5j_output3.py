"""Three output-side figures of one Stage 5j run: (1) Vrms + Irms, (2) Va + Ia waveforms, (3) frequency.

Input : matlab/validation_outputs/stage5j/results_<label>.mat (matlab/run_stage5j.m)
Output: <prefix>_vrms_irms.png, <prefix>_va_ia.png, <prefix>_frequency.png
Run   : python -I D:/workspace/engineering/vsg-project/python/analysis/plot_stage5j_output3.py [in.mat out_prefix]
        (no arguments = nominal run -> docs/figures/stage5j_nominal_*_2026-11-11.png)

Va / Ia are the raw 100 kHz windows stored in the results file (start-up, around each load
step, end of run); the full-rate 11 s waveform is not kept.
"""
from pathlib import Path
import sys

import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SRC = ROOT / 'matlab/validation_outputs/stage5j/results_nominal.mat'
DEFAULT_PREFIX = ROOT / 'docs/figures/stage5j_nominal'
SUFFIX = '_2026-11-11.png'
PH = ('A', 'B', 'C')
COL = ('#1f77b4', '#d62728', '#2ca02c')
EVENT_NAMES = ('load 70 -> 100 W', 'load 100 -> 70 W')


def main(src, prefix, suffix='.png'):
    d = loadmat(src, squeeze_me=True)
    t = d['t']
    tend = float(np.round(t[-1], 6))
    vnom = float(d['Vrms_set'])
    f0 = float(d['f0'])
    events = np.atleast_1d(np.asarray(d.get('events', []), dtype=float)).ravel()
    title = str(d['title'])

    def mark(ax, label=False):
        for k, te in enumerate(events):
            ax.axvline(te, color='0.35', ls='--', lw=0.9)
            if label:
                ax.text(te + 0.006 * tend, 0.04, EVENT_NAMES[k] if k < 2 else f'event {k + 1}',
                        transform=ax.get_xaxis_transform(), va='bottom', fontsize=9, color='0.25')

    # ---- 1. Vrms + Irms
    fig, (av, ai) = plt.subplots(2, 1, figsize=(13, 7.5), sharex=True, gridspec_kw=dict(hspace=0.12))
    av.axhspan(0.9 * vnom, 1.1 * vnom, color='0.9', zorder=0, label='setpoint $\\pm$10%')
    av.axhline(vnom, color='0.55', lw=0.8, label=f'setpoint {vnom:g} V')
    for k in range(3):
        av.plot(t, d['Vrms'][:, k], color=COL[k], lw=1.1, label=f'V{PH[k]} rms')
        ai.plot(t, d['Irms'][:, k], color=COL[k], lw=1.1, label=f'I{PH[k]} rms')
    av.set_ylim(0, 1.3 * vnom)
    av.set_ylabel('Load phase voltage [V rms]')
    av.legend(ncol=5, loc='lower right', fontsize=9)
    av.set_title(f'{title}\nOutput voltage and current, rms over a 20 ms sliding window', fontsize=11)
    ai.set_ylim(0, 1.25 * float(np.max(d['Irms'])))
    ai.set_ylabel('Load current [A rms]')
    ai.set_xlabel('Time [s]')
    ai.legend(ncol=3, loc='upper left', fontsize=9)
    ai.set_xlim(0, tend)
    mark(av)
    mark(ai, label=True)
    edges = np.unique(np.concatenate(([0.0], events, [tend])))
    for a, b in zip(edges[:-1], edges[1:]):
        m = (t >= a + 0.6 * (b - a)) & (t <= b)
        xm = 0.5 * (a + b)
        av.text(xm, 1.115 * vnom, f'{np.mean(d["Vrms"][m]):.2f} V', ha='center', va='bottom', fontsize=10)
        ai.text(xm, np.mean(d['Irms'][m]) + 0.06 * float(np.max(d['Irms'])), f'{np.mean(d["Irms"][m]):.2f} A',
                ha='center', va='bottom', fontsize=10)
    for a in (av, ai):
        a.grid(alpha=0.3)
    out1 = Path(f'{prefix}_vrms_irms{suffix}')
    fig.savefig(out1, dpi=140, bbox_inches='tight')
    plt.close(fig)

    # ---- 2. Va + Ia raw windows
    win = np.atleast_2d(d['windows'])
    t0s = np.atleast_1d(d['window_t0'])
    n = win.shape[0]
    vlim = 1.45 * vnom * np.sqrt(2)
    ilim = 1.25 * max(float(np.max(np.abs(np.atleast_2d(d[f'wi{k + 1}'])[:, 0]))) for k in range(n))
    fig, axs = plt.subplots(2, n, figsize=(4.1 * n, 6.2), sharex='col', gridspec_kw=dict(hspace=0.1, wspace=0.16))
    axs = np.atleast_2d(axs).reshape(2, n)
    for k in range(n):
        wt = np.atleast_1d(d[f'wt{k + 1}'])
        va = np.atleast_2d(d[f'wv{k + 1}'])[:, 0]
        ia = np.atleast_2d(d[f'wi{k + 1}'])[:, 0]
        t0 = float(t0s[k])
        is_event = any(abs(t0 - e) < 1e-9 for e in events)
        if k == 0:
            name, xl = 'start-up (soft-start)', 'ms'
        elif is_event:
            j = int(np.argmin(np.abs(events - t0)))
            name, xl = f'{EVENT_NAMES[j] if j < 2 else "event"} at {t0:g} s', 'ms from the load step'
        else:
            name, xl = f'steady state, end of run', f'ms from {t0:g} s'
        x = (wt - t0) * 1e3
        a_v, a_i = axs[0, k], axs[1, k]
        a_v.plot(x, va, color=COL[0], lw=0.9)
        a_i.plot(x, ia, color='#ff7f0e', lw=0.9)
        for s in (1, -1):
            a_v.axhline(s * vnom * np.sqrt(2), color='0.55', lw=0.7, ls=':')
        if is_event:
            a_v.axvline(0, color='0.35', ls='--', lw=0.9)
            a_i.axvline(0, color='0.35', ls='--', lw=0.9)
        a_v.set_title(name, fontsize=10)
        a_v.set_ylim(-vlim, vlim)
        a_i.set_ylim(-ilim, ilim)
        a_i.set_xlabel(xl)
        if k == 0:
            a_v.set_ylabel('Va, load phase A to N [V]')
            a_i.set_ylabel('Ia, load current [A]')
        else:
            plt.setp(a_v.get_yticklabels(), visible=False)
            plt.setp(a_i.get_yticklabels(), visible=False)
        for a in (a_v, a_i):
            a.grid(alpha=0.3)
    fig.suptitle(f'{title}\nPhase A output voltage and current waveforms (dotted: setpoint peak $\\pm${vnom * np.sqrt(2):.2f} V)',
                 fontsize=11, y=1.0)
    out2 = Path(f'{prefix}_va_ia{suffix}')
    fig.savefig(out2, dpi=140, bbox_inches='tight')
    plt.close(fig)

    # ---- 3. frequency
    fig, ax = plt.subplots(figsize=(13, 5))
    fr = d['freq_int']
    ok = np.isfinite(fr)
    ax.axhspan(f0 - 0.005, f0 + 0.005, color='#2ca02c', alpha=0.15, zorder=0, label=f'{f0:g} $\\pm$ 0.005 Hz')
    ax.axhline(f0, color='0.55', lw=0.8)
    ax.plot(t, d['f_term'], color='#8c564b', lw=0.6, alpha=0.55, label='terminal frequency (load-voltage vector angle, 20 ms)')
    ax.plot(t[ok], fr[ok], color='k', lw=1.5, label='virtual rotor frequency (controller)')
    m = ok & (t > 0.3)
    span = 1.35 * float(np.max(np.abs(fr[m] - f0)))
    ax.set_ylim(f0 - span, f0 + span)
    for k, te in enumerate(events):
        w = ok & (t > te) & (t <= te + 1.0)
        i = int(np.argmax(np.abs(fr[w] - f0)))
        tv, fv = t[w][i], fr[w][i]
        ax.annotate(f'{fv:.3f} Hz', xy=(tv, fv), xytext=(tv + 0.35, fv + (0.012 if fv > f0 else -0.012)),
                    fontsize=10, va='center', arrowprops=dict(arrowstyle='-', color='0.3', lw=0.8))
    early = ok & (t <= 0.3)
    if np.any(early) and np.max(fr[early]) > f0 + span:
        ax.text(0.03, 0.9, f'start-up: rotor peak {np.max(fr[early]):.3f} Hz (off scale)', transform=ax.transAxes,
                fontsize=9, color='0.2', bbox=dict(facecolor='white', edgecolor='none', alpha=0.85), zorder=5)
    ax.set_xlim(0, tend)
    ax.set_xlabel('Time [s]')
    ax.set_ylabel('Frequency [Hz]')
    ax.set_title(f'{title}\nFrequency with secondary restoration', fontsize=11)
    ax.legend(ncol=3, loc='upper right', fontsize=9)
    mark(ax, label=True)
    ax.grid(alpha=0.3)
    out3 = Path(f'{prefix}_frequency{suffix}')
    fig.savefig(out3, dpi=140, bbox_inches='tight')
    plt.close(fig)
    for o in (out1, out2, out3):
        print('saved', o)


if __name__ == '__main__':
    if len(sys.argv) == 3:
        main(Path(sys.argv[1]), sys.argv[2])
    elif len(sys.argv) == 1:
        main(DEFAULT_SRC, DEFAULT_PREFIX, SUFFIX)
    else:
        sys.exit('usage: plot_stage5j_output3.py [in.mat out_prefix]')
