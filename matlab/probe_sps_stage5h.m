function probe_sps_stage5h
% Read-only library discovery for the gate-driven power-stage model.
folder=fullfile(fileparts(mfilename('fullpath')),'validation_outputs','stage5h');
if ~exist(folder,'dir'); mkdir(folder); end
load_system('powerlib');
names={'MOSFET','Mosfet','Series RLC Branch','DC Voltage Source','Current Measurement', ...
    'Voltage Measurement','Ground','Breaker','powergui'};
blocks=find_system('powerlib','LookUnderMasks','all','FollowLinks','on','Type','Block');
items={};
for k=1:numel(blocks)
    p=blocks{k}; name=get_param(p,'Name');
    if ~any(strcmpi(name,names)); continue; end
    item=struct('path',p,'name',name,'masktype',get_param(p,'MaskType'), ...
        'ports',get_param(p,'Ports'),'display',get_param(p,'MaskDisplay'));
    params=get_param(p,'DialogParameters'); vals=struct();
    if isstruct(params); fields=fieldnames(params); else; fields={}; end
    for j=1:numel(fields)
        f=fields{j}; vals.(f)=get_param(p,f);
    end
    item.parameters=vals;
    item.prompts=get_param(p,'MaskPrompts');
    items{end+1}=item;
end
fid=fopen(fullfile(folder,'library_probe.json'),'w');
fprintf(fid,'%s',jsonencode(items)); fclose(fid);
disp(ver('powersys'));
fprintf('STAGE5H_LIBRARY_PROBE_OK\n');
end
