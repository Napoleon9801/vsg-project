% Stiff-source wiring smoke (0.3 s, before the ramp).
try
    addpath('D:/workspace/engineering/vsg-project/matlab');
    run_vsg_stiff_source('smoke',5,-0.25,0.3);
    fprintf('STIFF_SMOKE_OK\n');
catch ME
    disp(getReport(ME,'extended'));
end
exit;
