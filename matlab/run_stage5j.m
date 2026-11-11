function R = run_stage5j(P,label,varargin)
% RUN_STAGE5J  Build the Stage 5j model, simulate, save, summarise and plot.
%
%   P = vsg_stage5j_params();                 % 48 V, 12 Vrms, SVPWM, 20 kHz
%   run_stage5j(P,'nominal');
%
% Writes to matlab/validation_outputs/stage5j/:
%   vsg_stage5j_<label>.slx          model (see build_stage5j.m)
%   results_<label>.mat              decimated outputs (1 ms grid, raw windows, tail)
%   report_<label>.json              parameters and summary numbers
%   plot_<label>.png                 output overview (plot_vsg_output.py)
%   plot_<label>_bus_pwm.png         bus voltage, duty, inductor ripple (plot_stage5j.py)
% Options: 'show' (false) open the PNGs, 'python' ('python'), 'max_step' (2.5e-6),
%          'save_wave' (false) also write wave_<label>.mat: full-length Vload_abc / iload_abc
%          at the logging rate (for full-run phase-voltage plots)
% Run it in a MATLAB that does not have the same model open.  MATLAB R2018b.
opt=struct('show',false,'python','python','max_step',2.5e-6,'save_wave',false);
for k=1:2:numel(varargin); opt.(varargin{k})=varargin{k+1}; end
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5j');
pyDir=fullfile(fileparts(root),'python','analysis');
B=P.base;

info=build_stage5j(P,label);
load_system(info.model_file);
cl=onCleanup(@() close_system(info.model,0)); %#ok<NASGU>
fprintf('Simulating %s for %g s...\n',info.model,P.stop_time);
in=Simulink.SimulationInput(info.model);
in=in.setModelParameter('StopTime',num2str(P.stop_time,16),'MaxStep',num2str(opt.max_step,16),'ReturnWorkspaceOutputs','on');
tic; out=sim(in); wall=toc;

vars={'Vload_abc_ts','iload_abc_ts','sec_freq_Hz_ts','P_ts','Q_ts'};
names={'Vload_abc','iload_abc','freq','P_meas','Q_meas'};
s=struct();
for k=1:numel(vars)
    [tt,dd]=ts2mat(out.get(vars{k})); s.(names{k})=struct('time',tt,'data',dd);
end
[td,duty]=ts2mat(out.get('s5j_duty_abc_ts'));
[tv,vdcS]=ts2mat(out.get('s5j_Vdc_s_ts'));
[tl,iL]=ts2mat(out.get('iL_abc_ts'));
[ti,idc]=ts2mat(out.get('I_dc_ts'));
[tr,vrail]=ts2mat(out.get('Vdc_measured_ts'));
clear out;
tend=P.stop_time;
assert(s.Vload_abc.time(end)>=tend-1e-8 && all(isfinite(s.Vload_abc.data(:))),'Run incomplete or non-finite.');
assert(all(isfinite(duty(:))) && all(isfinite(iL(:))),'Non-finite duty or inductor current.');

