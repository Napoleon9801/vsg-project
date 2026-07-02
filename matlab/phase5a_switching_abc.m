% phase5a_switching_abc.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 5a — Switching-Model VSG (3-phase abc + SPWM)
% =========================================================================
%
%  Stage 4 ran entirely in the dq frame with an ideal voltage source as
%  the "inverter". Stage 5a finally puts the PHYSICAL 3-phase abc layer
%  underneath that controller:
%
%    [Outer + V-I PI in dq]  →  V_inv_d_ref, V_inv_q_ref
%                                     │
%                                     ▼
%                              [inverse Park, uses delta]
%                                     │
%                                     ▼
%                              V_a_ref, V_b_ref, V_c_ref  (3-phase sinusoids)
%                                     │
%                                     ▼
%                              [SPWM modulator: compare with 10-kHz triangle]
%                                     │
%                                     ▼
%                              gate states  →  behavioural 2-level bridge
%                                     │       V_inv_phase = ±V_dc/2
%                                     ▼
%                              V_inv_a/b/c  (switched square waves)
%                                     │
%                                     ▼
%                              [3-phase LC filter — vector, balanced]
%                                     │
%                                     ▼
%                              V_load_a/b/c  (clean sinusoids)
%                                     │
%                                     ▼
%                              [3-phase RL load with disturbance]
%                                     │
%                                     ▼
%                              I_load_abc, I_L_abc
%                                     │
%                                     ▼
%                              [forward Park, uses delta]
%                                     │
%                                     ▼
%                              V_load_d/q, I_L_d/q  →  back to V-I PI feedback
%                                                  →  power calc  →  P/Q feedback
%
%  KEY DESIGN CHOICES (confirmed with Napoleon 2026-05-27):
%    - Switching device : MOSFET-style behavioural bridge, ideal (no
%                         dead time, no on-resistance, no body diode).
%                         Realistic loss model is Stage 5b/5c work.
%    - PWM frequency    : 10 kHz (ESP32 MCPWM target)
%    - Modulation       : SPWM (sinusoidal). SVPWM efficiency gain is
%                         only ~15 % and adds significant block count —
%                         deferred to a later optimisation iteration.
%    - Library          : pure Simulink (NOT Simscape Electrical). The
%                         abc switching is captured by Sign+Gain blocks
%                         which is sufficient for control verification.
%                         Stage 5b/5c can swap in Universal Bridge.
%    - Control loops    : kept in dq frame (Choice A), identical to
%                         Stage 4. This is what ESP32 firmware will run.
%    - 3-phase topology : Y-connected, neutral grounded → phases are
%                         electrically decoupled at the AC side, so all
%                         3-phase blocks vectorise cleanly.
%
%  ELECTRICAL DESIGN POINT  (locked hardware design, 2026-05-30):
%    V_dc      = 40 V         (m = 14/20 = 0.70, linear SPWM)
%    V_ac_peak = 14 V         (d-axis voltage setpoint)
%    L_f       = 1.2 mH      C_f = 10 µF     →  f_res ≈ 1.45 kHz
%    R_load    = 2.94 Ω      L_load = 1 mH   →  P ≈ 100 W (3-phase)
%    f_sw      = 10 kHz       carrier period = 100 µs
%
%  DISTURBANCE: at t = 0.2 s, R_load drops to 0.7 × R_load
%               (load impedance step ≈ +43 % current → ~+40 W active power)
%
%  EXPECTED SS (post-disturb) — this baseline runs D = 0, so the pure
%  droop relation applies (with D > 0 the D·ω_s term must be added,
%  see phase5c_tuned.m):
%    ΔP_pu ≈ +0.41 → Δf = -R_p · ΔP_pu · f_base ≈ -1.02 Hz
%    f_ss ≈ 48.98 Hz
%  CAVEAT: with D = 0 the droop-only swing settles much slower than
%  T_sim = 1.5 s, so the final printed f (~49.23 Hz at t = 1.5 s) is a
%  MID-TRANSIENT snapshot, not the SS value above. Use the matched rerun
%  (phase5a_rerun_matched.m, T_sim = 3 s, D = 0.5) for SS comparisons.
%
%  Outputs:
%      vsg_stage5a.slx
%      vsg_stage5a_out.mat
%
%  Tested on MATLAB R2018b. Block count ~95. Sim time ~3-5 min.
%
%  Author  : Napoleon (Chinnawat Dumklang) — SUT EE
%  Stage 5a: 2026-05-27
% =========================================================================

%% --- PARAMETERS ---------------------------------------------------------

