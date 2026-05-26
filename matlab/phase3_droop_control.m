% phase3_droop_control.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 3 — Islanded VSG with P-f Droop (Governor Mimic)
% =========================================================================
%
%  Stage 1 :  pure swing equation (no restoring force, omega drifts)
%  Stage 2 :  + power-angle feedback (grid-connected, SG-like swing)
%  Stage 3 :  ISLANDED operation + P-f DROOP for primary frequency
%             response. This is the control loop a grid-forming VSG
%             actually runs — and the loop we will port to the ESP32.
%
%  Removed vs Stage 2:
%    - Pe = Pmax * sin(delta).  Stage 3 is ISLANDED — no infinite bus
%      to synchronise against. Pe is replaced by the load demand P_load.
%
%  Added in Stage 3:
%    - Active-power setpoint  P_set
%    - Load disturbance       P_load (step)
%    - P-f droop controller:
%
%         Pm  =  P_set  +  (1/(R_p*omega_s)) * (omega_s - omega)
%             =  P_set  +  (1/R_p) * Delta_f_pu
%
%  Steady-state analysis (with D = 0):
%      Energy balance :  Pm = P_load
%      Substituting   :  P_set + (1/(R_p*omega_s))*(omega_s - omega_ss) = P_load
%                        Delta_omega_ss = R_p*omega_s*(P_set - P_load)
%                        Delta_f_ss     = R_p*(P_set - P_load)*f_base
%
%  Defaults  R_p = 0.05,  Delta_P_load = +0.10 pu,  f_base = 50 Hz :
%      Delta_f_ss = -0.05 * 0.10 * 50 = -0.25 Hz   ->   f_ss = 49.75 Hz
%      Pm_ss      = P_set + 0.10 = 1.10 pu (matches P_load)
%
%  Dynamic response : first-order (no restoring spring in islanded mode):
%      tau = (2H/omega_s) / (1/(R_p*omega_s) + D)
%      For D = 0 : tau = 0.0318/0.0637 = 0.500 s
%      63 % settling at t = 1 + 0.5 = 1.5 s
%
%  System base : V_dc = 24 V, S_base = 100 VA, f_base = 50 Hz
%
%  Outputs (next to this script):
%      vsg_stage3.slx
%      vsg_stage3_out.mat
%
%  Tested on MATLAB R2018b. Base Simulink only.
%
%  Author  : Napoleon (Chinnawat Dumklang) - SUT EE
%  Stage 3 : 2026-05-26
% =========================================================================

%% --- PARAMETERS ---------------------------------------------------------

H              = 5;              % virtual inertia (s)
D              = 0;              % set to 0 in Stage 3 so the droop
                                 % response satisfies the textbook
                                 % Delta_f = -R_p * Delta_P exactly.
                                 % Stage 4 reintroduces D as AC damping.
f_base         = 50;             % Hz
omega_s        = 2*pi*f_base;    % rad/s

R_p            = 0.05;           % droop coefficient (pu/pu) - IEEE 5 %
K_droop        = 1/(R_p*omega_s);% gain on (omega_s - omega) [rad/s] -> pu

P_set          = 1.00;           % active-power setpoint (pu)
P_load_init    = 1.00;           % load before step (pu)
P_load_step    = 0.10;           % load step magnitude (pu)
P_load_t       = 1.0;            % step time (s)

T_sim          = 6;              % s

inertia_coeff  = 2*H/omega_s;    % s^2/rad

% --- Analytical predictions (printed at end) -----------------------------
df_ss          = R_p * (P_set - (P_load_init + P_load_step)) * f_base;  % Hz
f_ss_pred      = f_base + df_ss;
tau_pred       = inertia_coeff / (K_droop + D);                          % s
Pm_ss_pred     = P_set + K_droop * (-omega_s * df_ss / f_base);          % pu

%% --- SAFE MODEL INIT ----------------------------------------------------

