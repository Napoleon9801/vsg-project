function report=vsg_motor_ideal_source_check(output_dir)
% Independently integrate motor alone with MATLAB's variable-step ODE45.
% Separates motor physics from LC/VSG control instability and fixed-step RK4.
root=fileparts(mfilename('fullpath'));
if nargin<1; output_dir=fullfile(root,'validation_outputs','motor_ideal_source'); end
if ~exist(output_dir,'dir'); mkdir(output_dir); end
p=vsg_motor_parameters();
identity=vsg_source_identity({[mfilename('fullpath') '.m'],fullfile(root,'vsg_motor_rhs.m'), ...
    fullfile(root,'vsg_motor_parameters.m')});
options=odeset('RelTol',1e-9,'AbsTol',1e-11,'MaxStep',1e-3);
[time,state]=ode45(@(t,z)vsg_motor_rhs(z,[14;0],p.w0,p.motor,1,false),[0,2],zeros(5,1),options);
[dz,observed]=vsg_motor_rhs(state(end,:)',[14;0],p.w0,p.motor,1,false);
tail=time>1.8;
report=struct('scope','Hypothetical motor alone on ideal14Vpeak50Hz source; not inverter performance', ...
    'parameters',p.motor,'source_identity',identity,'voltage_peak',14,'frequency_hz',50, ...
    'speed_rad_s',state(end,5),'speed_rpm',state(end,5)*60/(2*pi), ...
    'stator_current_rms',norm(observed.stator_current)/sqrt(2),'torque',observed.torque, ...
    'input_power',observed.input_power,'shaft_power',observed.shaft_load_power, ...
    'tail_speed_peak_to_peak',max(state(tail,5))-min(state(tail,5)), ...
    'final_state_derivative_norm',norm(dz),'observed',observed);
report.pass=all(isfinite(state(:))) && report.tail_speed_peak_to_peak<0.01 && norm(dz)<0.01;
save(fullfile(output_dir,'ideal_source.mat'),'time','state','report','-v7');
vsg_assert_source_identity(identity);
fid=fopen(fullfile(output_dir,'ideal_source.json'),'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(report)); fclose(fid);
fprintf('IDEAL_MOTOR: pass=%d speed=%.6frpm shaft=%.6fW torque=%.9fNm\n', ...
    report.pass,report.speed_rpm,report.shaft_power,report.torque);
assert(report.pass,'VSG:IdealMotor','Motor-only equilibrium did not converge.');
end
