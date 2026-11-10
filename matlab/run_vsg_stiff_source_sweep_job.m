% Weak-grid (X = 1 pu) inertia sweep, FF off, 6 s runs (ramp 3.2-4.0 s, hold to 6 s).
addpath('D:/workspace/engineering/vsg-project/matlab');
for H=[0.05 5 10]
    lab=sprintf('sweep_x100_H%s',strrep(num2str(H),'.','p'));
    try
        run_vsg_stiff_source(lab,H,-0.25,6.0,2.5e-6,0,9.36e-3);
        fprintf('SWEEP_OK %s\n',lab);
    catch ME
        fprintf('SWEEP_FAIL %s\n',lab); disp(getReport(ME,'extended'));
    end
end
exit;
