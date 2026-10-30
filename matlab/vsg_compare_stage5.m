function result = vsg_compare_stage5(signals,c5,Ts)
% Compare CT dq plant observations at identical effective bandwidth.
% Interpolate to 200 kHz then apply a 1 ms moving average to BOTH models.
% This is a control-envelope comparison, not switching-ripple/THD evidence.
vsg_validate_signals(signals);
ct=struct('iL_d',struct('time',c5.t,'data',c5.iL_d), ...
    'Vload_d',struct('time',c5.t,'data',c5.Vload_d), ...
    'freq',struct('time',c5.t,'data',c5.freq));
vsg_validate_signals(ct);
dt=5e-6; tg=(0:dt:3)'; n=round(1e-3/dt);
result.method='CT plant dq; linear resample at 200 kHz; identical 1 ms boxcar';
result.bandwidth_note='Envelope ripple only; not raw PWM ripple or THD';
result.sample_time_controller=Ts;
windows=[0.90 0.99;1.8 2.0;2.8 2.99];
for k=1:2
    name={'iL_d','Vload_d'}; name=name{k};
    a=signals.([name '_ct']); b=ct.(name);
    assert(a.time(1)<=tg(1) && b.time(1)<=tg(1) && ...
        a.time(end)>=tg(end) && b.time(end)>=tg(end), ...
        'VSG:MissingWindow','Comparison needs the full 0..3 s interval.');
    ya=movmean(interp1(a.time,a.data,tg,'linear'),n);
    yb=movmean(interp1(b.time,b.data,tg,'linear'),n);
    for j=1:3
        ix=tg>=windows(j,1) & tg<=windows(j,2);
        result.([name '_p2p_5d'])(j)=max(ya(ix))-min(ya(ix));
        result.([name '_p2p_5c'])(j)=max(yb(ix))-min(yb(ix));
    end
end
result.windows=windows;
result.frequency_5d=mean(signals.freq.data(signals.freq.time>=2.8));
result.frequency_5c=mean(c5.freq(c5.t>=2.8));
result.growth_ratio=result.iL_d_p2p_5d(3)/max(result.iL_d_p2p_5d(2),1e-6);
result.criteria=struct('frequency_difference_Hz',0.01, ...
    'current_envelope_ratio',3,'current_envelope_floor_A',0.05, ...
    'growth_ratio',1.5);
result.checks=struct('frequency',abs(result.frequency_5d-result.frequency_5c)<0.01, ...
    'current_envelope',result.iL_d_p2p_5d(3)<3*max(result.iL_d_p2p_5c(3),0.05), ...
    'no_growth',result.growth_ratio<1.5);
result.pass=all(structfun(@(x)logical(x),result.checks));
result.scope='Ideal switching plant only; does not establish hardware readiness';
end
