function fig=show_stage5i_load_cycle(label)
% Open the recorded load-cycle P/f/Vrms/Irms curves; does not rerun Simulink.
% Curves are generated from raw output waveforms by plot_stage5i_load_cycle.py.
if nargin<1; label='nominal'; end
assert(ischar(label) && ~isempty(regexp(label,'^[a-zA-Z0-9_]+$','once')));
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5i_load_cycle');
file=fullfile(folder,['curves_' label '.mat']);
assert(exist(file,'file')==2,'Generate the saved RMS curves first: %s',file);
s=load(file);
t=s.time_s(:);
fig=figure('Name','Stage 5i - Load increase and decrease: P f Vrms Irms', ...
    'NumberTitle','off','Color','w','Position',[60 50 1250 850]);
ax(1)=subplot(4,1,1);
plot(t,s.P_load_W(:),'LineWidth',1.3);hold on;
plot(t,s.P_ref_W_equivalent(:),'--','LineWidth',1);
ylabel('P (W)');title('Measured load power: 20 ms mean; secondary ON');
legend('Output P','Controller P reference','Location','best');
ax(2)=subplot(4,1,2);
plot(t,s.freq_Hz(:),'LineWidth',1.3);hold on;
plot([0 11],[50 50],'k:');ylabel('f (Hz)');
title('Internal virtual-rotor frequency, omega/(2*pi)');
ax(3)=subplot(4,1,3);
plot(t,s.Vrms_abc_V,'LineWidth',1.1);ylabel('Vrms (V)');
title('Load phase-to-neutral voltage after LC; trailing 20 ms RMS');
legend('A','B','C','Location','best');
ax(4)=subplot(4,1,4);
plot(t,s.Irms_abc_A,'LineWidth',1.1);ylabel('Irms (A)');xlabel('Time (s)');
title('Load branch current; trailing 20 ms RMS');
legend('A','B','C','Location','best');
for k=1:4
    grid(ax(k),'on');xlim(ax(k),[0 11]);hold(ax(k),'on');
    limits=ylim(ax(k));
    plot(ax(k),[3 3],limits,'--','Color',[.65 .3 .4],'HandleVisibility','off');
    plot(ax(k),[7 7],limits,'--','Color',[.65 .3 .4],'HandleVisibility','off');
end
linkaxes(ax,'x');drawnow;
savefig(fig,fullfile(folder,['stage5i_load_cycle_' label '.fig']));
fprintf('STAGE5I_LOAD_CYCLE_FIGURE_READY: %s\n',file);
end
