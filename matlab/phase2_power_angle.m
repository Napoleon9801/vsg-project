% phase2_power_angle.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 2 — Swing Equation + Power-Angle Feedback
% =========================================================================
%
%  Stage 1 used a constant Pe — no restoring torque, so a step in Pm
%  just kept ω drifting away from ω_s. Stage 2 CLOSES THE LOOP by
%  replacing the constant Pe with the classical power-angle relation
%  of a synchronous machine connected through reactance X to an
%  infinite bus of voltage V:
%
%      Pe(δ) = (E · V / X) · sin(δ)   =   Pmax · sin(δ)
%
%  Linearising around equilibrium δ_eq:
%
%      (2H/ω_s)·δ̈ + D·δ̇ + Pmax·cos(δ_eq)·Δδ  =  ΔPm
%
%      → ω_n = sqrt( Pmax·cos(δ_eq) / (2H/ω_s) )      (rad/s)
%      → ζ   = D / ( 2·sqrt( (2H/ω_s)·Pmax·cos(δ_eq) ) )
%
%  Default values  H=5, D=0.3, X=0.5, E=1.05, V=1, Pm=1.0→1.10:
%
%      Pmax  = 2.10 pu
%      δ_eq  : 28.44° → 31.59°
%      ω_n  ≈ 7.62 rad/s   (f_d ≈ 1.21 Hz,  T_d ≈ 0.83 s)
%      ζ    ≈ 0.62          (visibly underdamped — ~3 oscillations
%                            before settling)
%
%  Note on D:  Stage 1 used D=10. Plugging that into the closed loop
%  gives ζ ≈ 4.1 — severely overdamped, no visible swing. We drop D to
%  0.3 here so the classical swing dynamic is pedagogically clear. Real
%  VSG damping for a 100 VA prototype falls in this range anyway; the
%  Stage-1 D=10 was a generic textbook value, not a design point.
%
%  System base (same as Stage 1):
%      V_dc_base = 24 V,  S_base = 100 VA,  f_base = 50 Hz
%
%  Outputs (written next to this script):
%      vsg_stage2.slx
%      vsg_stage2_out.mat
%
%  Tested on MATLAB R2018b. Base Simulink only.
%
%  Author : Napoleon (Chinnawat Dumklang) — SUT EE
%  Stage 2 : 2026-05-26
% =========================================================================

%% --- PARAMETERS ---------------------------------------------------------

H            = 5;             % virtual inertia (s)
D            = 0.3;           % damping (pu)  — see header for rationale
f_base       = 50;            % Hz
omega_s      = 2*pi*f_base;   % rad/s

E            = 1.05;          % internal EMF behind reactance (pu)
V            = 1.00;          % infinite-bus voltage (pu)
X_pu         = 0.50;          % coupling reactance (pu)
Pmax         = E * V / X_pu;  % static power-transfer limit (pu)

Pm_initial   = 1.00;          % pu
Pm_step      = 0.10;          % pu — +10 % step
Pm_step_time = 1.0;           % s
T_sim        = 5;             % s

inertia_coeff = 2*H/omega_s;  % s^2/rad

% Initial rotor angle = equilibrium for the initial operating point so
% the system starts in steady state at t=0 (otherwise Pe(0)=0 and ω runs
% away before the step even arrives).
delta_init   = asin(Pm_initial / Pmax);          % rad
delta_eq_new = asin((Pm_initial + Pm_step) / Pmax);

% Analytical small-signal predictions (printed at end for comparison)
K_lin    = Pmax * cos(delta_eq_new);
omega_n  = sqrt(K_lin / inertia_coeff);
zeta_lin = D / (2 * sqrt(inertia_coeff * K_lin));

%% --- SAFE MODEL INIT ----------------------------------------------------

model      = 'vsg_stage2';
script_dir = fileparts(mfilename('fullpath'));

if bdIsLoaded(model)
    close_system(model, 0);
end
evalin('base', 'clear omega_ts delta_ts');

new_system(model);
open_system(model);
set_param(model, 'Location', [80 80 1420 600]);

%% --- LAYOUT HELPERS -----------------------------------------------------

Y  = 240;
BW = 60;  BH = 25;
pos = @(x, y) [x-BW, y-BH, x+BW, y+BH];

CX.Pm    =   80;
CX.OmS   =   80;
CX.Sum1  =  280;        % Pm − Pe
CX.Sum2  =  460;        % − D·Δω
CX.Gain  =  620;        % × 1/(2H/ωs)
CX.IntW  =  780;
CX.SumD  =  940;
CX.GainD = 1100;        % D damping (feedback path, above main row)
CX.IntDe = 1100;        % integrate Δω → δ
CX.Sin   = 1100;        % sin(δ) — power-angle feedback
CX.GMax  = 1240;        % Pmax · sin(δ)  → Pe
CX.Scope = 1360;

