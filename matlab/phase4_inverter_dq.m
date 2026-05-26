% phase4_inverter_dq.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 4 — Average-Model Inverter + LC Filter + RL Load
%                             + Cascaded V-I Control + Q-V Droop (dq frame)
% =========================================================================
%
%  Stage 1-3 lived in abstract pu power balance. Stage 4 adds the FULL
%  physical layer in the synchronous dq reference frame rotating at the
%  VSG's own angular velocity omega_VSG. No abc, no PWM — those come in
%  Stage 5. Everything here is "average model" (switching ignored).
%
%  TOPOLOGY (everything in dq frame at omega_VSG):
%
%    V_inv_d/q ─[L_f, R_f]─► i_L_d/q ─► [C_f] ─► V_C_d/q ─► [R_load, L_load] ─► i_load_d/q
%                                          ▲
%                                          └── I_disturb_d (load-step input)
%
%  CONTROL CHAIN:
%
%       Q_meas ──► [Q-V droop]   ──► V_d_ref ──► [V loop PI] ──► I_d_ref ──► [I loop PI] ──► V_inv_d
%                                  V_q_ref=0  ──► [V loop PI] ──► I_q_ref ──► [I loop PI] ──► V_inv_q
%       P_meas ──► [Stage-3 swing eq + P-f droop] ──► omega, delta
%
%  PI TUNING (textbook cascaded-loop separation of bandwidths):
%       Current loop bandwidth :  omega_ci  = 2*pi*1000  =  6283 rad/s (~1 kHz)
%       Voltage loop bandwidth :  omega_cv  = 2*pi*100   =   628 rad/s (~100 Hz)
%       Outer droop loop       :  ~few Hz (set by H, R_p)
%
%  STEADY-STATE DESIGN POINT (chosen so the bench prototype maps cleanly):
%       V_dc      = 24  V    DC bus
%       V_ac_peak = 14  V    d-axis terminal voltage
%       R_load    = 1.91 ohm L_load = 1 mH   ->  P = 100 W, Q ~ 16.5 VAR
%       Filter:   L_f = 1.2 mH, C_f = 10 uF  ->  f_res ~ 1.45 kHz
%
%  DISTURBANCE: at t = 0.2 s, an extra current sink I_disturb_d = 2 A
%  is switched on in parallel with the load. Effective ΔP ~ 28 W (28%
%  increase). Predicted Δf_ss from P-f droop = -0.05 * 0.28 * 50 = -0.7 Hz.
%
%  OUTPUTS (next to this script):
%       vsg_stage4.slx
%       vsg_stage4_out.mat   (logs all dq states + P, Q, omega, V_d_ref)
%
%  Tested on MATLAB R2018b. Base Simulink only. Block count ~80.
%
%  Author  : Napoleon (Chinnawat Dumklang) - SUT EE
%  Stage 4 : 2026-05-26
% =========================================================================

%% --- PARAMETERS ---------------------------------------------------------

% Electrical base
V_dc           = 24;             % DC bus (V)
P_base         = 100;            % rated active power (W)
Q_base         = 100;            % rated reactive power (VAR)
f_base         = 50;             % Hz
omega_s        = 2*pi*f_base;    % rad/s
V_set          = 14;             % d-axis voltage setpoint (V peak)

% LC filter
L_f            = 1.2e-3;         % H
R_f            = 0.05;           % ohm — ESR of L_f
C_f            = 10e-6;          % F
f_res          = 1/(2*pi*sqrt(L_f*C_f));   % Hz (informational)

% RL load (sized so P = 100 W, Q ~ 16.5 VAR at V_d = 14 V steady state)
R_load         = 1.91;           % ohm
L_load         = 1e-3;           % H

% Outer VSG loop (Stage 3 pattern, with measured P instead of stepped P_load)
H              = 5;              % virtual inertia (s)
D              = 0;              % damping
R_p            = 0.05;           % P-f droop coefficient
K_droop_pf     = 1/(R_p*omega_s);% gain on (omega_s - omega)
P_set_pu       = 1.00;           % active-power setpoint (pu of P_base)
inertia_coeff  = 2*H/omega_s;    % s^2/rad

% Q-V droop  (V_d_ref = V_set - R_q*(Q_meas - Q_set))
R_q            = 0.05;           % 5% droop (V change per Q change in pu)
K_droop_qv     = R_q * V_set / Q_base;   % V per VAR  (0.05*14/100 = 0.007)
Q_set          = 0;              % VAR

% Voltage-loop PI (per axis)  —  omega_cv = 628 rad/s, zeta = 0.707
Kp_V           = 2*0.707*628*C_f;        % ~  8.88e-3
Ki_V           = 628^2 * C_f;            % ~  3.94

% Current-loop PI (per axis)  —  omega_ci = 6283 rad/s, pole/zero cancel
Kp_I           = 6283 * L_f;             % ~  7.54
Ki_I           = Kp_I * R_f / L_f;       % ~  314

% Disturbance: extra current sink stepped on at t = 0.2 s
I_disturb_t    = 0.20;           % step time (s)
I_disturb_d    = 2.0;            % step magnitude (A) on d-axis sink

T_sim          = 2.00;           % s — must cover ~5*tau_outer = 2.5 s for
                                 % the swing-equation outer loop to reach
                                 % its new steady state after the load
                                 % disturbance at t = 0.2 s. LC filter
                                 % dynamics settle in ~10 ms so they don't
                                 % drive the simulation horizon.

%% --- ANALYTICAL PREDICTIONS (printed at end) ----------------------------

% Steady-state load (before disturbance) — solved from V_d = 14, V_q = 0
ZL_d           = (R_load^2 + (omega_s*L_load)^2)/R_load;
I_load_d_ss0   = V_set / ZL_d;
I_load_q_ss0   = -omega_s*L_load * I_load_d_ss0 / R_load;
P_ss0          = V_set * I_load_d_ss0;
Q_ss0          = -V_set * I_load_q_ss0;

