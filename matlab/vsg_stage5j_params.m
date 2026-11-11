function P = vsg_stage5j_params(varargin)
% VSG_STAGE5J_PARAMS  User-adjustable parameters of Stage 5j (48 V battery bus,
% 12 Vrms, SVPWM with measured-Vdc feed-forward, 20 kHz carrier).
%
%   P = vsg_stage5j_params()                         % spec_48v_100w_2026-11-10 defaults
%   P = vsg_stage5j_params('Vdc',39)                 % constant bus at the battery cut-off
%   P = vsg_stage5j_params('Vdc_t',[0 1 2],'Vdc_v',[54.6 54.6 39])   % bus profile
%   run_stage5j(P,'my_case')                         % build + simulate + plot
%
% Fields shared with vsg_params (same meaning, new defaults where marked *):
%   Vdc*  48      nominal DC bus [V] (used when no profile is given)
%   Vrms* 12      phase voltage setpoint [V rms L-N]
%   f0 50, H 5, D 0.5, Rp 0.05, Dq 0.007, S 100, P_set_pu 1, Q_set 0, f_lpf_PQ 5
%   R_load* 4.297 always-connected R per phase [ohm]  -> 100 W at 12 Vrms when the
%                 step resistor is bypassed (with L_load 1 mH)
%   L_load  1e-3
%   R_step* 1.842 series R per phase bypassed during the step [ohm] -> 70 W before /
%                 after the step. Same conductance ratio (1.4286) as Stage 5i / E1.2.
%   t_step_up 3, t_step_down 7, stop_time 11, secondary_on 1, secondary_Ki 4, ff_on 1
% New in Stage 5j:
%   Vdc_t, Vdc_v  []   bus-voltage profile (time [s], volts), linear between points,
%                      held outside. Empty = constant Vdc.
%   fsw        20e3    carrier frequency [Hz]; must be a multiple of the 10 kHz
%                      controller rate (duty is updated once per controller sample)
%   duty_min   0.03    duty clamp (bootstrap refresh), high-side duty
%   duty_max   0.97
%   t_softstart 0.1    voltage setpoint ramps 0 -> Vrms in this time [s] (0 = step)
%
% Fixed design values stay in the model: Lf 1.2 mH, Rf 0.05 ohm, Cf 10 uF, Rd 1 ohm,
% voltage/current PI gains, controller Ts 100 us, dead time 520 ns, MOSFET data.

new=struct('Vdc_t',[],'Vdc_v',[],'fsw',20e3,'duty_min',0.03,'duty_max',0.97,'t_softstart',0.1);
baseDefaults={'Vdc',48,'Vrms',12,'R_load',4.297,'R_step',1.842};
if mod(numel(varargin),2)~=0; error('vsg_stage5j_params:args','Use name/value pairs.'); end
baseArgs=baseDefaults;
for k=1:2:numel(varargin)
    name=varargin{k};
    if isfield(new,name); new.(name)=varargin{k+1}; else; baseArgs=[baseArgs varargin(k:k+1)]; end %#ok<AGROW>
end
% Shared fields: reuse the tested validation. Its summary and SPWM-based
% modulation warning do not apply to SVPWM, so they are not shown.
ws0=warning('off','vsg_params:check'); restore=onCleanup(@() warning(ws0)); %#ok<NASGU>
[~,B]=evalc('vsg_params(baseArgs{:})');
keep=B.warnings(cellfun(@(s) isempty(strfind(s,'Vdc/2')),B.warnings)); %#ok<STREMP>

validateattributes(new.fsw,{'numeric'},{'scalar','real','finite','positive'},'vsg_stage5j_params','fsw');
validateattributes(new.t_softstart,{'numeric'},{'scalar','real','finite','nonnegative'},'vsg_stage5j_params','t_softstart');
validateattributes(new.duty_min,{'numeric'},{'scalar','real','>=',0,'<',0.5},'vsg_stage5j_params','duty_min');
validateattributes(new.duty_max,{'numeric'},{'scalar','real','>',0.5,'<=',1},'vsg_stage5j_params','duty_max');
Ts=1e-4; Lf=1.2e-3; Rf=0.05; deadtime=520e-9;      % fixed in the model
ratio=new.fsw*Ts;
if abs(ratio-round(ratio))>1e-9 || round(ratio)<1
    error('vsg_stage5j_params:fsw','fsw must be a multiple of %g Hz (controller rate).',1/Ts);
end
if isempty(new.Vdc_t) && isempty(new.Vdc_v)
    new.Vdc_t=[0 1]; new.Vdc_v=[B.Vdc B.Vdc];
