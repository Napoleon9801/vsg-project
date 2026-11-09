"""Plot the actual saved nominal Stage 5h VSG frequency, without rerunning."""
from pathlib import Path
import json
import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'python/.deps_stage5h'))
import h5py

source = ROOT / 'matlab/validation_outputs/stage5h/results_nominal.mat'
output = ROOT / 'docs/figures/stage5h_frequency_nominal_2026-11-05.png'
with h5py.File(source, 'r') as saved:
    time = np.asarray(saved['signals/freq/time']).ravel()
    frequency = np.asarray(saved['signals/freq/data']).ravel()
assert time.shape == frequency.shape
assert np.all(np.isfinite(frequency)) and np.all(np.diff(time) > 0)
assert time[0] == 0 and time[-1] == 3
peak = int(np.argmax(frequency))
plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 12,
                     'axes.spines.top': False, 'axes.spines.right': False})
fig, ax = plt.subplots(figsize=(12, 5.6), layout='constrained')
ax.plot(time, frequency, color='#1765a8', linewidth=2, label='VSG frequency')
ax.axhline(50, color='#687584', linestyle='--', linewidth=1, label='Nominal: 50 Hz')
ax.axvline(1, color='#c26a24', linestyle='--', linewidth=1.3)
ax.text(1.035, 50.205, 'Load increase\nat 1.0 s', color='#a25017', va='top')
ax.scatter([time[peak], time[-1]], [frequency[peak], frequency[-1]],
           color='#1765a8', s=32, zorder=3)
ax.annotate(f'Startup peak: {frequency[peak]:.4f} Hz',
            xy=(time[peak], frequency[peak]), xytext=(0.30, 50.175),
            arrowprops={'arrowstyle': '->', 'color': '#4c5865'}, fontsize=11)
ax.annotate(f'At 3 s: {frequency[-1]:.4f} Hz',
            xy=(time[-1], frequency[-1]), xytext=(2.02, 49.945),
            arrowprops={'arrowstyle': '->', 'color': '#4c5865'}, fontsize=11)
ax.set(xlim=(0, 3.06), ylim=(49.87, 50.225), xlabel='Time (s)',
       ylabel='Frequency (Hz)', title='Stage 5h | VSG frequency response to a load increase')
ax.grid(alpha=.20)
ax.legend(loc='upper right', frameon=False)
fig.supxlabel('Saved nominal simulation | 40 V DC | V_set = 14 V peak | f = omega / (2 pi)',
              fontsize=10, color='#4c5865')
fig.savefig(output, dpi=170)
plt.close(fig)
evidence = {'source': str(source), 'signal': 'signals.freq', 'unit': 'Hz',
            'samples': len(time), 'start_time_s': float(time[0]), 'end_time_s': float(time[-1]),
            'last_sample_Hz': float(frequency[-1]), 'maximum_Hz': float(frequency[peak]),
            'maximum_time_s': float(time[peak]), 'load_step_s': 1,
            'note': 'Saved controller frequency, not a fresh simulation or output zero-crossing estimate.'}
output.with_suffix('.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
print(output)
print(json.dumps(evidence, indent=2))
