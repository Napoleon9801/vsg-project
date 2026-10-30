function figures=show_stage5h_pwm
% View all six saved gate signals and per-phase dead time. No simulation run.
folder=fullfile(fileparts(mfilename('fullpath')),'validation_outputs','stage5h');
d=load(fullfile(folder,'results_nominal.mat'),'signals');
t=d.signals.gates_6.time; g=double(d.signals.gates_6.data);
assert(size(g,2)==6 && size(g,1)==numel(t));
names={'A HIGH (AH)','A LOW (AL)','B HIGH (BH)','B LOW (BL)','C HIGH (CH)','C LOW (CL)'};
colors=lines(6);
figures(1)=figure('Name','Stage 5h - All six MOSFET gate commands','NumberTitle','off','Color','w');
take=t>=2.9-2e-6 & t<=2.9005+2e-6;
for k=1:6
    ax=subplot(6,1,k);
    stairs(ax,(t(take)-2.9)*1e6,g(take,k),'Color',colors(k,:),'LineWidth',1.2);
    ylabel(ax,names{k}); ylim(ax,[-0.15 1.2]); yticks(ax,[0 1]); xlim(ax,[0 500]); grid(ax,'on');
    if k==1; title(ax,'Recorded logic gate commands: 1 ON / 0 OFF; not electrical Vgs'); end
end
xlabel('Time from 2.900000 s (us)');
figures(2)=figure('Name','Stage 5h - Dead time for A B C','NumberTitle','off','Color','w');
for p=1:3
    high=2*p-1; low=2*p;
    falls=find(diff(g(:,low))==-1)+1; j=find(t(falls)>=2.9,1); t0=t(falls(j));
    rises=find(diff(g(:,high))==1)+1; j=find(t(rises)>=t0,1); gap=(t(rises(j))-t0)*1e6;
    take=t>=t0-1e-6 & t<=t0+2e-6;
    ax=subplot(3,1,p);
    stairs(ax,(t(take)-t0)*1e6,g(take,[high low]),'LineWidth',1.4);
    legend(ax,names([high low]),'Location','best');
    ph='ABC'; title(ax,sprintf('Phase %c: %.3f us dead time (own event)',ph(p),gap));
    ylim(ax,[-0.15 1.2]); yticks(ax,[0 1]); xlim(ax,[-0.5 1.5]); grid(ax,'on');
    ylabel(ax,'Gate logic'); xlabel(ax,'Time from lower turn-off (us)');
end
drawnow;
end
