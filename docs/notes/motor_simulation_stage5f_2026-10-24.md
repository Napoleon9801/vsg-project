# Stage 5f — VSG supplying an induction motor

Date: 24 October 2026. Runner/model: Codex desktop / GPT-6. Initial implementation assistance: simulation_fixes; parent completed implementation after worker usage-limit interruption.

**Run status: experiments completed; coupled motor operation does not pass the declared operating screen. Stage 5f overall numerical validation also remains FAILED because cold-start integration convergence is unresolved.**

สรุปภาษาไทย: เพิ่มแบบจำลอง induction motor ที่มีแรงบิด ความเฉื่อย และการสูญเสีย พร้อม DC bus ที่ยุบตัวได้แล้ว มอเตอร์สมมติหมุนได้ แต่ค่าควบคุมเดิมและค่าที่ทดลองเพิ่มอีก 3 ชุดยังไม่ผ่านเกณฑ์การทำงาน จึงยังไม่ควรใช้ผลนี้เลือกรุ่นมอเตอร์หรือเปลี่ยน firmware สำหรับขับจริง ผลทดสอบแยกมอเตอร์กับแหล่งจ่ายอุดมคติผ่าน ช่วยยืนยันสมการมอเตอร์ แต่ไม่ได้ยืนยันเสถียรภาพของระบบ VSG ทั้งชุด

## Purpose and scope

Napoleon authorized further simulation development and an exploratory motor load. This study retains the40VDC/100W islanded design and the selected firmware control algebra. It adds a hypothetical low-voltage three-phase squirrel-cage induction machine, rather than interpreting a passive R–L branch as a motor.

This is a toolbox-free MATLAB averaged model compatible with R2018b, extending Stage5e's study approach. Existing Stage5c/5d switching models and Stage5e results are preserved. It does not create a new Simulink switching model or establish physical motor compatibility. The intended deliverable remains the VSG prototype; a motor is an optional research load, not an added purchasing commitment within the7,200THB budget.

## What is more realistic

- Four electromagnetic flux states and one mechanical speed state represent stator/rotor energy exchange, slip, electromagnetic torque and inertia.
- Stator and rotor copper losses, viscous friction and a speed-dependent mechanical fan load consume energy explicitly.
- A finite DC-link capacitor and source-only supply expose sag when current availability is insufficient; the supply cannot absorb negative current.
- Individual phase duties are clipped to0.03..0.97 and held as stationary alpha/beta commands for a controller interval, including an assumed one-tick command delay. The rotating dq plant therefore sees the physically held phase command, rather than a dq command that rotates continuously during that hold.
- An additional case applies assumed bridge resistance and a fundamental opposing-current deadtime voltage approximation. Deadtime modifies effective conversion voltage/power; it is not treated as heat by itself. Resistive bridge dissipation is separately drawn from the DC bus. No diode or switching-energy loss model is claimed.
- At sampled firmware OCP/thermal faults or a model-validity boundary, integration stops and exports the time/reason. The model does not invent post-shutdown diode/freewheel behavior.

## Equations and conventions

All dq vectors use the amplitude-invariant Park transform, q=-sin(theta), and J[d;q]=[-q;d]. Three-phase instantaneous power under the balanced-model assumption is1.5*v·i. SI rotor values are referred to the stator.

For Ls=Lls+Lm, Lr=Llr+Lm, Delta=Ls*Lr-Lm^2:

```text
i_s = (Lr*psi_s - Lm*psi_r) / Delta
i_r = (Ls*psi_r - Lm*psi_s) / Delta
dpsi_s/dt = v_s - Rs*i_s - omega_e*J*psi_s
dpsi_r/dt = -Rr*i_r - (omega_e - pole_pairs*omega_m)*J*psi_r
Te = 1.5*pole_pairs*(psi_sd*i_sq - psi_sq*i_sd)
Jm*domega_m/dt = Te - Tload - B*omega_m
```

The fan torque is signed to oppose rotation, using a smooth sign transition rather than clipping negative speed:

```text
Tload = multiplier*(25/150)*(omega_m/150)^2*tanh(omega_m/1)
```

Thus25W is the assumed fan demand at150rad/s when multiplier=1, not a manufacturer's motor nameplate rating. The torque-step scenario increases the multiplier to1.8; actual shaft power changes with the resulting speed and must be read from the results.

Magnetic energy is0.75*(psi_s·i_s+psi_r·i_r); kinetic energy is0.5*Jm*omega_m^2. The motor identity checked in tests is:

```text
d(Wmag + Wkin)/dt = Pmotor - Pstator_copper - Protor_copper - Pfriction - Pshaft_load
```

