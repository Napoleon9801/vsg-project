function open_stage5i_secondary
% Open the saved model and its recorded results for manual inspection.
root=fileparts(mfilename('fullpath'));
model='vsg_stage5i_secondary';
file=fullfile(root,'validation_outputs','stage5i',[model '.slx']);
open_system(file);
notes=find_system(model,'FindAll','on','SearchDepth',1,'Type','annotation');
for k=1:numel(notes)
    text=get_param(notes(k),'Name');
    if strncmp(text,'STAGE 5h  |',11)
        set_param(notes(k),'Name',strrep(text,'STAGE 5h','STAGE 5i'));
    end
end
scope=find_system(model,'SearchDepth',1,'Name','Secondary_Frequency_Control');
assert(numel(scope)==1);
open_system(scope{1});set_param(scope{1},'ZoomFactor','FitSystem');drawnow;pause(1);
print(['-s' scope{1}],'-dpng','-r0',fullfile(root,'..','docs','figures', ...
    'stage5i_secondary_controller_2026-11-06.png'));
open_system(model);set_param(model,'ZoomFactor','FitSystem');drawnow;pause(1);
save_system(model,file);
print(['-s' model],'-dpng','-r0',fullfile(root,'..','docs','figures', ...
    'stage5i_model_overview_2026-11-06.png'));
show_stage5i_results;
open_system(model);
fprintf('STAGE5I_MODEL_AND_RESULTS_OPEN_OK\n');
end
