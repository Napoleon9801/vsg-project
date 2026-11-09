% Isolated background entry point; all temporary and result files stay on D:.
try
    addpath('D:/workspace/engineering/vsg-project/matlab');
    run_stage5i_load_cycle(2.5e-6,'smoke',0.1);
    disp(memory);
    fprintf('MEMORY_BOUNDED_SMOKE_OK\n');
    run_stage5i_load_cycle(2.5e-6,'nominal',11);
catch ME
    disp(getReport(ME,'extended'));
end
exit;
