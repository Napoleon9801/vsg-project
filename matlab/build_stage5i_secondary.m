function model=build_stage5i_secondary
% Add bounded secondary frequency restoration to the saved Stage 5h layout.
% Controller command limits are simulation assumptions, not power protection.
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5i');
if ~exist(folder,'dir'); mkdir(folder); end
model='vsg_stage5i_secondary'; target=fullfile(folder,[model '.slx']);
assert(~bdIsLoaded(model),'Close the Stage 5i model before rebuilding.');
source=fullfile(root,'validation_outputs','stage5h','vsg_stage5h_mosfet_layout.slx');
if exist(target,'file'); copyfile(target,[target '.backup_' datestr(now,'yyyymmdd_HHMMSS')]); end
copyfile(source,target); open_system(target);
notes=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(notes)
    title=get_param(notes(k),'Name');
    if strncmp(title,'STAGE 5h  |',11)
        set_param(notes(k),'Name',strrep(title,'STAGE 5h','STAGE 5i'));
    end
end
workspace=get_param(model,'ModelWorkspace');
parameters=struct('secondary_Ki',4,'secondary_Ts',1e-4,'secondary_enable_time',0.5, ...
    'secondary_enable',1,'secondary_min_pu',-0.5,'secondary_max_pu',0.8, ...
    'secondary_f_ref_Hz',50);
fields=fieldnames(parameters);
for k=1:numel(fields); assignin(workspace,fields{k},parameters.(fields{k})); end

base=Simulink.ID.getHandle([model ':1']);
sumPm=Simulink.ID.getHandle([model ':12']);
assert(strcmp(get_param(base,'Name'),'P_set'));
assert(strcmp(get_param(sumPm,'Name'),'Sum_Pm'));
hp=get_param(sumPm,'PortHandles'); oldline=get_param(hp.Inport(1),'Line');
assert(get_param(oldline,'SrcBlockHandle')==base,'Unexpected P_set wiring.');
delete_line(oldline);
sys=add(model,'built-in/SubSystem','Secondary_Frequency_Control',[2080 420 2400 610]);
sys=getfullname(sys);
omega=add(sys,'built-in/Inport','omega',[40 110 70 130],'Port','1');
pbase=add(sys,'built-in/Inport','P_base_pu',[40 440 70 460],'Port','2');
hz=add(sys,'built-in/Gain','Rad_s_to_Hz',[140 95 240 145],'Gain','1/(2*pi)');
ref=add(sys,'built-in/Constant','Frequency_reference_Hz',[140 210 240 245], ...
    'Value','secondary_f_ref_Hz');
err=add(sys,'built-in/Sum','Frequency_error_Hz',[340 155 385 205],'Inputs','+-');
active=add(sys,'built-in/Step','Enable_after_startup',[120 320 240 355], ...
    'Time','secondary_enable_time','Before','0','After','secondary_enable', ...
    'SampleTime','secondary_Ts');
reset=add(sys,'built-in/Logic','Reset_when_disabled',[340 320 410 355], ...
    'Operator','NOT');
enableBoolean=add(sys,'built-in/DataTypeConversion','Enable_boolean',[270 315 315 360], ...
    'OutDataTypeStr','boolean');
integ=add(sys,'built-in/DiscreteIntegrator','Bounded_secondary_integrator',[520 155 700 225], ...
    'IntegratorMethod','Integration: Forward Euler','gainval','secondary_Ki', ...
    'SampleTime','secondary_Ts','InitialCondition','0','ExternalReset','level', ...
    'LimitOutput','on','UpperSaturationLimit','secondary_max_pu', ...
    'LowerSaturationLimit','secondary_min_pu','ShowSaturationPort','on');
sum=add(sys,'built-in/Sum','Corrected_power_reference',[840 430 890 480],'Inputs','++');
join(sys,omega,1,hz,1); join(sys,ref,1,err,1); join(sys,hz,1,err,2);
join(sys,active,1,enableBoolean,1);join(sys,enableBoolean,1,reset,1);
join(sys,err,1,integ,1); join(sys,reset,1,integ,2);
join(sys,pbase,1,sum,1); join(sys,integ,1,sum,2);
sources={sum,hz,integ,err,active,integ}; sourcePorts=[1 1 1 1 1 2];
outNames={'P_ref_pu','f_Hz','delta_P_pu','freq_error_Hz','enabled','clamp_state'};
for k=1:6
    output=add(sys,'built-in/Outport',outNames{k},[1100 60+90*k 1140 80+90*k], ...
        'Port',num2str(k));
    join(sys,sources{k},sourcePorts(k),output,1);
