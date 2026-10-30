% phase5d_discrete.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 5d — DISCRETE Controller / ideal switching plant
% =========================================================================
%
%  Stage 5c verified the control design with a CONTINUOUS controller.
%  The ESP32 firmware (vsg_controller.ino) is not continuous: it samples
%  at 10 kHz, computes with forward-Euler integrators, low-passes P/Q at
%  5 Hz, and its duty command only takes effect one PWM period after the
%  measurement that produced it. Those differences cost real phase margin:
%    - ZOH + one-cycle compute delay ~ 1.5*Ts = 150 us
%      -> ~54 deg of phase lag at the 1 kHz inner current-loop bandwidth
%    - fs/BW = 10 kHz / 1 kHz = 10, the textbook MINIMUM for discretising
%    - LC filter resonance (1.45 kHz, zeta = 0.046) sits only 1.45x above
%      the inner BW
%  A simulation failure blocks progression; a pass does not prove bench
%  stability because sensing, protection and power-stage nonidealities differ.
%
%  WHAT THIS SCRIPT DOES (surgical transform, not a rebuild):
%  Loads vsg_stage5c.slx (run phase5c_tuned.m first if missing), saves it
%  as vsg_stage5d.slx, then discretises ONLY the controller — the plant
%  (bridge, LC filter, RL load, carrier) stays continuous:
%
%   1. PI blocks (PI_V_d/q, PI_I_d/q) -> Discrete-time, Forward Euler,
%      Ts = 100 us  (matches firmware Ki_x_Ts integrator updates)
%   2. Swing-equation integrators (Int_omega, Int_theta, Int_delta) ->
%      Discrete-Time Integrator, Forward Euler, Ts = 100 us
%   3. dq measurement feedback (V_load_d/q, i_L_d/q) -> Zero-Order Hold
%      at 10 kHz (= AD7606 simultaneous sampling each control tick).
%      Implemented by renaming the source Goto tag to <tag>_ct and
%      bridging From(<tag>_ct) -> ZOH -> Goto(<tag>), so every consumer
%      (voltage loop, FF terms, power calc) sees the SAMPLED signal —
%      exactly what the firmware computes from.
%   4. P/Q measurement -> discrete 5 Hz LPF  y[k] = (1-K)y[k-1] + K u[k]
%      with K = 0.00313176 (the EXACT constant in vsg_controller.ino).
%      Stage 5c fed RAW P/Q to the swing eq — the firmware never does.
%   5. Phase voltage references (V_a/b/c_ref) -> Unit Delay (1 tick)
%      = mcpwm duty written this tick takes effect next PWM period.
%
%  NOT modelled (kept out deliberately, note for Ch.5/Ch.6):
%   - driver dead-time, ADC quantisation, sensor noise and offset
%   - firmware current/voltage saturations + anti-windup
%   - DC-bus dynamics (stiff 40 V source; real supply CL 3-4 A)
%
%  VERDICT CRITERIA printed at the end:
%   - f_ss within a few mHz of Stage 5c        (outer loop unaffected)
%   - i_L_d / V_load_d peak-to-peak ripple in steady windows not
%     significantly above Stage 5c              (inner loops stable)
%   - no growing oscillation after the load step
%
%  Outputs:
%      vsg_stage5d.slx
%      validation_outputs/stage5d/vsg_stage5d_out.mat (schema v2)
%      validation_outputs/stage5d/validation_stage5d.json
%  Set VSG_VALIDATION_OUTPUT_DIR to override the output directory.
%  signals.<name>.time/data is authoritative. Legacy flat arrays remain,
%  with time_<name> companions; t is the frequency clock ONLY.
%
%  MATLAB R2018b compatible.
%
%  Author  : Napoleon (Chinnawat Dumklang) - SUT EE
%  Stage 5d: 2026-07-02
% =========================================================================

%% --- PARAMETERS ----------------------------------------------------------

Ts_c   = 1e-4;          % controller sample time = 100 us (10 kHz)
K_lpf  = 0.00313176;    % 5 Hz discrete LPF gain — same constant as firmware

