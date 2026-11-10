% FF off, X 0.15 pu, H = 5: 4.4 s run (ramp 3.0-3.8 s) to check start-up settling + ramp response.
addpath('D:/workspace/engineering/vsg-project/matlab');
try
    run_vsg_stiff_source('ff0_H5',5,-0.25,4.4,2.5e-6,0,1.4e-3);
    fprintf('LONG_OK\n');
catch ME
    disp(getReport(ME,'extended'));
end
exit;
