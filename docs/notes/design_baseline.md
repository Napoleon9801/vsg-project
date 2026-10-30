# VSG implementation baseline — 2026-10-13

This is the authoritative current design index. Historical experiments at 24/48 V remain historical; they are not construction instructions. Source code and measured results take precedence over unverified design claims. Status is simulation development plus firmware compilation/host validation; hardware qualification remains pending.

| Quantity | Current baseline |
|---|---|
| Mode | Three-phase islanded grid-forming, no utility-grid connection |
| DC bus | 40 V nominal; finite-source behavior requires separate validation |
| AC voltage target | 14 V peak phase; 9.8995 V RMS phase; 17.1464 V RMS line-to-line |
| Power | 100 W nominal three-phase; 100 VA analysis base, not a proven thermal rating |
| Frequency | 50 Hz |
| Filter per phase | Lf 1.2 mH, Rf 0.05 ohm, Cf 10 uF with Rd 1 ohm in series |
| Controller | ESP32, Arduino-ESP32 2.0.17 legacy APIs; do not silently upgrade to 3.x |
| Control/PWM target | 10 kHz; scope verification and deadline evidence required |
| Power stage A | IRF540N + IR2104, non-isolated bootstrap; external independent shutdown required |
| Power stage B | DRV8302 alternative; exact module and ratings must be verified |
| ADC/current sensing | AD7606 + ACS712-20A; actual module straps, reset and calibration required |
| H, D, Rp, Rq | 5 s, 0.5, 0.05, 0.05 |

The amplitude-invariant dq power relation is P = 1.5*(vd*id + vq*iq). The implemented D multiplies frequency deviation in rad/s, while power is per-unit. Therefore the effective static slope is 1/(1/Rp + D*omega_s) = 0.005647 pu/pu, approximately 0.565%; Rp is the governor's 5% parameter, not the combined steady-state slope. Equal per-unit outer-loop equations do not prove complete thermal, switching or hardware equivalence to a larger converter.

For a 100 VA base at 17.1464 V line-to-line: Ibase = 3.3672 A RMS, Zbase = 2.94 ohm, Lbase = 9.3583 mH, Cbase = 1082.69 uF at 50 Hz. The selected filter corresponds to approximately 0.1282 pu L and 0.009236 pu C; old 24 V tables do not set this filter. Baseline SPWM m = 0.70 describes the nominal voltage target; instantaneous inverter references and saturation must be checked separately.

## Source and energy architecture

Initial bench tests use an adjustable current-limited DC source and a separately regulated auxiliary supply for gate drivers/sensors/logic, with a documented grounding scheme. Auxiliary supply voltage, current rating, startup sequencing and isolation are to be checked on the actual equipment. Do not connect a generic LM2596 module directly to the nominal 40 V bus: its recommended input ceiling is 40 V, leaving no positive excursion margin ([TI datasheet](https://www.ti.com/lit/ds/symlink/lm2596.pdf)). A bus-fed auxiliary converter requires a verified input/transient rating and reviewed module components.

BESS remains intended project scope, but chemistry, cell count, allowed charge/discharge current, BMS, charger and connection topology are not qualified. Do not directly parallel a 24 V battery with a 40 V supply. Neither a nominal 36 V SLA string nor a nominal 48 V pack is a regulated 40 V source across state of charge. Select a compatible controlled interface or revalidate the entire operating-voltage range. A source-only laboratory supply cannot automatically absorb returned energy. Qualify an energy sink/braking path before load-rejection experiments; a TVS is not a sustained energy sink.

The historical ~136 W post-step simulation is an overload experiment relative to the 100 W nominal target. It is not permission to run the hardware continuously at that power. Qualify load resistors, inductor saturation, switch temperatures and source capacity for the selected test duration.

## Validation boundaries

- Stage 5c: continuous-controller switching baseline.
- Stage 5d: discrete-controller switching model. Preserve per-signal timestamps and distinguish continuous plant ripple from controller-sampled signals.
- Stage 5e: robustness extension; consult its validation report for fidelity, actual executed cases and failures. A reduced/averaged model is not a switching or hardware proof.
- Stages 5f–5g (2026-10-24): hypothetical induction motor, finite source and simulation-only gain sweep. All six motor scenarios and three gain candidates fail the operating screen. Direct-connection integration convergence passes; cold start remains unresolved after 5us/2.5us comparison. Motor-only ideal-source ODE45 and independent equivalent-circuit checks pass. These exploratory results do not change firmware gains, the100W inverter baseline or procurement scope. See `D:\workspace\engineering\vsg-project\docs\notes\motor_simulation_stage5f_2026-10-24.md`.
- Manual learning track: Stages 1–2 recorded passed; Stage 3 next. Existing manual work is preserved.
- Firmware dry-run remains the default. Power operation requires physical checks described in `D:\workspace\engineering\vsg-project\docs\notes\hardware_shutdown_and_bench_plan.md` and the firmware's explicit readiness configuration.
- Bench captures, hardware-in-the-loop results and Chapter 6 measurements are not yet available in this repository. Compilation and simulation do not establish bench safety.

Historical BoM prices are planning estimates from earlier work, not current quotations. Word drafts predating this baseline are historical; use the newly regenerated review copies when provided, and preserve advisor originals.

## Neutral and voltage sensing selection — 2026-10-22

The selected Rev A architecture joins filter and balanced Y-load stars at N_AC with no hard bond to DC negative, logic ground or PE. The sensing network still provides resistive loading, so this is not galvanic isolation. Phase measurements use a non-isolated OPA4197 differential front end with nominal gain 1/4 and +/-12 V auxiliary rails; the fourth amplifier buffers a 1/10 bus divider. Firmware phase scale x4 remains unchanged; ADC V7 bus acquisition is not implemented.

Design values, logical connections, BoM and analytical evidence are in `D:\workspace\engineering\vsg-project\docs\notes\neutral_voltage_sensing_design_rev_a_2026-10-22.md`. This selection does not release physical operation: ADC module compatibility, rail-loss/disconnect timing, contact reliability, alias/loop behavior and PCB checks remain pending. The ideal grounded-neutral simulation does not establish physical common-mode equivalence.

Whole-prototype budget assumptions and allowances are in `D:\workspace\engineering\vsg-project\docs\notes\complete_prototype_budget_2026-10-22.md`; instruments are assumed borrowed and unscoped BESS is excluded.


## Advisor scope flexibility and funding — 2026-10-23

Napoleon confirms that he consulted his advisor and may revise the examined proposal scope. Continue the existing 40 V / 100 W islanded engineering baseline without treating historical 300 W or weak-grid wording as a blocker. This does not establish approval of every detailed circuit or physical readiness. Confirmed grant is THB7,200; a small personal contribution is possible but unspecified. Budget optimization must use qualified parts and verified lab inventory; do not assume the complete inverter fits the grant. Details: `D:\workspace\engineering\vsg-project\docs\notes\proposal_scope_budget_7200_2026-10-23.md`.
