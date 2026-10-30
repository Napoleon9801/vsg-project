classdef test_vsg_motor < matlab.unittest.TestCase
    % Independent physical invariants, not hard-coded simulation trajectories.
    methods (Test)
        function zeroStateRemainsZero(tc)
            p=vsg_motor_parameters();
            [dz,o]=vsg_motor_rhs(zeros(5,1),zeros(2,1),p.w0,p.motor,1,false);
            tc.verifyEqual(dz,zeros(5,1),'AbsTol',1e-14);
            tc.verifyEqual(o.magnetic_energy,0,'AbsTol',1e-14);
        end
        function motorEnergyConservedWithLossAndLoad(tc)
            p=vsg_motor_parameters();
            [~,o]=vsg_motor_rhs([.03;-.015;.02;-.005;83],[9;-2],p.w0,p.motor,1.3,false);
            expected=o.input_power-o.copper_loss-o.friction_loss-o.shaft_load_power;
            tc.verifyEqual(o.storage_derivative,expected,'AbsTol',1e-10);
            tc.verifyGreaterThanOrEqual(o.magnetic_energy,0);
        end
        function unpoweredMotorIsPassive(tc)
            p=vsg_motor_parameters();
            [~,o]=vsg_motor_rhs([.03;-.015;.02;-.005;83],[0;0],p.w0,p.motor,1,false);
            tc.verifyLessThan(o.storage_derivative,0);
        end
        function torqueAndEnergyIndependentOfFrameAngle(tc)
            p=vsg_motor_parameters(); a=.73; R=[cos(a),-sin(a);sin(a),cos(a)];
            z=[.03;-.015;.02;-.005;83]; v=[9;-2];
            [~,before]=vsg_motor_rhs(z,v,p.w0,p.motor,1,false);
            [~,after]=vsg_motor_rhs([R*z(1:2);R*z(3:4);z(5)],R*v,p.w0,p.motor,1,false);
            tc.verifyEqual(after.torque,before.torque,'AbsTol',1e-12);
            tc.verifyEqual(after.magnetic_energy,before.magnetic_energy,'AbsTol',1e-12);
            tc.verifyEqual(after.input_power,before.input_power,'AbsTol',1e-12);
        end
        function positiveTorqueAcceleratesUnloadedRotor(tc)
            p=vsg_motor_parameters();
            [dz,o]=vsg_motor_rhs([.04;0;.035;-.002;0],[14;0],p.w0,p.motor,0,false);
            tc.verifyGreaterThan(o.torque,0);
            tc.verifyGreaterThan(dz(5),0);
        end
        function lockedRotorHasNoMechanicalWork(tc)
            p=vsg_motor_parameters();
            [dz,o]=vsg_motor_rhs([.04;0;.035;-.002;0],[14;0],p.w0,p.motor,1,true);
            tc.verifyEqual(dz(5),0);
            tc.verifyEqual(o.kinetic_energy,0);
            tc.verifyEqual(o.storage_derivative,o.input_power-o.copper_loss,'AbsTol',1e-10);
        end
        function fullPlantEnergyBalanceIncludingBridgeLoss(tc)
            p=vsg_motor_parameters(); p.Rbridge=.05; p.deadtime=520e-9;
            x=zeros(20,1); x(1:4)=[2;-1;10;2]; x(7:13)=[.03;-.015;.02;-.005;83;39;.4];
            [dx,o]=vsg_motor_plant_rhs(x,[12;2],p.w0,p,true,1.3);
            storage_dot=p.Cdc*x(12)*dx(12)+1.5*p.Lf*dot(x(1:2),dx(1:2))+ ...
                1.5*p.Cf*dot(x(3:4),dx(3:4))+o.motor.storage_derivative;
            tc.verifyEqual(storage_dot,dx(14)-sum(dx(15:20)),'AbsTol',1e-9);
            tc.verifyGreaterThan(o.bridge_loss,0);
            tc.verifyEqual(o.bridge_dc_power-o.bridge_output_power,o.bridge_loss,'AbsTol',1e-10);
        end
        function sourceCannotAbsorbRegeneratedEnergy(tc)
            p=vsg_motor_parameters(); x=zeros(20,1); x(12)=42;
            [~,o]=vsg_motor_plant_rhs(x,[0;0],p.w0,p,false,1);
            tc.verifyEqual(o.source_current,0);
        end
        function deadtimeAloneIsNotInventedHeat(tc)
            p=vsg_motor_parameters(); p.Rbridge=0; p.deadtime=520e-9;
            x=zeros(20,1); x(1:2)=[2;-1]; x(12)=40;
            [~,o]=vsg_motor_plant_rhs(x,[12;2],p.w0,p,false,1);
            tc.verifyEqual(o.bridge_loss,0);
            tc.verifyEqual(o.bridge_dc_power,o.bridge_output_power,'AbsTol',1e-12);
        end
        function invalidIntegrationStepRejected(tc)
            p=vsg_motor_parameters(); p.integration_step=3e-5;
            tc.verifyError(@()vsg_motor_run_case('motor_cold_start',p),'VSG:IntegrationStep');
        end
    end
end