% Electrical base
%
% V_dc history: 24 V → 48 V on 2026-05-27 (V_set = 14 V exceeded the
% 24 V design's linear SPWM range V_dc/2 = 12 V, causing overmodulation).
% 48 V → 40 V on 2026-05-30 when the hardware design point was locked
% (design_point_reconciliation.md): m = 14/20 = 0.70, matches firmware.
% NOTE: V_dc/2 is BAKED into the bridge gain + carrier amplitude of the
% built .slx — phase5b_hd_sweep.m and phase5a_rerun_matched.m reuse that
% model, so they inherit whatever V_dc this script was last built with.
V_dc           = 40;             % DC bus (V) — locked hardware design point
P_base         = 100;            % rated 3-phase active power (W)
Q_base         = 100;            % rated 3-phase reactive power (VAR)
f_base         = 50;             % Hz
omega_s        = 2*pi*f_base;    % rad/s
V_set          = 14;             % d-axis voltage setpoint (V peak phase)

% Filter & load
%
% R_load redesigned 2026-05-27: previous 1.91 Ω gave P_3phase ≈ 150 W
% (because P_total = 1.5·V·I includes the 3-phase factor). New 2.94 Ω
% gives exactly P_3phase = 100 W at V_d = 14 V — matches P_set so the
% baseline frequency is 50.00 Hz with no droop offset.
L_f            = 1.2e-3;
R_f            = 0.05;
C_f            = 10e-6;
f_res          = 1/(2*pi*sqrt(L_f*C_f));
R_load_init    = 2.94;                   % gives P_3phase = 100 W at V_d=14
R_load_after   = R_load_init * 0.70;     % 30 % reduction → +43 % current
L_load         = 1e-3;
R_load_t       = 0.20;                   % disturbance time (s)

% PWM
f_sw           = 10e3;                   % switching freq (Hz)
T_sw           = 1/f_sw;                 % 100 µs
carrier_amp    = V_dc/2;                 % triangle amplitude ±V_dc/2

% Outer VSG loop
H              = 5;
D              = 0;
R_p            = 0.05;
K_droop_pf     = 1/(R_p*omega_s);
P_set_pu       = 1.00;
inertia_coeff  = 2*H/omega_s;

% Q-V droop
R_q            = 0.05;
K_droop_qv     = R_q*V_set/Q_base;       % ≈ 0.007 V/VAR
Q_set          = 0;

% Voltage-loop PI (per axis)  — kept from Stage 4
Kp_V           = 2*0.707*628*C_f;        % ≈ 8.88e-3
Ki_V           = 628^2 * C_f;            % ≈ 3.94

% Current-loop PI (per axis)
Kp_I           = 6283 * L_f;             % ≈ 7.54
Ki_I           = Kp_I * R_f / L_f;       % ≈ 314

T_sim          = 1.5;                    % s
solver_step    = 5e-6;                   % 5 µs MaxStep (20 samples per carrier)

% Analytical SS predictions — 3-PHASE TOTAL POWER (includes 3/2 factor
% from the amplitude-invariant Park transformation; this is what the
% power-calc block in the model computes and what swing eq sees).
% Pre-disturb:  V_d = V_set, V_q = 0, current set by load impedance
ZL_d_pre       = (R_load_init^2 + (omega_s*L_load)^2)/R_load_init;
I_d_ss_pre     = V_set / ZL_d_pre;
I_q_ss_pre     = -omega_s*L_load*I_d_ss_pre/R_load_init;
P_ss_pre       = 1.5 * V_set * I_d_ss_pre;                       % 3-phase
Q_ss_pre       = 1.5 * (-V_set * I_q_ss_pre);                    % 3-phase

% Post-disturb (V_d held by voltage loop, R changed)
ZL_d_post      = (R_load_after^2 + (omega_s*L_load)^2)/R_load_after;
I_d_ss_post    = V_set / ZL_d_post;
P_ss_post      = 1.5 * V_set * I_d_ss_post;                      % 3-phase

dP_pu          = (P_ss_post - P_ss_pre)/P_base;
df_ss_pred     = -R_p * dP_pu * f_base;
f_ss_pred      = f_base + df_ss_pred;

%% --- SAFE MODEL INIT ----------------------------------------------------

model      = 'vsg_stage5a';
script_dir = fileparts(mfilename('fullpath'));
model_path = fullfile(script_dir, [model '.slx']);

if bdIsLoaded(model); close_system(model, 0); end
if exist(model_path, 'file'); delete(model_path); end

evalin('base', ['clear omega_ts delta_ts Vd_ref_ts ' ...
                'Vload_d_ts Vload_q_ts iL_d_ts iL_q_ts ' ...
                'Vload_a_ts Vload_b_ts Vload_c_ts ' ...
                'Vinv_a_ts P_ts Q_ts iload_abc_ts iL_abc_ts']);

new_system(model);
open_system(model);
set_param(model, 'Location', [40 40 1600 1000]);

%% --- LAYOUT HELPERS -----------------------------------------------------

BW = 50; BH = 22;
pos = @(x, y) [x-BW, y-BH, x+BW, y+BH];

ln = @(s, d) add_line(model, s, d, 'autorouting', 'on');
goto_block = @(name, tag, pos_) add_block('simulink/Signal Routing/Goto', ...
    [model '/' name], 'GotoTag', tag, 'TagVisibility', 'global', 'Position', pos_);
from_block = @(name, tag, pos_) add_block('simulink/Signal Routing/From', ...
    [model '/' name], 'GotoTag', tag, 'Position', pos_);

% Vertical bands (y centres)
Y_OUTER  = 80;     % swing eq + P-f droop
Y_QV     = 200;    % Q-V droop
Y_VLOOP  = 320;    % voltage loop PIs (d, q)
Y_ILOOP  = 460;    % current loop PIs (d, q)
Y_IPARK  = 600;    % inverse Park (dq → abc)
Y_PWM    = 720;    % PWM + bridge
Y_LC     = 840;    % 3-phase LC filter
Y_LOAD   = 980;    % 3-phase RL load
Y_FPARK  = 1120;   % forward Park (abc → dq for feedback)
Y_PWR    = 1260;   % power calc
Y_LOG    = 1380;   % logging

%% =========================================================================
%  1) SOURCES
%% =========================================================================

add_block('simulink/Sources/Constant', [model '/P_set'], ...
    'Value', num2str(P_set_pu), 'Position', pos(80, Y_OUTER-30));
add_block('simulink/Sources/Constant', [model '/omega_s_const'], ...
    'Value', num2str(omega_s),  'Position', pos(80, Y_OUTER+30));
add_block('simulink/Sources/Constant', [model '/V_set'], ...
    'Value', num2str(V_set),    'Position', pos(80, Y_QV-30));
add_block('simulink/Sources/Constant', [model '/Q_set'], ...
    'Value', num2str(Q_set),    'Position', pos(80, Y_QV+30));
add_block('simulink/Sources/Constant', [model '/Vq_ref_zero'], ...
    'Value', '0',               'Position', pos(80, Y_VLOOP+60));

%% =========================================================================
%  2) OUTER LOOP — Swing equation + P-f droop  (same as Stage 4)
%% =========================================================================

from_block('From_Pmeas_outer', 'P_meas', pos(160, Y_OUTER+100));
add_block('simulink/Math Operations/Gain', [model '/P_to_pu'], ...
    'Gain', num2str(1/P_base), 'Position', pos(260, Y_OUTER+100));
ln('From_Pmeas_outer/1', 'P_to_pu/1');

from_block('From_omega_outer', 'omega', pos(260, Y_OUTER-100));
add_block('simulink/Sources/Constant', [model '/omega_s_outer'], ...
    'Value', num2str(omega_s), 'Position', pos(260, Y_OUTER-30));
