function report = phase5e_robustness(output_dir)
% Bounded averaged-dq robustness study, MATLAB R2018b, no toolboxes needed.
% Stage 5d remains the PWM model. Here RK4 resolves an averaged LC/RL plant.
% Controller limit/AW algebra mirrors firmware, including FIXED 40 V duty
% normalization: bus sag reduces applied voltage (no invented bus sensor).
% Finite source parameters below are study assumptions, NOT measured BESS.
% No switch loss, PWM ripple, hardware comparator, gate driver or ADC timing
% fidelity is claimed. A 10 V stop is a model-validity boundary, not firmware.
root=fileparts(mfilename('fullpath'));
if nargin<1; output_dir=fullfile(root,'validation_outputs','stage5e'); end
if ~exist(output_dir,'dir'); mkdir(output_dir); end
p=struct('Ts',1e-4,'integration_step',1e-5,'duration',6,'event',3,'recover',4.5, ...
    'Lf',1.2e-3,'Rf',0.05,'Cf',10e-6,'Rd',1,'Ll',1e-3, ...
    'Kpv',0.00887592,'KivTs',0.000394384,'Kpi',7.5396,'KiiTs',0.031415, ...
    'Iref',10,'Vmax',20,'Vnom',40,'Vset',14,'w0',2*pi*50, ...
    'H',5,'D',0.5,'Rp',0.05,'Dq',0.007,'Pbase',100,'Klpf',0.00313176, ...
    'Cdc',2200e-6,'Rsource',0.30,'Isource',4,'delay',1, ...
    'deadtime',0,'sensor_step',0,'sensor_bias',0,'trip_current',10, ...
    'thermal_rated_mean_square',11.34,'thermal_limit',20,'minimum_bus',10);
firmware=fullfile(root,'..','hardware','esp32','vsg_controller','vsg_controller.ino');
source_identity=vsg_source_identity({[mfilename('fullpath') '.m'], ...
    fullfile(root,'vsg_firmware_control_step.m'), ...
    fullfile(root,'vsg_assert_firmware_parameters.m'),firmware});
vsg_assert_firmware_parameters(firmware,p);
cases={'nominal','load_step','load_rejection','overload','source_limit','nonideal'};
report=struct('schema_version',1,'scope','Averaged dq study, not HIL or bench validation', ...
    'parameters',p,'source_identity',source_identity,'cases',struct());
for c=1:numel(cases)
    name=cases{c}; q=p;
    if strcmp(name,'source_limit'); q.Isource=2.7; end
    if strcmp(name,'nonideal')
        q.deadtime=520e-9; q.sensor_step=0.01; q.sensor_bias=0.02; q.delay=2;
    end
    result=run_case(name,q);
    report.cases.(name)=result.metrics;
    path=fullfile(output_dir,[name '.mat']); vsg_backup_output(path);
    save(path,'result','q','-v7');
    fprintf('[Stage 5e] %s: pass=%d, bus min %.3f V, peak current %.3f A, fault %s\n', ...
        name,result.metrics.pass,result.metrics.minimum_bus,result.metrics.peak_current,result.metrics.fault);
end
report.pass=all(structfun(@(x)x.pass,report.cases));
report.pass_meaning='Test expectations met; not operating acceptance. Check each regulation_acceptable separately.';
vsg_assert_source_identity(source_identity);
report.limitations=['Averaged dq plant; nominal assumed Cdc/Rsource; no PWM/THD claims; ' ...
    'deadtime is fundamental opposing-current voltage approximation; sensor errors are dq-domain ' ...
    'quantization/bias; nonideal combines two-tick delay, not measured jitter; ' ...
    'thermal/OC are sampled model protections, not hardware shutdown validation; ' ...
    'balanced linear RL loads only: no unbalanced/nonlinear-load or THD inference; ' ...
    'faulted bridge uses an ideal zero-voltage surrogate, not diode/freewheel turn-off physics'];
