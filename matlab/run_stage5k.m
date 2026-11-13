function R = run_stage5k(P,label,varargin)
% RUN_STAGE5K  Build the Stage 5k model (Stage 5j + step-up transformers),
% simulate, save, summarise and plot both sides of the transformer.
%
%   P = vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true);
%   run_stage5k(P,'tx9');
%
% Writes to matlab/validation_outputs/stage5k/:
%   vsg_stage5k_<label>.slx          model (see build_stage5k.m)
%   results_<label>_hv.mat           decimated HV-side outputs (load terminals)
%   results_<label>_lv.mat           decimated LV-side outputs (filter capacitor)
%   report_<label>.json              parameters, prediction and summary numbers
%   plot_<label>_hv.png / _lv.png    output overviews (plot_vsg_output.py)
% Options: 'show' (false), 'python' ('python'), 'max_step' (2.5e-6)
% Run it in a MATLAB that does not have the same model open.  MATLAB R2018b.
opt=struct('show',false,'python','python','max_step',2.5e-6);
for k=1:2:numel(varargin); opt.(varargin{k})=varargin{k+1}; end
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5k');
pyDir=fullfile(fileparts(root),'python','analysis');
B=P.base; T=P.tx; Vn=T.Vhv_load_nom;

info=build_stage5k(P,label);
load_system(info.model_file);
cl=onCleanup(@() close_system(info.model,0)); %#ok<NASGU>
fprintf('Simulating %s for %g s...\n',info.model,P.stop_time);
in=Simulink.SimulationInput(info.model);
in=in.setModelParameter('StopTime',num2str(P.stop_time,16),'MaxStep',num2str(opt.max_step,16),'ReturnWorkspaceOutputs','on');
tic; out=sim(in); wall=toc;

lv=struct(); hv=struct();
[tt,dd]=ts2mat(out.get('Vload_abc_ts')); lv.Vload_abc=struct('time',tt,'data',dd);
[tt,dd]=ts2mat(out.get('iload_abc_ts')); lv.iload_abc=struct('time',tt,'data',dd);
[tt,dd]=ts2mat(out.get('Vhv_abc_ts'));   hv.Vload_abc=struct('time',tt,'data',dd);
[tt,dd]=ts2mat(out.get('ihv_abc_ts'));   hv.iload_abc=struct('time',tt,'data',dd);
nm={'sec_freq_Hz_ts','freq';'P_ts','P_meas';'Q_ts','Q_meas'};
for k=1:3
    [tt,dd]=ts2mat(out.get(nm{k,1})); lv.(nm{k,2})=struct('time',tt,'data',dd);
end
hv.freq=lv.freq;
[td,duty]=ts2mat(out.get('s5j_duty_abc_ts'));
[~,vdcS]=ts2mat(out.get('s5j_Vdc_s_ts'));
[ti,idc]=ts2mat(out.get('I_dc_ts'));
[tr,vrail]=ts2mat(out.get('Vdc_measured_ts'));
clear out tt dd;
tend=P.stop_time;
assert(hv.Vload_abc.time(end)>=tend-1e-8 && all(isfinite(hv.Vload_abc.data(:))) && all(isfinite(lv.Vload_abc.data(:))),'Run incomplete or non-finite.');
assert(all(isfinite(duty(:))),'Non-finite duty.');

% ---- winding polarity: HV and LV phase voltages must be in phase (last 40 ms)
m=hv.Vload_abc.time>tend-0.04;
vl=interp1(lv.Vload_abc.time,lv.Vload_abc.data(:,1),hv.Vload_abc.time(m));
cc=corrcoef(hv.Vload_abc.data(m,1),vl); polarity=cc(1,2);
assert(polarity>0.9,'HV phase A is not in phase with LV phase A (correlation %.3f): check the winding polarity.',polarity);

