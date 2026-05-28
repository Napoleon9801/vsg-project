# AI / Machine Learning for VSG — Literature Survey 01

**Author:** Napoleon (Chinnawat Dumklang), SUT EE  
**Compiled:** 2026-05-23  
**Scope:** Mapping how AI/ML methods intersect with VSG / grid-forming inverter / BESS control, with a deliberate filter for ESP32-feasible implementations.  
**Status:** Search-string + candidate-shortlist phase. All search strings must be re-run by Napoleon on IEEE Xplore / Semantic Scholar / Scopus. Author/DOI fields flagged `[Authors to be verified]` were not confidently resolvable without live database access and must be confirmed before citing.

---

## 1. Comparative Angle Matrix (Top-Level)

| # | Angle | Literature Density (2020–2026) | ESP32 Feasibility | Thesis Differentiator Score (0–10) | Recommended Priority |
|---|-------|--------------------------------|-------------------|------------------------------------|----------------------|
| 1 | RL (DDPG/SAC/PPO) for VSG H, D tuning | **Saturated** (~50+ papers) | Low (inference OK, training offline) | 4 | Useful baseline, not novel |
| 2 | ANN / LSTM virtual inertia emulation | Moderate (~20–30 papers) | Medium | 6 | Possible secondary contribution |
| 3 | Model-free / data-driven GFM control | Growing fast | Low–Medium | 5 | Theoretically deep, high entry barrier |
| 4 | Fuzzy / ANFIS adaptive VSG | **Saturated**, especially in MENA/SEA journals | High | 3 | Easy but crowded; weak novelty |
| 5 | **PINN for inverter / power-electronic dynamics** | **Sparse** (~10–15 papers, mostly 2023+) | Medium (offline training, light inference) | **8** | **Strong differentiator** |
| 6 | **TinyML / edge ML on MCU for converter control** | **Very sparse** for kHz-class power control | High by definition | **9** | **Highest differentiator — direct ESP32 fit** |
| 7 | LSTM/Transformer frequency / RoCoF prediction for FFR | Moderate (~15–25 papers) | Medium (LSTM inference fits ESP32-S3) | 7 | Strong, complements outer-loop |
| 8 | AE / 1D-CNN anomaly detection on inverter telemetry | Moderate (~30 papers, mostly motor-drive / PV) | High (inference cheap) | 6 | Good "safety feature" sub-chapter |

**Honest take:** Angles 1 and 4 are crowded fields. A 3rd-year undergrad cannot out-publish a PhD lab on DDPG-VSG. The realistic novelty windows are **Angles 6, 5, and 7** — in that order. Angle 6 is essentially uncrowded for power-converter control rates and aligns directly with Napoleon's ESP32 + BESS scope.

---

## 2. Per-Angle Search Strings + Shortlists

### 2.1 Angle 1 — Reinforcement Learning for VSG Parameter Tuning

#### Search Strings
```
S1: ("virtual synchronous generator" OR "VSG" OR "virtual inertia") 
    AND ("reinforcement learning" OR "DDPG" OR "deep deterministic policy gradient" 
         OR "SAC" OR "PPO" OR "Q-learning")
    AND ("adaptive" OR "tuning" OR "online")

S2: ("grid-forming" OR "synchronverter") 
    AND ("deep reinforcement learning" OR "actor-critic") 
    AND ("inertia" OR "damping" OR "droop")

S3: ("frequency regulation" OR "frequency support" OR "primary control") 
    AND "reinforcement learning" 
    AND ("inverter" OR "converter" OR "inverter-based resource")
```

#### Candidate Papers

##### P1.1 — Adaptive Inertia and Damping of VSG using DDPG
- **Authors:** [Authors to be verified — typically from Chinese power-systems groups, e.g., Tsinghua / SGCC affiliates]
- **Year:** 2021–2022
- **Venue:** IEEE Transactions on Power Electronics OR IEEE Transactions on Smart Grid
- **DOI/Doc #:** [to be verified]
- **Why relevant:** Demonstrates that DDPG can outperform fixed H, D under step-load and grid-fault disturbances — direct template for Napoleon's adaptive layer.
- **Inferred limitations:** (a) Training done in Simulink on a desktop, not on MCU. (b) No hardware validation in most variants. (c) Reward function tuning rarely justified rigorously. (d) Sample efficiency typically poor (>100k episodes).

