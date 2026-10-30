# VSG design-point reconciliation — resolved baseline

Revision 2026-10-20. Supersedes the 2026-05-30 open-choice memo. The current design is 40 V DC, not an outstanding 24/48 V choice. Hardware qualification remains open.

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

## Historical decisions versus current instructions

- Stage 5a's historical 24 V case overmodulated a 14 V peak phase reference; the historical 48 V correction gave m = 0.5833. Preserve those results under their original conditions.
- The current 40 V nominal bus gives m = 14/(40/2) = 0.70. This nominal ratio does not prove instantaneous inverter references remain unsaturated under load or transients.
- Earlier 24 V line-to-line scaling tables (Lf 1.47 mH, Cf 27.63 uF) are superseded. Do not mix them with the present 14 V peak phase target.
- Option A now means the primary discrete IRF540N + IR2104 stage; Option B means the unqualified DRV8302 alternative. Neither label changes the 40 V control baseline.

## Correct analysis bases

At Sbase = 100 VA and fbase = 50 Hz:

- Vbase_LL = sqrt(3/2)*14 = 17.1464 V RMS.
- Ibase = Sbase/(sqrt(3)*Vbase_LL) = 3.3672 A RMS.
- Zbase = Vbase_LL^2/Sbase = 2.94 ohm.
- Lbase = Zbase/(2*pi*50) = 9.3583 mH.
- Cbase = 1/(2*pi*50*Zbase) = 1082.69 uF.
- Lf_pu = 0.1282; Cf_pu = 0.009236.

The implemented damping term is D*(omega-omega_s) with rad/s frequency deviation and per-unit power. Effective static P-f slope is 1/(1/Rp+D*omega_s) = 1/(20+0.5*2*pi*50) = 0.005647 pu/pu, approximately 0.565%. Rp = 0.05 is the governor parameter; the combined slope is not 5%. Equal per-unit equations alone do not establish equal switching losses, thermal limits, protection, or full-system dynamics at larger scale.

## Remaining qualification work

BESS remains in scope; chemistry, cell count, BMS, charger, bidirectional interface and permitted operating-voltage range are unresolved. A 24 V battery must not be directly paralleled with a 40 V source; a nominal 36/48 V string is not a regulated 40 V source. A source-only bench supply needs an independently qualified energy sink before regeneration/load rejection.

Use a separate regulated auxiliary supply initially. Generic LM2596 modules are not approved for direct connection to the nominal 40 V bus; the IC's recommended input ceiling leaves no upward margin. Select any bus-fed replacement only after checking the complete module and transient ratings.

Preserve Stage 5c/5d provenance and per-signal timestamps. Stage 5d is the discrete controller model, not active damping. Stage 5e robustness work must state whether it is averaged/reduced or switching and list executed cases. No HIL or bench completion follows from these simulations. Historical Word drafts and prices remain historical, with new review copies tracked separately.

Simulation validation results and Stage 5d/5e fidelity limits: `D:\workspace\engineering\vsg-project\docs\notes\simulation_validation_2026-10-13.md`.
