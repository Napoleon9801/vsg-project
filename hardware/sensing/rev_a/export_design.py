"""Export Rev A component schedule and logical connectivity (not PCB CAD netlist)."""
from pathlib import Path
import csv
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parent

bom = [
    ['U1','OPA4197ID','SOIC-14; quad opamp; +/-12 V analog supply',1,1,'S01/S02','Verify stock and package; no firmware change'],
    ['RA/RB/RC gain networks; RBUS chain','PLT0805Z1002LBTS','10k;0.01%;5ppm/C;0805;0.25W',40,44,'S01/S02','30 phase +10 bus;4 spare; no assumed ratio tracking'],
    ['CGA/CFA/CGB/CFB/CGC/CFC','Specification-controlled','1nF C0G >=50V <=1%;pair match<=0.1%',6,10,'S01','Selection inventory may need increasing; verify measurement uncertainty'],
    ['CBUS','Specification-controlled','10nF C0G >=50V <=5%',1,2,'S02','Bus divider pole ~1.768kHz'],
    ['CDEC_P/CDEC_N','Specification-controlled','100nF ceramic >=25V',2,4,'S01/S02','Close to U1 rails'],
    ['CBULK_P/CBULK_N','Specification-controlled','4.7uF >=25V',2,3,'S01/S02','Negative rail electrolytic positive terminal at AGND'],
    ['RBLEED_P/RBLEED_N','Specification-controlled','1k 0.5W <=1%',2,2,'S01/S02','DC rail-rise bound only; does not make off rail zero'],
    ['K1/K2','G6K-2P-Y DC5','Nonlatching DPDT;5V coil;polarized;bottom-view drawing',2,2,'S01/S02','Contact reliability and ADC power-loss timing remain HOLD'],
    ['QK1/QK2','2N3904','One transistor per coil; actual manufacturer pinout required',2,4,'S01/S02','Package/footprint not released'],
    ['DK1/DK2','1N4148','Coil flyback diode; anode collector/cathode +5V',2,4,'S01/S02','Release delay with diode must be measured'],
    ['RBK1/RBK2','Specification-controlled','1k >=0.125W <=1%',2,4,'S01/S02','One base resistor per transistor'],
    ['RPD_K1/RPD_K2;RADCPD_A/B/C/BUS','Specification-controlled','100k >=0.125W <=1%',6,8,'S01/S02','2 base pulldowns +4 ADC-side pulldowns'],
    ['RLINK_A/B/C/BUS','Specification-controlled','0 ohm output link',4,6,'S01/S02','Do not add arbitrary unmatched ADC series-R'],
    ['J1/J2/J3/J4','Specification-controlled','6/3/8/3 pin keyed connectors; pitch/rating/layout review',4,4,'P11','Connector cost in wiring budget not double-counted'],
    ['Sensing PCB','CAD not released','Precision analog layout and test points',1,1,'P10','PCB fabrication cost separate'],
    ['S05 interface','Separate design','Qualified AFE_CONNECT_DRIVE and fast gate shutdown',1,1,'S05','Not included as completed circuitry; separate protection budget'],
]
with (ROOT/'sensing_bom.csv').open('w',newline='',encoding='utf-8-sig') as file:
    w=csv.writer(file)
    w.writerow(['references','part_or_spec','description','used_quantity','suggested_buy_quantity','budget_owner','qualification_note'])
    w.writerows(bom)

connections=[]
def component(ref,kind,value,n1,n2):
    connections.append([ref,kind,value,n1,n2])

for phase,pins in [('A',(3,2,1)),('B',(5,6,7)),('C',(10,9,8))]:
    for branch,start,end in [('P',f'OUT_{phase}',f'P_{phase}'),('N','N_AC',f'M_{phase}')]:
        previous=start
        for i in range(1,5):
            next_node=end if i==4 else f'{phase}_{branch}_CHAIN_{i}'
            component(f'R{phase}{branch}{i}','R','10k_0.01%',previous,next_node)
            previous=next_node
    component(f'R{phase}G','R','10k_0.01%',f'P_{phase}','AGND_SENSE')
    component(f'R{phase}F','R','10k_0.01%',f'M_{phase}',f'V_SENSE_{phase}')
    component(f'CG{phase}','C','1nF_C0G_matched',f'P_{phase}','AGND_SENSE')
    component(f'CF{phase}','C','1nF_C0G_matched',f'M_{phase}',f'V_SENSE_{phase}')
    for pin,node in zip(pins,(f'P_{phase}',f'M_{phase}',f'V_SENSE_{phase}')):
        component(f'U1.{pin}','PIN','OPA4197ID',node,'')

