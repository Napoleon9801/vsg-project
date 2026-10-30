function [dz,o,powers] = vsg_motor_rhs(z,voltage,omega_e,m,load_multiplier,locked)
% z=[psi_sd psi_sq psi_rd psi_rq omega_mech]' in a common rotating frame.
% Park q=-sin, J*[d;q]=[-q;d]; electrical rotor speed=pole_pairs*omega_mech.
% Te=3/2*p*(psi_sd*i_sq-psi_sq*i_sd), positive for motoring.
ps=z(1:2); pr=z(3:4); wm=z(5);
is=(m.Lr*ps-m.Lm*pr)/m.determinant;
ir=(m.Ls*pr-m.Lm*ps)/m.determinant;
torque=1.5*m.pole_pairs*(ps(1)*is(2)-ps(2)*is(1));
load_torque=load_multiplier*(m.mechanical_power_nominal/m.omega_nominal)* ...
    (wm/m.omega_nominal)^2*tanh(wm/m.load_sign_speed);
dps=voltage-m.Rs*is-omega_e*[-ps(2);ps(1)];
dpr=-m.Rr*ir-(omega_e-m.pole_pairs*wm)*[-pr(2);pr(1)];
dwm=(torque-load_torque-m.B*wm)/m.Jm;
if locked; dwm=0; end
dz=[dps;dpr;dwm];
powers=[1.5*(m.Rs*(is'*is)+m.Rr*(ir'*ir));m.B*wm^2;load_torque*wm];
% RK stages need derivatives/powers, not observation structs or diagnostics.
if nargout==3; o=[]; return; end
o=struct('stator_current',is,'rotor_current',ir,'torque',torque, ...
    'load_torque',load_torque,'input_power',1.5*(voltage'*is), ...
    'copper_loss',powers(1), ...
    'friction_loss',powers(2),'shaft_load_power',powers(3), ...
    'magnetic_energy',0.75*(ps'*is+pr'*ir), ...
    'kinetic_energy',0.5*m.Jm*wm^2);
o.storage_derivative=1.5*(is'*dps+ir'*dpr)+m.Jm*wm*dwm;
end