##### P1.2 — SAC-based Adaptive Virtual Inertia
- **Authors:** [Authors to be verified]
- **Year:** 2022–2023
- **Venue:** IEEE Access OR IET Renewable Power Generation
- **Why relevant:** SAC is more sample-efficient than DDPG; useful if Napoleon wants to try BESS-aware reward shaping (penalise SoC excursions).
- **Inferred limitations:** Pure simulation; reward weights are heuristic; rarely verified against IEEE-1547 ride-through windows.

##### P1.3 — Multi-agent RL for parallel VSGs
- **Authors:** [Authors to be verified]
- **Year:** 2023
- **Venue:** IEEE Transactions on Industrial Electronics OR Applied Energy
- **Why relevant:** If Napoleon ever scales to two-VSG microgrid, MARL is the SOTA framing. Not core to single-prototype scope.
- **Inferred limitations:** Centralised critic during training is impractical for distributed real microgrid.

> **Honest gap call:** RL-for-VSG is **saturated**. Napoleon should cite 2–3 of these as related work but should NOT pick this as primary contribution.

---

### 2.2 Angle 2 — Neural-Network-Based Virtual Inertia

#### Search Strings
```
S1: ("virtual inertia" OR "synthetic inertia") 
    AND ("neural network" OR "ANN" OR "LSTM" OR "deep learning") 
    AND ("emulation" OR "replace" OR "swing equation")

S2: ("data-driven" OR "neural") AND "swing equation" AND ("inverter" OR "converter")

S3: ("recurrent neural network" OR "LSTM" OR "GRU") 
    AND "inertia response" AND ("grid-forming" OR "VSG")
```

#### Candidate Papers

##### P2.1 — LSTM-Based Virtual Inertia Emulator
- **Authors:** [Authors to be verified]
- **Year:** 2022
- **Venue:** IEEE Transactions on Smart Grid OR Electric Power Systems Research (Elsevier — fallback)
- **Why relevant:** Replaces the swing-equation integrator with an LSTM trained on Simulink data. Direct architectural precedent for what Napoleon could try.
- **Inferred limitations:** No stability proof; ML block can saturate or hallucinate outside training distribution; no hardware run.

##### P2.2 — ANN-augmented swing equation (hybrid model)
- **Authors:** [Authors to be verified]
- **Year:** 2021
- **Venue:** IEEE PES General Meeting proceedings (conference paper)
- **Why relevant:** Hybrid analytical + ANN — ANN only corrects model mismatch. Lower risk than full replacement and friendlier to a thesis defence.
- **Inferred limitations:** Conference paper depth; lacks discretisation analysis at MCU sample rates.

##### P2.3 — Physics-aware NN swing dynamics
- **Authors:** [Authors to be verified]
- **Year:** 2023
- **Venue:** IEEE Transactions on Power Systems
- **Why relevant:** Bridges Angle 2 with Angle 5 (PINN). Could be used to justify Napoleon's hybrid framing.
- **Inferred limitations:** Heavy GPU training cost; inference cost rarely reported in MCU-friendly units (FLOPs / kB).

---

### 2.3 Angle 3 — Data-Driven / Model-Free GFM Inverter Control

#### Search Strings
```
S1: ("grid-forming" OR "GFM") AND ("data-driven" OR "model-free" OR "model-based reinforcement learning") 
    AND ("control" OR "stability")

S2: ("Koopman operator" OR "behavioural systems theory" OR "DeePC") 
    AND ("inverter" OR "converter" OR "grid-forming")

S3: ("neural ODE" OR "neural state-space") AND ("inverter" OR "power electronics")
```

#### Candidate Papers

##### P3.1 — DeePC for GFM Inverter (Data-enabled Predictive Control)
- **Authors:** [Authors to be verified — likely ETH Zurich / Florian Dorfler group lineage]
- **Year:** 2022–2023
- **Venue:** IEEE Transactions on Power Systems OR IEEE CDC / ACC proceedings
- **Why relevant:** Foundational data-driven control reference. Probably too heavy for ESP32 inference, but a must-cite.
- **Inferred limitations:** Online QP solve; not MCU-feasible at kHz rates without aggressive compression.

