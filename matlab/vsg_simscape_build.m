% vsg_simscape_build.m
% VSG 10 kVA / 400 V / 50 Hz — Full Simscape Electrical R2026a Build Script
%
% Builds the complete VSG Simulink model PROGRAMMATICALLY using only
% Simscape Electrical blocks (no SimPowerSystems / Specialized Power Systems).
% The SPS library (SimPowerSystems) was removed in R2026a; every electrical
% block here comes from the 'ee_lib' (Simscape Electrical) namespace.
%
% MODEL ARCHITECTURE
% ==================
%   [DC Bus]  ->  [3-Phase Averaged VSI]  ->  [LC Filter (3-phase)]
%             ->  [Grid Impedance RL]     ->  [Stiff 3-Phase Grid]
%
%   Control path (pure Simulink, no Simscape):
%   [Swing Eq. subsystem] -> [Park Transform] -> [Current PI] -> [VSI modulation]
%
% BUILD ORDER (incremental test strategy):
%   Step 1 — Electrical backbone:   DC bus + averaged VSI + LC filter + grid
%   Step 2 — Measurements:          3-phase V/I sensors → dq transform
%   Step 3 — Swing equation:        J*dω/dt block (reuse Phase 1 subsystem)
%   Step 4 — Voltage reference:     E, theta → v_abc* (inverse Park)
%   Step 5 — Current PI loop:       dq error → duty cycle → VSI
%   Step 6 — PLL:                   grid-synchronisation for fault tests
%   Step 7 — Load step test:        connect ideal load at PCC, step power
%
% SIMSCAPE ELECTRICAL BLOCK PATHS USED (R2026a verified names):
%   ee_lib/Connectors & References/Electrical Reference
%   ee_lib/Sources/Controlled Voltage Source   (3-phase averaged inverter output)
%   ee_lib/Passive/Inductor
%   ee_lib/Passive/Capacitor
%   ee_lib/Passive/Resistor
%   ee_lib/Sources/Voltage Source              (stiff grid)
%   ee_lib/Sensors/Voltage Sensor
%   ee_lib/Sensors/Current Sensor
%   ee_lib/Utilities/PS-Simulink Converter
%   ee_lib/Utilities/Simulink-PS Converter
%   ee_lib/Connectors & References/Solver Configuration   (REPLACES Powergui)
%
%   Simscape/Utilities/Solver Configuration   (alternative path if ee_lib path fails)
%
%   Standard Simulink (control path only):
%   simulink/Math Operations/Gain
%   simulink/Math Operations/Sum
%   simulink/Continuous/Integrator
%   simulink/Continuous/Transfer Fcn
%   simulink/Sources/Constant
%   simulink/Sinks/Scope
%   simulink/Sinks/To Workspace
%   simulink/Signal Routing/Mux
%   simulink/Signal Routing/Demux
%   simulink/Math Operations/Trigonometric Function
%   simulink/Math Operations/Product
%
% IMPORTANT NOTES:
%   1. "Solver Configuration" block (ee_lib) REPLACES Powergui.
%      Without it, Simscape networks will not simulate. One per connected network.
%   2. The "Three-Phase Source" SPS block does NOT exist in R2026a ee_lib.
%      Stiff grid = three Voltage Source blocks wired with 120-deg phase offsets,
%      or one "Controlled Voltage Source" set to a fixed sinusoidal signal.
%   3. "Three-Phase Series RLC Branch" SPS block: use individual Resistor +
%      Inductor + Capacitor blocks from ee_lib/Passive/ instead.
%   4. Average VSI model: use three "Controlled Voltage Source" blocks (one
%      per phase), each driven by the PWM duty cycle * V_dc signal from
%      the control path via Simulink-PS Converter.
%   5. All Simscape connections use physical ports (thick lines in editor).
%      Signal ports (thin lines) are only on the control path.
%      PS-Simulink and Simulink-PS Converter blocks bridge the two domains.
%
% Author : Napoleon (Chinnawat Dumklang), SUT EE Year 3
% Date   : 2026-05-13
% MATLAB  : R2026a, Simscape + Simscape Electrical required

%% =========================================================================
%  0. LOAD PARAMETERS
%% =========================================================================

script_dir = fileparts(mfilename('fullpath'));
run(fullfile(script_dir, 'vsg_simscape_params.m'));

model_name = 'vsg_simscape_10kva';

if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

model_path = fullfile(script_dir, 'models', [model_name '.slx']);

%% =========================================================================
%  1. CREATE MODEL
%% =========================================================================

new_system(model_name);
open_system(model_name);
set_param(model_name, 'Location', [50 50 1800 900]);

% ---- Solver configuration (critical for Simscape) ------------------------
% Use ode23t: suitable for stiff power-electronic networks, handles
% discontinuities from switching / saturation well.
% MinStep 'auto' lets the Simscape local solver sub-step inside Ts_sim.
set_param(model_name, ...
    'Solver',          'ode23t',       ...
    'StopTime',        num2str(T_end), ...
    'MaxStep',         num2str(Ts_sim * 10),  ... % = 10 µs global max step
    'RelTol',          '1e-4',         ...  % Looser than pure-signal models
    'AbsTol',          '1e-6',         ...
    'ZeroCrossControl','UseLocalSettings');