The full-plant energy residual subtracts integrated source power at the DC-bus terminals and adds filter/bridge/copper/friction/load dissipation to the change in all stored electrical and mechanical energy. Power integrals use the same RK4 substeps as the states. Source terminal energy excludes upstream source internal dissipation; it is not an efficiency model of a real bench supply.

## Assumptions, not measured parameters

| Quantity | Value |
|---|---|
| Rs / Rr referred to stator | 0.8 /0.6ohm |
| Stator / rotor leakage | 3 /3mH |
| Magnetizing inductance | 60mH, linear and unsaturated |
| Pole pairs | 2; synchronous speed1500rpm at50Hz |
| Mechanical inertia / friction | 2e-4kg*m^2 /1e-5N*m*s/rad |
| Fan reference | 25W at150rad/s |
| Inverter voltage target | 14Vpeak phase ≈9.90Vrms phase ≈17.15Vrms line-to-line |
| Filter | Lf1.2mH/Rf0.05ohm; Cf10uF with seriesRd1ohm |
| Source | 40V,0.30ohm effective droop,4A current limit, source only |
| DC link | 2200uF |
| Limited-source case | 0.8A, motor connects at3s |
| Nonideal case | Rbridge0.05ohm, deadtime520ns fundamental approximation |
| Control interval / plant integration | 100us /10us RK4; cold/direct connection rerun at5us, cold start additionally at2.5us |
| Operating frequency | Existing VSG near50Hz; voltage ramps for2s during startup |

This control remains VSG feeding a motor as a load. The startup is a voltage ramp at approximately50Hz, not a V/f frequency ramp, rotor-speed controller or field-oriented motor control. No low-speed torque boost has been invented or added to the firmware.

## Scenarios and acceptance interpretation

Seven scenarios: RL reference, motor connected from cold startup, motor connected at3s after unloaded voltage buildup, fan-load coefficient step at3s, rotor locked at zero speed,0.8A-limited source with delayed connection, and assumed bridge loss/deadtime.

The cold-start and direct-connection cases are repeated with half the plant integration step. The same controller interval is retained; this is integration convergence, not a test of controller scheduling jitter.

Numerical tests, completed simulations, motor rotation and acceptable operation are distinct flags. A completed locked-rotor calculation is not a successful motor application. Model boundaries at DC bus10..48V are study validity stops, not firmware UV/OV protection. Sampled current/thermal protections mirror selected thresholds but do not validate the independent hardware shutdown circuit.

The settled motor screen requires completion,0<slip<0.2, and final0.2s peak-to-peak variation below0.5rad/s in speed,0.28V in voltage magnitude and0.1Hz in frequency. Mean voltage must be within10% of14Vpeak, mean bus at least36V and mean frequency48..52Hz. These are declared study screening criteria, not a motor rating, THD test or hardware acceptance standard. An independent per-phase steady-state equivalent circuit checks the final current, input power and torque when this screen is met.

Logged states and instantaneous powers are sampled before the new command is applied (left limit). Frequency and `requested_duty_min/max` are newly computed control outputs; requested duty enters the delay queue and is not the duty that produced the power in the same row. Do not infer instantaneous conversion efficiency from misaligned command/power traces.

## Executed results

MATLAB R2018b executed all seven scenarios. All seven passed their finite-state, command/source limit, nonnegative-loss and integrated energy-balance checks. **Those checks do not establish convergence or acceptable operation.** Ten motor/plant unit tests passed, including reference-frame invariance, energy balance and the regression that deadtime voltage error alone is not resistive heat.

The following values come from the original 10us integration run. RPM and shaft power are means over the last 0.2s of each recorded trajectory, including the shortened locked-rotor record. They are not steady-state ratings. Current is the maximum inverter dq-vector magnitude, not a phase RMS rating. The cold-start numbers remain provisional because its trajectory convergence test failed.

| Scenario | End of record | Mean rpm | Mean shaft W | Minimum bus V | Peak inverter current A | Motor operating screen |
|---|---|---:|---:|---:|---:|---|
| R–L reference | Completed 6s | — | — | 39.239 | 4.708 | Not applicable |
| Cold motor startup | Completed 6s | 1370.4 | 22.14 | 39.432 | 3.319 | FAIL |
| Motor connects at3s | Completed 6s | 1308.0 | 19.79 | 39.182 | 5.359 | FAIL |
| Fan coefficient step x1.8 | Completed 6s | 1231.1 | 29.99 | 39.365 | 3.856 | FAIL |
| Locked rotor | Sampled thermal trip at5.4798s | 0 | 0 | 39.435 | 5.930 | FAIL |
| Source limited to0.8A | Completed 6s, no sampled fault | 566.7 | 1.55 | 10.373 | 4.724 | FAIL |
| Assumed resistance/deadtime | Completed 6s | 1288.1 | 18.88 | 39.453 | 3.306 | FAIL |