% ---- voltage THD of the last 0.2 s (Hann window, fundamental = +/-2 bins around f0)
tV=s.Vload_abc.time; mT=tV>tend-0.2+1e-12;
thd=nan(1,3); thd2k=nan(1,3); dtV=median(diff(tV(mT)));
if tend>=0.4
    for k=1:3
        x=s.Vload_abc.data(mT,k); n=numel(x); w=0.5-0.5*cos(2*pi*(0:n-1)'/n);
        S=abs(fft((x-mean(x)).*w)).^2; S=S(1:floor(n/2)); fb=(0:numel(S)-1)'/(n*dtV);
        [~,i1]=min(abs(fb-B.f0)); lobe=(i1-2:i1+2)';
        fund=sum(S(lobe)); rest=S; rest(lobe)=0; rest(1:3)=0;
        thd(k)=100*sqrt(sum(rest)/fund); thd2k(k)=100*sqrt(sum(rest(fb<=2000))/fund);
    end
end

if opt.save_wave
    W=struct('t',s.Vload_abc.time,'Vload_abc',s.Vload_abc.data,'t_i',s.iload_abc.time,'iload_abc',s.iload_abc.data, ...
        'events',[P.t_step_up P.t_step_down],'Vrms_set',B.Vrms,'f0',B.f0);
    wavePath=fullfile(folder,['wave_' label '.mat']);
    save(wavePath,'-struct','W','-v7'); clear W;
    fprintf('Wave file: %s\n',wavePath);
end
D=vsg_output_decimate(s,[P.t_step_up P.t_step_down]);
clear s;
g=D.t;
% duty envelope per 1 ms, sampled bus voltage, commanded profile
bin=floor(td/1e-3+1e-9)+1;
dlo=accumarray(bin,min(duty,[],2),[],@min); dhi=accumarray(bin,max(duty,[],2),[],@max);
gi=min(max(round(g/1e-3),1),numel(dlo));
D.duty_min=dlo(gi); D.duty_max=dhi(gi);
D.Vdc_sampled=interp1(tv,vdcS,g,'previous','extrap');
D.Vdc_profile=interp1(P.Vdc_t,P.Vdc_v,min(max(g,P.Vdc_t(1)),P.Vdc_t(end)));
% tail: last 40 ms of solver-rate inductor current and DC side
m=tl>=tend-0.04; D.tail_t=tl(m); D.tail_iL=iL(m,:);
m=ti>=tend-0.04; D.tail_tdc=ti(m); D.tail_Idc=idc(m);
m=tr>=tend-0.04; D.tail_trail=tr(m); D.tail_Vrail=vrail(m);
D.title=sprintf('%s (Vbus %.4g-%.4g V, Vrms %.4g V, SVPWM %g kHz, H %g, D %g)',info.model,min(P.Vdc_v),max(P.Vdc_v),B.Vrms,P.fsw/1e3,B.H,B.D);
D.Vrms_set=B.Vrms; D.f0=B.f0; D.fsw=P.fsw; D.duty_lim=[P.duty_min P.duty_max]; D.t_softstart=P.t_softstart;
matPath=fullfile(folder,['results_' label '.mat']);
if exist(matPath,'file'); vsg_backup_output(matPath); end
save(matPath,'-struct','D','-v7');

% ---- summary: settled value of each segment (last 40 %)
edges=unique([0 D.events(:)' tend]);
seg=struct('from_s',{},'to_s',{},'Vpos_rms',{},'Vrms_abc',{},'Irms',{},'P_W',{},'Q_var',{},'f_rotor_Hz',{},'Vdc_V',{});
for k=1:numel(edges)-1
    a=edges(k)+0.6*(edges(k+1)-edges(k)); b=edges(k+1); m=g>=a & g<=b;
    seg(end+1)=struct('from_s',edges(k),'to_s',edges(k+1),'Vpos_rms',mean(D.Vpos_rms(m)),'Vrms_abc',mean(D.Vrms(m,:),1), ...
        'Irms',mean(mean(D.Irms(m,:))),'P_W',mean(D.P_20ms(m)),'Q_var',mean(D.Q_20ms(m)), ...
        'f_rotor_Hz',mean(D.freq_int(m)),'Vdc_V',mean(D.Vdc_sampled(m))); %#ok<AGROW>
end
% ---- transients after each load step (20 ms rms windows), in % of the setpoint
ev=struct('t_s',{},'Vphase_min_pct',{},'Vphase_max_pct',{},'Vpos_min_pct',{},'Vpos_max_pct',{},'Vpos_last_outside_2pct_ms',{},'f_rotor_min_Hz',{},'f_rotor_max_Hz',{});
for k=1:numel(D.events)
    e=D.events(k); nxt=min([D.events(D.events>e); tend]); m=g>e & g<=min(e+1,nxt);
    vp=100*(D.Vrms(m,:)/B.Vrms-1); vs=100*(D.Vpos_rms(m)/B.Vrms-1); gm=g(m);
    lastOut=find(abs(vs)>2,1,'last'); if isempty(lastOut); rec=0; else; rec=1e3*(gm(lastOut)-e); end
    ev(end+1)=struct('t_s',e,'Vphase_min_pct',min(vp(:)),'Vphase_max_pct',max(vp(:)),'Vpos_min_pct',min(vs),'Vpos_max_pct',max(vs), ...
        'Vpos_last_outside_2pct_ms',rec,'f_rotor_min_Hz',min(D.freq_int(m)),'f_rotor_max_Hz',max(D.freq_int(m))); %#ok<AGROW>
end
% ---- start-up
mS=g<=min(tend,P.t_softstart+0.4);
startup=struct('v_peak_V',max(abs(D.wv1(:))),'v_peak_pct_of_setpoint_peak',100*max(abs(D.wv1(:)))/(B.Vrms*sqrt(2)), ...
    'Vrms_phase_max_V',max(max(D.Vrms(mS,:))),'i_peak_first_window_A',max(abs(D.wi1(:))));
% ---- duty use (after the first controller sample)
mD=td>P.t_softstart+0.05;
if ~any(mD); mD=td>2e-4; end
dz=duty(mD,:);
dutyUse=struct('min',min(dz(:)),'max',max(dz(:)),'samples_at_clamp',sum(any(dz<=P.duty_min+1e-9 | dz>=P.duty_max-1e-9,2)),'samples',size(dz,1));
% ---- bus: sign and tracking of the commanded profile
vprof=interp1(P.Vdc_t,P.Vdc_v,min(max(tv,P.Vdc_t(1)),P.Vdc_t(end)));
bus=struct('min_V',min(vdcS),'max_V',max(vdcS),'max_abs_error_vs_profile_V',max(abs(vdcS-vprof)));
assert(bus.min_V>0,'Measured DC rail is not positive: source polarity is wrong.');
% ---- inductor-current ripple, last 20 ms: remove the fundamental, p-p per carrier period
% (the 1 ms grid can end one ulp after the last log sample, which makes the last
% interpolated frequency NaN: take the last finite value)
mR=D.tail_t>=tend-0.02; tR=D.tail_t(mR); fr=D.freq_int(find(isfinite(D.freq_int),1,'last'));
A=[sin(2*pi*fr*tR) cos(2*pi*fr*tR) ones(numel(tR),1)];
nP=round(0.02*P.fsw); pp=nan(nP,3);
for k=1:3
    y=D.tail_iL(mR,k); res=y-A*(A\y);
    idx=min(floor((tR-(tend-0.02))*P.fsw)+1,nP);
    pp(:,k)=accumarray(idx,res,[nP 1],@max)-accumarray(idx,res,[nP 1],@min);
end
ripple=struct('pp_max_A',max(pp(:)),'pp_median_A',median(pp(:)),'i_peak_tail_A',max(abs(D.tail_iL(mR,:)),[],1), ...
    'estimate_Vdc_over_4Lf_fsw_A',mean(D.tail_Vrail)/(4*1.2e-3*P.fsw));
% ---- DC power over the last 20 ms
a=tend-0.02;
pdc=interp1(D.tail_trail,D.tail_Vrail,D.tail_tdc,'linear','extrap').*D.tail_Idc; mP=D.tail_tdc>=a;
Pdc=trapz(D.tail_tdc(mP),pdc(mP))/(D.tail_tdc(end)-D.tail_tdc(find(mP,1)));
dcSide=struct('P_dc_W',Pdc,'I_dc_mean_A',trapz(D.tail_tdc(mP),D.tail_Idc(mP))/(D.tail_tdc(end)-D.tail_tdc(find(mP,1))), ...
    'P_out_W',D.P_20ms(end),'efficiency_pct',100*D.P_20ms(end)/Pdc);

mA=g>P.t_softstart+0.3;
if ~any(mA); mA=true(size(g)); end
R=struct('label',label,'model_file',info.model_file,'model_sha256',info.model_sha256, ...
    'source_model_sha256',info.source_model_sha256,'builder_sha256',info.builder_sha256, ...
    'wall_seconds',wall,'maximum_step_s',opt.max_step,'params',info.params,'stage5j',info.stage5j, ...
    'derived',info.derived,'warnings',{info.warnings},'segments',seg,'load_steps',ev,'startup',startup, ...
    'duty',dutyUse,'bus',bus,'inductor_ripple',ripple,'dc_side',dcSide, ...
    'thd_V_pct_last_0p2s',thd,'thd_V_pct_up_to_2kHz',thd2k, ...
    'f_rotor_min_Hz',min(D.freq_int(mA)),'f_rotor_max_Hz',max(D.freq_int(mA)), ...
    'Vrms_phase_min_V',min(min(D.Vrms(mA,:))),'Vrms_phase_max_V',max(max(D.Vrms(mA,:))), ...
    'results_file',matPath, ...
    'scope','Simulation only (SPS MOSFET switching model). Stiff DC bus following the profile: no battery impedance or DC-link capacitor. Vdc sample is ideal. No current limit or PI anti-windup. No hardware qualification.');
repPath=fullfile(folder,['report_' label '.json']);
if exist(repPath,'file'); vsg_backup_output(repPath); end
fid=fopen(repPath,'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(R)); fclose(fid);

plots={fullfile(pyDir,'plot_vsg_output.py'),fullfile(folder,['plot_' label '.png']); ...
       fullfile(pyDir,'plot_stage5j.py'),fullfile(folder,['plot_' label '_bus_pwm.png'])};
for k=1:size(plots,1)
    cmd=sprintf('"%s" -I "%s" "%s" "%s"',opt.python,plots{k,1},matPath,plots{k,2});
    [st,msg]=system(cmd);
    if st==0
        fprintf('Plot: %s\n',plots{k,2});
        if opt.show; try; winopen(plots{k,2}); catch; end; end
    else
        warning('run_stage5j:plot','Plot failed (results are saved). Command:\n%s\n%s',cmd,msg);
    end
end

fprintf('\n%-12s %-9s %-9s %-9s %-9s %-10s %-8s\n','segment','V+ rms','I rms','P [W]','Q [var]','f [Hz]','Vdc');
for k=1:numel(seg)
    fprintf('%4.1f-%-6.1f %-9.3f %-9.3f %-9.1f %-9.1f %-10.4f %-8.2f\n',seg(k).from_s,seg(k).to_s,seg(k).Vpos_rms,seg(k).Irms,seg(k).P_W,seg(k).Q_var,seg(k).f_rotor_Hz,seg(k).Vdc_V);
end
for k=1:numel(ev)
    fprintf('step at %g s: phase Vrms %+.1f..%+.1f %%, V+ %+.1f..%+.1f %%, V+ inside 2%% after %.0f ms\n',ev(k).t_s,ev(k).Vphase_min_pct,ev(k).Vphase_max_pct,ev(k).Vpos_min_pct,ev(k).Vpos_max_pct,ev(k).Vpos_last_outside_2pct_ms);
end
fprintf('start-up peak %.2f V (%.0f %% of setpoint peak) | duty %.3f..%.3f, %d of %d samples at clamp\n',startup.v_peak_V,startup.v_peak_pct_of_setpoint_peak,dutyUse.min,dutyUse.max,dutyUse.samples_at_clamp,dutyUse.samples);
fprintf('bus %.2f..%.2f V | ripple max %.3f A p-p (median %.3f) | P_dc %.1f W, P_out %.1f W, eff %.1f %% | THD_V %.2f %%\n', ...
    bus.min_V,bus.max_V,ripple.pp_max_A,ripple.pp_median_A,Pdc,dcSide.P_out_W,dcSide.efficiency_pct,max(thd));
fprintf('STAGE5J_COMPLETE: %s (%.0f s wall)\n',repPath,wall);
end

function [t,d]=ts2mat(x)
if isstruct(x); t=x.time(:); d=x.signals.values; else; t=x.Time(:); d=x.Data; end
if size(d,1)~=numel(t); d=permute(d,[ndims(d),1:ndims(d)-1]); end
d=reshape(d,numel(t),[]);
end
