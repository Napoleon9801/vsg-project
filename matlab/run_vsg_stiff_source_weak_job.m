% FF off, X = 1 pu (9.36 mH), H = 5: does the VSG synchronise with a weak grid?
addpath('D:/workspace/engineering/vsg-project/matlab');
try
    run_vsg_stiff_source('ff0_H5_x100',5,-0.25,4.4,2.5e-6,0,9.36e-3);
    fprintf('WEAK_OK\n');
catch ME
    disp(getReport(ME,'extended'));
end
exit;
