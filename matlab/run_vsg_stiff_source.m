function report = run_vsg_stiff_source(label,H,rocofHzPerS,stopTime,maxStep,ffGain,Lline)
% Stiff-source inertia test (SIMULATION-ONLY extension; the advisor-approved
% hardware baseline remains islanded). MATLAB R2018b.
%
% Source model : validation_outputs/e12_ff_load_cycle/vsg_e12_ff_load_cycle.slx
%                (Stage 5i switching model + E1.2 estimated load-current FF)
% Built copy   : validation_outputs/vsg_stiff_source/vsg_stiff_source.slx
%
% Changes vs source:
%   - stiff 3-phase source: three Controlled Voltage Sources in a FLOATING Y
%     (no zero-sequence path to DC-), 14 V peak, phase 0, frequency
%       f_g(t) = 50 Hz until t1, then ramp at rocof for T_ramp, then hold
%   - line per phase: R 0.05 ohm + L 1.4 mH (X ~ 0.15 pu on 100 VA / 2.94 ohm)
%     between the source and the PCC (load/Cf node), grid current measured
%   - P_set = 0.3 pu so that droop + inertial response stays near rating
%   - secondary frequency control OFF (it would fight the grid frequency)
%   - inertia H via Gain_inv_2Hws = omega_s/(2H); D, Rp, LPF, FF unchanged
%   - local RL load kept (low-demand state, events moved beyond stopTime)
% Expected: grid-side apparent inertia H_eff = H + K*tf/2 (K=177.08, tf=31.8 ms).
if nargin<1; label='smoke'; end
if nargin<2; H=5; end
if nargin<3; rocofHzPerS=-0.25; end
if nargin<4; stopTime=2.6; end
if nargin<5; maxStep=2.5e-6; end
if nargin<6; ffGain=1; end
if nargin<7; Lline=1.4e-3; end
assert(ischar(label) && ~isempty(regexp(label,'^[a-zA-Z0-9_]+$','once')));
validateattributes(H,{'numeric'},{'scalar','real','finite','positive'});
Tramp=0.8; tHold=0.6; if stopTime>=5.5; tHold=2.0; end
t1=stopTime-Tramp-tHold;   % ramp 0.8 s, then hold before stop
Vpk=14; Pset=0.3; Rline=0.05;
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','vsg_stiff_source');
if ~exist(folder,'dir'); mkdir(folder); end
source=fullfile(root,'validation_outputs','e12_ff_load_cycle','vsg_e12_ff_load_cycle.slx');
model='vsg_stiff_source';
modelPath=fullfile(folder,[model '.slx']);
sourceHash=fileHash(source);
assert(~bdIsLoaded(model),'Stiff-source model already open; use an isolated MATLAB process.');
oldPath=path; pathCleanup=onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(folder);
if exist(modelPath,'file'); vsg_backup_output(modelPath); end
copyfile(source,modelPath);
load_system(modelPath);
closeCleanup=onCleanup(@() close_system(model,0)); %#ok<NASGU>

mw=get_param(model,'ModelWorkspace');
assignin(mw,'secondary_enable',0);
assignin(mw,'load_increase_time_s',1000);
assignin(mw,'load_removal_time_s',2000);
assignin(mw,'e12_ff_gain',ffGain);
ws=2*pi*50;
assert(strcmp(get_param([model '/P_set'],'BlockType'),'Constant'));
set_param([model '/P_set'],'Value',num2str(Pset,16));
assert(abs(str2double(get_param([model '/Gain_inv_2Hws'],'Gain'))-ws/10)<1e-3,'Unexpected inertia gain in source.');
set_param([model '/Gain_inv_2Hws'],'Gain',num2str(ws/(2*H),16));