% After disturbance: V_d ~ V_set (voltage loop holds it), but extra 2 A is drawn
P_after        = V_set * (I_load_d_ss0 + I_disturb_d);
dP_pu          = (P_after - P_ss0) / P_base;
df_ss_pred     = -R_p * dP_pu * f_base;            % Hz
f_ss_pred      = f_base + df_ss_pred;

%% --- SAFE MODEL INIT ----------------------------------------------------

model      = 'vsg_stage4';
script_dir = fileparts(mfilename('fullpath'));
model_path = fullfile(script_dir, [model '.slx']);

if bdIsLoaded(model); close_system(model, 0); end

% Delete the previous .slx file from disk too, so the new in-memory
% model does not "shadow" the on-disk one (R2018b emits a warning if it
% sees the same name in two places).
if exist(model_path, 'file')
    delete(model_path);
end

evalin('base', ['clear omega_ts delta_ts Vd_ref_ts VCd_ts VCq_ts ' ...
                'iLd_ts iLq_ts iloadd_ts iloadq_ts P_ts Q_ts Vinv_d_ts Vinv_q_ts']);

new_system(model);
open_system(model);
set_param(model, 'Location', [40 40 1500 900]);

%% --- LAYOUT HELPERS -----------------------------------------------------

BW = 55;  BH = 22;
pos = @(x, y) [x-BW, y-BH, x+BW, y+BH];

% Vertical bands (each ~120 px tall)
Y_OUTER = 80;     % outer swing+droop+QV
Y_VLOOP = 220;    % voltage PIs
Y_ILOOP = 340;    % current PIs
Y_LFIL  = 460;    % filter L
Y_CFIL  = 580;    % filter C
Y_LOAD  = 700;    % RL load
Y_PWR   = 820;    % power calc

%% =========================================================================
%  HELPER LAMBDAS
%% =========================================================================
ln = @(s, d) add_line(model, s, d, 'autorouting', 'on');
goto_block = @(name, tag, pos_) add_block('simulink/Signal Routing/Goto', ...
    [model '/' name], 'GotoTag', tag, 'TagVisibility', 'global', 'Position', pos_);
from_block = @(name, tag, pos_) add_block('simulink/Signal Routing/From', ...
    [model '/' name], 'GotoTag', tag, 'Position', pos_);

%% =========================================================================
%  1) SOURCES (left column, x = 80)
%% =========================================================================

add_block('simulink/Sources/Constant', [model '/P_set'], ...
    'Value', num2str(P_set_pu), 'Position', pos(80, Y_OUTER-40));

add_block('simulink/Sources/Constant', [model '/V_set'], ...
    'Value', num2str(V_set), 'Position', pos(80, Y_VLOOP-40));

add_block('simulink/Sources/Constant', [model '/Q_set'], ...
    'Value', num2str(Q_set), 'Position', pos(80, Y_VLOOP+40));

add_block('simulink/Sources/Constant', [model '/Vq_ref_zero'], ...
    'Value', '0', 'Position', pos(80, Y_VLOOP+90));

% Disturbance: I_disturb_d step
add_block('simulink/Sources/Step', [model '/I_disturb'], ...
    'Time', num2str(I_disturb_t), 'Before', '0', 'After', num2str(I_disturb_d), ...
    'Position', pos(80, Y_CFIL+40));

%% =========================================================================
%  2) OUTER LOOP — Swing equation + P-f droop  (drives omega)
%% =========================================================================
% Pm = P_set + K_droop_pf * (omega_s - omega)
% (2H/ws) * domega/dt = Pm - P_meas_pu - D*(omega - omega_s)

% Convert P_meas (W) to pu
add_block('simulink/Math Operations/Gain', [model '/P_meas_to_pu'], ...
    'Gain', num2str(1/P_base), 'Position', pos(260, Y_OUTER+100));
from_block('From_Pmeas_outer', 'P_meas', pos(140, Y_OUTER+100));
ln('From_Pmeas_outer/1', 'P_meas_to_pu/1');

% Droop gain on (omega - omega_s) -> droop correction (sign: -K_droop_pf)
from_block('From_omega_outer', 'omega', pos(260, Y_OUTER-100));
add_block('simulink/Math Operations/Sum', [model '/Sum_dev_outer'], ...
    'Inputs', '+-', 'Position', pos(360, Y_OUTER-50));
ln('From_omega_outer/1',  'Sum_dev_outer/1');
add_block('simulink/Sources/Constant', [model '/omega_s_outer'], ...
    'Value', num2str(omega_s), 'Position', pos(260, Y_OUTER-20));
ln('omega_s_outer/1',     'Sum_dev_outer/2');

add_block('simulink/Math Operations/Gain', [model '/Gain_droop_pf'], ...
    'Gain', num2str(-K_droop_pf), 'Position', pos(460, Y_OUTER-50));
ln('Sum_dev_outer/1', 'Gain_droop_pf/1');

% Sum_Pm = P_set + droop_correction
add_block('simulink/Math Operations/Sum', [model '/Sum_Pm'], ...
    'Inputs', '++', 'Position', pos(560, Y_OUTER-50));
ln('P_set/1',         'Sum_Pm/1');
ln('Gain_droop_pf/1', 'Sum_Pm/2');

% Sum_PmPe = Pm - P_meas_pu
add_block('simulink/Math Operations/Sum', [model '/Sum_PmPe'], ...
    'Inputs', '+-', 'Position', pos(660, Y_OUTER));
ln('Sum_Pm/1',       'Sum_PmPe/1');
ln('P_meas_to_pu/1', 'Sum_PmPe/2');

% Damping branch (D = 0 default — block kept for symmetry)
add_block('simulink/Math Operations/Gain', [model '/Gain_D'], ...
    'Gain', num2str(D), 'Position', pos(560, Y_OUTER+80));
