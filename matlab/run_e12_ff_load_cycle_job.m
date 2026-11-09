% E1.2 isolated background entry point; all temporary and result files stay on D:.
try
    addpath('D:/workspace/engineering/vsg-project/matlab');
    run_e12_ff_load_cycle(2.5e-6,'smoke_ff0',0.1,0,1000);
    fprintf('E12_SMOKE_FF0_OK\n');
    run_e12_ff_load_cycle(2.5e-6,'smoke_ff1',0.1,1,1000);
    fprintf('E12_SMOKE_FF1_OK\n');
    run_e12_ff_load_cycle(2.5e-6,'nominal_ff1',11,1,1000);
    fprintf('E12_NOMINAL_FF1_OK\n');
catch ME
    disp(getReport(ME,'extended'));
end
exit;
