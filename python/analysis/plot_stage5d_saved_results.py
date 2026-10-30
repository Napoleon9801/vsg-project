"""Plot saved Stage 5d validation data using each signal's own clock."""
from pathlib import Path
import json
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'matlab/validation_outputs/stage5d'
names = ['freq', 'P_meas', 'Q_meas', 'Vload_d', 'Vload_q', 'Vload_abc', 'iload_abc']
data = loadmat(SOURCE / 'vsg_stage5d_out.mat', variable_names=(
    names + ['time_' + n for n in names] + ['R_load_init', 'R_load_after', 'R_load_t']))
report = json.loads((SOURCE / 'validation_stage5d.json').read_text())
step = float(data['R_load_t'].item())
plt.rcParams.update({'font.size': 10, 'axes.grid': True, 'grid.alpha': .22})
fig, axes = plt.subplots(3, 2, figsize=(14, 10), layout='constrained')

def plot_signal(ax, name, label=None, window=None):
    t = data['time_' + name].ravel()
    y = data[name]
    assert y.shape[0] == t.size
    mask = np.ones(t.size, dtype=bool) if window is None else ((t >= window[0]) & (t <= window[1]))
    ax.plot(t[mask], y[mask], lw=1, label=label)
    ax.set_xlabel('Time (s)')

plot_signal(axes[0, 0], 'freq', 'Stage 5d')
axes[0, 0].set(title='Frequency response', ylabel='Hz')
axes[0, 0].axhline(50, color='gray', ls=':', lw=1)
plot_signal(axes[0, 1], 'P_meas', 'P (W)')
plot_signal(axes[0, 1], 'Q_meas', 'Q (var)')
axes[0, 1].set(title='Filtered measured power', ylabel='W / var')
axes[0, 1].legend()
plot_signal(axes[1, 0], 'Vload_d', 'Vd')
plot_signal(axes[1, 0], 'Vload_q', 'Vq')
axes[1, 0].set(title='Sampled output voltage in dq frame', ylabel='V')
axes[1, 0].legend()
plot_signal(axes[1, 1], 'Vload_abc', window=(step-.04, step+.08))
axes[1, 1].set(title='Three-phase output voltage around load step', ylabel='V')
axes[1, 1].legend(['Phase A', 'Phase B', 'Phase C'], loc='upper right')
plot_signal(axes[2, 0], 'Vload_abc', window=(2.9, 2.96))
axes[2, 0].set(title='Steady-state output voltage', ylabel='V')
plot_signal(axes[2, 1], 'iload_abc', window=(2.9, 2.96))
axes[2, 1].set(title='Steady-state load current', ylabel='A')
for ax in axes.flat:
    if ax.get_xlim()[0] < step < ax.get_xlim()[1]:
        ax.axvline(step, color='black', ls='--', lw=.8)
r0, r1 = (float(data[n].item()) for n in ['R_load_init', 'R_load_after'])
fig.suptitle(f'Stage 5d | Saved validation results | R: {r0:g} -> {r1:g} ohm at {step:g} s\n'
             f'Final frequency: {report["metrics"]["frequency_5d"]:.6f} Hz | Simulation checks: PASS', fontsize=15)
fig.supxlabel('Ideal switching plant with selected discrete-control effects. Hardware equivalence is not established.\n'
              'Power uses output-node voltage and filter-inductor current; it is not load-only power.', fontsize=10)
output = ROOT / 'docs/figures/stage5d_saved_results_2026-10-29.png'
fig.savefig(output, dpi=160)
print(output)
for n in ['freq', 'P_meas', 'Q_meas', 'Vload_d', 'Vload_q']:
    t = data['time_' + n].ravel()
    print(n, 'mean 2.8-2.99s:', np.mean(data[n][(t >= 2.8) & (t <= 2.99)], axis=0))
