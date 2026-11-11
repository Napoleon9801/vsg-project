function run_stage5j_job(caseName)
% Batch entry for the Stage 5j cases (one isolated MATLAB process per case):
%   matlab -nosplash -nodesktop -wait -logfile stage5j_<case>.log -r "run_stage5j_job('nominal')"
%   smoke        0.4 s, 48 V, soft-start 0.1 s
%   smoke_step   0.4 s, 48 V, no soft-start (setpoint step, as in Stage 5i / E1.2)
%   nominal      11 s, 48 V, load 70 -> 100 W at 3 s, back at 7 s (same schedule as Stage 5i)
%   nominal_wave same as nominal, also saves wave_nominal_wave.mat (full Vload/iload)
%   bus_sweep    4 s, load 100 W from 0.8 s, bus 54.6 V -> 39 V between 1.5 and 2.5 s
try
    extra={};
    switch caseName
        case 'smoke'
            P=vsg_stage5j_params('t_step_up',50,'t_step_down',60,'stop_time',0.4);
        case 'smoke_step'
            P=vsg_stage5j_params('t_step_up',50,'t_step_down',60,'stop_time',0.4,'t_softstart',0);
        case 'nominal'
            P=vsg_stage5j_params();
        case 'nominal_wave'
            P=vsg_stage5j_params();
            extra={'save_wave',true};
        case 'bus_sweep'
            P=vsg_stage5j_params('t_step_up',0.8,'t_step_down',100,'stop_time',4, ...
                'Vdc_t',[0 1.5 2.5 4],'Vdc_v',[54.6 54.6 39 39]);
        otherwise
            error('Unknown case %s',caseName);
    end
    run_stage5j(P,caseName,extra{:});
catch err
    disp(getReport(err,'extended','hyperlinks','off'));
    fprintf('STAGE5J_JOB_FAILED: %s\n',caseName);
end
exit;
end
