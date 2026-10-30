function target = layout_stage5h_mosfet
% Presentation copy: preserve block parameters and net connectivity;
% redraw existing net routing without rebuilding the electrical components.
root = fileparts(mfilename('fullpath'));
folder = fullfile(root,'validation_outputs','stage5h');
source = fullfile(folder,'vsg_stage5h_mosfet.slx');
target = fullfile(folder,'vsg_stage5h_mosfet_layout.slx');
model = 'vsg_stage5h_mosfet_layout';
assert(~bdIsLoaded(model),'Close the existing layout copy before regenerating.');
stamp = datestr(now,'yyyymmdd_HHMMSS');
copyfile(source,fullfile(folder,['vsg_stage5h_mosfet.before_layout_' stamp '.slx']));
if exist(target,'file'); copyfile(target,[target '.backup_' stamp]); end
copyfile(source,target);
open_system(target);
plan = jsondecode(fileread(fullfile(folder,'layout_plan_2026-10-30.json')));
for s=1:numel(plan)
    if isempty(plan(s).scope); scope=model;
    else; scope=[model '/' plan(s).scope]; end
    oldnotes=find_system(scope,'SearchDepth',1,'FindAll','on','Type','annotation');
    % Keep original explanatory notes, below the new section layout.
    for i=1:numel(oldnotes)
        set_param(oldnotes(i),'Position',[50 2850+100*(i-1)]);
    end
    for b=1:numel(plan(s).blocks)
        item=plan(s).blocks(b);
        block=Simulink.ID.getHandle([model ':' item.sid]);
        assert(strcmp(get_param(block,'Name'),item.name),'SID/name mismatch');
        set_param(block,'Position',item.position(:)', ...
            'BackgroundColor',item.color,'FontName','Arial','FontSize','10');
    end
    for a=1:numel(plan(s).headings)
        item=plan(s).headings(a);
        note=Simulink.Annotation(scope,item.text);
        note.Position=item.position(:)';
        note.FontName='Arial'; note.FontSize=15; note.FontWeight='bold';
        note.ForegroundColor='blue';
    end
    % Recreate routing from the source XML net terminal sets. No signal names,
    % logging attributes or custom line properties exist on these source nets.
    % Independent XML verification checks every net and block parameter.
    lines=find_system(scope,'FindAll','on','SearchDepth',1,'Type','line');
    roots=[];
    for j=1:numel(lines)
        if get_param(lines(j),'LineParent')==-1; roots(end+1)=lines(j); end %#ok<AGROW>
    end
    for j=1:numel(roots)
        if ishandle(roots(j)); delete_line(roots(j)); end
    end
    for j=1:numel(plan(s).nets)
        net=plan(s).nets(j); ports=zeros(numel(net.ports),1);
        xy=zeros(numel(net.ports),2);
        for k=1:numel(net.ports)
            token=regexp(net.ports{k},'^(\d+)#(\w+):(\d+)$','tokens','once');
            block=Simulink.ID.getHandle([model ':' token{1}]);
            fields=get_param(block,'PortHandles');
            types={'in','out','lconn','rconn','enable','trigger','reset'};
            names={'Inport','Outport','LConn','RConn','Enable','Trigger','Reset'};
            idx=find(strcmp(types,token{2}),1);
            ports(k)=fields.(names{idx})(str2double(token{3}));
            xy(k,:)=get_param(ports(k),'Position');
        end
        if net.physical
            % Short spanning tree, preserving the complete undirected net.
            connected=1; remaining=2:numel(ports);
            while ~isempty(remaining)
                best=inf; a=0; b=0;
                for c=connected
                    for r=remaining
                        distance=sum(abs(xy(c,:)-xy(r,:)));
                        if distance<best; best=distance; a=c; b=r; end
                    end
                end
                add_line(scope,ports(a),ports(b),'autorouting','on');
                connected(end+1)=b; remaining(remaining==b)=[];
            end
        else
            for k=2:numel(ports)
                add_line(scope,ports(1),ports(k),'autorouting','on');
            end
        end
    end
    set_param(scope,'ZoomFactor','FitSystem');
end
save_system(model,target);
fprintf('STAGE5H_LAYOUT_SAVED: %s\n',target);
figures=fullfile(root,'..','docs','figures');
for s=1:numel(plan)
    if isempty(plan(s).scope); scope=model; label='overview';
    else; scope=[model '/' plan(s).scope]; label='circuit'; end
    open_system(scope);
    set_param(scope,'ZoomFactor','FitSystem'); drawnow;
    pause(1);
    set_param(scope,'PaperPositionMode','auto');
    % R2018b on this display clips offscreen blocks at explicit -r120.
    % Screen resolution -r0 was visually verified to export the whole system.
    print(['-s' scope],'-dpng','-r0',fullfile(figures,['stage5h_layout_' label '_2026-10-30.png']));
end
open_system(model); set_param(model,'ZoomFactor','FitSystem');
fprintf('STAGE5H_LAYOUT_DONE\n');
end
