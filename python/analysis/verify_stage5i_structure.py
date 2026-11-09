"""Independently verify Stage 5i preserves Stage 5h plant and primary control.

Allowed changes: added secondary controller/telemetry and replacement of the
P_set -> Sum_Pm input-1 edge by the declared Goto/From secondary-reference path.
The original 297 blocks, their hierarchy and nonvisual parameters must match.
"""
from collections import Counter
import copy
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'matlab/validation_outputs/stage5h/vsg_stage5h_mosfet_layout.slx'
TARGET = ROOT / 'matlab/validation_outputs/stage5i/vsg_stage5i_secondary.slx'
VISUAL = {'Position', 'ZOrder', 'BackgroundColor', 'ForegroundColor', 'FontName',
          'FontSize', 'FontWeight', 'FontAngle', 'NamePlacement', 'ShowName',
          'DropShadow', 'Selected'}
MULTIBODY_DEFAULTS = {
    'MECH.SimMechanicsCC': {
        'DisabledProps': '[]', 'Description': None, 'Name': 'SimscapeMultibody1G',
        'WarnOnRedundantConstraints': 'on', 'WarnOnSingularInitialAssembly': 'off',
        'ShowCutJoints': 'off', 'VisOnUpdateDiagram': 'off', 'VisDuringSimulation': 'off',
        'EnableVisSimulationTime': 'on', 'VisSampleTime': '0', 'DisableBodyVisControl': 'off',
        'ShowCG': 'on', 'ShowCS': 'on', 'ShowOnlyPortCS': 'off', 'HighlightModel': 'on',
        'FramesToBeSkipped': '0', 'AnimationDelay': '3', 'RecordAVI': 'off',
        'CompressAVI': 'on', 'AviFileName': None, 'AutoFitVis': 'off', 'EnableSelection': 'on',
        'LastVizWinPosition': '[-1 -1 -1 -1]', 'CamPosition': '[0 0 0]',
        'CamTarget': '[0 0 -1]', 'CamUpVector': '[0 1 0]', 'CamHeight': '-1',
        'CamViewAngle': '0', 'VisBackgroundColor': '[0.9 0.9 0.95]',
        'DefaultBodyColor': '[1 0 0]', 'MDLBodyVisualizationType': 'Convex hull from body CS locations',
        'OVRRIDBodyVisualizationType': 'NONE', 'VisConfigFile': None},
    'simmechanics.ConfigurationSet': {'DisabledProps': '[]', 'Description': 'Simscape Multibody',
                                    'Name': 'SimscapeMultibody'},
    'simmechanics.DiagnosticsConfigSet': {
        'DisabledProps': '[]', 'Description': 'Diagnostics', 'Name': 'DiagnosticsConfigSet',
        'SimMechanicsInvalidVisualProperty': 'warning', 'SimMechanicsCrossSectionNullEdge': 'warning',
        'SimMechanicsUnconnectedFramePorts': 'warning', 'SimMechanicsUnconnectedGeometryPorts': 'warning',
        'SimMechanicsRedundantBlock': 'warning', 'SimMechanicsConflictingReferenceFrames': 'warning',
        'SimMechanicsRigidlyBoundBlock': 'error', 'SimMechanicsUnsatisfiedHighPriorityTargets': 'warning',
        'SimMechanicsJointTargetOverSpecification': 'error'},
    'simmechanics.ExplorerConfigSet': {'DisabledProps': '[]', 'Description': 'Explorer',
                                     'Name': 'ExplorerConfigSet',
                                     'SimMechanicsOpenEditorOnUpdate': 'on',
                                     'InternalSimMechanicsExplorerSettings': None}}


def canonical(element, skip_system=True):
    if skip_system and element.tag == 'System':
        return None
    if element.tag == 'P' and element.get('Name') in VISUAL:
        return None
    if (element.tag == 'P' and element.get('Name') == 'ScopeSpecificationString'
            and element.text == 'Simulink.scopes.TimeScopeBlockCfg'):
        return None
    children = [canonical(c, skip_system) for c in element]
    return (element.tag, tuple(sorted(element.attrib.items())),
            (element.text or '').strip(), tuple(c for c in children if c is not None))


def props(element):
    return {p.get('Name'): p.text for p in element.findall('P')}


