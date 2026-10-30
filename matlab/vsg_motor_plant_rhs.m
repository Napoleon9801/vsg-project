function [dx,o] = vsg_motor_plant_rhs(x,stationary_command,omega,p,connected,load_multiplier)
% Physical states: iLf(1:2),vCf(3:4),iRL(5:6),psi_s(7:8),psi_r(9:10),
% omega_mech(11),Vdc(12),theta(13). States14:20 integrate powers using RK4.
% Positive source energy enters the DC capacitor; no sink current available.
i=x(1:2); vc=x(3:4); bus=x(12); theta=x(13);
motor_state=x(7:11);
if strcmp(p.load_kind,'rl')
    il=x(5:6);
elseif connected
    il=(p.motor.Lr*motor_state(1:2)-p.motor.Lm*motor_state(3:4))/p.motor.determinant;
else
    il=zeros(2,1);
end
v=vc+p.Rd*(i-il);
if strcmp(p.load_kind,'motor') && connected
    if nargout>1
        [dm,mo]=vsg_motor_rhs(motor_state,v,omega,p.motor,load_multiplier,p.locked);
        motor_powers=[mo.copper_loss;mo.friction_loss;mo.shaft_load_power];
    else
        [dm,~,motor_powers]=vsg_motor_rhs(motor_state,v,omega,p.motor,load_multiplier,p.locked);
    end
else
    dm=zeros(5,1);
    motor_powers=zeros(3,1);
    if nargout>1; [~,mo]=vsg_motor_rhs(zeros(5,1),zeros(2,1),omega,p.motor,0,true); end
end
c=cos(theta); s=sin(theta);
ideal=(bus/p.Vnom)*[c*stationary_command(1)+s*stationary_command(2); ...
    -s*stationary_command(1)+c*stationary_command(2)];
deadtime_error=zeros(2,1);
if p.deadtime>0 && norm(i)>1e-12
    deadtime_error=(4/pi)*bus*p.deadtime/p.Ts*i/norm(i);
end
effective=ideal-deadtime_error;
applied=effective-p.Rbridge*i;
bridge_loss=1.5*p.Rbridge*(i'*i);
% Deadtime changes conversion/duty. It is not itself a heat-loss law.
% Only the separately assumed resistance dissipates heat in this model.
bridge_dc_power=1.5*(effective'*i);
isource=min(max((p.Vnom-bus)/p.Rsource,0),p.Isource);
source_power=bus*isource;
filter_loss=1.5*(p.Rf*(i'*i)+p.Rd*sum((i-il).^2));
dil=zeros(2,1); rl_loss=0; rl_energy=0;
if strcmp(p.load_kind,'rl')
    dil=(v-p.Rload*il)/p.Ll-omega*[-il(2);il(1)];
    rl_loss=1.5*p.Rload*(il'*il); rl_energy=0.75*p.Ll*(il'*il);
end
di=(applied-v-p.Rf*i)/p.Lf-omega*[-i(2);i(1)];
dvc=(i-il)/p.Cf-omega*[-vc(2);vc(1)];
dx=[di;dvc;dil;dm;(isource-bridge_dc_power/bus)/p.Cdc;omega; ...
    source_power;filter_loss;bridge_loss;motor_powers;rl_loss];
if nargout<2; return; end
o=struct('voltage',v,'load_current',il,'motor',mo,'source_current',isource, ...
    'source_power',source_power,'bridge_dc_power',bridge_dc_power, ...
    'bridge_output_power',1.5*(applied'*i),'bridge_loss',bridge_loss, ...
    'filter_loss',filter_loss,'rl_loss',rl_loss, ...
    'stored_energy',0.5*p.Cdc*bus^2+0.75*p.Lf*(i'*i)+ ...
    0.75*p.Cf*(vc'*vc)+rl_energy+mo.magnetic_energy+mo.kinetic_energy);
end
