function report = run_stage5i_load_cycle(maxStep,label,stopTime)
% Build and run an isolated 11 s load increase/removal copy of saved Stage 5i.
% MATLAB R2018b. Original model and open user sessions are never saved here.
if nargin<1; maxStep=2.5e-6; end
if nargin<2; label='nominal'; end
if nargin<3; stopTime=11; end
validateattributes(maxStep,{'numeric'},{'scalar','real','finite','positive'});
assert(ischar(label) && ~isempty(regexp(label,'^[a-zA-Z0-9_]+$','once')));
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5i_load_cycle');
if ~exist(folder,'dir'); mkdir(folder); end
source=fullfile(root,'validation_outputs','stage5i','vsg_stage5i_secondary.slx');
model='vsg_stage5i_load_cycle';
modelPath=fullfile(folder,[model '.slx']);
sourceHash=fileHash(source);
assert(~bdIsLoaded(model),'Load-cycle model is already open; use an isolated MATLAB process.');
oldPath=path;
pathCleanup=onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(folder);
vsg_backup_output(modelPath);
copyfile(source,modelPath);
load_system(modelPath);
closeCleanup=onCleanup(@() close_system(model,0)); %#ok<NASGU>
mw=get_param(model,'ModelWorkspace');
assignin(mw,'load_increase_time_s',3);
assignin(mw,'load_removal_time_s',7);
assignin(mw,'secondary_enable',1);

% SID 223 is the actual original 0 -> 1 load-bypass command. Preserve all
% three electrical breaker terminals and their destination input ports.
stepPath=Simulink.ID.getFullName([model ':223']);
plant=get_param(stepPath,'Parent');
stepPorts=get_param(stepPath,'PortHandles');
oldLine=get_param(stepPorts.Outport,'Line');
destinations=get_param(oldLine,'DstPortHandle');
assert(numel(destinations)==3,'Expected exactly three load-breaker destinations.');
set_param(stepPath,'Time','load_increase_time_s','Before','0','After','1','Name','Load_Increase_3s');
delete_line(oldLine);
fall=add_block('built-in/Step',[plant '/Load_Removal_7s'], ...
    'Time','load_removal_time_s','Before','0','After','-1','SampleTime','0', ...
    'Position',[2030 270 2130 310]);
sumBlock=add_block('built-in/Sum',[plant '/Load_Cycle_Command'], ...
    'Inputs','++','Position',[2200 185 2230 235]);
sumPorts=get_param(sumBlock,'PortHandles');
fallPorts=get_param(fall,'PortHandles');
add_line(plant,stepPorts.Outport,sumPorts.Inport(1),'autorouting','on');
add_line(plant,fallPorts.Outport,sumPorts.Inport(2),'autorouting','on');
for k=1:numel(destinations)
    add_line(plant,sumPorts.Outport,destinations(k),'autorouting','on');
end
commandLog=add_block('built-in/ToWorkspace',[plant '/Log_Load_Command'], ...
    'VariableName','load_command_ts','SaveFormat','Timeseries', ...
    'MaxDataPoints','inf','SampleTime','1e-4', ...
    'Position',[2320 190 2500 230]);
logPorts=get_param(commandLog,'PortHandles');
add_line(plant,sumPorts.Outport,logPorts.Inport,'autorouting','on');

% Preserve every physical and controller block. Limit only unused diagnostic
% sinks to their final point to avoid storing redundant GB-scale raw traces.
vars={'Vload_abc_ts','iload_abc_ts','sec_freq_Hz_ts','P_ts','Q_ts', ...
    'sec_P_ref_pu_ts','sec_delta_P_pu_ts','sec_clamp_state_ts', ...
    'load_command_ts'};
names={'Vload_abc','iload_abc','freq','P_meas','Q_meas', ...
    'sec_P_ref_pu','sec_delta_P_pu','sec_clamp_state','load_command'};
logs=find_system(model,'LookUnderMasks','all','FollowLinks','off','BlockType','ToWorkspace');
limited={};
for k=1:numel(logs)
    varName=get_param(logs{k},'VariableName');
    if ~any(strcmp(varName,vars))
        set_param(logs{k},'MaxDataPoints','1');
        limited{end+1}=varName; %#ok<AGROW>
    elseif any(strcmp(varName,{'Vload_abc_ts','iload_abc_ts'}))
        set_param(logs{k},'SampleTime','5e-6');
    end
end
annotations=find_system(model,'FindAll','on','Type','annotation');
for k=1:numel(annotations)
    text=get_param(annotations(k),'Name');
    if strcmp(text,'RL LOAD + BYPASS AT 1 s')
        set_param(annotations(k),'Name','RL LOAD | INCREASE 3 s / RETURN 7 s');
    end
end
set_param(model,'StopTime','11','MaxStep',num2str(maxStep,16), ...
    'ReturnWorkspaceOutputs','on','SaveTime','off','SaveOutput','off', ...
    'SaveState','off','SignalLogging','off');
