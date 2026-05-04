% VSG Phase 1 — Swing Equation Simulation
% Models: J*d(omega)/dt = Pm - Pe - D*(omega - omega_ref)
%
% Run vsg_params.m first to load system parameters.

vsg_params;

%% Time vector
t = 0 : Ts : T_end;
N = length(t);

%% State initialisation
omega   = zeros(1, N);   % Angular frequency (rad/s)
delta   = zeros(1, N);   % Rotor angle (rad)
omega(1) = omega_n;
delta(1) = 0;

%% Disturbance: step change in electrical power at t = 1s
Pe = Pm_ref * ones(1, N);
Pe(t >= 1.0) = Pm_ref * 1.2;   % 20% load step at t = 1s

%% Euler integration of swing equation
for k = 1 : N-1
    d_omega = (Pm_ref - Pe(k) - D * (omega(k) - omega_ref)) / J;
    omega(k+1) = omega(k) + Ts * d_omega;
    delta(k+1) = delta(k) + Ts * omega(k);
end

freq = omega / (2 * pi);   % Convert to Hz

%% Plot results
figure('Name', 'VSG Phase 1 — Swing Equation Response');

subplot(2,1,1);
plot(t, freq, 'b', 'LineWidth', 1.5);
yline(50, 'r--', 'f_n = 50 Hz');
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('VSG Frequency Response to 20% Load Step at t = 1s');
grid on;

subplot(2,1,2);
plot(t, rad2deg(delta), 'm', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Rotor Angle (deg)');
title('Virtual Rotor Angle \delta(t)');
grid on;

%% Save simulation data
script_dir = fileparts(mfilename('fullpath'));          % .../matlab/scripts
data_dir   = fullfile(script_dir, '..', 'data');       % .../matlab/data
if ~exist(data_dir, 'dir'); mkdir(data_dir); end
save_path  = fullfile(data_dir, 'phase1_swing.mat');
save(save_path, 't', 'omega', 'delta', 'freq', 'Pe');
fprintf('Simulation complete. Data saved to %s\n', save_path);
