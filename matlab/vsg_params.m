function P = vsg_params(varargin)
% VSG_PARAMS  Central set of USER-ADJUSTABLE parameters for the islanded VSG model.
%
%   P = vsg_params()                       % defaults = E1.2 FF load-cycle model as tested
%   P = vsg_params('H',10,'Vdc',60)        % override any field by name
%   P = vsg_params('t_step_up',2,'t_step_down',5,'stop_time',8)
%
% Then build a model that uses them:   apply_vsg_params(P,'my_case')
%
% Only parameters that can be changed WITHOUT redesigning the control loops are
% here. Fixed design values (Lf, Rf, Cf, Rd, voltage/current PI gains, controller
% sample time Ts = 100 us, 10 kHz carrier period, MOSFET data) stay in the model.
% Everything derived from these inputs (omega_s/(2H), 1/(Rp*omega_s), LPF
% coefficients, carrier +/-Vdc/2, omega*Cf, rotor initial omega) is written as an
% expression in the blocks, so the model stays consistent when an input changes.
%
% Fields (defaults):
%   Vdc          40      DC-link voltage [V]          (carrier follows: +/-Vdc/2)
%   Vrms         9.8995  output phase voltage setpoint [V rms] (= 14 V peak)
%   f0           50      nominal frequency [Hz]       (omega_s = 2*pi*f0 everywhere)
%   H            5       virtual inertia [s]
%   D            0.5     damping, multiplies delta-omega in rad/s [pu/(rad/s)]
%   Rp           0.05    P-f droop [pu]               K = 1/Rp + D*omega_s
%   Dq           0.007   Q-V droop [V/var]
%   S            100     power base [VA]
%   P_set_pu     1       active-power setpoint [pu of S]
%   Q_set        0       reactive-power setpoint [var]
%   f_lpf_PQ     5       P/Q measurement low-pass cut-off [Hz]
%   R_load       2.058   always-connected load, R per phase [ohm]
%   L_load       1e-3    always-connected load, L per phase [H]
%   R_step       0.882   series R per phase that is BYPASSED during the step [ohm]
%                        (load goes UP at t_step_up, back DOWN at t_step_down)
%   t_step_up    3       time of load increase [s]  (Inf = no step)
%   t_step_down  7       time of load decrease [s]  (Inf = stays high)
%   stop_time    11      simulation stop time [s]
%   secondary_on 1       secondary frequency restoration on/off
%   secondary_Ki 4       secondary integral gain [pu/(Hz*s)]
%   ff_on        1       E1.2 load-current feed-forward on/off (islanded only)
%
% The function prints a summary and warns about combinations that are known to
% misbehave (modulation headroom, secondary loop damping, secondary range, step
% timing). Warnings do not stop you; errors are only for impossible values.

P = struct( ...
    'Vdc',40, 'Vrms',14/sqrt(2), 'f0',50, ...
    'H',5, 'D',0.5, 'Rp',0.05, 'Dq',0.007, ...
    'S',100, 'P_set_pu',1, 'Q_set',0, 'f_lpf_PQ',5, ...
    'R_load',2.058, 'L_load',1e-3, 'R_step',0.882, ...
    't_step_up',3, 't_step_down',7, 'stop_time',11, ...
    'secondary_on',1, 'secondary_Ki',4, 'ff_on',1);

