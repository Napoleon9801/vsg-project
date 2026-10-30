% validate_stage2_manual.m
% =========================================================================
%  VSG PROJECT  ::  STAGE 2 — Validate the hand-built Simulink model
% =========================================================================
%
%  Runs vsg_stage2_manual.slx (built by hand following
%  manual/STAGE2_MANUAL_BUILD.md) and compares its omega/delta traces
%  against the reference output vsg_stage2_out.mat produced by the
%  auto-built model (phase2_power_angle.m).
%
%  PASS criteria (after interpolating onto the reference time grid):
%      max |f_manual - f_ref|      < 1e-4 Hz
%      max |delta_manual - d_ref|  < 1e-4 rad
%
%  Tested on MATLAB R2018b + base Simulink. Run with F5 from this folder.
%
%  Author : Napoleon (Chinnawat Dumklang) — SUT EE
% =========================================================================

model      = 'vsg_stage2_manual';
script_dir = fileparts(mfilename('fullpath'));
ref_path   = fullfile(script_dir, 'vsg_stage2_out.mat');
mdl_path   = fullfile(script_dir, [model '.slx']);

TOL_F     = 1e-4;   % Hz
TOL_DELTA = 1e-4;   % rad

%% --- PRECONDITIONS ------------------------------------------------------

if ~exist(ref_path, 'file')
    error(['Reference vsg_stage2_out.mat not found.\n' ...
           'Run phase2_power_angle.m first to regenerate it.']);
end
if ~exist(mdl_path, 'file')
    error(['%s.slx not found in %s.\n' ...
           'Build it by hand first — see manual\\STAGE2_MANUAL_BUILD.md.'], ...
          model, script_dir);
end

ref = load(ref_path);   % t, omega, delta, freq, Pmax, delta_eq_new, ...

%% --- RUN THE MANUAL MODEL ----------------------------------------------

if bdIsLoaded(model)
    close_system(model, 0);
end
evalin('base', 'clear omega_ts delta_ts');

load_system(mdl_path);
fprintf('[Validate] Simulating %s ...\n', model);
sim(model);

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

fprintf('\n================ STAGE 2 MANUAL-BUILD VALIDATION ================\n');
fprintf('  delta_final        : %8.3f deg  (ref %8.3f deg, eq %8.3f deg)\n', ...
        rad2deg(d_man(end)), rad2deg(ref.delta(end)), rad2deg(ref.delta_eq_new));
fprintf('  delta_peak         : %8.3f deg  (ref %8.3f deg)\n', ...
        rad2deg(max(d_man)), rad2deg(max(ref.delta)));
fprintf('  f_peak             : %8.4f Hz   (ref %8.4f Hz)\n', ...
        max(f_man), max(ref.freq));
fprintf('  f_final            : %8.4f Hz   (ref %8.4f Hz)\n', ...
        f_man(end), ref.freq(end));
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
    fprintf(['  RESULT             : FAIL — common Stage-2 mistakes:\n' ...
             '                       * Int_delta IC must be asin(1.0/2.1)\n' ...
             '                       * Gain_D must be 0.3 (not 10)\n' ...
             '                       * Gain_Pmax (2.1) must enter Sum_PmPe at the MINUS port\n' ...
             '                       * StopTime must be 5 s\n']);
end
fprintf('==================================================================\n');

%% --- OVERLAY PLOT -------------------------------------------------------

Pe_man = ref.Pmax * sin(d_man);

figure('Name', 'Stage 2 - Manual vs Reference', 'Color', 'w', 'NumberTitle', 'off');

subplot(3, 1, 1);
plot(ref.t, ref.freq, 'b', 'LineWidth', 1.8); hold on;
plot(ref.t, f_man, 'r--', 'LineWidth', 1.2);
ylabel('f (Hz)'); grid on;
legend('reference (auto-built)', 'manual build', 'Location', 'northeast');
title('Stage 2: Frequency (manual vs reference)');

subplot(3, 1, 2);
plot(ref.t, rad2deg(ref.delta), 'b', 'LineWidth', 1.8); hold on;
plot(ref.t, rad2deg(d_man), 'r--', 'LineWidth', 1.2);
ylabel('\delta (deg)'); grid on;
legend('reference (auto-built)', 'manual build', 'Location', 'southeast');
title('Stage 2: Rotor angle (manual vs reference)');

subplot(3, 1, 3);
plot(ref.t, ref.Pe, 'Color', [0.1 0.5 0.1], 'LineWidth', 1.8); hold on;
plot(ref.t, Pe_man, 'r--', 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('P_e (pu)'); grid on;
legend('reference (auto-built)', 'manual build', 'Location', 'southeast');
title('Electrical power P_e = P_{max}\cdot sin(\delta)');
