"""Independent structure and saved waveform checks for the Stage 5i load cycle."""
import argparse
import copy
import json
from pathlib import Path
import sys

import numpy as np
from scipy.integrate import trapezoid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'python/.deps_stage5h'))
import h5py
import verify_stage5i_structure as structure
from plot_stage5i_load_cycle import samples, digest

FOLDER = ROOT / 'matlab/validation_outputs/stage5i_load_cycle'


def structure_check():
    source = ROOT / 'matlab/validation_outputs/stage5i/vsg_stage5i_secondary.slx'
    target = FOLDER / 'vsg_stage5i_load_cycle.slx'
    _, a, al, ass, _ = structure.read(source)
    _, b, bl, bss, _ = structure.read(target)
    assert set(a) <= set(b)
    assert set(b)-set(a) == {'415', '416', '417'}
    assert all(al[sid] == bl[sid] for sid in a)
    changes = []
    for sid in a:
        before, after = copy.deepcopy(a[sid]), copy.deepcopy(b[sid])
        pa, pb = structure.props(before), structure.props(after)
        if sid == '223':
            assert pb['Time'] == 'load_increase_time_s'
            after.remove(after.find("P[@Name='Time']"))
            changes.append({'sid': sid, 'parameter': 'Time', 'new': 'load_increase_time_s'})
            if after.get('Name') != before.get('Name'):
                assert after.get('Name') == 'Load_Increase_3s'
                changes.append({'sid': sid, 'parameter': 'Name', 'new': 'Load_Increase_3s'})
                after.set('Name', before.get('Name'))
        elif before.get('BlockType') == 'ToWorkspace' and pa.get('VariableName') in ['Vload_abc_ts','iload_abc_ts']:
            assert pb['SampleTime'] == '5e-6'
            if 'SampleTime' in pa:
                after.find("P[@Name='SampleTime']").text = pa['SampleTime']
            else:
                after.remove(after.find("P[@Name='SampleTime']"))
            changes.append({'sid': sid, 'parameter': 'SampleTime', 'new': '5e-6'})
        elif before.get('BlockType') == 'ToWorkspace' and pa.get('MaxDataPoints') != pb.get('MaxDataPoints'):
            assert pa['MaxDataPoints'] == 'inf' and pb['MaxDataPoints'] == '1'
            after.find("P[@Name='MaxDataPoints']").text = 'inf'
            changes.append({'sid': sid, 'parameter': 'MaxDataPoints', 'new': '1'})
        assert structure.canonical(before) == structure.canonical(after), sid
    for sid in ass:
        before, after = structure.netlist(ass[sid]), structure.netlist(bss[sid])
        if sid == '210':
            for dst in ['251#in:1', '277#in:1', '302#in:1']:
                before[('signal', '223#out:1', dst)] -= 1
                before[('signal', '416#out:1', dst)] += 1
            for src, dst in [('223#out:1', '416#in:1'), ('415#out:1', '416#in:2'), ('416#out:1', '417#in:1')]:
                before[('signal', src, dst)] += 1
            before = +before
        assert before == after, sid
    report = {'pass': True, 'source_model': str(source), 'source_sha256': digest(source),
              'target_model': str(target), 'target_sha256': digest(target),
              'preserved_original_blocks': len(a), 'new_blocks': ['415', '416', '417'],
              'allowed_parameter_changes': changes,
              'physical_netsets_unchanged': True,
              'scope': 'Block parameters/hierarchy and electrical/control netlists; new load command and logging-only changes explicitly allowed.'}
    (FOLDER/'structure_verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    return report


def waveform_check(label):
    analysis = json.loads((FOLDER/f'analysis_{label}.json').read_text())
    execution = json.loads((FOLDER/f'report_{label}.json').read_text())
    checks = [{'name': 'runner_finite_complete_load_protocol_checks', 'pass': bool(execution['execution_pass'])}]
    source = FOLDER/f'results_{label}.mat'
    with h5py.File(source, 'r') as h:
        t = np.asarray(h['signals/Vload_abc/time']).ravel()
        for row in analysis['steady_windows']:
            a, b = row['window_s']
            start = max(0, np.searchsorted(t, a, side='left')-1)
            stop = min(len(t), np.searchsorted(t, b, side='right')+1)
            tt = t[start:stop]
            # Independent uniform-grid reconstruction and trapezoidal quadrature.
            grid = np.linspace(a, b, int(round((b-a)/2e-6))+1)
            v = samples(h['signals/Vload_abc/data'], start, stop, len(t))
            i = samples(h['signals/iload_abc/data'], start, stop, len(t))
            vv = np.column_stack([np.interp(grid, tt, v[:, k]) for k in range(3)])
            ii = np.column_stack([np.interp(grid, tt, i[:, k]) for k in range(3)])
            vrms = np.sqrt(trapezoid(vv**2, grid, axis=0)/(b-a))
            irms = np.sqrt(trapezoid(ii**2, grid, axis=0)/(b-a))
            power = trapezoid(np.sum(vv*ii, axis=1), grid)/(b-a)
            ve = float(np.max(np.abs(vrms-np.array(row['phase_voltage_rms_V']))))
            ie = float(np.max(np.abs(irms-np.array(row['load_current_rms_A']))))
            pe = float(abs(power-row['P_load_W']))
            checks.append({'name': row['name']+'_independent_2us_quadrature',
                           'max_voltage_rms_error_V': ve, 'max_current_rms_error_A': ie,
                           'power_error_W': pe, 'thresholds_V_A_W': [.001, .001, .02],
                           'pass': ve<.001 and ie<.001 and pe<.02})
    low, high, back = analysis['steady_windows']
    checks.append({'name': 'power_and_all_phase_currents_increase_then_decrease',
                   'pass': bool(high['P_load_W'] > low['P_load_W'] and high['P_load_W'] > back['P_load_W']
                   and np.all(np.array(high['load_current_rms_A']) > np.array(low['load_current_rms_A']))
                   and np.all(np.array(high['load_current_rms_A']) > np.array(back['load_current_rms_A'])))})
    vreturn = float(np.max(np.abs(np.array(back['phase_voltage_rms_V'])-np.array(low['phase_voltage_rms_V']))))
    ireturn = float(np.max(np.abs(np.array(back['load_current_rms_A'])-np.array(low['load_current_rms_A']))))
    checks.append({'name': 'return_to_original_load_operating_point', 'max_Vrms_change_V': vreturn,
                   'max_Irms_change_A': ireturn, 'thresholds_V_A': [.05, .05], 'pass': vreturn<.05 and ireturn<.05})
    for row in analysis['steady_windows']:
        error = abs(row['frequency_internal_mean_Hz']-50)
        checks.append({'name': row['name']+'_mean_frequency', 'error_Hz': error, 'threshold_Hz': .005, 'pass': error<.005})
    report = {'source': str(source), 'checks': checks, 'pass': all(item['pass'] for item in checks),
              'scope': 'Explicit engineering screens for this scenario, not a universal SG/VSG certification.'}
    (FOLDER/f'independent_checks_{label}.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--structure-only', action='store_true')
    parser.add_argument('--label', default='nominal')
    args = parser.parse_args()
    if args.structure_only:
        result = structure_check()
    else:
        result = waveform_check(args.label)
    print(json.dumps(result, indent=2))
    assert result['pass']
