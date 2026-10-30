function model = build_stage5h_mosfet
% Stage 5h: six gate-driven SPS MOSFETs, floating AC star, inherited 5d control.
% R2018b. Separate electrical extension; never overwrites Stage 5d.
% Device parameters are declared study assumptions, not a qualified IRF540N model.
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5h');
if ~exist(folder,'dir'); mkdir(folder); end
model='vsg_stage5h_mosfet';
target=fullfile(folder,[model '.slx']);
if bdIsLoaded(model); close_system(model,0); end
if exist(target,'file'); copyfile(target,[target '.backup_' datestr(now,'yyyymmdd_HHMMSS')]); end
open_system(fullfile(root,'validation_outputs','stage5d','vsg_stage5d.slx'));
save_system('vsg_stage5d',target);
load_system('powerlib');

% Delete only the behavioral bridge/plant; keep 5d control and logging intact.
remove={'Fp_Vinva_lc','Fp_Vinvb_lc','Fp_Vinvc_lc','Mux_Vinv_abc', ...
    'Fp_VL_lc','Fp_iL_lc','Gain_Rf_lc','Sum_diL','Gain_inv_Lf','Int_iL_abc', ...
    'Goto_iLabc','Fp_iload_C','Sum_iCf','Gain_inv_Cf','Int_VCf_abc','Gain_Rd', ...
    'Sum_Vload_abc','Goto_Vloadabc','R_load_step','Mux_Rload_vec', ...
    'Fp_iload_load','Prod_Rload_iload','Fp_Vload_load','Sum_diload', ...
    'Gain_inv_Lload','Int_iload_abc','Goto_iloadabc'};
for c='abc'
    remove=[remove,{['Fp_V' c 'ref'],['Fp_carr_' c],['Sum_pwm_' c], ...
        ['Sign_pwm_' c],['Gain_Vinv_' c],['Goto_Vinv_' c]}];
end
for k=1:numel(remove)
    found=find_system(model,'SearchDepth',1,'Name',remove{k});
    assert(numel(found)==1,'Expected one original block: %s',remove{k});
    handles=get_param(found{1},'LineHandles'); fields=fieldnames(handles);
    for j=1:numel(fields)
        lines=handles.(fields{j}); lines=lines(lines>0);
        for h=lines(:)'
            if ishandle(h); delete_line(h); end
        end
    end
    delete_block(found{1});
end

pg=add(model,'powerlib/powergui','powergui',2200,30,110,50);
set_param(pg,'SimulationMode','Continuous','frequency','50');
sys=add(model,'built-in/SubSystem','Gate_Driver_and_MOSFET_Circuit',2200,800,340,370);
sys=getfullname(sys);
inputs={'V_a_ref','V_b_ref','V_c_ref','V_carrier'};
for k=1:4
    add(sys,'built-in/Inport',inputs{k},20,45+40*k,30,18,'Port',num2str(k));
    f=add(model,'simulink/Signal Routing/From',['Electrical_' inputs{k}],1960,810+60*k,110,25,'GotoTag',inputs{k});
    signal(model,f,1,get_param(sys,'Handle'),k);
end

% Genuine electrical source, sensors, MOSFETs, passive components and breakers.
mos=find_system('powerlib','SearchDepth',2,'LookUnderMasks','all','FollowLinks','on','Name','Mosfet'); assert(numel(mos)==1);
dc=find_system('powerlib','SearchDepth',2,'LookUnderMasks','all','FollowLinks','on','Name','DC Voltage Source'); assert(numel(dc)==1);
src=add(sys,dc{1},'DC_40V',590,40,50,70,'Amplitude','40');
idc=add(sys,'powerlib/Measurements/Current Measurement','DC_Current',680,35,45,30);
gnd=add(sys,'powerlib/Elements/Ground','DC_Reference',600,145,30,25);
% R2018b SPS DC source has '-' on LConn and '+' on RConn (verified PMIOPort).
physical(sys,port(src,'RConn',1),port(idc,'LConn',1));
physical(sys,port(src,'LConn',1),port(gnd,'LConn',1));
plus=port(idc,'RConn',1); minus=port(src,'LConn',1);
vdc=add(sys,'powerlib/Measurements/Voltage Measurement','Measured_DC_rail',780,65,45,40);
physical(sys,plus,port(vdc,'LConn',1)); physical(sys,minus,port(vdc,'LConn',2));
step=add(sys,'simulink/Sources/Step','Load_Step_1s',1130,30,70,35, ...
    'Time','1','Before','0','After','1','SampleTime','0');