ln('Sum_dev_outer/1', 'Gain_D/1');

% Sum_swing
add_block('simulink/Math Operations/Sum', [model '/Sum_swing'], ...
    'Inputs', '+-', 'Position', pos(760, Y_OUTER));
ln('Sum_PmPe/1', 'Sum_swing/1');
ln('Gain_D/1',   'Sum_swing/2');

% Inertia gain
add_block('simulink/Math Operations/Gain', [model '/Gain_inv_2Hws'], ...
    'Gain', num2str(1/inertia_coeff), 'Position', pos(860, Y_OUTER));
ln('Sum_swing/1', 'Gain_inv_2Hws/1');

% Integrator -> omega
add_block('simulink/Continuous/Integrator', [model '/Int_omega'], ...
    'InitialCondition', num2str(omega_s), 'Position', pos(960, Y_OUTER));
ln('Gain_inv_2Hws/1', 'Int_omega/1');

% Broadcast omega
goto_block('Goto_omega', 'omega', pos(1080, Y_OUTER));
ln('Int_omega/1', 'Goto_omega/1');

% Delta integrator (drives the dq frame phase; here only used for logging)
from_block('From_omega_d', 'omega', pos(1080, Y_OUTER+80));
add_block('simulink/Sources/Constant', [model '/omega_s_d'], ...
    'Value', num2str(omega_s), 'Position', pos(1080, Y_OUTER+120));
add_block('simulink/Math Operations/Sum', [model '/Sum_dom'], ...
    'Inputs', '+-', 'Position', pos(1180, Y_OUTER+100));
ln('From_omega_d/1','Sum_dom/1');
ln('omega_s_d/1',   'Sum_dom/2');
add_block('simulink/Continuous/Integrator', [model '/Int_delta'], ...
    'InitialCondition', '0', 'Position', pos(1280, Y_OUTER+100));
ln('Sum_dom/1', 'Int_delta/1');
goto_block('Goto_delta', 'delta', pos(1380, Y_OUTER+100));
ln('Int_delta/1', 'Goto_delta/1');

%% =========================================================================
%  3) Q-V DROOP  →  V_d_ref
%% =========================================================================
% V_d_ref = V_set - K_droop_qv * (Q_meas - Q_set)

from_block('From_Qmeas', 'Q_meas', pos(180, Y_VLOOP-100));
add_block('simulink/Math Operations/Sum', [model '/Sum_Qerr'], ...
    'Inputs', '+-', 'Position', pos(260, Y_VLOOP-80));
ln('From_Qmeas/1','Sum_Qerr/1');
ln('Q_set/1',     'Sum_Qerr/2');
add_block('simulink/Math Operations/Gain', [model '/Gain_qv'], ...
    'Gain', num2str(-K_droop_qv), 'Position', pos(360, Y_VLOOP-80));
ln('Sum_Qerr/1', 'Gain_qv/1');
add_block('simulink/Math Operations/Sum', [model '/Sum_Vdref'], ...
    'Inputs', '++', 'Position', pos(460, Y_VLOOP-50));
ln('V_set/1',  'Sum_Vdref/1');
ln('Gain_qv/1','Sum_Vdref/2');
goto_block('Goto_Vdref', 'V_d_ref', pos(560, Y_VLOOP-50));
ln('Sum_Vdref/1', 'Goto_Vdref/1');

%% =========================================================================
%  4) VOLTAGE LOOP PIs  (d-axis and q-axis)
%% =========================================================================
% V_d_ref - V_C_d  ->  PI  ->  i_d_ref
% V_q_ref - V_C_q  ->  PI  ->  i_q_ref

% --- d-axis voltage PI ---
from_block('From_Vdref_v', 'V_d_ref', pos(640, Y_VLOOP-20));
from_block('From_VCd_v',   'V_C_d',   pos(640, Y_VLOOP+20));
add_block('simulink/Math Operations/Sum', [model '/Sum_Vderr'], ...
    'Inputs', '+-', 'Position', pos(740, Y_VLOOP));
ln('From_Vdref_v/1','Sum_Vderr/1');
ln('From_VCd_v/1',  'Sum_Vderr/2');
add_block('simulink/Continuous/PID Controller', [model '/PI_V_d'], ...
    'Controller', 'PI', 'P', num2str(Kp_V), 'I', num2str(Ki_V), ...
    'Position', pos(860, Y_VLOOP));
ln('Sum_Vderr/1', 'PI_V_d/1');
goto_block('Goto_idref', 'i_d_ref', pos(960, Y_VLOOP));
ln('PI_V_d/1', 'Goto_idref/1');

% --- q-axis voltage PI ---
from_block('From_VCq_v', 'V_C_q', pos(640, Y_VLOOP+80));
add_block('simulink/Math Operations/Sum', [model '/Sum_Vqerr'], ...
    'Inputs', '+-', 'Position', pos(740, Y_VLOOP+80));
ln('Vq_ref_zero/1', 'Sum_Vqerr/1');
ln('From_VCq_v/1',  'Sum_Vqerr/2');
add_block('simulink/Continuous/PID Controller', [model '/PI_V_q'], ...
    'Controller', 'PI', 'P', num2str(Kp_V), 'I', num2str(Ki_V), ...
    'Position', pos(860, Y_VLOOP+80));
ln('Sum_Vqerr/1', 'PI_V_q/1');
goto_block('Goto_iqref', 'i_q_ref', pos(960, Y_VLOOP+80));
ln('PI_V_q/1', 'Goto_iqref/1');

%% =========================================================================
%  5) CURRENT LOOP PIs  (d-axis and q-axis)
%% =========================================================================

% --- d-axis current PI ---
from_block('From_idref', 'i_d_ref', pos(120, Y_ILOOP-30));
from_block('From_iLd_c', 'i_L_d',   pos(120, Y_ILOOP+30));
add_block('simulink/Math Operations/Sum', [model '/Sum_iderr'], ...
    'Inputs', '+-', 'Position', pos(220, Y_ILOOP));
