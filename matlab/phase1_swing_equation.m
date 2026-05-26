% phase1_swing_equation.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 1 — Pure Swing-Equation Test
% =========================================================================
%
%  Tests that integrating the synchronous-generator swing equation gives
%  the expected H/D response to a step in mechanical (reference) power.
%  No power-angle feedback, no inverter, no PWM — Stage 1 is the
%  foundation that every later stage layers on top of.
%
%      (2H / w_s) * dw/dt = Pm - Pe - D*(w - w_s)        ... swing eq.
%      ddelta/dt          = w - w_s                       ... angle eq.
%
%  System base (matches the physical-prototype plan):
%      V_dc_base = 24 V        DC bus rating of the lab prototype
%      S_base    = 100 VA      apparent-power rating
%      f_base    = 50 Hz       Thai grid frequency
%
%  Outputs (written next to this script):
%      vsg_stage1.slx          Simulink model (auto-built every run)
%      vsg_stage1_out.mat      t, omega, delta, freq for Python analysis
%
%  Tested on MATLAB R2018b + base Simulink (no Simscape required for Stage 1).
%  Run with F5.  Re-runs are safe — the script closes the previous model
%  copy first, so no stale block handles.
%
%  Author : Napoleon (Chinnawat Dumklang) — SUT EE
%  Rewrite: 2026-05-26
% =========================================================================

%% --- PARAMETERS ---------------------------------------------------------

H            = 5;             % virtual inertia constant (s)
D            = 10;             % damping coefficient (pu)
f_base       = 50;             % Hz
omega_s      = 2*pi*f_base;    % synchronous angular frequency (rad/s)

Pm_initial   = 1.0;            % pu — mechanical/ref power before step
Pm_step      = 0.10;           % pu — step magnitude (+10 %)
Pm_step_time = 1.0;            % s — when the step occurs
Pe           = 1.0;            % pu — electrical load (constant in Stage 1)

T_sim        = 10;             % s — simulation horizon

inertia_coeff = 2*H/omega_s;   % s^2/rad — multiplies dw/dt

%% --- SAFE MODEL INIT ----------------------------------------------------

model      = 'vsg_stage1';        % renamed from phase1_vsg to avoid shadowing
script_dir = fileparts(mfilename('fullpath'));

if bdIsLoaded(model)
    close_system(model, 0);
end

% Clear any stale base-workspace timeseries from a prior run so we can tell
% if the new sim actually wrote them.
evalin('base', 'clear omega_ts delta_ts');

new_system(model);
open_system(model);
set_param(model, 'Location', [80 80 1320 600]);

%% --- LAYOUT HELPERS -----------------------------------------------------

Y  = 240;                      % main signal-flow row (y centre)
BW = 60;  BH = 25;             % block half-width / half-height
pos = @(x, y) [x-BW, y-BH, x+BW, y+BH];

X.Pm    =   80;                % column x-centres, left-to-right
X.Pe    =   80;
X.OmS   =   80;
X.Sum1  =  280;
X.Sum2  =  460;
X.Gain  =  620;
X.IntW  =  780;
X.SumD  =  940;
X.GainD = 1100;
X.IntDe = 1100;
X.Scope = 1240;

%% --- ADD BLOCKS ---------------------------------------------------------

add_block('simulink/Sources/Step', [model '/Pm'], ...
    'Time',     num2str(Pm_step_time), ...
    'Before',   num2str(Pm_initial), ...
    'After',    num2str(Pm_initial + Pm_step), ...
    'Position', pos(X.Pm, Y-100));

add_block('simulink/Sources/Constant', [model '/Pe'], ...
    'Value',    num2str(Pe), ...
    'Position', pos(X.Pe, Y));

add_block('simulink/Sources/Constant', [model '/omega_s'], ...
    'Value',    num2str(omega_s), ...
    'Position', pos(X.OmS, Y+100));

add_block('simulink/Math Operations/Sum', [model '/Sum_PmPe'], ...
    'Inputs',  '+-', ...
    'Position', pos(X.Sum1, Y-50));

add_block('simulink/Math Operations/Sum', [model '/Sum_swing'], ...
    'Inputs',  '+-', ...
    'Position', pos(X.Sum2, Y-50));

add_block('simulink/Math Operations/Gain', [model '/Gain_inv_2Hws'], ...
    'Gain',    num2str(1/inertia_coeff), ...
    'Position', pos(X.Gain, Y-50));

add_block('simulink/Continuous/Integrator', [model '/Int_omega'], ...
    'InitialCondition', num2str(omega_s), ...
    'Position', pos(X.IntW, Y-50));

add_block('simulink/Math Operations/Sum', [model '/Sum_dev'], ...
    'Inputs',  '+-', ...
    'Position', pos(X.SumD, Y-50));

add_block('simulink/Math Operations/Gain', [model '/Gain_D'], ...
    'Gain',    num2str(D), ...
    'Position', pos(X.GainD, Y-150));