mV=add(sys,'simulink/Signal Routing/Mux','Vload_abc',1650,100,15,90,'Inputs','3');
mI=add(sys,'simulink/Signal Routing/Mux','iL_abc',1710,250,15,90,'Inputs','3');
mLoad=add(sys,'simulink/Signal Routing/Mux','iload_abc',1770,400,15,90,'Inputs','3');
mGate=add(sys,'simulink/Signal Routing/Mux','Gate_Order_AH_AL_BH_BL_CH_CL',1830,550,15,150,'Inputs','6');
mPole=add(sys,'simulink/Signal Routing/Mux','Pole_Voltage_abc',1890,760,15,90,'Inputs','3');
neutral=[]; vpA=[]; vds=[];
for k=1:3
    ph='ABC'; ph=ph(k); y=240+(k-1)*360;
    cmp=add(sys,'simulink/Logic and Bit Operations/Relational Operator',['PWM_' ph],100,y,65,40,'Operator','>');
    signal(sys,get_param([sys '/' inputs{k}],'Handle'),1,cmp,1);
    signal(sys,get_param([sys '/V_carrier'],'Handle'),1,cmp,2);
    not=add(sys,'simulink/Logic and Bit Operations/Logical Operator',['Complement_' ph],200,y+95,65,30,'Operator','NOT');
    signal(sys,cmp,1,not,1);
    gates=zeros(1,2);
    for side=1:2
        suffix=[ph num2str(side)]; yy=y+(side-1)*95;
        if side==1; req=cmp; else; req=not; end
        reset=add(sys,'simulink/Logic and Bit Operations/Logical Operator',['ResetTimer_' suffix],270,yy+35,45,25,'Operator','NOT');
        one=add(sys,'simulink/Sources/Constant',['One_' suffix],270,yy-35,35,20,'Value','1');
        timer=add(sys,'simulink/Continuous/Integrator',['HighTime_' suffix],335,yy,45,35, ...
            'ExternalReset','level','InitialCondition','0');
        threshold=add(sys,'simulink/Sources/Constant',['Deadtime_' suffix],335,yy+45,60,20,'Value','520e-9');
        ready=add(sys,'simulink/Logic and Bit Operations/Relational Operator',['DelayElapsed_' suffix],415,yy,45,35,'Operator','>=');
        gate=add(sys,'simulink/Logic and Bit Operations/Logical Operator',['Gate_' suffix],480,yy,55,35, ...
            'Operator','AND','Inputs','2');
        signal(sys,req,1,reset,1); signal(sys,one,1,timer,1); signal(sys,reset,1,timer,2);
        signal(sys,timer,1,ready,1); signal(sys,threshold,1,ready,2);
        signal(sys,req,1,gate,1); signal(sys,ready,1,gate,2);
        gates(side)=gate; signal(sys,gate,1,mGate,2*(k-1)+side);
    end
    high=add(sys,mos{1},['MOSFET_' ph '_HIGH'],690,y-25,60,70, ...
        'Orientation','down','Ron','0.044','Lon','0','Rd','0.01','Vfd','0.8', ...
        'IC','0','Rs','1e5','Cs','inf','Measurements','off');
    low=add(sys,mos{1},['MOSFET_' ph '_LOW'],690,y+110,60,70, ...
        'Orientation','down','Ron','0.044','Lon','0','Rd','0.01','Vfd','0.8', ...
        'IC','0','Rs','1e5','Cs','inf','Measurements','off');
    signal(sys,gates(1),1,high,1); signal(sys,gates(2),1,low,1);
    physical(sys,plus,port(high,'LConn',1));
    physical(sys,port(high,'RConn',1),port(low,'LConn',1));
    physical(sys,minus,port(low,'RConn',1));
    pole=port(high,'RConn',1);
    il=add(sys,'powerlib/Measurements/Current Measurement',['iL_' ph],810,y+40,45,35);
    filter=add(sys,'powerlib/Elements/Series RLC Branch',['Lf_Rf_' ph],900,y+40,95,35, ...
        'BranchType','RL','Resistance','0.05','Inductance','1.2e-3','SetiL0','on','InitialCurrent','0');
    rc=add(sys,'powerlib/Elements/Series RLC Branch',['Rd_Cf_' ph],1070,y+115,70,55, ...
        'Orientation','down','BranchType','RC','Resistance','1','Capacitance','10e-6','Setx0','on','InitialVoltage','0');
    loadI=add(sys,'powerlib/Measurements/Current Measurement',['iload_' ph],1180,y+40,45,35);
    rl=add(sys,'powerlib/Elements/Series RLC Branch',['Load_RL_' ph],1270,y+40,85,35, ...
        'BranchType','RL','Resistance','2.058','Inductance','1e-3','SetiL0','on','InitialCurrent','0');
    extra=add(sys,'powerlib/Elements/Series RLC Branch',['Load_Extra_R_' ph],1410,y+40,75,35, ...
        'BranchType','R','Resistance','0.882');
    bypass=add(sys,'powerlib/Elements/Breaker',['Bypass_Extra_R_' ph],1410,y+135,75,35, ...
        'InitialState','0','External','on','BreakerResistance','0.001', ...
        'SnubberResistance','1e6','SnubberCapacitance','inf');
    physical(sys,pole,port(il,'LConn',1)); physical(sys,port(il,'RConn',1),port(filter,'LConn',1));
    node=port(filter,'RConn',1);
    physical(sys,node,port(rc,'LConn',1)); physical(sys,node,port(loadI,'LConn',1));
    physical(sys,port(loadI,'RConn',1),port(rl,'LConn',1));
    physical(sys,port(rl,'RConn',1),port(extra,'LConn',1));
    physical(sys,port(extra,'LConn',1),port(bypass,'LConn',1));
    physical(sys,port(extra,'RConn',1),port(bypass,'RConn',1));
    physical(sys,port(rc,'RConn',1),port(extra,'RConn',1));
    if isempty(neutral); neutral=port(rc,'RConn',1); else; physical(sys,neutral,port(rc,'RConn',1)); end
    signal(sys,step,1,bypass,1);
    vm=add(sys,'powerlib/Measurements/Voltage Measurement',['Vphase_' ph],1550,y+30,45,40);
    physical(sys,node,port(vm,'LConn',1)); physical(sys,neutral,port(vm,'LConn',2));
    vp=add(sys,'powerlib/Measurements/Voltage Measurement',['Vpole_' ph],800,y+160,45,40);
    physical(sys,pole,port(vp,'LConn',1)); physical(sys,minus,port(vp,'LConn',2));
    signal(sys,vm,1,mV,k); signal(sys,il,1,mI,k);
    signal(sys,loadI,1,mLoad,k); signal(sys,vp,1,mPole,k);
    if k==1
        vpA=vp;
        vds=add(sys,'powerlib/Measurements/Voltage Measurement','Vds_A_HIGH',870,y-80,45,40);
        physical(sys,plus,port(vds,'LConn',1)); physical(sys,pole,port(vds,'LConn',2));
    end