add_block('simulink/Math Operations/Sum', [model '/Sum_dev_outer'], ...
    'Inputs', '+-', 'Position', pos(380, Y_OUTER-60));
ln('From_omega_outer/1', 'Sum_dev_outer/1');
ln('omega_s_outer/1',    'Sum_dev_outer/2');

add_block('simulink/Math Operations/Gain', [model '/Gain_droop_pf'], ...
    'Gain', num2str(-K_droop_pf), 'Position', pos(500, Y_OUTER-60));
ln('Sum_dev_outer/1', 'Gain_droop_pf/1');

add_block('simulink/Math Operations/Sum', [model '/Sum_Pm'], ...
    'Inputs', '++', 'Position', pos(620, Y_OUTER-30));
ln('P_set/1',         'Sum_Pm/1');
ln('Gain_droop_pf/1', 'Sum_Pm/2');

add_block('simulink/Math Operations/Sum', [model '/Sum_PmPe'], ...
    'Inputs', '+-', 'Position', pos(740, Y_OUTER));
ln('Sum_Pm/1',  'Sum_PmPe/1');
ln('P_to_pu/1', 'Sum_PmPe/2');

add_block('simulink/Math Operations/Gain', [model '/Gain_D'], ...
    'Gain', num2str(D), 'Position', pos(620, Y_OUTER+80));
ln('Sum_dev_outer/1', 'Gain_D/1');

add_block('simulink/Math Operations/Sum', [model '/Sum_swing'], ...
    'Inputs', '+-', 'Position', pos(860, Y_OUTER));
ln('Sum_PmPe/1', 'Sum_swing/1');
ln('Gain_D/1',   'Sum_swing/2');

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_2Hws'], ...
    'Gain', num2str(1/inertia_coeff), 'Position', pos(980, Y_OUTER));
ln('Sum_swing/1', 'Gain_inv_2Hws/1');

add_block('simulink/Continuous/Integrator', [model '/Int_omega'], ...
    'InitialCondition', num2str(omega_s), 'Position', pos(1100, Y_OUTER));
ln('Gain_inv_2Hws/1', 'Int_omega/1');

goto_block('Goto_omega', 'omega', pos(1220, Y_OUTER));
ln('Int_omega/1', 'Goto_omega/1');

% Delta integrator (the dq frame phase — used by Park transforms)
from_block('From_omega_d', 'omega', pos(1100, Y_OUTER+80));
add_block('simulink/Sources/Constant', [model '/omega_s_d'], ...
    'Value', num2str(omega_s), 'Position', pos(1100, Y_OUTER+120));
add_block('simulink/Math Operations/Sum', [model '/Sum_dom'], ...
    'Inputs', '+-', 'Position', pos(1220, Y_OUTER+100));
ln('From_omega_d/1', 'Sum_dom/1');
ln('omega_s_d/1',    'Sum_dom/2');

% NOTE: For Park transformations we need the ABSOLUTE phase angle of the
% VSG output (theta = omega_s*t + integral of slip), not just the slip
% delta. Use Int_theta with input = omega (not omega - omega_s).
add_block('simulink/Continuous/Integrator', [model '/Int_theta'], ...
    'InitialCondition', '0', 'Position', pos(1340, Y_OUTER));
ln('From_omega_d/1', 'Int_theta/1');
goto_block('Goto_theta', 'theta', pos(1460, Y_OUTER));
ln('Int_theta/1', 'Goto_theta/1');

% Also keep delta (slip integral) for diagnostics
add_block('simulink/Continuous/Integrator', [model '/Int_delta'], ...
    'InitialCondition', '0', 'Position', pos(1340, Y_OUTER+100));
ln('Sum_dom/1', 'Int_delta/1');
goto_block('Goto_delta', 'delta', pos(1460, Y_OUTER+100));
ln('Int_delta/1', 'Goto_delta/1');

%% =========================================================================
%  3) Q-V DROOP
%% =========================================================================

from_block('From_Qmeas', 'Q_meas', pos(160, Y_QV-80));
add_block('simulink/Math Operations/Sum', [model '/Sum_Qerr'], ...
    'Inputs', '+-', 'Position', pos(280, Y_QV-30));
ln('From_Qmeas/1', 'Sum_Qerr/1');
ln('Q_set/1',      'Sum_Qerr/2');
add_block('simulink/Math Operations/Gain', [model '/Gain_qv'], ...
    'Gain', num2str(-K_droop_qv), 'Position', pos(400, Y_QV-30));
ln('Sum_Qerr/1', 'Gain_qv/1');
add_block('simulink/Math Operations/Sum', [model '/Sum_Vdref'], ...
    'Inputs', '++', 'Position', pos(520, Y_QV));
ln('V_set/1',  'Sum_Vdref/1');
ln('Gain_qv/1','Sum_Vdref/2');
goto_block('Goto_Vdref', 'V_d_ref', pos(640, Y_QV));
ln('Sum_Vdref/1', 'Goto_Vdref/1');

%% =========================================================================
%  4) V-I CASCADED PI in dq
%% =========================================================================

% --- d-axis voltage PI ---
from_block('From_Vdref_v', 'V_d_ref',  pos(160, Y_VLOOP-30));
from_block('From_VLd_v',   'V_load_d', pos(160, Y_VLOOP));
add_block('simulink/Math Operations/Sum', [model '/Sum_Vderr'], ...
    'Inputs', '+-', 'Position', pos(280, Y_VLOOP-15));
ln('From_Vdref_v/1', 'Sum_Vderr/1');
ln('From_VLd_v/1',   'Sum_Vderr/2');
add_block('simulink/Continuous/PID Controller', [model '/PI_V_d'], ...
    'Controller', 'PI', 'P', num2str(Kp_V), 'I', num2str(Ki_V), ...
    'Position', pos(400, Y_VLOOP-15));
ln('Sum_Vderr/1', 'PI_V_d/1');
goto_block('Goto_idref', 'i_d_ref', pos(520, Y_VLOOP-15));
ln('PI_V_d/1', 'Goto_idref/1');

% --- q-axis voltage PI ---
from_block('From_VLq_v', 'V_load_q', pos(160, Y_VLOOP+60));
add_block('simulink/Math Operations/Sum', [model '/Sum_Vqerr'], ...
    'Inputs', '+-', 'Position', pos(280, Y_VLOOP+45));
