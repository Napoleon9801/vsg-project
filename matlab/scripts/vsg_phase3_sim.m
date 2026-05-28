% VSG Phase 3 — Grid-Connected Inverter (Quasi-Static Electrical, L-Filter)
%
% Assumption: inner current control bandwidth >> VSG bandwidth.
% The electrical subsystem is solved quasi-statically at each timestep:
%   R_f*i_d - omega*L_f*i_q = E*cos(delta) - V_g
%   R_f*i_q + omega*L_f*i_d = E*sin(delta)
%
% Solving the 2x2 system:
%   i_d = [R_f*(E*cos(delta)-V_g) + omega*L_f*E*sin(delta)] / Z^2
%   i_q = [R_f*E*sin(delta) - omega*L_f*(E*cos(delta)-V_g)] / Z^2
%   where Z^2 = R_f^2 + (omega*L_f)^2
%
% Mechanical state vector: [omega, delta, Pm]  (same as Phase 2)
% Electrical outputs:       i_d, i_q, Pe, Q    (quasi-static, no stiff ODE)

vsg_params;

%% Time vector
t  = 0 : Ts : T_end;
N  = length(t);

%% State initialisation ────────────────────────────────────────────────────
% Equilibrium at omega = omega_n, Pe = Pm_ref, Q = Q_ref = 0
% From quasi-static: solve for delta_0 and E_0
% Pe = 1.5*V_g*i_d,  Q = -1.5*V_g*i_q
% i_d_target = Pm_ref/(1.5*V_g),  i_q_target = 0
%
% Back-compute E and delta from the 2x2 system:
%   E*cos(delta) = V_g + R_f*i_d0 - omega_n*L_f*i_q0
%   E*sin(delta) =       R_f*i_q0 + omega_n*L_f*i_d0

i_d0   = Pm_ref / (1.5 * V_g);
i_q0   = -Q_ref  / (1.5 * V_g);
rhs_d  = V_g + R_f*i_d0 - omega_n*L_f*i_q0;
rhs_q  =       R_f*i_q0 + omega_n*L_f*i_d0;
E0     = sqrt(rhs_d^2 + rhs_q^2);
delta0 = atan2(rhs_q, rhs_d);

omega  = zeros(1,N);  delta  = zeros(1,N);  Pm  = zeros(1,N);
i_d    = zeros(1,N);  i_q    = zeros(1,N);
E_arr  = zeros(1,N);  Pe     = zeros(1,N);  Q_arr = zeros(1,N);

omega(1)  = omega_n;  delta(1) = delta0;  Pm(1) = Pm_ref;
E_arr(1)  = E0;

fprintf('Initial conditions:\n');
fprintf('  i_d0 = %.4f A  |  i_q0 = %.4f A\n', i_d0, i_q0);
fprintf('  E0   = %.4f V  |  delta0 = %.4f deg\n', E0, rad2deg(delta0));

%% Load disturbance: step at t = 1s ────────────────────────────────────────
% 20% load increase → extra i_d drawn from inverter output
i_load          = zeros(1,N);
i_load(t >= 1.0) = 0.2 * i_d0;

%% Euler integration ───────────────────────────────────────────────────────
for k = 1 : N-1
    % Q-V droop: virtual EMF magnitude
    Q_arr(k)  = -1.5 * V_g * i_q(k);
    E_arr(k)  = E_ref + Kq * (Q_ref - Q_arr(k));

    % Quasi-static electrical equations
    Z2        = R_f^2 + (omega(k)*L_f)^2;
    Ed        = E_arr(k)*cos(delta(k));
    Eq        = E_arr(k)*sin(delta(k));
    i_d(k)    = (R_f*(Ed - V_g) + omega(k)*L_f*Eq)    / Z2;
    i_q(k)    = (R_f*Eq         - omega(k)*L_f*(Ed - V_g)) / Z2;

    % Active power to grid (net of local load)
    Pe(k)     = 1.5 * V_g * (i_d(k) - i_load(k));

    % Swing equation
    d_omega   = (Pm(k) - Pe(k) - D*(omega(k) - omega_ref)) / J;
    % Angle dynamics
    d_delta   = omega(k) - omega_ref;
    % Secondary frequency restoration
    d_Pm      = Ki_sec * (omega_ref - omega(k));

    omega(k+1) = omega(k) + Ts * d_omega;
    delta(k+1) = delta(k) + Ts * d_delta;
    Pm(k+1)    = Pm(k)    + Ts * d_Pm;
