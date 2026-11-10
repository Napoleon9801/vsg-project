function export_e12_output_overview()
% Decimate the 11 s E1.2 FF nominal run (results_nominal_ff1.mat, v7.3) into a
% small v7 file of output-side quantities for plotting. Read-only on the source.
% MATLAB R2018b. Plot with: python -I python/analysis/plot_vsg_output.py
folder=fullfile(fileparts(mfilename('fullpath')),'validation_outputs','e12_ff_load_cycle');
src=fullfile(folder,'results_nominal_ff1.mat');
dst=fullfile(folder,'e12_output_decimated.mat');
S=load(src,'signals'); s=S.signals; clear S;
fprintf('FIELDS: %s\n',strjoin(fieldnames(s)',', '));
out=vsg_output_decimate(s,[3 7]);
out.title='E1.2 FF run (results_nominal_ff1), secondary control ON';
save(dst,'-struct','out','-v7');
fprintf('EXPORT_DONE %s\n',dst);
end
