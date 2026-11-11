"""Four output-side figures of the Stage 5j nominal run, each with zooms on the load steps.

  1. <prefix>_vrms_zoom      phase Vrms (20 ms window), full run + zoom at each load step
  2. <prefix>_vphase_zoom    phase voltages va/vb/vc, zoom at each load step only
  3. <prefix>_irms_zoom      phase Irms (20 ms window), full run + zoom at each load step
  4. <prefix>_freq_split     virtual-rotor frequency and terminal (output) frequency, separate axes

Input : matlab/validation_outputs/stage5j/results_<label>.mat   (1 ms grid, run_stage5j.m)
        matlab/validation_outputs/stage5j/wave_<label>.mat      (full-length Vload_abc, run_stage5j 'save_wave')
Run   : python -I D:/workspace/engineering/vsg-project/python/analysis/plot_stage5j_output4.py [results.mat wave.mat out_prefix]
        no arguments = nominal_wave run -> docs/figures/stage5j_nominal_*_2026-11-11.png
"""
from pathlib import Path
import sys

import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'matlab/validation_outputs/stage5j'
DEFAULT = (OUT / 'results_nominal_wave.mat', OUT / 'wave_nominal_wave.mat', ROOT / 'docs/figures/stage5j_nominal')
SUFFIX = '_2026-11-11.png'
PH = ('A', 'B', 'C')
COL = ('#1f77b4', '#d62728', '#2ca02c')
EVENT_NAMES = ('load 70 -> 100 W', 'load 100 -> 70 W')
RMS_ZOOM = (-0.05, 0.25)    # s around each step, rms plots
WAVE_ZOOM = (-0.04, 0.10)   # s around each step, phase-voltage plot


def event_name(k, te):
    return f'{EVENT_NAMES[k] if k < len(EVENT_NAMES) else "event"} at {te:g} s'


def grid_full_plus_zooms(n_ev, title):
    fig = plt.figure(figsize=(13, 8.2))
    gs = fig.add_gridspec(2, n_ev, height_ratios=(1.0, 1.0), hspace=0.32, wspace=0.12)
    ax_full = fig.add_subplot(gs[0, :])
    ax_z = [fig.add_subplot(gs[1, k]) for k in range(n_ev)]
    fig.suptitle(title, fontsize=11, y=0.985)
    return fig, ax_full, ax_z


def shade_zoom(ax, events, zoom):
    for te in events:
        ax.axvspan(te + zoom[0], te + zoom[1], color='#ffbf00', alpha=0.25, zorder=0)


def mark(ax, events, label=False, tend=None):
    for k, te in enumerate(events):
        ax.axvline(te, color='0.35', ls='--', lw=0.9)
        if label:
            ax.text(te + 0.006 * tend, 0.04, EVENT_NAMES[k] if k < len(EVENT_NAMES) else f'event {k + 1}',
                    transform=ax.get_xaxis_transform(), va='bottom', fontsize=9, color='0.25')


