# VSG project review — 2026-10-12 UTC+7

Reviewer: Codex / GPT-6, with an engineering sub-agent. Scope: source and documentation review plus independent inspection of existing MAT results. No firmware, model, wiring, or thesis source was modified. No hardware was operated or firmware flashed. MATLAB MCP could not attach, so no new MATLAB static-analysis or simulation pass is claimed.

## Assessment

The project has a substantial simulation foundation, including a discrete-controller Stage 5d, but repository evidence does not establish a working or validated physical prototype. Prioritize startup/protection correctness and trustworthy measurement before adding advanced control features.

Repository HEAD: `22a68c9` (2026-07-26). The July firmware fixes are committed. Pre-existing untracked manual-build guides and validators remain untouched.

Current implemented design: 40 V DC, nominal 100 W three-phase, 14 V peak/phase, Lf = 1.2 mH, Cf = 10 uF, Rd = 1 ohm, H = 5 s, D = 0.5, Rp = Rq = 0.05, nominal 10 kHz control/PWM. Older 24/48 V notes are not the implemented baseline.

## Priority 1 — repair startup and complete independent shutdown before powered testing

### PWM does not resume from its parked state

Evidence: `D:\workspace\engineering\vsg-project\hardware\esp32\vsg_controller\vsg_controller.ino:661` forces the three generators LOW. The control loop at line 562 subsequently calls only `mcpwm_set_duty()`. No `mcpwm_set_duty_type()` restores the generator actions. The comment at line 659 claiming duty updates clear the force is incorrect for the reviewed legacy driver.