previous='DC_LINK_P'
for i in range(1,10):
    nxt='BUS_DIV' if i==9 else f'BUS_CHAIN_{i}'
    component(f'RBUS{i}','R','10k_0.01%',previous,nxt); previous=nxt
component('RBUS10','R','10k_0.01%','BUS_DIV','AGND_SENSE')
component('CBUS','C','10nF','BUS_DIV','AGND_SENSE')
for pin,node in [(12,'BUS_DIV'),(13,'V_SENSE_BUS'),(14,'V_SENSE_BUS'),(4,'APLUS12'),(11,'AMINUS12')]:
    component(f'U1.{pin}','PIN','OPA4197ID',node,'')
for rail,suffix in [('APLUS12','P'),('AMINUS12','N')]:
    component(f'RBLEED_{suffix}','R','1k_0.5W',rail,'AGND_SENSE')
    component(f'CDEC_{suffix}','C','100nF',rail,'AGND_SENSE')
    component(f'CBULK_{suffix}','C','4.7uF',rail,'AGND_SENSE')

for channel,adc,k,pole in [('A','ADC_V4','K1','A'),('B','ADC_V5','K1','B'),('C','ADC_V6','K2','A'),('BUS','ADC_V7','K2','B')]:
    component(f'RLINK_{channel}','R','0',f'V_SENSE_{channel}',f'RELAY_IN_{channel}')
    component(f'RADCPD_{channel}','R','100k',adc,'AGND_SENSE')
    for contact,node in [('COM',adc),('NC','AGND_SENSE'),('NO',f'RELAY_IN_{channel}')]:
        component(f'{k}.{contact}_{pole}','CONTACT','G6K_named_contact',node,'')

for k in ('K1','K2'):
    component(f'RB{k}','R','1k','AFE_CONNECT_DRIVE',f'BASE_{k}')
    component(f'RPD_{k}','R','100k',f'BASE_{k}','AGND_SENSE')
    component(f'D{k}','DIODE_ANODE_CATHODE','1N4148',f'COLLECTOR_{k}','5V_RELAY')
    component(f'{k}.COIL','COIL_POS_NEG','5V_polarized','5V_RELAY',f'COLLECTOR_{k}')
    for terminal,node in [('B',f'BASE_{k}'),('C',f'COLLECTOR_{k}'),('E','AGND_SENSE')]:
        component(f'Q{k}.{terminal}','PIN','2N3904_named_terminal',node,'')

with (ROOT/'logical_connections.csv').open('w',newline='',encoding='utf-8-sig') as file:
    w=csv.writer(file); w.writerow(['reference','kind','value','node_1','node_2']); w.writerows(connections)