def rms_figure(t, Y, events, tend, vnom, kind, title, out):
    is_v = kind == 'V'
    unit = 'V' if is_v else 'A'
    fig, ax, az = grid_full_plus_zooms(len(events), title)
    if is_v:
        ax.axhspan(0.9 * vnom, 1.1 * vnom, color='0.9', zorder=0, label='setpoint $\\pm$10%')
        ax.axhline(vnom, color='0.55', lw=0.8, label=f'setpoint {vnom:g} V')
    for k in range(3):
        ax.plot(t, Y[:, k], color=COL[k], lw=1.1, label=f'{kind}{PH[k]} rms')
    ymax = 1.3 * vnom if is_v else 1.25 * float(np.max(Y))
    ax.set_ylim(0, ymax)
    ax.set_xlim(0, tend)
    ax.set_xlabel('Time [s]')
    ax.set_ylabel(f'{"Load phase voltage" if is_v else "Load current"} [{unit} rms]')
    shade_zoom(ax, events, RMS_ZOOM)
    mark(ax, events, label=True, tend=tend)
    edges = np.unique(np.concatenate(([0.0], events, [tend])))
    for a, b in zip(edges[:-1], edges[1:]):
        m = (t >= a + 0.6 * (b - a)) & (t <= b)
        yv = float(np.mean(Y[m]))
        ax.text(0.5 * (a + b), (1.115 * vnom) if is_v else yv + 0.06 * float(np.max(Y)),
                f'{yv:.2f} {unit}', ha='center', va='bottom', fontsize=10)
    ax.legend(ncol=5 if is_v else 3, loc='center right' if is_v else 'upper left', fontsize=9)
    ax.grid(alpha=0.3)

    for j, (a, te) in enumerate(zip(az, events)):
        m = (t >= te + RMS_ZOOM[0]) & (t <= te + RMS_ZOOM[1])
        x = (t[m] - te) * 1e3
        if is_v:
            a.axhspan(0.9 * vnom, 1.1 * vnom, color='0.9', zorder=0)
            a.axhline(vnom, color='0.55', lw=0.8)
        for k in range(3):
            a.plot(x, Y[m, k], color=COL[k], lw=1.3, label=f'{kind}{PH[k]}')
        a.axvline(0, color='0.35', ls='--', lw=0.9)
        seg = Y[(t > te) & (t <= te + RMS_ZOOM[1])]
        lo, hi = float(np.min(seg)), float(np.max(seg))
        if is_v:
            txt = (f'min {lo:.2f} V ({100 * (lo / vnom - 1):+.1f} %)\n'
                   f'max {hi:.2f} V ({100 * (hi / vnom - 1):+.1f} %)')
            a.set_ylim(min(0.8 * vnom, lo - 0.3), max(1.2 * vnom, hi + 0.3))
        else:
            pre = Y[(t >= te - 0.05) & (t < te)].mean()
            post = Y[(t >= te + RMS_ZOOM[1] - 0.05) & (t <= te + RMS_ZOOM[1])].mean()
            txt = f'before {pre:.2f} A -> after {post:.2f} A\nmin {lo:.2f} A, max {hi:.2f} A'
            pad = 0.15 * (hi - lo)
            a.set_ylim(lo - pad, hi + pad)
        a.text(0.98, 0.04 if j == 0 or not is_v else 0.04, txt, transform=a.transAxes, ha='right', va='bottom',
               fontsize=9, bbox=dict(facecolor='white', edgecolor='0.7', alpha=0.9))
        a.set_title(f'Zoom: {event_name(j, te)}', fontsize=10)
        a.set_xlabel('ms from the load step')
        a.set_xlim(RMS_ZOOM[0] * 1e3, RMS_ZOOM[1] * 1e3)
        if j == 0:
            a.set_ylabel(f'[{unit} rms]')
            a.legend(ncol=3, loc='upper right', fontsize=8)
        a.grid(alpha=0.3)
    fig.savefig(out, dpi=140, bbox_inches='tight')
    plt.close(fig)
    return out


def vphase_figure(W, events, tend, vnom, title, out):
    t = np.asarray(W['t']).ravel()
    V = np.atleast_2d(W['Vload_abc'])
    vpk = vnom * np.sqrt(2)
    fig, az = plt.subplots(1, len(events), figsize=(13, 4.6), sharey=True, gridspec_kw=dict(wspace=0.08))
    az = np.atleast_1d(az)
    fig.suptitle(title, fontsize=11, y=1.02)
    for j, (a, te) in enumerate(zip(az, events)):
        m = (t >= te + WAVE_ZOOM[0]) & (t <= te + WAVE_ZOOM[1])
        x = (t[m] - te) * 1e3
        for k in range(3):
            a.plot(x, V[m, k], color=COL[k], lw=0.9, label=f'v{PH[k].lower()}N')
        for s in (1, -1):
            a.axhline(s * vpk, color='k', lw=0.8, ls=':')
        a.axvline(0, color='0.35', ls='--', lw=0.9)
        post = V[(t > te) & (t <= te + WAVE_ZOOM[1])]
        pk = float(np.max(np.abs(post)))
        a.text(0.98, 0.03, f'max |v| after step {pk:.2f} V ({100 * (pk / vpk - 1):+.1f} % of {vpk:.2f} V)',
               transform=a.transAxes, ha='right', va='bottom', fontsize=9,
               bbox=dict(facecolor='white', edgecolor='0.7', alpha=0.9))
        a.set_ylim(-1.45 * vpk, 1.45 * vpk)
        a.set_xlim(WAVE_ZOOM[0] * 1e3, WAVE_ZOOM[1] * 1e3)
        a.set_title(f'Zoom: {event_name(j, te)}', fontsize=10)
        a.set_xlabel('ms from the load step')
        if j == 0:
            a.set_ylabel('Load phase-to-neutral voltage [V]')
            a.legend(ncol=3, loc='upper right', fontsize=8)
        a.grid(alpha=0.3)
    fig.savefig(out, dpi=140, bbox_inches='tight')
    plt.close(fig)
    return out