The installed core 2.0.17 header at `D:\tools\arduino-cli-data\packages\esp32\hardware\esp32\2.0.17\tools\sdk\esp32\include\driver\include\driver\mcpwm.h:451` explicitly describes the required restoration. [Espressif's matching driver source](https://raw.githubusercontent.com/espressif/esp-idf/v4.4.7/components/driver/mcpwm.c) corroborates that duty updates change compare values, while duty-type setup restores generator event actions.

Action: implement an explicit handover after valid duty initialization, while preserving the fault latch. Verify all three PWM outputs on the bare controller before enabling a power stage.

### Startup can overwrite a software fault

Evidence: the same sketch starts the timer at line 877, checks only hardware OCP at line 883, enables drivers at line 894, then unconditionally assigns SOFT_START at line 899. The control task can enter FAULT for ADC/current/thermal problems during that interval. A software fault can therefore be overwritten, or gates enabled after that fault.

Action: give one task ownership of state transitions and gate enable; make FAULT persistent until explicit reset. Test faults before enable and during bootstrap delay, verifying that no later code re-enables gates or resumes startup.

### Documented OCP does not independently shut down both gate outputs

Evidence: `D:\workspace\engineering\vsg-project\docs\notes\power_stage_options.md:46` routes the comparator to ESP32 FAULT; line 77 routes gate enable from GPIO22. `D:\workspace\engineering\vsg-project\python\analysis\power_stage_A_wiring.py:195` likewise lacks a comparator-to-driver shutdown path. The sketch's hardware action forces PWM IN low; software later disables gates at line 608.

For an enabled IR2104, IN low requests the complementary low-side output; this differs from disabling both gate outputs. See the [Infineon IR2104 datasheet](https://www.infineon.com/assets/row/public/documents/24/49/infineon-ir2104-ds-en.pdf). Actual assembled wiring was not inspected.

Action: complete and document an independent, latched driver-disable circuit, including verified polarity/default state and GPIO/comparator arbitration. Do not simply short a comparator output against a push-pull MCU output. Demonstrate shutdown of HO and LO with CPU-independent fault injection.

## Priority 2 — repair Stage 5d data export and validation

Evidence: `D:\workspace\engineering\vsg-project\matlab\phase5d_discrete.m:256` retains only the frequency signal's time vector, then discards other signals' individual timestamps at lines 259–268. In the existing `D:\workspace\engineering\vsg-project\matlab\vsg_stage5d_out.mat`:

| Signal | Saved sample count |
|---|---:|
| t, frequency, sampled dq signals | 30,001 |
| Vload_abc, iL_abc, Vinv_a | 912,094 |

The sole exported time vector cannot describe the continuous waveform arrays. Preserve a time vector per rate/group, or export complete timeseries. Add dimension, timestamp monotonicity, finite-value and metadata checks.

The ripple verdict at `D:\workspace\engineering\vsg-project\matlab\phase5d_discrete.m:274` also compares sampled 5d dq signals with continuous 5c signals. Their peak-to-peak values do not measure identical bandwidths. Sampling once per PWM period can miss switching ripple. Compare controller-visible signals at identical rates separately from continuous plant ripple, and calculate THD from correctly timestamped plant waveforms with a stated frequency range and window.

Independently re-read saved results (not a new simulation):

| Quantity | Stage 5c | Stage 5d |
|---|---:|---:|
| Final frequency | 49.8959089 Hz | 49.8981208 Hz |
| Saved DC bus | 40 V | 40 V |
| Post-step dq-current p-p | 0.385343 A | 0.035277 A |

The frequency difference is 2.212 mHz. The unequal-rate current figures must not be interpreted as a physical ripple reduction. The saved 5d late/mid sampled-ripple ratio is about 0.977; that alone is not a stability-margin or hardware-safety proof.

Stage 5d depends on a previously built 5c SLX while separately hardcoding metadata. Assert the loaded model's parameters against metadata, save the source revision/build settings, and make a failed verdict produce a machine-readable failure rather than only printing FAIL.

## Priority 3 — extend the model to cover the actual operating envelope

The omissions are explicit at `D:\workspace\engineering\vsg-project\matlab\phase5d_discrete.m:41`: dead-time, ADC quantization/noise, current/voltage saturation and anti-windup, and DC-bus dynamics. The ideal 40 V source does not validate the BESS or supply behavior.

Recommended next model: add firmware-equivalent limits and anti-windup first, followed by finite DC-link capacitance/source impedance/current limits and load rejection. Then include dead-time, sensor errors and timing variation. Test load increase/decrease, startup, overload recovery, unbalance and component tolerances. Define acceptance limits before running the matrix. This is consistent with [MathWorks' grid-forming converter validation example](https://www.mathworks.com/help/simscape-electrical/ug/design-analyze-gridforming-converter.html), which treats current limiting and disturbances as explicit test dimensions; the example is a reference, not a claim of R2018b compatibility.

The existing post-step power is approximately 136 W, above the nominal 100 W rating. Establish the allowed transient/continuous power and thermal envelope for the actual inductors, switches, load resistors and source before reproducing this step physically.

## Priority 4 — capture real-time and ADC evidence

The sketch still defaults to DRY_RUN=1 (`D:\workspace\engineering\vsg-project\hardware\esp32\vsg_controller\vsg_controller.ino:147`); the README explicitly says it has not been bench-tested.

Check actual PWM frequency and alignment, ADC sample timing, worst-case execution time and missed deadlines. Current timing telemetry samples every 100th step (line 577), while missed notifications only increment a counter (line 593). Define an appropriate response to sustained overruns.

BUSY-high timeout handling exists, but line 704 does not prove BUSY asserted for a fresh conversion; stuck LOW can pass. Document the actual module's RESET, RANGE, oversampling and serial-mode configuration, validate conversion start and finish, and inject stuck-HIGH/LOW cases. See [Analog Devices AD7606 datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/AD7606_7606-6_7606-4.pdf). Board-specific reset circuitry remains unknown.

Keep build/toolchain settings, oscilloscope captures and telemetry CSVs with each bench result. Existing compilation records are useful but cannot replace these measurements.

## Priority 5 — reconcile thesis, instructions and learning progress

- `D:\workspace\engineering\vsg-project\docs\thesis\chapter4_simulation_results.md:38` still lists 48 V. Its line 234 discusses Stage 5d as future active-damping work, although the implemented 5d is a discrete-control model.
- `D:\workspace\engineering\vsg-project\docs\thesis\chapter5_hardware_design.md:149` still describes a 24 V battery buffer; line 216 lists obsolete firmware/filter values. The locked 40 V decision at line 280 conflicts with old pending decisions from line 292 onward. Resolve battery/source architecture explicitly before using these instructions for construction.
- `D:\workspace\engineering\vsg-project\docs\notes\vsg_esp32_implementation_guide.md:385` still describes control in a timer ISR rather than the implemented task.
- Explain damping units and effective droop in the thesis. For the implemented swing law, effective slope is 1/(1/Rp + D*omega_s) = 0.005647 pu/pu (about 0.565%), despite the governor parameter Rp = 5%. Compare H values at the same damping/effective slope when claiming an inertia benefit.
- `D:\workspace\engineering\vsg-project\matlab\manual\PROGRESS.md` records manual Stages 1 and 2 passed, with Stage 3 next. That learning track is distinct from the scripted Stage 5d progress. Preserve and version its currently untracked guides/validators when preparing the next project commit.

## Recommended sequence

1. Repair PWM handover and startup state ownership; define independent driver shutdown.
2. Repair multirate exports, align validation signals and save reproducible pass/fail evidence.
3. Add limits, DC-side dynamics and a bounded disturbance test matrix.
4. Complete bare-board timing/ADC/fault measurements, then staged powered validation.
5. Update the thesis and construction documents to the same verified design baseline.

Advanced features such as adaptive inertia or additional damping schemes can follow after this baseline is reproducible. The immediate project contribution is a defensible simulation-to-ESP32 comparison with measured limitations.
