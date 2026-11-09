function fig=show_stage5i_results
% View saved Stage 5i frequency restoration alongside the saved Stage 5h run.
root=fileparts(mfilename('fullpath'));
baseline=fullfile(root,'validation_outputs','stage5h','results_nominal.mat');
current=fullfile(root,'validation_outputs','stage5i','results_nominal.mat');
report=jsondecode(fileread(fullfile(root,'validation_outputs','stage5i','report_nominal.json')));
a=readSignal(baseline,'freq',[]);b=readSignal(current,'freq',[]);
fig=figure('Name','Stage 5i - Secondary frequency restoration','NumberTitle','off', ...
    'Color','w','Position',[80 80 1250 760]);
ax=subplot(2,2,1);
plot(a.time,a.data,'Color',[.55 .55 .55]);hold on;
plot(b.time,b.data,'b','LineWidth',1.5);
plot([0 6],[50 50],'k:');grid on;ylabel('Hz');xlabel('Time (s)');
title('Frequency: primary only / secondary enabled');legend('Stage 5h (ends at 3 s)','Stage 5i','50 Hz');
ax=subplot(2,2,2);
p=readSignal(current,'sec_P_ref_pu',[]);
ix=unique([1:100:numel(p.time),numel(p.time)]);
plot(p.time(ix),100*p.data(ix),'LineWidth',1.5);grid on;
xlabel('Time (s)');ylabel('W equivalent');title('Power reference on 100 W base');
ax=subplot(2,2,3);drawLast(ax,readSignal(current,'Vload_abc',.06));ylabel('V');title('Load phase voltages');
ax=subplot(2,2,4);drawLast(ax,readSignal(current,'iload_abc',.06));ylabel('A');title('Load phase currents');
drawnow;
savefig(fig,fullfile(root,'validation_outputs','stage5i','stage5i_secondary_results.fig'));
fprintf('STAGE5I_RESULTS_OPEN: final mean %.9f Hz\n',report.final_frequency_Hz);
end
function drawLast(ax,s)
last=s.time(end);index=s.time>=last-.06;
plot(ax,s.time(index),s.data(index,:));grid(ax,'on');xlabel(ax,'Time (s)');
legend(ax,{'A','B','C'});
end
function s=readSignal(file,name,tail)
% Read only requested HDF5 datasets, avoiding the large raw switching records.
group=['/signals/' name];t=h5read(file,[group '/time']);t=t(:);
first=1;if ~isempty(tail);first=find(t>=t(end)-tail,1);end
info=h5info(file,[group '/data']);dimensions=info.Dataspace.Size;
count=numel(t)-first+1;
if dimensions(1)==numel(t)
    y=h5read(file,[group '/data'],[first 1],[count dimensions(2)]);
else
    assert(dimensions(2)==numel(t));
    y=h5read(file,[group '/data'],[1 first],[dimensions(1) count])';
end
s=struct('time',t(first:end),'data',y);
end
