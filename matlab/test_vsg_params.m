function R = test_vsg_params()
% TEST_VSG_PARAMS  Checks that the central-parameter model (apply_vsg_params) is
% equivalent to the tested E1.2 FF model at default values, and that VDC and the
% load-step times act as intended. Writes validation_outputs/vsg_params/test_vsg_params.json.
% Run in a fresh MATLAB R2018b process (about 4 minutes).
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','vsg_params');
source=fullfile(root,'validation_outputs','e12_ff_load_cycle','vsg_e12_ff_load_cycle.slx');
srcHash=hash(source);
T=0.8;

% ---- 1. static: every linked parameter evaluates to the old value at defaults
P0=vsg_params('stop_time',T);
info=apply_vsg_params(P0,'default');
load_system(source); [~,srcModel]=fileparts(source);
oldVars=wsStruct(get_param(srcModel,'ModelWorkspace'));
load_system(info.model_file);
newVars=wsStruct(get_param(info.model,'ModelWorkspace'));
worst=0; rows={};
for k=1:numel(info.changes)
    c=info.changes{k};
    a=evalWith(c.old,oldVars); b=evalWith(c.new,newVars);
    assert(isequal(size(a),size(b)),'Size mismatch in %s/%s',c.block,c.param);
    rel=max(abs(a(:)-b(:))./max(abs(a(:)),1e-12));
    worst=max(worst,rel);
    rows{end+1}=sprintf('%s | %s | %s -> %s | rel %.2e',strrep(c.block,sprintf('\n'),' '),c.param,c.old,c.new,rel); %#ok<AGROW>
end
fprintf('%s\n',rows{:});
fprintf('STATIC worst relative difference = %.3e over %d parameters\n',worst,numel(info.changes));
R.static_worst_rel=worst; R.static_n=numel(info.changes);
close_system(info.model,0);

% ---- 2. dynamic: original vs parametric default, Vdc 60, custom step times
cases={ ...
  'original', '', []; ...
  'default',  'default', P0; ...
  'vdc60',    'vdc60', vsg_params('Vdc',60,'stop_time',T); ...
  'steps',    'steps', vsg_params('t_step_up',0.40,'t_step_down',0.60,'stop_time',T)};
S=struct();
for k=1:size(cases,1)
    if isempty(cases{k,2})
        mdl=srcModel;
    else
        inf2=apply_vsg_params(cases{k,3},cases{k,2}); load_system(inf2.model_file); mdl=inf2.model;
    end
    in=Simulink.SimulationInput(mdl);
    in=in.setModelParameter('StopTime',num2str(T),'ReturnWorkspaceOutputs','on');
    tic; out=sim(in); wall=toc;
    S.(cases{k,1})=grab(out); S.(cases{k,1}).wall=wall;
    fprintf('SIM %s done in %.1f s\n',cases{k,1},wall);
    if ~strcmp(mdl,srcModel); close_system(mdl,0); end
end
close_system(srcModel,0);

o=S.original; d=S.default;
g=(0.05:1e-3:T)';
dv=interp1(d.t,d.v,g)-interp1(o.t,o.v,g);
R.default_vs_original_max_abs_V=max(abs(dv(:)));
R.default_vs_original_rms_V=sqrt(mean(dv(:).^2));
win=@(s,a,b) s.t>=a & s.t<b;
rmsw=@(s,f,a,b) sqrt(mean(s.(f)(win(s,a,b),:).^2,1));
R.vdc60_Vrms_0p5_0p8=rmsw(S.vdc60,'v',0.5,0.8);
R.default_Vrms_0p5_0p8=rmsw(d,'v',0.5,0.8);
R.vdc60_Vrms_rel_diff=max(abs(R.vdc60_Vrms_0p5_0p8./R.default_Vrms_0p5_0p8-1));
s=S.steps;
R.steps_Irms_before=rmsw(s,'i',0.30,0.40);
R.steps_Irms_during=rmsw(s,'i',0.50,0.60);
R.steps_Irms_after=rmsw(s,'i',0.70,0.80);
R.predicted_I_low=P0.derived.I_low_A; R.predicted_I_high=P0.derived.I_high_A;
R.wall_s=structfun(@(x) x.wall,S)';
R.source_unchanged=strcmp(hash(source),srcHash);
fprintf('TEST_RESULT %s\n',jsonencode(R));
fid=fopen(fullfile(folder,'test_vsg_params.json'),'w'); fprintf(fid,'%s',jsonencode(R)); fclose(fid);
assert(R.source_unchanged,'Source model changed.');
end

function s=grab(out)
[s.t,s.v]=ts2mat(out.get('Vload_abc_ts'));
[ti,iv]=ts2mat(out.get('iload_abc_ts'));
s.i=interp1(ti,iv,s.t);
end

function [t,d]=ts2mat(x)
if isstruct(x); t=x.time(:); d=x.signals.values; else; t=x.Time(:); d=x.Data; end
if size(d,1)~=numel(t); d=permute(d,[ndims(d),1:ndims(d)-1]); end
d=reshape(d,numel(t),[]);
end

function S=wsStruct(mw)
S=struct(); w=mw.whos;
for k=1:numel(w); S.(w(k).name)=mw.getVariable(w(k).name); end
end

function val=evalWith(expr__,S__)
f__=fieldnames(S__);
for k__=1:numel(f__); eval([f__{k__} '=S__.(f__{k__});']); end
val=eval(expr__);
end

function hex=hash(file)
fid=fopen(file,'rb'); bytes=fread(fid,Inf,'*uint8'); fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256'); md.update(bytes);
hex=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