path=fullfile(output_dir,'validation_stage5e.json'); vsg_backup_output(path);
fid=fopen(path,'w'); assert(fid>=0); fprintf(fid,'%s',jsonencode(report)); fclose(fid);
assert(report.pass,'VSG:Stage5eRegression','Stage 5e failed; inspect per-case JSON.');
end

function result=run_case(name,p)
N=round(p.duration/p.Ts)+1; t=(0:N-1)'*p.Ts;
x=zeros(7,1); x(7)=p.Vnom; state=struct('zv',zeros(2,1),'zi',zeros(2,1));
omega=p.w0; theta=0; pq=zeros(2,1); thermal=0;
queue=zeros(2,p.delay); log=zeros(N,18); fault='none'; triptime=NaN;
for k=1:N
    tk=t(k); R=2.94;
    if tk>=p.event && tk<p.recover
        if any(strcmp(name,{'load_step','source_limit','nonideal'})); R=2.94*0.7; end
        if strcmp(name,'load_rejection'); R=2.94*10; end
        if strcmp(name,'overload'); R=0.55; end
    end
    i=x(1:2); v=x(3:4)+p.Rd*(i-x(5:6));
    vm=v; im=i;
    if p.sensor_step>0
        vm=round(vm/p.sensor_step)*p.sensor_step+p.sensor_bias;
        im=round(im/p.sensor_step)*p.sensor_step+p.sensor_bias;
    end
    pq=pq+p.Klpf*([1.5*dot(vm,im);1.5*(vm(2)*im(1)-vm(1)*im(2))]-pq);
    E=p.Vset*min(tk/2,1);
    if tk>=2
        omega=omega+p.Ts*(1+(1-omega/p.w0)/p.Rp-pq(1)/p.Pbase-p.D*(omega-p.w0))/(2*p.H/p.w0);
        E=p.Vset-p.Dq*pq(2);
    end
    theta=mod(theta+omega*p.Ts,2*pi);
    phases=im(1)*cos(theta+[0;-2*pi/3;2*pi/3])-im(2)*sin(theta+[0;-2*pi/3;2*pi/3]);
    thermal=max(0,thermal+p.Ts*(mean(phases.^2)-p.thermal_rated_mean_square));
    if strcmp(fault,'none')
        if max(abs(phases))>p.trip_current; fault='sampled_overcurrent';
        elseif thermal>p.thermal_limit; fault='sampled_thermal';
        elseif x(7)<p.minimum_bus; fault='model_bus_boundary'; end
        if ~strcmp(fault,'none'); triptime=tk; end
    end
    if strcmp(fault,'none')
        [command,state,info]=vsg_firmware_control_step(vm,im,omega,E,state,p);
    else
        command=zeros(2,1);
        info=struct('reference',zeros(2,1),'current_saturated',false,'voltage_saturated',false);
    end
    applied=queue(:,1); queue=[queue(:,2:end),command];
    if ~strcmp(fault,'none')
        applied=zeros(2,1); queue(:)=0; state.zv(:)=0; state.zi(:)=0;
    end
    isource=min(max((p.Vnom-x(7))/p.Rsource,0),p.Isource);
    log(k,:)=[v',i',omega/(2*pi),x(7),isource,norm(info.reference),norm(command), ...
        info.current_saturated,info.voltage_saturated,norm(state.zv),norm(state.zi), ...
        strcmp(fault,'none'),R,pq(1),norm(applied),thermal];
    if k<N
        h=p.integration_step;
        for j=1:round(p.Ts/h)
            a=plant(x,applied,omega,R,p);
            b=plant(x+0.5*h*a,applied,omega,R,p);
            c=plant(x+0.5*h*b,applied,omega,R,p);
            d=plant(x+h*c,applied,omega,R,p);
            x=x+h*(a+2*b+2*c+d)/6;
        end
    end
