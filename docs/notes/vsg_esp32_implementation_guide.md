# VSG ESP32 implementation guide — 40 V / 100 W prototype

Revision 2026-10-20. Replaces the old 10 kVA tutorial and standalone ISR code examples; use the maintained sketch as the executable source.

Current design authority: `D:\workspace\engineering\vsg-project\docs\notes\design_baseline.md`.
Independent shutdown circuit and acceptance evidence: `D:\workspace\engineering\vsg-project\docs\notes\hardware_shutdown_and_bench_plan.md`.
Source review: `D:\workspace\engineering\vsg-project\docs\notes\project_review_2026-10-12.md`.

| Quantity | Current value |
|---|---|
| Mode / power / frequency | Islanded three-phase / 100 W nominal / 50 Hz |
| DC bus / AC target | 40 V nominal / 14 V peak per phase |
| AC RMS | 9.8995 V phase; 17.1464 V line-to-line |
| Filter per phase | Lf = 1.2 mH, Rf = 0.05 ohm; Cf = 10 uF with series Rd = 1 ohm |
| H / D / Rp / Rq | 5 s / 0.5 / 0.05 / 0.05 |
| PWM and control target | 10 kHz; actual timing requires measurement |
| Primary power stage | IRF540N + IR2104; independent hardware shutdown |
| Alternative | DRV8302 module; exact board ratings not yet qualified |

## Source and toolchain

Source: `D:\workspace\engineering\vsg-project\hardware\esp32\vsg_controller\vsg_controller.ino`.

The project pins Arduino-ESP32 2.0.17 and its legacy MCPWM/timer APIs. They are version-specific; a 3.x upgrade requires an explicit port and revalidation. Do not paste the superseded register-level ISR examples into the maintained sketch.

The timer ISR sends a FreeRTOS task notification. A high-priority control task performs ADC/SPI work, floating-point transforms, swing/droop and PI calculations, state transitions and PWM updates. Telemetry is separate. Floating-point control and blocking SPI work do not belong in the timer ISR. A 10 kHz target provides a 100 us deadline; scope measurements and every-cycle timing/missed-tick accounting are required to establish it is met.

## Control equations and units

Amplitude-invariant dq power: P = 1.5*(vd*id + vq*iq). Voltage references use phase peak values; the RMS line-to-line analysis base is 17.1464 V, not 24 V or 40 V.

The swing equation is:

    (2H/omega_s)*domega/dt = Pset_pu + (1-omega/omega_s)/Rp - Pe_pu - D*(omega-omega_s)

Here omega is rad/s and D multiplies a rad/s deviation. At the baseline, effective P-f slope is 0.005647 pu/pu (0.565%), despite Rp = 0.05. Compare inertia values at fixed damping/effective slope. Q-V droop uses Dq = Rq*14/100 = 0.007 V/VAR when Qbase = 100 VAR.

Current-loop design bandwidth is 1 kHz and voltage-loop design bandwidth is 100 Hz. Recompute gains from Lf, Rf and Cf when changing hardware. Stage 5c is the continuous controller reference; Stage 5d is discrete control. Sample delay, numerical integration, limits and anti-windup must be explicitly matched before declaring firmware equivalence. Stage 5e robustness tests have their own model-fidelity boundary.

## Startup and fault invariants

- DRY_RUN_NO_POWER_STAGE defaults to 1; gate request must remain LOW in dry-run.
- One control-task owner manages runtime state and gate request. FAULT must remain latched through standby/bootstrap/soft-start until explicit reset; setup must not overwrite it.
- Initialize valid compare duties, then explicitly restore MCPWM generator actions with the supported duty-type API. Updating duty alone does not undo force-low in the pinned driver.
- GPIO22 is MCU_REQUEST into external hardware permit logic. It is not a direct IR2104 SD wire. SD LOW disables both outputs; PWM IN LOW alone does not.
- Any real-power readiness flags describe evidence already obtained; toggling flags does not perform the physical tests.
- A hardware trip must latch shutdown independently of MCU operation and require deliberate re-arm. Software fault polling and PWM force-low are additional layers.

See the pinned-driver rationale in the project review and [Espressif driver source](https://raw.githubusercontent.com/espressif/esp-idf/v4.4.7/components/driver/mcpwm.c).

## Acquisition and calibration

AD7606 is the external simultaneous ADC; ACS712-20A is the current-sensor baseline. Firmware GPIO assignments are not proof of the module header wiring. Record actual AD7606 RESET source/power-up pulse, RANGE, oversampling straps, serial mode, VDRIVE, channel order and signed scale. Verify BUSY both asserts after CONVST and completes; stuck LOW and stuck HIGH must be separate injected cases. A timeout cannot replace the module's reset requirements.

Calibrate each zero-current offset and voltage/current scale using references before energizing the bridge. Check signal common mode, divider ratios, grounding and saturation across the intended range. Current sensor supply variation affects the measurement; do not substitute an ACS712-5A scale. Capture raw samples alongside converted values for fault diagnosis.

## Verification records

Record exact source revision/configuration and compiler/core version. Compilation and host checks establish only the tested software behavior. Save PWM phase alignment/carrier captures, timing maxima/missed cycles, ADC calibration and fault injection captures using the acceptance table in the shutdown plan. No HIL or physical bench completion is claimed in this guide.

For simulation comparisons, use each waveform's own timestamps and a stated window/bandwidth. Compare controller-sampled outputs at identical rates separately from plant ripple; do not interpret a once-per-carrier sample as the full 10 kHz ripple. Current/voltage saturation, DC-source behavior, dead-time and measurement errors require separate model coverage.

Simulation validation results and Stage 5d/5e fidelity limits: `D:\workspace\engineering\vsg-project\docs\notes\simulation_validation_2026-10-13.md`.
