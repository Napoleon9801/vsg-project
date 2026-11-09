"""Measured load P, virtual-rotor f and terminal RMS for the Stage 5i load cycle.

Integrates recorded waveforms in bounded-memory chunks. The memory-bounded
runner logs voltage/current every 5 us. Each interval
uses the exact product integral of its piecewise-linear voltage/current traces.
"""
from pathlib import Path
import argparse
import hashlib
import json
import sys

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy.io import savemat
from scipy.integrate import trapezoid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'python/.deps_stage5h'))
import h5py

FOLDER = ROOT / 'matlab/validation_outputs/stage5i_load_cycle'
FIGURES = ROOT / 'docs/figures'
DATE = '2026-11-06'
WINDOW = .020
COLORS = ['#1476b8', '#df7e22', '#259660']


def digest(path):
    sha = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            sha.update(chunk)
    return sha.hexdigest()


def samples(dataset, start, stop, n):
    if dataset.shape[-1] == n:
        return np.asarray(dataset[:, start:stop]).T
    assert dataset.shape[0] == n, dataset.shape
    return np.asarray(dataset[start:stop, :])


def times(handle, name):
    return np.asarray(handle[f'signals/{name}/time']).ravel()


def scalar(handle, name):
    t = times(handle, name)
    y = np.asarray(handle[f'signals/{name}/data']).ravel()
    assert len(t) == len(y) and np.all(np.isfinite(y)), name
    assert np.all(np.diff(t) >= 0), name
    return t, y


def products(a, b):
    """Seven channels: Va²,Vb²,Vc²,Ia²,Ib²,Ic²,sum(Vphase*Iphase)."""
    return np.column_stack((a[:, :3] * b[:, :3], a[:, 3:] * b[:, 3:],
                            np.sum(a[:, :3] * b[:, 3:], axis=1)))


def integrate_queries(t, reader, query, chunk_size=100000):
    """Cumulative product integrals at query times, from simultaneous six traces."""
    assert len(t) > 1 and np.all(np.isfinite(t)) and np.all(np.diff(t) >= 0)
    assert np.min(query) >= t[0] - 1e-12 and np.max(query) <= t[-1] + 1e-12
    query = np.clip(query, t[0], t[-1])
    at = np.minimum(np.searchsorted(t, query, side='right') - 1, len(t) - 2)
    result = np.full((len(query), 7), np.nan)
    total = np.zeros(7)
    for lo in range(0, len(t) - 1, chunk_size):
        hi = min(lo + chunk_size, len(t) - 1)
        y = reader(lo, hi + 1)
        assert y.shape == (hi + 1 - lo, 6) and np.all(np.isfinite(y))
        base = y[:-1]
        delta = np.diff(y, axis=0)
        dt = np.diff(t[lo:hi + 1])[:, None]
        aa = products(base, base)
        ab = products(base, delta) + products(delta, base)
        bb = products(delta, delta)
        steps = dt * (aa + ab / 2 + bb / 3)
        cumulative = np.vstack((np.zeros((1, 7)), np.cumsum(steps, axis=0)))
        chosen = np.flatnonzero((at >= lo) & (at < hi))
        if len(chosen):
            local = at[chosen] - lo
            width = dt[local, 0]
            elapsed = query[chosen] - t[at[chosen]]
            ratio = np.divide(elapsed, width, out=np.zeros_like(elapsed), where=width > 0)[:, None]
            result[chosen] = total + cumulative[local] + elapsed[:, None] * (
                aa[local] + ab[local] * ratio / 2 + bb[local] * ratio**2 / 3)
        total += cumulative[-1]
    result[query == t[-1]] = total
    assert np.all(np.isfinite(result))
    return result