plant=[model '/Gate_Driver_and_MOSFET_Circuit'];
clk=add_block('built-in/Clock',[plant '/Grid_Clock'],'Position',[60 1400 90 1430]);
% theta_g = 2*pi*(50 t + r/2 * clip(t-t1,0,T)^2 + r*T*max(t-t1-T,0))
pos=sprintf('((u-%.17g)+abs(u-%.17g))/2',t1,t1);
ramp=sprintf('((%s)+%.17g-abs((%s)-%.17g))/2',pos,Tramp,pos,Tramp);
after=sprintf('((u-%.17g)+abs(u-%.17g))/2',t1+Tramp,t1+Tramp);
theta=sprintf('2*pi*(50*u+0.5*(%.17g)*(%s)^2+(%.17g)*(%.17g)*(%s))',rocofHzPerS,ramp,rocofHzPerS,Tramp,after);
fexpr=sprintf('50+(%.17g)*(%s)',rocofHzPerS,ramp);
fg=add_block('built-in/Fcn',[plant '/Grid_frequency_Hz'],'Expr',fexpr,'Position',[160 1460 360 1490]);
add_line(plant,[get_param(clk,'Name') '/1'],[get_param(fg,'Name') '/1'],'autorouting','on');
fgLog=add_block('built-in/ToWorkspace',[plant '/Log_grid_frequency'],'VariableName','grid_f_ts', ...
    'SaveFormat','Structure With Time','MaxDataPoints','inf','SampleTime','1e-4','Position',[420 1460 560 1490]);
add_line(plant,[get_param(fg,'Name') '/1'],[get_param(fgLog,'Name') '/1'],'autorouting','on');

