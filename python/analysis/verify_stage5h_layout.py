"""Check layout copy against the saved source, including physical net sets."""
import copy
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

ROOT=Path(r'D:\workspace\engineering\vsg-project')
FOLDER=ROOT/'matlab/validation_outputs/stage5h'
SOURCE=FOLDER/'vsg_stage5h_mosfet.slx'
TARGET=FOLDER/'vsg_stage5h_mosfet_layout.slx'
VISUAL={'Position','ZOrder','BackgroundColor','ForegroundColor','FontName','FontSize',
        'FontWeight','FontAngle','NamePlacement','ShowName','DropShadow','Selected'}

def canonical(element):
    if element.tag=='System':return None
    if element.tag=='P' and element.get('Name') in VISUAL:return None
    # R2018b materializes the default Scope implementation when loading.
    if (element.tag=='P' and element.get('Name')=='ScopeSpecificationString'
            and element.text=='Simulink.scopes.TimeScopeBlockCfg'):return None
    children=[canonical(c) for c in element]
    return (element.tag,sorted(element.attrib.items()),(element.text or '').strip(),
            [c for c in children if c is not None])

def read(path):
    with zipfile.ZipFile(path) as archive:
        doc=ET.fromstring(archive.read('simulink/blockdiagram.xml'))
        configs={n:ET.tostring(ET.fromstring(archive.read(n))) for n in archive.namelist()
                 if n.startswith('simulink/configSet') and n.endswith('.xml')}
    blocks={b.get('SID'):b for b in doc.iter('Block')}
    scopes={'root':doc.find('Model/System'),
            'plant':doc.find(".//Block[@Name='Gate_Driver_and_MOSFET_Circuit']/System")}
    nets={}
    for name,system in scopes.items():
        netlist=[]
        for line in system.findall('Line'):
            src=[p.text for p in line.iter('P') if p.get('Name')=='Src']
            dst=[p.text for p in line.iter('P') if p.get('Name')=='Dst']
            if line.get('LineType')=='Connection':
                netlist.append(('physical',tuple(sorted(set(src+dst)))))
            else:
                assert len(src)==1
                netlist.extend(('signal',src[0],d) for d in dst)
            assert all(p.get('Name') in {'Src','Dst','Points','ZOrder'} for p in line.iter('P'))
        nets[name]=sorted(netlist)
    return blocks,nets,configs,scopes

a,an,ac,_=read(SOURCE);b,bn,bc,scopes=read(TARGET)
changes=[]
for sid in sorted(set(a)|set(b)):
    if sid not in a or sid not in b or canonical(a[sid])!=canonical(b[sid]):
        changes.append({'sid':sid,'name':a.get(sid,b.get(sid)).get('Name')})
        if sid in a and sid in b:
            aa={p.get('Name'):p.text for p in a[sid].findall('P')}
            bb={p.get('Name'):p.text for p in b[sid].findall('P')}
            print('DIFF',sid,[(k,aa.get(k),bb.get(k)) for k in set(aa)|set(bb)
                             if k not in VISUAL and aa.get(k)!=bb.get(k)])
overlaps=[]
for name,s in scopes.items():
    rects=[]
    for block in s.findall('Block'):
        raw=block.find("P[@Name='Position']").text
        r=[int(float(x)) for x in raw.strip('[]').split(',')]
        rects.append((block.get('Name'),r))
    for i,(n,r) in enumerate(rects):
        for m,t in rects[i+1:]:
            if max(r[0],t[0])<min(r[2],t[2]) and max(r[1],t[1])<min(r[3],t[3]):
                overlaps.append([name,n,m])
report={'source':str(SOURCE),'target':str(TARGET),
        'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'target_sha256':hashlib.sha256(TARGET.read_bytes()).hexdigest(),
        'block_count':len(a),'nonvisual_block_changes':changes,
        'signal_and_physical_nets_identical':an==bn,
        'configuration_files_identical':ac==bc,'overlapping_block_rectangles':overlaps}
report['normalization_note']='Only known default ScopeSpecificationString initialization and visual fields excluded.'
report['pass']=not changes and an==bn and ac==bc and not overlaps
out=FOLDER/'layout_verification_2026-10-30.json'
out.write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
assert report['pass'],'Layout verification failed'