def quadrature_selfcheck():
    # Nonuniform samples, chunk boundaries and duplicated solver timestamps.
    rng = np.random.default_rng(17)
    t = np.r_[0, np.sort(rng.uniform(0, 1, 4000)), 1]
    t = np.sort(np.r_[t, t[400], t[2000]])
    offsets = np.array([1., 2., 3., -.5, .7, 1.2])
    slopes = np.array([.1, -.3, .5, .7, -.2, .9])
    y = offsets + t[:, None] * slopes
    q = np.r_[0, .00371, .4, .82017, 1]
    observed = integrate_queries(t, lambda a, b: y[a:b], q, 123)
    aa = products(offsets[None, :], offsets[None, :])[0]
    ab = (products(offsets[None, :], slopes[None, :]) +
          products(slopes[None, :], offsets[None, :]))[0]
    bb = products(slopes[None, :], slopes[None, :])[0]
    expected = q[:, None] * aa + q[:, None]**2 * ab / 2 + q[:, None]**3 * bb / 3
    error = float(np.max(np.abs(observed - expected)))
    assert error < 1e-11, error
    return {'analytic_nonuniform_linear_product_max_error': error, 'pass': True}


def mean_scalar(t, y, a, b):
    inside = (t > a) & (t < b)
    tx = np.r_[a, t[inside], b]
    yy = np.r_[np.interp(a, t, y), y[inside], np.interp(b, t, y)]
    return float(trapezoid(yy, tx) / (b-a))


def event_metrics(t, y, a, b):
    selected = (t >= a) & (t < b)
    tx, yy = t[selected], y[selected]
    low, high = int(np.argmin(yy)), int(np.argmax(yy))
    outside = np.flatnonzero(np.abs(yy - 50) > .005)
    after = 0 if not len(outside) else int(outside[-1] + 1)
    settle = None if after >= len(tx) else float(tx[after])
    return {'range_s': [a, b], 'min_Hz': float(yy[low]), 'min_time_s': float(tx[low]),
            'max_Hz': float(yy[high]), 'max_time_s': float(tx[high]),
            'observed_in_50_plus_minus_0_005_Hz_until_next_event_s': settle,
            'observed_settling_delay_s': None if settle is None else settle-a}


def annotate_events(ax):
    for when, label in [(3, 'Load increase'), (7, 'Load decrease')]:
        ax.axvline(when, color='#9b5062', linestyle='--', linewidth=.9)
    ax.grid(alpha=.22)


