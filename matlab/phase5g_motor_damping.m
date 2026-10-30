function report=phase5g_motor_damping(output_dir)
% Bounded exploratory gain sweep; intentionally NOT current firmware settings.
root=fileparts(mfilename('fullpath'));
if nargin<1; output_dir=fullfile(root,'validation_outputs','stage5g'); end
if ~exist(output_dir,'dir'); mkdir(output_dir); end
p=vsg_motor_parameters();
firmware=fullfile(root,'..','hardware','esp32','vsg_controller','vsg_controller.ino');
vsg_assert_firmware_parameters(firmware,p);
identity=vsg_source_identity({[mfilename('fullpath') '.m'],fullfile(root,'vsg_motor_parameters.m'), ...
    fullfile(root,'vsg_motor_run_case.m'),fullfile(root,'vsg_motor_plant_rhs.m'), ...
    fullfile(root,'vsg_motor_rhs.m'),fullfile(root,'vsg_firmware_control_step.m'),firmware});
report=struct('scope','Exploratory simulation-only voltage PI damping sweep; firmware unchanged', ...
    'source_identity',identity,'firmware_parameter_mirror',false,'cases',struct());
factors=[4,8,12];
for n=1:numel(factors)
    q=p; q.Kpv=p.Kpv*factors(n); q.KivTs=p.KivTs*0.25;
    name=sprintf('kp_x%d_ki_x025',factors(n));
    result=vsg_motor_run_case('motor_cold_start',q);
    report.cases.(name)=struct('Kpv',q.Kpv,'KivTs',q.KivTs,'metrics',result.metrics);
    save(fullfile(output_dir,[name '.mat']),'result','-v7');
    fprintf('[Stage 5g] %s: screen=%d numerical=%d rpm=%.2f speed_pp=%.3f voltage_pp=%.3f Ipk=%.3f fault=%s\n', ...
        name,result.metrics.settled_operation_screen,result.metrics.numerical_checks_pass,result.metrics.final_rpm, ...
        result.metrics.tail_speed_peak_to_peak,result.metrics.tail_voltage_magnitude_peak_to_peak, ...
        result.metrics.peak_inverter_current,result.metrics.firmware_fault);
end
vsg_assert_source_identity(identity);
fid=fopen(fullfile(output_dir,'validation_stage5g.json'),'w'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(report)); fclose(fid);
end
