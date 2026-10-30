# Firmware safety hardening and validation

Implementation started 2026-10-13; final checks performed **2026-10-20 (UTC+7)**.
Agent runner/model: **Codex / GPT-6**.

**Status: software validation only. No board was flashed, connected to a power stage, or energized.** The saved sketch defaults to `DRY_RUN_NO_POWER_STAGE=1`; all four hardware-readiness acknowledgements remain `0`. Native tests and compiler success do not establish ADC timing, gate-driver operation, or hardware protection performance.

## Files and provenance

- `D:\workspace\engineering\vsg-project\hardware\esp32\vsg_controller\vsg_controller.ino` — integration, peripheral initialization, ISR/task scheduling and telemetry.
- `D:\workspace\engineering\vsg-project\hardware\esp32\vsg_controller\safety_policy.h` — shared startup, ADC handshake, PWM handover and deadline policies.
- `D:\workspace\engineering\vsg-project\hardware\esp32\tests\safety_policy_test.cpp` — native C++ regression tests exercising those actual shared policies.
- `D:\workspace\engineering\vsg-project\hardware\esp32\tests\run_policy_tests.py` — native build/run wrapper.
- `D:\workspace\engineering\vsg-project\hardware\esp32\tests\compile_matrix.py` — compile-only matrix in temporary sketch copies; it has no upload command.
- `D:\workspace\engineering\vsg-project\docs\notes\firmware_validation_2026-10-13.md` — this report.

Final source SHA-256:

| File | SHA-256 |
|---|---|
| `D:\workspace\engineering\vsg-project\hardware\esp32\vsg_controller\vsg_controller.ino` | `9963A68D018B0946786B6742DA80847165B7FBDCD683DA65258D912FBB0C7B85` |
| `D:\workspace\engineering\vsg-project\hardware\esp32\vsg_controller\safety_policy.h` | `4342C1B5F174B73C78706FF50EBB4E23B7DCEE80B659A57EF05219B6A2FC5B6B` |

The VSG control equations, gains and electrical design constants were preserved. No simulation files, project logs, or other agents' files were edited by this firmware work.

## Changes and their limits

1. **PWM handover:** every phase's compare value is written before generator actions are restored using `mcpwm_set_duty_type(..., MCPWM_DUTY_MODE_0)`. Duty writes alone do not undo the legacy driver's force-low mode. Any write/restore error removes the gate request and latches a fault. The hardware one-shot fault latch is never cleared by this handover.
2. **Startup ownership:** after initialization and calibration, the control task alone owns the state and gate request. A valid sample and passed protection checks precede the bootstrap request; protection remains active during the 10 ms bootstrap interval. `setup()` cannot subsequently overwrite FAULT with SOFT_START. FAULT is absorbing until a reset, and its first diagnostic reason is retained.
3. **ADC freshness:** acquisition requires BUSY initially LOW, then an observed assertion within 5 us, then completion within 50 us. A failed handshake performs no SPI data read. The original AD7606 serial timing requires idle-HIGH SCLK and falling-edge sampling; the sketch now selects SPI mode 2. The dry fixture uses a deterministic 5 us delay and dummy SPI transfer rather than floating BUSY polling. This fixture is not an ADC timing measurement.
4. **Deadline handling:** the ISR records the oldest pending release using the ESP-IDF microsecond timebase. The task checks notification backlog, wake delay and release-to-control-step-finish response. A response at or above 90 us, or more than one queued notification, removes the gate request and latches FAULT. The 100 us period retains a 10 us margin for timing telemetry and scheduling overhead. Maximum step time and response time include every executed step, not only one in 100; no 240 MHz CPU assumption is used. This measures from ISR entry, not the ideal hardware alarm edge, and it does not prove behavior during a completely stalled CPU or delayed interrupt delivery.
5. **Phase carriers:** timers 1 and 2 synchronize to timer 0's ZERO event with `mcpwm_sync_configure`, supported by the installed core. The up/down frequency argument is doubled to nominal 20 kHz for an approximately 10 kHz carrier. At 80 MHz timer resolution, the pinned legacy driver's period-minus-one arithmetic predicts approximately 10002.5 Hz, a 0.025% nominal error. Actual frequency, phase alignment, duty and update timing still require scope measurements. The 10 kHz control timer remains separate from the PWM carrier; phase-locked sampling is not claimed.
6. **Readiness lock:** real-power compilation requires explicit acknowledgement of independent latched shutdown, ADC reset/straps, board wiring and DC-bus protection. Invalid power-stage selections are rejected. A/B are compile selections, not proof that an arbitrary DRV8302 shield or discrete board matches the proposed pins.