%% =========================================================================
%  LAYOUT CONSTANTS
%  The model is organised in horizontal bands (rows):
%   Row A (y=80):   Stiff grid sources
%   Row B (y=220):  Grid impedance RL
%   Row C (y=360):  LC filter (capacitor bank)
%   Row D (y=500):  Averaged VSI outputs (controlled voltage sources)
%   Row E (y=700):  DC bus + measurements
%   Row F (y=900):  Control subsystems (pure Simulink)
%
%  NOTE: In Simscape, 3-phase connections use three separate single-phase
%  nodes (a, b, c). This script wires all three phases explicitly.
%  Positions are approximate — use Simulink auto-layout to clean up.
%% =========================================================================

% Helper
pos = @(cx, cy, bw, bh) [cx-bw, cy-bh, cx+bw, cy+bh];
W = 40; H = 25;   % standard half-width / half-height for passive elements

%% =========================================================================
%  2. ADD SOLVER CONFIGURATION BLOCK
%  Must exist in the model for any Simscape physical network to simulate.
%  Path: simscape/Utilities/Solver Configuration
%  (In R2026a the block may also appear as ee_lib Solver Configuration —
%  the simscape path is always safe as a fallback.)
%% =========================================================================

add_block('nesl_utility/Solver Configuration', [model_name '/SolverConfig']);
set_param([model_name '/SolverConfig'], ...
    'UseLocalSolver',  'off',    ...   % Global ode23t handles stepping
    'DoFixedCost',     'off',    ...
    'Position',        [20 20 160 60]);

% Solver Configuration needs a Simscape network connection.
% Connect it to the Electrical Reference (ground) node below.

%% =========================================================================
%  3. ELECTRICAL REFERENCE (GROUND)
%  ee_lib path: ee_lib/Connectors & References/Electrical Reference
%  Provides the circuit ground for the Simscape network.
%% =========================================================================

% Three ground nodes: one per phase grouping, plus DC ground
for ph = {'A','B','C','DC'}
    bname = ['Gnd_' ph{1}];
    add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
              [model_name '/' bname]);
    % Position them at bottom of canvas
    col = find(strcmp({'A','B','C','DC'}, ph{1}));
    set_param([model_name '/' bname], 'Position', ...
        pos(150 + (col-1)*300, 820, W, H));
end

%% =========================================================================
%  4. STIFF GRID (INFINITE BUS)
%  SPS "Three-Phase Source" does NOT exist in Simscape Electrical R2026a.
%  Replacement: three Voltage Source blocks from ee_lib, one per phase.
%  Block path: ee_lib/Sources/Voltage Source
%  Each source is a sinusoidal voltage with 120-degree phase offset.
%
%  The Voltage Source block in ee_lib takes a physical signal input (PS port)
%  for the voltage waveform, connected via Simulink-PS Converter.
%  Alternatively, set the block to "Sinusoidal" mode directly in parameters.
%
%  VERIFIED R2026a block: "ee_lib/Sources/AC Voltage Source"
%  This block has a built-in sinusoidal generator and avoids needing
%  an external signal — use it instead of the generic Voltage Source.
%  Parameters: Peak Amplitude (V), Phase Shift (deg), Frequency (Hz)
%% =========================================================================

grid_phases = {
    'Grid_A',   0;      % Phase A:   0 degrees
    'Grid_B', -120;     % Phase B: -120 degrees
    'Grid_C',  120;     % Phase C: +120 degrees (positive sequence)
};

for k = 1:size(grid_phases, 1)
    bname = grid_phases{k,1};
    phase_deg = grid_phases{k,2};
    add_block('ee_lib/Sources/AC Voltage Source', [model_name '/' bname]);
    set_param([model_name '/' bname], ...
        'Vp',       num2str(V_pk),        ...   % Peak amplitude (V) = 326.6 V
        'Phase',    num2str(phase_deg),   ...   % Phase shift (deg)
        'Frequency', num2str(f_0),        ...   % Frequency (Hz)
        'Position', pos(1400, 80 + (k-1)*160, W, H));
end

%% =========================================================================
%  5. GRID IMPEDANCE (RL, series, one per phase)
%  No "Three-Phase Series RLC Branch" in ee_lib.
%  Use individual Resistor + Inductor blocks per phase.
%  Block paths:
%    ee_lib/Passive/Resistor
%    ee_lib/Passive/Inductor
%% =========================================================================

for ph = {'A','B','C'}
    p = ph{1};
    % Resistor
    rname = ['Rg_' p];
    add_block('ee_lib/Passive/Resistor', [model_name '/' rname]);
    set_param([model_name '/' rname], ...
        'R',        num2str(R_g), ...
        'Position', pos(1200, 80 + (strcmp(p,'A')*0 + strcmp(p,'B')*160 + strcmp(p,'C')*320), W, H));

    % Inductor
    lname = ['Lg_' p];
    add_block('ee_lib/Passive/Inductor', [model_name '/' lname]);
    set_param([model_name '/' lname], ...
        'L',        num2str(L_g), ...
        'Position', pos(1050, 80 + (strcmp(p,'A')*0 + strcmp(p,'B')*160 + strcmp(p,'C')*320), W, H));
end

%% =========================================================================
%  6. LC OUTPUT FILTER
%  L-branch (series) + C-branch (shunt to ground) per phase.
%  Optional parallel damping resistor R_damp across each capacitor.
%  Block paths: ee_lib/Passive/Inductor, Capacitor, Resistor (same as above)
%% =========================================================================

