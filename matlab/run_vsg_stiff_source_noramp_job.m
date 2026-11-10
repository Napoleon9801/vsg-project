% Control runs for superposition: identical to the weak-grid sweep but RoCoF = 0.
addpath('D:/workspace/engineering/vsg-project/matlab');
for H=[0.05 5 10]
    lab=sprintf('noramp_x100_H%s',strrep(num2str(H),'.','p'));
    try
        run_vsg_stiff_source(lab,H,0,6.0,2.5e-6,0,9.36e-3);
        fprintf('NORAMP_OK %s\n',lab);
    catch ME
        fprintf('NORAMP_FAIL %s\n',lab); disp(getReport(ME,'extended'));
    end
end
exit;