ln('From_idref/1', 'Sum_iderr/1');
ln('From_iLd_c/1', 'Sum_iderr/2');
add_block('simulink/Continuous/PID Controller', [model '/PI_I_d'], ...
    'Controller', 'PI', 'P', num2str(Kp_I), 'I', num2str(Ki_I), ...
    'Position', pos(340, Y_ILOOP));
ln('Sum_iderr/1', 'PI_I_d/1');
goto_block('Goto_Vinvd', 'V_inv_d', pos(460, Y_ILOOP));
ln('PI_I_d/1', 'Goto_Vinvd/1');

% --- q-axis current PI ---
from_block('From_iqref', 'i_q_ref', pos(120, Y_ILOOP+90));
from_block('From_iLq_c', 'i_L_q',   pos(120, Y_ILOOP+150));
add_block('simulink/Math Operations/Sum', [model '/Sum_iqerr'], ...
    'Inputs', '+-', 'Position', pos(220, Y_ILOOP+120));
ln('From_iqref/1', 'Sum_iqerr/1');
ln('From_iLq_c/1', 'Sum_iqerr/2');
add_block('simulink/Continuous/PID Controller', [model '/PI_I_q'], ...
    'Controller', 'PI', 'P', num2str(Kp_I), 'I', num2str(Ki_I), ...
    'Position', pos(340, Y_ILOOP+120));
ln('Sum_iqerr/1', 'PI_I_q/1');
goto_block('Goto_Vinvq', 'V_inv_q', pos(460, Y_ILOOP+120));
ln('PI_I_q/1', 'Goto_Vinvq/1');

%% =========================================================================
%  6) FILTER INDUCTOR DYNAMICS  (states: i_L_d, i_L_q)
%% =========================================================================
% L_f * di_L_d/dt = V_inv_d - V_C_d + omega*L_f*i_L_q - R_f*i_L_d
% L_f * di_L_q/dt = V_inv_q - V_C_q - omega*L_f*i_L_d - R_f*i_L_q

% ---- d axis ----
from_block('From_Vinvd_L', 'V_inv_d', pos(580, Y_LFIL-40));
from_block('From_VCd_L',   'V_C_d',   pos(580, Y_LFIL-10));
from_block('From_iLq_L',   'i_L_q',   pos(580, Y_LFIL+20));
from_block('From_omega_Ld','omega',   pos(580, Y_LFIL+50));
from_block('From_iLd_self','i_L_d',   pos(580, Y_LFIL+90));

% Cross-coupling: omega * i_L_q
add_block('simulink/Math Operations/Product', [model '/Prod_wiLq'], ...
    'Position', pos(700, Y_LFIL+35));
ln('From_omega_Ld/1', 'Prod_wiLq/1');
ln('From_iLq_L/1',    'Prod_wiLq/2');
add_block('simulink/Math Operations/Gain', [model '/Gain_Lf_wiLq'], ...
    'Gain', num2str(L_f), 'Position', pos(820, Y_LFIL+35));
ln('Prod_wiLq/1', 'Gain_Lf_wiLq/1');

% R_f * i_L_d
add_block('simulink/Math Operations/Gain', [model '/Gain_Rf_d'], ...
    'Gain', num2str(R_f), 'Position', pos(700, Y_LFIL+90));
ln('From_iLd_self/1', 'Gain_Rf_d/1');

% RHS sum:  V_inv_d  -  V_C_d  + omega*L_f*i_L_q  -  R_f*i_L_d
add_block('simulink/Math Operations/Sum', [model '/Sum_diLd'], ...
    'Inputs', '+-+-', 'Position', pos(940, Y_LFIL));
ln('From_Vinvd_L/1',   'Sum_diLd/1');
ln('From_VCd_L/1',     'Sum_diLd/2');
ln('Gain_Lf_wiLq/1',   'Sum_diLd/3');
ln('Gain_Rf_d/1',      'Sum_diLd/4');

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_Lf_d'], ...
    'Gain', num2str(1/L_f), 'Position', pos(1060, Y_LFIL));
ln('Sum_diLd/1', 'Gain_inv_Lf_d/1');

add_block('simulink/Continuous/Integrator', [model '/Int_iLd'], ...
    'InitialCondition', '0', 'Position', pos(1180, Y_LFIL));
ln('Gain_inv_Lf_d/1', 'Int_iLd/1');
goto_block('Goto_iLd', 'i_L_d', pos(1300, Y_LFIL));
ln('Int_iLd/1', 'Goto_iLd/1');

% ---- q axis ----   (symmetric, with - omega*L_f*i_L_d term)
from_block('From_Vinvq_L','V_inv_q', pos(580, Y_LFIL+130));
from_block('From_VCq_L',  'V_C_q',   pos(580, Y_LFIL+155));
from_block('From_iLd_L',  'i_L_d',   pos(580, Y_LFIL+180));
from_block('From_omega_Lq','omega',  pos(580, Y_LFIL+210));
from_block('From_iLq_self','i_L_q',  pos(580, Y_LFIL+240));

add_block('simulink/Math Operations/Product', [model '/Prod_wiLd'], ...
    'Position', pos(700, Y_LFIL+195));
ln('From_omega_Lq/1', 'Prod_wiLd/1');
ln('From_iLd_L/1',    'Prod_wiLd/2');
add_block('simulink/Math Operations/Gain', [model '/Gain_Lf_wiLd'], ...
    'Gain', num2str(L_f), 'Position', pos(820, Y_LFIL+195));
ln('Prod_wiLd/1', 'Gain_Lf_wiLd/1');

add_block('simulink/Math Operations/Gain', [model '/Gain_Rf_q'], ...
    'Gain', num2str(R_f), 'Position', pos(700, Y_LFIL+240));