shifts={'+0','-2*pi/3','+2*pi/3'}; ph='ABC';
lib='powerlib';
load_system(lib);
negPorts=zeros(1,3);
imux=add_block('built-in/Mux',[plant '/Grid_I_mux'],'Inputs','3','Position',[900 1380 905 1520]);
for k=1:3
    y=1300+130*(k-1);
    f=add_block('built-in/Fcn',[plant '/Grid_v' ph(k)], ...
        'Expr',sprintf('%.17g*cos(%s%s)',Vpk,theta,shifts{k}),'Position',[160 y 360 y+30]);
    add_line(plant,[get_param(clk,'Name') '/1'],[get_param(f,'Name') '/1'],'autorouting','on');
    src=add_block([lib '/Electrical Sources/Controlled Voltage Source'],[plant '/Grid_src_' ph(k)], ...
        'Position',[420 y-10 470 y+40]);
    try; set_param(src,'Initialize','off'); catch; end
    add_line(plant,[get_param(f,'Name') '/1'],[get_param(src,'Name') '/1'],'autorouting','on');
    ln=add_block([lib '/Elements/Series RLC Branch'],[plant '/Grid_line_' ph(k)], ...
        'BranchType','RL','Resistance',num2str(Rline),'Inductance',num2str(Lline),'Position',[540 y-5 600 y+35]);
    im=add_block([lib '/Measurements/Current Measurement'],[plant '/Grid_I_' ph(k)],'Position',[660 y-10 700 y+40]);
    sp=get_param(src,'PortHandles'); lp=get_param(ln,'PortHandles'); mp=get_param(im,'PortHandles');
    % Controlled Voltage Source polarity (R2018b powerlib): RConn1 = +, LConn1 = -.
    % Verified 2026-11-10 from smoke data: wiring LConn1 to the line gave
    % v_src = -14cos(theta) (corr -1.000), i.e. a 180 deg grid and 33 A fault-like flow.
    add_line(plant,sp.RConn(1),lp.LConn(1),'autorouting','on');
    add_line(plant,lp.RConn(1),mp.LConn(1),'autorouting','on');
    pccPorts=get_param([plant '/iload_' ph(k)],'PortHandles');
    add_line(plant,mp.RConn(1),pccPorts.LConn(1),'autorouting','on');
    mux=get_param(imux,'PortHandles');
    add_line(plant,mp.Outport(1),mux.Inport(k),'autorouting','on');
    negPorts(k)=sp.LConn(1);
    if k==1
        fprintf('CVS mask: %s\n',strjoin(get_param(src,'MaskNames')',', '));
    end
end
add_line(plant,negPorts(1),negPorts(2),'autorouting','on');
add_line(plant,negPorts(1),negPorts(3),'autorouting','on');
igLog=add_block('built-in/ToWorkspace',[plant '/Log_grid_current'],'VariableName','igrid_abc_ts', ...
    'SaveFormat','Structure With Time','MaxDataPoints','inf','SampleTime','5e-6','Position',[960 1430 1100 1470]);
mux=get_param(imux,'PortHandles'); igp=get_param(igLog,'PortHandles');
add_line(plant,mux.Outport(1),igp.Inport(1),'autorouting','on');

set_param(model,'StopTime',num2str(stopTime,16),'MaxStep',num2str(maxStep,16));
save_system(model,modelPath);
modelHash=fileHash(modelPath);
fprintf('STIFF_BUILT: %s H=%g rocof=%g Hz/s\n',modelPath,H,rocofHzPerS);

in=Simulink.SimulationInput(model);
in=in.setModelParameter('StopTime',num2str(stopTime,16),'MaxStep',num2str(maxStep,16),'ReturnWorkspaceOutputs','on');
tic; out=sim(in); elapsed=toc;
vars={'Vload_abc_ts','iload_abc_ts','igrid_abc_ts','grid_f_ts','sec_freq_Hz_ts','P_ts','Q_ts'};
names={'Vload_abc','iload_abc','igrid_abc','grid_f','freq','P_meas','Q_meas'};
signals=struct();
for k=1:numel(names)
    ts=out.get(vars{k});
    if isstruct(ts)
        tt=ts.time(:); d=ts.signals.values;
        if size(d,1)~=numel(tt); d=permute(d,[ndims(d),1:ndims(d)-1]); end
    else
        tt=ts.Time(:); d=ts.Data;
        if ~ts.IsTimeFirst; d=permute(d,[ndims(d),1:ndims(d)-1]); end
    end
    signals.(names{k})=struct('time',tt,'data',reshape(d,numel(tt),[]));
    clear ts d tt;
end
clear out;
finite=true; complete=true;
for k=1:numel(names)
    s=signals.(names{k});
    finite=finite && ~isempty(s.data) && all(isfinite(s.data(:)));
    complete=complete && s.time(end)>=stopTime-1e-8;
end
report=struct('label',label,'model_file',modelPath,'model_sha256',modelHash, ...
    'source_model_file',source,'source_model_sha256',sourceHash, ...
    'runner_sha256',fileHash([mfilename('fullpath') '.m']),'wall_seconds',elapsed, ...
    'H_s',H,'rocof_Hz_per_s',rocofHzPerS,'ramp_start_s',t1,'ramp_duration_s',Tramp, ...
    'grid_V_peak',Vpk,'P_set_pu',Pset,'line_R_ohm',Rline,'line_L_H',Lline, ...
    'secondary_enable',0,'ff_gain',ffGain,'stop_time_s',stopTime,'maximum_step_s',maxStep, ...
    'all_signals_finite',finite,'all_logs_cover_requested_run',complete, ...
    'expected_H_eff_s',H+177.08*0.031752/2, ...
    'scope','Simulation-only stiff-source extension; floating-Y ideal source; not a grid-connection design or hardware qualification.');
report.execution_pass=finite && complete;
resultPath=fullfile(folder,['results_' label '.mat']);
reportPath=fullfile(folder,['report_' label '.json']);
if exist(resultPath,'file'); vsg_backup_output(resultPath); end
if exist(reportPath,'file'); vsg_backup_output(reportPath); end
save(resultPath,'signals','report','-v7.3');
fid=fopen(reportPath,'w'); assert(fid>=0); fprintf(fid,'%s',jsonencode(report)); fclose(fid);
assert(strcmp(fileHash(source),sourceHash),'Source model changed during execution.');
fprintf('STIFF_COMPLETE: %s\n',jsonencode(report));
end

function hex=fileHash(file)
fid=fopen(file,'rb'); assert(fid>=0);
bytes=fread(fid,Inf,'*uint8'); fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest=typecast(md.digest(),'uint8');
hex=lower(reshape(dec2hex(digest,2).',1,[]));
end