Cold startup has final-window speed variation39.827rad/s and voltage-magnitude variation18.653V peak-to-peak. Direct connection has52.985rad/s and17.907V respectively. Both are far outside the declared0.5rad/s and0.28V limits. The limited-source case settles near an unacceptable low-voltage/low-speed point; its small final speed variation does not make it acceptable. Source current limit is upstream DC current, distinct from the inverter phase-current envelope.

The locked-rotor result represents the modeled sampled thermal accumulator reaching its threshold, not a measured winding temperature or a demonstrated hardware shutdown. The limited-source result exposes the absence of measured DC-bus UV/OV protection in the mirrored firmware behavior. A10V model boundary is not a protection threshold implemented in the firmware.

![Motor startup and connection study](D:/workspace/engineering/vsg-project/docs/figures/stage5f_motor_operation_2026-10-24.png)

![DC-source limits and locked rotor](D:/workspace/engineering/vsg-project/docs/figures/stage5f_motor_limits_2026-10-24.png)

These figures show the original10us averaged trajectories. Cold-start details are illustrative pending convergence; none are measured hardware traces or PWM/THD results.

### Integration convergence: an unresolved failure is retained

Maximum differences compare matching controller-sample times over the entire record. Voltage means the maximum absolute difference across the dq voltage components, not a difference of mean magnitudes. The declared tolerances are0.05V voltage,0.05V bus,0.05A current and0.5rad/s speed.

| Case and integration steps | Voltage difference V | Bus difference V | Current difference A | Speed difference rad/s | Result |
|---|---:|---:|---:|---:|---|
| Cold10us versus5us | 0.587034 | 0.013907 | 0.062423 | 2.125321 | FAIL voltage/current/speed |
| Direct connection10us versus5us | 0.001856 | 0.000169 | 0.000329 | 0.002066 | PASS |
| Cold5us versus2.5us | 0.109361 | 0.002540 | 0.010959 | 0.301924 | FAIL voltage |

Refinement reduces the discrepancy but does not meet the voltage tolerance. Therefore `validation_stage5f.json` and the refinement report deliberately retain `pass=false`; the Stage5f runner saves evidence and then raises an assertion. Small energy residuals are insufficient to certify trajectory accuracy. The converged direct-connection comparison independently shows unacceptable oscillation, so the practical failure finding does not rest solely on the cold-start run. Long-time numerical sensitivity, controller/LC interaction and limiting need further diagnosis; a particular physical cause has not been proven.

### Independent motor-physics check

The same hypothetical motor, supplied directly by an ideal14Vpeak/50Hz source, was integrated with variable-step ODE45 and compared with a separately implemented per-phase induction-machine equivalent circuit in Python. It settles at1396.438rpm,23.164W shaft load and0.159867N*m electromagnetic torque. Current, input power, torque and shaft-power relative errors are below1.4e-14; power balance, zero mechanical work at locked rotor, zero synchronous torque and generating-torque sign checks pass.

This validates consistency of the linear motor equations and their equilibrium implementation. It is not an experimental motor validation or a test of coupled inverter stability. The coupled-run phasor reports contain `checked_count=0, pass=null` because no case passed the operating screen; an empty comparison must never be reported as a pass.

### Stage5g: bounded controller experiment

Three simulation-only candidates increased voltage Kp and reduced voltage Ki to0.25 times baseline. Current PI, source and motor assumptions were retained. None is adopted in firmware.

| Voltage Kp multiplier | Mean rpm, final0.2s | Speed peak-to-peak rad/s | Voltage magnitude peak-to-peak V | Operating screen |
|---|---:|---:|---:|---|
| x4 | 1314.1 | 38.882 | 10.371 | FAIL |
| x8 | 1408.7 | 10.286 | 9.150 | FAIL |
| x12 | 1398.8 | 0.552 | 14.837 | FAIL |

All three complete their numerical-invariant checks, but have not received separate integration-refinement studies. The x12 candidate's small speed variation conceals substantial voltage oscillation. Mean RPM alone is an inadequate tuning objective. No stable motor-drive setting was found in this bounded sweep.

![Simulation-only voltage PI candidates](D:/workspace/engineering/vsg-project/docs/figures/stage5g_motor_damping_2026-10-24.png)