%% --- ADD BLOCKS ---------------------------------------------------------

add_block('simulink/Sources/Step', [model '/Pm'], ...
    'Time',     num2str(Pm_step_time), ...
    'Before',   num2str(Pm_initial), ...
    'After',    num2str(Pm_initial + Pm_step), ...
    'Position', pos(CX.Pm, Y-100));

add_block('simulink/Sources/Constant', [model '/omega_s'], ...
    'Value',    num2str(omega_s), ...
    'Position', pos(CX.OmS, Y+100));

add_block('simulink/Math Operations/Sum', [model '/Sum_PmPe'], ...
    'Inputs',  '+-', ...
    'Position', pos(CX.Sum1, Y-50));

add_block('simulink/Math Operations/Sum', [model '/Sum_swing'], ...
    'Inputs',  '+-', ...
    'Position', pos(CX.Sum2, Y-50));

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_2Hws'], ...
    'Gain',    num2str(1/inertia_coeff), ...
    'Position', pos(CX.Gain, Y-50));

add_block('simulink/Continuous/Integrator', [model '/Int_omega'], ...
    'InitialCondition', num2str(omega_s), ...
    'Position', pos(CX.IntW, Y-50));

add_block('simulink/Math Operations/Sum', [model '/Sum_dev'], ...
    'Inputs',  '+-', ...
    'Position', pos(CX.SumD, Y-50));

add_block('simulink/Math Operations/Gain', [model '/Gain_D'], ...
    'Gain',    num2str(D), ...
    'Position', pos(CX.GainD, Y-150));

add_block('simulink/Continuous/Integrator', [model '/Int_delta'], ...
    'InitialCondition', num2str(delta_init), ...
    'Position', pos(CX.IntDe, Y+80));

% Power-angle feedback path: δ → sin(δ) → Pmax·sin(δ) = Pe
add_block('simulink/Math Operations/Trigonometric Function', ...
    [model '/Sin_delta'], ...
    'Operator', 'sin', ...
    'Position', pos(CX.Sin, Y+200));

add_block('simulink/Math Operations/Gain', [model '/Gain_Pmax'], ...
    'Gain',    num2str(Pmax), ...
    'Position', pos(CX.GMax, Y+200));

add_block('simulink/Sinks/Scope', [model '/Scope_omega_delta'], ...
    'NumInputPorts', '2', ...
    'Position',      pos(CX.Scope, Y));

add_block('simulink/Sinks/To Workspace', [model '/ToWS_omega'], ...
    'VariableName', 'omega_ts', ...
    'SaveFormat',   'Timeseries', ...
    'Position',     pos(CX.IntW, Y+170));

add_block('simulink/Sinks/To Workspace', [model '/ToWS_delta'], ...
    'VariableName', 'delta_ts', ...
    'SaveFormat',   'Timeseries', ...
    'Position',     pos(CX.IntDe, Y+280));

%% --- CONNECT BLOCKS -----------------------------------------------------
%
%  Signal flow (★ = new feedback path closing the loop vs Stage 1):
%
%    Pm ─────────────► Sum_PmPe ─► Sum_swing ─► Gain_inv_2Hws ─► Int_omega ─┬─► Sum_dev ─┬─► Gain_D ─► (back to Sum_swing −)
%                          ▲                                                │           │
%                          │                                                │           └─► Int_delta ─► Scope ch2
%    ★ Pe = Pmax·sin(δ) ◄──┘                                                └─► Scope ch1
%                          ▲
%    ★    Gain_Pmax ◄── Sin_delta ◄── Int_delta (δ)
%
%      omega_s ──► Sum_dev (−)

ln = @(src, dst) add_line(model, src, dst, 'autorouting', 'on');

ln('Pm/1',            'Sum_PmPe/1');
ln('Gain_Pmax/1',     'Sum_PmPe/2');     % ★ Pe feedback closes the loop
ln('Sum_PmPe/1',      'Sum_swing/1');
ln('Sum_swing/1',     'Gain_inv_2Hws/1');
ln('Gain_inv_2Hws/1', 'Int_omega/1');
ln('Int_omega/1',     'Sum_dev/1');
ln('omega_s/1',       'Sum_dev/2');
ln('Sum_dev/1',       'Gain_D/1');
ln('Gain_D/1',        'Sum_swing/2');
ln('Sum_dev/1',       'Int_delta/1');
ln('Int_delta/1',     'Sin_delta/1');    % ★ δ → sin(δ)
ln('Sin_delta/1',     'Gain_Pmax/1');    % ★ sin(δ) → Pmax·sin(δ) = Pe
ln('Int_omega/1',     'Scope_omega_delta/1');
ln('Int_delta/1',     'Scope_omega_delta/2');
ln('Int_omega/1',     'ToWS_omega/1');
ln('Int_delta/1',     'ToWS_delta/1');