% Electrical/control constants (identical to phase5c_tuned.m, for metadata
% and analytical prediction — the numeric values inside the model come
% from the loaded vsg_stage5c.slx, which must have been built at 40 V)
V_dc         = 40;
P_base       = 100;   Q_base = 100;
f_base       = 50;    omega_s = 2*pi*f_base;
V_set        = 14;
L_f          = 1.2e-3;  R_f = 0.05;  C_f = 10e-6;  R_d = 1.0;
H            = 5;     D = 0.5;   R_p = 0.05;  R_q = 0.05;
R_load_init  = 2.94;  R_load_after = R_load_init*0.70;  L_load = 1e-3;
R_load_t     = 1.0;   T_sim = 3.0;
f_sw         = 10e3;
Kp_V         = 2*0.707*628*C_f;   Ki_V = 628^2*C_f;
Kp_I         = 6283*L_f;          Ki_I = Kp_I*R_f/L_f;

% Analytical SS (same corrected formula as 5c — includes the D term)
ZL_d_pre   = (R_load_init^2  + (omega_s*L_load)^2)/R_load_init;
ZL_d_post  = (R_load_after^2 + (omega_s*L_load)^2)/R_load_after;
P_ss_pre   = 1.5*V_set^2/ZL_d_pre;
P_ss_post  = 1.5*V_set^2/ZL_d_post;
dP_pu      = (P_ss_post - P_ss_pre)/P_base;
df_ss_pred = -dP_pu/(1/R_p + D*omega_s)*f_base;
f_ss_pred  = f_base + df_ss_pred;

%% --- LOAD 5c MODEL, SAVE AS 5d ------------------------------------------

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
output_dir = getenv('VSG_VALIDATION_OUTPUT_DIR');
if isempty(output_dir); output_dir=fullfile(script_dir,'validation_outputs','stage5d'); end
if ~exist(output_dir,'dir'); mkdir(output_dir); end
src_path   = fullfile(script_dir, 'vsg_stage5c.slx');
model      = 'vsg_stage5d';
model_path = fullfile(output_dir, [model '.slx']);

if ~exist(src_path, 'file')
    error(['vsg_stage5c.slx not found — run phase5c_tuned.m first ' ...
           '(and make sure it was built at the locked 40 V design point).']);
end

if bdIsLoaded('vsg_stage5c'); close_system('vsg_stage5c', 0); end
if bdIsLoaded(model);         close_system(model, 0);         end
vsg_backup_output(model_path);

load_system(src_path);
source_identity=vsg_source_identity({src_path, ...
    fullfile(script_dir,'phase5c_tuned.m'),[mfilename('fullpath') '.m'], ...
    fullfile(script_dir,'vsg_assert_stage5c.m'),fullfile(script_dir,'vsg_compare_stage5.m'), ...
    fullfile(script_dir,'vsg_validate_signals.m')});
vsg_assert_stage5c('vsg_stage5c');
save_system('vsg_stage5c', model_path);   % loaded model is now 'vsg_stage5d'

evalin('base', ['clear omega_ts delta_ts Vd_ref_ts ' ...
                'Vload_d_ts Vload_q_ts iL_d_ts iL_q_ts ' ...
                'Vload_abc_ts Vload_a_ts Vload_b_ts Vload_c_ts ' ...
                'Vinv_a_ts P_ts Q_ts iload_abc_ts iL_abc_ts']);

fprintf('[Stage 5d] Transforming controller to discrete (Ts = %g us)...\n', Ts_c*1e6);

%% --- 1) PI CONTROLLERS -> DISCRETE FORWARD EULER -------------------------

pi_blocks = {'PI_V_d', 'PI_V_q', 'PI_I_d', 'PI_I_q'};
for k = 1:numel(pi_blocks)
    set_param([model '/' pi_blocks{k}], ...
        'TimeDomain',       'Discrete-time', ...
        'SampleTime',       num2str(Ts_c), ...
        'IntegratorMethod', 'Forward Euler');
end
fprintf('  [1/5] 4 PI controllers -> discrete forward Euler\n');

%% --- 2) SWING-EQ INTEGRATORS -> DISCRETE-TIME INTEGRATORS ----------------
% Each is a single-in single-out Continuous Integrator with known wiring:
%   Int_omega : Gain_inv_2Hws/1 -> in,  out -> Goto_omega/1   (IC = omega_s)
%   Int_theta : From_omega_d/1  -> in,  out -> Goto_theta/1   (IC = 0)
%   Int_delta : Sum_dom/1       -> in,  out -> Goto_delta/1   (IC = 0)

