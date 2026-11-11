function info = build_stage5j(P,label,varargin)
% BUILD_STAGE5J  Stage 5j model: 48 V battery bus (variable), 12 Vrms, SVPWM
% (min-max zero-sequence injection) with measured-Vdc feed-forward, 20 kHz
% carrier, duty clamp and voltage soft-start.  MATLAB R2018b.
%
%   P = vsg_stage5j_params();  build_stage5j(P,'nominal');
%   -> validation_outputs/stage5j/vsg_stage5j_nominal.slx   ('open',true opens it)
%
% Source = the E1.2 FF islanded model, taken through apply_vsg_params (never
% modified): all Stage 5i / E1.2 control blocks, gains and the electrical
% network are inherited. Changes made here, and nothing else:
%   1. Modulator (new subsystem SVPWM_MinMax_Vdc_FF, 10 kHz, before the existing
%      one-sample Delay_V_x_ref):
%        v0 = -(max(v_abc)+min(v_abc))/2
%        duty_x = sat(0.5 + (v_x + v0)/Vdc_sampled, duty_min, duty_max)
%      Vdc_sampled = ZOH(Measured_DC_rail, 100 us), floored at 10 V.
%      The signals tagged V_x_ref now carry DUTY (0..1), not volts.
%   2. Carrier: triangle 0..1 at vsg_fsw (was +/-20 V at 10 kHz). It starts at
%      its valley, so the 10 kHz controller samples stay on carrier valleys.
%   3. DC source: Controlled Voltage Source driven by a time profile
%      (vsg_Vdc_t, vsg_Vdc_v) instead of the fixed DC Voltage Source.
%   4. Voltage setpoint multiplied by a 0 -> 1 ramp of vsg_t_softstart.
%   5. Logs: duty, sampled Vdc (10 kHz); last 60000 solver points of i_L, I_dc
%      and the DC rail for ripple and DC power.
% Not modelled: battery impedance / DC-link capacitor (stiff bus), Vdc sensing
% filter and ADC scaling, current limit, PI anti-windup, gate-driver bootstrap.
opt=struct('open',false);
for k=1:2:numel(varargin); opt.(varargin{k})=varargin{k+1}; end
assert(isstruct(P) && isfield(P,'base') && isfield(P,'derived'),'Pass the struct returned by vsg_stage5j_params().');
assert(ischar(label) && ~isempty(regexp(label,'^[a-zA-Z0-9_]{1,30}$','once')),'label: letters, digits, _ (max 30).');

root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5j');
if ~exist(folder,'dir'); mkdir(folder); end
model=['vsg_stage5j_' label];
modelPath=fullfile(folder,[model '.slx']);
if bdIsLoaded(model); close_system(model,0); end

% ---- parametric E1.2 copy from the tested helper, then move it into stage5j
[~,baseInfo]=evalc('apply_vsg_params(P.base,[''s5j_'' label])');
if exist(modelPath,'file'); vsg_backup_output(modelPath); end
copyfile(baseInfo.model_file,modelPath);
delete(baseInfo.model_file);                                  % intermediate, just created
tmpJson=fullfile(fileparts(baseInfo.model_file),[baseInfo.model '_params.json']);
if exist(tmpJson,'file'); delete(tmpJson); end
load_system(modelPath);
if ~opt.open; cl=onCleanup(@() close_system(model,0)); end %#ok<NASGU>
load_system('powerlib'); load_system('simulink');

mw=get_param(model,'ModelWorkspace');
assignin(mw,'vsg_fsw',P.fsw);
assignin(mw,'vsg_duty_min',P.duty_min);
assignin(mw,'vsg_duty_max',P.duty_max);
assignin(mw,'vsg_Vdc_t',P.Vdc_t);
assignin(mw,'vsg_Vdc_v',P.Vdc_v);
assignin(mw,'vsg_Vdc_floor',10);
assignin(mw,'vsg_t_softstart',P.t_softstart);
evalin(mw,'clear vsg_Vdc');                                   % replaced by the profile
Ts='1e-4';
assert(strcmp(get_param([model '/Delay_V_a_ref'],'SampleTime'),'0.0001'),'Unexpected controller sample time.');

