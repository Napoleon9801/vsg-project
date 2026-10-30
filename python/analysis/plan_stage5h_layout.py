"""Explicit presentation-only layout plan for the saved Stage 5h model."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(r'D:\workspace\engineering\vsg-project')
SOURCE = ROOT / 'matlab/validation_outputs/stage5h/vsg_stage5h_mosfet.slx'
with zipfile.ZipFile(SOURCE) as archive:
    doc = ET.fromstring(archive.read('simulink/blockdiagram.xml'))
root = doc.find('Model/System')
plant = next(b for b in root.findall('Block') if b.get('Name') == 'Gate_Driver_and_MOSFET_Circuit').find('System')
plans = []

def scope_plan(system, scope):
    blocks = {b.get('Name'): b for b in system.findall('Block')}
    used = set()
    nets=[]
    for line in system.findall('Line'):
        physical=line.get('LineType')=='Connection'
        sources=[e.text for e in line.iter('P') if e.get('Name')=='Src']
        destinations=[e.text for e in line.iter('P') if e.get('Name')=='Dst']
        assert physical or len(sources)==1
        nets.append({'physical':physical,'ports':sources+destinations})
    plan = {'scope': scope, 'blocks': [], 'headings': [], 'nets': nets}
    plans.append(plan)
    def put(name, x, y, w=110, h=32, color='white'):
        b = blocks[name]
        assert name not in used, name
        used.add(name)
        plan['blocks'].append({'sid': b.get('SID'), 'name': name,
                              'position': [x, y, x+w, y+h], 'color': color})
    def heading(text, x, y):
        plan['headings'].append({'text': text, 'position': [x,y]})
    def finish():
        assert used == set(blocks), sorted(set(blocks)-used)
    return put, heading, finish

p, title, done = scope_plan(root, '')
title('STAGE 5h  |  VSG CONTROL + SWITCHING MOSFET INVERTER\n40 V DC  /  50 Hz  /  Ts = 100 us  /  10 kHz PWM',50,20)
title('01  ACTIVE POWER / FREQUENCY / VIRTUAL ROTOR',50,130)
for name,x,y in [
 ('P_set',50,300),('From_omega_outer',50,200),('omega_s_outer',50,240),
 ('Sum_dev_outer',230,220),('Gain_droop_pf',390,220),('Sum_Pm',550,300),
 ('From_Pmeas_outer',230,400),('P_to_pu',390,400),('Sum_PmPe',710,315),
 ('Gain_D',710,220),('Sum_swing',870,315),('Gain_inv_2Hws',1030,315),
 ('Int_omega',1190,315),('Goto_omega',1370,315),('From_omega_d',1030,420),
 ('omega_s_d',1030,500),('Sum_dom',1190,470),('Int_delta',1370,470),
 ('Goto_delta',1530,470),('Int_theta',1370,390),('Goto_theta',1530,390),
 ('omega_s_const',50,500)]: p(name,x,y,color='[0.88 0.94 1]')
title('02  REACTIVE POWER / VOLTAGE DROOP',1830,130)
for n,x,y in [('Q_set',1830,200),('From_Qmeas',1830,280),('Sum_Qerr',2010,240),
 ('Gain_qv',2170,240),('V_set',2170,340),('Sum_Vdref',2330,280),('Goto_Vdref',2490,280)]:p(n,x,y,color='[0.88 0.94 1]')
title('LIVE SIGNALS  |  Double-click a Scope, then Run\nPWM channel order: AH, AL, BH, BL, CH, CL',2920,130)
for i,tag in enumerate(['gates_6','V_load_abc','i_L_abc','Vds_A_high']):
    p('View_'+tag,2920,230+90*i,150,32,'[0.88 1 0.88]')
    p('Scope_'+tag,3160,220+90*i,110,52,'[0.88 1 0.88]')
p('powergui',3550,200,160,70,'[1 0.96 0.8]')
title('03  VOLTAGE CONTROL  |  d / q',50,650)
for i,axis in enumerate('dq'):
    y=740+230*i
    p('From_Vdref_v' if axis=='d' else 'Vq_ref_zero',50,y,color='[0.88 0.94 1]')
    p('From_VL'+axis+'_v',50,y+85,color='[0.88 0.94 1]')
    p('Sum_V'+axis+'err',230,y+35,50,50)
    p('PI_V_'+axis,360,y+35,130,50,'[0.88 0.94 1]')
    p('Goto_i'+axis+'ref',570,y+45,130)
title('04  CURRENT CONTROL + DECOUPLING',850,650)
for i,a in enumerate('dq'):
    y=740+270*i; other='q' if a=='d' else 'd'
    for n,x,yy in [('From_i'+a+'ref',850,y),('From_iL'+a+'_c',850,y+80),
      ('Sum_i'+a+'err',1030,y+30),('PI_I_'+a,1190,y+30),
      ('From_omega_ff'+a,850,y+170),('From_iL'+other+'_ff'+a,1030,y+170),
      ('Prod_wLi'+other+'_'+a,1190,y+170),('Gain_Lf_'+a,1350,y+170),
      ('From_VL'+a+'_ff'+a,1350,y+100),('Sum_Vinv'+a+'_FF',1510,y+30),
      ('Goto_Vinv'+a,1680,y+30)]:p(n,x,yy,color='[0.88 0.94 1]')
title('05  INVERSE PARK + ONE-TICK DELAY',1930,650)
for i,n in enumerate(['From_Vinvd_p','From_Vinvq_p','From_theta_ip']):p(n,1930,740+80*i,130)
p('Mux_dqt_inv',2130,730,12,210)
for i,a in enumerate('abc'):
    y=745+90*i
    p('Fcn_V'+a+'_ref',2220,y,140)
    p('Goto_V'+a+'ref',2440,y,130)
    p('From_V_'+a+'_ref_now',1930,1060+85*i,145)
    p('Delay_V_'+a+'_ref',2220,1060+85*i,140,35,'[0.92 0.88 1]')
    p('Goto_V_'+a+'_ref_d',2440,1060+85*i,130)
p('Carrier',2730,1080,130,50,'[1 0.94 0.82]');p('Goto_carrier',2940,1090,140)
title('06  ELECTRICAL PLANT  |  Double-click to inspect MOSFETs',3300,650)
p('Gate_Driver_and_MOSFET_Circuit',3520,740,320,500,'[1 0.94 0.82]')
for i,n in enumerate(['V_a_ref','V_b_ref','V_c_ref','V_carrier']):p('Electrical_'+n,3290,800+100*i,155)
tags=['V_load_abc','i_L_abc','i_load_abc','V_inv_a','gates_6','I_dc','V_neutral','V_pole_abc','Vds_A_high','Vdc_measured']
for i,n in enumerate(tags):p('Electrical_out_'+n,3980,750+52*i,160,26)
title('07  VOLTAGE / CURRENT MEASUREMENT  |  abc -> dq',50,1410)
for i,(short,prefix) in enumerate([('VL','Vload'),('iL','iL')]):
    y=1500+280*i; start=50
    p('Fp_'+prefix+'_park',start,y,140)
    p('Demux_'+short,start+210,y-20,12,120)
    p('Fp_theta_'+short+'park',start,y+150,140)
    p('Mux_'+short+'_park',start+390,y-20,12,210)
    for k,a in enumerate('dq'):
        p('Fcn_'+short+a,start+490,y+100*k,150)
        p('Goto_'+short+a,start+720,y+100*k,150)
title('08  MEASURED ACTIVE / REACTIVE POWER',1080,1410)
for i,n in enumerate(['VLd','VLq','iLd','iLq']):p('Fp_'+n+'_p',1080,1500+90*i,130)
for i,n in enumerate(['Prod_VdId','Prod_VqIq','Prod_VqId','Prod_VdIq']):p(n,1310,1500+100*i,65,42)
for i,a in enumerate('PQ'):
    y=1550+220*i
    p('Sum_'+a+'inDQ',1480,y,65,50)
    p('Gain_3o2_'+a,1630,y,100,45)
    p('Goto_'+a,1800,y,115)
title('09  SAMPLED FEEDBACK + 5 Hz POWER FILTERS',2110,1410)
for i,(tag,stem) in enumerate([('V_load_d','Vload_d'),('V_load_q','Vload_q'),('i_L_d','iL_d'),('i_L_q','iL_q')]):
    y=1500+125*i
    p('From_'+tag+'_ct',2110,y,145)
    p('ZOH_'+tag,2340,y,130,35,'[0.92 0.88 1]')
    p('Goto_'+tag+'_s',2580,y,140)
    p('TWS_'+stem+'_ct_ts',2340,y+60,180,32,'[0.94 0.94 0.94]')
for i,a in enumerate('PQ'):
    y=1550+160*i
    p('From_'+a+'_meas_raw',2900,y,160)
    p('LPF_'+a+'_meas',3160,y,145,42,'[0.92 0.88 1]')
    p('Goto_'+a+'_meas_f',3410,y,155)
title('10  SAVED DATA  |  Workspace timeseries (separate from live Scopes)',50,2150)
lognames=['omega','delta','Vd_ref','Vload_d','Vload_q','iL_d','iL_q','Vload_abc','iL_abc','iload_abc','Vinv_a','P','Q']
for i,n in enumerate(lognames):
    col=i//5;row=i%5;x=50+780*col;y=2250+90*row
    p('FL_'+n+'_ts',x,y,170)
    p('TWS_'+n+'_ts',x+300,y,210,35,'[0.94 0.94 0.94]')
for i,n in enumerate(['gates_6','I_dc','V_neutral','V_pole_abc','Vds_A_high','Vdc_measured']):
    x=2450+(i//3)*850;y=2250+(i%3)*100
    p('Log_'+n,x,y,170)
    p('LogOut_'+n,x+300,y,210,35,'[0.94 0.94 0.94]')
done()

p,title,done=scope_plan(plant,'Gate_Driver_and_MOSFET_Circuit')
title('STAGE 5h  |  GATE COMMANDS -> SIX MOSFETS -> LC FILTER -> RL LOAD\nLogic gates include 520 ns turn-on delay; the driver is not an electrical Vgs model.',60,20)
title('DC SUPPLY  |  40 V',1100,100)
p('DC_40V',1100,180,60,80,'[1 0.94 0.82]')
p('DC_Current',1230,150,65,40)
p('DC_Reference',1100,320,35,30)
p('Measured_DC_rail',1410,190,65,50)
p('Load_Step_1s',2030,180,100,45,'[1 0.94 0.82]')
for i,n in enumerate(['V_a_ref','V_b_ref','V_c_ref','V_carrier']):p(n,60,140+65*i,60,20)
title('PWM + DEADTIME',230,400);title('HALF BRIDGE',1130,400)
title('FILTER + DAMPING',1440,400);title('RL LOAD + BYPASS AT 1 s',1960,400)
title('MEASUREMENTS / OUTPUTS',2650,400)
for k,a in enumerate('ABC'):
    base=500+600*k
    title('PHASE '+a,60,base-25)
    p('PWM_'+a,230,base+20,70,50,'[0.88 0.94 1]')
    p('Complement_'+a,230,base+250,70,40,'[0.88 0.94 1]')
    for side in (1,2):
        suffix=a+str(side);y=base+(side-1)*230
        p('One_'+suffix,390,y+15,45,25)
        p('ResetTimer_'+suffix,390,y+90,55,30)
        p('HighTime_'+suffix,540,y+20,70,50,'[0.92 0.88 1]')
        p('Deadtime_'+suffix,540,y+115,85,25,'[0.92 0.88 1]')
        p('DelayElapsed_'+suffix,720,y+30,65,50,'[0.92 0.88 1]')
        p('Gate_'+suffix,920,y+30,75,50,'[0.88 1 0.88]')
    p('MOSFET_'+a+'_HIGH',1160,base+25,75,90,'[1 0.94 0.82]')
    p('MOSFET_'+a+'_LOW',1160,base+300,75,90,'[1 0.94 0.82]')
    p('iL_'+a,1340,base+190,65,40)
    p('Lf_Rf_'+a,1490,base+190,120,40,'[1 0.94 0.82]')
    p('Rd_Cf_'+a,1680,base+310,75,90,'[1 0.94 0.82]')
    p('iload_'+a,1820,base+190,65,40)
    p('Load_RL_'+a,1980,base+190,120,40,'[1 0.94 0.82]')
    p('Load_Extra_R_'+a,2190,base+190,110,40,'[1 0.94 0.82]')
    p('Bypass_Extra_R_'+a,2190,base+350,110,40,'[1 0.94 0.82]')
    p('Vphase_'+a,2440,base+190,70,55)
    p('Vpole_'+a,1340,base+430,70,55)
p('Vds_A_HIGH',1320,520,70,55)
p('N_AC_to_DCminus',2440,2250,70,55)
for i,(mux,tag,count) in enumerate([('Vload_abc','V_load_abc',3),('iL_abc','i_L_abc',3),
 ('iload_abc','i_load_abc',3),('Gate_Order_AH_AL_BH_BL_CH_CL','gates_6',6),('Pole_Voltage_abc','V_pole_abc',3)]):
    y=520+300*i
    p(mux,2750,y,15,120 if count==3 else 200)
    p(tag,3070,y+50,65,22)
for i,tag in enumerate(['V_inv_a','I_dc','V_neutral','Vds_A_high','Vdc_measured']):p(tag,3070,2040+90*i,65,22)
title('N_AC: shared floating filter/load star; no direct connection to DC minus.',1530,2380)
done()
target=ROOT/'matlab/validation_outputs/stage5h/layout_plan_2026-10-30.json'
target.write_text(json.dumps(plans,indent=2),encoding='utf-8')
print(target)
print([(p['scope'],len(p['blocks'])) for p in plans])
