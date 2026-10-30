function fig = show_stage5d_results(source)
% SHOW_STAGE5D_RESULTS Display all six Stage 5d plots in one MATLAB figure.
%   show_stage5d_results             : saved validation MAT file
%   show_stage5d_results('workspace'): latest Run-button timeseries in base workspace
%   show_stage5d_results(out)        : a Simulink.SimulationOutput from sim(in)
% No simulation is started and no model or saved results are changed.
% Compatible with MATLAB R2018b. Each signal uses its own time array.

if nargin == 0
    source = 'saved';
end
names = {'freq','P_meas','Q_meas','Vload_d','Vload_q','Vload_abc','iload_abc'};
vars = {'omega_ts','P_ts','Q_ts','Vload_d_ts','Vload_q_ts','Vload_abc_ts','iload_abc_ts'};
s = struct();
if ischar(source) && strcmpi(source,'saved')
    folder = fileparts(mfilename('fullpath'));
    file = fullfile(folder,'validation_outputs','stage5d','vsg_stage5d_out.mat');
    wanted = [names, strcat('time_',names), {'R_load_t','R_load_init','R_load_after'}];
    raw = load(file,wanted{:});
    for k = 1:numel(names)
        n = names{k};
        s.(n).time = raw.(['time_' n])(:);
        s.(n).data = raw.(n);
    end
    stepTime = raw.R_load_t;
    description = sprintf('Saved validation data | R: %.3f to %.3f ohm at %.1f s', ...
        raw.R_load_init,raw.R_load_after,stepTime);
else
    fromBase = ischar(source) && strcmpi(source,'workspace');
    if ~fromBase && ~isa(source,'Simulink.SimulationOutput')
        error('VSG:PlotSource','Use ''saved'', ''workspace'', or a Simulink.SimulationOutput.');
    end
    for k = 1:numel(names)
        if fromBase
            if ~evalin('base',sprintf('exist(''%s'',''var'')',vars{k}))
                error('VSG:MissingSignal','Missing %s. Run the model first or use show_stage5d_results(''saved'').',vars{k});
            end
            ts = evalin('base',vars{k});
        else
            ts = source.get(vars{k});
        end
        assert(isa(ts,'timeseries'),'Expected a timeseries for %s.',vars{k});
        values = ts.Data;
        if ~ts.IsTimeFirst
            values = permute(values,[ndims(values),1:ndims(values)-1]);
        end
        s.(names{k}).time = ts.Time(:);
        s.(names{k}).data = reshape(values,numel(ts.Time),[]);
    end
    s.freq.data = s.freq.data/(2*pi);
    stepTime = 1; % Annotation for the unchanged Stage 5d baseline.
    description = 'Current simulation signals | baseline load-step marker: 1 s';
end
for k = 1:numel(names)
    n = names{k};
    assert(size(s.(n).data,1)==numel(s.(n).time),'Time/data mismatch: %s',n);
end

fig = figure('Name','Stage 5d - All six results','NumberTitle','off', ...
    'Color','w','Units','normalized','Position',[0.04 0.06 0.92 0.85]);
ax = gobjects(6,1);
for k = 1:6
    ax(k) = subplot(3,2,k,'Parent',fig);
end
drawSignal(ax(1),s.freq,[]);
title(ax(1),'Frequency response'); ylabel(ax(1),'Hz');
drawSignal(ax(2),s.P_meas,[]); hold(ax(2),'on');
drawSignal(ax(2),s.Q_meas,[]);
title(ax(2),'Filtered measured power'); ylabel(ax(2),'W / var');
legend(ax(2),{'P (W)','Q (var)'},'Location','best');
drawSignal(ax(3),s.Vload_d,[]); hold(ax(3),'on');
drawSignal(ax(3),s.Vload_q,[]);
title(ax(3),'Sampled output voltage in dq'); ylabel(ax(3),'V');
legend(ax(3),{'Vd','Vq'},'Location','best');
drawSignal(ax(4),s.Vload_abc,[stepTime-0.04 stepTime+0.08]);
title(ax(4),'Three-phase voltage around load step'); ylabel(ax(4),'V');
legend(ax(4),{'Phase A','Phase B','Phase C'},'Location','best');
drawSignal(ax(5),s.Vload_abc,[2.90 2.96]);
title(ax(5),'Steady-state output voltage'); ylabel(ax(5),'V');
drawSignal(ax(6),s.iload_abc,[2.90 2.96]);
title(ax(6),'Steady-state load current'); ylabel(ax(6),'A');
for k = 1:6
    grid(ax(k),'on'); xlabel(ax(k),'Time (s)');
    if k <= 4
        limits = ylim(ax(k)); hold(ax(k),'on');
        plot(ax(k),[stepTime stepTime],limits,'k--','HandleVisibility','off');
        ylim(ax(k),limits);
    end
end
annotation(fig,'textbox',[0.05 0.951 0.9 0.045], ...
    'String',['Stage 5d | ' description],'EdgeColor','none', ...
    'HorizontalAlignment','center','FontSize',12,'FontWeight','bold','Interpreter','none');
annotation(fig,'textbox',[0.05 0.001 0.9 0.035], ...
    'String','Ideal simulated plant; not hardware validation. P/Q uses filter-inductor current, not load-only current.', ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',9,'Interpreter','none');
drawnow;
fprintf('STAGE5D_SIX_PLOTS_OK: %s\n',description);
end

function drawSignal(ax,s,window)
t = s.time; y = s.data;
if isempty(window)
    selected = true(size(t));
else
    selected = t >= window(1) & t <= window(2);
    assert(any(selected),'No samples in requested plot window; run the baseline to 3 seconds.');
end
plot(ax,t(selected),y(selected,:),'LineWidth',1);
if ~isempty(window)
    xlim(ax,window);
end
end
