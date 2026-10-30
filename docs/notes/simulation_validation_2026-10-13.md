# Simulation validation changes — started 2026-10-13, final check 2026-10-20 UTC+7

Agent runner/model: Codex / GPT-6 engineering sub-agent. Repository baseline HEAD: `22a68c9`; changes remain uncommitted. Validation uses the licensed MATLAB R2018b installation at `D:\MATLAB1\bin\matlab.exe`, not the expired R2026a MCP installation. No hardware was operated.

## Implemented

`D:\workspace\engineering\vsg-project\matlab\phase5d_discrete.m` now saves schema version 2. The authoritative representation is `signals.<name>.time` paired with `signals.<name>.data`. Existing flat names remain with explicit `time_<name>` companions. `t` denotes only the omega/frequency clock; it must never index the continuous plant waveform arrays. The new run retains 30,001 controller samples and 912,094 plant samples, each with its correct timestamp vector. Continuous dq observations are tapped **before** the controller ZOH.

Comparison with Stage 5c uses continuous dq observations from both models, linearly resampled onto the same 5 microsecond grid and filtered using the same 1 ms boxcar. This is a control-envelope comparison. It does not measure raw PWM ripple or THD. Windows are 0.90–0.99 s, 1.8–2.0 s and 2.8–2.99 s; the prestep window excludes the switching instant at 1 s.

The run asserts selected loaded-model electrical, load and controller parameters against the 40 V baseline, checks the baseline MAT parameter values, rejects invalid exports, records SHA-256 source/model/result identities, and rejects source changes during execution. These are parameter/provenance guards, not a proof that every block implements the intended mathematics. JSON criteria and pass/fail evidence are saved even if the regression verdict fails.

Stage 5d retains its original ideal switching plant and selected discrete effects. It does **not** reproduce all firmware behavior: startup ramp, capacitor-current feedforward, vector clamps, conditional anti-windup, protection, ADC behavior and real DC-source behavior remain outside Stage 5d. The former “bench-safe gains” claim is removed.

`D:\workspace\engineering\vsg-project\matlab\phase5e_robustness.m` adds a separate, bounded **averaged dq** study, with a 10 kHz controller and RK4 plant integration at 10 microseconds. Its shared helper mirrors the firmware's vector current-reference limit, voltage-command limit, capacitor and inductor decoupling, and conditional integrator formulas in double precision. It parses and asserts the actual firmware numeric constants before running. This is not compiled firmware/SIL.

The assumed finite DC source is 40 V with 0.30 ohm source resistance, 2,200 microfarad DC capacitor, no sinking current, and a 4 A source-current limit (2.7 A in the source-limiting scenario). These are **study assumptions, not measured or selected BESS hardware values**. Applied voltage scales with actual bus voltage while duty normalization remains fixed at 40 V, matching the firmware's lack of a measured DC-bus input.

The six cases run 6 s with a 2 s startup ramp, disturbance at 3 s, and load restoration at 4.5 s: nominal, 30% resistance reduction, tenfold resistance increase, 0.55 ohm overload, source current limit, and a combined nonideal approximation. The last case adds a two-tick delay, 520 ns fundamental deadtime voltage approximation, and 0.01-unit dq quantization plus 0.02-unit dq bias (V for voltage, A for current). These are sensitivity assumptions, not sensor/gate-driver characterizations. The delay is applied to dq commands and is not an exact emulation of holding previous abc duty cycles while the rotating frame advances.

Sampled phase overcurrent and excess mean-square thermal accumulation are included. A latched fault drives an ideal zero-voltage bridge surrogate; actual diode/freewheel turn-off and independent hardware shutdown are **not** simulated. A 10 V bus boundary is a numerical model-validity stop, not a firmware undervoltage function.

## Regression evidence

The completed combined run is recorded in `D:\workspace\engineering\vsg-project\matlab\validation_outputs\final_validation.log`: **11 of 11 unit checks, Stage 5d's three regression gates, and six of six Stage 5e expectation checks passed**. On 2026-10-20 all recorded Stage 5d source/model/helper hashes were rechecked against current files and matched; Stage 5d was therefore not needlessly rerun. The final firmware-provenance Stage 5e rerun completed all six cases successfully on 2026-10-20, recorded in `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5e_final_2026-10-20.log`. The parent independently rechecked all recorded Stage 5d and Stage 5e source hashes against current files; all matched, including firmware SHA-256 `9963a68d018b0946786b6742da80847165b7fbdcd683da65258d912fbb0c7b85`.

Stage 5d verified results (final simulation duration 18.6 s):

| Quantity | Stage 5d | Stage 5c |
|---|---:|---:|
| Mean final-window frequency | 49.8981223 Hz | 49.8959107 Hz |
| Final-window current envelope peak-to-peak | 0.0374021 A | 0.00519282 A |
| Final-window voltage envelope peak-to-peak | 0.0805611 V | 0.0146393 V |