model      = 'vsg_stage3';
script_dir = fileparts(mfilename('fullpath'));
if bdIsLoaded(model)
    close_system(model, 0);
end
evalin('base', 'clear omega_ts delta_ts Pm_ts');

new_system(model);
open_system(model);
set_param(model, 'Location', [80 80 1480 700]);

%% --- LAYOUT HELPERS -----------------------------------------------------

BW = 60;  BH = 25;
pos = @(x, y) [x-BW, y-BH, x+BW, y+BH];

% Columns (left -> right signal flow)
C1 =   80;   % sources
C2 =  280;   % Sum_Pm  (Pm formation)
C3 =  460;   % Sum_PmPe
C4 =  620;   % Sum_swing
C5 =  780;   % Gain_inv_2Hws  /  Gain_droop  /  Gain_D
C6 =  940;   % Int_omega
C7 = 1100;   % Sum_dev
C8 = 1280;   % Scope

% Rows
R_top    = 120;   % droop feedback (above main row)
R_main   = 280;   % main signal flow
R_bot    = 460;   % damping branch + delta observer
R_sources= 380;   % source-stack column (P_load + delta integrator)

%% --- SOURCE BLOCKS ------------------------------------------------------

add_block('simulink/Sources/Constant', [model '/P_set'], ...
    'Value',    num2str(P_set), ...
    'Position', pos(C1, R_main-50));

add_block('simulink/Sources/Constant', [model '/omega_s'], ...
    'Value',    num2str(omega_s), ...
    'Position', pos(C1, R_main+80));

add_block('simulink/Sources/Step', [model '/P_load'], ...
    'Time',     num2str(P_load_t), ...
    'Before',   num2str(P_load_init), ...
    'After',    num2str(P_load_init + P_load_step), ...
    'Position', pos(C1, R_sources+80));

%% --- MAIN SIGNAL FLOW ---------------------------------------------------

% Sum_Pm : Pm = P_set + P_droop
add_block('simulink/Math Operations/Sum', [model '/Sum_Pm'], ...
    'Inputs',  '++', ...
    'Position', pos(C2, R_main-50));

% Sum_PmPe : Pm - P_load
add_block('simulink/Math Operations/Sum', [model '/Sum_PmPe'], ...
    'Inputs',  '+-', ...
    'Position', pos(C3, R_main));

% Sum_swing : (Pm - P_load) - D*Domega
add_block('simulink/Math Operations/Sum', [model '/Sum_swing'], ...
    'Inputs',  '+-', ...
    'Position', pos(C4, R_main));

% Gain_inv_2Hws
add_block('simulink/Math Operations/Gain', [model '/Gain_inv_2Hws'], ...
    'Gain',    num2str(1/inertia_coeff), ...
    'Position', pos(C5, R_main));

% Int_omega
add_block('simulink/Continuous/Integrator', [model '/Int_omega'], ...
    'InitialCondition', num2str(omega_s), ...
    'Position', pos(C6, R_main));

% Sum_dev : omega - omega_s
add_block('simulink/Math Operations/Sum', [model '/Sum_dev'], ...
    'Inputs',  '+-', ...
    'Position', pos(C7, R_main));

%% --- DROOP FEEDBACK (above main row) ------------------------------------
%
%  Sum_dev output = omega - omega_s.
%  Gain_droop with gain = -K_droop  ->  output = -K_droop*(omega - omega_s)
%                                              =  K_droop*(omega_s - omega)
%  = (1/(R_p*omega_s))*(omega_s - omega) = droop correction in pu.

add_block('simulink/Math Operations/Gain', [model '/Gain_droop'], ...
    'Gain',    num2str(-K_droop), ...
    'Position', pos(C5, R_top));

%% --- DAMPING FEEDBACK (below main row) ----------------------------------

add_block('simulink/Math Operations/Gain', [model '/Gain_D'], ...
    'Gain',    num2str(D), ...
    'Position', pos(C5, R_bot));