% ---- 1. SVPWM subsystem between From_V_x_ref_now and Delay_V_x_ref
dpos=get_param([model '/Delay_V_b_ref'],'Position');
sv=[model '/SVPWM_MinMax_Vdc_FF'];
add_block('built-in/SubSystem',sv,'Position',[dpos(1)-60 dpos(2)-420 dpos(1)+120 dpos(2)-260]);
inN={'v_a_ref_V','v_b_ref_V','v_c_ref_V','Vdc_measured'};
for k=1:4
    add_block('built-in/Inport',[sv '/' inN{k}],'Port',num2str(k),'Position',[30 60+70*k 60 76+70*k]);
end
mx=add_block('built-in/Mux',[sv '/v_abc'],'Inputs','3','Position',[130 110 136 290]);
vmax=add_block('built-in/MinMax',[sv '/max_abc'],'Function','max','Inputs','1','Position',[190 140 230 170]);
vmin=add_block('built-in/MinMax',[sv '/min_abc'],'Function','min','Inputs','1','Position',[190 230 230 260]);
sm=add_block('built-in/Sum',[sv '/max_plus_min'],'Inputs','++','Position',[270 180 295 220]);
g0=add_block('built-in/Gain',[sv '/v0_zero_sequence'],'Gain','-0.5','Position',[330 185 390 215]);
zoh=add_block('built-in/ZeroOrderHold',[sv '/Vdc_sample_10kHz'],'SampleTime',Ts,'Position',[130 335 170 365]);
flo=add_block('built-in/Saturate',[sv '/Vdc_floor'],'UpperLimit','inf','LowerLimit','vsg_Vdc_floor','Position',[210 335 250 365]);
dmx=add_block('built-in/Mux',[sv '/duty_abc'],'Inputs','3','Position',[760 110 766 290]);
for k=1:3; L(sv,[sv '/' inN{k}],1,mx,k); end
L(sv,mx,1,vmax,1); L(sv,mx,1,vmin,1); L(sv,vmax,1,sm,1); L(sv,vmin,1,sm,2); L(sv,sm,1,g0,1);
L(sv,[sv '/Vdc_measured'],1,zoh,1); L(sv,zoh,1,flo,1);
ph='abc';
for k=1:3
    y=430+90*(k-1);
    m3=add_block('built-in/Mux',[sv '/v_v0_Vdc_' ph(k)],'Inputs','3','Position',[470 y 476 y+60]);
    fc=add_block('built-in/Fcn',[sv '/duty_raw_' ph(k)],'Expr','0.5 + (u(1)+u(2))/u(3)','Position',[510 y+15 650 y+45]);
    st=add_block('built-in/Saturate',[sv '/duty_clamp_' ph(k)],'UpperLimit','vsg_duty_max','LowerLimit','vsg_duty_min','Position',[680 y+15 720 y+45]);
    op=add_block('built-in/Outport',[sv '/duty_' ph(k)],'Port',num2str(k),'Position',[850 y+22 880 y+38]);
    L(sv,[sv '/' inN{k}],1,m3,1); L(sv,g0,1,m3,2); L(sv,flo,1,m3,3);
    L(sv,m3,1,fc,1); L(sv,fc,1,st,1); L(sv,st,1,op,1); L(sv,st,1,dmx,k);
end
opV=add_block('built-in/Outport',[sv '/Vdc_sampled'],'Port','4','Position',[850 342 880 358]);
L(sv,flo,1,opV,1);
t1=add_block('built-in/ToWorkspace',[sv '/Log_duty_abc'],'VariableName','s5j_duty_abc_ts','SaveFormat','Structure With Time', ...
    'MaxDataPoints','inf','SampleTime',Ts,'Position',[800 185 940 215]);
t2=add_block('built-in/ToWorkspace',[sv '/Log_Vdc_sampled'],'VariableName','s5j_Vdc_s_ts','SaveFormat','Structure With Time', ...
    'MaxDataPoints','inf','SampleTime',Ts,'Position',[300 385 440 415]);