end
note=Simulink.Annotation(sys,sprintf(['SECONDARY FREQUENCY RESTORATION\n' ...
    'e = 50 Hz - f; d(delta P)/dt = Ki*e; Ki = 4 pu/(Hz*s), Ts = 100 us\n' ...
    'Enable at 0.5 s; reset while disabled; integral state limited to [-0.5, +0.8] pu\n' ...
    'P_ref = P_base + delta P. These are command limits, not hardware protection.']));
note.Position=[40 15];note.FontSize=12;note.FontWeight='bold';

gbase=add(model,'built-in/Goto','Sec_Base_Goto',[230 320 365 350], ...
    'GotoTag','secondary_P_base_pu','TagVisibility','global');
fbase=add(model,'built-in/From','Sec_Base_From',[1830 540 2010 570], ...
    'GotoTag','secondary_P_base_pu');
fomega=add(model,'built-in/From','Sec_Omega_From',[1830 450 2010 480], ...
    'GotoTag','omega');
gpref=add(model,'built-in/Goto','Sec_Pref_Goto',[2490 420 2680 450], ...
    'GotoTag','secondary_P_ref_pu','TagVisibility','global');
fpref=add(model,'built-in/From','Sec_Pref_From',[360 270 530 300], ...
    'GotoTag','secondary_P_ref_pu');
join(model,base,1,gbase,1);join(model,fbase,1,get_param(sys,'Handle'),2);
join(model,fomega,1,get_param(sys,'Handle'),1);join(model,get_param(sys,'Handle'),1,gpref,1);
join(model,fpref,1,sumPm,1);
scope=add(model,'built-in/Scope','Scope_frequency_Hz',[2740 480 2850 535]);
join(model,get_param(sys,'Handle'),2,scope,1);
set_param(scope,'BackgroundColor','[0.88 1 0.88]');
names={'sec_P_ref_pu','sec_freq_Hz','sec_delta_P_pu','sec_freq_error_Hz','sec_enabled','sec_clamp_state'};
for k=1:6
    tag=['secondary_log_' num2str(k)];
    g=add(model,'built-in/Goto',['Sec_LogTag_' num2str(k)], ...
        [2490 465+28*(k-1) 2660 485+28*(k-1)],'GotoTag',tag,'TagVisibility','global');
    join(model,get_param(sys,'Handle'),k,g,1);
    x=50+650*mod(k-1,3); y=2820+100*floor((k-1)/3);
    f=add(model,'built-in/From',['Sec_LogFrom_' num2str(k)],[x y x+180 y+30],'GotoTag',tag);
    tw=add(model,'built-in/ToWorkspace',['Log_' names{k}],[x+280 y x+500 y+35], ...
        'VariableName',[names{k} '_ts'],'SaveFormat','Timeseries','MaxDataPoints','inf');
    join(model,f,1,tw,1);
end
note=Simulink.Annotation(model,'11  SECONDARY CONTROL LOGS  |  delta P is in pu on a 100 W base');
note.Position=[50 2750];note.FontSize=15;note.ForegroundColor='blue';note.FontWeight='bold';
note=Simulink.Annotation(model,'SECONDARY FREQUENCY CONTROL  |  Restore 50 Hz');
note.Position=[1830 385];note.FontSize=12;note.ForegroundColor='blue';note.FontWeight='bold';
set_param(get_param(sys,'Handle'),'BackgroundColor','[0.85 1 0.90]');
set_param(model,'StopTime','6');
set_param(sys,'ZoomFactor','100');set_param(model,'ZoomFactor','20');
save_system(model,target);
fprintf('STAGE5I_BUILD_OK: %s\n',target);
end

function h=add(scope,type,name,position,varargin)
h=add_block(type,[scope '/' name],'Position',position,varargin{:});
set_param(h,'FontName','Arial','FontSize','10');
end
function join(scope,source,sourceIndex,target,targetIndex)
a=get_param(source,'PortHandles');b=get_param(target,'PortHandles');
add_line(scope,a.Outport(sourceIndex),b.Inport(targetIndex),'autorouting','on');
end