%% --- SOLVER CONFIG ------------------------------------------------------

set_param(model, ...
    'Solver',   'ode45', ...
    'StopTime', num2str(T_sim), ...
    'MaxStep',  '1e-3', ...
    'RelTol',   '1e-6', ...
    'AbsTol',   '1e-8');

%% --- SAVE & RUN ---------------------------------------------------------

model_path = fullfile(script_dir, [model '.slx']);
save_system(model, model_path);
fprintf('[Stage 2] Model saved : %s\n', model_path);

fprintf('[Stage 2] Simulating (T_sim = %g s) ...\n', T_sim);
sim(model);

omega_ts = evalin('base', 'omega_ts');
delta_ts = evalin('base', 'delta_ts');

t     = omega_ts.Time;
omega = omega_ts.Data;
delta = delta_ts.Data;
freq  = omega / (2*pi);
Pe    = Pmax * sin(delta);

%% --- SAVE .MAT ----------------------------------------------------------

out_path = fullfile(script_dir, 'vsg_stage2_out.mat');
save(out_path, ...
     't', 'omega', 'delta', 'freq', 'Pe', ...
     'H', 'D', 'omega_s', 'f_base', 'E', 'V', 'X_pu', 'Pmax', ...
     'Pm_initial', 'Pm_step', 'Pm_step_time', ...
     'delta_init', 'delta_eq_new', 'omega_n', 'zeta_lin', 'T_sim', ...
     '-v7');

fprintf('[Stage 2] Data saved  : %s\n', out_path);
fprintf('  Analytical : del_eq_init = %6.3f deg,  del_eq_new = %6.3f deg\n', ...
        rad2deg(delta_init), rad2deg(delta_eq_new));
fprintf('               omega_n     = %6.3f rad/s, f_d ~ %5.3f Hz, zeta = %5.3f\n', ...
        omega_n, omega_n/(2*pi), zeta_lin);
fprintf('  Simulated  : del_peak   = %6.3f deg,  del_final = %6.3f deg\n', ...
        rad2deg(max(delta)), rad2deg(delta(end)));
fprintf('               f_peak     = %6.4f Hz,    f_final  = %6.4f Hz\n', ...
        max(freq), freq(end));

%% --- QUICK MATLAB PLOT --------------------------------------------------

figure('Name', 'VSG Stage 2 — Power-Angle Swing', 'Color', 'w', ...
       'NumberTitle', 'off');

subplot(3, 1, 1);
plot(t, freq, 'b', 'LineWidth', 1.6); hold on;
plot([t(1) t(end)], [f_base f_base], 'r--');
plot([Pm_step_time Pm_step_time], ylim, 'k:');
ylabel('f (Hz)'); grid on;
title(sprintf('Frequency  [H=%g s, D=%g, X=%g, Pmax=%.2f, \\zeta\\approx%.2f]', ...
              H, D, X_pu, Pmax, zeta_lin));

subplot(3, 1, 2);
plot(t, rad2deg(delta), 'm', 'LineWidth', 1.6); hold on;
plot([t(1) t(end)], [rad2deg(delta_init)   rad2deg(delta_init)],   'g--');
plot([t(1) t(end)], [rad2deg(delta_eq_new) rad2deg(delta_eq_new)], 'r--');
plot([Pm_step_time Pm_step_time], ylim, 'k:');
ylabel('\delta (deg)'); grid on;
title(sprintf('Rotor angle  (\\delta_{eq,init}=%.2f^\\circ \\rightarrow \\delta_{eq,new}=%.2f^\\circ)', ...
              rad2deg(delta_init), rad2deg(delta_eq_new)));

subplot(3, 1, 3);
plot(t, Pe, 'Color', [0.1 0.5 0.1], 'LineWidth', 1.6); hold on;
plot([t(1) t(end)], [Pm_initial Pm_initial], 'g--');
plot([t(1) t(end)], [Pm_initial+Pm_step Pm_initial+Pm_step], 'r--');
plot([Pm_step_time Pm_step_time], ylim, 'k:');
xlabel('Time (s)'); ylabel('P_e (pu)'); grid on;
title('Electrical power output  P_e = P_{max}\cdot sin(\delta)');

fprintf('[Stage 2] Done.\n');