save_system(model,modelPath);
modelHash=fileHash(modelPath);
runnerHash=fileHash([mfilename('fullpath') '.m']);
fprintf('STAGE5I_LOAD_CYCLE_BUILT: %s\n',modelPath);

in=Simulink.SimulationInput(model);
in=in.setModelParameter('StopTime',num2str(stopTime,16),'MaxStep',num2str(maxStep,16), ...
    'ReturnWorkspaceOutputs','on');
tic;
out=sim(in);
elapsed=toc;
signals=struct();
for k=1:numel(names)
    ts=out.get(vars{k});
    d=ts.Data;
    if ~ts.IsTimeFirst; d=permute(d,[ndims(d),1:ndims(d)-1]); end
    signals.(names{k})=struct('time',ts.Time(:),'data',reshape(d,numel(ts.Time),[]));
end
clear out ts d;
report=struct('model_file',modelPath,'model_sha256',modelHash, ...
    'source_model_file',source,'source_model_sha256',sourceHash, ...
    'runner_file',[mfilename('fullpath') '.m'],'runner_sha256',runnerHash, ...
    'stop_time_s',stopTime,'maximum_step_s',maxStep,'wall_seconds',elapsed, ...
    'secondary_enable',1,'load_increase_time_s',3,'load_removal_time_s',7, ...
    'load_R_low_demand_ohm',2.94,'load_R_high_demand_nominal_ohm',2.058, ...
    'load_L_H',0.001,'DC_voltage_V',40,'V_set_phase_peak_V',14, ...
    'retained_signal_names',{names},'unused_logs_limited_to_final_point',{limited}, ...
    'frequency_definition','Internal virtual rotor omega/(2*pi), not an independent terminal-frequency estimate', ...
    'P_meas_definition','Original controller P measurement based on filter-inductor current; not load-only power', ...
    'scope','Simulation stress case; high demand around 136 W exceeds the 100 W nominal hardware target. No hardware qualification.', ...
    'gate_order','AH AL BH BL CH CL','voltage_current_logging_sample_time_s',5e-6, ...
    'gate_screen_available',false, ...
    'logging_scope','Output waveforms sampled at 200 kHz for RMS/power; raw gate/deadtime/DC pulse logging omitted to bound memory.');
finite=true; timeValid=true; complete=true;
for k=1:numel(names)
    s=signals.(names{k});
    finite=finite && ~isempty(s.data) && all(isfinite(s.data(:)));
    timeValid=timeValid && all(isfinite(s.time)) && all(diff(s.time)>=0);
    complete=complete && s.time(1)<=1e-9 && s.time(end)>=stopTime-1e-8;
end
report.all_signals_finite=finite;
report.time_axes_valid=timeValid;
report.all_logs_cover_requested_run=complete;
report.voltage_current_time_axes_identical=isequal(signals.Vload_abc.time,signals.iload_abc.time);
assert(size(signals.Vload_abc.data,2)==3 && size(signals.iload_abc.data,2)==3);
ct=signals.load_command.time; command=signals.load_command.data;
expected=double(ct>=3-1e-12 & ct<7-1e-12);
report.load_command_protocol=all(command==expected);
edges=find(diff(command)~=0)+1;
report.load_command_transition_times_s=ct(edges)';
report.load_command_transition_values=command(edges)';
expectedEvents=[3;7]; expectedValues=[1;0];
selectEvents=expectedEvents<=stopTime;
expectedEvents=expectedEvents(selectEvents); expectedValues=expectedValues(selectEvents);
report.load_command_exact_events=isequal(command(edges),expectedValues) ...
    && numel(edges)==numel(expectedEvents) && all(abs(ct(edges)-expectedEvents)<1e-10);
correction=signals.sec_delta_P_pu.data;
report.secondary_correction_min_pu=min(correction);
report.secondary_correction_max_pu=max(correction);
report.secondary_within_limits=all(correction>=-0.5-1e-12 & correction<=0.8+1e-12);
report.secondary_clamp_active_samples=sum(signals.sec_clamp_state.data~=0);
report.execution_pass=finite && timeValid && complete && report.secondary_within_limits ...
    && report.load_command_protocol && report.load_command_exact_events;
report.operating_validation='RMS, power, and frequency dynamics are evaluated independently from saved raw waveforms.';
resultPath=fullfile(folder,['results_' label '.mat']);
reportPath=fullfile(folder,['report_' label '.json']);
vsg_backup_output(resultPath); vsg_backup_output(reportPath);
save(resultPath,'signals','report','-v7.3');
fid=fopen(reportPath,'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(report)); fclose(fid);
assert(strcmp(fileHash(source),sourceHash),'Original Stage 5i source changed during execution.');
fprintf('STAGE5I_LOAD_CYCLE_COMPLETE: %s\n',jsonencode(report));
end

function hex=fileHash(file)
fid=fopen(file,'rb'); assert(fid>=0);
bytes=fread(fid,Inf,'*uint8'); fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(bytes);
digest=typecast(md.digest(),'uint8');
hex=lower(reshape(dec2hex(digest,2).',1,[]));
end