# Explicit component/signal diagram; component-to-pin CSV is the detailed logical source.
svg='''<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="900" viewBox="0 0 1400 900">
<style>text{font-family:Arial,sans-serif;fill:#14233b} .title{font-size:25px;font-weight:bold}.h{font-size:19px;font-weight:bold}.t{font-size:17px}.small{font-size:15px}.wire{fill:none;stroke:#244a70;stroke-width:3}.box{fill:#edf4fb;stroke:#244a70;stroke-width:2}.warn{fill:#fff2d9;stroke:#ad6b00;stroke-width:2}</style>
<rect width="1400" height="900" fill="white"/>
<text x="35" y="40" class="title">VSG SENSING Rev A — neutral + differential voltage measurement</text>
<text x="35" y="68" class="small">Design values selected. NOT released for power operation. Module, sequencing and alias tests remain pending.</text>
<rect x="30" y="90" width="1340" height="165" rx="8" class="box"/>
<text x="50" y="120" class="h">Neutral: ONE N_AC star for the three Rd-Cf branches and the three Y-load branches</text>
<text x="50" y="155" class="t">SW_x → L_x → ACS_x → OUT_x → load branch → N_AC</text>
<text x="50" y="185" class="t">OUT_x → Rd_x → Cf_x → N_AC     |     N_AC sense lead → amplifier negative-input chains</text>
<text x="50" y="218" class="h">NO hard bond N_AC ↔ DC− / AGND / PE. AGND_SENSE has a quiet reference connection to DC−.</text>
<text x="50" y="243" class="small">The resistor networks still load N_AC; this is NOT galvanic isolation. Repeat phase circuit below for A, B and C.</text>
<text x="45" y="315" class="h">OUT_x</text><path d="M130 310 H195" class="wire"/>
<rect x="195" y="290" width="220" height="40" class="box"/><text x="210" y="316" class="t">4 × 10k in series</text>
<path d="M415 310 H650" class="wire"/><circle cx="520" cy="310" r="5" fill="#244a70"/>
<path d="M520 310 V355" class="wire"/><rect x="445" y="355" width="150" height="65" class="box"/>
<text x="465" y="382" class="t">10k || 1nF</text><text x="458" y="405" class="small">matched pair</text>
<path d="M520 420 V448" class="wire"/><text x="435" y="475" class="t">AGND_SENSE</text>
<polygon points="650,280 650,570 870,425" class="box"/>
<text x="665" y="320" class="h">+</text><text x="665" y="540" class="h">−</text>
<text x="687" y="415" class="h">OPA4197</text><text x="705" y="445" class="t">±12 V</text>
<text x="45" y="540" class="h">N_AC</text><path d="M130 535 H195" class="wire"/>
<rect x="195" y="515" width="220" height="40" class="box"/><text x="210" y="541" class="t">4 × 10k in series</text>
<path d="M415 535 H650" class="wire"/><circle cx="610" cy="535" r="5" fill="#244a70"/>
<path d="M610 535 V615 H710 M865 615 H940 V425 M870 425 H1070" class="wire"/>
<rect x="710" y="590" width="155" height="50" class="box"/><text x="723" y="620" class="t">10k || 1nF</text>
<circle cx="940" cy="425" r="5" fill="#244a70"/><text x="930" y="390" class="h">V_SENSE_x</text>
<rect x="1070" y="325" width="270" height="210" class="box"/>
<text x="1090" y="355" class="h">Output selection</text>
<text x="1090" y="385" class="small">NO = V_SENSE_x via 0Ω</text>
<text x="1090" y="415" class="small">NC = AGND_SENSE</text>
<text x="1090" y="445" class="small">COM = ADC V4 / V5 / V6</text>
<text x="1090" y="475" class="small">COM → 100k → AGND</text>
<text x="1090" y="505" class="small">Relay coil drive: see netlist</text>
<text x="45" y="665" class="h">H(s) = 0.25 / (1 + s · 10k · 1nF)     |     ±14 V phase → ±3.5 V ADC     |     firmware ×4</text>
<text x="45" y="695" class="t">U1D bus channel: DC+ → 9×10k → BUS_DIV; BUS_DIV → (10k || 10nF) → AGND; follower → V7.</text>
<text x="45" y="725" class="small">All gain/divider resistors: 10k 0.01% ≤5ppm/°C. 1nF pair matching ≤0.1%. Supplies/decoupling/bleeders: see design note.</text>
<rect x="30" y="750" width="1340" height="125" rx="8" class="warn"/>
<text x="50" y="780" class="h">Release gates: actual ADC network + rail-loss/relay timing + low-current contacts + alias/loop tests + CAD review</text>
<text x="50" y="810" class="t">15.9 kHz pole is NOT adequate anti-alias proof at 10 kSPS. Default-ground relay is NOT instantaneous protection.</text>
<text x="50" y="840" class="t">No invented module header pins. No bus energization, firmware flag changes or hardware PASS claimed.</text>
</svg>'''
ET.fromstring(svg)
(ROOT/'sensing_overview.svg').write_text(svg,encoding='utf-8')
assert len([r for r in connections if r[2]=='10k_0.01%']) == 40
assert len([r for r in connections if r[0].startswith('U1.')]) == 14
assert len({r[0] for r in connections}) == len(connections)
print(f'Exported {len(bom)} BoM groups, {len(connections)} logical connections, and schematic overview SVG.')


if __name__ == '__main__':
    pass