The current envelope is approximately 7.2 times the continuous-controller envelope; it is **not** within a strict 3x ratio. The actual regression threshold is `3 * max(Stage5c_current_envelope, 0.05 A)`, which is 0.15 A here. Other gates are a frequency difference below 0.01 Hz and a late/mid current-envelope ratio below 1.5; measured growth ratio is 0.977414. Voltage envelope is reported without an acceptance gate. All three explicit gates pass. These thresholds are screening criteria, not hardware requirements.

The 11 passing export/control unit tests exercise valid multirate data; mismatched lengths; repeated/reversed timestamps; NaN data; infinite timestamps; missing clocks; both vector clamps and integrator hold; voltage/current integrator unwinding; and stale source-manifest rejection.

Stage 5e case results:

| Case | Expectation checks | Minimum bus | Peak dq current magnitude | Settled regulation screen | Protection |
|---|---|---:|---:|---|---|
| Nominal | PASS | 39.239 V | 4.708 A | Acceptable under screening criteria | None |
| Load step | PASS | 33.569 V | 6.652 A | Acceptable after settling; transient bus dip flagged | None |
| Load rejection | PASS | 39.239 V | 4.708 A | Acceptable under screening criteria | None |
| Overload | PASS: latched trip expected | 39.227 V | 10.001 A | Not acceptable / tripped | Sampled thermal at 3.5908 s |
| Source current limit | PASS: degradation expected | 16.781 V | 5.945 A | **Not acceptable** | None |
| Combined nonideal approximation | PASS | 34.415 V | 7.161 A | Acceptable after settling; transient bus dip flagged | None |

The current-reference clamp activates for 4,519 ticks in overload and 26,687 ticks in the source-limited case. Plant peak dq current can exceed the 10 A reference limit slightly; the reference clamp is not an instantaneous physical current guarantee. The source-limited case has mean disturbed vd 7.874 V and mean disturbed bus 16.784 V, and still has vd 10.908 V at the final window after load restoration. Its expectation PASS is evidence of degraded regulation, **not** a successful operating point or recovery. Faulted-model discharge behavior is not a prediction of real disabled gate-driver behavior.

## Reproduction

In licensed MATLAB R2018b:

```matlab
addpath('D:\workspace\engineering\vsg-project\matlab');
test_vsg_validation;
phase5d_discrete;
phase5e_robustness;
```

For the desktop executable, use `-r`, `-wait` and `-logfile` (R2018b has no `-batch`). Runs are launched hidden. Stage 5d reads the existing Stage 5c model and baseline MAT; it does not rebuild or overwrite those references. Its generated model/result/report go to `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5d\`. Stage 5e case MATs and JSON go to `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5e\`. Existing generated outputs receive timestamped backups before replacement. `VSG_VALIDATION_OUTPUT_DIR` overrides only Stage 5d's output directory; Stage 5e accepts an optional output directory argument.

Primary evidence files:

- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5d\validation_stage5d.json`
- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5d\vsg_stage5d_out.mat`
- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5e\validation_stage5e.json`
- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\unit_report.mat`

Generated MAT/SLX files and backups are not intended for source control. The existing original reference outputs, `D:\workspace\engineering\vsg-project\matlab\manual\`, and the existing manual Stage 1/2 validators are preserved.

## Scope and remaining validation

An expectation PASS means the declared behavior occurred. It does not imply acceptable operation. Each Stage 5e case separately reports `regulation_acceptable`, `expected_degraded_regulation`, `expected_fault`, and `protection_triggered`. Regulation screening requires settled disturbance-window mean vd within 10% of 14 V, mean bus at least 36 V, and no fault; transient bus dips below 36 V are flagged separately.

The source-limited case reveals a material gap: severe DC-bus sag can occur without triggering firmware overcurrent/thermal protection. Real hardware needs a verified DC-bus undervoltage/overvoltage interlock or a separately specified sensing/protection implementation. Do not invent ADC scaling or thresholds from this study.

No conclusions about unbalanced loads, nonlinear loads, switching losses, THD, measured sensor noise, execution jitter, gate-driver behavior, BESS charge acceptance, or independent shutdown timing can be drawn from this balanced averaged dq model. Solver convergence and cross-validation against a switching model with the same finite-source/limit dynamics remain future work. The source-current-limited waveform and assumed source parameters must be replaced/checked against measured hardware before using them as design evidence.

Changed MATLAB source files:

- `D:\workspace\engineering\vsg-project\matlab\phase5d_discrete.m`
- `D:\workspace\engineering\vsg-project\matlab\phase5e_robustness.m`
- `D:\workspace\engineering\vsg-project\matlab\test_vsg_validation.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_validate_signals.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_compare_stage5.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_assert_stage5c.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_source_identity.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_assert_source_identity.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_backup_output.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_firmware_control_step.m`
- `D:\workspace\engineering\vsg-project\matlab\vsg_assert_firmware_parameters.m`