if mod(numel(varargin),2)~=0; error('vsg_params:args','Use name/value pairs.'); end
for k=1:2:numel(varargin)
    name=varargin{k};
    if ~isfield(P,name); error('vsg_params:unknown','Unknown parameter "%s". Valid: %s',name,strjoin(fieldnames(P)',', ')); end
    P.(name)=varargin{k+1};
end

% ---- impossible values -> error
pos={'Vdc','Vrms','f0','H','Rp','S','f_lpf_PQ','R_load','stop_time'};
for k=1:numel(pos)
    v=P.(pos{k}); validateattributes(v,{'numeric'},{'scalar','real','finite','positive'},'vsg_params',pos{k});
end
nonneg={'D','Dq','L_load','R_step','secondary_Ki'};
for k=1:numel(nonneg)
    v=P.(nonneg{k}); validateattributes(v,{'numeric'},{'scalar','real','finite','nonnegative'},'vsg_params',nonneg{k});
end
validateattributes(P.P_set_pu,{'numeric'},{'scalar','real','finite'},'vsg_params','P_set_pu');
validateattributes(P.Q_set,{'numeric'},{'scalar','real','finite'},'vsg_params','Q_set');
validateattributes(P.t_step_up,{'numeric'},{'scalar','real','nonnegative','nonnan'},'vsg_params','t_step_up');
validateattributes(P.t_step_down,{'numeric'},{'scalar','real','nonnegative','nonnan'},'vsg_params','t_step_down');
if P.t_step_down<=P.t_step_up
    error('vsg_params:steps','t_step_down (%g s) must be later than t_step_up (%g s).',P.t_step_down,P.t_step_up);
end
for f={'secondary_on','ff_on'}
    if ~ismember(P.(f{1}),[0 1]); error('vsg_params:flag','%s must be 0 or 1.',f{1}); end
end

% ---- derived quantities (for the summary and checks only; the model uses expressions)
Ts=1e-4; secLim=[-0.5 0.8]; secStart=0.5;     % fixed in the model
ws=2*pi*P.f0;
d.omega_s=ws;
d.K_pu=1/P.Rp+P.D*ws;
d.droop_eff_pct=100/d.K_pu;
d.tau_m_s=2*P.H/d.K_pu;
d.tau_lpf_s=1/(2*pi*P.f_lpf_PQ);
d.Vpk=P.Vrms*sqrt(2);
d.Vpk_max_linear=P.Vdc/2;
d.modulation=d.Vpk/d.Vpk_max_linear;
ZL=ws*P.L_load;
Rlo=P.R_load+P.R_step; Rhi=P.R_load;
d.P_low_W=3*P.Vrms^2*Rlo/(Rlo^2+ZL^2);   d.P_high_W=3*P.Vrms^2*Rhi/(Rhi^2+ZL^2);
d.I_low_A=P.Vrms/hypot(Rlo,ZL);          d.I_high_A=P.Vrms/hypot(Rhi,ZL);
d.P_low_pu=d.P_low_W/P.S;                d.P_high_pu=d.P_high_W/P.S;
d.df_low_no_secondary_Hz=-(d.P_low_pu-P.P_set_pu)/d.K_pu*P.f0;
d.df_high_no_secondary_Hz=-(d.P_high_pu-P.P_set_pu)/d.K_pu*P.f0;
if P.secondary_Ki>0
    d.secondary_zeta=d.K_pu/(2*sqrt(2*P.H*P.secondary_Ki*P.f0));
    d.secondary_Ki_for_zeta1=d.K_pu^2/(8*P.H*P.f0);
else
    d.secondary_zeta=Inf; d.secondary_Ki_for_zeta1=d.K_pu^2/(8*P.H*P.f0);
end
P.derived=d;

% ---- warnings (known trouble, not impossible)
w={};
if d.modulation>1
    w{end+1}=sprintf('Vrms*sqrt(2) = %.2f V peak exceeds the linear limit Vdc/2 = %.2f V: the inverter cannot make this voltage (no modulation limit in the model either).',d.Vpk,d.Vpk_max_linear);
elseif d.modulation>0.8
    w{end+1}=sprintf('Modulation %.0f%% of Vdc/2: little headroom; the start-up transient already reaches ~1.4x the setpoint.',100*d.modulation);
end
if P.secondary_on && d.secondary_zeta<0.7
    w{end+1}=sprintf('Secondary loop damping zeta = %.2f (< 0.7): frequency restoration will oscillate. Ki ~ %.3g gives zeta = 1.',d.secondary_zeta,d.secondary_Ki_for_zeta1);
end
need=[d.P_low_pu d.P_high_pu]-P.P_set_pu;
if P.secondary_on && (any(need<secLim(1)) || any(need>secLim(2)))
    w{end+1}=sprintf('Secondary must add %.2f / %.2f pu but is limited to [%.1f, %.1f] pu: frequency will not return to f0. Change P_set_pu, S or the load.',need(1),need(2),secLim(1),secLim(2));
end
if isfinite(P.t_step_up) && P.t_step_up<secStart+0.2
    w{end+1}=sprintf('t_step_up = %g s is inside the start-up transient / before secondary starts (%.1f s).',P.t_step_up,secStart);
end
if isfinite(P.t_step_up) && P.t_step_up>=P.stop_time
    w{end+1}='t_step_up is after stop_time: no load step will be seen.';
end
if P.f_lpf_PQ>0.1/Ts
    w{end+1}=sprintf('f_lpf_PQ = %g Hz is too close to the 10 kHz controller rate.',P.f_lpf_PQ);
end
if P.ff_on==0
    w{end+1}='ff_on = 0: back to the slow E1.2 baseline voltage recovery (tau ~85-125 ms).';
end
P.warnings=w;

% ---- summary
fprintf('\n=== VSG parameters ===\n');
fprintf('Vdc %.4g V | Vrms %.4g V (%.4g V pk, modulation %.0f%% of Vdc/2) | f0 %.4g Hz\n',P.Vdc,P.Vrms,d.Vpk,100*d.modulation,P.f0);
fprintf('H %.4g s | D %.4g | Rp %.4g -> K = %.2f pu (effective droop %.3f%%), tau_m = %.1f ms, LPF %.3g Hz (tau %.1f ms)\n', ...
    P.H,P.D,P.Rp,d.K_pu,d.droop_eff_pct,1e3*d.tau_m_s,P.f_lpf_PQ,1e3*d.tau_lpf_s);
fprintf('Load low %.1f W / %.2f A  ->  high %.1f W / %.2f A  (P_set %.3g pu = %.1f W, S %.4g VA)\n', ...
    d.P_low_W,d.I_low_A,d.P_high_W,d.I_high_A,P.P_set_pu,P.P_set_pu*P.S,P.S);
fprintf('Steady df without secondary: low %+.3f Hz, high %+.3f Hz\n',d.df_low_no_secondary_Hz,d.df_high_no_secondary_Hz);
fprintf('Step up %g s, down %g s, stop %g s | secondary %d (Ki %.3g, zeta %.2f) | FF %d\n', ...
    P.t_step_up,P.t_step_down,P.stop_time,P.secondary_on,P.secondary_Ki,d.secondary_zeta,P.ff_on);
for k=1:numel(w); warning('vsg_params:check','%s',w{k}); end
end