end

% Final sample
Q_arr(N) = -1.5 * V_g * i_q(N);
E_arr(N) = E_ref + Kq*(Q_ref - Q_arr(N));
Z2_N     = R_f^2 + (omega(N)*L_f)^2;
Ed_N     = E_arr(N)*cos(delta(N)); Eq_N = E_arr(N)*sin(delta(N));
i_d(N)   = (R_f*(Ed_N - V_g) + omega(N)*L_f*Eq_N) / Z2_N;
i_q(N)   = (R_f*Eq_N - omega(N)*L_f*(Ed_N - V_g)) / Z2_N;
Pe(N)    = 1.5 * V_g * (i_d(N) - i_load(N));

freq = omega / (2*pi);

%% Results ─────────────────────────────────────────────────────────────────
idx_nadir = find(freq == min(freq), 1);
fprintf('\n=== Phase 3 — Grid-Connected Inverter ===\n');
fprintf('  Frequency nadir    : %.4f Hz at t = %.3f s\n', freq(idx_nadir), t(idx_nadir));
fprintf('  Steady-state freq  : %.4f Hz\n', freq(end));
fprintf('  Steady-state Pe    : %.2f W\n', Pe(end));
fprintf('  Steady-state Q     : %.2f VAR\n', Q_arr(end));
fprintf('  Steady-state i_d   : %.4f A\n', i_d(end));
fprintf('  Steady-state i_q   : %.4f A\n', i_q(end));
fprintf('  Steady-state delta : %.4f deg\n', rad2deg(delta(end)));

%% Plot ────────────────────────────────────────────────────────────────────
clr_blue   = [0.27 0.51 0.71];
clr_green  = [0.18 0.55 0.34];
clr_red    = [0.86 0.27 0.22];
clr_orange = [0.93 0.53 0.18];
clr_purple = [0.56 0.35 0.71];
clr_gray   = [0.5 0.5 0.5];

figure('Name','VSG Phase 3 — Grid-Connected Inverter','Position',[100 100 950 800]);

subplot(3,2,1);
plot(t, freq, 'Color',clr_blue,'LineWidth',1.8); hold on;
yline(50,'k:','LineWidth',1); xline(1,'Color',clr_gray,'LineStyle',':');
ylabel('Frequency (Hz)'); title('Grid Frequency \omega/2\pi'); grid on;

subplot(3,2,2);
plot(t, Pm, 'Color',clr_green,'LineWidth',1.8); hold on;
yline(Pm_ref,'k:'); xline(1,'Color',clr_gray,'LineStyle',':');
ylabel('Pm (W)'); title('Virtual Mechanical Power Pm(t)'); grid on;

subplot(3,2,3);
plot(t, i_d, 'Color',clr_blue,'LineWidth',1.8); hold on;
xline(1,'Color',clr_gray,'LineStyle',':');
ylabel('i_d (A)'); title('d-axis Current i_d(t)  [\propto Active Power]'); grid on;

subplot(3,2,4);
plot(t, i_q, 'Color',clr_red,'LineWidth',1.8); hold on;
yline(0,'k:'); xline(1,'Color',clr_gray,'LineStyle',':');
ylabel('i_q (A)'); title('q-axis Current i_q(t)  [\propto Reactive Power]'); grid on;

subplot(3,2,5);
plot(t, Pe, 'Color',clr_orange,'LineWidth',1.8); hold on;
yline(Pm_ref,'k:'); xline(1,'Color',clr_gray,'LineStyle',':');
ylabel('Pe (W)'); xlabel('Time (s)');
title('Active Power Delivered to Grid Pe(t)'); grid on;

subplot(3,2,6);
plot(t, rad2deg(delta), 'Color',clr_purple,'LineWidth',1.8); hold on;
xline(1,'Color',clr_gray,'LineStyle',':');
ylabel('\delta (deg)'); xlabel('Time (s)');
title('Virtual Rotor Angle \delta(t)'); grid on;

%% Save ────────────────────────────────────────────────────────────────────
script_dir = fileparts(mfilename('fullpath'));
data_dir   = fullfile(script_dir, '..', 'data');
if ~exist(data_dir,'dir'); mkdir(data_dir); end
save_path  = fullfile(data_dir, 'phase3_inverter.mat');
save(save_path,'t','omega','delta','Pm','i_d','i_q','E_arr','Pe','Q_arr','freq');
fprintf('\nData saved to %s\n', save_path);
