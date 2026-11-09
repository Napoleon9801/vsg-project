function report = run_stage5i_secondary(stopTime,maxStep,label,enable)
% Run Stage 5i without saving or permanently changing its model parameters.
% Defaults: 6 s, 2.5 us maximum plant step, secondary control enabled.
if nargin<1; stopTime=6; end
if nargin<2; maxStep=2.5e-6; end
if nargin<3; label='nominal'; end
if nargin<4; enable=1; end
validateattributes(stopTime,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(maxStep,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(enable,{'numeric','logical'},{'scalar'});
assert(enable==0 || enable==1,'Secondary enable must be 0 or 1.');
assert(ischar(label) && ~isempty(regexp(label,'^[a-zA-Z0-9_]+$','once')), ...
    'Invalid result label.');
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5i');
model='vsg_stage5i_secondary';
modelPath=fullfile(folder,[model '.slx']);
assert(exist(modelPath,'file')==2,'Build Stage 5i before running it.');
% Resolve the saved model without opening its editor or saving any overrides.
oldPath=path;
pathCleanup=onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(folder);
in=Simulink.SimulationInput(model);
in=in.setModelParameter('StopTime',num2str(stopTime,16), ...
    'MaxStep',num2str(maxStep,16),'ReturnWorkspaceOutputs','on');
in=in.setVariable('secondary_enable',double(enable),'Workspace',model);
tic;
out=sim(in);
elapsed=toc;

names={'omega','Vload_d','Vload_q','Vload_abc','iL_abc','iload_abc', ...
    'P_meas','Q_meas','gates_6','I_dc','V_neutral','V_pole_abc', ...
    'Vds_A_high','Vdc_measured','sec_P_ref_pu','sec_freq_Hz', ...
    'sec_delta_P_pu','sec_freq_error_Hz','sec_enabled','sec_clamp_state'};
vars={'omega_ts','Vload_d_ts','Vload_q_ts','Vload_abc_ts','iL_abc_ts', ...
    'iload_abc_ts','P_ts','Q_ts','gates_6_ts','I_dc_ts','V_neutral_ts', ...
    'V_pole_abc_ts','Vds_A_high_ts','Vdc_measured_ts','sec_P_ref_pu_ts', ...
    'sec_freq_Hz_ts','sec_delta_P_pu_ts','sec_freq_error_Hz_ts','sec_enabled_ts','sec_clamp_state_ts'};
signals=struct();
for k=1:numel(names)
    ts=out.get(vars{k});
    d=ts.Data;
    if ~ts.IsTimeFirst
        d=permute(d,[ndims(d),1:ndims(d)-1]);
    end
    signals.(names{k})=struct('time',ts.Time(:), ...
        'data',reshape(d,numel(ts.Time),[]));
end
signals.freq=struct('time',signals.omega.time, ...
    'data',signals.omega.data/(2*pi));

report=struct('model_file',modelPath,'stop_time_s',stopTime, ...
    'maximum_step_s',maxStep,'wall_seconds',elapsed, ...
    'secondary_enable',double(enable),'frequency_reference_Hz',50, ...
    'secondary_Ki_pu_per_Hz_s',4,'secondary_sample_time_s',1e-4,'secondary_enable_time_s',0.5, ...
    'load_step_time_s',1,'frequency_band_Hz',0.005, ...
    'secondary_correction_limits_pu',[-0.5 0.8], ...
    'scope',['Secondary frequency restoration on six SPS MOSFET macro models; ' ...
    'logical gates; floating AC star; no driver electrical or thermal qualification'], ...
    'gate_order','AH AL BH BL CH CL','deadtime_requested_s',520e-9, ...
    'MOSFET_Ron_ohm',0.044,'diode_Rd_ohm',0.01,'diode_Vf_V',0.8, ...
    'numerical_snubber_R_ohm',1e5,'breaker_on_R_ohm',0.001);
allNames=fieldnames(signals);
finite=true;
timeValid=true;
allLogsComplete=true;
for k=1:numel(allNames)
    s=signals.(allNames{k});
    finite=finite && ~isempty(s.data) && all(isfinite(s.data(:)));
    timeValid=timeValid && ~isempty(s.time) && all(isfinite(s.time)) ...
        && all(diff(s.time)>=0);
    allLogsComplete=allLogsComplete && ~isempty(s.time) ...
        && s.time(1)<=1e-9 && s.time(end)>=stopTime-max(1e-9,1e-8*stopTime);
end
report.all_signals_finite=finite;
report.time_axes_valid=timeValid;
report.all_logs_cover_requested_run=allLogsComplete;
report.actual_end_time_s=signals.freq.time(end);
report.initial_iL_A=signals.iL_abc.data(1,:);
report.initial_load_voltage_V=signals.Vload_abc.data(1,:);

assert(size(signals.gates_6.data,2)==6,'Expected six gate channels.');
g=signals.gates_6.data>0.5;
gt=signals.gates_6.time;
report.gate_overlap_samples=sum(g(:,1:2:6) & g(:,2:2:6),1);
deadByGate=cell(6,1);
riseCounts=zeros(1,6);
measuredCounts=zeros(1,6);
for k=1:6
    other=k+1;
    if mod(k,2)==0; other=k-1; end
    rises=find(diff(double(g(:,k)))==1)+1;
    falls=find(diff(double(g(:,other)))==-1)+1;
    riseTimes=gt(rises);
    fallTimes=unique(gt(falls));
    riseCounts(k)=numel(rises);
    if isempty(fallTimes) || isempty(riseTimes)
        deadByGate{k}=zeros(0,1);
        continue;
    end
    % Bin j+1 identifies the latest opposite falling edge j at or before
    % each rise. This avoids a full edge-array search for every PWM rise.
    [~,~,bins]=histcounts(riseTimes,[-Inf;fallTimes;Inf]);
    previous=bins-1;
    valid=previous>0;
    deadByGate{k}=riseTimes(valid)-fallTimes(previous(valid));
    measuredCounts(k)=sum(valid);
end
dead=vertcat(deadByGate{:});
report.gate_rising_edge_counts=riseCounts;
report.deadtime_measured_counts=measuredCounts;
report.deadtime_min_s=[];
report.deadtime_median_s=[];
report.deadtime_max_s=[];
if ~isempty(dead)
    report.deadtime_min_s=min(dead);
    report.deadtime_median_s=median(dead);
    report.deadtime_max_s=max(dead);
end
report.gate_screen=finite && timeValid && all(report.gate_overlap_samples==0) ...
    && all(measuredCounts>0) && ~isempty(dead) ...
    && min(dead)>=0.9*520e-9 && median(dead)<=1.1*520e-9;

report.dc_current_min_A=min(signals.I_dc.data(:));
report.dc_current_max_A=max(signals.I_dc.data(:));
report.dc_rail_min_V=min(signals.Vdc_measured.data(:));
report.dc_rail_max_V=max(signals.Vdc_measured.data(:));
report.pole_voltage_min_V=min(signals.V_pole_abc.data,[],1);
report.pole_voltage_max_V=max(signals.V_pole_abc.data,[],1);
report.electrical_sanity_screen=finite && report.dc_rail_min_V>39.99 ...
    && report.dc_rail_max_V<40.01 && max(abs(signals.I_dc.data(:)))<100 ...
    && all(report.pole_voltage_min_V>-2) && all(report.pole_voltage_max_V<42);
correction=signals.sec_delta_P_pu.data(:);
report.secondary_correction_min_pu=min(correction);
report.secondary_correction_max_pu=max(correction);
report.secondary_clamp_states=unique(signals.sec_clamp_state.data(:))';
report.secondary_clamp_active_samples=sum(signals.sec_clamp_state.data(:)~=0);
beforeEnable=signals.sec_delta_P_pu.time<0.5;
report.secondary_zero_before_enable=all(abs(correction(beforeEnable))<=1e-12);
report.secondary_correction_within_limits=finite ...
    && all(correction>=-0.5-1e-12 & correction<=0.8+1e-12);
report.secondary_disabled_zero_correction_screen=[];
if ~enable
    report.secondary_disabled_zero_correction_screen=finite && all(abs(correction)<=1e-12);
end

% All windows use actual logged time, rather than the former fixed 2.8-3 s.
endTime=report.actual_end_time_s;
report.operating_window_available=finite && timeValid && allLogsComplete && endTime>=2;
report.final_mean_window_s=[];
report.final_frequency_Hz=[];
report.final_Vd_V=[];
report.final_Vq_V=[];
report.final_P_W=[];
report.final_Q_var=[];
report.final_sec_P_ref_pu=[];
report.final_sec_delta_P_pu=[];
report.final_sec_freq_error_Hz=[];
report.phase_voltage_rms_V=[];
report.load_current_rms_A=[];
report.operating_screen=[];
report.last_second_frequency_min_Hz=[];
report.last_second_frequency_max_Hz=[];
report.last_second_max_abs_frequency_error_Hz=[];
report.last_second_in_frequency_band=[];
report.secondary_restoration_screen=[];
if report.operating_window_available
    a=endTime-0.4;
    report.final_mean_window_s=[a endTime];
    report.final_frequency_Hz=windowMean(signals.freq,a,endTime);
    report.final_Vd_V=windowMean(signals.Vload_d,a,endTime);
    report.final_Vq_V=windowMean(signals.Vload_q,a,endTime);
    report.final_P_W=windowMean(signals.P_meas,a,endTime);
    report.final_Q_var=windowMean(signals.Q_meas,a,endTime);
    report.final_sec_P_ref_pu=windowMean(signals.sec_P_ref_pu,a,endTime);
    report.final_sec_delta_P_pu=windowMean(signals.sec_delta_P_pu,a,endTime);
    report.final_sec_freq_error_Hz=windowMean(signals.sec_freq_error_Hz,a,endTime);
    report.phase_voltage_rms_V=windowRms(signals.Vload_abc,a,endTime);
    report.load_current_rms_A=windowRms(signals.iload_abc,a,endTime);
    report.operating_screen=report.final_frequency_Hz>49 && report.final_frequency_Hz<51 ...
        && all(report.phase_voltage_rms_V>=8.9 & report.phase_voltage_rms_V<=10.9);
    [~,f]=windowData(signals.freq,endTime-1,endTime);
    report.last_second_frequency_min_Hz=min(f(:));
    report.last_second_frequency_max_Hz=max(f(:));
    report.last_second_max_abs_frequency_error_Hz=max(abs(f(:)-50));
    report.last_second_in_frequency_band=all(abs(f(:)-50)<=0.005);
    if enable
        report.secondary_restoration_screen=report.last_second_in_frequency_band;
    end
end

report.poststep_window_available=finite && timeValid && endTime>1;
report.poststep_frequency_nadir_Hz=[];
report.poststep_frequency_nadir_time_s=[];
report.poststep_frequency_peak_Hz=[];
report.poststep_frequency_peak_time_s=[];
report.observed_settling_time_s=[];
report.observed_settling_delay_after_load_step_s=[];
report.final_continuous_in_band_duration_s=[];
report.settling_definition=['Earliest logged post-step point after the final out-of-band ' ...
    'sample; the frequency remains within 50 +/- 0.005 Hz through the observed end only.'];
if report.poststep_window_available
    [ft,f]=windowData(signals.freq,1,endTime);
    [report.poststep_frequency_nadir_Hz,j]=min(f);
    report.poststep_frequency_nadir_time_s=ft(j);
    [report.poststep_frequency_peak_Hz,j]=max(f);
    report.poststep_frequency_peak_time_s=ft(j);
    lastOutside=find(abs(f-50)>0.005,1,'last');
    report.final_continuous_in_band_duration_s=0;
    if isempty(lastOutside)
        firstInside=1;
    elseif lastOutside<numel(ft)
        firstInside=lastOutside+1;
    else
        firstInside=[];
    end
    if ~isempty(firstInside)
        report.observed_settling_time_s=ft(firstInside);
        report.observed_settling_delay_after_load_step_s=ft(firstInside)-1;
        report.final_continuous_in_band_duration_s=endTime-ft(firstInside);
    end
end
report.execution_screen=finite && timeValid && allLogsComplete ...
    && report.gate_screen && report.electrical_sanity_screen ...
    && report.secondary_correction_within_limits && report.secondary_zero_before_enable;
% Short and secondary-disabled runs are evidence for regression, not proof
% of successful secondary frequency restoration. Leave that verdict absent.
report.validation_complete=report.operating_window_available && logical(enable);
report.pass=[];
if report.validation_complete
    report.pass=report.execution_screen && report.operating_screen ...
        && report.secondary_restoration_screen;
end
resultPath=fullfile(folder,['results_' label '.mat']);
reportPath=fullfile(folder,['report_' label '.json']);
vsg_backup_output(resultPath);
vsg_backup_output(reportPath);
save(resultPath,'signals','report','-v7.3');
fid=fopen(reportPath,'w');
assert(fid>=0,'Cannot open report output: %s',reportPath);
fileCleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report));
fprintf('STAGE5I_SIMULATION_COMPLETE: %s\n',jsonencode(report));
end

function [t,y]=windowData(s,a,b)
% Keep actual samples and exact endpoints; integrate without weighting
% clusters of adaptive solver output as though they were uniform samples.
before=find(s.time<=a,1,'last');
after=find(s.time>=b,1,'first');
assert(~isempty(before) && ~isempty(after),'Logged signal does not cover the metric window.');
index=before:after;
[ut,j]=unique(s.time(index),'last');
data=s.data(index(j),:);
inside=ut>a & ut<b;
t=[a;ut(inside);b];
y=[interp1(ut,data,a,'linear');data(inside,:);interp1(ut,data,b,'linear')];
end

function m=windowMean(s,a,b)
[t,y]=windowData(s,a,b);
m=trapz(t,y,1)/(b-a);
end

function r=windowRms(s,a,b)
% Uniform resampling avoids bias from adaptive switching-edge clusters.
[t,y]=windowData(s,a,b);
grid=(a:2e-6:b)';
if grid(end)<b; grid(end+1)=b; end
uniform=interp1(t,y,grid,'linear');
r=sqrt(trapz(grid,uniform.^2,1)/(b-a));
end
