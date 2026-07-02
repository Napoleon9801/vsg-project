% phase5d_discrete.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 5d — Hardware-Faithful DISCRETE Controller
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
%  If the discrete loop rings here, it will ring on the bench — and this
%  script finds that out for ~0 THB instead of a burnt MOSFET.
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
%   - IR2104 dead-time 520 ns (0.52 % of Ts — secondary at m = 0.70)
%   - AD7606 quantisation (16-bit over +/-10 V -> 0.3 mV, negligible)
%     and ACS712 noise (bench comparison will show it)
%   - firmware current/voltage saturations + anti-windup (inactive for
%     this +43 % load step: |i_ref| ~ 6.7 A < 10 A clamp)
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
%      vsg_stage5d_out.mat            (same schema as 5c + meta)
%      ../python/plots/phase5d_vs_5c.png   (overlay figure)
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
src_path   = fullfile(script_dir, 'vsg_stage5c.slx');
model      = 'vsg_stage5d';
model_path = fullfile(script_dir, [model '.slx']);

if ~exist(src_path, 'file')
    error(['vsg_stage5c.slx not found — run phase5c_tuned.m first ' ...
           '(and make sure it was built at the locked 40 V design point).']);
end

if bdIsLoaded('vsg_stage5c'); close_system('vsg_stage5c', 0); end
if bdIsLoaded(model);         close_system(model, 0);         end
if exist(model_path, 'file'); delete(model_path);             end

load_system(src_path);
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
sim(model);
fprintf('[Stage 5d] Sim done in %.1f s\n', toc(t_start));

%% --- EXTRACT -------------------------------------------------------------

ots   = evalin('base','omega_ts');      t = ots.Time;   omega = ots.Data;
delta = evalin('base','delta_ts');      delta = delta.Data;
Vdr   = evalin('base','Vd_ref_ts');     Vd_ref = Vdr.Data;
VLd   = evalin('base','Vload_d_ts');    Vload_d = VLd.Data;
VLq   = evalin('base','Vload_q_ts');    Vload_q = VLq.Data;
ILd   = evalin('base','iL_d_ts');       iL_d = ILd.Data;
ILq   = evalin('base','iL_q_ts');       iL_q = ILq.Data;
VLabc = evalin('base','Vload_abc_ts');  Vload_abc = VLabc.Data;
ILabc = evalin('base','iL_abc_ts');     iL_abc = ILabc.Data;
Ildabc= evalin('base','iload_abc_ts');  iload_abc = Ildabc.Data;
Vinva = evalin('base','Vinv_a_ts');     Vinv_a = Vinva.Data;
Pts   = evalin('base','P_ts');          P_meas = Pts.Data;
Qts   = evalin('base','Q_ts');          Q_meas = Qts.Data;
freq  = omega/(2*pi);

%% --- METRICS vs STAGE 5c -------------------------------------------------

c5 = load(fullfile(script_dir, 'vsg_stage5c_out.mat'), ...
          't', 'freq', 'iL_d', 'Vload_d', 'P_meas');

% peak-to-peak in a window (steady pre-step and steady post-step)
p2p = @(x, tt, t1, t2) max(x(tt>=t1 & tt<=t2)) - min(x(tt>=t1 & tt<=t2));

w_pre  = [0.90 1.00];    % settled, just before the load step at 1.0 s
w_post = [2.80 3.00];    % settled, end of run

m.iLd_p2p_pre_5d   = p2p(iL_d,      t,    w_pre(1),  w_pre(2));
m.iLd_p2p_pre_5c   = p2p(c5.iL_d,   c5.t, w_pre(1),  w_pre(2));
m.iLd_p2p_post_5d  = p2p(iL_d,      t,    w_post(1), w_post(2));
m.iLd_p2p_post_5c  = p2p(c5.iL_d,   c5.t, w_post(1), w_post(2));
m.VLd_p2p_pre_5d   = p2p(Vload_d,   t,    w_pre(1),  w_pre(2));
m.VLd_p2p_pre_5c   = p2p(c5.Vload_d,c5.t, w_pre(1),  w_pre(2));
m.VLd_p2p_post_5d  = p2p(Vload_d,   t,    w_post(1), w_post(2));
m.VLd_p2p_post_5c  = p2p(c5.Vload_d,c5.t, w_post(1), w_post(2));
m.f_ss_5d          = freq(end);
m.f_ss_5c          = c5.freq(end);

% growing-oscillation check: ripple in late window vs mid window
m.iLd_p2p_mid_5d = p2p(iL_d, t, 1.8, 2.0);
growth_ratio     = m.iLd_p2p_post_5d / max(m.iLd_p2p_mid_5d, 1e-9);

fprintf('\n================ STAGE 5d (discrete) vs 5c (continuous) ================\n');
fprintf('  f_ss           : 5d %.4f Hz | 5c %.4f Hz | pred %.4f Hz\n', ...
        m.f_ss_5d, m.f_ss_5c, f_ss_pred);