ln('Vq_ref_zero/1', 'Sum_Vqerr/1');
ln('From_VLq_v/1',  'Sum_Vqerr/2');
add_block('simulink/Continuous/PID Controller', [model '/PI_V_q'], ...
    'Controller', 'PI', 'P', num2str(Kp_V), 'I', num2str(Ki_V), ...
    'Position', pos(400, Y_VLOOP+45));
ln('Sum_Vqerr/1', 'PI_V_q/1');
goto_block('Goto_iqref', 'i_q_ref', pos(520, Y_VLOOP+45));
ln('PI_V_q/1', 'Goto_iqref/1');

% --- d-axis current PI ---
from_block('From_idref', 'i_d_ref', pos(640, Y_ILOOP-30));
from_block('From_iLd_c', 'i_L_d',   pos(640, Y_ILOOP));
add_block('simulink/Math Operations/Sum', [model '/Sum_iderr'], ...
    'Inputs', '+-', 'Position', pos(760, Y_ILOOP-15));
ln('From_idref/1', 'Sum_iderr/1');
ln('From_iLd_c/1', 'Sum_iderr/2');
add_block('simulink/Continuous/PID Controller', [model '/PI_I_d'], ...
    'Controller', 'PI', 'P', num2str(Kp_I), 'I', num2str(Ki_I), ...
    'Position', pos(880, Y_ILOOP-15));
ln('Sum_iderr/1', 'PI_I_d/1');
goto_block('Goto_Vinvd', 'V_inv_d_ref', pos(1000, Y_ILOOP-15));
ln('PI_I_d/1', 'Goto_Vinvd/1');

% --- q-axis current PI ---
from_block('From_iqref', 'i_q_ref', pos(640, Y_ILOOP+60));
from_block('From_iLq_c', 'i_L_q',   pos(640, Y_ILOOP+90));
add_block('simulink/Math Operations/Sum', [model '/Sum_iqerr'], ...
    'Inputs', '+-', 'Position', pos(760, Y_ILOOP+75));
ln('From_iqref/1', 'Sum_iqerr/1');
ln('From_iLq_c/1', 'Sum_iqerr/2');
add_block('simulink/Continuous/PID Controller', [model '/PI_I_q'], ...
    'Controller', 'PI', 'P', num2str(Kp_I), 'I', num2str(Ki_I), ...
    'Position', pos(880, Y_ILOOP+75));
ln('Sum_iqerr/1', 'PI_I_q/1');
goto_block('Goto_Vinvq', 'V_inv_q_ref', pos(1000, Y_ILOOP+75));
ln('PI_I_q/1', 'Goto_Vinvq/1');

%% =========================================================================
%  5) INVERSE PARK  (dq → abc, amplitude-invariant)
%% =========================================================================
% v_a = v_d*cos(theta)         - v_q*sin(theta)
% v_b = v_d*cos(theta-2pi/3)   - v_q*sin(theta-2pi/3)
% v_c = v_d*cos(theta+2pi/3)   - v_q*sin(theta+2pi/3)

from_block('From_Vinvd_p', 'V_inv_d_ref', pos(160, Y_IPARK-30));
from_block('From_Vinvq_p', 'V_inv_q_ref', pos(160, Y_IPARK));
from_block('From_theta_ip','theta',       pos(160, Y_IPARK+30));

add_block('simulink/Signal Routing/Mux', [model '/Mux_dqt_inv'], ...
    'Inputs', '3', 'Position', pos(280, Y_IPARK));
ln('From_Vinvd_p/1', 'Mux_dqt_inv/1');
ln('From_Vinvq_p/1', 'Mux_dqt_inv/2');
ln('From_theta_ip/1','Mux_dqt_inv/3');

add_block('simulink/User-Defined Functions/Fcn', [model '/Fcn_Va_ref'], ...
    'Expr', 'u(1)*cos(u(3)) - u(2)*sin(u(3))', ...
    'Position', pos(420, Y_IPARK-50));
add_block('simulink/User-Defined Functions/Fcn', [model '/Fcn_Vb_ref'], ...
    'Expr', 'u(1)*cos(u(3) - 2*pi/3) - u(2)*sin(u(3) - 2*pi/3)', ...
    'Position', pos(420, Y_IPARK));
add_block('simulink/User-Defined Functions/Fcn', [model '/Fcn_Vc_ref'], ...
    'Expr', 'u(1)*cos(u(3) + 2*pi/3) - u(2)*sin(u(3) + 2*pi/3)', ...
    'Position', pos(420, Y_IPARK+50));

ln('Mux_dqt_inv/1', 'Fcn_Va_ref/1');
ln('Mux_dqt_inv/1', 'Fcn_Vb_ref/1');
ln('Mux_dqt_inv/1', 'Fcn_Vc_ref/1');

goto_block('Goto_Varef', 'V_a_ref', pos(560, Y_IPARK-50));
goto_block('Goto_Vbref', 'V_b_ref', pos(560, Y_IPARK));
goto_block('Goto_Vcref', 'V_c_ref', pos(560, Y_IPARK+50));
ln('Fcn_Va_ref/1', 'Goto_Varef/1');
ln('Fcn_Vb_ref/1', 'Goto_Vbref/1');
ln('Fcn_Vc_ref/1', 'Goto_Vcref/1');

%% =========================================================================
%  6) PWM + BEHAVIOURAL 2-LEVEL BRIDGE
%% =========================================================================
% Triangle carrier at 10 kHz amplitude ±V_dc/2.
% Compare V_x_ref vs V_carrier. Output = sign(V_x_ref - V_carrier) * V_dc/2.
% This emulates an ideal 2-level VSI without modelling individual switches.

% --- Triangle carrier --------------------------------------------------
% Repeating Sequence: 1 carrier period [0, T_sw/2, T_sw], values [-amp, +amp, -amp]
add_block('simulink/Sources/Repeating Sequence', [model '/Carrier'], ...
    'rep_seq_t', sprintf('[0 %g %g]', T_sw/2, T_sw), ...
    'rep_seq_y', sprintf('[%g %g %g]', -carrier_amp, carrier_amp, -carrier_amp), ...
    'Position', pos(700, Y_PWM-80));
