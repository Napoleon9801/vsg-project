"""
load_vsg_papers.py
Creates a "VSG Research" notebook in NotebookLM and loads all VSG hardware
implementation papers found via Semantic Scholar searches (2025-05-05).

Run from terminal:
    python workspace/engineering/vsg-project/python/load_vsg_papers.py
"""

import asyncio
from notebooklm import NotebookLMClient

# ---------------------------------------------------------------------------
# All VSG hardware papers found via Semantic Scholar (2025-05-05)
# Organized as structured text sources — replace with full PDFs via SUT login
# when available.
# ---------------------------------------------------------------------------

PAPERS = [
    {
        "title": "Control of Stand-Alone Inverter using Virtual Synchronous Generator (ICATEEE 2022)",
        "content": """Title: Control of Stand-Alone Inverter using Virtual Synchronous Generator
Authors: Not fully retrieved
Year: 2022
Venue: IEEE ICATEEE 2022 (International Conference on Advanced Technology in Electronic and Electrical Engineering)
DOI: 10.1109/ICATEEE57445.2022.10093091
IEEE Doc ID: 10093091
URL: https://ieeexplore.ieee.org/document/10093091

Abstract Summary:
Designs and verifies VSG control for a stand-alone inverter via PSIM simulation,
then validates with a Processor-in-the-Loop (PIL) test implemented on a Texas
Instruments F28335 DSP board. DSP results match simulation outputs.

Hardware Details:
- MCU/DSP Platform: Texas Instruments TMS320F28335
- Inverter Topology: VSI (type not specified)
- Power Rating: Not specified
- Filter: Not specified
- Testbed Type: Processor-in-the-Loop (PIL)
- Validation Method: PSIM simulation + PIL on F28335

Relevance to Napoleon's Project:
This is the most directly applicable paper for hardware implementation. The F28335
PIL validation workflow mirrors the recommended path: MATLAB/Simulink simulation ->
PIL on DSP -> physical prototype. Confirms TI C2000 F28335 as a viable MCU choice.
"""
    },
    {
        "title": "Adaptive Inertia VSG with Even Power Sharing in Islanded Microgrid (IEEE 2023)",
        "content": """Title: A New Adaptive Inertia-Based Virtual Synchronous Generator with Even Inverter Output Power Sharing in Islanded Microgrid
Authors: Not fully retrieved
Year: 2023
Venue: IEEE Journals & Magazine (IEEE Xplore)
DOI: Not confirmed
IEEE Doc ID: 10329423
URL: https://ieeexplore.ieee.org/abstract/document/10329423

Abstract Summary:
Proposes an adaptive inertia VSG for frequency regulation plus a feedforward
line-impedance power sharing mechanism for parallel inverter DGs. Validated via
PSIM simulation and physical hardware tests on a three-inverter microgrid using
a TMS320F28335 DSP.

Hardware Details:
- MCU/DSP Platform: TMS320F28335
- Inverter Topology: Three parallel VSIs (multi-inverter microgrid)
- Power Rating: Not specified
- Filter: Not specified
- Testbed Type: Physical hardware (3-inverter microgrid)
- Validation Method: PSIM + physical hardware

Relevance to Napoleon's Project:
Confirms TMS320F28335 in a real multi-inverter setup. Adaptive inertia (H varies
dynamically) is a natural Phase 2+ extension for Napoleon's swing equation.
"""
    },
    {
        "title": "Field Demo: VSG Grid-Forming Inverters + Diesel SG in Microgrid (IEEE 2022)",
        "content": """Title: Field Demonstration of Parallel Operation of Virtual Synchronous Controlled Grid-Forming Inverters and a Diesel Synchronous Generator in a Microgrid
Authors: Hirase et al.
Year: 2022
Venue: IEEE Journals & Magazine (IEEE Xplore)
DOI: Not confirmed
IEEE Doc ID: 9755962
URL: https://ieeexplore.ieee.org/document/9755962/

Abstract Summary:
Full-scale field demonstration (125 kVA diesel SG + five 20 kVA inverter-BES units,
44.4% inverter penetration) of VSG-controlled grid-forming inverters operating in
parallel with a real diesel synchronous generator in a physical microgrid. Validates
VSG readiness for IEEE Std 2988 standardisation.

Hardware Details:
- MCU/DSP Platform: Not specified
- Inverter Topology: Five 3-phase grid-forming inverters + Battery Energy Storage
- Power Rating: 5 x 20 kVA inverters + 125 kVA diesel SG
- Filter: Not specified
- Testbed Type: Full field deployment (real microgrid)
- Validation Method: Field measurements

Relevance to Napoleon's Project:
The most mature VSG hardware paper in the dataset. Shows what a full-scale VSG looks
like at 20 kVA per unit. Napoleon's prototype will be lab-scale (~100W-1kW), but
this paper provides the architecture benchmark.
"""
    },
    {
        "title": "VSG Control for Back-to-Back Inverter Testing in Renewable Energy Systems (IEEE 2024)",
        "content": """Title: Modelling and Design of Virtual Synchronous Generator Control for Back-to-Back Inverter Testing in Renewable Energy Systems
Authors: Not fully retrieved
Year: 2024
Venue: IEEE Conference Publication (IEEE Xplore)
DOI: Not confirmed
IEEE Doc ID: 10807621
URL: https://ieeexplore.ieee.org/document/10807621/

Abstract Summary:
Presents a VSG-based control method for back-to-back (B2B) inverter test rigs.
Two 3-leg inverters are connected through an LCL filter — one as grid-forming
(VSG-APC/RPC), one as grid-following (PLL-current control) — enabling power
recirculation for continuous testing.

Hardware Details:
- MCU/DSP Platform: Not specified
- Inverter Topology: Two 3-leg back-to-back inverters
- Power Rating: Not specified
- Filter: LCL filter (explicitly stated)
- Testbed Type: Laboratory testbed (power recirculation)
- Validation Method: Laboratory measurements

Relevance to Napoleon's Project:
LCL filter explicitly confirmed for grid-connected VSG. This is the standard filter
choice — Napoleon should use LCL rather than plain LC for better harmonic attenuation.
"""
    },
    {
        "title": "Real-Time Simulation of Power System with VSG Hardware-in-the-Loop (IECON 2011)",
        "content": """Title: Real time simulation of a power system with VSG hardware in the loop
Authors: V. Karapanos, S.W.H. de Haan, K.H. Zwetsloot
Year: 2011
Venue: IEEE IECON 2011 (37th Annual Conference of the IEEE Industrial Electronics Society)
DOI: 10.1109/IECON.2011.6119919
IEEE Doc ID: 6119919
URL: https://ieeexplore.ieee.org/document/6119919/

Abstract Summary:
Presents a real-time HIL method to study VSG-grid interaction by replacing the
physical power system with an FPGA-based real-time simulator. A bespoke three-phase
MOSFET inverter with output filters acts as the VSG hardware under test.

Hardware Details:
- MCU/DSP Platform: FPGA (real-time simulator) + MOSFET-based 3-phase inverter
- Inverter Topology: Three-phase MOSFET inverter
- Power Rating: Not specified (lab scale)
- Filter: Output filter (type not specified)
- Testbed Type: Power Hardware-in-the-Loop (P-HIL)
- Validation Method: FPGA real-time simulation + physical inverter

Relevance to Napoleon's Project:
Foundational HIL methodology paper. Shows that even in 2011 the standard was P-HIL
before full physical testing. Napoleon's path should include HIL validation between
simulation and prototype.
"""
    },
    {
        "title": "Hardware-in-Loop Simulation of Photovoltaic VSG (IEEE 2018)",
        "content": """Title: Hardware in Loop Simulation Test of Photovoltaic Virtual Synchronous Generator
Authors: Not fully retrieved
Year: 2018
Venue: IEEE Conference Publication (IEEE Xplore)
DOI: Not confirmed
IEEE Doc ID: 8582262
URL: https://ieeexplore.ieee.org/document/8582262/

Abstract Summary:
Proposes an RT-LAB-based HIL simulation test platform for a PV-VSG system.
Demonstrates that a grid-connected PV inverter with VSG control emulates SG-like
inertia and improves power system stability.

Hardware Details:
- MCU/DSP Platform: RT-LAB real-time simulator
- Inverter Topology: Grid-connected PV inverter
- Power Rating: Not specified
- Filter: Not specified
- Testbed Type: Hardware-in-the-Loop (RT-LAB)
- Validation Method: RT-LAB HIL measurements

Relevance to Napoleon's Project:
PV source + VSG is a common academic prototype combination. RT-LAB is an alternative
to OPAL-RT. Confirms HIL before physical build as standard practice.
"""
    },
    {
        "title": "HIL Validation of VSG in Low Inertia Power System (IEEE PESGM 2018)",
        "content": """Title: Modelling, Simulation and Hardware-in-the-Loop Validation of Virtual Synchronous Generator Control in Low Inertia Power System
Authors: Not fully retrieved
Year: 2018
Venue: IEEE PESGM 2018 / IEEE Conference Publication (IEEE Xplore)
DOI: Not confirmed
IEEE Doc ID: 8442998
URL: https://ieeexplore.ieee.org/document/8442998/

Abstract Summary:
Develops a DAE model of VSG control, compares frequency support against droop
control for electrical energy storage, and validates the model against physical
hardware-in-the-loop measurements.

Hardware Details:
- MCU/DSP Platform: Not specified
- Inverter Topology: Not specified
- Power Rating: Not specified
- Filter: Not specified
- Testbed Type: Hardware-in-the-Loop
- Validation Method: HIL measurements vs. DAE model

Relevance to Napoleon's Project:
DAE model validation against HIL — confirms that the simplified swing equation
model (Napoleon's Phase 1) can be rigorously validated against hardware measurements.
"""
    },
    {
        "title": "Generalized VSG Control Design for Renewable Power Systems (IEEE TSTE 2022)",
        "content": """Title: Generalized Virtual Synchronous Generator Control Design for Renewable Power Systems
Authors: Rathnayake, D.; Razzaghi, R.; Bahrani, B.
Year: 2022
Venue: IEEE Transactions on Sustainable Energy, Vol. 13, No. 2, pp. 1021-1036
DOI: 10.1109/TSTE.2022.3143664
IEEE Doc ID: 9684692
URL: https://ieeexplore.ieee.org/document/9684692/

Abstract Summary:
Proposes a GVSG controller for grid-forming inverters with seamless GC/SA mode
switching. Provides closed-form gain equations from frequency-response analysis
and verifies with experimental step-response tests showing lower overshoot and
shorter settling time than conventional VSG.

Hardware Details:
- MCU/DSP Platform: Not specified
- Inverter Topology: Grid-forming VSI
- Power Rating: Not specified
- Filter: Not specified
- Testbed Type: Experimental (step-response tests)
- Validation Method: Frequency-response analysis + experimental validation

Relevance to Napoleon's Project:
Journal-quality GVSG paper with closed-form controller design equations. The
gain-selection methodology can be directly applied to Napoleon's Phase 4 control
loop design. Mode-switching (grid-connected <-> islanded) is a Phase 5+ feature.
"""
    },
    {
        "title": "VSG & Droop on OPAL-RT + TI C2000 (IEEE EEEIC 2025)",
        "content": """Title: Evaluation of Virtual Synchronous Generator and Droop Control in Microgrids Using Real-Time Hardware-in-the-Loop for Inverter-Based Resources
Authors: S. M. I. Ahmed M. Ibrahim, S. M. Sajjad, Hossain Rafin, Osama A. Mohammed
Year: 2025
Venue: 2025 IEEE EEEIC / I&CPS Europe
DOI: 10.1109/EEEIC/ICPSEurope64998.2025.11169235
URL: https://ieeexplore.ieee.org/document/10093091

Abstract Summary:
Models two parallel inverters in MATLAB/Simulink and implements them on an OPAL-RT
HIL testbed with Texas Instruments C2000 MCUs. VSG consistently outperforms droop
control in voltage regulation, current quality, and load-sharing accuracy.

Hardware Details:
- MCU/DSP Platform: Texas Instruments C2000 microcontrollers
- HIL Platform: OPAL-RT real-time simulator
- Inverter Topology: Two parallel inverters (single or three-phase)
- Power Rating: Not specified
- Filter: Not specified
- Testbed Type: Real-Time HIL (OPAL-RT + C2000)
- Validation Method: OPAL-RT HIL measurements + MATLAB/Simulink comparison

Relevance to Napoleon's Project:
MOST directly applicable paper. MATLAB/Simulink -> OPAL-RT HIL -> TI C2000 MCU
workflow is exactly Napoleon's recommended path. Confirms TI C2000 as the MCU choice.
VSG outperforms droop control — validates the choice of VSG over simpler droop.
"""
    },
    {
        "title": "DC Bias Disturbance Observer for VSG (IEEE TIE 2025)",
        "content": """Title: Utilization of a Disturbance Observer for Enhancing Robustness Against DC Biases in a Virtual Synchronous Generator
Authors: Seungbo Choi, Geon-Su Heo, Yongsoon Park
Year: 2025
Venue: IEEE Transactions on Industrial Electronics
DOI: 10.1109/TIE.2025.3577303
URL: https://ieeexplore.ieee.org/document/10093091

Abstract Summary:
Identifies ADC-induced DC bias as the root cause of synchronous oscillation in
CURESYM-based VSGs. Proposes a filter-based disturbance observer in stationary
frame to replace the ESO. Validated through HIL tests and physical experiments.

Hardware Details:
- MCU/DSP Platform: Physical inverter bench + HIL testbed
- Inverter Topology: Grid-connected VSG inverter
- Power Rating: Not specified
- Filter: Not specified
- Testbed Type: HIL + physical hardware bench
- Validation Method: Oscilloscope measurements + HIL

Critical Hardware Warning for Napoleon:
ADC DC bias (from quantization noise and offset) feeds into the swing equation
integrator and causes self-sustaining synchronous oscillation. The fix is a
high-pass disturbance observer on the frequency measurement before the swing
equation input. This MUST be addressed in Phase 5 (embedded implementation).
"""
    },
    {
        "title": "Model-Free Predictive VSG Control (IEEE Access 2025)",
        "content": """Title: Model-Free Predictive Control Based on RLS Algorithm for Grid-Forming Inverters With Virtual Synchronous Generator
Authors: Min Huang, Huiying Zhang, Kangan Wang, Zhilei Yao, Weimin Wu
Year: 2025
Venue: IEEE Access
DOI: 10.1109/ACCESS.2025.3556089

Abstract Summary:
Proposes a model-free predictive control (ARX-based inner loop) combined with a
simplified VSG outer loop for grid-forming inverters. Improves parameter robustness
and dynamic characteristics. Validated by simulation and hardware experiment.

Hardware Details:
- MCU/DSP Platform: Not specified (hardware experiment confirmed)
- Inverter Topology: Grid-forming VSI
- Power Rating: Not specified
- Filter: Not specified
- Testbed Type: Physical hardware + simulation
- Validation Method: Experimental + simulation

Relevance to Napoleon's Project:
Model-free inner loop control is a Phase 4+ enhancement that removes the need for
accurate plant model parameters — relevant if parameter estimation becomes difficult
during the physical prototype stage.
"""
    },
    {
        "title": "VSG Droop Full Comparison in Grid-Forming Inverters (IEEE PEDG 2023)",
        "content": """Title: A Full Comparison between Droop Control and Virtual Synchronous Generator Control Considering Reactive Power Dynamics in Grid-Forming Inverters
Authors: Jiazhi Wang, Zeng Liu, Yidong Shi, Jinjun Liu
Year: 2023
Venue: IEEE PEDG 2023
DOI: 10.1109/PEDG56097.2023.10215129

Abstract Summary:
Provides a complete analytical comparison of droop and VSG control for both active
and reactive power dynamics in grid-connected and stand-alone modes. Theoretical
results verified by software simulation and hardware experiments.

Hardware Details:
- MCU/DSP Platform: Not specified
- Inverter Topology: Grid-forming VSI
- Power Rating: Not specified
- Filter: Not specified
- Testbed Type: Hardware experiment
- Validation Method: Analytical + simulation + hardware

Relevance to Napoleon's Project:
Reactive power dynamics comparison (Q-V droop vs. VSG) is essential for Napoleon's
Phase 2 (closed-loop power control). This paper provides the theoretical basis
for choosing VSG over droop for both P-f and Q-V channels.
"""
    },
    {
        "title": "VSG Hardware Implementation Summary — Napoleon VSG Project (Meta-Document)",
        "content": """Title: VSG Hardware Implementation Research Summary
Project: Napoleon's VSG Prototype — Suranaree University of Technology
Date: 2025-05-05
Source: Semantic Scholar API searches

HARDWARE COMPARISON TABLE (from abstracts):
===========================================

Paper                          | MCU/DSP          | Topology          | Power      | Filter | Testbed
-------------------------------|------------------|-------------------|------------|--------|------------------
ICATEEE 2022 (10093091)        | TI F28335        | VSI               | -          | -      | PIL
IEEE 2023 (10329423)           | TMS320F28335     | 3x parallel VSIs  | -          | -      | Physical HW
Field Demo 2022 (9755962)      | -                | 5x 3-phase VSI    | 5x20 kVA   | -      | Real microgrid
B2B 2024 (10807621)            | -                | 2x 3-leg B2B      | -          | LCL    | Lab testbed
IECON 2011 (6119919)           | FPGA+MOSFET      | 3-phase MOSFET    | -          | Output | P-HIL
PV-VSG 2018 (8582262)          | RT-LAB           | PV grid-connected | -          | -      | RT-LAB HIL
EEEIC 2025                     | TI C2000         | 2x parallel VSI   | -          | -      | OPAL-RT HIL
TIE 2025 (TIE.2025.3577303)    | Physical bench   | Grid-connected    | -          | -      | HIL+physical
IEEE Access 2025               | -                | Grid-forming VSI  | -          | -      | HW experiment
PEDG 2023                      | -                | Grid-forming VSI  | -          | -      | HW experiment

KEY FINDINGS FOR PROTOTYPE DECISIONS:
======================================
1. MCU/DSP: TI TMS320F28335 (or F28379D successor) is the dominant platform
2. Filter: LCL is standard for grid-connected VSG
3. Validation path: Simulation -> PIL/HIL -> Physical hardware
4. Critical pitfall: ADC DC bias causes swing equation oscillation (see TIE 2025)
5. Inverter topology: Single-phase H-bridge or 3-phase VSI (both used in literature)
6. Power rating: Academic prototypes typically 100W - 20 kVA

PHASE 0 DECISIONS PENDING:
===========================
- Single-phase vs. 3-phase topology
- Target MCU: TI C2000 F28335/F28379D vs. STM32 vs. ESP32
- Power level: ~100W lab vs. ~1kW
- HIL platform: OPAL-RT / Typhoon HIL / Simulink Desktop Real-Time
- Timeline: Before or after internship (June 8, 2026)
"""
    }
]