def freq_figure(d, events, tend, f0, title, out):
    t = d['t']
    fr = d['freq_int']
    ft = d['f_term']
    fig, axs = plt.subplots(2, 1, figsize=(13, 8), sharex=True, gridspec_kw=dict(hspace=0.3))
    series = ((fr, 'k', 1.5, 'virtual rotor frequency'),
              (ft, '#8c564b', 0.9, 'output frequency (load-voltage vector angle)'))
    for a, (y, c, lw, name) in zip(axs, series):
        ok = np.isfinite(y)
        a.axhspan(f0 - 0.005, f0 + 0.005, color='#2ca02c', alpha=0.15, zorder=0, label=f'{f0:g} $\\pm$ 0.005 Hz')
        a.axhline(f0, color='0.55', lw=0.8)
        a.plot(t[ok], y[ok], color=c, lw=lw, label=name)
        m = ok & (t > 0.3)
        span = 1.35 * float(np.max(np.abs(y[m] - f0)))
        a.set_ylim(f0 - span, f0 + span)
        for k, te in enumerate(events):
            w = ok & (t > te) & (t <= te + 1.0)
            i = int(np.argmax(np.abs(y[w] - f0)))
            tv, fv = t[w][i], y[w][i]
            a.plot(tv, fv, 'o', ms=5, mfc='none', mec='#ff7f0e', mew=1.5, zorder=6)
            up = fv > f0
            a.text(tv + (0.12 if up else -0.12), fv, f'{"peak" if up else "dip"} {fv:.4f} Hz', fontsize=10, va='center',
                   ha='left' if up else 'right',
                   bbox=dict(facecolor='white', edgecolor='0.7', alpha=0.9), zorder=6)
        early = ok & (t <= 0.3)
        if np.any(early) and np.max(np.abs(y[early] - f0)) > span:
            pk = y[early][int(np.argmax(np.abs(y[early] - f0)))]
            a.text(0.015, 0.93, f'start-up transient (t < 0.3 s) off scale, peak {pk:.3f} Hz', transform=a.transAxes, va='top',
                   fontsize=9, color='0.2', bbox=dict(facecolor='white', edgecolor='none', alpha=0.85), zorder=5)
        seg = ok & (t > tend - 1.0)
        a.text(0.985, 0.06, f'mean last 1 s: {np.mean(y[seg]):.4f} Hz', transform=a.transAxes, ha='right',
               fontsize=9, bbox=dict(facecolor='white', edgecolor='none', alpha=0.85), zorder=5)
        a.set_ylabel('Frequency [Hz]')
        a.legend(ncol=2, loc='lower right', bbox_to_anchor=(1.0, 1.0), fontsize=9, frameon=False)
        mark(a, events, label=True, tend=tend)
        a.grid(alpha=0.3)
    axs[0].set_title('(a) Virtual rotor frequency', fontsize=10, loc='left')
    axs[1].set_title('(b) Output frequency at the load terminals (20 ms average)', fontsize=10, loc='left')
    axs[1].set_xlim(0, tend)
    axs[1].set_xlabel('Time [s]')
    fig.suptitle(f'{title}\nFrequency with secondary restoration', fontsize=11, y=0.98)
    fig.savefig(out, dpi=140, bbox_inches='tight')
    plt.close(fig)
    return out


def main(src, wave, prefix, suffix='.png'):
    d = loadmat(src, squeeze_me=True)
    t = d['t']
    tend = float(np.round(t[-1], 6))
    vnom = float(d['Vrms_set'])
    f0 = float(d['f0'])
    events = np.atleast_1d(np.asarray(d.get('events', []), dtype=float)).ravel()
    title = str(d['title'])
    outs = [
        rms_figure(t, d['Vrms'], events, tend, vnom, 'V',
                   f'{title}\nOutput phase voltage, rms over a 20 ms sliding window', Path(f'{prefix}_vrms_zoom{suffix}')),
        rms_figure(t, d['Irms'], events, tend, vnom, 'I',
                   f'{title}\nOutput phase current, rms over a 20 ms sliding window', Path(f'{prefix}_irms_zoom{suffix}')),
        freq_figure(d, events, tend, f0, title, Path(f'{prefix}_freq_split{suffix}')),
    ]
    if wave is not None and Path(wave).exists():
        W = loadmat(wave, squeeze_me=True)
        outs.append(vphase_figure(W, events, tend, vnom,
                                  f'{title}\nOutput phase voltages (dotted: setpoint peak $\\pm${vnom * np.sqrt(2):.2f} V)',
                                  Path(f'{prefix}_vphase_zoom{suffix}')))
    else:
        print('wave file missing, phase-voltage figure skipped:', wave)
    for o in outs:
        print('saved', o)


if __name__ == '__main__':
    if len(sys.argv) == 4:
        main(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
    elif len(sys.argv) == 1:
        main(*DEFAULT, SUFFIX)
    else:
        sys.exit('usage: plot_stage5j_output4.py [results.mat wave.mat out_prefix]')