int_specs = { ...
    'Int_omega', 'Gain_inv_2Hws/1', 'Goto_omega/1', num2str(omega_s); ...
    'Int_theta', 'From_omega_d/1',  'Goto_theta/1', '0'; ...
    'Int_delta', 'Sum_dom/1',       'Goto_delta/1', '0'};

for k = 1:size(int_specs,1)
    blk = int_specs{k,1}; src = int_specs{k,2};
    dst = int_specs{k,3}; ic  = int_specs{k,4};
    pos_ = get_param([model '/' blk], 'Position');
    delete_line(model, src, [blk '/1']);
    delete_line(model, [blk '/1'], dst);
    delete_block([model '/' blk]);
    add_block('simulink/Discrete/Discrete-Time Integrator', [model '/' blk], ...
        'IntegratorMethod', 'Integration: Forward Euler', ...
        'SampleTime',       num2str(Ts_c), ...
        'InitialCondition', ic, ...
        'Position',         pos_);
    add_line(model, src, [blk '/1'], 'autorouting', 'on');
    add_line(model, [blk '/1'], dst, 'autorouting', 'on');
end
fprintf('  [2/5] Int_omega/Int_theta/Int_delta -> DTI forward Euler\n');

%% --- 3) dq FEEDBACK -> ZERO-ORDER HOLD @ 10 kHz --------------------------
% Rename the source Goto's tag to <tag>_ct, then bridge
% From(<tag>_ct) -> ZOH(Ts_c) -> Goto(<tag>). Every existing From block
% keeps its tag and transparently receives the sampled signal.

zoh_specs = { ...   % {source Goto block, tag}
    'Goto_VLd', 'V_load_d'; ...
    'Goto_VLq', 'V_load_q'; ...
    'Goto_iLd', 'i_L_d'; ...
    'Goto_iLq', 'i_L_q'};

x0 = 1700;  y0 = 60;   % free canvas area for interposed chains
BW = 50; BH = 22;
pp = @(x, y) [x-BW, y-BH, x+BW, y+BH];

for k = 1:size(zoh_specs,1)
    gblk = zoh_specs{k,1}; tag = zoh_specs{k,2};
    y = y0 + (k-1)*80;
    set_param([model '/' gblk], 'GotoTag', [tag '_ct']);
    add_block('simulink/Signal Routing/From', [model '/From_' tag '_ct'], ...
        'GotoTag', [tag '_ct'], 'Position', pp(x0, y));
    add_block('simulink/Discrete/Zero-Order Hold', [model '/ZOH_' tag], ...
        'SampleTime', num2str(Ts_c), 'Position', pp(x0+140, y));
    add_block('simulink/Signal Routing/Goto', [model '/Goto_' tag '_s'], ...
        'GotoTag', tag, 'TagVisibility', 'global', 'Position', pp(x0+280, y));
    add_line(model, ['From_' tag '_ct/1'], ['ZOH_' tag '/1'], 'autorouting', 'on');
    add_line(model, ['ZOH_' tag '/1'], ['Goto_' tag '_s/1'], 'autorouting', 'on');
    % Observe the plant BEFORE the controller ZOH for honest ripple checks.
    ct_names={'Vload_d_ct_ts','Vload_q_ct_ts','iL_d_ct_ts','iL_q_ct_ts'};
    add_block('simulink/Sinks/To Workspace',[model '/TWS_' ct_names{k}], ...
        'VariableName',ct_names{k},'SaveFormat','Timeseries');
    add_line(model,['From_' tag '_ct/1'],['TWS_' ct_names{k} '/1']);
end
fprintf('  [3/5] V_load_dq + i_L_dq feedback -> ZOH @ 10 kHz\n');

%% --- 4) P/Q -> DISCRETE 5 Hz LPF (exact firmware filter) -----------------
% Firmware: y += K_lpf*(u - y)  ->  H(z) = K*z / (z - (1-K))

lpf_num = sprintf('[%.10g 0]', K_lpf);
lpf_den = sprintf('[1 %.10g]', -(1 - K_lpf));

