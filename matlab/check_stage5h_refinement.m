function comparison=check_stage5h_refinement
% Independent full-run step refinement of the electrical extension.
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5h');
nominal=jsondecode(fileread(fullfile(folder,'report_nominal.json')));
refined=run_stage5h_mosfet(3,1.25e-6,'refined');
comparison=struct();
comparison.frequency_difference_Hz=abs(nominal.final_frequency_Hz-refined.final_frequency_Hz);
comparison.Vd_difference_V=abs(nominal.final_Vd_V-refined.final_Vd_V);
comparison.voltage_rms_relative_difference=abs(nominal.phase_voltage_rms_V(:)-refined.phase_voltage_rms_V(:))./refined.phase_voltage_rms_V(:);
comparison.current_rms_relative_difference=abs(nominal.load_current_rms_A(:)-refined.load_current_rms_A(:))./refined.load_current_rms_A(:);
comparison.criteria=struct('frequency_Hz',0.005,'Vd_V',0.05,'rms_relative',0.01);
comparison.pass=nominal.operating_screen && refined.operating_screen ...
    && nominal.gate_screen && refined.gate_screen ...
    && nominal.electrical_sanity_screen && refined.electrical_sanity_screen ...
    && comparison.frequency_difference_Hz<=0.005 && comparison.Vd_difference_V<=0.05 ...
    && all(comparison.voltage_rms_relative_difference<=0.01) ...
    && all(comparison.current_rms_relative_difference<=0.01);
comparison.scope='Final operating values and gate/electrical screens at 2.5us and 1.25us MaxStep; not a complete transient, EMI, thermal or hardware validation.';
fid=fopen(fullfile(folder,'step_refinement.json'),'w');
fprintf(fid,'%s',jsonencode(comparison)); fclose(fid);
fprintf('STAGE5H_REFINEMENT_COMPLETE: %s\n',jsonencode(comparison));
end