##### P3.2 — Koopman-based linear surrogate for inverter dynamics
- **Authors:** [Authors to be verified]
- **Year:** 2023
- **Why relevant:** Could enable linear MPC on ESP32 if surrogate is small enough.
- **Inferred limitations:** Surrogate validity outside training trajectory is rarely proven.

> **Honest gap call:** Angle 3 is **theoretically deep** and gated by control-theory background. A 3rd-year undergrad can cite it but probably should not build on it as primary contribution unless co-advised by a control theorist.

---

### 2.4 Angle 4 — Fuzzy / ANFIS / Neural-Fuzzy Adaptive VSG

#### Search Strings
```
S1: ("VSG" OR "virtual synchronous generator") AND ("fuzzy logic" OR "ANFIS" OR "neuro-fuzzy") 
    AND ("adaptive inertia" OR "adaptive damping")

S2: ("fuzzy" OR "ANFIS") AND ("droop control" OR "frequency support") 
    AND ("microgrid" OR "islanded")

S3: "Takagi-Sugeno" AND ("inverter" OR "VSG" OR "grid-forming")
```

#### Candidate Papers

##### P4.1 — Fuzzy adaptive H for VSG
- **Authors:** [Authors to be verified — many candidates from Iranian / Indian / Egyptian groups]
- **Year:** 2020–2023
- **Venue:** IEEE Access (high probability) or IEEE Transactions on Industry Applications
- **Why relevant:** Simple rule-based table; runs in microseconds on ESP32. Easy to implement, easy to compare against ML methods as a baseline.
- **Inferred limitations:** Rule base is heuristic; no formal stability proof; performance plateaus quickly.

##### P4.2 — ANFIS-tuned droop coefficient
- **Authors:** [Authors to be verified]
- **Year:** 2021–2022
- **Why relevant:** ANFIS is an underrated baseline — Napoleon can frame TinyML neural net as "ANFIS evolved."
- **Inferred limitations:** Training data scarcity in published works; sometimes only 1 disturbance case shown.

> **Honest gap call:** Angle 4 is **saturated** in the SEA / MENA literature. Good as a baseline-comparison chapter, not a thesis differentiator.

---

### 2.5 Angle 5 — Physics-Informed Neural Networks (PINN) for Inverter / Power-Electronic Dynamics

#### Search Strings
```
S1: ("physics-informed neural network" OR "PINN") 
    AND ("inverter" OR "power electronics" OR "converter" OR "grid-forming")

S2: "physics-informed" AND ("swing equation" OR "virtual inertia" OR "synchronous machine")

S3: ("Lyapunov" OR "stability-constrained") AND ("neural network" OR "deep learning") 
    AND ("inverter" OR "power system dynamics")
```

#### Candidate Papers

##### P5.1 — PINN for power system swing dynamics
- **Authors:** [Authors to be verified — Misyris/Chatzivasileiadis (DTU) is a strong candidate lineage]
- **Year:** 2020–2022
- **Venue:** IEEE PES General Meeting OR IEEE Transactions on Power Systems
- **Why relevant:** Foundational reference applying PINN to swing equation — directly transferable framing to VSG swing-emulation block.
- **Inferred limitations:** Solves the *forward* problem; inverse / control use is still open. Inference time on MCU not reported.

##### P5.2 — Stability-constrained learning for GFM inverters
- **Authors:** [Authors to be verified]
- **Year:** 2023–2024
- **Venue:** IEEE Transactions on Power Electronics
- **Why relevant:** Provides Lyapunov-style guarantees missing from Angles 1–2. Strong narrative for a defence: "ML, but provably stable."
- **Inferred limitations:** Training cost; constraint enforcement may sacrifice transient performance.

##### P5.3 — PINN surrogate for converter EMT simulation
- **Authors:** [Authors to be verified]
- **Year:** 2023
- **Why relevant:** Could replace heavy EMT model in Napoleon's HIL loop — speedup angle.
- **Inferred limitations:** Surrogate may not capture switching ripple needed for real filter design.

---

### 2.6 Angle 6 — TinyML / Edge ML on ESP32 / MCU for Power-Converter Control [**Highest Differentiator**]

