function result = vsg_motor_run_case(name,p)
% Run one reproducible scenario; terminate at any fault/model boundary.
% Successful numerical checks do not imply a successful motor application.
assert(p.Ts/p.integration_step>=1 && abs(p.Ts/p.integration_step-round(p.Ts/p.integration_step))<1e-10, ...
    'VSG:IntegrationStep','Integration step must divide controller sample time.');
switch name
    case 'rl_reference'
        p.load_kind='rl';
    case 'motor_cold_start'
    case 'motor_direct_connection'
        p.connected_at=p.event;
    case 'motor_torque_step'
    case 'motor_locked_rotor'
        p.locked=true;
    case 'motor_source_limit'
        p.Isource=0.8; p.connected_at=p.event;
    case 'motor_nonideal'
        p.Rbridge=0.05; p.deadtime=520e-9;
    otherwise
        error('VSG:UnknownScenario','Unknown scenario: %s',name);
end
N=round(p.duration/p.Ts)+1;
x=zeros(20,1); x(12)=p.Vnom; energy_initial=0.5*p.Cdc*p.Vnom^2;
state=struct('zv',zeros(2,1),'zi',zeros(2,1));
omega=p.w0; pq=zeros(2,1); thermal=0;
queue=zeros(2,p.delay); stationary=zeros(2,1);
columns={'vd','vq','id','iq','freq','Vdc','Isource','omega_m','rpm','slip', ...
    'torque_e','torque_load','stator_current_mag','rotor_current_mag','P_motor', ...
    'P_copper','P_friction','P_shaft_load','P_filter_loss','P_bridge_loss', ...
    'Iref_mag','Vcmd_mag','current_clamp','voltage_clamp','thermal_accumulator', ...
    'connected','stored_energy','energy_residual','E_source','E_filter_loss', ...
    'E_bridge_loss','E_motor_copper','E_friction','E_shaft_load','E_RL_loss', ...
    'requested_duty_min','requested_duty_max','P_source','P_bridge_dc','P_bridge_output','P_RL_loss'};
data=zeros(N,numel(columns)); time=(0:N-1)'*p.Ts;
termination='completed'; fault='none'; trip_time=NaN;
last_duty=[0.5;0.5;0.5]; info=struct('reference',zeros(2,1),'current_saturated',false,'voltage_saturated',false);
command=zeros(2,1);
for k=1:N
    tk=time(k); connected=tk>=p.connected_at;
    multiplier=p.torque_multiplier;
    if strcmp(name,'motor_torque_step') && tk>=p.event; multiplier=1.8*multiplier; end
    [~,obs]=vsg_motor_plant_rhs(x,stationary,omega,p,connected,multiplier);
    i=x(1:2); v=obs.voltage;
    phase=i(1)*cos(x(13)+[0;-2*pi/3;2*pi/3])-i(2)*sin(x(13)+[0;-2*pi/3;2*pi/3]);
    thermal=max(0,thermal+p.Ts*(mean(phase.^2)-p.thermal_rated_mean_square));
    if max(abs(phase))>p.trip_current
        termination='firmware_fault'; fault='sampled_overcurrent'; trip_time=tk;
    elseif thermal>p.thermal_limit
        termination='firmware_fault'; fault='sampled_thermal'; trip_time=tk;
    elseif ~all(isfinite(x)) || x(12)<p.minimum_bus || x(12)>p.maximum_bus
        termination='model_boundary'; fault='none';
    end
    if strcmp(termination,'completed')
        pq=pq+p.Klpf*([1.5*dot(v,i);1.5*(v(2)*i(1)-v(1)*i(2))]-pq);
        E=p.Vset*min((tk+p.Ts)/2,1);
        if tk>=2
            omega=omega+p.Ts*(1+(1-omega/p.w0)/p.Rp-pq(1)/p.Pbase-p.D*(omega-p.w0))/(2*p.H/p.w0);
            E=p.Vset-p.Dq*pq(2);
        end
        [command,state,info]=vsg_firmware_control_step(v,i,omega,E,state,p);
        % Firmware advances angle once before inverse Park. Queue stationary
        % alpha/beta commands, so a delayed PWM period holds physical phase duty.
        theta_cmd=x(13)+omega*p.Ts;
        ab=[cos(theta_cmd)*command(1)-sin(theta_cmd)*command(2); ...
            sin(theta_cmd)*command(1)+cos(theta_cmd)*command(2)];
        phases=[ab(1);-0.5*ab(1)+sqrt(3)/2*ab(2);-0.5*ab(1)-sqrt(3)/2*ab(2)];
        duty=min(max(0.5+phases/p.Vnom,p.duty_min),p.duty_max);
        clipped=p.Vnom*(duty-0.5);
        ab=[(2/3)*(clipped(1)-0.5*clipped(2)-0.5*clipped(3));(clipped(2)-clipped(3))/sqrt(3)];
        stationary=queue(:,1); queue=[queue(:,2:end),ab]; last_duty=duty;
    end
    residual=obs.stored_energy-energy_initial-x(14)+sum(x(15:20));
    mo=obs.motor;
    % States and powers are sampled at the left limit (old held command).
    % freq and requested_duty fields are NEW controller outputs; these duties
    % enter the delay queue and must not be read as currently applied duty.
    data(k,:)=[v',i',omega/(2*pi),x(12),obs.source_current,x(11),x(11)*60/(2*pi), ...
        (omega-p.motor.pole_pairs*x(11))/omega,mo.torque,mo.load_torque, ...
        norm(mo.stator_current),norm(mo.rotor_current),mo.input_power,mo.copper_loss, ...
        mo.friction_loss,mo.shaft_load_power,obs.filter_loss,obs.bridge_loss, ...
        norm(info.reference),norm(command),info.current_saturated,info.voltage_saturated, ...
        thermal,connected,obs.stored_energy,residual,x(14:20)', ...
        min(last_duty),max(last_duty),obs.source_power,obs.bridge_dc_power,obs.bridge_output_power,obs.rl_loss];
    if ~strcmp(termination,'completed'); break; end
    if k<N
        h=p.integration_step;
        for j=1:round(p.Ts/h)
            a=vsg_motor_plant_rhs(x,stationary,omega,p,connected,multiplier);
            b=vsg_motor_plant_rhs(x+0.5*h*a,stationary,omega,p,connected,multiplier);
            c=vsg_motor_plant_rhs(x+0.5*h*b,stationary,omega,p,connected,multiplier);
            d=vsg_motor_plant_rhs(x+h*c,stationary,omega,p,connected,multiplier);
            x=x+h*(a+2*b+2*c+d)/6;
        end
    end