lpf_specs = { ...   % {source Goto block, tag}
    'Goto_P', 'P_meas'; ...
    'Goto_Q', 'Q_meas'};

for k = 1:size(lpf_specs,1)
    gblk = lpf_specs{k,1}; tag = lpf_specs{k,2};
    y = y0 + 320 + (k-1)*80;
    set_param([model '/' gblk], 'GotoTag', [tag '_raw']);
    add_block('simulink/Signal Routing/From', [model '/From_' tag '_raw'], ...
        'GotoTag', [tag '_raw'], 'Position', pp(x0, y));
    add_block('simulink/Discrete/Discrete Transfer Fcn', [model '/LPF_' tag], ...
        'Numerator', lpf_num, 'Denominator', lpf_den, ...
        'SampleTime', num2str(Ts_c), 'Position', pp(x0+140, y));
    add_block('simulink/Signal Routing/Goto', [model '/Goto_' tag '_f'], ...
        'GotoTag', tag, 'TagVisibility', 'global', 'Position', pp(x0+280, y));
    add_line(model, ['From_' tag '_raw/1'], ['LPF_' tag '/1'], 'autorouting', 'on');
    add_line(model, ['LPF_' tag '/1'], ['Goto_' tag '_f/1'], 'autorouting', 'on');
end
fprintf('  [4/5] P/Q -> discrete 5 Hz LPF (K = %g, firmware-exact)\n', K_lpf);

%% --- 5) DUTY REFS -> ONE-TICK COMPUTE DELAY ------------------------------
% mcpwm_set_duty written at tick k takes effect the following period.

dly_specs = { ...   % {source Goto block, tag}
    'Goto_Varef', 'V_a_ref'; ...
    'Goto_Vbref', 'V_b_ref'; ...
    'Goto_Vcref', 'V_c_ref'};

for k = 1:size(dly_specs,1)
    gblk = dly_specs{k,1}; tag = dly_specs{k,2};
    y = y0 + 480 + (k-1)*80;
    set_param([model '/' gblk], 'GotoTag', [tag '_now']);
    add_block('simulink/Signal Routing/From', [model '/From_' tag '_now'], ...
        'GotoTag', [tag '_now'], 'Position', pp(x0, y));
    add_block('simulink/Discrete/Unit Delay', [model '/Delay_' tag], ...
        'SampleTime', num2str(Ts_c), 'Position', pp(x0+140, y));
    add_block('simulink/Signal Routing/Goto', [model '/Goto_' tag '_d'], ...
        'GotoTag', tag, 'TagVisibility', 'global', 'Position', pp(x0+280, y));
    add_line(model, ['From_' tag '_now/1'], ['Delay_' tag '/1'], 'autorouting', 'on');
    add_line(model, ['Delay_' tag '/1'], ['Goto_' tag '_d/1'], 'autorouting', 'on');
end
fprintf('  [5/5] V_abc_ref -> one-tick compute delay\n');

%% --- SOLVER + RUN --------------------------------------------------------

set_param(model, ...
    'Solver',   'ode23tb', ...
    'StopTime', num2str(T_sim), ...
    'MaxStep',  '5e-6', ...
    'SaveTime', 'off', 'SaveState', 'off', 'SaveOutput', 'off');

save_system(model, model_path);
fprintf('[Stage 5d] Model saved : %s\n', model_path);
fprintf('[Stage 5d] Simulating (T_sim = %g s) ...\n', T_sim);

t_start = tic;
in=Simulink.SimulationInput(model);
in=in.setModelParameter('StopTime',num2str(T_sim),'ReturnWorkspaceOutputs','on');
out=sim(in);
fprintf('[Stage 5d] Sim done in %.1f s\n', toc(t_start));

%% --- EXPORT EACH SIGNAL WITH ITS OWN CLOCK -------------------------------
names={'omega','delta','Vd_ref','Vload_d','Vload_q','iL_d','iL_q', ...
    'Vload_abc','iL_abc','iload_abc','Vinv_a','P_meas','Q_meas', ...
    'Vload_d_ct','Vload_q_ct','iL_d_ct','iL_q_ct'};