goto_block('Goto_carrier', 'V_carrier', pos(820, Y_PWM-80));
ln('Carrier/1', 'Goto_carrier/1');

% --- Per-phase compare → sign → scale to V_dc/2 ------------------------
phases = {'a','b','c'};
phase_y = [Y_PWM-40, Y_PWM, Y_PWM+40];
for k = 1:3
    ph = phases{k}; y = phase_y(k);
    from_block(sprintf('Fp_V%sref',ph), sprintf('V_%s_ref',ph), pos(700, y));
    from_block(sprintf('Fp_carr_%s',ph), 'V_carrier',           pos(700, y+20));

    add_block('simulink/Math Operations/Sum', [model '/Sum_pwm_' ph], ...
        'Inputs', '+-', 'Position', pos(820, y));
    ln(sprintf('Fp_V%sref/1',ph), sprintf('Sum_pwm_%s/1',ph));
    ln(sprintf('Fp_carr_%s/1',ph), sprintf('Sum_pwm_%s/2',ph));

    add_block('simulink/Math Operations/Sign', [model '/Sign_pwm_' ph], ...
        'Position', pos(940, y));
    ln(sprintf('Sum_pwm_%s/1',ph), sprintf('Sign_pwm_%s/1',ph));

    add_block('simulink/Math Operations/Gain', [model '/Gain_Vinv_' ph], ...
        'Gain', num2str(V_dc/2), 'Position', pos(1060, y));
    ln(sprintf('Sign_pwm_%s/1',ph), sprintf('Gain_Vinv_%s/1',ph));

    goto_block(sprintf('Goto_Vinv_%s',ph), sprintf('V_inv_%s',ph), pos(1180, y));
    ln(sprintf('Gain_Vinv_%s/1',ph), sprintf('Goto_Vinv_%s/1',ph));
end

%% =========================================================================
%  7) 3-PHASE LC FILTER  (vector, balanced, neutral grounded)
%% =========================================================================
% Per phase:
%   L_f * di_L/dt    = V_inv - V_load - R_f*i_L
%   C_f * dV_load/dt = i_L  - i_load
%
% Implemented as 3-element vector signals.

% Mux V_inv_a,b,c into V_inv_abc vector
from_block('Fp_Vinva_lc', 'V_inv_a', pos(160, Y_LC-30));
from_block('Fp_Vinvb_lc', 'V_inv_b', pos(160, Y_LC));
from_block('Fp_Vinvc_lc', 'V_inv_c', pos(160, Y_LC+30));
add_block('simulink/Signal Routing/Mux', [model '/Mux_Vinv_abc'], ...
    'Inputs', '3', 'Position', pos(280, Y_LC));
ln('Fp_Vinva_lc/1', 'Mux_Vinv_abc/1');
ln('Fp_Vinvb_lc/1', 'Mux_Vinv_abc/2');
ln('Fp_Vinvc_lc/1', 'Mux_Vinv_abc/3');

% Read back V_load_abc and i_L_abc for the LC RHS
from_block('Fp_VL_lc', 'V_load_abc', pos(280, Y_LC+80));
from_block('Fp_iL_lc', 'i_L_abc',    pos(280, Y_LC+110));

% R_f * i_L
add_block('simulink/Math Operations/Gain', [model '/Gain_Rf_lc'], ...
    'Gain', num2str(R_f), 'Position', pos(400, Y_LC+110));
ln('Fp_iL_lc/1', 'Gain_Rf_lc/1');

% Sum: V_inv - V_load - R_f*i_L
add_block('simulink/Math Operations/Sum', [model '/Sum_diL'], ...
    'Inputs', '+--', 'Position', pos(520, Y_LC));
ln('Mux_Vinv_abc/1', 'Sum_diL/1');
ln('Fp_VL_lc/1',     'Sum_diL/2');
ln('Gain_Rf_lc/1',   'Sum_diL/3');

% × 1/L_f
add_block('simulink/Math Operations/Gain', [model '/Gain_inv_Lf'], ...
    'Gain', num2str(1/L_f), 'Position', pos(640, Y_LC));
ln('Sum_diL/1', 'Gain_inv_Lf/1');

% Integrator → i_L_abc
add_block('simulink/Continuous/Integrator', [model '/Int_iL_abc'], ...
    'InitialCondition', '[0;0;0]', 'Position', pos(760, Y_LC));
ln('Gain_inv_Lf/1', 'Int_iL_abc/1');
goto_block('Goto_iLabc', 'i_L_abc', pos(880, Y_LC));
ln('Int_iL_abc/1', 'Goto_iLabc/1');

% Capacitor dynamics: dV_load/dt = (i_L - i_load) / C_f
from_block('Fp_iload_C', 'i_load_abc', pos(880, Y_LC+80));
add_block('simulink/Math Operations/Sum', [model '/Sum_dVL'], ...
    'Inputs', '+-', 'Position', pos(1000, Y_LC+40));
ln('Int_iL_abc/1', 'Sum_dVL/1');
ln('Fp_iload_C/1', 'Sum_dVL/2');

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_Cf'], ...
    'Gain', num2str(1/C_f), 'Position', pos(1120, Y_LC+40));
ln('Sum_dVL/1', 'Gain_inv_Cf/1');

add_block('simulink/Continuous/Integrator', [model '/Int_Vload_abc'], ...
    'InitialCondition', '[0;0;0]', 'Position', pos(1240, Y_LC+40));
ln('Gain_inv_Cf/1', 'Int_Vload_abc/1');
goto_block('Goto_Vloadabc', 'V_load_abc', pos(1360, Y_LC+40));
ln('Int_Vload_abc/1', 'Goto_Vloadabc/1');

%% =========================================================================
%  8) 3-PHASE RL LOAD with stepped R_load disturbance
%% =========================================================================
% L_load * di_load/dt = V_load - R_load(t) * i_load
% R_load(t) is a scalar Step that we broadcast to a 3-vector before
% element-wise multiplying with i_load_abc.

