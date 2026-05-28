% phase5a_rerun_matched.m
% =========================================================================
%  Re-run Stage 5a baseline at the Stage 5c operating point so the two
%  can be compared apples-to-apples (same H, D, disturbance time, T_sim).
%
%  Without this, the 5a-vs-5c overlay confounds three changes:
%      D    : 0   -> 0.5
%      R_d  : 0   -> 1.0   (Stage 5c)
%      FF   : off -> on    (Stage 5c)
%  By running 5a at H=5, D=0.5 too, the only differences left are R_d
%  and the inner-loop FF — isolating their effect for Chapter 4.
%
%  Re-uses vsg_stage5a.slx that was already built by phase5a_switching_abc.m,
%  so no model rebuild is needed. Same logging schema as the original 5a
%  output, written to vsg_stage5a_matched_out.mat.
%
%  R2018b compatible. ~3-5 min sim time.
% =========================================================================

%% --- CONFIG -------------------------------------------------------------

H_match        = 5;
D_match        = 0.5;
R_load_t_match = 1.0;
T_sim_match    = 3.0;
f_base         = 50;
omega_s        = 2*pi*f_base;
inv_2Hws_match = omega_s / (2 * H_match);

%% --- LOAD MODEL --------------------------------------------------------

script_dir = fileparts(mfilename('fullpath'));
model      = 'vsg_stage5a';
model_path = fullfile(script_dir, [model '.slx']);

if ~exist(model_path, 'file')
    error('vsg_stage5a.slx not found. Run phase5a_switching_abc.m first.');
end
if ~bdIsLoaded(model)
    load_system(model_path);
end

%% --- OVERRIDE PARAMETERS + RUN -----------------------------------------

% Same block-parameter override pattern as Stage 5b sweep — phase5a bakes
% numeric literals into block props so workspace setVariable is not enough.
in = Simulink.SimulationInput(model);
in = in.setBlockParameter([model '/Gain_inv_2Hws'], ...
        'Gain', num2str(inv_2Hws_match));
in = in.setBlockParameter([model '/Gain_D'], ...
        'Gain', num2str(D_match));
in = in.setBlockParameter([model '/R_load_step'], ...
        'Time', num2str(R_load_t_match));
in = in.setModelParameter('StopTime', num2str(T_sim_match));

fprintf('[5a matched] H=%g D=%g R_load_t=%g T_sim=%g\n', ...
        H_match, D_match, R_load_t_match, T_sim_match);
fprintf('[5a matched] Simulating ~3-5 min ...\n');

t_start = tic;
% sim(SimulationInput) routes To Workspace data into the returned
% SimulationOutput rather than base workspace — so we MUST capture and
% read via out.get(...) here (unlike plain sim(model) used by phase5a).
out = sim(in);
fprintf('[5a matched] Sim done in %.1f s\n', toc(t_start));

%% --- PULL TIMESERIES from SimulationOutput ---------------------------

ots      = out.get('omega_ts');     t = ots.Time;  omega = ots.Data;
dts      = out.get('delta_ts');     delta = dts.Data;
Vdr      = out.get('Vd_ref_ts');    Vd_ref = Vdr.Data;
VLd      = out.get('Vload_d_ts');   Vload_d = VLd.Data;
VLq      = out.get('Vload_q_ts');   Vload_q = VLq.Data;
ILd      = out.get('iL_d_ts');      iL_d = ILd.Data;
ILq      = out.get('iL_q_ts');      iL_q = ILq.Data;
VLabc    = out.get('Vload_abc_ts'); Vload_abc = VLabc.Data;
ILabc    = out.get('iL_abc_ts');    iL_abc = ILabc.Data;
Iloadabc = out.get('iload_abc_ts'); iload_abc = Iloadabc.Data;
Vinva    = out.get('Vinv_a_ts');    Vinv_a = Vinva.Data;
Pts      = out.get('P_ts');         P_meas = Pts.Data;
Qts      = out.get('Q_ts');         Q_meas = Qts.Data;
freq     = omega/(2*pi);

%% --- SAVE --------------------------------------------------------------

% Mirror phase5a's save schema so plot_phase5c.py can load it as a drop-in
% baseline. Also tag with the matched operating point so downstream
% consumers know this is the rerun, not the original 5a.
H            = H_match;
D            = D_match;
R_p          = 0.05;
R_q          = 0.05;
R_d          = 0;        % Stage 5a has no damping resistor
L_f          = 1.2e-3;
C_f          = 10e-6;
R_f          = 0.05;
zeta_filter  = R_f/2 * sqrt(C_f/L_f);
f_res        = 1/(2*pi*sqrt(L_f*C_f));
f_sw         = 10e3;
V_dc         = 48;
V_set        = 14;
P_base       = 100;
Q_base       = 100;
R_load_init  = 2.94;
R_load_after = R_load_init * 0.70;
L_load       = 1e-3;
R_load_t     = R_load_t_match;
T_sim        = T_sim_match;
Kp_V         = 2*0.707*628*C_f;
Ki_V         = 628^2 * C_f;
Kp_I         = 6283 * L_f;
Ki_I         = Kp_I * R_f / L_f;

% Analytical SS predictions for the matched op
ZL_d_pre   = (R_load_init^2 + (omega_s*L_load)^2)/R_load_init;
I_d_ss_pre = V_set / ZL_d_pre;
P_ss_pre   = 1.5 * V_set * I_d_ss_pre;
Q_ss_pre   = 1.5 * (-V_set * (-omega_s*L_load*I_d_ss_pre/R_load_init));
ZL_d_post  = (R_load_after^2 + (omega_s*L_load)^2)/R_load_after;
I_d_ss_post= V_set / ZL_d_post;
P_ss_post  = 1.5 * V_set * I_d_ss_post;
dP_pu      = (P_ss_post - P_ss_pre)/P_base;
df_ss_pred = -R_p * dP_pu * f_base;
f_ss_pred  = f_base + df_ss_pred;

out_path = fullfile(script_dir, 'vsg_stage5a_matched_out.mat');
save(out_path, ...
     't', 'omega', 'delta', 'freq', 'Vd_ref', ...
     'Vload_d', 'Vload_q', 'iL_d', 'iL_q', ...
     'Vload_abc', 'iL_abc', 'iload_abc', 'Vinv_a', ...
     'P_meas', 'Q_meas', ...
     'V_dc','V_set','P_base','Q_base','f_base','omega_s', ...
     'H','D','R_p','R_q','L_f','C_f','R_f','R_d','zeta_filter','f_sw','f_res', ...
     'R_load_init','R_load_after','L_load','R_load_t', ...
     'Kp_V','Ki_V','Kp_I','Ki_I', ...
     'P_ss_pre','P_ss_post','df_ss_pred','f_ss_pred','T_sim', ...
     '-v7');

fprintf('[5a matched] Saved : %s\n', out_path);
fprintf('  V_d final = %.3f V    V_q final = %+.4f V\n', Vload_d(end), Vload_q(end));
fprintf('  P final   = %.2f W    f final   = %.4f Hz (Df = %+.4f Hz)\n', ...
        P_meas(end), freq(end), freq(end)-f_base);