def draw_figures(t, p, f, v, i, pref, label):
    plt.rcParams.update({'font.size': 10, 'axes.spines.top': False, 'axes.spines.right': False})
    FIGURES.mkdir(parents=True, exist_ok=True)
    fig, axes = plt.subplots(4, 1, figsize=(13.5, 11), sharex=True, layout='constrained')
    axes[0].plot(t, p, color='#1873a3', linewidth=1.5, label='Measured total load P (20 ms mean)')
    axes[0].plot(t, pref*100, color='#ad672e', linestyle='--', linewidth=1, label='Controller P reference (100 W base)')
    axes[0].set(ylabel='P (W)', title='Output active power')
    axes[0].legend(fontsize=9, loc='lower right')
    axes[1].plot(t, f, color='#7655a0', linewidth=1.5, label='Virtual-rotor frequency: omega / (2 pi)')
    axes[1].axhline(50, color='#333333', linewidth=.8, linestyle=':')
    axes[1].set(ylabel='f (Hz)', title='VSG frequency (internal state; not a terminal-frequency estimator)')
    axes[1].legend(fontsize=9)
    for phase, color in enumerate(COLORS):
        style = ['-', '--', ':'][phase]
        axes[2].plot(t, v[:, phase], color=color, linestyle=style, linewidth=1.25, label=f'Phase {"ABC"[phase]}')
        axes[3].plot(t, i[:, phase], color=color, linestyle=style, linewidth=1.25, label=f'Phase {"ABC"[phase]}')
    axes[2].set(ylabel='Vrms (V)', title='Load phase-to-neutral voltage after LC filter | trailing 20 ms RMS')
    axes[3].set(ylabel='Irms (A)', xlabel='Time (s)', title='Load branch current | trailing 20 ms RMS')
    for ax in axes[2:]:
        ax.legend(ncol=3, fontsize=9)
    for ax in axes:
        annotate_events(ax)
        ax.set_xlim(0, 11)
    for when, text in [(3, 'Increase at 3 s'), (7, 'Decrease at 7 s')]:
        axes[0].text(when+.06, .96, text, transform=axes[0].get_xaxis_transform(), va='top', fontsize=9, color='#843b4d')
    fig.suptitle('Stage 5i | Load increase and return | Secondary control ON\n'
                 '40 V DC; phase V_set = 14 V peak; actual switching-model records', fontsize=15)
    fig.supxlabel('RMS/mean window = 20 ms (one nominal 50 Hz cycle); first complete window at 0.02 s.\n'
                  'Higher-load interval is a simulation stress case, not a demonstrated hardware power rating.', fontsize=9)
    overview = FIGURES / f'stage5i_load_cycle_{label}_{DATE}.png'
    fig.savefig(overview, dpi=160)
    plt.close(fig)

    fig, axes = plt.subplots(2, 2, figsize=(13.5, 7.5), layout='constrained')
    for col, event in enumerate([3, 7]):
        selected = (t >= event-.15) & (t <= event+.5)
        for phase, color in enumerate(COLORS):
            style = ['-', '--', ':'][phase]
            axes[0, col].plot(t[selected], v[selected, phase], color=color, linestyle=style, label=f'Phase {"ABC"[phase]}')
            axes[1, col].plot(t[selected], i[selected, phase], color=color, linestyle=style, label=f'Phase {"ABC"[phase]}')
        axes[0, col].set_title('Load increase' if col == 0 else 'Load decrease')
        for row in [0, 1]:
            axes[row, col].axvline(event, color='#9b5062', linestyle='--', linewidth=.9)
            axes[row, col].set(xlim=(event-.15, event+.5), xlabel='Time (s)', ylabel='Vrms (V)' if row == 0 else 'Irms (A)')
            axes[row, col].grid(alpha=.22)
            axes[row, col].ticklabel_format(axis='y', style='plain', useOffset=False)
            axes[row, col].legend(fontsize=9, ncol=3)
    fig.suptitle('Stage 5i | Output RMS around both load transitions\nTrailing 20 ms window; phase-to-neutral voltage and load current', fontsize=14)
    zoom = FIGURES / f'stage5i_load_cycle_rms_zoom_{label}_{DATE}.png'
    fig.savefig(zoom, dpi=160)
    plt.close(fig)
    return [str(overview), str(zoom)]