%% --- DELTA INTEGRATOR (passive observer) --------------------------------
%
%  In islanded mode delta drifts linearly when omega ~= omega_s, because
%  no external reference locks it. We still integrate it for thesis
%  observability — it represents the VSG's phase output that will drive
%  the inverter in Stage 4.

add_block('simulink/Continuous/Integrator', [model '/Int_delta'], ...
    'InitialCondition', '0', ...
    'Position', pos(C7, R_bot+80));

%% --- SCOPES & TO-WORKSPACE ----------------------------------------------

add_block('simulink/Sinks/Scope', [model '/Scope_omega_Pm_delta'], ...
    'NumInputPorts', '3', ...
    'Position', pos(C8, R_main));

add_block('simulink/Sinks/To Workspace', [model '/ToWS_omega'], ...
    'VariableName', 'omega_ts', 'SaveFormat', 'Timeseries', ...
    'Position', pos(C6, R_main+170));

add_block('simulink/Sinks/To Workspace', [model '/ToWS_Pm'], ...
    'VariableName', 'Pm_ts', 'SaveFormat', 'Timeseries', ...
    'Position', pos(C2, R_main+170));

add_block('simulink/Sinks/To Workspace', [model '/ToWS_delta'], ...
    'VariableName', 'delta_ts', 'SaveFormat', 'Timeseries', ...
    'Position', pos(C7, R_bot+200));

%% --- CONNECTIONS --------------------------------------------------------
%
%  Topology:
%
%        P_set ─┐
%               ├─► Sum_Pm ─► Sum_PmPe ─► Sum_swing ─► Gain_inv_2Hws ─► Int_omega ─┬─► Sum_dev ─┬─► Gain_droop ─► (back to Sum_Pm +)
%   droop fb ─┐│                ▲              ▲                                   │           ├─► Gain_D     ─► (back to Sum_swing -)
%             ▼│                │              │                                   │           └─► Int_delta  (observer)
%      Gain_droop        P_load (−)     Gain_D (−)
%                                                          omega_s ──► Sum_dev (−)

ln = @(s, d) add_line(model, s, d, 'autorouting', 'on');

% Pm formation
ln('P_set/1',         'Sum_Pm/1');
ln('Gain_droop/1',    'Sum_Pm/2');           % droop correction
ln('Sum_Pm/1',        'Sum_PmPe/1');

% Load disturbance
ln('P_load/1',        'Sum_PmPe/2');

% Swing equation
ln('Sum_PmPe/1',      'Sum_swing/1');
ln('Sum_swing/1',     'Gain_inv_2Hws/1');
ln('Gain_inv_2Hws/1', 'Int_omega/1');
ln('Int_omega/1',     'Sum_dev/1');
ln('omega_s/1',       'Sum_dev/2');

% Damping feedback
ln('Sum_dev/1',       'Gain_D/1');
ln('Gain_D/1',        'Sum_swing/2');

% Droop feedback (the key new path)
ln('Sum_dev/1',       'Gain_droop/1');

% Delta observer
ln('Sum_dev/1',       'Int_delta/1');

% Logging
ln('Int_omega/1',     'Scope_omega_Pm_delta/1');
ln('Sum_Pm/1',        'Scope_omega_Pm_delta/2');
ln('Int_delta/1',     'Scope_omega_Pm_delta/3');
ln('Int_omega/1',     'ToWS_omega/1');
ln('Sum_Pm/1',        'ToWS_Pm/1');
ln('Int_delta/1',     'ToWS_delta/1');

%% --- SOLVER -------------------------------------------------------------

set_param(model, ...
    'Solver',   'ode45', ...
    'StopTime', num2str(T_sim), ...
    'MaxStep',  '1e-3', ...
    'RelTol',   '1e-6', 'AbsTol', '1e-8');

%% --- SAVE & RUN ---------------------------------------------------------

model_path = fullfile(script_dir, [model '.slx']);
save_system(model, model_path);
fprintf('[Stage 3] Model saved : %s\n', model_path);