#### Search Strings
```
S1: ("TinyML" OR "edge machine learning" OR "embedded neural network") 
    AND ("inverter" OR "converter" OR "motor drive" OR "power electronics")

S2: ("ESP32" OR "STM32" OR "Cortex-M" OR "RP2040") 
    AND ("neural network" OR "machine learning") 
    AND ("control" OR "estimation" OR "prediction") 
    AND ("inverter" OR "BLDC" OR "PWM" OR "converter")

S3: ("quantized neural network" OR "int8 inference" OR "TensorFlow Lite Micro" OR "TFLM" OR "CMSIS-NN")
    AND ("real-time control" OR "kHz" OR "embedded controller")
```

#### Candidate Papers

##### P6.1 — TinyML for motor / converter control on Cortex-M
- **Authors:** [Authors to be verified — likely Politecnico di Milano, ETH PBL group (Benini), or ARM research]
- **Year:** 2022–2024
- **Venue:** IEEE Transactions on Industrial Electronics OR IEEE Embedded Systems Letters
- **Why relevant:** **Directly answers Napoleon's core question:** can a tiny NN do real-time inference inside the control loop on a sub-$10 MCU?
- **Inferred limitations:** Most papers do BLDC / PV MPPT, not VSG inertia emulation — leaves Napoleon's specific application open as a contribution.

##### P6.2 — CMSIS-NN benchmarks for control-loop inference
- **Authors:** [Authors to be verified — ARM authors, e.g., Lai/Suda]
- **Year:** 2018 (original) + 2022+ follow-ups
- **Venue:** arXiv + IEEE conferences
- **Why relevant:** Tells Napoleon what NN sizes fit a 240 MHz Cortex-M / ESP32 at 10–20 kHz update rate. Crucial sizing reference.
- **Inferred limitations:** Generic, not power-electronics specific.

##### P6.3 — TensorFlow Lite Micro on ESP32 for sensor inference
- **Authors:** [Authors to be verified — Google / Pete Warden lineage; Espressif app-notes]
- **Year:** 2021–2023
- **Why relevant:** Tooling reference. Napoleon will use TFLM or ESP-DL. Establishes the deployable inference framework.
- **Inferred limitations:** Demonstrations are usually audio / vision; power-electronics latency budgets are stricter.

##### P6.4 — FPGA / MCU-based NN current controller
- **Authors:** [Authors to be verified]
- **Year:** 2023
- **Venue:** IEEE Transactions on Power Electronics
- **Why relevant:** Closest precedent of NN-inside-the-loop for an inverter. Likely uses FPGA, but architecturally informs ESP32 port.
- **Inferred limitations:** FPGA-based; latency budget on MCU will be tighter, may force quantisation.

> **Honest gap call:** Angle 6 is **the most uncrowded**. There is a wide-open window for a credible undergrad contribution: "ESP32-deployed TinyML inertia-coefficient predictor inside a VSG-BESS control loop." Even a negative-result thesis (showing what does NOT fit) is publishable.

---

### 2.7 Angle 7 — LSTM / Transformer Frequency / RoCoF Prediction for FFR

#### Search Strings
```
S1: ("LSTM" OR "GRU" OR "transformer") AND ("frequency prediction" OR "RoCoF" OR "frequency nadir") 
    AND ("power system" OR "microgrid")

S2: ("fast frequency response" OR "FFR") AND ("deep learning" OR "neural network") 
    AND ("inverter" OR "BESS" OR "battery")

S3: "time-series forecasting" AND ("grid frequency" OR "RoCoF") AND ("recurrent" OR "transformer")
```

#### Candidate Papers

##### P7.1 — LSTM frequency nadir forecasting
- **Authors:** [Authors to be verified]
- **Year:** 2021–2023
- **Venue:** IEEE Transactions on Power Systems
- **Why relevant:** Feeds VSG outer loop a 100–500 ms look-ahead → adaptive H boost before nadir hits. Genuinely useful for BESS-backed VSG.
- **Inferred limitations:** Forecast horizon vs. control latency tradeoff not always rigorous; trained on synthetic PSS/E data.

##### P7.2 — Transformer-based RoCoF estimator
- **Authors:** [Authors to be verified]
- **Year:** 2023–2024
- **Why relevant:** Higher accuracy at the cost of MCU feasibility — Napoleon may need to distil it.
- **Inferred limitations:** Transformer inference is heavy for ESP32; likely needs aggressive pruning/quantisation.