end
pre=t>2.8 & t<2.95; final=t>5.8;
disturbed=t>p.event+0.8 & t<p.recover-0.1;
checks=struct('finite',all(isfinite(log(:))),'current_reference',max(log(:,8))<=p.Iref+1e-10, ...
    'voltage_command',max(log(:,9))<=p.Vmax+1e-10,'source_limit',max(log(:,7))<=p.Isource+1e-10, ...
    'source_nonnegative',min(log(:,7))>=0,'bus_bounded',min(log(:,6))>0 && max(log(:,6))<45, ...
    'integrator_bounded',max(log(:,12))<30 && max(log(:,13))<50);
if strcmp(name,'overload')
    checks.protection=strcmp(fault,'sampled_overcurrent') || strcmp(fault,'sampled_thermal');
    checks.fault_latched=all(log(t>triptime,14)==0);
    checks.zero_command_after_fault=all(log(t>=triptime,17)==0);
elseif strcmp(name,'source_limit')
    checks.source_exercised=any(log(:,7)>p.Isource-1e-6);
    checks.sag_visible=min(log(:,6))<37;
else
    checks.no_fault=strcmp(fault,'none');
    checks.voltage_recovered=abs(mean(log(final,1))-mean(log(pre,1)))<0.5;
    checks.frequency_bounded=all(log(:,5)>48 & log(:,5)<52);
end
metrics=struct('pass',all(structfun(@(z)logical(z),checks)),'checks',checks, ...
    'minimum_bus',min(log(:,6)),'peak_current',max(sqrt(sum(log(:,3:4).^2,2))), ...
    'fault',fault,'trip_time',triptime,'final_vd',mean(log(final,1)), ...
    'final_frequency',mean(log(final,5)),'current_clamp_ticks',sum(log(:,10)), ...
    'voltage_clamp_ticks',sum(log(:,11)));
metrics.expected_fault=strcmp(name,'overload');
metrics.protection_triggered=~strcmp(fault,'none') && ~strcmp(fault,'model_bus_boundary');
metrics.expected_degraded_regulation=strcmp(name,'source_limit') || strcmp(name,'overload');
metrics.mean_event_vd=mean(log(disturbed,1));
metrics.mean_event_bus=mean(log(disturbed,6));
metrics.regulation_acceptable=strcmp(fault,'none') && ...
    abs(metrics.mean_event_vd-p.Vset)<0.1*p.Vset && metrics.mean_event_bus>=0.9*p.Vnom;
metrics.regulation_criterion='During settled disturbance: vd within 10% of 14 V, bus >=36 V, no fault; not hardware acceptance';
metrics.transient_bus_below_36V=any(log(t>2.8,6)<36);
result=struct('time',t,'data',log,'columns',{{'vd','vq','id','iq','freq','Vdc','Isource', ...
    'Iref_mag','Vcmd_mag','I_clamp','V_clamp','V_integrator_mag','I_integrator_mag', ...
    'running','Rload','P_filtered','applied_command_mag','thermal_accumulator'}},'metrics',metrics);
end

function dx=plant(x,command,omega,R,p)
i=x(1:2); vc=x(3:4); il=x(5:6); v=vc+p.Rd*(i-il);
vinv=command*(max(x(7),0)/p.Vnom);
if p.deadtime>0 && norm(i)>1e-9
    vinv=vinv-(4/pi)*max(x(7),0)*p.deadtime/p.Ts*i/norm(i);
end
J=[0 -1;1 0];
isource=min(max((p.Vnom-x(7))/p.Rsource,0),p.Isource);
% Energy-conserving averaged bridge power; no unmodeled conversion efficiency.
pbridge=1.5*dot(vinv,i);
dx=[(vinv-v-p.Rf*i)/p.Lf-omega*J*i; ...
    (i-il)/p.Cf-omega*J*vc; (v-R*il)/p.Ll-omega*J*il; ...
    (isource-pbridge/max(x(7),1))/p.Cdc];
end