for ph = {'A','B','C'}
    p = ph{1};
    row_y = 80 + (strcmp(p,'A')*0 + strcmp(p,'B')*160 + strcmp(p,'C')*320);

    % Series filter inductor
    add_block('ee_lib/Passive/Inductor', [model_name '/Lf_' p]);
    set_param([model_name '/Lf_' p], ...
        'L',        num2str(L_f), ...
        'Position', pos(750, row_y, W, H));

    % Filter series resistance (winding resistance)
    add_block('ee_lib/Passive/Resistor', [model_name '/Rf_' p]);
    set_param([model_name '/Rf_' p], ...
        'R',        num2str(R_f), ...
        'Position', pos(600, row_y, W, H));

    % Shunt filter capacitor (to neutral/ground)
    add_block('ee_lib/Passive/Capacitor', [model_name '/Cf_' p]);
    set_param([model_name '/Cf_' p], ...
        'C',        num2str(C_f), ...
        'Position', pos(900, row_y + 100, W, H));

    % Parallel damping resistor across Cf (reduces resonance peak)
    add_block('ee_lib/Passive/Resistor', [model_name '/Rdamp_' p]);
    set_param([model_name '/Rdamp_' p], ...
        'R',        num2str(R_damp), ...
        'Position', pos(900, row_y + 170, W, H));
end

%% =========================================================================
%  7. AVERAGED VOLTAGE SOURCE INVERTER (VSI)
%  The averaged VSI model replaces the switched VSI for control development.
%  Implementation: three Controlled Voltage Sources (one per phase).
%  The control path sends v_abc_ref (three scalar signals); these are
%  converted to physical signals via Simulink-PS Converter blocks.
%
%  Block: ee_lib/Sources/Controlled Voltage Source
%  This block has:
%    + terminal (positive)
%    - terminal (negative, connects to DC midpoint or ground)
%    PS input port: receives the physical signal for instantaneous voltage
%
%  The DC midpoint of the H-bridge is the negative terminal.
%  For a 3-phase 2-level VSI: v_phase = (duty_cycle - 0.5) * V_dc
%  In averaged model: v_phase_ref comes directly from the control law.
%% =========================================================================

for ph = {'A','B','C'}
    p = ph{1};
    row_y = 80 + (strcmp(p,'A')*0 + strcmp(p,'B')*160 + strcmp(p,'C')*320);

    % Controlled Voltage Source (averaged VSI phase leg)
    vsi_name = ['VSI_' p];
    add_block('ee_lib/Sources/Controlled Voltage Source', [model_name '/' vsi_name]);
    set_param([model_name '/' vsi_name], ...
        'Position', pos(400, row_y, W+10, H+5));

    % Simulink-PS Converter: bridges control signal → physical signal port
    conv_name = ['SL2PS_' p];
    add_block('nesl_utility/Simulink-PS Converter', [model_name '/' conv_name]);
    set_param([model_name '/' conv_name], ...
        'Position', pos(280, row_y, W, H));
end

%% =========================================================================
%  8. DC BUS VOLTAGE SOURCE
%  Represents a stiff DC bus (battery, rectifier, or PV source).
%  Block: ee_lib/Sources/DC Voltage Source
%  In the averaged model this simply fixes V_dc; no dynamics.
%% =========================================================================

add_block('ee_lib/Sources/DC Voltage Source', [model_name '/VDC']);
set_param([model_name '/VDC'], ...
    'v',        num2str(V_dc), ...
    'Position', pos(200, 650, W+10, H+5));

%% =========================================================================
%  9. VOLTAGE AND CURRENT SENSORS (PCC measurement)
%  Sensors are placed at the Point of Common Coupling (PCC):
%  between the LC filter and the grid impedance.
%
%  Block paths:
%    ee_lib/Sensors/Voltage Sensor
%    ee_lib/Sensors/Current Sensor
%
%  Each sensor has:
%    + and - electrical ports (in series for current, parallel for voltage)
%    PS output port → PS-Simulink Converter → Simulink signal
%% =========================================================================

% Voltage sensors at PCC (measure phase voltage to ground)
for ph = {'A','B','C'}
    p = ph{1};
    row_y = 80 + (strcmp(p,'A')*0 + strcmp(p,'B')*160 + strcmp(p,'C')*320);

    vs_name = ['Vsens_' p];
    add_block('ee_lib/Sensors/Voltage Sensor', [model_name '/' vs_name]);
    set_param([model_name '/' vs_name], ...
        'Position', pos(960, row_y + 60, W, H));

    % PS-Simulink converter for voltage measurement
    add_block('nesl_utility/PS-Simulink Converter', [model_name '/PS2SL_V' p]);
    set_param([model_name '/PS2SL_V' p], ...
        'Position', pos(960, row_y + 120, W, H));

    % Current sensors (series in line)
    cs_name = ['Isens_' p];
    add_block('ee_lib/Sensors/Current Sensor', [model_name '/' cs_name]);
    set_param([model_name '/' cs_name], ...
        'Position', pos(850, row_y, W, H));

    add_block('nesl_utility/PS-Simulink Converter', [model_name '/PS2SL_I' p]);
    set_param([model_name '/PS2SL_I' p], ...
        'Position', pos(850, row_y + 80, W, H));
