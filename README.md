# Virtual Synchronous Generator (VSG) — Napoleon

## Overview
A Virtual Synchronous Generator (VSG) emulates the inertia and damping behaviour of a
synchronous machine using a power converter. This project develops a VSG model from
simulation to physical prototype.

**Status**: Early-stage — MATLAB/Simulink simulation phase  
**End goal**: Physical prototype (ESP32-based control)

## Repository Structure
```
vsg-project/
├── matlab/
│   ├── models/      # Simulink .slx models
│   ├── scripts/     # MATLAB .m analysis scripts
│   └── data/        # Simulation output (git-ignored)
├── python/
│   ├── analysis/    # Post-processing scripts
│   ├── plots/       # Generated figures (git-ignored)
│   └── requirements.txt
├── hardware/
│   ├── esp32/       # ESP32 firmware (Arduino IDE)
│   └── arduino/     # Arduino sketches
└── docs/
    ├── references/  # PDFs / papers (git-ignored, store in NotebookLM)
    └── notes/       # Design decisions, derivations
```

## Key References
- Power System Analysis — Hadi Saadat (`C:\Users\User\`)
- VSG theory: emulates swing equation `J·dω/dt = Tm - Te - D·(ω - ω0)`

## Simulation Phases
- [ ] Phase 1: VSG swing equation model in Simulink
- [ ] Phase 2: Active/reactive power control loop
- [ ] Phase 3: Grid-connected inverter model
- [ ] Phase 4: ESP32 firmware for real-time control
- [ ] Phase 5: Physical prototype and bench testing

## Python Environment Setup
```bash
cd python
pip install -r requirements.txt
```
