function report = run_stage5h_mosfet(stopTime,maxStep,label)
% Run an existing Stage 5h circuit, save inspectable signals and report.
% Defaults: full 3 s load-step experiment, 2.5 us maximum plant step.
if nargin<1; stopTime=3; end
if nargin<2; maxStep=2.5e-6; end
if nargin<3; label='nominal'; end
assert(~isempty(regexp(label,'^[a-zA-Z0-9_]+$','once')),'Invalid result label.');
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5h');
model='vsg_stage5h_mosfet'; path=fullfile(folder,[model '.slx']);
if ~exist(path,'file'); error('Build the model first with build_stage5h_mosfet.'); end
if ~bdIsLoaded(model); open_system(path); end
in=Simulink.SimulationInput(model);
in=in.setModelParameter('StopTime',num2str(stopTime,16),'MaxStep',num2str(maxStep,16), ...
    'ReturnWorkspaceOutputs','on');
tic; out=sim(in); elapsed=toc;
names={'omega','Vload_d','Vload_q','Vload_abc','iL_abc','iload_abc','P_meas','Q_meas', ...
    'gates_6','I_dc','V_neutral','V_pole_abc','Vds_A_high','Vdc_measured'};
vars={'omega_ts','Vload_d_ts','Vload_q_ts','Vload_abc_ts','iL_abc_ts','iload_abc_ts','P_ts','Q_ts', ...
    'gates_6_ts','I_dc_ts','V_neutral_ts','V_pole_abc_ts','Vds_A_high_ts','Vdc_measured_ts'};
signals=struct();
for k=1:numel(names)
    ts=out.get(vars{k}); d=ts.Data;
    if ~ts.IsTimeFirst; d=permute(d,[ndims(d),1:ndims(d)-1]); end
    signals.(names{k})=struct('time',ts.Time(:),'data',reshape(d,numel(ts.Time),[]));
end
signals.freq=struct('time',signals.omega.time,'data',signals.omega.data/(2*pi));
report=struct('stop_time_s',stopTime,'maximum_step_s',maxStep,'wall_seconds',elapsed, ...
    'scope','Six SPS MOSFET macro models; logical gates; floating AC star; no driver electrical or thermal qualification', ...
    'gate_order','AH AL BH BL CH CL','deadtime_requested_s',520e-9, ...
    'MOSFET_Ron_ohm',0.044,'diode_Rd_ohm',0.01,'diode_Vf_V',0.8, ...
    'numerical_snubber_R_ohm',1e5,'breaker_on_R_ohm',0.001, ...
    'Vinv_a_legacy_log_reference','A pole relative to DCminus, not the +/-20V Stage5d behavioral signal');
finite=true;
for k=1:numel(names)
    finite=finite && all(all(isfinite(signals.(names{k}).data)));
end
report.all_signals_finite=finite;
report.initial_iL_A=signals.iL_abc.data(1,:);
report.initial_load_voltage_V=signals.Vload_abc.data(1,:);
g=signals.gates_6.data>0.5; gt=signals.gates_6.time;
report.gate_overlap_samples=sum(g(:,1:2:6) & g(:,2:2:6),1);
dead=[];
for k=1:6
    other=k+1; if mod(k,2)==0; other=k-1; end
    rises=find(diff(double(g(:,k)))==1)+1;
    falls=find(diff(double(g(:,other)))==-1)+1;
    fallTimes=gt(falls);
    for r=rises(:)'
        j=find(fallTimes<=gt(r),1,'last');
        if ~isempty(j); dead(end+1)=gt(r)-fallTimes(j); end
    end
end
if isempty(dead)
    report.deadtime_min_s=[]; report.deadtime_median_s=[]; report.deadtime_max_s=[];
else
    report.deadtime_min_s=min(dead); report.deadtime_median_s=median(dead); report.deadtime_max_s=max(dead);
end
report.dc_current_min_A=min(signals.I_dc.data);
report.dc_current_max_A=max(signals.I_dc.data);
report.dc_rail_min_V=min(signals.Vdc_measured.data);
report.dc_rail_max_V=max(signals.Vdc_measured.data);
report.pole_voltage_min_V=min(signals.V_pole_abc.data,[],1);
report.pole_voltage_max_V=max(signals.V_pole_abc.data,[],1);
report.operating_window_available=stopTime>=3;
if report.operating_window_available
    report.final_frequency_Hz=windowMean(signals.freq,2.8,2.99);
    report.final_Vd_V=windowMean(signals.Vload_d,2.8,2.99);
    report.final_Vq_V=windowMean(signals.Vload_q,2.8,2.99);
    report.final_P_W=windowMean(signals.P_meas,2.8,2.99);
    report.final_Q_var=windowMean(signals.Q_meas,2.8,2.99);
    report.phase_voltage_rms_V=windowRms(signals.Vload_abc,2.8,3);
    report.load_current_rms_A=windowRms(signals.iload_abc,2.8,3);
    report.operating_screen=report.final_frequency_Hz>49 && report.final_frequency_Hz<51 ...
        && all(report.phase_voltage_rms_V>8.9 & report.phase_voltage_rms_V<10.9);
end
report.gate_screen=finite && all(report.gate_overlap_samples==0) && ~isempty(dead) ...
    && min(dead)>=0.9*520e-9 && median(dead)<=1.1*520e-9;
report.electrical_sanity_screen=report.dc_rail_min_V>39.99 && report.dc_rail_max_V<40.01 ...
    && max(abs(signals.I_dc.data))<100 && all(report.pole_voltage_min_V>-2) ...
    && all(report.pole_voltage_max_V<42);
resultPath=fullfile(folder,['results_' label '.mat']);
reportPath=fullfile(folder,['report_' label '.json']);
vsg_backup_output(resultPath); vsg_backup_output(reportPath);
save(resultPath,'signals','report','-v7.3');
fid=fopen(reportPath,'w');
fprintf(fid,'%s',jsonencode(report)); fclose(fid);
fprintf('STAGE5H_SIMULATION_COMPLETE: %s\n',jsonencode(report));
end

function m=windowMean(s,a,b)
take=s.time>=a & s.time<=b; assert(any(take));
m=mean(s.data(take,:),1);
end
function r=windowRms(s,a,b)
% Uniform-grid resampling avoids weighting adaptive solver edge clusters.
t=(a:2e-6:b)'; [ut,idx]=unique(s.time,'last');
y=interp1(ut,s.data(idx,:),t,'linear'); r=sqrt(mean(y.^2,1));
end