ln('From_iLq_self/1', 'Gain_Rf_q/1');

% L_f * di_L_q/dt =  V_inv_q  -  V_C_q  -  omega*L_f*i_L_d  -  R_f*i_L_q
add_block('simulink/Math Operations/Sum', [model '/Sum_diLq'], ...
    'Inputs', '+---', 'Position', pos(940, Y_LFIL+170));
ln('From_Vinvq_L/1',  'Sum_diLq/1');
ln('From_VCq_L/1',    'Sum_diLq/2');
ln('Gain_Lf_wiLd/1',  'Sum_diLq/3');
ln('Gain_Rf_q/1',     'Sum_diLq/4');

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_Lf_q'], ...
    'Gain', num2str(1/L_f), 'Position', pos(1060, Y_LFIL+170));
ln('Sum_diLq/1', 'Gain_inv_Lf_q/1');

add_block('simulink/Continuous/Integrator', [model '/Int_iLq'], ...
    'InitialCondition', '0', 'Position', pos(1180, Y_LFIL+170));
ln('Gain_inv_Lf_q/1', 'Int_iLq/1');
goto_block('Goto_iLq', 'i_L_q', pos(1300, Y_LFIL+170));
ln('Int_iLq/1', 'Goto_iLq/1');

%% =========================================================================
%  7) FILTER CAPACITOR DYNAMICS  (states: V_C_d, V_C_q)
%% =========================================================================
% C_f * dV_C_d/dt =  i_L_d - i_load_d - I_disturb_d + omega*C_f*V_C_q
% C_f * dV_C_q/dt =  i_L_q - i_load_q              - omega*C_f*V_C_d

% ---- d axis ----
from_block('From_iLd_C',    'i_L_d',     pos(140, Y_CFIL-40));
from_block('From_iloadd_C', 'i_load_d',  pos(140, Y_CFIL-10));
from_block('From_VCq_self_d','V_C_q',    pos(140, Y_CFIL+20));
from_block('From_omega_Cd', 'omega',     pos(140, Y_CFIL+50));

add_block('simulink/Math Operations/Product', [model '/Prod_wVCq'], ...
    'Position', pos(260, Y_CFIL+35));
ln('From_omega_Cd/1',  'Prod_wVCq/1');
ln('From_VCq_self_d/1','Prod_wVCq/2');
add_block('simulink/Math Operations/Gain', [model '/Gain_Cf_wVCq'], ...
    'Gain', num2str(C_f), 'Position', pos(380, Y_CFIL+35));
ln('Prod_wVCq/1', 'Gain_Cf_wVCq/1');

add_block('simulink/Math Operations/Sum', [model '/Sum_dVCd'], ...
    'Inputs', '+--+', 'Position', pos(500, Y_CFIL));
ln('From_iLd_C/1',    'Sum_dVCd/1');
ln('From_iloadd_C/1', 'Sum_dVCd/2');
ln('I_disturb/1',     'Sum_dVCd/3');
ln('Gain_Cf_wVCq/1',  'Sum_dVCd/4');

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_Cf_d'], ...
    'Gain', num2str(1/C_f), 'Position', pos(620, Y_CFIL));
ln('Sum_dVCd/1', 'Gain_inv_Cf_d/1');

add_block('simulink/Continuous/Integrator', [model '/Int_VCd'], ...
    'InitialCondition', '0', 'Position', pos(740, Y_CFIL));
ln('Gain_inv_Cf_d/1', 'Int_VCd/1');
goto_block('Goto_VCd', 'V_C_d', pos(860, Y_CFIL));
ln('Int_VCd/1', 'Goto_VCd/1');

% ---- q axis ----
from_block('From_iLq_C',    'i_L_q',    pos(140, Y_CFIL+100));
from_block('From_iloadq_C', 'i_load_q', pos(140, Y_CFIL+125));
from_block('From_VCd_self_q','V_C_d',   pos(140, Y_CFIL+150));
from_block('From_omega_Cq', 'omega',    pos(140, Y_CFIL+175));

add_block('simulink/Math Operations/Product', [model '/Prod_wVCd'], ...
    'Position', pos(260, Y_CFIL+165));
ln('From_omega_Cq/1',  'Prod_wVCd/1');
ln('From_VCd_self_q/1','Prod_wVCd/2');
add_block('simulink/Math Operations/Gain', [model '/Gain_Cf_wVCd'], ...
    'Gain', num2str(C_f), 'Position', pos(380, Y_CFIL+165));
ln('Prod_wVCd/1', 'Gain_Cf_wVCd/1');

add_block('simulink/Math Operations/Sum', [model '/Sum_dVCq'], ...
    'Inputs', '+--', 'Position', pos(500, Y_CFIL+130));
ln('From_iLq_C/1',    'Sum_dVCq/1');
ln('From_iloadq_C/1', 'Sum_dVCq/2');
ln('Gain_Cf_wVCd/1',  'Sum_dVCq/3');

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_Cf_q'], ...
    'Gain', num2str(1/C_f), 'Position', pos(620, Y_CFIL+130));
ln('Sum_dVCq/1', 'Gain_inv_Cf_q/1');

add_block('simulink/Continuous/Integrator', [model '/Int_VCq'], ...
    'InitialCondition', '0', 'Position', pos(740, Y_CFIL+130));
ln('Gain_inv_Cf_q/1', 'Int_VCq/1');
goto_block('Goto_VCq', 'V_C_q', pos(860, Y_CFIL+130));
ln('Int_VCq/1', 'Goto_VCq/1');

%% =========================================================================
%  8) RL LOAD DYNAMICS  (states: i_load_d, i_load_q)
%% =========================================================================
% L_load * di_load_d/dt = V_C_d - R_load*i_load_d + omega*L_load*i_load_q
% L_load * di_load_q/dt = V_C_q - R_load*i_load_q - omega*L_load*i_load_d