variables={'omega_ts','delta_ts','Vd_ref_ts','Vload_d_ts','Vload_q_ts', ...
    'iL_d_ts','iL_q_ts','Vload_abc_ts','iL_abc_ts','iload_abc_ts', ...
    'Vinv_a_ts','P_ts','Q_ts','Vload_d_ct_ts','Vload_q_ct_ts','iL_d_ct_ts','iL_q_ct_ts'};
signals=struct(); export=struct();
for k=1:numel(names)
    signal_ts=out.get(variables{k});
    signal_data=signal_ts.Data;
    if ~signal_ts.IsTimeFirst
        signal_data=permute(signal_data,[ndims(signal_data),1:ndims(signal_data)-1]);
    end
    signal_data=reshape(signal_data,numel(signal_ts.Time),[]);
    signals.(names{k})=struct('time',signal_ts.Time(:),'data',signal_data);
    export.(names{k})=signal_data;
    export.(['time_' names{k}])=signal_ts.Time(:);
end
signals.freq=struct('time',signals.omega.time,'data',signals.omega.data/(2*pi));
export.freq=signals.freq.data; export.time_freq=signals.freq.time;
export.t=signals.freq.time; % legacy alias: not valid for plant waveforms!
shape_report=vsg_validate_signals(signals);

baseline_path=fullfile(script_dir,'vsg_stage5c_out.mat');
c5=load(baseline_path);
expected=struct('V_dc',V_dc,'V_set',V_set,'P_base',P_base,'Q_base',Q_base, ...
    'H',H,'D',D,'R_p',R_p,'R_q',R_q,'L_f',L_f,'C_f',C_f,'R_f',R_f, ...
    'R_d',R_d,'f_sw',f_sw,'R_load_init',R_load_init,'R_load_after',R_load_after, ...
    'L_load',L_load,'R_load_t',R_load_t,'Kp_V',Kp_V,'Ki_V',Ki_V,'Kp_I',Kp_I,'Ki_I',Ki_I);
fields=fieldnames(expected);
for k=1:numel(fields)
    name=fields{k};
    assert(isfield(c5,name) && abs(c5.(name)-expected.(name))<1e-9, ...
        'VSG:BaselineResultParameter','Stage 5c result parameter mismatch: %s',name);
    export.(name)=expected.(name);
end
metrics_5d=vsg_compare_stage5(signals,c5,Ts_c);
vsg_assert_source_identity(source_identity);
meta=struct('schema_version',2,'Ts_c',Ts_c,'K_lpf',K_lpf, ...
    'source_identity',source_identity,'baseline_identity',vsg_source_identity({baseline_path}), ...
    'timestamp_contract','signals.<name>.time/data; t is the omega/frequency clock only', ...
    'not_modeled','deadtime, sensor error, clamps, antiwindup, finite DC bus, protection', ...
    'scope','Ideal switching plant with selected discrete-controller effects; not firmware equivalence');
export.signals=signals; export.meta=meta; export.metrics_5d=metrics_5d;
export.shape_report=shape_report; export.T_sim=T_sim; export.f_base=f_base;
export.omega_s=omega_s; export.P_ss_pre=P_ss_pre; export.P_ss_post=P_ss_post;
export.df_ss_pred=df_ss_pred; export.f_ss_pred=f_ss_pred;
out_path=fullfile(output_dir,'vsg_stage5d_out.mat'); vsg_backup_output(out_path);
save(out_path,'-struct','export','-v7');
report_path=fullfile(output_dir,'validation_stage5d.json'); vsg_backup_output(report_path);
fid=fopen(report_path,'w'); assert(fid>=0,'Cannot open validation report');
fprintf(fid,'%s',jsonencode(struct('meta',meta,'shape',shape_report,'metrics',metrics_5d))); fclose(fid);
fprintf('[Stage 5d] f: %.6f Hz (5c %.6f); growth %.3f; simulation checks pass=%d\n', ...
    metrics_5d.frequency_5d,metrics_5d.frequency_5c,metrics_5d.growth_ratio,metrics_5d.pass);
fprintf('[Stage 5d] Export: %s\n',out_path);
assert(metrics_5d.pass,'VSG:Stage5dRegression','Stage 5d regression failed; see JSON evidence.');
