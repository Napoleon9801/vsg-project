function P = vsg_stage5k_params(varargin)
% VSG_STAGE5K_PARAMS  Parameters of Stage 5k = Stage 5j (48 V battery bus, SVPWM,
% 20 kHz) + three single-phase step-up transformers (Y-Y) between the LC filter
% and the load. The load sits on the high-voltage side.
%
%   P = vsg_stage5k_params()                              % "230 V : 12 V" part, 12 Vrms setpoint
%   P = vsg_stage5k_params('tx_Vlv',9,'Vrms',10.9)        % "230 V : 9 V" part
%   P = vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true)   % setpoint chosen for Vhv_load_nom at high load
%   run_stage5k(P,'my_case')
%
% Transformer (per phase). ALL VALUES ARE ASSUMED until a real part is measured
% (open-circuit test: ratio, no-load current, no-load loss; short-circuit test: R, X):
%   tx_S         50    rated power [VA]
%   tx_Vhv       230   nameplate high-voltage winding [V rms]
%   tx_Vlv       12    nameplate low-voltage winding [V rms] = its voltage AT RATED
%                      RESISTIVE LOAD when the part is used as sold (step-down)
%   tx_reg_pct   10    nameplate regulation (V_open - V_full_load)/V_full_load [%]
%                      -> open-circuit LV voltage = tx_Vlv*(1+reg), turns ratio
%                         HV/LV = tx_Vhv/(tx_Vlv*(1+reg))
%   tx_xr        0.3   X/R of the series impedance
%   tx_imag_pct  10    magnetizing current at nominal voltage [% of rated current]
%   tx_p0_pct    3     core loss at nominal voltage [% of rated VA]
% Load (resistive, star, high-voltage side):
%   Vhv_load_nom 230   voltage the load resistors are sized for [V rms L-N]
%   P_high_W     100   total power of the load at Vhv_load_nom during the step [W]
%   P_low_W      70    total power of the load at Vhv_load_nom before / after [W]
% Other:
%   auto_Vrms    false true = set the LV setpoint so that the predicted HV voltage
%                      at the high load equals Vhv_load_nom (overrides 'Vrms')
% Load-current feed-forward of the voltage loop (E1.2: i_ref += gain*(LPF(i_L_dq)
% +/- w*Cf*v), an ESTIMATE of the load current from the inductor current):
%   ff_gain      0.8   feed-forward gain 0..1. Default 0.8 (2026-11-13 sweep on the
%                      assumed "230 V : 9 V" part: 0.9 still stable, 1.0 unstable;
%                      0.8 keeps some distance from that edge). Passing ff_on (0
%                      or 1) instead sets the gain to that value. Do not pass
%                      ff_on together with ff_gain.
%   ff_lpf_Hz    1000  cut-off of the first-order low-pass on i_L_dq [Hz]
%                      (1000 Hz = the E1.2 / Stage 5j value). With the transformer,
%                      gain 1 at 1000 Hz is unstable: the estimate contains the
%                      magnetizing current.
% Every vsg_stage5j_params / vsg_params field is accepted too, except R_load,
% L_load and R_step (they are derived here). Vrms is the LOW-VOLTAGE setpoint at
% the filter capacitor: the voltage loop does not see the transformer.
%
% Model: linear T-equivalent (series R/X split equally between the windings,
% magnetizing branch after the LV winding impedance). No saturation, no inrush,
% no hysteresis.

tx=struct('tx_S',50,'tx_Vhv',230,'tx_Vlv',12,'tx_reg_pct',10,'tx_xr',0.3,'tx_imag_pct',10,'tx_p0_pct',3, ...
    'Vhv_load_nom',230,'P_high_W',100,'P_low_W',70,'auto_Vrms',false);
ff=struct('ff_gain',NaN,'ff_lpf_Hz',1000);
if mod(numel(varargin),2)~=0; error('vsg_stage5k_params:args','Use name/value pairs.'); end
pass={}; Vrms=12; f0=50;
for k=1:2:numel(varargin)
    name=varargin{k}; val=varargin{k+1};
    if isfield(ff,name)
        ff.(name)=val;
    elseif isfield(tx,name)
        tx.(name)=val;
    elseif any(strcmp(name,{'R_load','L_load','R_step'}))
        error('vsg_stage5k_params:load','%s is derived from P_high_W / P_low_W / Vhv_load_nom.',name);
    else
        if strcmp(name,'Vrms'); Vrms=val; end
        if strcmp(name,'f0'); f0=val; end
        pass=[pass varargin(k:k+1)]; %#ok<AGROW>
    end
end
pos={'tx_S','tx_Vhv','tx_Vlv','tx_reg_pct','tx_imag_pct','tx_p0_pct','Vhv_load_nom','P_high_W','P_low_W'};
for k=1:numel(pos)
    validateattributes(tx.(pos{k}),{'numeric'},{'scalar','real','finite','positive'},'vsg_stage5k_params',pos{k});