end
vn=add(sys,'powerlib/Measurements/Voltage Measurement','N_AC_to_DCminus',1550,1180,45,40);
physical(sys,neutral,port(vn,'LConn',1)); physical(sys,minus,port(vn,'LConn',2));
outs={mV,mI,mLoad,vpA,mGate,idc,vn,mPole,vds,vdc};
tags={'V_load_abc','i_L_abc','i_load_abc','V_inv_a','gates_6','I_dc','V_neutral','V_pole_abc','Vds_A_high','Vdc_measured'};
for k=1:numel(outs)
    o=add(sys,'built-in/Outport',tags{k},2050,80+k*105,40,20,'Port',num2str(k));
    signal(sys,outs{k},1,o,1);
    g=add(model,'simulink/Signal Routing/Goto',['Electrical_out_' tags{k}],2700,780+55*k,120,25, ...
        'GotoTag',tags{k},'TagVisibility','global');
    signal(model,get_param(sys,'Handle'),k,g,1);
end
note=Simulink.Annotation(sys,['Six SPS MOSFETs: logic gate inputs, not an electrical IR2104 model.' char(10) ...
    'Deadtime assumption 520 ns; Ron=44 mOhm; diode Rd=10 mOhm/Vf=0.8 V.' char(10) ...
    'Numerical snubbers 100 kOhm. N_AC joins filter/load stars; no DC-minus bond.']);
note.Position=[100 10];

scopeTags={'gates_6','V_load_abc','i_L_abc','Vds_A_high'};
for k=1:numel(scopeTags)
    tag=scopeTags{k};
    f=add(model,'simulink/Signal Routing/From',['View_' tag],2200,1280+k*90,100,25,'GotoTag',tag);
    sc=add(model,'simulink/Sinks/Scope',['Scope_' tag],2400,1280+k*90,70,45);
    signal(model,f,1,sc,1);
end
newTags={'gates_6','I_dc','V_neutral','V_pole_abc','Vds_A_high','Vdc_measured'};
for k=1:numel(newTags)
    tag=newTags{k};
    f=add(model,'simulink/Signal Routing/From',['Log_' tag],2800,1250+k*75,100,25,'GotoTag',tag);
    tws=add(model,'simulink/Sinks/To Workspace',['LogOut_' tag],3000,1250+k*75,140,35, ...
        'VariableName',[tag '_ts'],'SaveFormat','Timeseries','MaxDataPoints','inf');
    signal(model,f,1,tws,1);
end
set_param(model,'Solver','ode23tb','StopTime','3','MaxStep','2.5e-6', ...
    'RelTol','1e-4','AbsTol','1e-6','ReturnWorkspaceOutputs','on');
save_system(model,target);
fprintf('STAGE5H_BUILD_OK: %s\n',target);
end

function h=add(sys,lib,name,x,y,w,hgt,varargin)
h=add_block(lib,[sys '/' name],'Position',[x y x+w y+hgt],varargin{:});
end
function h=port(block,kind,index)
p=get_param(block,'PortHandles'); h=p.(kind)(index);
end
function signal(sys,a,ai,b,bi)
add_line(sys,port(a,'Outport',ai),port(b,'Inport',bi),'autorouting','on');
end
function physical(sys,a,b)
add_line(sys,a,b,'autorouting','on');
end
