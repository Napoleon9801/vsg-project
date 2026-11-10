function info = apply_vsg_params(P,label,varargin)
% APPLY_VSG_PARAMS  Build a parametric copy of the E1.2 FF islanded VSG model.
%
%   P = vsg_params('H',10,'t_step_up',2,'t_step_down',5,'stop_time',8);
%   apply_vsg_params(P,'h10');            % -> validation_outputs/vsg_params/vsg_param_h10.slx
%   apply_vsg_params(P,'h10','open',true) % also opens it in Simulink
%
% The source model (validation_outputs/e12_ff_load_cycle/vsg_e12_ff_load_cycle.slx)
% is only copied, never modified. In the copy every adjustable value is a Model
% Workspace variable named vsg_* and every derived value is an expression of
% them, so you can also change e.g. vsg_H later in Model Explorer
% (Modeling > Model Explorer > Model Workspace) and press Run; nothing goes out
% of sync. Stop time is a normal model setting (toolbar).
% MATLAB R2018b.
opt=struct('open',false);
for k=1:2:numel(varargin); opt.(varargin{k})=varargin{k+1}; end
assert(isstruct(P) && isfield(P,'derived'),'Pass the struct returned by vsg_params().');
assert(ischar(label) && ~isempty(regexp(label,'^[a-zA-Z0-9_]{1,40}$','once')),'label: letters, digits, _ (max 40).');

root=fileparts(mfilename('fullpath'));
source=fullfile(root,'validation_outputs','e12_ff_load_cycle','vsg_e12_ff_load_cycle.slx');
folder=fullfile(root,'validation_outputs','vsg_params');
if ~exist(folder,'dir'); mkdir(folder); end
model=['vsg_param_' label];
modelPath=fullfile(folder,[model '.slx']);
sourceHash=fileHash(source);
if bdIsLoaded(model); close_system(model,0); end
if exist(modelPath,'file'); vsg_backup_output(modelPath); end
copyfile(source,modelPath);
load_system(modelPath);
if ~opt.open; cl=onCleanup(@() close_system(model,0)); end %#ok<NASGU>

% ---- 1. inputs -> Model Workspace (vsg_*), drop the variables they replace
mw=get_param(model,'ModelWorkspace');
in={'Vdc','Vrms','f0','H','D','Rp','Dq','S','P_set_pu','Q_set','f_lpf_PQ', ...
    'R_load','L_load','R_step','t_step_up','t_step_down','secondary_on','secondary_Ki','ff_on'};
for k=1:numel(in); assignin(mw,['vsg_' in{k}],P.(in{k})); end
for v={'e12_ff_gain','e12_wCf','load_increase_time_s','load_removal_time_s','secondary_enable','secondary_Ki','secondary_f_ref_Hz'}
    evalin(mw,['clear ' v{1}]);
end

% ---- 2. blocks -> expressions
pl=[model '/Gate_Driver_and_MOSFET_Circuit'];
Cf=get_param([pl '/Rd_Cf_A'],'Capacitance');              % fixed design value, kept as is
ws='(2*pi*vsg_f0)';
Kpq=sprintf('(1e-4/(1/(2*pi*vsg_f_lpf_PQ)+1e-4))');       % Ts = 1e-4 s (fixed)
assert(strcmp(get_param([model '/LPF_P_meas'],'SampleTime'),'0.0001'),'Unexpected controller sample time.');
ch={};
ch=setp(ch,[pl '/DC_40V'],'Amplitude','vsg_Vdc');
ch=setp(ch,[model '/Carrier'],'rep_seq_y','[-vsg_Vdc/2 vsg_Vdc/2 -vsg_Vdc/2]');
ch=setp(ch,[model '/V_set'],'Value','vsg_Vrms*sqrt(2)');
ch=setp(ch,[model '/P_set'],'Value','vsg_P_set_pu');
ch=setp(ch,[model '/Q_set'],'Value','vsg_Q_set');
ch=setp(ch,[model '/P_to_pu'],'Gain','1/vsg_S');
for b={'omega_s_const','omega_s_d','omega_s_outer'}; ch=setp(ch,[model '/' b{1}],'Value',ws); end
ch=setp(ch,[model '/Int_omega'],'InitialCondition',ws);
ch=setp(ch,[model '/Gain_inv_2Hws'],'Gain',[ws '/(2*vsg_H)']);
ch=setp(ch,[model '/Gain_D'],'Gain','vsg_D');
ch=setp(ch,[model '/Gain_droop_pf'],'Gain',['-1/(vsg_Rp*' ws ')']);
ch=setp(ch,[model '/Gain_qv'],'Gain','-vsg_Dq');
for b={'LPF_P_meas','LPF_Q_meas'}
    ch=setp(ch,[model '/' b{1}],'Numerator',['[' Kpq ' 0]']);
    ch=setp(ch,[model '/' b{1}],'Denominator',['[1 ' Kpq '-1]']);