end
validateattributes(tx.tx_xr,{'numeric'},{'scalar','real','finite','nonnegative'},'vsg_stage5k_params','tx_xr');
validateattributes(Vrms,{'numeric'},{'scalar','real','finite','positive'},'vsg_stage5k_params','Vrms');
if tx.P_low_W>=tx.P_high_W; error('vsg_stage5k_params:load','P_low_W must be smaller than P_high_W.'); end
validateattributes(ff.ff_lpf_Hz,{'numeric'},{'scalar','real','finite','positive','<',2000},'vsg_stage5k_params','ff_lpf_Hz');
hasFfOn=any(strcmp(pass(1:2:end),'ff_on'));
if ~isnan(ff.ff_gain)
    validateattributes(ff.ff_gain,{'numeric'},{'scalar','real','>=',0,'<=',1},'vsg_stage5k_params','ff_gain');
    if hasFfOn; error('vsg_stage5k_params:ff','Pass ff_gain or ff_on, not both.'); end
    pass=[pass {'ff_on',double(ff.ff_gain>0)}];
elseif ~hasFfOn
    ff.ff_gain=0.8;                       % default for the transformer case
    pass=[pass {'ff_on',1}];
end                                       % else: ff_on given, gain = ff_on (set below)

% ---- transformer equivalent circuit (per phase, referred to the LV side)
ws=2*pi*f0; reg=tx.tx_reg_pct/100; xr=tx.tx_xr;
Voc=tx.tx_Vlv*(1+reg);                    % open-circuit LV voltage at nominal HV voltage
a=tx.tx_Vhv/Voc;                          % turns ratio HV/LV
Zb=tx.tx_Vlv^2/tx.tx_S;                   % rated base on the LV side
% |1 + (R + jX)| = 1 + reg at rated resistive load, X = xr*R
Rpu=(-2+sqrt(4+4*(1+xr^2)*((1+reg)^2-1)))/(2*(1+xr^2));
Rs=Rpu*Zb; Xs=xr*Rs;                      % total series impedance, LV side
Irated=tx.tx_S/tx.tx_Vlv;
Xm=Voc/(tx.tx_imag_pct/100*Irated);
Rm=Voc^2/(tx.tx_p0_pct/100*tx.tx_S);
Z1=(Rs+1j*Xs)/2; Z2=(Rs+1j*Xs)/2;         % LV winding, HV winding referred to LV
Zm=1/(1/Rm+1/(1j*Xm));

% ---- load resistors on the HV side
Rhi=tx.Vhv_load_nom^2/(tx.P_high_W/3);
Rlo=tx.Vhv_load_nom^2/(tx.P_low_W/3);

    function r=txsolve(V1,Rhv)
        % steady state of one phase for a regulated LV terminal voltage V1 [V rms]
        if isinf(Rhv); Zsec=Inf; else; Zsec=Z2+Rhv/a^2; end
        if isinf(Zsec); Zp=Zm; else; Zp=1/(1/Zm+1/Zsec); end
        Zin=Z1+Zp; I1=V1/Zin; E=V1-I1*Z1;
        if isinf(Zsec); I2=0; Vh=abs(E)*a; else; I2=E/Zsec; Vh=abs(I2)*Rhv/a; end
        Ph=3*abs(I2)^2*Rhv/a^2; if isinf(Rhv); Ph=0; end
        S1=3*V1*conj(I1);
        r=struct('Vhv_V',Vh,'Ihv_A',abs(I2)/a,'P_hv_W',Ph,'P_lv_W',real(S1),'Q_lv_var',imag(S1), ...
            'I_lv_A',abs(I1),'Zin_ohm_re',real(Zin),'Zin_ohm_im',imag(Zin),'tx_efficiency_pct',100*Ph/max(real(S1),eps));
    end

hi0=txsolve(Vrms,Rhi);
Vrms_needed=Vrms*tx.Vhv_load_nom/hi0.Vhv_V;          % linear circuit
if tx.auto_Vrms
    Vrms=Vrms_needed;
    idx=find(strcmp(pass(1:2:end),'Vrms'));
    if isempty(idx); pass=[pass {'Vrms',Vrms}]; else; pass{2*idx(end)}=Vrms; end
end
hi=txsolve(Vrms,Rhi); lo=txsolve(Vrms,Rlo); nl=txsolve(Vrms,Inf);

% ---- Stage 5j parameter set, checked with the LV-side equivalent of the load
Req=hi.Zin_ohm_re; Leq=max(hi.Zin_ohm_im,0)/ws; Rstep_eq=max(lo.Zin_ohm_re-hi.Zin_ohm_re,0);
if ~any(strcmp(pass(1:2:end),'Vrms')); pass=[pass {'Vrms',Vrms}]; end
P=vsg_stage5j_params(pass{:},'R_load',Req,'L_load',Leq,'R_step',Rstep_eq);
P.lv_equivalent=struct('R_load',Req,'L_load',Leq,'R_step',Rstep_eq);
if isnan(ff.ff_gain); ff.ff_gain=P.base.ff_on; end
P.ff_gain=ff.ff_gain; P.ff_lpf_Hz=ff.ff_lpf_Hz;
% the model's load blocks sit on the HV side and get the real resistors
% (build_stage5k switches Load_RL_x to a pure resistor; L_load is then unused)
P.base.R_load=Rhi; P.base.R_step=Rlo-Rhi; P.base.L_load=1e-3;

