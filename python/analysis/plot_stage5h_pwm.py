"""Display all six recorded MOSFET gate commands; do not simulate or synthesize PWM."""
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

SOURCE = ROOT / 'matlab/validation_outputs/stage5h/results_nominal.mat'
OUT = ROOT / 'docs/figures'
with h5py.File(SOURCE, 'r') as f:
    time = np.asarray(f['signals/gates_6/time']).ravel()
    gates = np.asarray(f['signals/gates_6/data']).T
assert gates.shape == (time.size, 6)
assert np.all(np.isin(gates, [0, 1]))
assert np.all(np.diff(time) >= 0)
names = ['A HIGH (AH)', 'A LOW (AL)', 'B HIGH (BH)', 'B LOW (BL)', 'C HIGH (CH)', 'C LOW (CL)']
colors = ['#1476b8', '#db6c27', '#19846b', '#b88616', '#7956aa', '#c34372']
start, end = 2.9, 2.9005
lo = max(0, np.searchsorted(time, start, side='left') - 1)
hi = min(len(time), np.searchsorted(time, end, side='right') + 1)
plt.rcParams.update({'font.size': 11, 'axes.spines.top': False, 'axes.spines.right': False})
fig, axes = plt.subplots(6, 1, figsize=(14, 9), sharex=True, layout='constrained')
for k, ax in enumerate(axes):
    ax.step((time[lo:hi] - start)*1e6, gates[lo:hi, k], where='post', color=colors[k], lw=1.4)
    ax.set(ylim=(-.15, 1.22), yticks=[0, 1], ylabel=names[k])
    ax.grid(axis='x', alpha=.3)
    ax.set_xlim(0, 500)
axes[-1].set_xlabel('Time from 2.900000 s (us)')
fig.suptitle('Stage 5h | Actual recorded gate commands for all six MOSFETs\n10 kHz carrier | Same 500 us window for every device', fontsize=16)
fig.supxlabel('1 = gate ON command; 0 = gate OFF command. These are logic commands, not measured Vgs.', fontsize=10)
full = OUT / 'stage5h_pwm_all_six_2026-10-30.png'
fig.savefig(full, dpi=160)

fig2, axes2 = plt.subplots(3, 1, figsize=(12, 8), sharex=True, layout='constrained')
details = []
for phase, ax in enumerate(axes2):
    high, low = 2*phase, 2*phase+1
    falls = np.flatnonzero(np.diff(gates[:, low].astype(int)) == -1) + 1
    falling = falls[np.flatnonzero(time[falls] >= start)[0]]
    t0 = time[falling]
    rises = np.flatnonzero(np.diff(gates[:, high].astype(int)) == 1) + 1
    rising = rises[np.flatnonzero(time[rises] >= t0)[0]]
    delay_us = (time[rising] - t0)*1e6
    a = max(0, np.searchsorted(time, t0-1e-6) - 1)
    b = min(len(time), np.searchsorted(time, t0+2e-6, side='right') + 1)
    for k in [high, low]:
        ax.step((time[a:b]-t0)*1e6, gates[a:b, k], where='post', label=names[k], color=colors[k], lw=1.6)
    ax.axvspan(0, delay_us, color='#dfeee3', alpha=.7)
    ax.text(delay_us/2, .48, f'{delay_us:.3f} us\nboth OFF', ha='center', va='center', fontsize=11)
    ax.set(ylim=(-.15, 1.25), yticks=[0, 1], ylabel='Gate logic', xlim=(-.5, 1.5),
           title=f'Phase {"ABC"[phase]} | lower turn-off at t = {t0:.9f} s')
    ax.legend(loc='upper right', fontsize=9)
    ax.grid(alpha=.2)
    details.append({'phase': 'ABC'[phase], 'lower_off_time_s': float(t0), 'upper_on_time_s': float(time[rising]), 'deadtime_us': float(delay_us)})
axes2[-1].set_xlabel('Time relative to each phase\'s lower-gate turn-off (us)')
fig2.suptitle('Stage 5h | Dead time in each upper/lower pair\nEach panel is aligned to its own switching event', fontsize=15)
zoom = OUT / 'stage5h_pwm_deadtime_abc_2026-10-30.png'
fig2.savefig(zoom, dpi=160)
overlap = np.sum((gates[:, ::2] > 0) & (gates[:, 1::2] > 0), axis=0)
evidence = {'source': str(SOURCE), 'signal': 'signals.gates_6', 'gate_order': names,
            'view_start_s': start, 'view_end_s': end, 'samples_in_source': int(time.size),
            'overlap_samples_ABC_full_run': overlap.tolist(), 'deadtime_examples': details}
(OUT / 'stage5h_pwm_plot_evidence_2026-10-30.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
print(full)
print(zoom)
print(json.dumps(evidence, indent=2))