% R_load_signal scalar step
add_block('simulink/Sources/Step', [model '/R_load_step'], ...
    'Time',   num2str(R_load_t), ...
    'Before', num2str(R_load_init), ...
    'After',  num2str(R_load_after), ...
    'Position', pos(160, Y_LOAD-50));

% Broadcast scalar → 3-vector by Muxing the same scalar 3 times
add_block('simulink/Signal Routing/Mux', [model '/Mux_Rload_vec'], ...
    'Inputs', '3', 'Position', pos(280, Y_LOAD-50));
ln('R_load_step/1', 'Mux_Rload_vec/1');
ln('R_load_step/1', 'Mux_Rload_vec/2');
ln('R_load_step/1', 'Mux_Rload_vec/3');

% Element-wise product with i_load_abc
from_block('Fp_iload_load', 'i_load_abc', pos(280, Y_LOAD+10));
add_block('simulink/Math Operations/Product', [model '/Prod_Rload_iload'], ...
    'Inputs', '2', 'Multiplication', 'Element-wise(.*)', ...
    'Position', pos(400, Y_LOAD-20));
ln('Mux_Rload_vec/1',   'Prod_Rload_iload/1');
ln('Fp_iload_load/1',   'Prod_Rload_iload/2');

% V_load - R*i_load
from_block('Fp_Vload_load', 'V_load_abc', pos(400, Y_LOAD+50));
add_block('simulink/Math Operations/Sum', [model '/Sum_diload'], ...
    'Inputs', '+-', 'Position', pos(520, Y_LOAD+10));
ln('Fp_Vload_load/1',     'Sum_diload/1');
ln('Prod_Rload_iload/1',  'Sum_diload/2');

% × 1/L_load
add_block('simulink/Math Operations/Gain', [model '/Gain_inv_Lload'], ...
    'Gain', num2str(1/L_load), 'Position', pos(640, Y_LOAD+10));
ln('Sum_diload/1', 'Gain_inv_Lload/1');

% Integrator → i_load_abc
add_block('simulink/Continuous/Integrator', [model '/Int_iload_abc'], ...
    'InitialCondition', '[0;0;0]', 'Position', pos(760, Y_LOAD+10));
ln('Gain_inv_Lload/1', 'Int_iload_abc/1');
goto_block('Goto_iloadabc', 'i_load_abc', pos(880, Y_LOAD+10));
ln('Int_iload_abc/1', 'Goto_iloadabc/1');

%% =========================================================================
%  9) FORWARD PARK  (abc → dq, amplitude-invariant)
%% =========================================================================
% v_d = (2/3) * [ v_a*cos(theta)        + v_b*cos(theta-2pi/3) + v_c*cos(theta+2pi/3) ]
% v_q = -(2/3)* [ v_a*sin(theta)        + v_b*sin(theta-2pi/3) + v_c*sin(theta+2pi/3) ]
%
% Applied to BOTH V_load_abc (for voltage loop feedback) and i_L_abc
% (for current loop feedback).

% --- V_load_abc → V_load_d, V_load_q ---
from_block('Fp_Vload_park', 'V_load_abc', pos(160, Y_FPARK-30));
from_block('Fp_theta_VLpark', 'theta', pos(160, Y_FPARK+30));

% Demux V_load_abc → 3 scalars
add_block('simulink/Signal Routing/Demux', [model '/Demux_VL'], ...
    'Outputs', '3', 'Position', pos(280, Y_FPARK-30));
ln('Fp_Vload_park/1', 'Demux_VL/1');

% Bundle [v_a, v_b, v_c, theta] into 4-vector for Fcn input
add_block('simulink/Signal Routing/Mux', [model '/Mux_VL_park'], ...
    'Inputs', '4', 'Position', pos(400, Y_FPARK-15));
ln('Demux_VL/1',         'Mux_VL_park/1');
ln('Demux_VL/2',         'Mux_VL_park/2');
ln('Demux_VL/3',         'Mux_VL_park/3');
ln('Fp_theta_VLpark/1',  'Mux_VL_park/4');

add_block('simulink/User-Defined Functions/Fcn', [model '/Fcn_VLd'], ...
    'Expr', '(2/3)*( u(1)*cos(u(4)) + u(2)*cos(u(4)-2*pi/3) + u(3)*cos(u(4)+2*pi/3) )', ...
    'Position', pos(540, Y_FPARK-30));
add_block('simulink/User-Defined Functions/Fcn', [model '/Fcn_VLq'], ...
    'Expr', '-(2/3)*( u(1)*sin(u(4)) + u(2)*sin(u(4)-2*pi/3) + u(3)*sin(u(4)+2*pi/3) )', ...
    'Position', pos(540, Y_FPARK+20));
ln('Mux_VL_park/1', 'Fcn_VLd/1');
ln('Mux_VL_park/1', 'Fcn_VLq/1');

goto_block('Goto_VLd', 'V_load_d', pos(680, Y_FPARK-30));
goto_block('Goto_VLq', 'V_load_q', pos(680, Y_FPARK+20));
ln('Fcn_VLd/1', 'Goto_VLd/1');
ln('Fcn_VLq/1', 'Goto_VLq/1');

% --- i_L_abc → i_L_d, i_L_q ---
from_block('Fp_iL_park',     'i_L_abc', pos(800, Y_FPARK-30));
from_block('Fp_theta_iLpark','theta',   pos(800, Y_FPARK+30));

add_block('simulink/Signal Routing/Demux', [model '/Demux_iL'], ...
    'Outputs', '3', 'Position', pos(920, Y_FPARK-30));
ln('Fp_iL_park/1', 'Demux_iL/1');

add_block('simulink/Signal Routing/Mux', [model '/Mux_iL_park'], ...
    'Inputs', '4', 'Position', pos(1040, Y_FPARK-15));
ln('Demux_iL/1',         'Mux_iL_park/1');
ln('Demux_iL/2',         'Mux_iL_park/2');
ln('Demux_iL/3',         'Mux_iL_park/3');
ln('Fp_theta_iLpark/1',  'Mux_iL_park/4');