The existing FPU-safe task architecture, offset calibration, GPIO34/39 external-pull-up requirement, overload integral and MCPWM one-shot status readback remain in place. Their physical performance is still unmeasured.

## Executed checks

Native tests were compiled with installed Microsoft Visual C++ 14.44.35207, `/W4 /WX`, and executed successfully on 2026-10-20:

- Fault injection at INIT, STANDBY, BOOTSTRAP, SOFT_START and RUNNING; subsequent initialize/start/finish calls cannot clear FAULT or replace its first reason.
- Bootstrap timing boundary and unsigned microsecond-counter wrap.
- Normal ADC conversion, initially asserted BUSY, stuck-LOW BUSY, stuck-HIGH BUSY and timeout across counter wrap; no SPI read after an invalid handshake.
- Notification backlog, missing notification, exact response-budget boundary and a late wake despite a short execution time.
- All three duty writes precede any PWM restore. Normal subsequent updates do not re-release generators. Failures at every duty-write/restore position, including the second and third restore, propagate failure.

These are native policy tests; they do not emulate ESP32 registers, interrupt timing, ADC electrical signals or the physical one-shot latch.

Compiler: Arduino CLI **1.5.1**, ESP32 Arduino core **2.0.17**, FQBN `esp32:esp32:esp32`, `--warnings all`. The legacy MCPWM/timer API is intentionally pinned to core 2.x; core 3.x is rejected by the existing guard. The new synchronization calls use the nondeprecated API available in 2.0.17. Compilation uses temporary copies under `D:\tools\tmp`; acknowledgement values of `1` exist only in disposable compile-test copies and do not certify hardware.

Final compile matrix, completed 2026-10-20: **10/10 expected outcomes**, four successful builds with **no compiler warnings**, five expected readiness-lock refusals and one expected invalid-stage refusal.

| Case | Result | Flash bytes | Global RAM bytes |
|---|---|---:|---:|
| A / default dry | PASS | 288385 | 21820 |
| A / real branch, temporary compile-only acknowledgements | PASS | 290189 | 21836 |
| B / dry | PASS | 288393 | 21820 |
| B / real branch, temporary compile-only acknowledgements | PASS | 290197 | 21836 |
| Real branch / all four acknowledgements absent | Expected `REAL POWER LOCKED` refusal | n/a | n/a |
| Real branch / shutdown acknowledgement missing | Expected `REAL POWER LOCKED` refusal | n/a | n/a |
| Real branch / ADC acknowledgement missing | Expected `REAL POWER LOCKED` refusal | n/a | n/a |
| Real branch / wiring acknowledgement missing | Expected `REAL POWER LOCKED` refusal | n/a | n/a |
| Real branch / DC-bus protection acknowledgement missing | Expected `REAL POWER LOCKED` refusal | n/a | n/a |
| `POWER_STAGE=999` | Expected unsupported-stage refusal | n/a | n/a |

`git diff --check` also passed for the owned firmware and report. Final source hashes above were checked again after compilation; the default source remained in dry mode with all acknowledgements unset.

Reproduce the checks without accessing a board:

```powershell
python "D:\workspace\engineering\vsg-project\hardware\esp32\tests\run_policy_tests.py"
python "D:\workspace\engineering\vsg-project\hardware\esp32\tests\compile_matrix.py"
```

The default CLI path is `C:\Program Files\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe`; data/core directory is `D:\tools\arduino-cli-data`. The compile wrapper accepts `--cli`, `--data` and `--temp-root` overrides. An initial interrupted Oct13 standalone CLI call returned an invalid-instance error; subsequent complete runs initialized normally. Only the final complete matrix is treated as evidence.

