# VSG implementation and verification — 2026-10-20

Runner/model: Codex desktop / GPT-6, with engineering and documentation subagents. Work began on 2026-10-12 and resumed after interruptions. Repository base: `22a68c9`. Changes are local and uncommitted.

## Completed software and documentation work

- Fixed ESP32 PWM resume after force-low, single-owner startup/fault transitions, fresh ADC conversion handshake, carrier synchronization and release-to-finish deadline checks. FAULT remains latched; real-power builds require four hardware-readiness acknowledgements.
- Added native regression tests for the actual shared firmware policies and a compile-only matrix covering both power-stage selections, readiness locks and invalid selections.
- Corrected Stage 5d multirate exports: every signal carries its own timestamps. Comparisons use continuous dq observations with identical resampling/filtering, explicit screening thresholds and source provenance.
- Added Stage 5e, a six-case averaged dq study covering startup, load step/rejection, overload, source limiting and approximate nonidealities. Its controller helper mirrors selected firmware equations and checks firmware constants. It is not compiled firmware, HIL, switching-loss, THD or physical protection validation.
- Reconciled the design baseline and eight thesis/design documents. Corrected effective droop, per-unit bases, IR2104 shutdown guidance, auxiliary-supply limits and unresolved BESS assumptions. Historical Chapter 4 results remain labelled historical.
- Regenerated the functional power-stage diagram, a Stage 5e results plot and separate Chapters 3–5 Word review copies. Original advisor DOCX files and original baseline simulation outputs were preserved.

## Verified results

| Check | Evidence and result |
|---|---|
| Native firmware policies | MSVC `/W4 /WX`; startup/fault injection, timer wrap, ADC freshness, deadline and PWM error-path checks passed |
| ESP32 compile matrix | 10/10 expected outcomes: four warning-free A/B dry/real builds, five expected readiness refusals and one expected invalid-stage refusal |
| MATLAB validation unit checks | 11/11 passed in licensed R2018b |
| Stage 5d | Three explicit regression gates passed; 18 exported signal clocks/dimensions checked; source/model/result hashes match current files |
| Stage 5e final rerun | Six/six expectation checks passed on 2026-10-20; all recorded source hashes match, including final firmware |
| Thesis review exports | Native Word PDF rendering and visual layout review; exact source/output hashes and page counts recorded in the export manifest |
| Repository formatting | `git diff --check` passed after removing a trailing blank line |

Stage 5d's final frequency is 49.898122 Hz versus 49.895911 Hz for Stage 5c. Its final current envelope is 0.037402 A peak-to-peak versus 0.005193 A. This passes the documented 0.15 A screening threshold; it does **not** pass a strict 3x ratio and is not raw PWM ripple or THD.

Stage 5e expectations deliberately distinguish expected failure from acceptable regulation:

| Case | Minimum DC bus | Peak dq current | Outcome |
|---|---:|---:|---|
| Nominal | 39.239 V | 4.708 A | Settled regulation screen passed |
| Load step | 33.569 V | 6.652 A | Recovers; transient sag flagged |
| Load rejection | 39.239 V | 4.708 A | Settled regulation screen passed |
| Overload | 39.227 V | 10.001 A | Expected sampled thermal fault at 3.5908 s |
| Source limit, 2.7 A | 16.781 V | 5.945 A | Unacceptable regulation; no protection trip |
| Combined nonideal approximation | 34.415 V | 7.161 A | Recovers; transient sag flagged |

The finite source, DC capacitance, impedance and nonidealities are study assumptions. A passing expectation check must not be presented as successful operation in all six conditions.

## Physical work remains

The saved firmware still defaults to `DRY_RUN_NO_POWER_STAGE=1`; all four readiness flags remain zero. No board was flashed or energized.

1. Identify the actual board/ADC modules and qualify ADC reset/straps, voltage scaling, signal mapping and BUSY/SPI waveforms.
2. Implement and test independent latched driver shutdown, power-on default-off and deliberate manual re-arm. Validate fault dominance while the CPU is halted.
3. Specify and qualify DC-bus UV/OV sensing, source-current limiting and returned-energy handling. Firmware still normalizes duty using nominal 40 V and has no measured DC-bus trip. Do not invent ADC pins or thresholds from the study assumptions.
4. Measure PWM frequency/alignment, bootstrap behavior, worst-case execution timing, gate waveforms and device/inductor/thermal stress.
5. Progress through the documented low-energy bench procedure and retain raw measurements before making prototype/HIL claims.

This is the boundary of the current verified result: software, simulation evidence and documentation are updated; physical qualification needs the actual hardware and measurements.

## Files to use

- Design baseline: `D:\workspace\engineering\vsg-project\docs\notes\design_baseline.md`
- Firmware report: `D:\workspace\engineering\vsg-project\docs\notes\firmware_validation_2026-10-13.md`
- Simulation report: `D:\workspace\engineering\vsg-project\docs\notes\simulation_validation_2026-10-13.md`
- Physical acceptance plan: `D:\workspace\engineering\vsg-project\docs\notes\hardware_shutdown_and_bench_plan.md`
- Word copies and export manifest: `D:\workspace\engineering\vsg-project\docs\thesis\review_2026-10-20`
- Final Stage 5e evidence: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5e\validation_stage5e.json`
- Final Stage 5e log: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5e_final_2026-10-20.log`
- Combined unit/Stage 5d log: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\final_validation.log`
- Integration file inventory: `D:\workspace\engineering\vsg-project\docs\notes\implementation_files_2026-10-20.json`

Generated simulation outputs are excluded from Git because of their size; they remain available locally. Existing manual-learning files were preserved and are not attributed to this change set.

## Reproduction

```powershell
python "D:\workspace\engineering\vsg-project\hardware\esp32\tests\run_policy_tests.py"
python "D:\workspace\engineering\vsg-project\hardware\esp32\tests\compile_matrix.py"
```

In licensed MATLAB R2018b:

```matlab
addpath('D:\workspace\engineering\vsg-project\matlab');
test_vsg_validation;
phase5d_discrete;
phase5e_robustness;
```

The compile matrix only builds temporary copies; its real-branch acknowledgements do not qualify hardware. Core 2.0.17 is pinned because the sketch uses the legacy ESP32 API.

## Execution notes

Preferred Gemini bulk delegation failed on quota before editing; documentation work used the available Codex worker. Later agent quota interruptions did not invalidate the saved completed reports and final simulation artifacts, which the parent checked directly. The packaged DOCX renderer lacked its LibreOffice dependency, so installed Microsoft Word rendered the review copies through a separate hidden COM instance. Native policy and MATLAB checks do not replace hardware testing.