else
    validateattributes(new.Vdc_t,{'numeric'},{'vector','real','finite','increasing','nonnegative'},'vsg_stage5j_params','Vdc_t');
    validateattributes(new.Vdc_v,{'numeric'},{'vector','real','finite','positive','numel',numel(new.Vdc_t)},'vsg_stage5j_params','Vdc_v');
    if numel(new.Vdc_t)<2; error('vsg_stage5j_params:profile','Vdc profile needs at least 2 points.'); end
    new.Vdc_t=new.Vdc_t(:)'; new.Vdc_v=new.Vdc_v(:)';
end

P=struct('base',B);
f=fieldnames(new); for k=1:numel(f); P.(f{k})=new.(f{k}); end
P.t_step_up=B.t_step_up; P.t_step_down=B.t_step_down; P.stop_time=B.stop_time;
P.Vrms=B.Vrms; P.f0=B.f0;

d=rmfield(B.derived,{'Vpk_max_linear','modulation'});       % SPWM quantities, not valid here
d.Vdc_min=min(P.Vdc_v); d.Vdc_max=max(P.Vdc_v);
d.Vpk=B.Vrms*sqrt(2);
% inverter-side peak needed at the high load (Rf and Lf drop, load current in phase)
Ipk=d.I_high_A*sqrt(2);
d.Vinv_pk_high=hypot(d.Vpk+Rf*Ipk,d.omega_s*Lf*Ipk);
d.svpwm_gain_pk_per_Vdc=(P.duty_max-P.duty_min)/sqrt(3);   % phase peak per volt of bus
d.Vpk_limit_at_Vdc_min=d.Vdc_min*d.svpwm_gain_pk_per_Vdc;
d.modulation_at_Vdc_min=d.Vinv_pk_high/d.Vpk_limit_at_Vdc_min;
d.Vdc_needed_high_load=d.Vinv_pk_high/d.svpwm_gain_pk_per_Vdc;
d.ripple_pp_estimate_A=d.Vdc_max/(4*Lf*P.fsw);             % spec note section 4
d.min_pulse_s=P.duty_min/P.fsw;
P.derived=d;

w=keep;
if d.modulation_at_Vdc_min>1
    w{end+1}=sprintf('Bus minimum %.1f V cannot make the high-load voltage: needs %.2f V peak, SVPWM limit with duty clamp is %.2f V. Minimum bus is %.1f V.', ...
        d.Vdc_min,d.Vinv_pk_high,d.Vpk_limit_at_Vdc_min,d.Vdc_needed_high_load);
elseif d.modulation_at_Vdc_min>0.9
    w{end+1}=sprintf('Only %.0f%% modulation headroom at the bus minimum %.1f V.',100*(1-d.modulation_at_Vdc_min),d.Vdc_min);
end
if d.min_pulse_s<2*deadtime
    w{end+1}=sprintf('Minimum pulse %.2f us is below twice the dead time (%.2f us).',1e6*d.min_pulse_s,1e6*deadtime);
end
if isfinite(P.t_step_up) && P.t_step_up<P.t_softstart+0.2
    w{end+1}='t_step_up is inside or right after the soft-start ramp.';
end
P.warnings=w;

fprintf('\n=== Stage 5j parameters ===\n');
fprintf('Bus %.4g..%.4g V (%d-point profile) | Vrms %.4g V L-N (%.4g V pk) | f0 %.4g Hz | fsw %.4g kHz, duty %.2f..%.2f, soft-start %.3g s\n', ...
    d.Vdc_min,d.Vdc_max,numel(P.Vdc_t),B.Vrms,d.Vpk,B.f0,P.fsw/1e3,P.duty_min,P.duty_max,P.t_softstart);
fprintf('SVPWM limit at bus minimum %.2f V pk, inverter needs %.2f V pk at high load -> modulation %.0f%% (bus needed >= %.1f V)\n', ...
    d.Vpk_limit_at_Vdc_min,d.Vinv_pk_high,100*d.modulation_at_Vdc_min,d.Vdc_needed_high_load);
fprintf('H %.4g s | D %.4g | Rp %.4g -> K = %.2f pu, tau_m = %.1f ms | P/Q LPF %.3g Hz\n',B.H,B.D,B.Rp,d.K_pu,1e3*d.tau_m_s,B.f_lpf_PQ);
fprintf('Load low %.1f W / %.2f A  ->  high %.1f W / %.2f A (step up %g s, down %g s, stop %g s)\n', ...
    d.P_low_W,d.I_low_A,d.P_high_W,d.I_high_A,B.t_step_up,B.t_step_down,B.stop_time);
fprintf('Ripple estimate %.2f A p-p at %.1f V | secondary %d (Ki %.3g) | FF %d\n',d.ripple_pp_estimate_A,d.Vdc_max,B.secondary_on,B.secondary_Ki,B.ff_on);
for k=1:numel(w); warning('vsg_stage5j_params:check','%s',w{k}); end
end