## Hardware acceptance still required

The authoritative physical plan is `D:\workspace\engineering\vsg-project\docs\notes\hardware_shutdown_and_bench_plan.md`. Before any readiness acknowledgement changes:

- Verify **IR2104 /SD LOW disables both HO and LO**, and HIGH permits complementary operation, against the actual board. This polarity was checked visually in the original manufacturer's Figure 1 and Figure 3. GPIO22 must request an external latched permit; it must not directly fight an open-collector comparator output. Verify fault dominance, power-on/reset default-off, manual re-arm conditions, and gate shutdown while the CPU is halted. MCPWM IN force-low alone turns on the low side when /SD is enabled; it is not a substitute for both-gates-off shutdown.
- Identify the exact ADC module. Verify its external power-up RESET pulse, CONVST A/B connection, RANGE, oversampling, serial-mode straps, V_DRIVE and six-channel signal mapping. No reset pinout or extra ADC channel was invented. Capture CONVST/BUSY/CS/SCLK/data and inject missing conversion and stuck BUSY faults. GPIO/API overhead can miss a very short BUSY pulse; the intended response is a safe fault, and actual timing must be qualified rather than bypassing the assertion check.
- Verify pin mapping, power-up pulls, the GPIO34/39 external pull-ups and actual driver/shield logic. Scope PWM resume, 3-phase carrier synchronization, bootstrap interval and requested/physical-enable signals with the power stage disabled first. Capture software and hardware faults during STANDBY/bootstrap and after normal operation; demonstrate no automatic restart.
- Verify independent **DC-bus undervoltage/overvoltage, source-current-limit and returned-energy protection**. The sketch still uses nominal `Vdc=40 V` and has no measured DC-bus channel or runtime Vdc trip. A simulation of source collapse cannot be treated as a firmware DC-bus protection test. Select and validate the physical sensing and shutdown circuit before claiming this protection exists.
- Record worst-case response/step time under representative telemetry and fault injection. Demonstrate the deadline trip using a controlled delay on an unpowered test fixture. Validate shutdown latency and MOSFET stress using actual waveforms; there is no measured sub-microsecond system shutdown claim.
- Only after the above, progress through the current-limited low-energy bench plan and compare matched-bandwidth measured signals with the Stage 5d switching model. Store raw scope/CSV evidence, board revision, exact source hash and toolchain settings. Native tests and software simulation are not HIL or a completed physical prototype.

## Primary references

- [Infineon IR2104 datasheet, PD60046-S](https://www.infineon.com/assets/row/public/documents/24/49/infineon-ir2104-ds-en.pdf), page 5 Figures 1/3: active-LOW shutdown and complementary outputs. Page 3 contains device propagation-delay specifications, not the complete comparator-to-MOSFET system latency.
- [Analog Devices AD7606/AD7606-6/AD7606-4 Rev. G datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/AD7606_7606-6_7606-4.pdf): RESET after power-up, BUSY conversion indication and serial read timing. [ADI no-OS AD7606 driver](https://github.com/analogdevicesinc/no-OS/blob/main/drivers/adc/ad7606/ad7606.c) also selects SPI mode 2; the exact module remains unqualified.
- [Espressif ESP-IDF v4.4.7 MCPWM driver](https://github.com/espressif/esp-idf/blob/v4.4.7/components/driver/mcpwm.c): duty comparator writes, generator-mode restore, synchronization and legacy frequency arithmetic.
- Installed matching header: `D:\tools\arduino-cli-data\packages\esp32\hardware\esp32\2.0.17\tools\sdk\esp32\include\driver\include\driver\mcpwm.h`; its `mcpwm_set_duty_type` documentation explicitly requires restoring the mode after `mcpwm_set_signal_low/high`, and its up/down enum documents the frequency halving.
- [Espressif ESP-IDF v4.4.7 ESP32 LAC timebase](https://github.com/espressif/esp-idf/blob/v4.4.7/components/esp_timer/src/esp_timer_impl_lac.c): IRAM timebase implementation and `esp_timer_get_time` alias used by the ISR.