end
for ax='dq'
    ch=setp(ch,[model '/E12_ff_gain_' ax],'Gain','vsg_ff_on');
    ch=setp(ch,[model '/E12_wCf_' ax],'Gain',[ws '*' Cf]);
end
sec=[model '/Secondary_Frequency_Control'];
ch=setp(ch,[sec '/Frequency_reference_Hz'],'Value','vsg_f0');
ch=setp(ch,[sec '/Enable_after_startup'],'After','vsg_secondary_on');
ch=setp(ch,[sec '/Bounded_secondary_integrator'],'gainval','vsg_secondary_Ki');
ch=setp(ch,[pl '/Load_Increase_3s'],'Time','vsg_t_step_up');
ch=setp(ch,[pl '/Load_Removal_7s'],'Time','vsg_t_step_down');
set_param([pl '/Load_Increase_3s'],'Name','Load_Step_Up');      % times are now variables
set_param([pl '/Load_Removal_7s'],'Name','Load_Step_Down');
for ph='ABC'
    assert(strcmp(get_param([pl '/Load_RL_' ph],'BranchType'),'RL') && strcmp(get_param([pl '/Load_Extra_R_' ph],'BranchType'),'R'));
    ch=setp(ch,[pl '/Load_RL_' ph],'Resistance','vsg_R_load');
    ch=setp(ch,[pl '/Load_RL_' ph],'Inductance','vsg_L_load');
    ch=setp(ch,[pl '/Load_Extra_R_' ph],'Resistance','vsg_R_step');
end
set_param(model,'StopTime',num2str(P.stop_time,16));

% ---- 3. no other place may still hold a hard-coded 50 Hz / omega_s
left=find_system(model,'LookUnderMasks','none','BlockType','Constant','Value','314.1593');
assert(isempty(left),'Hard-coded omega_s still present: %s',strjoin(left',', '));

set_param(model,'SimulationCommand','update');          % compile check
save_system(model,modelPath);
assert(strcmp(fileHash(source),sourceHash),'Source model changed.');

info=struct('model',model,'model_file',modelPath,'source_model_file',source, ...
    'source_model_sha256',sourceHash,'model_sha256',fileHash(modelPath),'params',rmfield(P,{'derived','warnings'}), ...
    'derived',P.derived,'warnings',{P.warnings},'changes',{ch});
fid=fopen(fullfile(folder,[model '_params.json']),'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(info)); fclose(fid);
fprintf('VSG_PARAM_MODEL: %s (%d block parameters linked)\n',modelPath,numel(ch));
if opt.open; open_system(model); end
end

function ch=setp(ch,blk,param,expr)
old=get_param(blk,param);
set_param(blk,param,expr);
ch{end+1}=struct('block',blk,'param',param,'old',old,'new',expr);
end

function hex=fileHash(file)
fid=fopen(file,'rb'); assert(fid>=0);
bytes=fread(fid,Inf,'*uint8'); fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest=typecast(md.digest(),'uint8');
hex=lower(reshape(dec2hex(digest,2).',1,[]));
end