% ---- d axis ----
from_block('From_VCd_load',     'V_C_d',    pos(980, Y_LOAD-40));
from_block('From_iloadq_self_d','i_load_q', pos(980, Y_LOAD));
from_block('From_omega_loadd',  'omega',    pos(980, Y_LOAD+30));
from_block('From_iloadd_self',  'i_load_d', pos(980, Y_LOAD+60));

add_block('simulink/Math Operations/Product', [model '/Prod_w_iloadq'], ...
    'Position', pos(1100, Y_LOAD+15));
ln('From_omega_loadd/1',    'Prod_w_iloadq/1');
ln('From_iloadq_self_d/1',  'Prod_w_iloadq/2');
add_block('simulink/Math Operations/Gain', [model '/Gain_Lload_wiloadq'], ...
    'Gain', num2str(L_load), 'Position', pos(1220, Y_LOAD+15));
ln('Prod_w_iloadq/1', 'Gain_Lload_wiloadq/1');

add_block('simulink/Math Operations/Gain', [model '/Gain_Rload_d'], ...
    'Gain', num2str(R_load), 'Position', pos(1100, Y_LOAD+60));
ln('From_iloadd_self/1', 'Gain_Rload_d/1');

add_block('simulink/Math Operations/Sum', [model '/Sum_diloadd'], ...
    'Inputs', '+-+', 'Position', pos(1340, Y_LOAD));
ln('From_VCd_load/1',       'Sum_diloadd/1');
ln('Gain_Rload_d/1',        'Sum_diloadd/2');
ln('Gain_Lload_wiloadq/1',  'Sum_diloadd/3');

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_Lload_d'], ...
    'Gain', num2str(1/L_load), 'Position', pos(1440, Y_LOAD));
ln('Sum_diloadd/1', 'Gain_inv_Lload_d/1');

add_block('simulink/Continuous/Integrator', [model '/Int_iloadd'], ...
    'InitialCondition', '0', 'Position', pos(1540, Y_LOAD));
% Note: layout pushes past x=1500 — Simulink autoresizes
ln('Gain_inv_Lload_d/1', 'Int_iloadd/1');
goto_block('Goto_iloadd', 'i_load_d', pos(1640, Y_LOAD));
ln('Int_iloadd/1', 'Goto_iloadd/1');

% ---- q axis ----
from_block('From_VCq_load',     'V_C_q',    pos(980, Y_LOAD+110));
from_block('From_iloadd_self_q','i_load_d', pos(980, Y_LOAD+140));
from_block('From_omega_loadq',  'omega',    pos(980, Y_LOAD+170));
from_block('From_iloadq_self',  'i_load_q', pos(980, Y_LOAD+200));

add_block('simulink/Math Operations/Product', [model '/Prod_w_iloadd'], ...
    'Position', pos(1100, Y_LOAD+155));
ln('From_omega_loadq/1',    'Prod_w_iloadd/1');
ln('From_iloadd_self_q/1',  'Prod_w_iloadd/2');
add_block('simulink/Math Operations/Gain', [model '/Gain_Lload_wiloadd'], ...
    'Gain', num2str(L_load), 'Position', pos(1220, Y_LOAD+155));
ln('Prod_w_iloadd/1', 'Gain_Lload_wiloadd/1');

add_block('simulink/Math Operations/Gain', [model '/Gain_Rload_q'], ...
    'Gain', num2str(R_load), 'Position', pos(1100, Y_LOAD+200));
ln('From_iloadq_self/1', 'Gain_Rload_q/1');

add_block('simulink/Math Operations/Sum', [model '/Sum_diloadq'], ...
    'Inputs', '+--', 'Position', pos(1340, Y_LOAD+160));
ln('From_VCq_load/1',       'Sum_diloadq/1');
ln('Gain_Rload_q/1',        'Sum_diloadq/2');
ln('Gain_Lload_wiloadd/1',  'Sum_diloadq/3');

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_Lload_q'], ...
    'Gain', num2str(1/L_load), 'Position', pos(1440, Y_LOAD+160));
ln('Sum_diloadq/1', 'Gain_inv_Lload_q/1');

add_block('simulink/Continuous/Integrator', [model '/Int_iloadq'], ...
    'InitialCondition', '0', 'Position', pos(1540, Y_LOAD+160));
ln('Gain_inv_Lload_q/1', 'Int_iloadq/1');
goto_block('Goto_iloadq', 'i_load_q', pos(1640, Y_LOAD+160));
ln('Int_iloadq/1', 'Goto_iloadq/1');

%% =========================================================================
%  9) POWER CALCULATION  (at the INVERTER OUTPUT, not at the load)
%% =========================================================================
% Measure power at the V_C node using the inductor current i_L (= total
% current flowing out of the VSG). This is the correct feedback signal
% for the swing equation, because the VSG must control the power IT
% produces — not the subset of that power that happens to land on the
% load (the rest may go to other parallel loads or, in our case, to the
% disturbance sink).
%
%   P_meas =  V_C_d * i_L_d  +  V_C_q * i_L_q
%   Q_meas =  V_C_q * i_L_d  -  V_C_d * i_L_q

from_block('From_VCd_p', 'V_C_d', pos(140, Y_PWR));
from_block('From_VCq_p', 'V_C_q', pos(140, Y_PWR+25));
from_block('From_iLd_p', 'i_L_d', pos(140, Y_PWR+50));
from_block('From_iLq_p', 'i_L_q', pos(140, Y_PWR+75));

add_block('simulink/Math Operations/Product', [model '/Prod_Vd_id'], ...
    'Position', pos(260, Y_PWR+10));
ln('From_VCd_p/1', 'Prod_Vd_id/1');
ln('From_iLd_p/1', 'Prod_Vd_id/2');