L(sv,dmx,1,t1,1); L(sv,flo,1,t2,1);
note=Simulink.Annotation([sv '/SVPWM min-max, 10 kHz: v0 = -0.5*(max+min); duty = sat(0.5 + (v_x + v0) : Vdc_sampled)']);
note.Position=[130 40];

for k=1:3
    fromBlk=[model '/From_V_' ph(k) '_ref_now']; delayBlk=[model '/Delay_V_' ph(k) '_ref'];
    dp=get_param(delayBlk,'PortHandles'); oldLine=get_param(dp.Inport,'Line');
    assert(strcmp(getfullname(get_param(oldLine,'SrcBlockHandle')),fromBlk),'Delay_V_x_ref must be fed by From_V_x_ref_now.');
    delete_line(oldLine);
    L(model,fromBlk,1,sv,k); L(model,sv,k,delayBlk,1);
end
spos=get_param(sv,'Position');
fv=add_block('built-in/From',[model '/S5J_From_Vdc_measured'],'GotoTag','Vdc_measured','Position',[spos(1)-200 spos(4)-30 spos(1)-80 spos(4)-6]);
L(model,fv,1,sv,4);
term=add_block('built-in/Terminator',[model '/S5J_Vdc_sampled_unused'],'Position',[spos(3)+60 spos(4)-25 spos(3)+80 spos(4)-5]);
L(model,sv,4,term,1);

% ---- 2. carrier: 0..1 triangle at vsg_fsw, valley at t = 0
set_param([model '/Carrier'],'rep_seq_t','[0 0.5/vsg_fsw 1/vsg_fsw]','rep_seq_y','[0 1 0]');

% ---- 3. DC source -> controlled source with a time profile
pl=[model '/Gate_Driver_and_MOSFET_Circuit'];
old=[pl '/DC_40V'];
before=physPorts(old);
replace_block(pl,'Name','DC_40V','powerlib/Electrical Sources/Controlled Voltage Source','noprompt');
src=[pl '/DC_40V'];
assert(strcmp(get_param(src,'MaskType'),'Controlled Voltage Source'),'DC source was not replaced.');
set_param(src,'Initialize','off');
% R2018b powerlib: both sources have LConn1 = minus, RConn1 = plus (run_vsg_stiff_source.m,
% build_stage5h_mosfet.m). replace_block keeps the plus terminal but the minus port
% sits 15 px further right on the new block, so its line is left open: rejoin the
% minus node at the DC reference. run_stage5j checks the sign from the measured rail.
sh=get_param(src,'PortHandles'); gh=get_param([pl '/DC_Reference'],'PortHandles');
assert(get_param(sh.LConn(1),'Line')==-1 && get_param(sh.RConn(1),'Line')~=-1,'Unexpected DC source wiring after replacement.');
add_line(pl,sh.LConn(1),gh.LConn(1),'autorouting','on');
after=physPorts(src);
assert(isequal(before,after),'DC source terminals changed during replacement:\n%s\n%s',strjoin(before,' | '),strjoin(after,' | '));
set_param(src,'Name','DC_Battery_Bus'); src=[pl '/DC_Battery_Bus'];
p=get_param(src,'Position');
clk=add_block('built-in/Clock',[pl '/Bus_Clock'],'Position',[p(1)-330 p(2)-90 p(1)-300 p(2)-60]);
lut=add_block('simulink/Lookup Tables/1-D Lookup Table',[pl '/Bus_Voltage_Profile_V'], ...
    'BreakpointsForDimension1','vsg_Vdc_t','Table','vsg_Vdc_v','ExtrapMethod','Clip', ...
    'Position',[p(1)-250 p(2)-100 p(1)-150 p(2)-50]);
L(pl,clk,1,lut,1); L(pl,lut,1,src,1);