add_block('simulink/Continuous/Integrator', [model '/Int_delta'], ...
    'InitialCondition', '0', ...
    'Position', pos(X.IntDe, Y+80));

add_block('simulink/Sinks/Scope', [model '/Scope_omega_delta'], ...
    'NumInputPorts', '2', ...
    'Position',      pos(X.Scope, Y));

add_block('simulink/Sinks/To Workspace', [model '/ToWS_omega'], ...
    'VariableName', 'omega_ts', ...
    'SaveFormat',   'Timeseries', ...
    'Position',     pos(X.IntW, Y+170));

add_block('simulink/Sinks/To Workspace', [model '/ToWS_delta'], ...
    'VariableName', 'delta_ts', ...
    'SaveFormat',   'Timeseries', ...
    'Position',     pos(X.IntDe, Y+170));

%% --- CONNECT BLOCKS -----------------------------------------------------
%
%  Signal flow:
%
%    Pm ─┐
%        ├─► Sum_PmPe ─► Sum_swing ─► Gain_inv_2Hws ─► Int_omega ─┬─► Sum_dev ─┬─► Gain_D ─► (back to Sum_swing -)
%    Pe ─┘                  ▲                                     │           │
%                           │                                     │           └─► Int_delta ─► Scope ch2
%                           └── (D damping feedback)               └─► Scope ch1
%      omega_s ──► Sum_dev (-)

ln = @(src, dst) add_line(model, src, dst, 'autorouting', 'on');

ln('Pm/1',            'Sum_PmPe/1');
ln('Pe/1',            'Sum_PmPe/2');
ln('Sum_PmPe/1',      'Sum_swing/1');
ln('Sum_swing/1',     'Gain_inv_2Hws/1');
ln('Gain_inv_2Hws/1', 'Int_omega/1');
ln('Int_omega/1',     'Sum_dev/1');
ln('omega_s/1',       'Sum_dev/2');
ln('Sum_dev/1',       'Gain_D/1');
ln('Gain_D/1',        'Sum_swing/2');
ln('Sum_dev/1',       'Int_delta/1');
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

%% --- SAVE MODEL ---------------------------------------------------------

model_path = fullfile(script_dir, [model '.slx']);
save_system(model, model_path);
fprintf('[Stage 1] Model saved : %s\n', model_path);

%% --- RUN SIMULATION -----------------------------------------------------
%
%  Note: in R2018b the model property ReturnWorkspaceOutputs defaults to
%  'off', so the To Workspace blocks write `omega_ts` and `delta_ts`
%  directly into the BASE workspace (not into a Simulink.SimulationOutput
%  object). Because this script itself runs in base, we can read them by
%  name with `evalin('base', ...)` immediately after sim() returns.

fprintf('[Stage 1] Simulating (T_sim = %g s) ...\n', T_sim);
sim(model);

omega_ts = evalin('base', 'omega_ts');
delta_ts = evalin('base', 'delta_ts');

t     = omega_ts.Time;
omega = omega_ts.Data;
delta = delta_ts.Data;
freq  = omega / (2*pi);                  % Hz
Pe_vec = Pe * ones(size(t));             % constant — kept for Python plotter

%% --- SAVE .MAT FOR PYTHON -----------------------------------------------

out_path = fullfile(script_dir, 'vsg_stage1_out.mat');
save(out_path, ...
     't', 'omega', 'delta', 'freq', 'Pe_vec', ...
     'H', 'D', 'omega_s', 'f_base', ...
     'Pm_initial', 'Pm_step', 'Pm_step_time', 'Pe', 'T_sim', ...
     '-v7');

f_nadir = min(freq);
f_ss    = freq(end);
fprintf('[Stage 1] Data saved  : %s\n', out_path);
fprintf('[Stage 1] f_nadir = %.4f Hz   f_ss = %.4f Hz   Df_ss = %+.4f Hz\n', ...
        f_nadir, f_ss, f_ss - f_base);

%% --- QUICK MATLAB PLOT --------------------------------------------------

figure('Name', 'VSG Stage 1 — Swing-Equation Response', ...
       'Color', 'w', 'NumberTitle', 'off');

subplot(2, 1, 1);
plot(t, freq, 'b', 'LineWidth', 1.6); hold on;
plot([t(1) t(end)], [f_base f_base], 'r--');
plot([Pm_step_time Pm_step_time], ylim, 'k:');
text(Pm_step_time, f_base, sprintf('  \\DeltaP_m = +%g pu', Pm_step), ...
     'VerticalAlignment', 'bottom');
xlabel('Time (s)'); ylabel('Frequency (Hz)'); grid on;
title(sprintf('VSG frequency response  [H = %g s,  D = %g]', H, D));

subplot(2, 1, 2);
plot(t, rad2deg(delta), 'm', 'LineWidth', 1.6);
xlabel('Time (s)'); ylabel('\delta (deg)'); grid on;
title('Virtual rotor angle \delta(t)');

fprintf('[Stage 1] Done.\n');
