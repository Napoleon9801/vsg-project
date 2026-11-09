function report=test_stage5i_secondary_limits
% Execute the actual secondary subsystem against known frequency inputs.
% Validates state clamping, unwind, enable/reset and gain/time units.
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5i');
source='vsg_stage5i_secondary';
open_system(fullfile(folder,[source '.slx']));
scope=find_system(source,'SearchDepth',1,'Name','Secondary_Frequency_Control');
assert(numel(scope)==1);
model='stage5i_secondary_test_harness';
assert(~bdIsLoaded(model));new_system(model);open_system(model);
workspace=get_param(model,'ModelWorkspace');
variables=struct('secondary_Ki',4,'secondary_Ts',1e-4,'secondary_enable_time',0.5, ...
    'secondary_enable',1,'secondary_min_pu',-0.5,'secondary_max_pu',0.8,'secondary_f_ref_Hz',50);
fields=fieldnames(variables);
for k=1:numel(fields);assignin(workspace,fields{k},variables.(fields{k}));end
assignin(workspace,'frequency_test_signal',[0 49.9*2*pi;0.6 49.9*2*pi]);
dut=add_block(scope{1},[model '/Secondary_Under_Test'],'Position',[300 80 560 300]);
freq=add_block('built-in/FromWorkspace',[model '/Injected_omega'], ...
    'Position',[30 80 180 115],'VariableName','frequency_test_signal','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value');
base=add_block('built-in/Constant',[model '/Base_power_pu'], ...
    'Position',[30 220 150 250],'Value','1');
connect(model,freq,1,dut,1);connect(model,base,1,dut,2);
names={'pref','freq','correction','error','enabled','clamp'};
for k=1:6
    log=add_block('built-in/ToWorkspace',[model '/Log_' names{k}], ...
        'Position',[680 30+70*k 820 60+70*k],'VariableName',[names{k} '_test'], ...
        'SaveFormat','Timeseries','MaxDataPoints','inf');
    connect(model,dut,k,log,1);
end
set_param(model,'Solver','FixedStepDiscrete','FixedStep','0.0001','StopTime','0.6', ...
    'ReturnWorkspaceOutputs','on');
save_system(model,fullfile(folder,[model '.slx']));
checks=struct('name',{},'pass',{},'measured',{});

in=Simulink.SimulationInput(model);out=sim(in);
d=out.get('correction_test');
checks(end+1)=item('zero_before_enable',max(abs(d.Data(d.Time<0.5)))<1e-12, ...
    max(abs(d.Data(d.Time<0.5))));
value=d.Data(end);
checks(end+1)=item('Ki_units_and_sample_time',abs(value-.04)<5e-5,value);

in=in.setVariable('secondary_enable',0,'Workspace',model);out=sim(in);
d=out.get('correction_test');p=out.get('pref_test');
checks(end+1)=item('disabled_correction_zero',all(abs(d.Data)<1e-12),max(abs(d.Data)));
checks(end+1)=item('disabled_base_reference_exact',all(abs(p.Data-1)<1e-12),max(abs(p.Data-1)));

in=Simulink.SimulationInput(model);
in=in.setModelParameter('StopTime','2.2');
in=in.setVariable('secondary_enable_time',0,'Workspace',model);
in=in.setVariable('frequency_test_signal', ...
    [0 49;0.9999 49;1 51;1.9999 51;2 49;2.2 49].*[ones(6,1),2*pi*ones(6,1)],'Workspace',model);
out=sim(in);d=out.get('correction_test');p=out.get('pref_test');flag=out.get('clamp_test');
checks(end+1)=item('upper_integrator_bound',abs(max(d.Data)-.8)<1e-12,max(d.Data));
checks(end+1)=item('lower_integrator_bound',abs(min(d.Data)+.5)<1e-12,min(d.Data));
checks(end+1)=item('total_command_bound',all(p.Data>=.5-1e-12 & p.Data<=1.8+1e-12), ...
    [min(p.Data) max(p.Data)]);
v=interp1(d.Time,d.Data,1.1,'previous');
checks(end+1)=item('unwind_from_upper_without_hidden_windup',abs(v-.4)<.001,v);
v=interp1(d.Time,d.Data,2.1,'previous');
checks(end+1)=item('unwind_from_lower_without_hidden_windup',abs(v+.1)<.001,v);
checks(end+1)=item('both_saturation_states_observed',any(flag.Data==1) && any(flag.Data==-1), ...
    unique(flag.Data)');
report=struct('scope','Actual copied secondary subsystem, no electrical plant', ...
    'checks',checks,'pass',all([checks.pass]));
fid=fopen(fullfile(folder,'secondary_limits_test_2026-11-06.json'),'w');
fprintf(fid,'%s\n',jsonencode(report));fclose(fid);
fprintf('STAGE5I_SUBSYSTEM_TESTS: %s\n',jsonencode(report));
assert(report.pass,'Secondary subsystem behavior test failed.');
close_system(model,0);close_system(source,0);
end
function s=item(name,pass,measured)
s=struct('name',name,'pass',logical(pass),'measured',measured);
end
function connect(model,a,ai,b,bi)
x=get_param(a,'PortHandles');y=get_param(b,'PortHandles');
add_line(model,x.Outport(ai),y.Inport(bi),'autorouting','on');
end
