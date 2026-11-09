% E1.2 nominal-only retry (smokes already completed 2026-11-10 00:52-00:53).
try
    addpath('D:/workspace/engineering/vsg-project/matlab');
    run_e12_ff_load_cycle(2.5e-6,'nominal_ff1',11,1,1000);
    fprintf('E12_NOMINAL_FF1_OK\n');
catch ME
    disp(getReport(ME,'extended'));
end
exit;