def normalize_unused_multibody(old, new, blocks):
    """Remove only the exact observed R2018b default unused config addition."""
    original = old.find(".//Object[@ClassName='SSC.SimscapeCC']")
    current = new.find(".//Object[@ClassName='SSC.SimscapeCC']")
    if original is None or current is None:
        return []
    old_components = original.find("Array[@PropName='Components']")
    added = current.find("Array[@PropName='Components']")
    if old_components is not None or added is None:
        return []
    domain_words = ('simmechanics', 'multibody', 'sm_lib', 'mechlib', 'mech_')
    for block in blocks.values():
        references = [p.text or '' for p in block.findall('P')
                      if p.get('Name') in ('SourceBlock', 'ReferenceBlock', 'MaskType', 'AncestorBlock')]
        assert not any(word in value.lower() for value in references for word in domain_words), \
            'Cannot normalize Multibody config when a model block references that domain'
    objects = list(added.iter('Object'))
    assert Counter(o.get('ClassName') for o in objects) == Counter(MULTIBODY_DEFAULTS.keys()), \
        'Unexpected added Simscape configuration classes'
    assert added.attrib == {'PropName': 'Components', 'Type': 'Handle', 'Dimension': '1*2'}
    for obj in objects:
        assert obj.get('Version') == '1.18.1'
        assert props(obj) == MULTIBODY_DEFAULTS[obj.get('ClassName')], \
            f"Non-default added Multibody configuration: {obj.get('ClassName')}"
        assert all(child.tag in ('P', 'Array') for child in obj)
    nested = [node for node in added.iter('Array') if node is not added]
    assert len(nested) == 1 and nested[0].attrib == added.attrib
    assert [o.get('ClassName') for o in added.findall('Object')] == [
        'MECH.SimMechanicsCC', 'simmechanics.ConfigurationSet']
    assert [o.get('ClassName') for o in nested[0].findall('Object')] == [
        'simmechanics.DiagnosticsConfigSet', 'simmechanics.ExplorerConfigSet']
    evidence = {'parent_class': 'SSC.SimscapeCC',
                'added_defaults': {o.get('ClassName'): props(o) for o in objects},
                'reason': 'Exact observed R2018b default unused Multibody configuration materialization.',
                'no_multibody_block_references': True}
    current.remove(added)
    return [evidence]


def netlist(system):
    nets = []
    for line in system.findall('Line'):
        assert all(p.get('Name') in {'Src', 'Dst', 'Points', 'ZOrder'}
                   for p in line.iter('P')), 'Unexpected custom line attribute'
        src = [p.text for p in line.iter('P') if p.get('Name') == 'Src']
        dst = [p.text for p in line.iter('P') if p.get('Name') == 'Dst']
        if line.get('LineType') == 'Connection':
            nets.append(('physical', tuple(sorted(set(src + dst)))))
        else:
            assert len(src) == 1
            nets.extend(('signal', src[0], d) for d in dst)
    return Counter(nets)


def read(path):
    with zipfile.ZipFile(path) as archive:
        doc = ET.fromstring(archive.read('simulink/blockdiagram.xml'))
        configs = {n: ET.fromstring(archive.read(n)) for n in archive.namelist()
                   if n.startswith('simulink/configSet') and n.endswith('.xml')}
    model = doc.find('Model')
    systems = {}
    blocks = {}
    locations = {}

    def walk(system, owner):
        systems[owner] = system
        for block in system.findall('Block'):
            sid = block.get('SID')
            assert sid not in blocks
            blocks[sid] = block
            locations[sid] = owner
            child = block.find('System')
            if child is not None:
                walk(child, sid)
    walk(model.find('System'), 'root')
    return model, blocks, locations, systems, configs