def main(label):
    selfcheck = quadrature_selfcheck()
    source = FOLDER / f'results_{label}.mat'
    periods = [('before_increase', 2.6, 3.), ('higher_load', 6.6, 7.), ('after_return', 10.6, 11.)]
    with h5py.File(source, 'r') as h:
        t = times(h, 'Vload_abc')
        ti = times(h, 'iload_abc')
        assert np.array_equal(t, ti), 'Voltage and load-current timestamps must match exactly.'
        del ti
        assert t[0] <= 0 and t[-1] >= 11-1e-9
        dt = np.diff(t)
        observed_dt = [float(dt.min()), float(dt.max())]
        assert np.all(np.abs(dt-5e-6) < 1e-10), 'Unexpected waveform logging period'
        del dt
        voltage = h['signals/Vload_abc/data']
        current = h['signals/iload_abc/data']
        n = len(t)
        def reader(a, b):
            return np.column_stack((samples(voltage, a, b, n), samples(current, a, b, n)))
        display = np.arange(20, 11001, dtype=float) / 1000
        edges = np.array([edge for _, a, b in periods for edge in [a, b]])
        query = np.r_[display, np.maximum(display-WINDOW, 0), edges]
        integrated = integrate_queries(t, reader, query)
        width = len(display)
        moving = (integrated[:width] - integrated[width:2*width]) / WINDOW
        assert np.min(moving[:, :6]) >= -1e-7
        rms = np.sqrt(np.maximum(moving[:, :6], 0))
        p = moving[:, 6]
        ft, fy = scalar(h, 'freq')
        pt, py = scalar(h, 'sec_P_ref_pu')
        mt, my = scalar(h, 'P_meas')
        f = np.interp(display, ft, fy)
        pref = np.interp(display, pt, py)
        control_p = np.interp(display, mt, my)
        stats = []
        for k, (name, a, b) in enumerate(periods):
            means = (integrated[2*width+2*k+1] - integrated[2*width+2*k]) / (b-a)
            stats.append({'name': name, 'window_s': [a, b], 'P_load_W': float(means[6]),
                          'phase_voltage_rms_V': np.sqrt(means[:3]).tolist(),
                          'load_current_rms_A': np.sqrt(means[3:6]).tolist(),
                          'frequency_internal_mean_Hz': mean_scalar(ft, fy, a, b),
                          'P_control_measurement_W': mean_scalar(mt, my, a, b)})
        events = [event_metrics(ft, fy, 3, 7), event_metrics(ft, fy, 7, 11+1e-9)]
        raw_count = len(t)
    rms_events = []
    for event in [3, 7]:
        selected = (display >= event) & (display <= event+.5)
        rms_events.append({'command_event_s': event, 'observation_window_s': [event, event+.5],
                           'Vrms_min_abc_V': rms[selected, :3].min(axis=0).tolist(),
                           'Vrms_max_abc_V': rms[selected, :3].max(axis=0).tolist(),
                           'Irms_min_abc_A': rms[selected, 3:].min(axis=0).tolist(),
                           'Irms_max_abc_A': rms[selected, 3:].max(axis=0).tolist()})
    figure_paths = draw_figures(display, p, f, rms[:, :3], rms[:, 3:], pref, label)
    csv = FOLDER / f'curves_{label}.csv'
    fields = ['time_s', 'P_load_mean20ms_W', 'frequency_internal_Hz',
              'Vrms_A_V', 'Vrms_B_V', 'Vrms_C_V', 'Irms_A_A', 'Irms_B_A', 'Irms_C_A',
              'P_ref_W_equivalent', 'P_control_measurement_W']
    data = np.column_stack((display, p, f, rms, 100*pref, control_p))
    np.savetxt(csv, data, delimiter=',', header=','.join(fields), comments='', fmt='%.10g')
    compact = FOLDER / f'curves_{label}.mat'
    savemat(compact, {'time_s': display, 'P_load_W': p, 'freq_Hz': f,
                      'Vrms_abc_V': rms[:, :3], 'Irms_abc_A': rms[:, 3:],
                      'P_ref_W_equivalent': 100*pref, 'rms_window_s': WINDOW})
    report = {'source_mat': str(source), 'source_sha256': digest(source),
              'raw_voltage_current_sample_count': raw_count, 'raw_time_range_s': [0, 11],
              'rms_window_s': WINDOW, 'plot_spacing_s': .001, 'quadrature_selfcheck': selfcheck,
              'method': 'Exact time integrals of products of piecewise-linear recorded samples; trailing fixed 20 ms window. Solver MaxStep2.5us; output logging5us (200kHz).',
              'voltage_current_logging_sample_time_s': 5e-6,
              'observed_waveform_dt_min_max_s': observed_dt,
              'P_definition': 'sum of load phase voltage times load branch current; displayed as trailing20ms mean',
              'f_definition': 'internal virtual rotor omega/(2*pi); not independently measured terminal frequency',
              'V_definition': 'phase-to-floating-load-neutral after LC',
              'I_definition': 'load branch, not filter-inductor current',
              'steady_windows': stats, 'frequency_events': events, 'rms_events': rms_events,
              'figures': figure_paths, 'csv': str(csv), 'compact_mat': str(compact),
              'scope': 'Observed simulation load-cycle response with secondary enabled; not hardware qualification or full VSG identification.'}
    path = FOLDER / f'analysis_{label}.json'
    path.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--label', default='nominal')
    parser.add_argument('--selfcheck', action='store_true')
    args = parser.parse_args()
    if args.selfcheck:
        print(json.dumps(quadrature_selfcheck()))
    else:
        main(args.label)
