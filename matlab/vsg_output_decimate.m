function out = vsg_output_decimate(s,events)
% VSG_OUTPUT_DECIMATE  Reduce a run's output-side logs to a small plotting set.
%   s      struct with fields Vload_abc, iload_abc (high-rate, columns A B C) and,
%          if present, freq, P_meas, Q_meas; each has .time and .data
%   events load-step times [s] (non-finite or outside the run are ignored)
% Returns (1 ms grid, 20 ms windows unless noted):
%   t, P_1ms, Q_1ms, P_20ms, Q_20ms (terminal sum v*i), Vrms(:,3), Irms(:,3),
%   Vpos_rms (positive-sequence magnitude), V0_rms, f_term (voltage space-vector
%   angle), freq_int / P_meas_int / Q_meas_int (controller signals), raw v/i
%   windows wt#, wv#, wi# (100 kHz) with windows(#,:) and window_t0(#), events.
t=s.Vload_abc.time(:); v=double(s.Vload_abc.data); i=double(s.iload_abc.data);
ti=s.iload_abc.time(:);
if numel(ti)~=numel(t) || max(abs(ti-t))>1e-12; i=interp1(ti,i,t); end
tend=t(end);
dt=1e-3; W=0.02; g=(W:dt:tend)';
ci=@(y) [0; cumsum(0.5*(y(1:end-1)+y(2:end)).*diff(t))];
wmean=@(c,a,b) (interp1(t,c,b)-interp1(t,c,a))./(b-a);
p=sum(v.*i,2);
q=((v(:,2)-v(:,3)).*i(:,1)+(v(:,3)-v(:,1)).*i(:,2)+(v(:,1)-v(:,2)).*i(:,3))/sqrt(3);
cp=ci(p); cq=ci(q);
out.t=g;
out.P_1ms=wmean(cp,g-dt,g);     out.Q_1ms=wmean(cq,g-dt,g);
out.P_20ms=wmean(cp,g-W,g);     out.Q_20ms=wmean(cq,g-W,g);
for k=1:3
    c2=ci(v(:,k).^2); out.Vrms(:,k)=sqrt(wmean(c2,g-W,g));
    c2=ci(i(:,k).^2); out.Irms(:,k)=sqrt(wmean(c2,g-W,g));
end
% amplitude-invariant Clarke: |v_alphabeta| = phase peak; 20 ms mean / sqrt(2) ~ V+ rms
al=(2/3)*(v(:,1)-0.5*v(:,2)-0.5*v(:,3)); be=(2/3)*(sqrt(3)/2)*(v(:,2)-v(:,3));
cm=ci(sqrt(al.^2+be.^2)); out.Vpos_rms=wmean(cm,g-W,g)/sqrt(2);
v0=sum(v,2)/3; c0=ci(v0.^2); out.V0_rms=sqrt(wmean(c0,g-W,g));
th=unwrap(atan2(be,al));
out.f_term=(interp1(t,th,g)-interp1(t,th,g-W))/(2*pi*W);
clear al be th cm c0 v0 p q cp cq c2;
nm={'freq','P_meas','Q_meas'};
for k=1:numel(nm)
    if isfield(s,nm{k})
        x=s.(nm{k}); out.([nm{k} '_int'])=interp1(x.time(:),double(x.data(:,1)),g);
    end
end
% raw windows: start-up, around each event inside the run, end
ev=events(isfinite(events) & events>0.05 & events<tend-0.01);
win=[0 min(0.12,tend)]; t0=0;
for k=1:numel(ev); win(end+1,:)=[max(0,ev(k)-0.04) min(tend,ev(k)+0.08)]; t0(end+1)=ev(k); end %#ok<AGROW>
if tend>0.24; win(end+1,:)=[tend-0.12 tend]; t0(end+1)=tend-0.12; end
for k=1:size(win,1)
    idx=find(t>=win(k,1) & t<=win(k,2)); idx=idx(1:2:end);
    out.(sprintf('wt%d',k))=t(idx); out.(sprintf('wv%d',k))=v(idx,:); out.(sprintf('wi%d',k))=i(idx,:);
end
out.windows=win; out.window_t0=t0(:); out.events=ev(:);
end
