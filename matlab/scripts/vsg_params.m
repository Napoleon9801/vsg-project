% VSG System Parameters
% Central parameter file — source this before running any simulation

%% Virtual Inertia & Damping
J   = 0.1;      % Virtual inertia constant (kg·m²) — higher = slower frequency response
D   = 10;       % Damping coefficient (N·m·s/rad)
Dp  = 20;       % Active power droop coefficient

%% Nominal Grid Values
omega_n = 2 * pi * 50;  % Nominal angular frequency (rad/s) — 50 Hz grid
V_n     = 220;          % Nominal voltage RMS (V)
S_n     = 1000;         % Nominal apparent power (VA)

%% Active Power Control
Pm_ref  = 500;   % Reference mechanical power input (W)
omega_ref = omega_n;    % Reference angular frequency (rad/s)

%% Reactive Power / Voltage Control
Q_ref   = 0;     % Reference reactive power (VAR)
E_ref   = V_n;   % Reference internal EMF magnitude (V)
Kq      = 0.001; % Reactive power droop gain (V/VAR)

%% Phase 2 — Secondary Frequency Restoration & Grid Model
Ki_sec  = 5;     % Secondary frequency restoration integral gain (W·s/rad)
X_g     = 10;    % Grid reactance (Ω) — determines P-δ and Q-V coupling
V_g     = V_n;   % Grid terminal voltage magnitude (V)

%% Simulation
Ts  = 1e-5;      % Simulation time step (s)
T_end = 5;       % Simulation duration (s)
