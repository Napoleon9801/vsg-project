% vsg_simscape_params.m
% VSG 10 kVA / 400 V / 50 Hz — Simscape Electrical R2026a Parameter File
%
% All quantities in SI (not per-unit) unless labelled _pu.
% These values size a small-scale grid-connected VSG suitable for
% incremental Simulink testing on a stiff 3-phase 400 V / 50 Hz bus.
%
% Reference topology:
%   DC Bus -> 3-Phase VSI (average model) -> LC Filter -> Grid Impedance -> Stiff Grid
%
% Control layers (outer to inner):
%   1. Swing equation (virtual inertia + damping)  — generates omega_vsg, theta
%   2. Reactive-power / voltage droop              — generates E_ref magnitude
%   3. Park-transform voltage reference            — generates v_d*, v_q*
%   4. Inner current control (PI, dq frame)        — generates d*, q* duty cycles
%   5. SPWM / SVM modulation                       — drives VSI switches
%
% For the Simscape Electrical averaged-inverter model (Phase 1 build) steps
% 4 and 5 are collapsed: the averaged inverter takes v_abc* directly.
%
% Author : Napoleon (Chinnawat Dumklang), SUT EE Year 3
% Date   : 2026-05-13

%% =========================================================================
%  GRID / SYSTEM BASE
%% =========================================================================
S_base   = 10e3;          % Rated apparent power (VA)
V_base   = 400;           % Line-to-line RMS (V) — European LV standard
f_0      = 50;            % Nominal frequency (Hz)
omega_0  = 2*pi*f_0;      % Nominal angular frequency (rad/s)  = 314.159 rad/s
V_phase  = V_base / sqrt(3);  % Phase RMS voltage (V)  = 230.9 V
V_pk     = V_phase * sqrt(2); % Phase peak voltage (V) = 326.6 V
I_rated  = S_base / (sqrt(3) * V_base);  % Rated line current (A) = 14.43 A

%% =========================================================================
%  DC BUS
%% =========================================================================
% Rule of thumb: V_dc >= sqrt(2) * V_LL * modulation_index_margin
% For full-range SPWM: V_dc >= sqrt(2) * 400 * 1.15 = 651 V
% Rounded up to a practical value:
V_dc     = 700;           % DC bus voltage (V)

%% =========================================================================
%  VIRTUAL INERTIA & DAMPING (swing equation)
%  Swing equation: J * d(omega)/dt = T_m - T_e - D*(omega - omega_0)
%  Equivalently in power:  J*omega_0 * d(omega)/dt ≈ P_m - P_e - D_p*(omega - omega_0)
%
%  Choosing J:
%    Equivalent inertia constant H = J * omega_0^2 / (2 * S_base)
%    Targeting H = 4 s (typical synchronous generator range: 2-10 s)
%    => J = 2*H*S_base / omega_0^2
%
%  Choosing D:
%    D determines the damping ratio of the frequency oscillation.
%    D_p = P_rated / delta_omega_max  where delta_omega_max = 2*pi*0.5 (0.5 Hz droop)
%    => D_p ≈ 10000 / (2*pi*0.5) = 3183 W/(rad/s)
%    Round to a cleaner value:
%% =========================================================================
H_vsg    = 4;             % Target virtual inertia constant (s)
J        = 2 * H_vsg * S_base / omega_0^2;   % Virtual inertia (kg·m²) = 0.2027 kg·m²
D_p      = 3000;          % Active power damping / droop (W/(rad/s))
                          %   = ~955 W per 0.1 Hz deviation — reasonable for 10 kVA

% Secondary check: natural frequency of swing oscillation
% omega_n_swing = sqrt(D_p / J)  (approximate, ignoring grid stiffness)
omega_n_swing = sqrt(D_p / J);  % rad/s  — expect ~120 rad/s ≈ 19 Hz (fast, stiff grid)

%% =========================================================================
%  REACTIVE POWER / VOLTAGE DROOP
%  Q droop: E = E_ref - K_q * (Q - Q_ref)
%  K_q: voltage change per VAR.  A 5% voltage change at rated Q gives:
%    K_q = 0.05 * V_phase / S_base = 0.05 * 230.9 / 10000 = 1.155e-3 V/VAR
%% =========================================================================
K_q      = 1.2e-3;        % Reactive power droop gain (V/VAR)
Q_ref    = 0;             % Reference reactive power (VAR) — unity PF nominal
E_ref    = V_phase;       % Reference internal EMF peak/RMS depends on context;
                          % used as RMS here for the swing equation output.

%% =========================================================================
%  LC OUTPUT FILTER
%  Design criteria:
%    1. Filter corner frequency f_c = 1/(2*pi*sqrt(L_f*C_f)) << f_sw
%    2. f_c >> f_0 to pass fundamental with low attenuation
%    3. Typical f_sw for VSI: 10-20 kHz.  Target f_c ≈ 1.5 kHz.
%
%  Base impedance: Z_base = V_base^2 / S_base = 16 Ω
%
%  L_f: typically 0.05–0.15 pu
%    L_f = 0.08 * Z_base / omega_0 = 0.08 * 16 / 314.16 = 4.07 mH  → 4 mH
%
%  C_f: target f_c with chosen L_f
%    C_f = 1 / ((2*pi*f_c)^2 * L_f)
%    f_c = 1500 Hz, L_f = 4e-3: C_f = 1/(2*pi*1500)^2/4e-3 = 2.82 µF  → 3 µF
%
%  Filter resistance R_f: parasitic + small damping resistor
%    R_f = 0.01 * Z_base = 0.16 Ω  (limits peak at resonance)
%% =========================================================================
Z_base   = V_base^2 / S_base;  % Base impedance (Ω) = 16 Ω
f_sw     = 10e3;                % Switching frequency (Hz) = 10 kHz
f_c_filt = 1500;                % Filter corner frequency (Hz)