##### P7.3 — Hybrid Kalman + LSTM frequency estimator
- **Authors:** [Authors to be verified]
- **Year:** 2022
- **Why relevant:** Hybrid approach lighter than full transformer; ESP32 plausible.
- **Inferred limitations:** Tuning Kalman + NN jointly is non-trivial.

---

### 2.8 Angle 8 — AE / 1D-CNN Anomaly Detection on Inverter Telemetry

#### Search Strings
```
S1: ("autoencoder" OR "1D-CNN" OR "one-dimensional convolutional") 
    AND ("fault detection" OR "anomaly detection") 
    AND ("inverter" OR "converter" OR "power electronics")

S2: ("variational autoencoder" OR "VAE") AND ("inverter fault" OR "open-circuit" OR "short-circuit")

S3: "condition monitoring" AND ("deep learning" OR "neural network") 
    AND ("power converter" OR "IGBT" OR "MOSFET")
```

#### Candidate Papers

##### P8.1 — 1D-CNN open-circuit fault detection in three-phase inverter
- **Authors:** [Authors to be verified]
- **Year:** 2020–2022
- **Venue:** IEEE Transactions on Industrial Electronics OR IEEE Transactions on Power Electronics
- **Why relevant:** Direct safety-feature chapter. ESP32 can run a small 1D-CNN on current/voltage signatures.
- **Inferred limitations:** Most works are three-phase; Napoleon's prototype may start single-phase.

##### P8.2 — Autoencoder anomaly detection for PV inverter
- **Authors:** [Authors to be verified]
- **Year:** 2022
- **Why relevant:** AE inference is cheap; unsupervised training fits "few-fault-data" reality.
- **Inferred limitations:** Threshold selection often heuristic.

##### P8.3 — IGBT/MOSFET health monitoring via NN
- **Authors:** [Authors to be verified]
- **Year:** 2023
- **Why relevant:** Long-term reliability angle for BESS-tied VSG.
- **Inferred limitations:** Often requires thermal sensors Napoleon's prototype may not have.

---

## 3. Ranked Recommendation

### Top 3 Angles for Napoleon's Thesis (in order)

1. **Angle 6 — TinyML on ESP32 for VSG control-loop inference.**  
   Direct platform fit, uncrowded literature, defensible as the central contribution.

2. **Angle 5 — PINN / stability-constrained NN for VSG swing dynamics.**  
   Strong theoretical narrative ("ML but provably stable"). Pairs naturally with Angle 6 as the *training* methodology behind a small deployable model.

3. **Angle 7 — LSTM frequency / RoCoF forecaster feeding adaptive H.**  
   Concrete BESS-aware use case. ESP32-S3 can host a small LSTM. Good demo material.

### Suggested Thesis Framing
> "A physics-informed, TinyML-deployable inertia-adaptation layer for an ESP32-based VSG-BESS prototype."
>
> Train a PINN-regularised compact NN offline (Angle 5), deploy quantised on ESP32 (Angle 6), with an optional LSTM frequency forecaster feeding adaptive H/D (Angle 7). Use Angles 1, 2, 4 as baseline comparisons. Angle 8 as a safety feature appendix.

### Highest-Priority Paper to Read First
**P6.2 — CMSIS-NN benchmarks (ARM, Lai/Suda lineage).**  
Why first: it sets the **feasibility envelope**. Until Napoleon knows what NN size fits an ESP32 budget at his target control rate (likely 10–20 kHz for inner loop, 100–1000 Hz for outer VSG loop), every other angle is speculative. Read it, extract the MAC-budget vs. inference-time curve, and that becomes the design constraint for all subsequent ML model selection.

---

## 4. Open Questions Napoleon Should Resolve Before Round 2

1. What is the **inner-loop control rate** of his Simulink model — 10 kHz, 20 kHz? This decides whether NN-in-the-inner-loop is feasible or whether ML should live only in the outer (slow) loop.
2. ESP32 classic vs. ESP32-S3 vs. ESP32-P4? S3 has vector instructions that matter for NN inference.
3. Is BESS modelled as ideal DC source or with SoC dynamics? Affects whether RL reward shaping is meaningful.
4. Single-phase or three-phase prototype? Affects which fault-detection literature transfers.

---

*End of file. Next research round should include live IEEE Xplore result counts per search string and confirmed authors/DOIs for every `[Authors to be verified]` flag.*
