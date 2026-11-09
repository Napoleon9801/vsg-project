"""Plot recorded Stage 5i secondary frequency restoration against Stage 5h.

The Stage 5h reference ends at its recorded 3 s endpoint. No extrapolation,
synthetic waveform or assumed final frequency is used.
"""
from pathlib import Path
import hashlib
import json
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'python/.deps_stage5h'))
import h5py

BASE = ROOT / 'matlab/validation_outputs/stage5h/results_nominal.mat'
SOURCE = ROOT / 'matlab/validation_outputs/stage5i/results_nominal.mat'
OUT = ROOT / 'docs/figures'
DATE = '2026-11-06'


def read_signal(handle, name):
    group = handle['signals'][name]
    t = np.asarray(group['time']).ravel()
    values = np.asarray(group['data']).reshape(-1)
    assert len(t) == len(values), f'{name}: expected a scalar timeseries'
    assert len(t) > 1 and np.all(np.diff(t) >= 0), name
    assert np.all(np.isfinite(t)) and np.all(np.isfinite(values)), name
    return t, values


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(8 * 1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def draw(ax, t, y, **kwargs):
    # Retain exact first/final points; decimation affects drawing only.
    indices = np.unique(np.r_[np.arange(0, len(t), max(1, len(t)//12000)), len(t)-1])
    ax.plot(t[indices], y[indices], **kwargs)


def main():
    with h5py.File(BASE, 'r') as old:
        tb, fb = read_signal(old, 'freq')
    with h5py.File(SOURCE, 'r') as current:
        t, frequency = read_signal(current, 'freq')
        tp, pref = read_signal(current, 'sec_P_ref_pu')
        td, delta = read_signal(current, 'sec_delta_P_pu')
        te, error = read_signal(current, 'sec_freq_error_Hz')
    assert tb[-1] >= 2.99 and t[-1] >= 5.99, 'Completed 3 s / 6 s records are required'
    assert np.isclose(tb[0], 0) and np.isclose(t[0], 0)

    plt.rcParams.update({'font.size': 11, 'axes.spines.top': False,
                         'axes.spines.right': False})
    fig, axes = plt.subplots(2, 1, figsize=(13.5, 8), sharex=True,
                             layout='constrained', height_ratios=[1.5, 1])
    draw(axes[0], tb, fb, color='#8b9098', linewidth=1.5,
         label=f'Stage 5h: primary control only (record ends at {tb[-1]:.1f} s)')
    draw(axes[0], t, frequency, color='#1476b8', linewidth=1.7,
         label='Stage 5i: secondary frequency control')
    axes[0].axhline(50, color='#263e34', linestyle=':', linewidth=1.1, label='50 Hz reference')
    axes[0].scatter([tb[-1], t[-1]], [fb[-1], frequency[-1]],
                    color=['#8b9098', '#1476b8'], s=28, zorder=5)
    axes[0].annotate(f'{fb[-1]:.6f} Hz at {tb[-1]:.1f} s',
                     (tb[-1], fb[-1]), xytext=(10, -24), textcoords='offset points',
                     color='#646972', fontsize=10)
    axes[0].annotate(f'{frequency[-1]:.6f} Hz at {t[-1]:.1f} s',
                     (t[-1], frequency[-1]), xytext=(-10, 16), textcoords='offset points',
                     ha='right', color='#1476b8', fontsize=10)
    axes[0].set_ylabel('Frequency (Hz)')
    axes[0].legend(loc='upper right', fontsize=9)

    draw(axes[1], td, 100 * delta, color='#a56522', linewidth=1.7,
         label='Secondary correction: 100 W base × delta P (pu)')
    axes[1].axhline(0, color='#777777', linewidth=.7)
    axes[1].annotate(f'Final correction = {100*delta[-1]:.3f} W\n'
                     f'Final P reference = {100*pref[-1]:.3f} W equivalent',
                     (td[-1], 100*delta[-1]), xytext=(-12, -36),
                     textcoords='offset points', ha='right', fontsize=10,
                     bbox={'facecolor': 'white', 'edgecolor': 'none', 'alpha': .8})
    axes[1].set(ylabel='Power-reference correction (W)', xlabel='Time (s)')
    axes[1].legend(loc='upper left', fontsize=9)
    for ax in axes:
        ax.axvline(.5, color='#668558', linestyle='--', linewidth=1,
                   label='Secondary enable at 0.5 s')
        ax.axvline(1, color='#c66050', linestyle='--', linewidth=1,
                   label='Load step at 1 s')
        ax.grid(alpha=.2)
        ax.set_xlim(0, t[-1] + .06)
    axes[0].text(.5, .02, ' enable 0.5 s', transform=axes[0].get_xaxis_transform(),
                 rotation=90, va='bottom', color='#4b6a3e', fontsize=9)
    axes[0].text(1, .02, ' load step 1 s', transform=axes[0].get_xaxis_transform(),
                 rotation=90, va='bottom', color='#a9473b', fontsize=9)
    fig.suptitle('Stage 5i | Secondary frequency restoration\n'
                 'Actual recorded simulation signals; Stage 5h comparison is available only over 0–3 s',
                 fontsize=15)
    fig.supxlabel('Correction is a controller power reference on a 100 W base, not measured load power.', fontsize=10)
    OUT.mkdir(parents=True, exist_ok=True)
    plot = OUT / f'stage5i_secondary_frequency_{DATE}.png'
    fig.savefig(plot, dpi=170)
    plt.close(fig)

    evidence = {
        'baseline_source': str(BASE), 'secondary_source': str(SOURCE),
        'baseline_sha256': digest(BASE), 'secondary_sha256': digest(SOURCE),
        'baseline_time_range_s': [float(tb[0]), float(tb[-1])],
        'secondary_time_range_s': [float(t[0]), float(t[-1])],
        'comparison_overlap_range_s': [float(max(tb[0], t[0])), float(min(tb[-1], t[-1]))],
        'baseline_extrapolated': False,
        'baseline_final_frequency_Hz': float(fb[-1]),
        'secondary_final_frequency_Hz': float(frequency[-1]),
        'secondary_final_frequency_error_Hz': float(error[-1]),
        'secondary_final_delta_P_pu': float(delta[-1]),
        'secondary_final_correction_W_equivalent': float(100*delta[-1]),
        'secondary_final_P_ref_pu': float(pref[-1]),
        'secondary_final_P_ref_W_equivalent': float(100*pref[-1]),
        'signal_sample_counts': {'baseline_freq': len(tb), 'secondary_freq': len(t),
                                 'sec_P_ref_pu': len(tp), 'sec_delta_P_pu': len(td),
                                 'sec_freq_error_Hz': len(te)},
        'plot': str(plot), 'power_base_W': 100,
        'assumed_event_times_s': {'secondary_enable': .5, 'load_step': 1},
        'scope': 'Visualization of actual saved records; no independent full hardware validation.'
    }
    report = OUT / f'stage5i_secondary_frequency_evidence_{DATE}.json'
    report.write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    print(json.dumps(evidence, indent=2))
    print(report)


if __name__ == '__main__':
    main()