L_f      = 0.08 * Z_base / omega_0;   % Filter inductance (H) = 4.07 mH
C_f      = 1 / ((2*pi*f_c_filt)^2 * L_f);  % Filter capacitance (F) = 2.8 µF
R_f      = 0.01 * Z_base;             % Filter series resistance (Ω) = 0.16 Ω
R_damp   = sqrt(L_f / C_f) * 0.3;    % Optional parallel damping R across C_f (Ω)
                                       % = 0.3 * sqrt(L_f/C_f) ≈ 6.9 Ω

% Verify corner frequency:
f_c_check = 1 / (2*pi*sqrt(L_f*C_f));   % Should be ≈ 1500 Hz

fprintf('Filter check: L_f=%.3f mH, C_f=%.2f uF, f_c=%.1f Hz\n', ...
    L_f*1e3, C_f*1e6, f_c_check);

%% =========================================================================
%  GRID IMPEDANCE (between filter capacitor and infinite bus)
%  Represents line + transformer leakage.
%  Typical X/R = 7 for MV grid, lower for LV lab setup.
%  Target Z_g = 0.05 pu = 0.8 Ω at 10 kVA base.
%  With X/R = 5: R_g = Z_g/sqrt(1+25) ≈ 0.154 Ω, L_g = R_g*5/omega_0
%% =========================================================================
Z_g_pu   = 0.05;                      % Grid impedance (pu)
Z_g      = Z_g_pu * Z_base;           % Grid impedance magnitude (Ω) = 0.8 Ω
XR_ratio = 5;                         % X/R ratio (laboratory LV grid)
R_g      = Z_g / sqrt(1 + XR_ratio^2);    % Grid resistance (Ω) = 0.157 Ω
L_g      = R_g * XR_ratio / omega_0;      % Grid inductance (H) = 2.50 mH

fprintf('Grid impedance: R_g=%.4f Ohm, L_g=%.3f mH (Z_g=%.3f pu)\n', ...
    R_g, L_g*1e3, Z_g_pu);

%% =========================================================================
%  INNER CURRENT CONTROL (PI, synchronous dq frame)
%  Plant: L_total = L_f + L_g (filter + grid inductance in series)
%  Desired current loop bandwidth: omega_cc = 0.1 * omega_sw = 2*pi*1000 rad/s
%
%  PI tuning (modulus optimum / symmetrical optimum):
%    Kp_i = L_total * omega_cc          (cancel pole at s = R/L)
%    Ki_i = R_total * omega_cc          (integrator gain)
%
%  The feed-forward decoupling terms (+/- omega*L*i_dq) are added separately.
%% =========================================================================
L_total  = L_f + L_g;         % Total series inductance seen by current controller (H)
R_total  = R_f + R_g;         % Total series resistance (Ω)
omega_cc = 2*pi*1000;          % Current control bandwidth (rad/s) = 6283 rad/s

Kp_i     = L_total * omega_cc;           % Current loop proportional gain (V/A) = 41.6
Ki_i     = R_total * omega_cc;           % Current loop integral gain (V/(A·s)) = 1980

fprintf('Current PI: Kp=%.2f V/A, Ki=%.1f V/(As)\n', Kp_i, Ki_i);

%% =========================================================================
%  OUTER POWER CONTROL (via swing equation, no separate PI needed)
%  The swing equation IS the outer power loop — J and D_p set bandwidth.
%  Voltage outer loop uses K_q droop (already defined above).
%  If a PLL is used for grid synchronisation, its bandwidth should be set
%  well below the current loop: omega_pll ≈ 0.1 * omega_cc = 628 rad/s.
%% =========================================================================
omega_pll = 0.1 * omega_cc;   % PLL bandwidth (rad/s)
Kp_pll    = 2 * omega_pll / V_pk;   % PLL proportional gain (typical SRF-PLL)
Ki_pll    = omega_pll^2 / V_pk;     % PLL integral gain

%% =========================================================================
%  SIMULATION SETTINGS
%% =========================================================================
Ts_ctrl  = 1 / f_sw;          % Control sample time = 100 µs
Ts_sim   = 1e-6;               % Simscape electrical solver step (s) = 1 µs
                                % Must satisfy: Ts_sim << 1/(10*f_sw) = 10 µs
T_end    = 5;                  % Total simulation time (s)

% Recommended Simscape solver: 'ode23t' (trapezoidal + NDF, stiff-capable)
% This replaces the Powergui role from SPS.

%% =========================================================================
%  PRINT SUMMARY
%% =========================================================================
fprintf('\n===== VSG 10 kVA / 400 V / 50 Hz — Parameter Summary =====\n');
fprintf('  DC bus:          V_dc  = %g V\n',     V_dc);
fprintf('  Virtual inertia: J     = %.4f kg·m²  (H_eq = %g s)\n', J, H_vsg);
fprintf('  Damping:         D_p   = %g W/(rad/s)\n', D_p);
fprintf('  Filter:          L_f   = %.3f mH,  C_f = %.2f µF,  R_f = %.3f Ω\n', ...
                            L_f*1e3, C_f*1e6, R_f);
fprintf('  Grid impedance:  R_g   = %.4f Ω,   L_g = %.3f mH\n', R_g, L_g*1e3);
fprintf('  Current PI:      Kp_i  = %.2f,  Ki_i = %.1f\n', Kp_i, Ki_i);
fprintf('  Q droop:         K_q   = %.4e V/VAR\n', K_q);
fprintf('  Solver step:     Ts    = %g µs  (model: ode23t)\n', Ts_sim*1e6);
fprintf('=========================================================\n');