end

%% =========================================================================
%  10. SWING EQUATION SUBSYSTEM  (pure Simulink)
%  Implements: J * dω/dt = P_m - P_e - D_p*(ω - ω_0)
%  Inputs:  P_m (reference mechanical power, W)
%           P_e (measured electrical power, W)  — from PCC V/I
%  Outputs: omega (rad/s), theta (rad) = integral of omega
%
%  This subsystem is built as an Atomic Subsystem so it can be reused
%  or replaced by a state-space representation later.
%% =========================================================================

% Create subsystem as a container
add_block('simulink/Ports & Subsystems/Atomic Subsystem', ...
    [model_name '/VSG_SwingEq']);
set_param([model_name '/VSG_SwingEq'], 'Position', pos(500, 780, 80, 40));

% Delete the default In1/Out1 ports inside the subsystem
se_path = [model_name '/VSG_SwingEq'];

% Add inports to the subsystem
add_block('simulink/Ports & Subsystems/In1', [se_path '/Pm_in']);
set_param([se_path '/Pm_in'],  'Port', '1', 'Position', pos(60, 180, 20, 15));

add_block('simulink/Ports & Subsystems/In1', [se_path '/Pe_in']);
set_param([se_path '/Pe_in'],  'Port', '2', 'Position', pos(60, 280, 20, 15));

% Swing equation components inside the subsystem:
%   Net power: Sum1 = P_m - P_e
add_block('simulink/Math Operations/Sum', [se_path '/Sum_net']);
set_param([se_path '/Sum_net'], 'Inputs', '+-', 'Position', pos(200, 230, 20, 20));

%   Damping subtraction: Sum2 = (P_m - P_e) - D_p*(ω - ω_0)
add_block('simulink/Math Operations/Sum', [se_path '/Sum_swing']);
set_param([se_path '/Sum_swing'], 'Inputs', '+-', 'Position', pos(350, 230, 20, 20));

%   Inertia gain: 1/J => dω/dt
add_block('simulink/Math Operations/Gain', [se_path '/Gain_J']);
set_param([se_path '/Gain_J'], 'Gain', num2str(1/J), 'Position', pos(480, 230, 30, 18));

%   Integrator 1: dω/dt → ω(t), IC = ω_0
add_block('simulink/Continuous/Integrator', [se_path '/Int_omega']);
set_param([se_path '/Int_omega'], ...
    'InitialCondition', num2str(omega_0), ...
    'Position', pos(620, 230, 30, 18));

%   ω_0 constant (nominal frequency)
add_block('simulink/Sources/Constant', [se_path '/omega_0']);
set_param([se_path '/omega_0'], 'Value', num2str(omega_0), 'Position', pos(480, 340, 35, 15));

%   Speed deviation: ω - ω_0
add_block('simulink/Math Operations/Sum', [se_path '/Sum_dev']);
set_param([se_path '/Sum_dev'], 'Inputs', '+-', 'Position', pos(750, 230, 20, 20));

%   Damping gain: D_p * (ω - ω_0)
add_block('simulink/Math Operations/Gain', [se_path '/Gain_D']);
set_param([se_path '/Gain_D'], 'Gain', num2str(D_p), 'Position', pos(620, 340, 30, 18));

%   Integrator 2: (ω - ω_0) → θ(t), IC = 0 (aligned with grid at t=0)
add_block('simulink/Continuous/Integrator', [se_path '/Int_theta']);
set_param([se_path '/Int_theta'], ...
    'InitialCondition', '0', ...
    'Position', pos(880, 230, 30, 18));

%   Outports: omega and theta
add_block('simulink/Ports & Subsystems/Out1', [se_path '/omega_out']);
set_param([se_path '/omega_out'], 'Port', '1', 'Position', pos(1000, 180, 20, 15));

add_block('simulink/Ports & Subsystems/Out1', [se_path '/theta_out']);
set_param([se_path '/theta_out'], 'Port', '2', 'Position', pos(1000, 280, 20, 15));

% Connect inside swing equation subsystem:
add_line(se_path, 'Pm_in/1',    'Sum_net/1',    'autorouting','on');
add_line(se_path, 'Pe_in/1',    'Sum_net/2',    'autorouting','on');
add_line(se_path, 'Sum_net/1',  'Sum_swing/1',  'autorouting','on');
add_line(se_path, 'Sum_swing/1','Gain_J/1',     'autorouting','on');
add_line(se_path, 'Gain_J/1',   'Int_omega/1',  'autorouting','on');
add_line(se_path, 'Int_omega/1','Sum_dev/1',    'autorouting','on');
add_line(se_path, 'omega_0/1',  'Sum_dev/2',    'autorouting','on');
add_line(se_path, 'Sum_dev/1',  'Gain_D/1',     'autorouting','on');
add_line(se_path, 'Gain_D/1',   'Sum_swing/2',  'autorouting','on');
add_line(se_path, 'Sum_dev/1',  'Int_theta/1',  'autorouting','on');
add_line(se_path, 'Int_omega/1','omega_out/1',  'autorouting','on');
add_line(se_path, 'Int_theta/1','theta_out/1',  'autorouting','on');

