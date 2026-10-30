function check_stage5h_layout
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5h');
names={'vsg_stage5h_mosfet','vsg_stage5h_mosfet_layout'};
outs=cell(1,2);
for i=1:2
    open_system(fullfile(folder,[names{i} '.slx']));
    in=Simulink.SimulationInput(names{i});
    in=in.setModelParameter('StopTime','0.02','ReturnWorkspaceOutputs','on');
    outs{i}=sim(in);
    fprintf('LAYOUT_SMOKE_RUN_OK: %s\n',names{i});
end
vars=outs{1}.who;
checks=struct('name',{},'identical_time',{},'max_abs_difference',{},'pass',{});
for k=1:numel(vars)
    a=outs{1}.get(vars{k}); b=outs{2}.get(vars{k});
    if ~isa(a,'timeseries'); continue; end
    same=isequal(a.Time,b.Time) && isequal(size(a.Data),size(b.Data));
    if same; err=max(abs(double(a.Data(:))-double(b.Data(:)))); else; err=inf; end
    checks(end+1)=struct('name',vars{k},'identical_time',same,'max_abs_difference',err, ...
        'pass',same && all(isfinite(a.Data(:))) && all(isfinite(b.Data(:))) && err<=1e-12); %#ok<AGROW>
end
assert(~isempty(checks),'No logged timeseries compared');
report=struct('stop_time',0.02,'checks',checks,'pass',all([checks.pass]), ...
    'scope','Short startup regression, not a new full 3 s validation');
fid=fopen(fullfile(folder,'layout_smoke_comparison_2026-10-30.json'),'w');
fprintf(fid,'%s\n',jsonencode(report)); fclose(fid);
assert(report.pass,'Layout startup regression differs');
fprintf('STAGE5H_LAYOUT_SMOKE_IDENTICAL: %d timeseries\n',numel(checks));
close_system(names{1},0);
model=names{2};
set_param(model,'Location',[40 40 1594 922]);
for s=1:2
    if s==1; scope=model;label='overview';
    else; scope=[model '/Gate_Driver_and_MOSFET_Circuit'];label='circuit';end
    open_system(scope); set_param(scope,'ZoomFactor','20'); drawnow;pause(1);
    out=fullfile(root,'..','docs','figures',['stage5h_layout_' label '_2026-10-30']);
    print(['-s' scope],'-dpng','-r0',[out '.png']);
    print(['-s' scope],'-dpdf',[out '.pdf']);
end
open_system(model);set_param(model,'ZoomFactor','FitSystem');
fprintf('STAGE5H_LAYOUT_REVIEW_READY\n');
end
