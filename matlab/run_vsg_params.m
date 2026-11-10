function R = run_vsg_params(P,label,varargin)
% RUN_VSG_PARAMS  One call: build the parametric model, simulate, save, plot.
%
%   P = vsg_params('t_step_up',2,'t_step_down',4,'stop_time',6,'H',10);
%   run_vsg_params(P,'h10');
%
% Writes to matlab/validation_outputs/vsg_params/:
%   vsg_param_<label>.slx         model (open it to inspect or rerun)
%   results_<label>.mat           decimated output signals (1 ms grid + raw windows)
%   report_<label>.json           parameters, derived values, summary numbers
%   plot_<label>.png              same layout as docs/figures/e12_output_overview_2026-11-10.png
% Options: 'show' (true)  open the PNG when done
%          'python' ('python')  interpreter used for the plot (needs numpy/scipy/matplotlib)
% Time: about 50 s of wall clock per simulated second (MaxStep 2.5 us, switching model).
% Run it in a MATLAB that does not have the same vsg_param_<label> model open.
opt=struct('show',true,'python','python');
for k=1:2:numel(varargin); opt.(varargin{k})=varargin{k+1}; end
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','vsg_params');
plotScript=fullfile(fileparts(root),'python','analysis','plot_vsg_output.py');

info=apply_vsg_params(P,label);
load_system(info.model_file);
cl=onCleanup(@() close_system(info.model,0)); %#ok<NASGU>
fprintf('Simulating %s for %g s (about %.0f min)...\n',info.model,P.stop_time,P.stop_time*50/60);
in=Simulink.SimulationInput(info.model);
in=in.setModelParameter('StopTime',num2str(P.stop_time,16),'ReturnWorkspaceOutputs','on');
tic; out=sim(in); wall=toc;

vars={'Vload_abc_ts','iload_abc_ts','sec_freq_Hz_ts','P_ts','Q_ts'};
names={'Vload_abc','iload_abc','freq','P_meas','Q_meas'};
s=struct();
for k=1:numel(vars)
    [tt,dd]=ts2mat(out.get(vars{k}));
    s.(names{k})=struct('time',tt,'data',dd);
end
clear out;
assert(s.Vload_abc.time(end)>=P.stop_time-1e-8 && all(isfinite(s.Vload_abc.data(:))),'Run incomplete or non-finite.');

D=vsg_output_decimate(s,[P.t_step_up P.t_step_down]);
clear s;
D.title=sprintf('%s (H %g, D %g, Rp %g, Vdc %g V, Vrms %.2f V, f0 %g Hz)',info.model,P.H,P.D,P.Rp,P.Vdc,P.Vrms,P.f0);
D.Vrms_set=P.Vrms; D.f0=P.f0;
matPath=fullfile(folder,['results_' label '.mat']);
if exist(matPath,'file'); vsg_backup_output(matPath); end
save(matPath,'-struct','D','-v7');

% summary per segment (last 40% of each segment = settled values)
edges=unique([0 D.events(:)' P.stop_time]);
seg=struct('from_s',{},'to_s',{},'Vpos_rms',{},'Irms',{},'P_W',{},'Q_var',{},'f_rotor_Hz',{});
for k=1:numel(edges)-1
    a=edges(k)+0.6*(edges(k+1)-edges(k)); b=edges(k+1);
    m=D.t>=a & D.t<=b;
    seg(end+1)=struct('from_s',edges(k),'to_s',edges(k+1),'Vpos_rms',mean(D.Vpos_rms(m)), ...
        'Irms',mean(mean(D.Irms(m,:))),'P_W',mean(D.P_20ms(m)),'Q_var',mean(D.Q_20ms(m)), ...
        'f_rotor_Hz',mean(D.freq_int(m))); %#ok<AGROW>
end
m=D.t>0.2;
R=struct('label',label,'model_file',info.model_file,'wall_seconds',wall,'params',info.params, ...
    'derived',info.derived,'warnings',{info.warnings},'segments',seg, ...
    'f_rotor_min_Hz',min(D.freq_int(m)),'f_rotor_max_Hz',max(D.freq_int(m)), ...
    'Vrms_phase_min_after_0p2s',min(min(D.Vrms(m,:))),'Vrms_phase_max_after_0p2s',max(max(D.Vrms(m,:))), ...
    'results_file',matPath,'scope','Simulation only; islanded E1.2 FF model with user parameters.');
fid=fopen(fullfile(folder,['report_' label '.json']),'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(R)); fclose(fid);

pngPath=fullfile(folder,['plot_' label '.png']);
cmd=sprintf('"%s" -I "%s" "%s" "%s"',opt.python,plotScript,matPath,pngPath);
[st,msg]=system(cmd);
if st==0
    R.plot_file=pngPath;
    fprintf('Plot: %s\n',pngPath);
    if opt.show; try; winopen(pngPath); catch; end; end
else
    R.plot_file='';
    warning('run_vsg_params:plot','Plot failed (results are saved). Command:\n%s\n%s',cmd,msg);
end
fprintf('\n%-12s %-10s %-10s %-10s %-10s %-10s\n','segment','V+ rms','I rms','P [W]','Q [var]','f [Hz]');
for k=1:numel(seg)
    fprintf('%4.1f-%-6.1f %-10.3f %-10.3f %-10.1f %-10.1f %-10.4f\n',seg(k).from_s,seg(k).to_s, ...
        seg(k).Vpos_rms,seg(k).Irms,seg(k).P_W,seg(k).Q_var,seg(k).f_rotor_Hz);
end
fprintf('rotor f range after 0.2 s: %.4f .. %.4f Hz | done in %.0f s\n',R.f_rotor_min_Hz,R.f_rotor_max_Hz,wall);
end

function [t,d]=ts2mat(x)
if isstruct(x); t=x.time(:); d=x.signals.values; else; t=x.Time(:); d=x.Data; end
if size(d,1)~=numel(t); d=permute(d,[ndims(d),1:ndims(d)-1]); end
d=reshape(d,numel(t),[]);
end
