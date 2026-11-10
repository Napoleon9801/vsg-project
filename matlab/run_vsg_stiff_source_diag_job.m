% Stiff-source stability diagnosis: 1.2 s runs (before ramp), three configurations.
addpath('D:/workspace/engineering/vsg-project/matlab');
cfg={'diag_ff1_x015',1,1.4e-3; 'diag_ff0_x015',0,1.4e-3; 'diag_ff1_x040',1,3.74e-3};
for k=1:size(cfg,1)
    try
        run_vsg_stiff_source(cfg{k,1},5,-0.25,1.2,2.5e-6,cfg{k,2},cfg{k,3});
        fprintf('DIAG_OK %s\n',cfg{k,1});
    catch ME
        fprintf('DIAG_FAIL %s\n',cfg{k,1}); disp(getReport(ME,'extended'));
    end
end
exit;