end
time=time(1:k); data=data(1:k,:);
tail=time>=max(time(end)-0.2,0);
numeric=struct('finite',all(isfinite(data(:))), ...
    'current_reference_limit',max(data(:,21))<=p.Iref+1e-9, ...
    'voltage_command_limit',max(data(:,22))<=p.Vmax+1e-9, ...
    'source_current_limit',max(data(:,7))<=p.Isource+1e-9 && min(data(:,7))>=0, ...
    'duty_limits',min(data(:,36))>=p.duty_min-1e-12 && max(data(:,37))<=p.duty_max+1e-12, ...
    'nonnegative_losses',min(min(data(:,16:20)))>=-1e-9, ...
    'energy_balance',max(abs(data(:,28)))<0.01+1e-3*max(data(:,29)));
metrics=struct('numerical_checks_pass',all(structfun(@(z)logical(z),numeric)), ...
    'numerical_checks',numeric,'termination',termination,'truncated',~strcmp(termination,'completed'), ...
    'requested_duration',p.duration,'actual_duration',time(end),'firmware_fault',fault,'trip_time',trip_time, ...
    'minimum_bus',min(data(:,6)),'maximum_bus',max(data(:,6)), ...
    'peak_inverter_current',max(sqrt(sum(data(:,3:4).^2,2))), ...
    'peak_stator_current',max(data(:,13)), 'final_speed_rad_s',mean(data(tail,8)), ...
    'final_rpm',mean(data(tail,9)),'final_slip',mean(data(tail,10)), ...
    'final_vd',mean(data(tail,1)),'final_frequency',mean(data(tail,5)), ...
    'final_shaft_load_power',mean(data(tail,18)), ...
    'max_energy_residual_J',max(abs(data(:,28))), ...
    'source_energy_J',data(end,29),'current_clamp_ticks',sum(data(:,23)), ...
    'voltage_clamp_ticks',sum(data(:,24)), ...
    'final_speed_change_over_tail',data(end,8)-data(find(tail,1),8));
metrics.motor_running=strcmp(p.load_kind,'motor') && ~p.locked && ~metrics.truncated && ...
    metrics.final_speed_rad_s>0 && metrics.final_slip>0 && metrics.final_slip<1;
metrics.application_rating_claim=false;
metrics.final_voltage_mag=mean(sqrt(sum(data(tail,1:2).^2,2)));
metrics.final_bus=mean(data(tail,6));
metrics.final_motor_input_W=mean(data(tail,15));
metrics.final_motor_current_rms=mean(data(tail,13))/sqrt(2);
metrics.tail_speed_peak_to_peak=max(data(tail,8))-min(data(tail,8));
vmag=sqrt(sum(data(tail,1:2).^2,2));
metrics.tail_voltage_magnitude_peak_to_peak=max(vmag)-min(vmag);
metrics.tail_frequency_peak_to_peak=max(data(tail,5))-min(data(tail,5));
metrics.settled_operation_screen=metrics.motor_running && metrics.final_slip<0.2 && ...
    metrics.tail_speed_peak_to_peak<0.5 && metrics.tail_voltage_magnitude_peak_to_peak<0.28 && ...
    metrics.tail_frequency_peak_to_peak<0.1 && ...
    abs(metrics.final_voltage_mag-p.Vset)<0.1*p.Vset && metrics.final_bus>=0.9*p.Vnom && ...
    metrics.final_frequency>=48 && metrics.final_frequency<=52;
metrics.screen_definition='Completed: 0<slip<0.2, final0.2s peak-to-peak speed<0.5rad/s, voltage magnitude<0.28V, frequency<0.1Hz; mean voltage14Vpeak +/-10%, bus>=36V,48..52Hz; study screen not rating/THD';
metrics.expected_fault='not prescribed; outcome characterized';
metrics.model_boundary_meaning='Vdc outside10..48V or nonfinite state; not firmware UV/OV behavior';
result=struct('scenario',name,'time',time,'data',data,'columns',{columns}, ...
    'parameters',p,'metrics',metrics,'final_state',x,'energy_initial',energy_initial);
end
