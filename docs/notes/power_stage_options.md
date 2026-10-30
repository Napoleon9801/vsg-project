# VSG power-stage options — current implementation reference

Revision 2026-10-20. Functional architecture only; actual assembly and module ratings remain unqualified.

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

## A — primary discrete stage

Three IR2104 half-bridge drivers control six IRF540N switches. The bootstrap driver is non-isolated. IR2104 has undervoltage lockout and internally set dead-time (520 ns typical under datasheet conditions); neither establishes acceptable dead-time or fault energy on the assembled bridge. Verify gate waveforms, bootstrap droop, switch overshoot and thermal behavior.

According to the [Infineon IR2104 datasheet](https://www.infineon.com/assets/row/public/documents/24/49/infineon-ir2104-ds-en.pdf), SD LOW disables both HO and LO; SD HIGH permits switching. IN LOW alone can turn LO on. Therefore MCU PWM force-low is supplemental protection, not an independent all-gates-off function.

```text
Comparator FAULT_N --> asynchronous CLEAR of hardware permit latch
                   --> ESP32 GPIO34 / MCPWM F0
Power supervisor ----> CLEAR; default latch state = disabled
Deliberate ARM ------> set latch only while fault healthy and MCU request LOW
GPIO22 MCU_REQUEST -- AND -- SD_PERMIT --> all three IR2104 SD inputs
HARDWARE_PERMIT ------/
```

External pull-downs keep MCU_REQUEST and SD_PERMIT LOW during reset, power loss or disconnected MCU. Hardware fault clears the latch even if the CPU stalls, and a vanished fault must not automatically re-arm it. GPIO34 requires an external pull-up to 3.3 V on the verified open-collector fault branch. Do not tie a comparator output against a push-pull GPIO output. Verify logic levels and loaded HIGH margin, power sequencing and the final interface using the shutdown document.

| Firmware signal | ESP32 GPIO | Intended destination |
|---|---:|---|
| PWM A/B/C | 25 / 26 / 27 | Driver IN signals, through verified level interface as needed |
| MCU_REQUEST | 22 | External permit logic; never direct bypass of the hardware latch |
| FAULT_N | 34 | Verified fault monitor and MCPWM F0; external pull-up |

These are firmware assignments, not module header pinouts. The comparator threshold, shunt/sensing coverage, blanking, latch parts and measured total shutdown latency remain qualification items. Do not infer a sub-microsecond end-to-end shutdown from the peripheral alone.

## B — DRV8302 alternative

The firmware includes a DRV8302 configuration, but no exact purchased module schematic or board rating has been established. Verify MOSFET and capacitor voltage margins, buck output and current, 3-PWM mode, enable/fault polarity, overcurrent threshold, dead-time configuration and cooling against the actual board and [TI DRV8302 datasheet](https://www.ti.com/lit/ds/symlink/drv8302.pdf). Chip ratings do not establish the board's continuous current or bus rating. Do not copy the old generic “8–60 V / 30 A” claim into purchasing or operating instructions.

Any alternative must provide equivalent default-off, independent latched shutdown; changing POWER_STAGE does not qualify the circuit. GPIO39 warning input, where used, also needs the verified external bias/interface.

## Supply, energy and cost

Use separately regulated auxiliary rails for initial testing. A generic LM2596 module is not approved on the 40 V bus; see [TI LM2596 datasheet](https://www.ti.com/lit/ds/symlink/lm2596.pdf). BESS voltage/interface and an energy absorption path remain unresolved; do not directly parallel the historical 24 V battery with this bus.

The old 2026-05-30 planning estimates were roughly 585 THB for the listed discrete-stage parts and 1,010–1,510 THB for the alternative module group. They are historical, incomplete for the revised shutdown circuit and not current quotations. Requote the final reviewed BoM; no present cost or procurement availability is implied.

Follow the shutdown acceptance plan with auxiliary-only gate captures before staged current-limited powered tests. No bench validation is claimed here.

Simulation validation results and Stage 5d/5e fidelity limits: `D:\workspace\engineering\vsg-project\docs\notes\simulation_validation_2026-10-13.md`.