fprintf('[Stage 3] Simulating (T_sim = %g s) ...\n', T_sim);
sim(model);

omega_ts = evalin('base', 'omega_ts');
Pm_ts    = evalin('base', 'Pm_ts');
delta_ts = evalin('base', 'delta_ts');

t     = omega_ts.Time;
omega = omega_ts.Data;
Pm    = Pm_ts.Data;
delta = delta_ts.Data;
freq  = omega / (2*pi);

%% --- SAVE .MAT ----------------------------------------------------------

out_path = fullfile(script_dir, 'vsg_stage3_out.mat');
save(out_path, ...
     't', 'omega', 'delta', 'freq', 'Pm', ...
     'H', 'D', 'omega_s', 'f_base', 'R_p', 'K_droop', ...
     'P_set', 'P_load_init', 'P_load_step', 'P_load_t', ...
     'df_ss', 'f_ss_pred', 'tau_pred', 'Pm_ss_pred', 'T_sim', ...
     '-v7');

fprintf('[Stage 3] Data saved  : %s\n', out_path);
fprintf('  Analytical : Df_ss     = %+8.4f Hz   f_ss     = %8.4f Hz\n', df_ss, f_ss_pred);
fprintf('               tau       =  %7.4f s    Pm_ss    = %8.4f pu\n', tau_pred, Pm_ss_pred);
fprintf('  Simulated  : f_final   = %8.4f Hz    Df_final = %+8.4f Hz\n', freq(end), freq(end)-f_base);
fprintf('               Pm_final  = %8.4f pu    delta_final = %7.2f deg\n', Pm(end), rad2deg(delta(end)));

%% --- QUICK PLOT ---------------------------------------------------------

figure('Name', 'VSG Stage 3 - Islanded Droop Response', 'Color', 'w', ...
       'NumberTitle', 'off');

subplot(3, 1, 1);
plot(t, freq, 'b', 'LineWidth', 1.6); hold on;
plot([t(1) t(end)], [f_base    f_base   ], 'r--');
plot([t(1) t(end)], [f_ss_pred f_ss_pred], 'g--');
plot([P_load_t P_load_t], ylim, 'k:');
ylabel('Frequency (Hz)'); grid on;
title(sprintf('Frequency response  [R_p = %g %%, H = %g s, \\tau \\approx %.2f s]', ...
              R_p*100, H, tau_pred));

subplot(3, 1, 2);
P_load_series = P_load_init + P_load_step * (t >= P_load_t);
plot(t, Pm,            'Color', [0.1 0.5 0.1], 'LineWidth', 1.6); hold on;
plot(t, P_load_series, 'Color', [0.7 0.1 0.1], 'LineWidth', 1.6, 'LineStyle', '--');
plot([P_load_t P_load_t], ylim, 'k:');
ylabel('Power (pu)'); grid on;
title('Power balance : droop output P_m catches up with load demand');
legend({'P_m(t) (droop output)', 'P_{load}(t)'}, 'Location', 'best', 'FontSize', 8);

subplot(3, 1, 3);
% Droop characteristic with operating-point shift
P_axis = linspace(0, 2, 100);
f_line = f_base - R_p * (P_axis - P_set) * f_base;
plot(P_axis, f_line, 'k-', 'LineWidth', 1.2); hold on;
plot(P_set,    f_base,    'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
plot(Pm(end),  freq(end), 'r*', 'MarkerSize', 14, 'LineWidth', 2);
xlabel('Active Power P (pu)'); ylabel('Frequency f (Hz)'); grid on;
title(sprintf('Droop characteristic (%g %% slope) and operating-point shift', R_p*100));
legend({'droop curve', 'initial OP (P_{set}, f_s)', 'final OP (sim)'}, ...
       'Location', 'best', 'FontSize', 8);
axis([0 2 47 53]);

fprintf('[Stage 3] Done.\n');
