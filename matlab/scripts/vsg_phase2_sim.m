% VSG Phase 2 — Active/Reactive Power Control with Secondary Frequency Restoration
%
% Adds to Phase 1:
%   1. Secondary frequency restoration: dPm/dt = Ki_sec*(omega_ref - omega)
%   2. Angle dynamics:                  d_delta/dt = omega - omega_ref
%   3. Q-V droop:                       E = E_ref + Kq*(Q_ref - Q)
%   4. Simplified grid model:           Pe = (E*V_g*sin(delta))/X_g
%                                       Q  = (E*V_g*cos(delta) - V_g^2)/X_g
%
% Compares Phase 1 (no secondary) vs Phase 2 (with secondary) side by side.

vsg_params;

%% Time vector
t  = 0 : Ts : T_end;
N  = length(t);

%% ── PHASE 1 (reference — no secondary, Pe forced) ────────────────────────
omega_p1 = zeros(1, N);
omega_p1(1) = omega_n;

Pe_forced        = Pm_ref * ones(1, N);
Pe_forced(t >= 1.0) = Pm_ref * 1.2;   % 20% load step at t = 1s

for k = 1 : N-1
    d_omega = (Pm_ref - Pe_forced(k) - D*(omega_p1(k) - omega_ref)) / J;
    omega_p1(k+1) = omega_p1(k) + Ts * d_omega;
end
freq_p1 = omega_p1 / (2*pi);

%% ── PHASE 2 (secondary restoration + Q-V droop + grid model) ─────────────
omega_p2 = zeros(1, N);
delta_p2 = zeros(1, N);
Pm_p2    = zeros(1, N);
E_p2     = zeros(1, N);
Pe_p2    = zeros(1, N);
Q_p2     = zeros(1, N);

% Initial conditions — equilibrium: Pe = Pm_ref at delta = asin(Pm_ref*X_g / (E_ref*V_g))
delta0       = asin(Pm_ref * X_g / (E_ref * V_g));
omega_p2(1)  = omega_n;
delta_p2(1)  = delta0;
Pm_p2(1)     = Pm_ref;
E_p2(1)      = E_ref;
Pe_p2(1)     = Pm_ref;
Q_p2(1)      = (E_ref * V_g * cos(delta0) - V_g^2) / X_g;

% Load disturbance: model as a conductance increase (extra load current)
% Represented as an additive Pe disturbance on top of grid model output
delta_Pe        = zeros(1, N);
delta_Pe(t >= 1.0) = 0.2 * Pm_ref;   % same 20% step disturbance

for k = 1 : N-1
    % Grid model: electrical power and reactive power from P-δ, Q-V equations
    Pe_p2(k) = (E_p2(k) * V_g * sin(delta_p2(k))) / X_g + delta_Pe(k);
    Q_p2(k)  = (E_p2(k) * V_g * cos(delta_p2(k)) - V_g^2) / X_g;

    % Q-V droop: update virtual EMF
    E_p2(k+1) = E_ref + Kq * (Q_ref - Q_p2(k));

    % Swing equation
    d_omega = (Pm_p2(k) - Pe_p2(k) - D*(omega_p2(k) - omega_ref)) / J;
    omega_p2(k+1) = omega_p2(k) + Ts * d_omega;

    % Angle dynamics
    delta_p2(k+1) = delta_p2(k) + Ts * (omega_p2(k) - omega_ref);

    % Secondary frequency restoration integral
    Pm_p2(k+1) = Pm_p2(k) + Ts * Ki_sec * (omega_ref - omega_p2(k));
end

freq_p2 = omega_p2 / (2*pi);

%% ── Results ───────────────────────────────────────────────────────────────
idx1 = find(freq_p1 == min(freq_p1), 1);
idx2 = find(freq_p2 == min(freq_p2), 1);

fprintf('=== Phase 1 (no secondary) ===\n');
fprintf('  Frequency nadir    : %.4f Hz at t = %.3f s\n', freq_p1(idx1), t(idx1));
fprintf('  Steady-state freq  : %.4f Hz\n', freq_p1(end));

fprintf('\n=== Phase 2 (with secondary restoration) ===\n');
fprintf('  Frequency nadir    : %.4f Hz at t = %.3f s\n', freq_p2(idx2), t(idx2));
fprintf('  Steady-state freq  : %.4f Hz\n', freq_p2(end));
fprintf('  Steady-state Pm    : %.2f W (adapted from %.2f W ref)\n', Pm_p2(end), Pm_ref);

%% ── Plot ──────────────────────────────────────────────────────────────────
figure('Name', 'VSG Phase 2 — Secondary Frequency Restoration', 'Position', [100 100 900 700]);

subplot(3,1,1);
plot(t, freq_p1, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Phase 1 (no secondary)');
hold on;
plot(t, freq_p2, 'b',   'LineWidth', 1.8, 'DisplayName', 'Phase 2 (with secondary)');
yline(50, 'k:', 'LineWidth', 1, 'DisplayName', 'f_n = 50 Hz');
xline(1.0, 'Color', [0.5 0.5 0.5], 'LineStyle', ':', 'DisplayName', 'Load step');
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('Frequency Response — Phase 1 vs Phase 2');
legend('Location', 'southeast'); grid on;

subplot(3,1,2);
plot(t, Pm_p2, 'g', 'LineWidth', 1.8);
yline(Pm_ref, 'k:', 'LineWidth', 1);
yline(Pm_ref * 1.2, 'r--', 'LineWidth', 1);
xline(1.0, 'Color', [0.5 0.5 0.5], 'LineStyle', ':');
xlabel('Time (s)'); ylabel('Pm (W)');
title('Virtual Mechanical Power Pm(t) — Secondary Controller Output');
grid on;

subplot(3,1,3);
plot(t, rad2deg(delta_p2), 'm', 'LineWidth', 1.8);
xline(1.0, 'Color', [0.5 0.5 0.5], 'LineStyle', ':');
xlabel('Time (s)'); ylabel('\delta (deg)');
title('Virtual Rotor Angle \delta(t)');
grid on;

%% ── Save ──────────────────────────────────────────────────────────────────
script_dir = fileparts(mfilename('fullpath'));
data_dir   = fullfile(script_dir, '..', 'data');
if ~exist(data_dir, 'dir'); mkdir(data_dir); end
save_path  = fullfile(data_dir, 'phase2_power_control.mat');
save(save_path, 't', 'omega_p1', 'omega_p2', 'freq_p1', 'freq_p2', ...
     'Pm_p2', 'delta_p2', 'E_p2', 'Q_p2', 'Pe_p2');
fprintf('\nData saved to %s\n', save_path);