%% =========================================================================
%  11. VOLTAGE REFERENCE GENERATOR  (pure Simulink subsystem)
%  Converts E_ref (magnitude) and theta (angle) into 3-phase voltage
%  references v_a*, v_b*, v_c* for the averaged VSI.
%
%  v_a* = E_ref * sqrt(2) * sin(theta)
%  v_b* = E_ref * sqrt(2) * sin(theta - 2π/3)
%  v_c* = E_ref * sqrt(2) * sin(theta + 2π/3)
%
%  This is the open-loop voltage mode reference. The inner current PI loop
%  (Step 5 in the build order) will later replace E_ref*sin(theta) with a
%  closed-loop duty cycle. For the initial electrical test, this direct
%  reference is used to verify synchronisation with the grid.
%% =========================================================================

add_block('simulink/Ports & Subsystems/Atomic Subsystem', ...
    [model_name '/VoltageRef']);
set_param([model_name '/VoltageRef'], 'Position', pos(350, 780, 80, 40));

vr_path = [model_name '/VoltageRef'];

% Inports
add_block('simulink/Ports & Subsystems/In1', [vr_path '/Eref_in']);
set_param([vr_path '/Eref_in'], 'Port', '1', 'Position', pos(60, 200, 20, 15));

add_block('simulink/Ports & Subsystems/In1', [vr_path '/theta_in']);
set_param([vr_path '/theta_in'], 'Port', '2', 'Position', pos(60, 280, 20, 15));

% sqrt(2) gain converts RMS E_ref to peak
add_block('simulink/Math Operations/Gain', [vr_path '/Gain_sqrt2']);
set_param([vr_path '/Gain_sqrt2'], 'Gain', 'sqrt(2)', 'Position', pos(200, 200, 30, 18));

% Phase offsets for B and C
add_block('simulink/Sources/Constant', [vr_path '/offset_B']);
set_param([vr_path '/offset_B'], 'Value', num2str(-2*pi/3), 'Position', pos(200, 350, 35, 15));

add_block('simulink/Sources/Constant', [vr_path '/offset_C']);
set_param([vr_path '/offset_C'], 'Value', num2str(2*pi/3),  'Position', pos(200, 420, 35, 15));

% Sum blocks for theta + offset
add_block('simulink/Math Operations/Sum', [vr_path '/Sum_thetaB']);
set_param([vr_path '/Sum_thetaB'], 'Inputs', '++', 'Position', pos(350, 350, 20, 20));

add_block('simulink/Math Operations/Sum', [vr_path '/Sum_thetaC']);
set_param([vr_path '/Sum_thetaC'], 'Inputs', '++', 'Position', pos(350, 420, 20, 20));

% sin blocks
add_block('simulink/Math Operations/Trigonometric Function', [vr_path '/sinA']);
set_param([vr_path '/sinA'], 'Operator', 'sin', 'Position', pos(350, 250, 30, 18));

add_block('simulink/Math Operations/Trigonometric Function', [vr_path '/sinB']);
set_param([vr_path '/sinB'], 'Operator', 'sin', 'Position', pos(500, 350, 30, 18));

add_block('simulink/Math Operations/Trigonometric Function', [vr_path '/sinC']);
set_param([vr_path '/sinC'], 'Operator', 'sin', 'Position', pos(500, 420, 30, 18));

% Product: E_pk * sin(theta+offset) for each phase
for ph = {'A','B','C'}
    p = ph{1};
    add_block('simulink/Math Operations/Product', [vr_path '/Prod_' p]);
    set_param([vr_path '/Prod_' p], 'Position', ...
        pos(640, 250+(strcmp(p,'B')*100)+(strcmp(p,'C')*170), 30, 18));
end

% Outports
for k = 1:3
    ph_label = {'A','B','C'};
    add_block('simulink/Ports & Subsystems/Out1', [vr_path '/vref_' ph_label{k}]);
    set_param([vr_path '/vref_' ph_label{k}], 'Port', num2str(k), ...
        'Position', pos(780, 250+(k-1)*90, 20, 15));
end

% Connect VoltageRef subsystem internals
add_line(vr_path, 'Eref_in/1',   'Gain_sqrt2/1', 'autorouting','on');
add_line(vr_path, 'theta_in/1',  'sinA/1',        'autorouting','on');
add_line(vr_path, 'theta_in/1',  'Sum_thetaB/1',  'autorouting','on');
add_line(vr_path, 'theta_in/1',  'Sum_thetaC/1',  'autorouting','on');
add_line(vr_path, 'offset_B/1',  'Sum_thetaB/2',  'autorouting','on');
add_line(vr_path, 'offset_C/1',  'Sum_thetaC/2',  'autorouting','on');
add_line(vr_path, 'Sum_thetaB/1','sinB/1',         'autorouting','on');
add_line(vr_path, 'Sum_thetaC/1','sinC/1',         'autorouting','on');
add_line(vr_path, 'Gain_sqrt2/1','Prod_A/1',       'autorouting','on');
add_line(vr_path, 'Gain_sqrt2/1','Prod_B/1',       'autorouting','on');
add_line(vr_path, 'Gain_sqrt2/1','Prod_C/1',       'autorouting','on');
add_line(vr_path, 'sinA/1',      'Prod_A/2',       'autorouting','on');
add_line(vr_path, 'sinB/1',      'Prod_B/2',       'autorouting','on');
add_line(vr_path, 'sinC/1',      'Prod_C/2',       'autorouting','on');
add_line(vr_path, 'Prod_A/1',    'vref_A/1',       'autorouting','on');
add_line(vr_path, 'Prod_B/1',    'vref_B/1',       'autorouting','on');
add_line(vr_path, 'Prod_C/1',    'vref_C/1',       'autorouting','on');