% ---- HV voltage THD of the last 0.2 s (Hann window, fundamental = +/-2 bins around f0)
thd=nan(1,3);
if tend>=0.4
    tV=hv.Vload_abc.time; mT=tV>tend-0.2+1e-12; dtV=median(diff(tV(mT)));
    for k=1:3
        x=hv.Vload_abc.data(mT,k); n=numel(x); w=0.5-0.5*cos(2*pi*(0:n-1)'/n);
        S=abs(fft((x-mean(x)).*w)).^2; S=S(1:floor(n/2)); fb=(0:numel(S)-1)'/(n*dtV);
        [~,i1]=min(abs(fb-B.f0)); lobe=(i1-2:i1+2)';
        fund=sum(S(lobe)); rest=S; rest(lobe)=0; rest(1:3)=0;
        thd(k)=100*sqrt(sum(rest)/fund);
    end
end

events=[P.t_step_up P.t_step_down];
Dh=vsg_output_decimate(hv,events);
Dl=vsg_output_decimate(lv,events);
clear hv lv;
g=Dh.t;
Dh.title=sprintf('%s HV side (%.0f V : %.4g V part, reg %.3g %% ASSUMED, LV setpoint %.4g Vrms, FF gain %.3g / %.4g Hz)',info.model,T.tx_Vhv,T.tx_Vlv,T.tx_reg_pct,B.Vrms,info.ff.gain,info.ff.lpf_Hz);
Dh.Vrms_set=Vn; Dh.f0=B.f0;
Dl.title=sprintf('%s LV side (filter capacitor, setpoint %.4g Vrms)',info.model,B.Vrms);
Dl.Vrms_set=B.Vrms; Dl.f0=B.f0;
matH=fullfile(folder,['results_' label '_hv.mat']); matL=fullfile(folder,['results_' label '_lv.mat']);
for f={matH,matL}; if exist(f{1},'file'); vsg_backup_output(f{1}); end; end
save(matH,'-struct','Dh','-v7'); save(matL,'-struct','Dl','-v7');

% ---- settled value of each segment (last 40 %), with the analytic prediction
edges=unique([0 Dh.events(:)' tend]);
seg=struct('from_s',{},'to_s',{},'load',{},'Vhv_pos_rms',{},'Vhv_rms_abc',{},'Ihv_rms',{},'P_hv_W',{}, ...
    'Vlv_pos_rms',{},'Ilv_rms',{},'P_lv_W',{},'Q_lv_var',{},'tx_loss_W',{},'f_rotor_Hz',{}, ...
    'pred_Vhv_V',{},'pred_P_hv_W',{},'pred_P_lv_W',{});
for k=1:numel(edges)-1
    a=edges(k)+0.6*(edges(k+1)-edges(k)); b=edges(k+1); m=g>=a & g<=b;
    mid=0.5*(edges(k)+edges(k+1));
    if mid>P.t_step_up && mid<P.t_step_down; name='high'; pr=T.predicted_high; else; name='low'; pr=T.predicted_low; end
    seg(end+1)=struct('from_s',edges(k),'to_s',edges(k+1),'load',name, ...
        'Vhv_pos_rms',mean(Dh.Vpos_rms(m)),'Vhv_rms_abc',mean(Dh.Vrms(m,:),1),'Ihv_rms',mean(mean(Dh.Irms(m,:))),'P_hv_W',mean(Dh.P_20ms(m)), ...
        'Vlv_pos_rms',mean(Dl.Vpos_rms(m)),'Ilv_rms',mean(mean(Dl.Irms(m,:))),'P_lv_W',mean(Dl.P_20ms(m)),'Q_lv_var',mean(Dl.Q_20ms(m)), ...
        'tx_loss_W',mean(Dl.P_20ms(m))-mean(Dh.P_20ms(m)),'f_rotor_Hz',mean(Dh.freq_int(m)), ...
        'pred_Vhv_V',pr.Vhv_V,'pred_P_hv_W',pr.P_hv_W,'pred_P_lv_W',pr.P_lv_W); %#ok<AGROW>
end
% ---- transients after each load step, HV side (20 ms rms windows)
%      percentages are relative to the settled value of the segment that follows
ev=struct('t_s',{},'Vhv_settled_V',{},'Vhv_phase_min_pct',{},'Vhv_phase_max_pct',{},'Vhv_pos_min_pct',{},'Vhv_pos_max_pct',{}, ...
    'Vhv_phase_min_V',{},'Vhv_phase_max_V',{},'Vhv_pos_last_outside_2pct_ms',{},'f_rotor_min_Hz',{},'f_rotor_max_Hz',{});
for k=1:numel(Dh.events)
    e=Dh.events(k); nxt=min([Dh.events(Dh.events>e); tend]); m=g>e & g<=min(e+1,nxt);
    ms=g>=e+0.6*(nxt-e) & g<=nxt; ref=mean(Dh.Vpos_rms(ms));
    vp=100*(Dh.Vrms(m,:)/ref-1); vs=100*(Dh.Vpos_rms(m)/ref-1); gm=g(m);
    lastOut=find(abs(vs)>2,1,'last'); if isempty(lastOut); rec=0; else; rec=1e3*(gm(lastOut)-e); end
    vv=Dh.Vrms(m,:);
    ev(end+1)=struct('t_s',e,'Vhv_settled_V',ref,'Vhv_phase_min_pct',min(vp(:)),'Vhv_phase_max_pct',max(vp(:)), ...
        'Vhv_pos_min_pct',min(vs),'Vhv_pos_max_pct',max(vs),'Vhv_phase_min_V',min(vv(:)),'Vhv_phase_max_V',max(vv(:)), ...
        'Vhv_pos_last_outside_2pct_ms',rec,'f_rotor_min_Hz',min(Dh.freq_int(m)),'f_rotor_max_Hz',max(Dh.freq_int(m))); %#ok<AGROW>
end
% ---- start-up (HV side)
startup=struct('vhv_peak_V',max(abs(Dh.wv1(:))),'vhv_peak_pct_of_nominal_peak',100*max(abs(Dh.wv1(:)))/(Vn*sqrt(2)), ...
    'ilv_peak_first_window_A',max(abs(Dl.wi1(:))));
% ---- duty use
mD=td>P.t_softstart+0.05;
if ~any(mD); mD=td>2e-4; end
dz=duty(mD,:);
dutyUse=struct('min',min(dz(:)),'max',max(dz(:)),'samples_at_clamp',sum(any(dz<=P.duty_min+1e-9 | dz>=P.duty_max-1e-9,2)),'samples',size(dz,1));
assert(min(vdcS)>0,'Measured DC rail is not positive: source polarity is wrong.');
% ---- DC power over the last 20 ms
a=tend-0.02; mP=ti>=a;
pdc=interp1(tr,vrail,ti(mP),'linear','extrap').*idc(mP);
Pdc=trapz(ti(mP),pdc)/(ti(end)-ti(find(mP,1)));
dcSide=struct('P_dc_W',Pdc,'P_lv_W',Dl.P_20ms(end),'P_hv_W',Dh.P_20ms(end), ...
    'efficiency_dc_to_hv_pct',100*Dh.P_20ms(end)/Pdc,'efficiency_inverter_pct',100*Dl.P_20ms(end)/Pdc,'efficiency_transformer_pct',100*Dh.P_20ms(end)/Dl.P_20ms(end));

mA=g>P.t_softstart+0.3;
if ~any(mA); mA=true(size(g)); end
R=struct('label',label,'model_file',info.model_file,'model_sha256',info.model_sha256, ...
    'source_model_sha256',info.source_model_sha256,'builder_sha256',info.builder_sha256, ...
    'wall_seconds',wall,'maximum_step_s',opt.max_step,'params',info.params,'stage5j',info.stage5j, ...
    'transformer',T,'lv_equivalent',P.lv_equivalent,'warnings',{P.warnings}, ...
    'segments',seg,'load_steps',ev,'startup',startup,'duty',dutyUse,'dc_side',dcSide, ...
    'polarity_correlation_hv_lv',polarity,'thd_Vhv_pct_last_0p2s',thd, ...
    'f_rotor_min_Hz',min(Dh.freq_int(mA)),'f_rotor_max_Hz',max(Dh.freq_int(mA)), ...
    'Vhv_phase_min_V',min(min(Dh.Vrms(mA,:))),'Vhv_phase_max_V',max(max(Dh.Vrms(mA,:))), ...
    'results_hv',matH,'results_lv',matL, ...
    'scope','Simulation only (SPS MOSFET switching model). Transformer = linear T-equivalent with ASSUMED data: no saturation, inrush or hysteresis. Voltage loop regulates the LV capacitor voltage only. Stiff DC bus, no current limit, no PI anti-windup. No hardware qualification.');
R.ff=info.ff;
repPath=fullfile(folder,['report_' label '.json']);
if exist(repPath,'file'); vsg_backup_output(repPath); end
fid=fopen(repPath,'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(R)); fclose(fid);

plots={matH,fullfile(folder,['plot_' label '_hv.png']);matL,fullfile(folder,['plot_' label '_lv.png'])};
for k=1:size(plots,1)
    cmd=sprintf('"%s" -I "%s" "%s" "%s"',opt.python,fullfile(pyDir,'plot_vsg_output.py'),plots{k,1},plots{k,2});
    [st,msg]=system(cmd);
    if st==0
        fprintf('Plot: %s\n',plots{k,2});
        if opt.show; try; winopen(plots{k,2}); catch; end; end
    else
        warning('run_stage5k:plot','Plot failed (results are saved). Command:\n%s\n%s',cmd,msg);
    end
end

fprintf('\n%-11s %-5s %-9s %-9s %-9s %-9s %-9s %-9s %-9s %-9s\n','segment','load','Vhv+','pred','P_hv','pred','Vlv+','P_lv','loss','f [Hz]');
for k=1:numel(seg)
    s=seg(k);
    fprintf('%4.1f-%-5.1f %-5s %-9.2f %-9.2f %-9.2f %-9.2f %-9.3f %-9.2f %-9.2f %-9.4f\n',s.from_s,s.to_s,s.load,s.Vhv_pos_rms,s.pred_Vhv_V,s.P_hv_W,s.pred_P_hv_W,s.Vlv_pos_rms,s.P_lv_W,s.tx_loss_W,s.f_rotor_Hz);
end
for k=1:numel(ev)
    e=ev(k);
    fprintf('step at %g s: HV phase %.1f..%.1f V (%+.1f..%+.1f %% of settled %.1f V), V+ %+.1f..%+.1f %%, inside 2%% after %.0f ms, f %.4f..%.4f Hz\n', ...
        e.t_s,e.Vhv_phase_min_V,e.Vhv_phase_max_V,e.Vhv_phase_min_pct,e.Vhv_phase_max_pct,e.Vhv_settled_V,e.Vhv_pos_min_pct,e.Vhv_pos_max_pct,e.Vhv_pos_last_outside_2pct_ms,e.f_rotor_min_Hz,e.f_rotor_max_Hz);
end
fprintf('start-up HV peak %.1f V (%.0f %% of %.0f V peak) | duty %.3f..%.3f, %d of %d samples at clamp | polarity corr %.3f\n', ...
    startup.vhv_peak_V,startup.vhv_peak_pct_of_nominal_peak,Vn*sqrt(2),dutyUse.min,dutyUse.max,dutyUse.samples_at_clamp,dutyUse.samples,polarity);
fprintf('P_dc %.1f W -> P_lv %.1f W -> P_hv %.1f W (inverter %.1f %%, transformer %.1f %%, total %.1f %%) | THD_Vhv %.2f %%\n', ...
    Pdc,dcSide.P_lv_W,dcSide.P_hv_W,dcSide.efficiency_inverter_pct,dcSide.efficiency_transformer_pct,dcSide.efficiency_dc_to_hv_pct,max(thd));
fprintf('STAGE5K_COMPLETE: %s (%.0f s wall)\n',repPath,wall);
end

function [t,d]=ts2mat(x)
if isstruct(x); t=x.time(:); d=x.signals.values; else; t=x.Time(:); d=x.Data; end
if size(d,1)~=numel(t); d=permute(d,[ndims(d),1:ndims(d)-1]); end
d=reshape(d,numel(t),[]);
end