% ---- Linear Transformer block values (pu on [tx_S, winding voltage])
Zb1=Voc^2/tx.tx_S;                        % block base of winding 1 (LV, V1 = Voc)
blk=struct('NominalPower',[tx.tx_S f0], ...
    'winding1',[Voc real(Z1)/Zb1 imag(Z1)/Zb1], ...
    'winding2',[tx.tx_Vhv real(Z2)/Zb1 imag(Z2)/Zb1], ...   % Z2*a^2 / (Vhv^2/S) = Z2/Zb1
    'RmLm',[Rm/Zb1 Xm/Zb1]);

d=P.derived;
Vdc_needed_for_nominal_hv=d.Vdc_needed_high_load*Vrms_needed/Vrms;   % linear scaling of the 5j limit
t=tx; t.Vrms_setpoint_lv=Vrms; t.turns_ratio_hv_per_lv=a; t.Voc_lv_V=Voc;
t.Rs_lv_ohm=Rs; t.Xs_lv_ohm=Xs; t.Rm_lv_ohm=Rm; t.Xm_lv_ohm=Xm; t.R_series_pu_rated=Rpu;
t.R_load_hv_high_ohm=Rhi; t.R_load_hv_low_ohm=Rlo;
t.block=blk;
t.predicted_high=hi; t.predicted_low=lo; t.predicted_no_load=nl;
t.Vrms_lv_for_nominal_hv_at_high_load=Vrms_needed;
t.Vdc_needed_for_nominal_hv_at_high_load=Vdc_needed_for_nominal_hv;
t.assumed=true;
P.tx=t;

w=P.warnings; nBase=numel(w);            % Stage 5j warnings were already shown
w{end+1}='Transformer data are ASSUMED (regulation, X/R, magnetizing current, core loss): measure the real part before trusting the HV voltage.';
if abs(hi.Vhv_V/tx.Vhv_load_nom-1)>0.05
    w{end+1}=sprintf('Predicted HV voltage at the high load is %.1f V (%+.1f %% of %.0f V). LV setpoint %.2f Vrms would give %.0f V; that needs a bus of at least %.1f V.', ...
        hi.Vhv_V,100*(hi.Vhv_V/tx.Vhv_load_nom-1),tx.Vhv_load_nom,Vrms_needed,tx.Vhv_load_nom,Vdc_needed_for_nominal_hv);
end
if nl.Vhv_V>1.1*tx.Vhv_load_nom
    w{end+1}=sprintf('Predicted no-load HV voltage is %.1f V (%+.1f %% of %.0f V).',nl.Vhv_V,100*(nl.Vhv_V/tx.Vhv_load_nom-1),tx.Vhv_load_nom);
end
if max(hi.I_lv_A*Vrms,hi.Ihv_A*hi.Vhv_V)>tx.tx_S
    w{end+1}=sprintf('Transformer loading at the high load is %.0f VA on the LV side: above the %.0f VA rating.',hi.I_lv_A*Vrms,tx.tx_S);
end
P.warnings=w;

fprintf('\n=== Stage 5k transformer (ASSUMED data) ===\n');
fprintf('%.0f VA, nameplate %.0f V : %.4g V, regulation %.3g %% -> open-circuit LV %.3f V, turns ratio %.3f, Rs %.3f ohm + j%.3f ohm (LV side)\n', ...
    tx.tx_S,tx.tx_Vhv,tx.tx_Vlv,tx.tx_reg_pct,Voc,a,Rs,Xs);
fprintf('LV setpoint %.3f Vrms | HV load resistors %.0f ohm (high) / %.0f ohm (low) per phase\n',Vrms,Rhi,Rlo);
fprintf('%-9s %-10s %-10s %-10s %-10s %-10s\n','load','V_hv [V]','P_hv [W]','P_lv [W]','Q_lv [var]','I_lv [A]');
rows={'high',hi;'low',lo;'none',nl};
for k=1:3
    r=rows{k,2};
    fprintf('%-9s %-10.1f %-10.1f %-10.1f %-10.1f %-10.3f\n',rows{k,1},r.Vhv_V,r.P_hv_W,r.P_lv_W,r.Q_lv_var,r.I_lv_A);
end
fprintf('LV setpoint for %.0f V at the high load: %.2f Vrms (bus >= %.1f V)\n',tx.Vhv_load_nom,Vrms_needed,Vdc_needed_for_nominal_hv);
fprintf('Load-current feed-forward: gain %.3g, i_L low-pass %.4g Hz\n',P.ff_gain,P.ff_lpf_Hz);
for k=nBase+1:numel(w); warning('vsg_stage5k_params:check','%s',w{k}); end
end
