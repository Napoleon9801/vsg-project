function [command,state,info] = vsg_firmware_control_step(v,i,omega,E,state,p)
% Double-precision mirror of firmware cascade algebra and conditional AW.
% This is NOT compiled firmware/SIL. Saturation is on vector magnitude.
ev=[E;0]-v;
ref=p.Kpv*ev+state.zv+omega*p.Cf*[-v(2);v(1)];
info.current_saturated=norm(ref)>p.Iref;
if info.current_saturated; ref=ref*(p.Iref/norm(ref)); end
for j=1:2
    if ~info.current_saturated || ev(j)*state.zv(j)<0
        state.zv(j)=state.zv(j)+p.KivTs*ev(j);
    end
end
ei=ref-i;
upi=p.Kpi*ei+state.zi;
command=upi+omega*p.Lf*[-i(2);i(1)]+v;
info.voltage_saturated=norm(command)>p.Vmax;
if info.voltage_saturated; command=command*(p.Vmax/norm(command)); end
for j=1:2
    if ~info.voltage_saturated || ei(j)*upi(j)<0
        state.zi(j)=state.zi(j)+p.KiiTs*ei(j);
    end
end
info.reference=ref;
end