add_block('simulink/User-Defined Functions/Fcn', [model '/Fcn_iLd'], ...
    'Expr', '(2/3)*( u(1)*cos(u(4)) + u(2)*cos(u(4)-2*pi/3) + u(3)*cos(u(4)+2*pi/3) )', ...
    'Position', pos(1180, Y_FPARK-30));
add_block('simulink/User-Defined Functions/Fcn', [model '/Fcn_iLq'], ...
    'Expr', '-(2/3)*( u(1)*sin(u(4)) + u(2)*sin(u(4)-2*pi/3) + u(3)*sin(u(4)+2*pi/3) )', ...
    'Position', pos(1180, Y_FPARK+20));
ln('Mux_iL_park/1', 'Fcn_iLd/1');
ln('Mux_iL_park/1', 'Fcn_iLq/1');

goto_block('Goto_iLd', 'i_L_d', pos(1320, Y_FPARK-30));
goto_block('Goto_iLq', 'i_L_q', pos(1320, Y_FPARK+20));
ln('Fcn_iLd/1', 'Goto_iLd/1');
ln('Fcn_iLq/1', 'Goto_iLq/1');

%% =========================================================================
%  10) POWER CALCULATION   (in dq, at the inverter terminal)
%% =========================================================================
% P = (3/2) * ( V_load_d * i_L_d + V_load_q * i_L_q )
% Q = (3/2) * ( V_load_q * i_L_d - V_load_d * i_L_q )

from_block('Fp_VLd_p',  'V_load_d', pos(160, Y_PWR));
from_block('Fp_VLq_p',  'V_load_q', pos(160, Y_PWR+20));
from_block('Fp_iLd_p',  'i_L_d',    pos(160, Y_PWR+40));
from_block('Fp_iLq_p',  'i_L_q',    pos(160, Y_PWR+60));

add_block('simulink/Math Operations/Product', [model '/Prod_VdId'], ...
    'Position', pos(280, Y_PWR+10));
ln('Fp_VLd_p/1', 'Prod_VdId/1');
ln('Fp_iLd_p/1', 'Prod_VdId/2');

add_block('simulink/Math Operations/Product', [model '/Prod_VqIq'], ...
    'Position', pos(280, Y_PWR+50));
ln('Fp_VLq_p/1', 'Prod_VqIq/1');
ln('Fp_iLq_p/1', 'Prod_VqIq/2');

add_block('simulink/Math Operations/Sum', [model '/Sum_PinDQ'], ...
    'Inputs', '++', 'Position', pos(400, Y_PWR+30));
ln('Prod_VdId/1', 'Sum_PinDQ/1');
ln('Prod_VqIq/1', 'Sum_PinDQ/2');

add_block('simulink/Math Operations/Gain', [model '/Gain_3o2_P'], ...
    'Gain', '3/2', 'Position', pos(520, Y_PWR+30));
ln('Sum_PinDQ/1', 'Gain_3o2_P/1');
goto_block('Goto_P', 'P_meas', pos(640, Y_PWR+30));
ln('Gain_3o2_P/1', 'Goto_P/1');

add_block('simulink/Math Operations/Product', [model '/Prod_VqId'], ...
    'Position', pos(280, Y_PWR+100));
ln('Fp_VLq_p/1', 'Prod_VqId/1');
ln('Fp_iLd_p/1', 'Prod_VqId/2');

add_block('simulink/Math Operations/Product', [model '/Prod_VdIq'], ...
    'Position', pos(280, Y_PWR+140));
ln('Fp_VLd_p/1', 'Prod_VdIq/1');
ln('Fp_iLq_p/1', 'Prod_VdIq/2');

add_block('simulink/Math Operations/Sum', [model '/Sum_QinDQ'], ...
    'Inputs', '+-', 'Position', pos(400, Y_PWR+120));
ln('Prod_VqId/1', 'Sum_QinDQ/1');
ln('Prod_VdIq/1', 'Sum_QinDQ/2');

add_block('simulink/Math Operations/Gain', [model '/Gain_3o2_Q'], ...
    'Gain', '3/2', 'Position', pos(520, Y_PWR+120));
ln('Sum_QinDQ/1', 'Gain_3o2_Q/1');
goto_block('Goto_Q', 'Q_meas', pos(640, Y_PWR+120));
ln('Gain_3o2_Q/1', 'Goto_Q/1');

%% =========================================================================
%  11) LOGGING (To Workspace)
%% =========================================================================

mk_tws = @(name, var, y) add_block('simulink/Sinks/To Workspace', ...
    [model '/' name], 'VariableName', var, 'SaveFormat', 'Timeseries', ...
    'Position', pos(820, y));

logs = {
    'omega',        'omega_ts';
    'delta',        'delta_ts';
    'V_d_ref',      'Vd_ref_ts';
    'V_load_d',     'Vload_d_ts';
    'V_load_q',     'Vload_q_ts';
    'i_L_d',        'iL_d_ts';
    'i_L_q',        'iL_q_ts';
    'V_load_abc',   'Vload_abc_ts';
    'i_L_abc',      'iL_abc_ts';
    'i_load_abc',   'iload_abc_ts';
    'V_inv_a',      'Vinv_a_ts';
    'P_meas',       'P_ts';
    'Q_meas',       'Q_ts';
};

for k = 1:size(logs,1)
    tag = logs{k,1}; var = logs{k,2};
    y = Y_LOG + (k-1)*30;
    from_block(['FL_' var], tag, pos(700, y));
    mk_tws(['TWS_' var], var, y);
    ln(['FL_' var '/1'], ['TWS_' var '/1']);
end

%% =========================================================================
%  12) SOLVER + RUN
%% =========================================================================

set_param(model, ...
    'Solver',   'ode23tb', ...
    'StopTime', num2str(T_sim), ...
    'MaxStep',  num2str(solver_step), ...
    'RelTol',   '1e-3', 'AbsTol', '1e-5');

save_system(model, model_path);
fprintf('[Stage 5a] Model saved : %s\n', model_path);

fprintf('[Stage 5a] Simulating (T_sim = %g s) — this will take 3-5 min ...\n', T_sim);
sim(model);

