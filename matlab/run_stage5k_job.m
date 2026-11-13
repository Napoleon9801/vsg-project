function run_stage5k_job(caseName)
% Batch entry for the Stage 5k cases (one isolated MATLAB process per case):
%   matlab -nosplash -nodesktop -wait -logfile stage5k_<case>.log -r "run_stage5k_job('tx9')"
% Transformer data are ASSUMED in every case (see vsg_stage5k_params.m).
% Load-current feed-forward (E1.2): at gain 1 the voltage loop is unstable once
% the transformer is added (growing ~41 Hz modulation of the rms voltage, duty
% reaches the clamp within 0.4 s; 'smoke', 'ff_g10s'). Gain 0 ('smoke_ff0',
% 'tx12', 'tx9') and gains up to 0.9 are stable. vsg_stage5k_params defaults to
% gain 0.8 ('tx9_ff08').
%   smoke      0.4 s, "230 V : 12 V" part, LV setpoint 12 Vrms, low load, FF ON (unstable, kept as evidence)
%   smoke_ff0  1 s,   same, FF off
%   tx12       3 s,   "230 V : 12 V" part, LV setpoint 12 Vrms, load 70 -> 100 W(nominal) at 1.5 s
%   tx9        11 s,  "230 V : 9 V" part, LV setpoint chosen for 230 V at the high load,
%              load 70 -> 100 W at 3 s, back at 7 s (same schedule as Stage 5i / 5j)
try
    switch caseName
        case 'smoke'       % gain 1 on purpose: the unstable evidence case
            P=vsg_stage5k_params('t_step_up',50,'t_step_down',60,'stop_time',0.4,'ff_gain',1);
        case 'tx9_ff08'    % 11 s, "230 V : 9 V" part, default feed-forward gain 0.8, Stage 5i / 5j schedule
            P=vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true);
        case 'smoke_ff0'
            P=vsg_stage5k_params('t_step_up',50,'t_step_down',60,'stop_time',1,'ff_on',0);
        case 'tx12'
            P=vsg_stage5k_params('t_step_up',1.5,'t_step_down',60,'stop_time',3,'ff_on',0);
        case 'tx9'
            P=vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true,'ff_on',0);
        % feed-forward study on the tx9 configuration, 2.6 s, load up at 1.0 s, down at 1.8 s
        case 'ff_lpf10'    % gain 1, i_L low-pass 10 Hz
            P=vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true,'t_step_up',1,'t_step_down',1.8,'stop_time',2.6,'ff_gain',1,'ff_lpf_Hz',10);
        case 'ff_lpf30'    % gain 1, i_L low-pass 30 Hz
            P=vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true,'t_step_up',1,'t_step_down',1.8,'stop_time',2.6,'ff_gain',1,'ff_lpf_Hz',30);
        case 'ff_g05'      % gain 0.5, i_L low-pass 1000 Hz (as E1.2)
            P=vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true,'t_step_up',1,'t_step_down',1.8,'stop_time',2.6,'ff_gain',0.5,'ff_lpf_Hz',1000);
        case {'ff_g07','ff_g08','ff_g09'}   % gain 0.7 / 0.8 / 0.9, i_L low-pass 1000 Hz
            g=str2double(caseName(end-1:end))/10;
            P=vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true,'t_step_up',1,'t_step_down',1.8,'stop_time',2.6,'ff_gain',g,'ff_lpf_Hz',1000);
        case 'ff_g10s'     % gain 1, 0.8 s, low load only: stability check on the tx9 configuration
            P=vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true,'t_step_up',50,'t_step_down',60,'stop_time',0.8,'ff_gain',1,'ff_lpf_Hz',1000);
        case 'ff_off'      % gain 0: reference for the same short schedule
            P=vsg_stage5k_params('tx_Vlv',9,'auto_Vrms',true,'t_step_up',1,'t_step_down',1.8,'stop_time',2.6,'ff_gain',0);
        otherwise
            error('Unknown case %s',caseName);
    end
    run_stage5k(P,caseName);
catch err
    disp(getReport(err,'extended','hyperlinks','off'));
    fprintf('STAGE5K_JOB_FAILED: %s\n',caseName);
end
exit;
end
