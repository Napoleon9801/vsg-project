function report=test_vsg_validation()
% Portable regression tests for export rejection and saturation/AW behavior.
s=struct('a',struct('time',[0;1;2],'data',[1;2;3]), ...
    'b',struct('time',[0;0.5;1;1.5;2],'data',zeros(5,3)));
vsg_validate_signals(s); tests={'valid_multirate'};
bad=s; bad.b.time=[0;1;2]; reject(bad,'VSG:LengthMismatch'); tests{end+1}='reject_length';
bad=s; bad.a.time=[0;1;1]; reject(bad,'VSG:TimeOrder'); tests{end+1}='reject_duplicate';
bad=s; bad.a.time=[0;2;1]; reject(bad,'VSG:TimeOrder'); tests{end+1}='reject_reversed';
bad=s; bad.a.data(2)=NaN; reject(bad,'VSG:Nonfinite'); tests{end+1}='reject_nan';
bad=s; bad.a.time(2)=Inf; reject(bad,'VSG:Nonfinite'); tests{end+1}='reject_infinite_time';
bad=s; bad.a=rmfield(bad.a,'time'); reject(bad,'VSG:SignalSchema'); tests{end+1}='reject_missing_clock';
p=struct('Kpv',0.00887592,'KivTs',0.000394384,'Kpi',7.5396, ...
    'KiiTs',0.031415,'Cf',10e-6,'Lf',1.2e-3,'Iref',10,'Vmax',20);
state=struct('zv',[12;0],'zi',[0;0]);
[cmd,updated,info]=vsg_firmware_control_step([0;0],[0;0],314,14,state,p);
assert(info.current_saturated && info.voltage_saturated);
assert(abs(norm(info.reference)-10)<1e-12 && abs(norm(cmd)-20)<1e-12);
assert(updated.zv(1)==state.zv(1) && updated.zi(1)==state.zi(1));
tests{end+1}='vector_limits_and_integrator_hold';
state.zv=[12;0];
[~,updated,info]=vsg_firmware_control_step([20;0],[0;0],314,14,state,p);
assert(info.current_saturated && updated.zv(1)<state.zv(1));
tests{end+1}='voltage_integrator_unwinds';
state=struct('zv',[0;0],'zi',[30;0]);
[~,updated,info]=vsg_firmware_control_step([0;0],[1;0],314,0,state,p);
assert(info.voltage_saturated && updated.zi(1)<state.zi(1));
tests{end+1}='current_integrator_unwinds';
identity=vsg_source_identity({[mfilename('fullpath') '.m']});
vsg_assert_source_identity(identity);
identity.sha256=repmat('0',1,64); caught=false;
try
    vsg_assert_source_identity(identity);
catch err
    assert(strcmp(err.identifier,'VSG:SourceChanged')); caught=true;
end
assert(caught,'Stale source manifest was incorrectly accepted.');
tests{end+1}='reject_stale_source_manifest';
report=struct('pass',true,'count',numel(tests),'tests',{tests});
fprintf('VSG validation unit tests: %d passed.\n',numel(tests));
end

function reject(signals,id)
caught=false;
try
    vsg_validate_signals(signals);
catch err
    assert(strcmp(err.identifier,id),'Expected %s, received %s',id,err.identifier);
    caught=true;
end
assert(caught,'Malformed export was incorrectly accepted.');
end