add_block('simulink/Math Operations/Product', [model '/Prod_Vq_iq'], ...
    'Position', pos(260, Y_PWR+60));
ln('From_VCq_p/1', 'Prod_Vq_iq/1');
ln('From_iLq_p/1', 'Prod_Vq_iq/2');

add_block('simulink/Math Operations/Sum', [model '/Sum_P'], ...
    'Inputs', '++', 'Position', pos(380, Y_PWR+35));
ln('Prod_Vd_id/1', 'Sum_P/1');
ln('Prod_Vq_iq/1', 'Sum_P/2');
goto_block('Goto_P', 'P_meas', pos(500, Y_PWR+35));
ln('Sum_P/1', 'Goto_P/1');

add_block('simulink/Math Operations/Product', [model '/Prod_Vq_id'], ...
    'Position', pos(260, Y_PWR+120));
ln('From_VCq_p/1', 'Prod_Vq_id/1');
ln('From_iLd_p/1', 'Prod_Vq_id/2');

add_block('simulink/Math Operations/Product', [model '/Prod_Vd_iq'], ...
    'Position', pos(260, Y_PWR+170));
ln('From_VCd_p/1', 'Prod_Vd_iq/1');
ln('From_iLq_p/1', 'Prod_Vd_iq/2');

add_block('simulink/Math Operations/Sum', [model '/Sum_Q'], ...
    'Inputs', '+-', 'Position', pos(380, Y_PWR+145));
ln('Prod_Vq_id/1', 'Sum_Q/1');
ln('Prod_Vd_iq/1', 'Sum_Q/2');
goto_block('Goto_Q', 'Q_meas', pos(500, Y_PWR+145));
ln('Sum_Q/1', 'Goto_Q/1');

%% =========================================================================
%  10) LOGGING (To Workspace)
%% =========================================================================

mk_tows = @(name, var, y) (add_block('simulink/Sinks/To Workspace', ...
    [model '/' name], 'VariableName', var, 'SaveFormat', 'Timeseries', ...
    'Position', pos(620, y)));

from_block('FL_omega',  'omega',    pos(560, Y_PWR+200)); mk_tows('TWS_omega',  'omega_ts',   Y_PWR+200);
ln('FL_omega/1',  'TWS_omega/1');
from_block('FL_delta',  'delta',    pos(560, Y_PWR+225)); mk_tows('TWS_delta',  'delta_ts',   Y_PWR+225);
ln('FL_delta/1',  'TWS_delta/1');
from_block('FL_Vdref',  'V_d_ref',  pos(560, Y_PWR+250)); mk_tows('TWS_Vdref',  'Vd_ref_ts',  Y_PWR+250);
ln('FL_Vdref/1',  'TWS_Vdref/1');
from_block('FL_VCd',    'V_C_d',    pos(560, Y_PWR+275)); mk_tows('TWS_VCd',    'VCd_ts',     Y_PWR+275);
ln('FL_VCd/1',    'TWS_VCd/1');
from_block('FL_VCq',    'V_C_q',    pos(560, Y_PWR+300)); mk_tows('TWS_VCq',    'VCq_ts',     Y_PWR+300);
ln('FL_VCq/1',    'TWS_VCq/1');
from_block('FL_iLd',    'i_L_d',    pos(560, Y_PWR+325)); mk_tows('TWS_iLd',    'iLd_ts',     Y_PWR+325);
ln('FL_iLd/1',    'TWS_iLd/1');
from_block('FL_iLq',    'i_L_q',    pos(560, Y_PWR+350)); mk_tows('TWS_iLq',    'iLq_ts',     Y_PWR+350);
ln('FL_iLq/1',    'TWS_iLq/1');
from_block('FL_iloadd', 'i_load_d', pos(560, Y_PWR+375)); mk_tows('TWS_iloadd', 'iloadd_ts',  Y_PWR+375);
ln('FL_iloadd/1', 'TWS_iloadd/1');
from_block('FL_iloadq', 'i_load_q', pos(560, Y_PWR+400)); mk_tows('TWS_iloadq', 'iloadq_ts',  Y_PWR+400);
ln('FL_iloadq/1', 'TWS_iloadq/1');
from_block('FL_P',      'P_meas',   pos(560, Y_PWR+425)); mk_tows('TWS_P',      'P_ts',       Y_PWR+425);
ln('FL_P/1',      'TWS_P/1');
from_block('FL_Q',      'Q_meas',   pos(560, Y_PWR+450)); mk_tows('TWS_Q',      'Q_ts',       Y_PWR+450);
ln('FL_Q/1',      'TWS_Q/1');

%% =========================================================================
%  11) SOLVER + RUN
%% =========================================================================

set_param(model, ...
    'Solver',   'ode23tb', ...                  % stiff solver — fast LC filter
    'StopTime', num2str(T_sim), ...
    'MaxStep',  '5e-5', ...                     % 50 us — captures 1.5 kHz res
    'RelTol',   '1e-4', 'AbsTol', '1e-6');

save_system(model, model_path);
fprintf('[Stage 4] Model saved : %s\n', model_path);

fprintf('[Stage 4] Simulating (T_sim = %g s, this may take 1-2 minutes) ...\n', T_sim);
sim(model);

% Pull each timeseries via a named handle first (R2018b cannot chain
% .Data onto evalin() directly — that syntax requires R2019b or later).
omega_ts_h  = evalin('base', 'omega_ts');
delta_ts_h  = evalin('base', 'delta_ts');
Vdref_ts_h  = evalin('base', 'Vd_ref_ts');
VCd_ts_h    = evalin('base', 'VCd_ts');
VCq_ts_h    = evalin('base', 'VCq_ts');
iLd_ts_h    = evalin('base', 'iLd_ts');
iLq_ts_h    = evalin('base', 'iLq_ts');
iloadd_ts_h = evalin('base', 'iloadd_ts');
iloadq_ts_h = evalin('base', 'iloadq_ts');
P_ts_h      = evalin('base', 'P_ts');
Q_ts_h      = evalin('base', 'Q_ts');

