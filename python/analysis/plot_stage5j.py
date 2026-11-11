"""Stage 5j bus / PWM view of one run: bus voltage, load voltage, duty use, inductor ripple.

Input : matlab/validation_outputs/stage5j/results_<label>.mat (matlab/run_stage5j.m)
Output: PNG
Run   : python -I D:/workspace/engineering/vsg-project/python/analysis/plot_stage5j.py in.mat out.png
"""
from pathlib import Path
import sys

import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

PH = ('A', 'B', 'C')
COL = ('#1f77b4', '#d62728', '#2ca02c')


def main(src, fig_path):
    d = loadmat(src, squeeze_me=True)
    t = d['t']
    tend = float(t[-1])
    vnom = float(d['Vrms_set'])
    fsw = float(d['fsw'])
    dlim = np.asarray(d['duty_lim'], dtype=float)
    events = np.atleast_1d(np.asarray(d.get('events', []), dtype=float)).ravel()
    title = str(d['title'])

    fig, ax = plt.subplots(5, 1, figsize=(14, 17), gridspec_kw=dict(hspace=0.3))

    def mark(a):
        for te in events:
            a.axvline(te, color='0.35', ls='--', lw=0.9)

    a = ax[0]
    a.plot(t, d['Vdc_profile'], color='0.6', lw=3, label='commanded bus profile')
    a.plot(t, d['Vdc_sampled'], color='#ff7f0e', lw=1.1, label='Vdc sampled by the controller (10 kHz)')
    a.set_ylabel('DC bus [V]')
    lo, hi = float(np.min(d['Vdc_profile'])), float(np.max(d['Vdc_profile']))
    a.set_ylim(lo - 3, hi + 3)
    a.legend(loc='upper right', fontsize=9)
    a.set_title(f'{title}: bus, voltage, duty and inductor ripple', fontsize=12)
    mark(a)

    a = ax[1]
    a.axhspan(0.9 * vnom, 1.1 * vnom, color='0.9', zorder=0, label='setpoint $\\pm$10%')
    a.axhline(vnom, color='0.6', lw=0.8)
    for k in range(3):
        a.plot(t, d['Vrms'][:, k], color=COL[k], lw=1.0, label=f'V{PH[k]} rms')
    a.plot(t, d['Vpos_rms'], color='k', lw=1.3, ls='--', label='V+ rms')
    a.set_ylabel('Load voltage [V rms]')
    a.set_ylim(0, 1.45 * vnom)
    a.legend(ncol=5, loc='lower right', fontsize=9)
    mark(a)

    a = ax[2]
    a.fill_between(t, d['duty_min'], d['duty_max'], color='#9467bd', alpha=0.45, lw=0, label='duty range of the three phases (per 1 ms)')
    for v in dlim:
        a.axhline(v, color='#d62728', lw=0.9, ls=':')
    a.text(0.005, dlim[1], ' duty clamp', transform=a.get_yaxis_transform(), va='bottom', fontsize=9, color='#d62728')
    a.set_ylim(0, 1)
    a.set_ylabel('High-side duty')
    a.set_xlabel('Time [s]')
    a.legend(loc='lower right', fontsize=9)
    mark(a)
    for a in ax[:3]:
        a.set_xlim(0, tend)
        a.grid(alpha=0.3)

    tt = np.atleast_1d(d['tail_t'])
    il = np.atleast_2d(d['tail_iL'])
    x = (tt - tt[-1]) * 1e3
    a = ax[3]
    for k in range(3):
        a.plot(x, il[:, k], color=COL[k], lw=0.7, label=f'i_L {PH[k]}')
    a.set_xlim(-40, 0)
    a.set_ylabel('Inductor current [A]')
    a.set_xlabel(f'ms before the end of the run ({tend:g} s)')
    a.legend(ncol=3, loc='upper right', fontsize=9)
    a.grid(alpha=0.3)

    a = ax[4]
    k = int(np.argmax(np.max(np.abs(il), axis=0)))
    m = x >= -20
    ipk = int(np.argmax(np.abs(il[m, k])))
    xc = x[m][ipk]
    z = (x >= xc - 0.2) & (x <= xc + 0.2)
    a.plot((x[z] - xc) * 1e3, il[z, k], color=COL[k], lw=1.0, marker='.', ms=2.5)
    a.set_ylabel(f'i_L {PH[k]} [A]')
    a.set_xlabel(f'us around the current peak ({1e6 / fsw:.0f} us carrier period, solver points shown)')
    a.grid(alpha=0.3)

    Path(fig_path).parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(fig_path, dpi=130, bbox_inches='tight')
    print('saved', fig_path)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit('usage: plot_stage5j.py in.mat out.png')
    main(Path(sys.argv[1]), Path(sys.argv[2]))