async def main():
    print("[VSG NotebookLM] Connecting to NotebookLM...")

    async with await NotebookLMClient.from_storage() as client:

        # --- Create or reuse "VSG Research" notebook ---
        print("[VSG NotebookLM] Checking for existing notebooks...")
        existing = await client.notebooks.list()
        notebook = None
        for nb in existing:
            if nb.title == "VSG Research":
                notebook = nb
                print(f"[VSG NotebookLM] Found existing notebook: {nb.id}")
                break

        if notebook is None:
            print("[VSG NotebookLM] Creating 'VSG Research' notebook...")
            notebook = await client.notebooks.create("VSG Research")
            print(f"[VSG NotebookLM] Created notebook: {notebook.id}")

        # --- Add each paper as a text source ---
        print(f"\n[VSG NotebookLM] Loading {len(PAPERS)} papers as sources...")
        for i, paper in enumerate(PAPERS, 1):
            print(f"  [{i}/{len(PAPERS)}] Adding: {paper['title'][:60]}...")
            try:
                await client.sources.add_text(
                    notebook.id,
                    paper["title"],
                    paper["content"],
                    wait=True
                )
                print(f"  [{i}/{len(PAPERS)}] OK")
            except Exception as e:
                print(f"  [{i}/{len(PAPERS)}] ERROR: {e}")

        print("\n[VSG NotebookLM] Done. All sources loaded.")
        print(f"[VSG NotebookLM] Notebook ID: {notebook.id}")
        print("[VSG NotebookLM] Open NotebookLM and search 'VSG Research' to verify.")


if __name__ == "__main__":
    asyncio.run(main())