### Performance and preserved baseline

Profiling identified repeated construction of observation structures at RK4 stages as unnecessary overhead. Requesting only the derivatives/powers needed by the integrator reduced a warmed0.05s cold-start benchmark from1.029863s to0.392341s (2.625x), with maximum logged-data difference0. This is a short-benchmark result, not a claim about every full run.

Firmware was not changed by this motor study. Its SHA-256 remains `9963A68D018B0946786B6742DA80847165B7FBDCD683DA65258D912FBB0C7B85`; dry-run defaults and readiness holds remain. No firmware flash, physical power test or motor purchase occurred.

## Next engineering work

1. Diagnose the coupled discrete controller, LC filter and motor dynamics using equilibrium linearization and sampled-loop analysis; test whether damping/current-loop changes address the observed oscillation. Blindly increasing voltage Kp did not resolve it.
2. Resolve cold-start integration sensitivity with a justified solver/refinement study before publishing precise transient values. Preserve the original failures and declared thresholds.
3. Require successful startup, load-step and limited-source behavior before proposing controller changes for firmware. Add measured-bus protection and returned-energy handling as separate design tasks.
4. Obtain real motor nameplate/parameter data if the motor extension is retained. Continue the40V/100W islanded prototype scope and lab inventory work; these hypothetical results do not justify additional procurement.

## Reproduction and files

In licensed MATLAB R2018b:

```matlab
addpath('D:\workspace\engineering\vsg-project\matlab');
phase5f_motor_realism;
```

The current Stage5f run is expected to raise `Stage5f numerical/physics checks failed` **after saving** its reports. Run the following separately after that expected assertion:

```matlab
phase5f_refine_convergence('motor_cold_start');
vsg_motor_ideal_source_check;
phase5g_motor_damping;
```

Plot/export and independent phasor checks:

```powershell
python "D:\workspace\engineering\vsg-project\python\analysis\plot_stage5f_motor.py"
python "D:\workspace\engineering\vsg-project\python\analysis\motor_equivalent_circuit.py"
python "D:\workspace\engineering\vsg-project\python\analysis\plot_stage5g_motor.py"
```

Main sources:

- `D:\workspace\engineering\vsg-project\matlab\phase5f_motor_realism.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_motor_parameters.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_motor_rhs.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_motor_plant_rhs.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_motor_run_case.m`
- `D:\workspace\engineering\vsg-project\matlab\test_vsg_motor.m`
- `D:\workspace\engineering\vsg-project\matlab\phase5f_refine_convergence.m`
- `D:\workspace\engineering\vsg-project\matlab\phase5g_motor_damping.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_motor_ideal_source_check.m`
- `D:\workspace\engineering\vsg-project\python\analysis\motor_equivalent_circuit.py`

Evidence is saved under `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5f`. MATLAB source hashes and unchanged firmware identity are recorded with the results; plotting refuses stale MATLAB source identities.

Additional outputs are under `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5g` and `D:\workspace\engineering\vsg-project\matlab\validation_outputs\motor_ideal_source`. These generated data directories are Git-ignored local evidence. A portable hash/status manifest is saved at `D:\workspace\engineering\vsg-project\docs\notes\motor_study_manifest_2026-10-24.json`; source files and figures remain in the working tree and have not been committed.

## Limits and implications for buying a motor

There is no identified real motor. Inductances, losses, inertia, fan load and source dynamics are assumed, with no saturation, core loss, temperature dependence, rotor skin effect, PWM ripple/THD, ADC timing/quantization, unbalance, common-mode sensing or switching-device model. Do not use this result to order a motor or claim full100W mechanical output. Nameplate winding voltage/frequency, current, pole count and motor parameters must be matched to the low-voltage inverter and its real source/protection envelope first.

## Primary references

- [MathWorks induction-machine equations](https://www.mathworks.com/help/simscape-electrical/ref/inductionmachinesquirrelcage.html): reference-frame and flux-current structure. The present implementation uses SI quantities and the amplitude-invariant1.5*pole_pairs torque factor; it does not invoke the current Simscape block or copy its per-unit parameters.
- [Imperix TN138: V/f induction-machine control](https://imperix.com/doc/implementation/vf-control-induction-machine): distinguishes frequency/flux-based motor control from this fixed-frequency VSG load study; no experimental results from that note are attributed to this prototype.
- [NXP AN4863: deadtime in VSI drives](https://www.nxp.com/docs/en/application-note/AN4863.pdf): current-polarity-dependent average-voltage error. This study retains only a fundamental approximation and models resistive heat separately.