%% =========================================================================
%  12. INNER CURRENT CONTROL SUBSYSTEM  (pure Simulink, PI in dq frame)
%  This subsystem is a PLACEHOLDER for Phase 2 of the control build.
%  In Phase 1 (open-loop voltage mode), bypass this and route VoltageRef
%  outputs directly to the Simulink-PS Converters at the VSI inputs.
%
%  Full PI current controller architecture (for reference):
%    Inputs:  i_d, i_q (measured dq currents from Park transform)
%             i_d_ref, i_q_ref (reference dq currents from power controller)
%             omega (from swing eq., for decoupling)
%    Outputs: v_d*, v_q* (duty cycle voltage references in dq)
%
%  PI equations:
%    v_d* = Kp_i*(i_d_ref - i_d) + Ki_i*integral(i_d_ref - i_d) - omega*L_total*i_q
%    v_q* = Kp_i*(i_q_ref - i_q) + Ki_i*integral(i_q_ref - i_q) + omega*L_total*i_d
%
%  After PI, inverse Park transform: v_dq* -> v_abc* -> VSI
%  Anti-windup: use back-calculation (Kb = 1/Kp_i) to prevent integrator
%  saturation when VSI output is limited by V_dc/2.
%% =========================================================================

% For now, create a Unity-gain pass-through subsystem labelled CurrentPI
% so the model structure is complete and Phase 1 tests can run.
add_block('simulink/Ports & Subsystems/Atomic Subsystem', ...
    [model_name '/CurrentPI']);
set_param([model_name '/CurrentPI'], 'Position', pos(200, 780, 80, 40));

cp_path = [model_name '/CurrentPI'];
add_block('simulink/Ports & Subsystems/In1', [cp_path '/vref_A_in']);
set_param([cp_path '/vref_A_in'], 'Port', '1', 'Position', pos(60, 200, 20, 15));
add_block('simulink/Ports & Subsystems/In1', [cp_path '/vref_B_in']);
set_param([cp_path '/vref_B_in'], 'Port', '2', 'Position', pos(60, 280, 20, 15));
add_block('simulink/Ports & Subsystems/In1', [cp_path '/vref_C_in']);
set_param([cp_path '/vref_C_in'], 'Port', '3', 'Position', pos(60, 360, 20, 15));

add_block('simulink/Ports & Subsystems/Out1', [cp_path '/vref_A_out']);
set_param([cp_path '/vref_A_out'], 'Port', '1', 'Position', pos(280, 200, 20, 15));
add_block('simulink/Ports & Subsystems/Out1', [cp_path '/vref_B_out']);
set_param([cp_path '/vref_B_out'], 'Port', '2', 'Position', pos(280, 280, 20, 15));
add_block('simulink/Ports & Subsystems/Out1', [cp_path '/vref_C_out']);
set_param([cp_path '/vref_C_out'], 'Port', '3', 'Position', pos(280, 360, 20, 15));

% Pass-through: direct wire input → output (unity gain, no control yet)
add_line(cp_path, 'vref_A_in/1', 'vref_A_out/1', 'autorouting','on');
add_line(cp_path, 'vref_B_in/1', 'vref_B_out/1', 'autorouting','on');
add_line(cp_path, 'vref_C_in/1', 'vref_C_out/1', 'autorouting','on');

%% =========================================================================
%  13. TOP-LEVEL CONTROL SIGNAL SOURCES
%  P_m reference (step disturbance for inertia test)
%  E_ref (reactive power / voltage reference — constant for Phase 1)
%% =========================================================================

% P_m step: starts at S_base * 0.5 (50% load), steps to 70% at t=1s
add_block('simulink/Sources/Step', [model_name '/Pm_ref']);
set_param([model_name '/Pm_ref'], ...
    'Time',   '1', ...
    'Before', num2str(S_base * 0.5), ...
    'After',  num2str(S_base * 0.7), ...
    'Position', pos(80, 720, 30, 18));

% E_ref constant
add_block('simulink/Sources/Constant', [model_name '/Eref']);
set_param([model_name '/Eref'], ...
    'Value',    num2str(V_phase), ...
    'Position', pos(80, 780, 30, 18));

% P_e measurement feedback — use a Constant (0) as placeholder for Phase 1
% (Phase 2 replaces this with computed 3-phase instantaneous power from sensors)
add_block('simulink/Sources/Constant', [model_name '/Pe_meas']);
set_param([model_name '/Pe_meas'], ...
    'Value',    num2str(S_base * 0.5), ...   % Matched to initial Pm so dω/dt = 0
    'Position', pos(80, 840, 30, 18));

%% =========================================================================
%  14. SCOPE AND TO-WORKSPACE LOGGING
%% =========================================================================

add_block('simulink/Sinks/Scope', [model_name '/Scope_Vabc']);
set_param([model_name '/Scope_Vabc'], 'NumInputPorts', '3', 'Position', pos(1600, 780, 40, 25));

add_block('simulink/Sinks/Scope', [model_name '/Scope_omega']);
set_param([model_name '/Scope_omega'], 'NumInputPorts', '1', 'Position', pos(1600, 840, 40, 25));

