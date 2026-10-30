# VSG hardware design and bench qualification handbook

Revision 2026-10-20. Current reference for the islanded prototype; this document is not a completed inspection or bench certificate. The historical 24 V scaling/connection instructions are superseded.

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

## Electrical bases and limits

For 100 VA and 50 Hz: Ibase = 3.3672 A RMS, Zbase = 2.94 ohm, Lbase = 9.3583 mH and Cbase = 1082.69 uF. Thus Lf = 0.1282 pu and Cf = 0.009236 pu. Filter resonance is approximately 1453 Hz. Power rating remains a design target pending measured thermal qualification.

Per-unit outer-loop equations can preserve selected control dynamics when bases, parameters and disturbances match. They do not prove identical full-system behavior to a 10 kVA/MW converter. The implemented rad/s damping produces an effective P-f slope of 0.005647 pu/pu, not a combined 5% slope.

At 14 V peak phase, a balanced resistive load of 2.94 ohm/phase consumes 100 W ideally. The historical roughly 136 W post-step run is an overload relative to the nominal target. Hardware resistor ratings, inductor saturation/ripple and switch temperatures must be qualified for the actual duration and cooling.

## Energy source and auxiliary supplies

Use an adjustable current-limited DC source with separately regulated auxiliary rails initially. Verify the complete ground/earth scheme before connecting USB or grounded instruments. A generic LM2596 module has no positive input margin on the nominal 40 V bus and is not approved for this connection ([TI datasheet](https://www.ti.com/lit/ds/symlink/lm2596.pdf)).

BESS is intended scope, but battery chemistry, cell count, BMS, charger, operating voltage, current and connection topology are unresolved. Do not directly parallel a 24 V pack with a 40 V source, and do not treat three 12 V SLA batteries as a regulated 40 V source. Qualify a controlled interface or revalidate the entire bus range.

A source-only supply cannot be assumed to absorb energy. Qualify a sink/braking path before load rejection. TVS protection handles bounded transients, not sustained regeneration. Select clamp behavior using worst-case clamp voltage, energy and actual component limits; a TVS part label is not the bus clamp voltage.

Design pre-charge and discharge around actual bus capacitance, resistor pulse energy, DC switch/fuse ratings and measured bus voltage. Verify discharge with a meter before handling; do not assume a fixed 10-second wait establishes zero energy. Fuse/current limiting complements gate shutdown rather than replacing it.

## Power stage and independent shutdown

Primary stage: six IRF540N and three non-isolated IR2104 drivers. IR2104 includes UVLO and internal dead-time. Verify actual switching dead-time, gate drive and bootstrap behavior under the assembled conditions ([Infineon datasheet](https://www.infineon.com/assets/row/public/documents/24/49/infineon-ir2104-ds-en.pdf)).

SD LOW disables both HO and LO; HIGH permits complementary switching. IN LOW alone can keep LO on. Use SD_PERMIT = MCU_REQUEST AND HARDWARE_PERMIT, with external default-LOW bias and a hardware permit latch asynchronously cleared by overcurrent and supply reset. The comparator must clear this latch without CPU assistance. Re-arm must be deliberate after healthy conditions; a held button or vanished fault must not restart switching. Verify the logic interface and supply-loss behavior as specified in the shutdown plan.

GPIO22 provides only MCU_REQUEST; GPIO34 monitors the fault branch and needs its external 3.3 V pull-up where the comparator output is open-collector. Never short the comparator output to a push-pull GPIO. Determine threshold, sensing coverage, blanking and measured total shutdown delay from the actual circuit; no sub-microsecond end-to-end trip is assumed.

DRV8302 is an alternative, not a qualified module. Verify the exact schematic, power components, enable logic, fault behavior, buck and cooling; chip specifications are not module ratings.

## Measurements and construction

AD7606 + ACS712-20A remains the sensor baseline. Qualify module RESET/RANGE/OS/mode/VDRIVE, channel order, signed conversion and conditioning. Measure zero-current offsets and gains. Inject BUSY stuck HIGH and LOW separately with a suitable fixture.

Keep gate and high-current commutation loops short; separate sensitive measurement returns from switching return currents and review the joining/earthing points. Isolate MOSFET drain tabs where a shared heatsink requires it. Verify inductor saturation and loss on the actual part/core rather than approving a core material by name alone. Select capacitors for voltage, ripple current and frequency, not capacitance alone.

Measure HO relative to VS with appropriately rated differential/isolated equipment. An earth-referenced scope ground clip must not be placed on a switching node.

## Staged acceptance

1. Inspect unpowered continuity, polarity, isolation where required, discharge and external default-off behavior.
2. With auxiliary power only, demonstrate both gates off during MCU reset/unpowered state and after independently injected fault; confirm no automatic restart.
3. Capture dry-run 10 kHz PWM alignment, control worst-case execution, missed ticks and ADC calibration. Dry-run gate request remains LOW.
4. Inject faults during standby/bootstrap/soft-start; check latch behavior and software FAULT persistence.
5. After these pass with saved evidence, proceed through documented low-energy current-limited power levels, measuring overshoot, current and temperature at each step.
6. Test load rejection/overload only after qualifying energy absorption and the relevant electrical/thermal envelope.

All physical tests remain PENDING until linked evidence exists. Historical prices dated 2026-05-30 are estimates, not current quotations. Use the shared shutdown document as the detailed acceptance record.

Simulation validation results and Stage 5d/5e fidelity limits: `D:\workspace\engineering\vsg-project\docs\notes\simulation_validation_2026-10-13.md`.
The report identifies a DC-bus protection gap: source-current limiting can cause severe bus sag without an overcurrent/thermal trip. Qualify a DC-bus undervoltage/overvoltage interlock or a separately specified sensing/protection implementation; study assumptions do not establish hardware thresholds or ADC scaling.
