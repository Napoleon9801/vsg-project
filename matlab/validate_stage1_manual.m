% validate_stage1_manual.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 1 — Validate the hand-built Simulink model
% =========================================================================
%
%  Runs vsg_stage1_manual.slx (built by hand following
%  manual/STAGE1_MANUAL_BUILD.md) and compares its omega/delta traces
%  against the reference output vsg_stage1_out.mat produced by the
%  auto-built model (phase1_swing_equation.m).
%
%  PASS criteria (after interpolating both traces onto the reference
%  time grid):
%      max |f_manual - f_ref|      < 1e-4 Hz
%      max |delta_manual - d_ref|  < 1e-4 rad
%
%  Tested on MATLAB R2018b + base Simulink. Run with F5 from this folder.
%
%  Author : Napoleon (Chinnawat Dumklang) — SUT EE
% =========================================================================

model      = 'vsg_stage1_manual';
script_dir = fileparts(mfilename('fullpath'));
ref_path   = fullfile(script_dir, 'vsg_stage1_out.mat');
mdl_path   = fullfile(script_dir, [model '.slx']);

TOL_F     = 1e-4;   % Hz
TOL_DELTA = 1e-4;   % rad

%% --- PRECONDITIONS ------------------------------------------------------

if ~exist(ref_path, 'file')
    error(['Reference vsg_stage1_out.mat not found.\n' ...
           'Run phase1_swing_equation.m first to regenerate it.']);
end
if ~exist(mdl_path, 'file')
    error(['%s.slx not found in %s.\n' ...
           'Build it by hand first — see manual\\STAGE1_MANUAL_BUILD.md.'], ...
          model, script_dir);
end

ref = load(ref_path);   % t, omega, delta, freq, f_base, ...

%% --- RUN THE MANUAL MODEL ----------------------------------------------

if bdIsLoaded(model)
    close_system(model, 0);
end
evalin('base', 'clear omega_ts delta_ts');

load_system(mdl_path);
fprintf('[Validate] Simulating %s ...\n', model);
sim(model);

% R2018b: To Workspace blocks write straight into the base workspace.
try
    omega_ts = evalin('base', 'omega_ts');
    delta_ts = evalin('base', 'delta_ts');
catch
    error(['omega_ts / delta_ts not found after sim.\n' ...
           'Check the To Workspace blocks: Variable name must be ' ...
           'omega_ts / delta_ts and Save format must be Timeseries.']);
end

%% --- COMPARE ON THE REFERENCE TIME GRID ---------------------------------

f_man = interp1(omega_ts.Time, omega_ts.Data, ref.t, 'linear') / (2*pi);
d_man = interp1(delta_ts.Time, delta_ts.Data, ref.t, 'linear');

err_f = max(abs(f_man - ref.freq));
err_d = max(abs(d_man - ref.delta));

f_nadir = min(f_man);
f_ss    = f_man(end);

fprintf('\n================ STAGE 1 MANUAL-BUILD VALIDATION ================\n');
fprintf('  f_nadir            : %.5f Hz   (ref %.5f Hz)\n', f_nadir, min(ref.freq));
fprintf('  f_ss               : %.5f Hz   (ref %.5f Hz)\n', f_ss, ref.freq(end));
fprintf('  max |df|           : %.3e Hz   (tol %.0e)\n', err_f, TOL_F);
fprintf('  max |ddelta|       : %.3e rad  (tol %.0e)\n', err_d, TOL_DELTA);

pass_f = err_f < TOL_F;
pass_d = err_d < TOL_DELTA;

if pass_f, s1 = 'PASS'; else, s1 = 'FAIL'; end
if pass_d, s2 = 'PASS'; else, s2 = 'FAIL'; end
fprintf('  frequency trace    : %s\n', s1);
fprintf('  delta trace        : %s\n', s2);

if pass_f && pass_d
    fprintf('  RESULT             : PASS — manual model matches reference.\n');
else
    fprintf(['  RESULT             : FAIL — check Sum signs, integrator ICs\n' ...
             '                       (Int_omega IC must be 2*pi*50), gains,\n' ...
             '                       and solver settings (ode45, MaxStep 1e-3).\n']);
end
fprintf('==================================================================\n');

%% --- OVERLAY PLOT -------------------------------------------------------

figure('Name', 'Stage 1 - Manual vs Reference', 'Color', 'w', 'NumberTitle', 'off');

subplot(2, 1, 1);
plot(ref.t, ref.freq, 'b', 'LineWidth', 1.8); hold on;
plot(ref.t, f_man, 'r--', 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('Frequency (Hz)'); grid on;
legend('reference (auto-built)', 'manual build', 'Location', 'southeast');
title('Stage 1: Frequency response (manual vs reference)');

subplot(2, 1, 2);
plot(ref.t, rad2deg(ref.delta), 'b', 'LineWidth', 1.8); hold on;
plot(ref.t, rad2deg(d_man), 'r--', 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('\delta (deg)'); grid on;
legend('reference (auto-built)', 'manual build', 'Location', 'southeast');
title('Stage 1: Rotor angle (manual vs reference)');