% To Workspace for post-processing
add_block('simulink/Sinks/To Workspace', [model_name '/ToWS_omega']);
set_param([model_name '/ToWS_omega'], ...
    'VariableName', 'omega_simscape', ...
    'SaveFormat',   'timeseries', ...
    'Position', pos(1600, 900, 40, 18));

%% =========================================================================
%  15. TOP-LEVEL SIGNAL ROUTING
%  Wire the control subsystems together and connect Simulink signals to
%  the Simulink-PS Converters driving the VSI.
%% =========================================================================

% Swing equation: P_m → port 1,  P_e_meas → port 2
add_line(model_name, 'Pm_ref/1',   'VSG_SwingEq/1', 'autorouting','on');
add_line(model_name, 'Pe_meas/1',  'VSG_SwingEq/2', 'autorouting','on');

% VoltageRef: E_ref → port 1,  theta (from SwingEq port 2) → port 2
add_line(model_name, 'Eref/1',         'VoltageRef/1',  'autorouting','on');
add_line(model_name, 'VSG_SwingEq/2',  'VoltageRef/2',  'autorouting','on');

% CurrentPI (pass-through): VoltageRef outputs → CurrentPI inputs
add_line(model_name, 'VoltageRef/1',   'CurrentPI/1',   'autorouting','on');
add_line(model_name, 'VoltageRef/2',   'CurrentPI/2',   'autorouting','on');
add_line(model_name, 'VoltageRef/3',   'CurrentPI/3',   'autorouting','on');

% CurrentPI outputs → Simulink-PS Converters (enter Simscape domain)
add_line(model_name, 'CurrentPI/1',  'SL2PS_A/1',  'autorouting','on');
add_line(model_name, 'CurrentPI/2',  'SL2PS_B/1',  'autorouting','on');
add_line(model_name, 'CurrentPI/3',  'SL2PS_C/1',  'autorouting','on');

% omega → Scope_omega + ToWS
add_line(model_name, 'VSG_SwingEq/1', 'Scope_omega/1', 'autorouting','on');
add_line(model_name, 'VSG_SwingEq/1', 'ToWS_omega/1',  'autorouting','on');

%% =========================================================================
%  16. SIMSCAPE PHYSICAL CONNECTIONS
%  IMPORTANT: Physical (thick) connections must be made using add_line with
%  Simscape port naming conventions.
%  Port naming for ee_lib blocks:
%    Voltage Source:        LConn1 (+), RConn1 (-)
%    Resistor:              LConn1, RConn1
%    Inductor:              LConn1, RConn1
%    Capacitor:             LConn1, RConn1
%    Controlled Voltage Source: LConn1 (+), RConn1 (-), LConn2 (PS signal in)
%    Current Sensor:        LConn1, RConn1 (+/-), RConn2 (PS signal out)
%    Voltage Sensor:        LConn1 (+), LConn2 (-), RConn1 (PS signal out)
%    Electrical Reference:  LConn1
%
%  These names are standard across Simscape Electrical R2020b+. Verify
%  exact port labels in R2026a using: get_param(block,'PortHandles')
%
%  NOTE: Full physical wiring for a 3-phase system is verbose.
%  The wiring below follows the signal chain for Phase A.
%  Phases B and C follow an identical pattern.
%% =========================================================================

% Phase A signal chain (physical Simscape connections):
% SL2PS_A (PS out) → VSI_A (LConn2 PS input)
% VSI_A (LConn1 +) → Rf_A (LConn1)
% Rf_A (RConn1) → Lf_A (LConn1)
% Lf_A (RConn1) → node_PCC_A
%   node_PCC_A → Isens_A (LConn1)  [series current sensor]
%   node_PCC_A → Cf_A (LConn1)     [shunt capacitor tap]
% Isens_A (RConn1) → Lg_A (LConn1)
% Lg_A (RConn1) → Rg_A (LConn1)
% Rg_A (RConn1) → Grid_A (LConn1 +)
% Grid_A (RConn1 -) → Gnd_A (LConn1)
% VSI_A (RConn1 -) → DC negative → VDC (-) → Gnd_DC (LConn1)
% Cf_A (RConn1) → Gnd_A (LConn1)  [capacitor to ground]
% Vsens_A (LConn1) ← node_PCC_A, (LConn2) → Gnd_A
%
% Physical signal (PS) connections:
% SL2PS_A (RConn1) → VSI_A (LConn2)
% Isens_A (RConn2) → PS2SL_IA (LConn1)
% Vsens_A (RConn1) → PS2SL_VA (LConn1)
%
% The Simulink outputs of PS2SL_VA and PS2SL_IA are scalar signals
% representing instantaneous phase voltage and current.