def main():
    am, a, al, ass, ac = read(SOURCE)
    bm, b, bl, bss, bc = read(TARGET)
    issues = []
    def check(condition, message):
        if not condition:
            issues.append(message)
    check(len(a) == 297, f'Unexpected source block count: {len(a)}')
    missing = sorted(set(a) - set(b))
    check(not missing, f'Missing original SIDs: {missing}')
    changes = [sid for sid in a if sid in b and canonical(a[sid]) != canonical(b[sid])]
    hierarchy = [sid for sid in a if al[sid] != bl.get(sid)]
    check(not changes, f'Changed original block parameters: {changes}')
    check(not hierarchy, f'Changed original block hierarchy: {hierarchy}')
    check(props(am) == props(bm), 'Model-level properties changed')
    for owner, system in ass.items():
        check(owner in bss, f'Missing original system {owner}')
        if owner in bss:
            oldp, newp = props(system), props(bss[owner])
            for key in ('SIDHighWatermark', 'ZoomFactor', 'Location', 'Open'):
                oldp.pop(key, None); newp.pop(key, None)
            check(oldp == newp, f'Original system properties changed: {owner}')

    config_changes = []
    normalized_additions = []
    check(set(ac) == set(bc), 'Configuration file set changed')
    for name in ac:
        if name not in bc:
            continue
        old, new = copy.deepcopy(ac[name]), copy.deepcopy(bc[name])
        normalized_additions.extend(normalize_unused_multibody(old, new, b))
        oldstop = old.findall(".//P[@Name='StopTime']")
        newstop = new.findall(".//P[@Name='StopTime']")
        if oldstop or newstop:
            check(len(oldstop) == len(newstop) == 1, 'StopTime config cardinality')
            if len(oldstop) == len(newstop) == 1:
                config_changes.append({'name': 'StopTime', 'old': oldstop[0].text, 'new': newstop[0].text})
                check(oldstop[0].text == '3' and newstop[0].text == '6', 'Expected StopTime 3 -> 6')
                newstop[0].text = oldstop[0].text
        check(canonical(old, False) == canonical(new, False), f'Unexpected config change: {name}')

    names = {block.get('Name'): sid for sid, block in b.items() if bl[sid] == 'root'}
    check(a.get('1') is not None and a['1'].get('Name') == 'P_set', 'Source SID1 must be P_set')
    check(a.get('12') is not None and a['12'].get('Name') == 'Sum_Pm', 'Source SID12 must be Sum_Pm')
    oldnets, newnets = netlist(ass['root']), netlist(bss['root'])
    replacement = ('signal', '1#out:1', '12#in:1')
    check(oldnets[replacement] == 1 and newnets[replacement] == 0, 'P_set direct edge was not replaced exactly')
    removed = oldnets - newnets
    added = newnets - oldnets
    check(removed == Counter({replacement: 1}), f'Unexpected removed root edges: {list(removed.elements())}')
    required = [('P_set', 'Sec_Base_Goto', 1, 1),
                ('Sec_Base_From', 'Secondary_Frequency_Control', 1, 2),
                ('Sec_Omega_From', 'Secondary_Frequency_Control', 1, 1),
                ('Secondary_Frequency_Control', 'Sec_Pref_Goto', 1, 1),
                ('Sec_Pref_From', 'Sum_Pm', 1, 1)]
    for start, end, outport, inport in required:
        check(start in names and end in names, f'Missing declared root block: {start}/{end}')
        if start in names and end in names:
            edge = ('signal', f'{names[start]}#out:{outport}', f'{names[end]}#in:{inport}')
            check(newnets[edge] == 1, f'Missing/duplicated edge: {start} -> {end}')
    tags = {'Sec_Base_Goto': 'secondary_P_base_pu', 'Sec_Base_From': 'secondary_P_base_pu',
            'Sec_Pref_Goto': 'secondary_P_ref_pu', 'Sec_Pref_From': 'secondary_P_ref_pu',
            'Sec_Omega_From': 'omega'}
    for name, tag in tags.items():
        if name in names:
            block = b[names[name]]
            check(props(block).get('GotoTag') == tag, f'Wrong GotoTag: {name}')
            check(block.get('BlockType') == ('Goto' if name.endswith('Goto') else 'From'), f'Wrong routing type: {name}')
            if name.endswith('Goto'):
                check(props(block).get('TagVisibility') == 'global', f'Wrong tag visibility: {name}')
    for tag in ('secondary_P_base_pu', 'secondary_P_ref_pu'):
        gotos = [sid for sid, block in b.items() if block.get('BlockType') == 'Goto'
                 and props(block).get('GotoTag') == tag]
        check(len(gotos) == 1, f'Tag must have one producer: {tag}')
    expected_types = {'Secondary_Frequency_Control': 'SubSystem',
                      'Sec_Base_Goto': 'Goto', 'Sec_Base_From': 'From',
                      'Sec_Pref_Goto': 'Goto', 'Sec_Pref_From': 'From',
                      'Sec_Omega_From': 'From', 'Scope_frequency_Hz': 'Scope'}
    expected_edges = []
    telemetry = ['sec_P_ref_pu', 'sec_freq_Hz', 'sec_delta_P_pu',
                 'sec_freq_error_Hz', 'sec_enabled', 'sec_clamp_state']
    for k, variable in enumerate(telemetry, 1):
        expected_types.update({f'Sec_LogTag_{k}': 'Goto', f'Sec_LogFrom_{k}': 'From',
                               f'Log_{variable}': 'ToWorkspace'})
        expected_edges.extend([('Secondary_Frequency_Control', f'Sec_LogTag_{k}', k, 1),
                               (f'Sec_LogFrom_{k}', f'Log_{variable}', 1, 1)])
        for name in (f'Sec_LogTag_{k}', f'Sec_LogFrom_{k}'):
            if name in names:
                check(props(b[names[name]]).get('GotoTag') == f'secondary_log_{k}',
                      f'Wrong telemetry tag: {name}')
        if f'Log_{variable}' in names:
            parameters = props(b[names[f'Log_{variable}']])
            check(parameters.get('VariableName') == variable + '_ts', f'Wrong telemetry variable: {variable}')
            check(parameters.get('SaveFormat') == 'Timeseries', f'Wrong telemetry format: {variable}')
    added_root_names = {b[sid].get('Name') for sid in set(b)-set(a) if bl[sid] == 'root'}
    check(added_root_names == set(expected_types), 'Unexpected added root block names')
    for name, block_type in expected_types.items():
        if name in names:
            check(b[names[name]].get('BlockType') == block_type, f'Unexpected new block type: {name}')
    expected_edges += required + [('Secondary_Frequency_Control', 'Scope_frequency_Hz', 2, 1)]
    expected_counter = Counter()
    for start, end, outport, inport in expected_edges:
        if start in names and end in names:
            expected_counter[('signal', f'{names[start]}#out:{outport}', f'{names[end]}#in:{inport}')] += 1
    check(added == expected_counter, 'Added root connectivity differs from declared secondary/telemetry wiring')
    expected_into_old = ('signal', f"{names.get('Sec_Pref_From', '?')}#out:1", '12#in:1')
    expected_from_old = ('signal', '1#out:1', f"{names.get('Sec_Base_Goto', '?')}#in:1")
    for edge in added:
        check(edge[0] == 'signal', f'Added root physical net: {edge}')
        if edge[0] == 'signal':
            if edge[1].split('#')[0] in a:
                check(edge == expected_from_old, f'Unexpected new branch from original block: {edge}')
            if edge[2].split('#')[0] in a:
                check(edge == expected_into_old, f'Unexpected new input to original block: {edge}')
    plant_sid = next(sid for sid, block in a.items()
                     if block.get('Name') == 'Gate_Driver_and_MOSFET_Circuit')
    check(netlist(ass[plant_sid]) == netlist(bss[plant_sid]), 'Electrical plant connectivity changed')
    check({sid for sid, owner in al.items() if owner == plant_sid}
          == {sid for sid, owner in bl.items() if owner == plant_sid}, 'Electrical plant membership changed')
    for owner in ass:
        if owner != 'root':
            check(netlist(ass[owner]) == netlist(bss[owner]), f'Old subsystem nets changed: {owner}')

    report = {'source': str(SOURCE), 'target': str(TARGET),
              'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'target_sha256': hashlib.sha256(TARGET.read_bytes()).hexdigest(),
              'original_block_count': len(a), 'target_block_count': len(b),
              'missing_old_sids': missing, 'changed_old_parameter_sids': changes,
              'changed_old_hierarchy_sids': hierarchy, 'config_changes': config_changes,
              'explicitly_normalized_config_additions': normalized_additions,
              'new_root_block_names': sorted(b[sid].get('Name') for sid in set(b)-set(a) if bl[sid] == 'root'),
              'removed_root_edges': list(removed.elements()), 'added_root_edges': list(added.elements()),
              'issues': issues, 'pass': not issues,
              'normalization': 'Visual block properties and known default ScopeSpecificationString excluded. StopTime 3 -> 6 allowed. Exact unused Multibody default additions checked against explicit values and reported. Original system zoom/window/SID-watermark changes allowed.',
              'scope': 'Structural preservation and declared secondary routing; does not itself establish stability or runtime equivalence.'}
    path = TARGET.parent / 'structure_verification_2026-11-06.json'
    path.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))
    assert report['pass'], 'Stage 5i structural verification failed'


if __name__ == '__main__':
    main()