% Pull timeseries (R2018b: split .Data off evalin)
ots = evalin('base','omega_ts');     t = ots.Time;  omega = ots.Data;
dts = evalin('base','delta_ts');     delta = dts.Data;
Vdr = evalin('base','Vd_ref_ts');    Vd_ref = Vdr.Data;
VLd = evalin('base','Vload_d_ts');   Vload_d = VLd.Data;
VLq = evalin('base','Vload_q_ts');   Vload_q = VLq.Data;
ILd = evalin('base','iL_d_ts');      iL_d = ILd.Data;
ILq = evalin('base','iL_q_ts');      iL_q = ILq.Data;
VLabc = evalin('base','Vload_abc_ts'); Vload_abc = VLabc.Data;
ILabc = evalin('base','iL_abc_ts');    iL_abc = ILabc.Data;
Iloadabc = evalin('base','iload_abc_ts'); iload_abc = Iloadabc.Data;
Vinva = evalin('base','Vinv_a_ts');  Vinv_a = Vinva.Data;
Pts = evalin('base','P_ts');         P_meas = Pts.Data;
Qts = evalin('base','Q_ts');         Q_meas = Qts.Data;
freq = omega/(2*pi);

%% --- SAVE .MAT ----------------------------------------------------------

out_path = fullfile(script_dir, 'vsg_stage5a_out.mat');
save(out_path, ...
     't', 'omega', 'delta', 'freq', 'Vd_ref', ...
     'Vload_d', 'Vload_q', 'iL_d', 'iL_q', ...
     'Vload_abc', 'iL_abc', 'iload_abc', 'Vinv_a', ...
     'P_meas', 'Q_meas', ...
     'V_dc','V_set','P_base','Q_base','f_base','omega_s', ...
     'H','D','R_p','R_q','L_f','C_f','R_f','f_sw','f_res', ...
     'R_load_init','R_load_after','L_load','R_load_t', ...
     'Kp_V','Ki_V','Kp_I','Ki_I', ...
     'P_ss_pre','P_ss_post','df_ss_pred','f_ss_pred','T_sim', ...
     '-v7');

fprintf('[Stage 5a] Data saved  : %s\n', out_path);
fprintf('  V_dc                 : %g V   (V_dc/2 = %g V linear SPWM max)\n', V_dc, V_dc/2);
fprintf('  Modulation index     : %.2f  (linear if < 1.0)\n', V_set/(V_dc/2));
fprintf('  Filter resonance     : %.0f Hz   PWM carrier : %.0f Hz\n', f_res, f_sw);
fprintf('  Pre-disturb  pred    : P_3ph = %6.2f W   Q_3ph = %6.2f VAR\n', P_ss_pre, Q_ss_pre);
fprintf('  Post-disturb pred    : P_3ph = %6.2f W   Df_ss = %+.3f Hz   f_ss = %.3f Hz\n', ...
        P_ss_post, df_ss_pred, f_ss_pred);
fprintf('  Sim final   measured : V_d   = %6.3f V    V_q  = %+.4f V\n', Vload_d(end), Vload_q(end));
fprintf('                          P_3ph = %6.2f W   Q_3ph = %6.2f VAR\n', P_meas(end), Q_meas(end));
fprintf('                          f     = %6.4f Hz   Df   = %+.4f Hz\n', freq(end), freq(end)-f_base);

%% --- QUICK PLOT ---------------------------------------------------------

figure('Name','VSG Stage 5a — abc Switching Model','Color','w', ...
       'Position',[100 100 1200 800],'NumberTitle','off');

% 1) 3-phase V_load (zoomed near disturbance)
subplot(3,2,1);
plot(t, Vload_abc, 'LineWidth', 1.0); hold on;
plot([R_load_t R_load_t], ylim, 'k:');
xlim([R_load_t-0.02 R_load_t+0.04]);
ylabel('V_{load,abc} (V)'); grid on; title('3-phase V_{load} near disturbance');
legend({'a','b','c'},'Location','best','FontSize',8);

% 2) V_inv_a switched waveform (zoomed)
subplot(3,2,2);
plot(t, Vinv_a, 'b', 'LineWidth', 0.6);
xlim([0.10 0.12]);
ylabel('V_{inv,a} (V)'); grid on; title('Inverter output (switched, 10 kHz PWM)');

% 3) Frequency
subplot(3,2,3);
plot(t, freq, 'b', 'LineWidth', 1.4); hold on;
plot([t(1) t(end)], [f_base    f_base   ], 'r--');
plot([t(1) t(end)], [f_ss_pred f_ss_pred], 'g--');
plot([R_load_t R_load_t], ylim, 'k:');
ylabel('f (Hz)'); grid on; title('VSG frequency (P-f droop)');

% 4) V_d / V_q
subplot(3,2,4);
plot(t, Vload_d, 'b', 'LineWidth', 1.2); hold on;
plot(t, Vload_q, 'm', 'LineWidth', 1.0);
plot(t, Vd_ref,  'r--', 'LineWidth', 0.8);
plot([R_load_t R_load_t], ylim, 'k:');
ylabel('V (V)'); grid on; title('V_{load,dq} after Park');
legend({'V_d','V_q','V_{d,ref}'},'Location','best','FontSize',8);

% 5) P and Q
subplot(3,2,5);
yyaxis left;  plot(t, P_meas, 'LineWidth', 1.4); ylabel('P (W)');
yyaxis right; plot(t, Q_meas, 'LineWidth', 1.4); ylabel('Q (VAR)');
plot([R_load_t R_load_t], ylim, 'k:');
xlabel('Time (s)'); grid on; title('Measured P (left), Q (right)');

% 6) Droop characteristic
subplot(3,2,6);
P_axis = linspace(0, 1.5*P_base, 200);
f_line = f_base - R_p*(P_axis/P_base - P_set_pu)*f_base;
plot(P_axis, f_line, 'k-', 'LineWidth', 1.2); hold on;
plot(P_ss_pre, f_base, 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
plot(P_meas(end), freq(end), 'r*', 'MarkerSize', 14, 'LineWidth', 2);
xlabel('P (W)'); ylabel('f (Hz)'); grid on; title('Droop characteristic');
legend({sprintf('%g%% droop',R_p*100),'initial OP','final OP (sim)'}, ...
       'Location','best','FontSize',8);

fprintf('[Stage 5a] Done.\n');