for ph = {'A','B','C'}
    p = ph{1};

    % PS signal path: SL2PS → VSI controlled input
    add_line(model_name, ['SL2PS_' p '/RConn1'],  ['VSI_' p '/LConn2'], 'autorouting','on');

    % Physical chain: VSI+ → Rf → Lf → [PCC junction] → Isens → Lg → Rg → Grid+
    add_line(model_name, ['VSI_' p '/LConn1'],   ['Rf_' p '/LConn1'],  'autorouting','on');
    add_line(model_name, ['Rf_' p '/RConn1'],    ['Lf_' p '/LConn1'],  'autorouting','on');
    add_line(model_name, ['Lf_' p '/RConn1'],    ['Isens_' p '/LConn1'], 'autorouting','on');
    add_line(model_name, ['Isens_' p '/RConn1'], ['Lg_' p '/LConn1'],  'autorouting','on');
    add_line(model_name, ['Lg_' p '/RConn1'],    ['Rg_' p '/LConn1'],  'autorouting','on');
    add_line(model_name, ['Rg_' p '/RConn1'],    ['Grid_' p '/LConn1'],'autorouting','on');

    % Grid return path: Grid- → Gnd
    add_line(model_name, ['Grid_' p '/RConn1'],  ['Gnd_' p '/LConn1'], 'autorouting','on');

    % Shunt capacitor: PCC → Cf → Gnd
    add_line(model_name, ['Lf_' p '/RConn1'],    ['Cf_' p '/LConn1'],  'autorouting','on');
    add_line(model_name, ['Cf_' p '/RConn1'],    ['Gnd_' p '/LConn1'], 'autorouting','on');

    % Damping resistor across Cf (parallel with Cf)
    add_line(model_name, ['Lf_' p '/RConn1'],    ['Rdamp_' p '/LConn1'], 'autorouting','on');
    add_line(model_name, ['Rdamp_' p '/RConn1'], ['Gnd_' p '/LConn1'],   'autorouting','on');

    % VSI negative terminal → common DC negative (Gnd_DC)
    add_line(model_name, ['VSI_' p '/RConn1'],   'Gnd_DC/LConn1',      'autorouting','on');

    % Voltage sensor at PCC (parallel, + to PCC node, - to Gnd)
    add_line(model_name, ['Lf_' p '/RConn1'],    ['Vsens_' p '/LConn1'], 'autorouting','on');
    add_line(model_name, ['Gnd_' p '/LConn1'],   ['Vsens_' p '/LConn2'], 'autorouting','on');

    % PS outputs of sensors → PS-Simulink converters
    add_line(model_name, ['Vsens_' p '/RConn1'],  ['PS2SL_V' p '/LConn1'], 'autorouting','on');
    add_line(model_name, ['Isens_' p '/RConn2'],  ['PS2SL_I' p '/LConn1'], 'autorouting','on');

    % PS-Simulink outputs → Scope_Vabc
end

% Connect PS2SL_VA outputs to Scope (one port per phase)
add_line(model_name, 'PS2SL_VA/1',  'Scope_Vabc/1', 'autorouting','on');
add_line(model_name, 'PS2SL_VB/1',  'Scope_Vabc/2', 'autorouting','on');
add_line(model_name, 'PS2SL_VC/1',  'Scope_Vabc/3', 'autorouting','on');

% DC bus
add_line(model_name, 'VDC/LConn1',  'Gnd_DC/LConn1', 'autorouting','on');

% Solver Configuration → must connect to a Simscape node.
% Connect to Gnd_A (any node in the network works; it carries no current).
add_line(model_name, 'SolverConfig/RConn1', 'Gnd_A/LConn1', 'autorouting','on');

%% =========================================================================
%  17. SAVE MODEL
%% =========================================================================

save_system(model_name, model_path);
fprintf('[VSG Simscape] Model saved to: %s\n', model_path);

%% =========================================================================
%  18. PRINT BUILD COMPLETE + NEXT STEPS
%% =========================================================================

fprintf('\n===== VSG Simscape Build Complete =====\n');
fprintf('Model: %s\n', model_path);
fprintf('\nBUILD STATUS:\n');
fprintf('  [x] Step 1: DC bus + averaged VSI + LC filter + grid (electrical backbone)\n');
fprintf('  [x] Step 2: V/I sensors at PCC (PS-Simulink interface)\n');
fprintf('  [x] Step 3: Swing equation subsystem (VSG_SwingEq)\n');
fprintf('  [x] Step 4: Voltage reference generator (VoltageRef)\n');
fprintf('  [x] Step 5: Current PI loop (CurrentPI — pass-through, Phase 1 only)\n');
fprintf('  [ ] Step 6: PLL for grid synchronisation (TODO: Phase 2)\n');
fprintf('  [ ] Step 7: Load step / grid fault test (TODO: Phase 3)\n');
fprintf('\nNEXT ACTIONS:\n');
fprintf('  1. Open model in Simulink: open_system(''%s'')\n', model_path);
fprintf('  2. Run Diagnostic > Update Model (Ctrl+D) to check for unconnected ports\n');
fprintf('  3. Use "Arrange All" (right-click canvas) to clean up block layout\n');
fprintf('  4. Run simulation: sim(''%s'') — check Scope_omega for ω(t)\n', model_name);
fprintf('  5. Verify V_pcc waveform (Scope_Vabc) is sinusoidal at 400V/50Hz\n');
fprintf('\nKEY PARAMETERS (re-run vsg_simscape_params.m to reset):\n');
fprintf('  J=%.4f kg·m²  D_p=%g W/(rad/s)  L_f=%.2f mH  C_f=%.2f µF\n', ...
    J, D_p, L_f*1e3, C_f*1e6);
fprintf('  V_dc=%g V  V_grid=%g Vrms L-L  f=%g Hz\n', V_dc, V_base, f_0);
fprintf('==========================================\n');
