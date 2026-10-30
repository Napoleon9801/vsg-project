function fig=show_stage5h_results(label)
% Interactive gate/device/output overview from saved electrical-circuit results.
if nargin<1; label='nominal'; end
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'validation_outputs','stage5h');
d=load(fullfile(folder,['results_' label '.mat']),'signals','report');
s=d.signals; r=d.report;
fig=figure('Name','Stage 5h - MOSFET gates and electrical circuit','NumberTitle','off', ...
    'Color','w','Units','normalized','Position',[0.03 0.04 0.94 0.89]);
ax=gobjects(8,1);
for k=1:8; ax(k)=subplot(4,2,k,'Parent',fig); end
draw(ax(1),s.gates_6,[2.9 2.9002],[1 2],true);
title(ax(1),'Phase A: upper / lower gate pulses'); ylabel(ax(1),'Logic 0 / 1');
legend(ax(1),{'AH','AL'},'Location','best'); ylim(ax(1),[-0.15 1.25]);
g=s.gates_6.data>0.5; t=s.gates_6.time;
falls=find(diff(double(g(:,2)))==-1)+1;
j=find(t(falls)>=2.9,1); assert(~isempty(j));
t0=t(falls(j)); take=t>=t0-1e-6 & t<=t0+2e-6;
stairs(ax(2),(t(take)-t0)*1e6,double(g(take,1:2)),'LineWidth',1.1);
title(ax(2),sprintf('Turn-on blanking: measured minimum %.3f us',r.deadtime_min_s*1e6));
xlabel(ax(2),'Time from lower turn-off (us)'); ylabel(ax(2),'Logic 0 / 1');
xlim(ax(2),[-0.5 1.5]); ylim(ax(2),[-0.15 1.25]); legend(ax(2),{'AH','AL'},'Location','best');
draw(ax(3),s.Vds_A_high,[2.9 2.9002],1,false);
title(ax(3),'Upper A MOSFET drain-source voltage'); ylabel(ax(3),'V');
draw(ax(4),s.Vload_abc,[2.9 2.96],1:3,false);
title(ax(4),'Output voltage relative to floating N_AC'); ylabel(ax(4),'V');
legend(ax(4),{'A','B','C'},'Location','best');
draw(ax(5),s.iL_abc,[2.9 2.96],1:3,false);
title(ax(5),'Filter-inductor currents before capacitor split'); ylabel(ax(5),'A');
draw(ax(6),s.freq,[],1,false);
title(ax(6),sprintf('Frequency: final %.4f Hz',r.final_frequency_Hz)); ylabel(ax(6),'Hz');
draw(ax(7),s.Vload_d,[],1,false); hold(ax(7),'on');
draw(ax(7),s.Vload_q,[],1,false);
title(ax(7),'Sampled dq voltage after load step'); ylabel(ax(7),'V');
legend(ax(7),{'Vd','Vq'},'Location','best');
draw(ax(8),s.I_dc,[],1,false);
title(ax(8),'DC source current (display decimated)'); ylabel(ax(8),'A');
for k=1:8
    grid(ax(k),'on');
    if k~=2; xlabel(ax(k),'Time (s)'); end
end
annotation(fig,'textbox',[0.03 .954 .94 .04], ...
    'String','Stage 5h | PWM -> 6 MOSFETs -> electrical LC / RL load -> VSG feedback', ...
    'EdgeColor','none','HorizontalAlignment','center','FontWeight','bold','FontSize',13,'Interpreter','none');
annotation(fig,'textbox',[0.03 .001 .94 .033], ...
    'String','SPS logic-gate macro models. Device/driver/thermal hardware qualification is not established.', ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',9);
drawnow;
savefig(fig,fullfile(folder,['stage5h_' label '.fig']));
figFolder=fullfile(root,'..','docs','figures');
set(fig,'PaperPositionMode','auto');
print(fig,fullfile(figFolder,['stage5h_mosfet_' label '_2026-10-29.png']),'-dpng','-r130');
fprintf('STAGE5H_FIGURE_OK\n');
end

function draw(ax,s,w,columns,steps)
t=s.time; y=s.data;
if isempty(w); ii=(1:numel(t))'; else; ii=find(t>=w(1) & t<=w(2)); end
assert(~isempty(ii),'Requested plot time is outside the saved result.');
if numel(ii)>100000; ii=ii(1:ceil(numel(ii)/100000):end); end
if steps; stairs(ax,t(ii),y(ii,columns),'LineWidth',1); else; plot(ax,t(ii),y(ii,columns),'LineWidth',1); end
if ~isempty(w); xlim(ax,w); end
end
