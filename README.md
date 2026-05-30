# Virtual Synchronous Generator (VSG) for Inverter Control

A grid-forming Virtual Synchronous Generator that emulates the inertia and damping of a
synchronous machine using a 3-phase voltage-source inverter. The project goes from
**MATLAB/Simulink simulation → verified control design → ESP32 hardware prototype**.

> **Author:** Chinnawat Dumklang (Napoleon) — Suranaree University of Technology (SUT), EE
> **Mode:** Pure islanded / grid-forming (no PLL) · **Rating:** 100 W · **Bus:** 40 V

## Status

| Part | State |
|---|---|
| Simulation (Stage 1–5c) | ✅ **Complete & analytically verified** (<10% error every stage) |
| H–D sensitivity sweep (30 cases) | ✅ Done → operating point **H = 5, D = 0.5** |
| Thesis Ch.2 (Lit. review) / Ch.3 (Method) / Ch.4 (Results) / Ch.5 (Hardware) | ✅ Drafted |
| ESP32 firmware | ✅ Drafted (`vsg_controller.ino`) — not yet compiled/bench-tested |
| Hardware build | ⏳ Design locked, awaiting parts (budget 7,200 THB) |
| Ch.6 (real-vs-sim results) | ⬜ After bench bring-up |

## Locked design point — "Option A" (sim-faithful)

| Param | Value | | Param | Value |
|---|---|---|---|---|
| DC bus `Vdc` | 40 V | | Inertia `H` | 5 s |
| AC setpoint `V_set` | 14 V peak/phase (m = 0.70) | | Damping `D` | 0.5 |
| Power `P` | 100 W (3-phase) | | Droop `R_p`/`R_q` | 0.05 / 0.05 |
| Filter `L_f`/`C_f`/`R_d` | 1.2 mH / 10 µF / 1 Ω | | Switching | 10 kHz SPWM |

Swing law (CSV-verified): `(2H/ω_s)·dω/dt = [P_set + (1−ω/ω_s)/R_p] − P_e − D·(ω−ω_s)`
→ at H=5, D=0.5: `f_ss = 49.898 Hz` (sim 49.896 Hz).

## Simulation highlights

Bottom-up build, each stage predicted then simulated:
`Stage 1` swing eq → `2` power-angle → `3` droop → `4` dq inverter + cascaded V-I PI →
`5a` 3-phase SPWM switching → `5b` **H–D sweep** → `5c` tuned (R_d damping + dq decoupling FF).
See `docs/thesis/chapter4_simulation_results.md` and `python/plots/`.

## Hardware — two documented power-stage options

Both share the same ESP32 control core, firmware, filter, AD7606 sensing and 40 V bus —
selectable in firmware via `#define POWER_STAGE`. Full comparison + wiring diagrams:
`docs/notes/power_stage_options.md`, `python/plots/power_stage_{A,B}_wiring.png`.

| | **A — discrete IRF540N + IR2104** (default) | **B — TI DRV8302 shield** |
|---|---|---|
| Cost | ~540 THB | ~1,000–1,500 THB |
| Blow-up recovery | ~20 THB / MOSFET | whole board |
| Protection | LM393 OCP + IR2104 dead-time (~520 ns) | integrated (OCP/UVLO/dead-time) |
| Best for | tight budget, self-funded repairs | speed, lower risk |

## Repository structure

```
vsg-project/
├── matlab/                 # programmatic Simulink builders (Stage 1–5c) + scripts/
├── python/
│   ├── analysis/           # plot_phase*.py, power_stage_{A,B}_wiring.py
│   └── plots/              # generated figures (git-tracked)
├── hardware/esp32/vsg_controller/vsg_controller.ino   # ESP32 firmware
└── docs/
    ├── thesis/             # chapter2..5 (.md + .docx)
    └── notes/              # design decisions, power_stage_options, reconciliation memo
```

## Getting started

**Python plots / analysis**
```bash
cd python
python -m venv .venv && .venv/Scripts/pip install -r requirements.txt
.venv/Scripts/python analysis/plot_phase5b_hd_sweep.py
```

**MATLAB (R2018b+)** — run the stage builders in `matlab/` (each builds its `.slx`,
simulates, and exports a `.mat` for the Python plotters).

**Firmware** — open `hardware/esp32/vsg_controller/vsg_controller.ino` in Arduino IDE
(ESP32 core v2.x; uses legacy `driver/mcpwm.h`). Set `POWER_STAGE` to A or B, verify
pin map against your wiring, then flash. **Always bench-test with the DC supply
current-limited (~3–4 A).**

## Key reference
Power System Analysis — Hadi Saadat. VSG emulates the swing equation
`J·dω/dt = Tm − Te − D·(ω − ω0)`.