% ---- 4. soft-start on the voltage setpoint
sumBlk=[model '/Sum_Vdref']; vset=[model '/V_set'];
sp=get_param(sumBlk,'PortHandles'); oldLine=get_param(sp.Inport(1),'Line');
assert(strcmp(getfullname(get_param(oldLine,'SrcBlockHandle')),vset),'Sum_Vdref input 1 must be V_set.');
delete_line(oldLine);
vp=get_param(vset,'Position');
dc=add_block('simulink/Sources/Digital Clock',[model '/S5J_SoftStart_Clock'],'SampleTime',Ts,'Position',[vp(1)-260 vp(2)-70 vp(1)-200 vp(2)-40]);
gr=add_block('built-in/Gain',[model '/S5J_SoftStart_Rate'],'Gain','1/max(vsg_t_softstart,1e-4)','Position',[vp(1)-170 vp(2)-70 vp(1)-90 vp(2)-40]);
sr=add_block('built-in/Saturate',[model '/S5J_SoftStart_0_to_1'],'UpperLimit','1','LowerLimit','0','Position',[vp(1)-60 vp(2)-70 vp(1)-20 vp(2)-40]);
pr=add_block('built-in/Product',[model '/S5J_V_set_ramped'],'Inputs','2','Position',[vp(3)+25 vp(2)-45 vp(3)+55 vp(2)-5]);
L(model,dc,1,gr,1); L(model,gr,1,sr,1); L(model,sr,1,pr,1); L(model,vset,1,pr,2); L(model,pr,1,sumBlk,1);

% ---- 5. logs for ripple / DC power: keep the last points only
tail={'iL_abc_ts','I_dc_ts','Vdc_measured_ts'};
tws=find_system(model,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace');
found=0;
for k=1:numel(tws)
    if any(strcmp(get_param(tws{k},'VariableName'),tail))
        set_param(tws{k},'MaxDataPoints','60000','SaveFormat','Structure With Time'); found=found+1;
    end
end
assert(found==numel(tail),'Expected tail logs not found.');

note=Simulink.Annotation([model '/Stage 5j: 48 V battery bus (profile), 12 Vrms, SVPWM min-max with measured Vdc, carrier vsg_fsw. V_x_ref tags carry duty 0..1.']);
note.Position=[spos(1)-200 spos(2)-40];
set_param(model,'StopTime',num2str(P.stop_time,16));
set_param(model,'SimulationCommand','update');                % compile check
save_system(model,modelPath);

info=struct('model',model,'model_file',modelPath,'model_sha256',fileHash(modelPath), ...
    'source_model_file',baseInfo.source_model_file,'source_model_sha256',baseInfo.source_model_sha256, ...
    'builder_sha256',fileHash([mfilename('fullpath') '.m']), ...
    'params',rmfield(P.base,{'derived','warnings'}), ...
    'stage5j',struct('Vdc_t',P.Vdc_t,'Vdc_v',P.Vdc_v,'fsw',P.fsw,'duty_min',P.duty_min,'duty_max',P.duty_max,'t_softstart',P.t_softstart), ...
    'derived',P.derived,'warnings',{P.warnings});
fid=fopen(fullfile(folder,[model '_params.json']),'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(info)); fclose(fid);
fprintf('STAGE5J_BUILT: %s\n',modelPath);
if opt.open; open_system(model); end
end

function L(sys,a,ai,b,bi)
pa=get_param(a,'PortHandles'); pb=get_param(b,'PortHandles');
add_line(sys,pa.Outport(ai),pb.Inport(bi),'autorouting','on');
end

function c=physPorts(blk)
% names of the blocks/ports on each physical terminal, order-independent
pc=get_param(blk,'PortConnectivity'); c={};
for k=1:numel(pc)
    if isempty(regexp(pc(k).Type,'^[LR]Conn','once')); continue; end
    names=cell(1,numel(pc(k).DstBlock));
    for j=1:numel(pc(k).DstBlock)
        names{j}=get_param(pc(k).DstBlock(j),'Name');
    end
    c{end+1}=[pc(k).Type ' ' strjoin(sort(names),',')]; %#ok<AGROW>
end
c=sort(c);
end

function hex=fileHash(file)
fid=fopen(file,'rb'); assert(fid>=0);
bytes=fread(fid,Inf,'*uint8'); fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest=typecast(md.digest(),'uint8');
hex=lower(reshape(dec2hex(digest,2).',1,[]));
end