t        = omega_ts_h.Time;
omega    = omega_ts_h.Data;
delta    = delta_ts_h.Data;
Vd_ref   = Vdref_ts_h.Data;
VCd      = VCd_ts_h.Data;
VCq      = VCq_ts_h.Data;
iLd      = iLd_ts_h.Data;
iLq      = iLq_ts_h.Data;
iloadd   = iloadd_ts_h.Data;
iloadq   = iloadq_ts_h.Data;
P_meas   = P_ts_h.Data;
Q_meas   = Q_ts_h.Data;
freq     = omega / (2*pi);

%% --- SAVE .MAT ----------------------------------------------------------

out_path = fullfile(script_dir, 'vsg_stage4_out.mat');
save(out_path, ...
     't', 'omega', 'delta', 'freq', 'Vd_ref', ...
     'VCd', 'VCq', 'iLd', 'iLq', 'iloadd', 'iloadq', ...
     'P_meas', 'Q_meas', ...
     'V_dc','V_set','P_base','Q_base','f_base','omega_s', ...
     'H','D','R_p','R_q','L_f','C_f','R_f','R_load','L_load', ...
     'Kp_V','Ki_V','Kp_I','Ki_I', ...
     'I_disturb_t','I_disturb_d', ...
     'P_ss0','Q_ss0','df_ss_pred','f_ss_pred','f_res','T_sim', ...
     '-v7');

fprintf('[Stage 4] Data saved  : %s\n', out_path);
fprintf('  Filter resonance     : %.0f Hz\n', f_res);
fprintf('  Analytical SS (pre-disturb)  : P = %.2f W, Q = %.2f VAR\n', P_ss0, Q_ss0);
fprintf('  Analytical Df_ss (post-step) : %+.4f Hz   ->  f_ss = %.4f Hz\n', df_ss_pred, f_ss_pred);
fprintf('  Simulated final              : V_d = %.3f V, V_q = %+.3f V\n', VCd(end), VCq(end));
fprintf('                                  P   = %.2f W, Q   = %.2f VAR\n', P_meas(end), Q_meas(end));
fprintf('                                  f   = %.4f Hz, Df  = %+.4f Hz\n', freq(end), freq(end)-f_base);

%% --- QUICK PLOT ---------------------------------------------------------

figure('Name', 'VSG Stage 4 - dq Average-Model VSG', 'Color', 'w', ...
       'Position', [100 100 1100 800], 'NumberTitle', 'off');

subplot(4,2,1);
plot(t, freq, 'b', 'LineWidth', 1.5); hold on;
plot([t(1) t(end)], [f_base   f_base  ], 'r--');
plot([t(1) t(end)], [f_ss_pred f_ss_pred], 'g--');
plot([I_disturb_t I_disturb_t], ylim, 'k:');
ylabel('f (Hz)'); grid on; title('Frequency (P-f droop)');

subplot(4,2,2);
plot(t, VCd, 'b', 'LineWidth', 1.5); hold on;
plot(t, Vd_ref, 'r--', 'LineWidth', 1.0);
plot(t, VCq, 'm', 'LineWidth', 1.0);
plot([I_disturb_t I_disturb_t], ylim, 'k:');
ylabel('V (V)'); grid on; title('Capacitor voltage (V_d, V_q) and V_{d,ref}');
legend({'V_{C,d}','V_{d,ref}','V_{C,q}'}, 'Location','best', 'FontSize',8);

subplot(4,2,3);
plot(t, P_meas, 'Color',[0.1 0.5 0.1], 'LineWidth', 1.5); hold on;
plot([I_disturb_t I_disturb_t], ylim, 'k:');
ylabel('P (W)'); grid on; title('Active power measured at load');

subplot(4,2,4);
plot(t, Q_meas, 'Color',[0.6 0.1 0.6], 'LineWidth', 1.5); hold on;
plot([I_disturb_t I_disturb_t], ylim, 'k:');
ylabel('Q (VAR)'); grid on; title('Reactive power measured at load');

subplot(4,2,5);
plot(t, iLd, 'b', 'LineWidth', 1.2); hold on;
plot(t, iLq, 'm', 'LineWidth', 1.2);
plot([I_disturb_t I_disturb_t], ylim, 'k:');
ylabel('i_L (A)'); grid on; title('Filter inductor currents');
legend({'i_{L,d}','i_{L,q}'}, 'Location','best', 'FontSize',8);

subplot(4,2,6);
plot(t, iloadd, 'b', 'LineWidth', 1.2); hold on;
plot(t, iloadq, 'm', 'LineWidth', 1.2);
plot([I_disturb_t I_disturb_t], ylim, 'k:');
ylabel('i_{load} (A)'); grid on; title('Load currents');
legend({'i_{load,d}','i_{load,q}'}, 'Location','best', 'FontSize',8);

subplot(4,2,7);
P_axis = linspace(0, 150, 200);
f_line = f_base - R_p * (P_axis/P_base - P_set_pu) * f_base;
plot(P_axis, f_line, 'k-', 'LineWidth', 1.2); hold on;
plot(P_meas(end), freq(end), 'r*', 'MarkerSize', 14, 'LineWidth', 2);
plot(P_ss0, f_base, 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
xlabel('P (W)'); ylabel('f (Hz)'); grid on; title('Droop characteristic + operating point');
legend({'5%% droop','final OP (sim)','initial OP'}, 'Location','best','FontSize',8);

subplot(4,2,8);
plot(t, omega/(2*pi)*360 * 1e-3, 'b','LineWidth',1.2); hold on;   % freq in mHz-like
ylabel('\omega/2\pi (Hz)'); xlabel('Time (s)'); grid on; title('Angular speed \omega');

fprintf('[Stage 4] Done.\n');
