"""E1.2 — test the breaker-staggering / unbalance hypothesis for the worst-phase excursions.

Load per phase (Gate_Driver_and_MOSFET_Circuit): Load_RL (2.058 ohm + 1 mH) in series
with Load_Extra_R (0.882 ohm) bypassed by an SPS Breaker (Ron 1 mohm, External control).
SPS Breaker closes on command and opens at the next current zero of its own phase.
Cf star and load star share N_AC, which floats w.r.t. DC- (measurement only).

1. Per-phase switching instant: residual r = (v - 2.058*i - 1e-3*di/dt)/i is the
   voltage per amp across the bypassed resistor: ~0.882 (bypass open) or ~0.001 (closed).
2. Sliding one-cycle (20 ms) 50 Hz DFT of va, vb, vc -> V+, V-, V0 (RMS) around events.
   If the positive-sequence magnitude stays inside the band while single phases exceed
   it, the excursion is unbalance that a positive-sequence dq controller cannot regulate.
   NOTE: the one-cycle DFT treats the moving rotor frequency (49.9-50.1 Hz) as 50 Hz;
   leakage at that offset is < 0.5 % and is reported as a bound, not removed.

Run: python D:\\workspace\\engineering\\vsg-project\\python\\analysis\\e12_breaker_check.py
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

ROOT = lc.ROOT
RUNS = {
    'baseline': ROOT / 'matlab/validation_outputs/stage5i_load_cycle/results_nominal.mat',
    'e12_ff': ROOT / 'matlab/validation_outputs/e12_ff_load_cycle/results_nominal_ff1.mat',
}
OUT = ROOT / 'matlab/validation_outputs/e12_ff_load_cycle/e12_breaker_check.json'
FIG = ROOT / 'docs/figures/e12_breaker_sequence_2026-11-10.png'
R_MAIN, L_LOAD, R_EXTRA = 2.058, 1e-3, 0.882
DT = 5e-6
V_NOM = 14 / np.sqrt(2)
A = np.exp(2j * np.pi / 3)


def window(h, t0, t1):
    t = lc.times(h, 'Vload_abc')
    n = len(t)
    k0, k1 = np.searchsorted(t, t0), np.searchsorted(t, t1)
    v = lc.samples(h['signals/Vload_abc/data'], k0, k1, n)
    i = lc.samples(h['signals/iload_abc/data'], k0, k1, n)
    return t[k0:k1], v, i


def switching_instants(t, v, i, event):
    didt = np.gradient(i, DT, axis=0)
    r = (v - R_MAIN * i - L_LOAD * didt) / np.where(np.abs(i) > 0.5, i, np.nan)
    out = []
    for ph in range(3):
        valid = np.isfinite(r[:, ph]) & (t >= event - 0.005)
        # state: 1 = extra R in circuit (bypass open), 0 = bypassed
        state = (r[:, ph] > R_EXTRA / 2).astype(float)
        idx = np.flatnonzero(valid)
        before = np.median(state[idx[t[idx] < event]])
        chg = idx[(t[idx] >= event) & (state[idx] != before)]
        if len(chg):
            # last valid sample still in the old state, then first in the new state
            k = chg[0]
            prev = idx[idx < k][-1]
            t_sw = 0.5 * (t[prev] + t[k])
            out.append({'phase': 'ABC'[ph], 'state_before': 'extra_R_in' if before else 'bypassed',
                        'switch_time_s': float(t_sw), 'delay_ms': float((t_sw - event) * 1e3),
                        'resolution_ms': float((t[k] - t[prev]) * 1e3),
                        'i_at_switch_A': float(i[k, ph])})
        else:
            out.append({'phase': 'ABC'[ph], 'switch_time_s': None})
    return out


def sequences(t, v, tq):
    n = int(round(0.02 / DT))
    w = np.exp(-2j * np.pi * 50 * t)
    res = []
    for tt in tq:
        k1 = np.searchsorted(t, tt)
        k0 = k1 - n
        ph = 2 * np.sum(v[k0:k1] * w[k0:k1, None], axis=0) / n / np.sqrt(2)   # RMS phasors
        va, vb, vc = ph
        vp = (va + A * vb + A * A * vc) / 3
        vn = (va + A * A * vb + A * vc) / 3
        v0 = (va + vb + vc) / 3
        rms = np.sqrt(np.mean(v[k0:k1] ** 2, axis=0))
        res.append([tt, abs(vp), abs(vn), abs(v0), *rms])
    return np.array(res)


def main():
    result = {}
    seqs = {}
    for name, path in RUNS.items():
        with h5py.File(path, 'r') as h:
            r = {}
            for ev in (3, 7):
                t, v, i = window(h, ev - 0.03, ev + 0.2)
                r[f'switching_{ev}s'] = switching_instants(t, v, i, ev)
                tq = np.arange(ev - 0.005, ev + 0.15, 0.0005)
                s = sequences(t, v, tq)
                seqs[(name, ev)] = s
                after = s[:, 0] >= ev
                r[f'sequence_{ev}s'] = {
                    'pos_seq_rms_min_max_V': [float(s[after, 1].min()), float(s[after, 1].max())],
                    'neg_seq_rms_max_V': float(s[after, 2].max()),
                    'neg_seq_max_time_s': float(s[after, 0][np.argmax(s[after, 2])]),
                    'zero_seq_rms_max_V': float(s[after, 3].max()),
                    'neg_seq_pre_event_V': float(s[~after, 2].max()),
                    'phase_rms_min_max_V': [float(s[after, 4:].min()), float(s[after, 4:].max())],
                    'pos_seq_within_pm10pct': bool(s[after, 1].min() >= 0.9 * V_NOM and s[after, 1].max() <= 1.1 * V_NOM),
                }
            result[name] = r
    result['dft_leakage_note'] = 'one-cycle 50 Hz DFT; rotor frequency 49.9-50.1 Hz gives < 0.5 % leakage between sequences'
    OUT.write_text(json.dumps(result, indent=2), encoding='utf-8')

    fig, axs = plt.subplots(2, 2, figsize=(13, 7.5), sharex='col', layout='constrained')
    for col, ev in enumerate((3, 7)):
        for name, ls in (('baseline', '--'), ('e12_ff', '-')):
            s = seqs[(name, ev)]
            axs[0, col].plot(s[:, 0], s[:, 1], 'k' + ls, lw=1.3, label=f'{name}: V+ (pos. seq.)')
            for p, c in zip(range(3), lc.COLORS):
                if name == 'e12_ff':
                    axs[0, col].plot(s[:, 0], s[:, 4 + p], color=c, lw=1, label=f'e12_ff: phase {"ABC"[p]} RMS')
            axs[1, col].plot(s[:, 0], s[:, 2], color='#b33a3a', ls=ls, lw=1.3, label=f'{name}: V- (neg. seq.)')
            axs[1, col].plot(s[:, 0], s[:, 3], color='#666666', ls=ls, lw=1.0, label=f'{name}: V0 (zero seq.)')
        for f in (0.9, 1.1):
            axs[0, col].axhline(V_NOM * f, color='#555555', lw=.7, ls=':')
        for sw in result['e12_ff'][f'switching_{ev}s']:
            if sw.get('switch_time_s'):
                for ax in axs[:, col]:
                    ax.axvline(sw['switch_time_s'], color='#999999', lw=.6)
        axs[0, col].set(title=f'{"Load increase" if ev == 3 else "Load return"} at {ev} s | 20 ms window', ylabel='V RMS (V)')
        axs[1, col].set(ylabel='V RMS (V)', xlabel='Time (s) — grey lines: per-phase breaker switching (FF run)')
        for ax in axs[:, col]:
            ax.grid(alpha=.25)
    axs[0, 0].legend(fontsize=8, ncol=2)
    axs[1, 0].legend(fontsize=8)
    fig.suptitle('E1.2 breaker check | positive / negative / zero sequence of load phase voltages', fontsize=13)
    fig.savefig(FIG, dpi=150)
    plt.close(fig)
    result['figure'] = str(FIG)
    OUT.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