fprintf('  i_L_d p2p pre  : 5d %.4f A | 5c %.4f A   (x%.2f)\n', ...
        m.iLd_p2p_pre_5d,  m.iLd_p2p_pre_5c,  m.iLd_p2p_pre_5d /max(m.iLd_p2p_pre_5c, 1e-9));
fprintf('  i_L_d p2p post : 5d %.4f A | 5c %.4f A   (x%.2f)\n', ...
        m.iLd_p2p_post_5d, m.iLd_p2p_post_5c, m.iLd_p2p_post_5d/max(m.iLd_p2p_post_5c,1e-9));
fprintf('  V_L_d p2p pre  : 5d %.4f V | 5c %.4f V   (x%.2f)\n', ...
        m.VLd_p2p_pre_5d,  m.VLd_p2p_pre_5c,  m.VLd_p2p_pre_5d /max(m.VLd_p2p_pre_5c, 1e-9));
fprintf('  V_L_d p2p post : 5d %.4f V | 5c %.4f V   (x%.2f)\n', ...
        m.VLd_p2p_post_5d, m.VLd_p2p_post_5c, m.VLd_p2p_post_5d/max(m.VLd_p2p_post_5c,1e-9));
fprintf('  late/mid i_L_d ripple ratio : %.2f  (>1.5 = growing oscillation!)\n', growth_ratio);

verdict_ok = abs(m.f_ss_5d - m.f_ss_5c) < 0.01 && ...
             m.iLd_p2p_post_5d < 3*max(m.iLd_p2p_post_5c, 0.05) && ...
             growth_ratio < 1.5;
if verdict_ok
    fprintf('  VERDICT: PASS — discrete controller stable at 10 kHz; firmware\n');
    fprintf('           gains are safe to take to the bench as-is.\n');
else
    fprintf('  VERDICT: FAIL — discretisation effects visible. Consider lowering\n');
    fprintf('           the inner current-loop BW to 500-600 Hz in the firmware\n');
    fprintf('           (Kp_i = 2*pi*BW*Lf) BEFORE bench bring-up.\n');
end
fprintf('=========================================================================\n\n');

%% --- SAVE ---------------------------------------------------------------

meta = struct();
meta.Ts_c        = Ts_c;
meta.K_lpf       = K_lpf;
meta.transform   = ['discrete PIs (FE) + DTI swing/theta/delta + ZOH dq feedback ' ...
                    '+ 5 Hz P/Q LPF + 1-tick duty delay; plant continuous'];
meta.not_modeled = 'dead-time 520 ns, ADC quantisation, saturations/anti-windup, DC-bus dynamics';
metrics_5d       = m;

out_path = fullfile(script_dir, 'vsg_stage5d_out.mat');
save(out_path, ...
     't', 'omega', 'delta', 'freq', 'Vd_ref', ...
     'Vload_d', 'Vload_q', 'iL_d', 'iL_q', ...
     'Vload_abc', 'iL_abc', 'iload_abc', 'Vinv_a', ...
     'P_meas', 'Q_meas', ...
     'V_dc','V_set','P_base','Q_base','f_base','omega_s', ...
     'H','D','R_p','R_q','L_f','C_f','R_f','R_d','f_sw', ...
     'R_load_init','R_load_after','L_load','R_load_t', ...
     'Kp_V','Ki_V','Kp_I','Ki_I', ...
     'P_ss_pre','P_ss_post','df_ss_pred','f_ss_pred','T_sim', ...
     'meta', 'metrics_5d', ...
     '-v7');
fprintf('[Stage 5d] Data saved  : %s\n', out_path);

%% --- OVERLAY FIGURE ------------------------------------------------------

fig = figure('Visible', 'off', 'Position', [50 50 1100 850]);

subplot(3,1,1);
plot(c5.t, c5.freq, 'LineWidth', 1.2); hold on;
plot(t, freq, '--', 'LineWidth', 1.2);
ylabel('f (Hz)'); grid on;
legend('5c continuous', '5d discrete', 'Location', 'best');
title(sprintf('Stage 5d (discrete 10 kHz ctrl) vs 5c (continuous), V_{dc} = %g V', V_dc));

subplot(3,1,2);
plot(c5.t, c5.iL_d, 'LineWidth', 0.8); hold on;
plot(t, iL_d, '--', 'LineWidth', 0.8);
ylabel('i_{L,d} (A)'); grid on;
legend('5c', '5d', 'Location', 'best');

subplot(3,1,3);
plot(c5.t, c5.Vload_d, 'LineWidth', 0.8); hold on;
plot(t, Vload_d, '--', 'LineWidth', 0.8);
ylabel('V_{load,d} (V)'); xlabel('t (s)'); grid on;
legend('5c', '5d', 'Location', 'best');

fig_path = fullfile(script_dir, '..', 'python', 'plots', 'phase5d_vs_5c.png');
print(fig, fig_path, '-dpng', '-r150');
close(fig);
fprintf('[Stage 5d] Figure saved: %s\n', fig_path);
fprintf('[Stage 5d] Done.\n');
