# VSG Hardware Prototype — Research Report #01
**Date:** 2026-05-20  
**Scope:** ESP32 inverter control feasibility, essential protection circuits, MOSFET selection  
**Target hardware:** Single-phase H-bridge, 24–48V DC bus, 100–500W, 50 Hz, Thai grid  
**MCU:** ESP32 (Xtensa LX6, 240 MHz, hardware FPU, Arduino IDE / ESP-IDF v5+)

---

## Table of Contents
1. [ESP32 Inverter Control Feasibility](#1-esp32-inverter-control-feasibility)
2. [Essential Protection Circuits](#2-essential-protection-circuits)
3. [Switch Technology Selection](#3-switch-technology-selection)
4. [First Power-On Safety Checklist](#4-first-power-on-safety-checklist)
5. [Open Questions & Next Steps](#5-open-questions--next-steps)
6. [Sources](#6-sources)

---

## 1. ESP32 Inverter Control Feasibility

### 1.1 MCPWM Peripheral — Switching Frequency

ESP32 has **two MCPWM units** (MCPWM0, MCPWM1). Each unit: 3 timers, 3 operators, 6 PWM outputs (3 complementary A/B pairs). Base clock: **160 MHz**.

For center-aligned SPWM (UP_DOWN counter mode — correct for single-phase SPWM):

| Switching Freq | Timer Resolution | Period Register | Effective Duty Resolution |
|---|---|---|---|
| 10 kHz | 16 MHz | 800 counts | ~9.6 bit |
| 20 kHz | 16 MHz | 400 counts | ~8.6 bit |
| 40 kHz | 16 MHz | 200 counts | ~7.6 bit |

**10–20 kHz is well within capability.** The practical upper limit before resolution degrades is ~80 kHz.

ESP-IDF v5+ API uses `mcpwm_timer_config_t::resolution_hz` — prescalers are calculated internally.

### 1.2 Hardware Dead Time

Dead time is **natively supported in hardware** via the MCPWM operator — does NOT depend on software timing and cannot be violated by OS jitter.

```c
mcpwm_dead_time_config_t dt_config = {
    .posedge_delay_ticks = 20,      // rising edge delay (ticks)
    .negedge_delay_ticks = 20,      // falling edge delay (ticks)
    .flags.invert_output_b = true   // B = complement of A + dead time
};
mcpwm_operator_apply_deadtime(oper_handle, &dt_config);
```

At timer resolution 10 MHz: **1 tick = 100 ns** → `posedge_delay_ticks = 20` → 2 µs dead time.  
**Start prototype at 2 µs dead time** — tune down after waveform is verified.

### 1.3 Hardware Fault Trip

The MCPWM **FAULT input** can trip all PWM outputs to a safe state (all low) in **< 1 µs**:

```c
mcpwm_gpio_fault_config_t fault_cfg = {
    .gpio_num = FAULT_GPIO,
    .flags.active_level = 0,  // active low
    .flags.pull_up = true,
};
// Trip action: force all outputs low on fault
mcpwm_operator_set_brake_on_fault(oper, fault, MCPWM_OPER_BRAKE_MODE_OST);
```

Wire an analog comparator output directly to the FAULT GPIO for hardware overcurrent protection.

### 1.4 ADC Sampling Rate and Current Control ISR

ESP32 has two **12-bit SAR ADCs** (ADC1: 8 channels, ADC2: 10 channels).

| Mode | Max Sample Rate |
|---|---|
| WiFi active | ~1,000 sps (ADC2 unusable) |
| WiFi OFF, polling | ~100,000 sps (100 ksps) |
| DMA continuous | up to ~270 ksps sustained |

> **Critical:** ADC2 is shared with the WiFi radio. **Disable WiFi entirely** for power electronics control. Use **ADC1 only**.

At 100 ksps (WiFi OFF):
- **10 kHz control ISR → feasible** (10× oversampling margin)
- **20 kHz control ISR → tight** (50 µs budget; ADC oneshot ~2 µs → ~40% of ISR budget)

**Correct ISR pattern:**
```c
// Use hardware timer interrupt at Fsw rate
// Pin ISR to Core 1 (APP_CPU)
// Core 0 (PRO_CPU) for housekeeping only
void IRAM_ATTR control_isr(void *arg) {
    adc_oneshot_read(adc_handle, ADC_CHANNEL_0, &raw);
    // ... current control loop ...
    mcpwm_comparator_set_compare_value(cmp, duty);
}
```

> **Fallback at 20 kHz:** If internal ADC is too noisy or slow, use an **external SPI ADC** (MCP3201, ADS8688) with hardware CS triggered synchronously to MCPWM. This is a known limitation of the ESP32 internal ADC.

### 1.5 Confirmed Open-Source ESP32 Inverter Implementations

| Project | Carrier Freq | Notes |
|---|---|---|
| `cybernetic-research/esp32-sine-inverter` | 18 kHz | Single-phase sinewave inverter, hardware demonstrated |
| Yopie DIY 3-phase SPWM | 20 kHz | 3-phase, 50 Hz, direct register writes |
| `FLWL/esp32-spwm` | Configurable | Single-phase SPWM, no LUT |

**Conclusion: 10–20 kHz inverter control on ESP32 is demonstrated in hardware by multiple projects.** The VSG outer loop (swing equation integration) is far less time-critical than the PWM ISR and is trivially feasible on ESP32.

---

## 2. Essential Protection Circuits

### 2.1 Non-Negotiable Protections (All Required Before First Power-On)

| # | Protection | Implementation | Why It Cannot Be Skipped |
|---|---|---|---|
| 1 | **Hardware overcurrent trip** | Shunt resistor → LM393 comparator → MCPWM FAULT pin | Software is too slow. Shoot-through destroys MOSFETs in < 1 µs at 48V. |
| 2 | **Dead time (hardware)** | MCPWM HW dead time block, start at 2 µs | MCU crash or software stall = zero dead time = immediate shoot-through. |
| 3 | **Gate driver isolation** | Isolated gate driver IC (see §2.2) | Prevent HV transients from coupling to ESP32 GND. Required for personnel safety. |
| 4 | **Pre-charge inrush limiting** | 10–47 Ω series resistor + bypass relay | Large electrolytic capacitors pull hundreds of amps on cold connect to DC bus. |
| 5 | **DC bus overvoltage TVS** | P6KE60A (60V TVS) across bus terminals | Switching transients and bus inductance spikes exceed DC bus voltage at turn-off. |
| 6 | **UVLO in gate driver** | Built into all recommended ICs below | Partial gate drive (VGS < threshold) → MOSFET in linear region → thermal runaway. |

### 2.2 Gate Driver IC Selection

For **24–48V DC bus, 100–500W, 10–20 kHz**:

| IC | Isolation | Peak Current (src/snk) | Built-in Dead Time | DESAT Protection | Verdict |
|---|---|---|---|---|---|
| **TI UCC21520** | 5.7 kVRMS reinforced | 4A / 6A | Programmable via resistor | ❌ needs external | **Recommended — add shunt comparator for OC** |
| **TI UCC21530** | 5.7 kVRMS reinforced | 4A / 6A | Programmable | ❌ needs external | Same family as UCC21520, slightly different pinout |
| **Skyworks Si8271** | 2.5 kVRMS (UL1577) | 4A / 4A | Programmable | ❌ needs external | Good alternative; 400 kV/µs CMR; lower input VCC (2.5–5.5V) |
| **ON Semi FAD3151MXA** | Isolated (automotive) | 2.5A / 2.5A | Yes | ✅ built-in | Simplest protection chain — integrates DESAT |
| **Infineon IR2184** | Bootstrap only (non-isolated) | 1.9A / 2.3A | ❌ none | ❌ | Simple but no isolation barrier; marked obsolescent; not recommended for first prototype |

> **Recommended combination:** **UCC21520** (isolated, reinforced, widely used in academic prototypes) + **LM393 shunt comparator** feeding the MCPWM FAULT pin for hardware overcurrent. If you want DESAT integrated: **FAD3151MXA**.

### 2.3 Desaturation (DESAT) Protection — How It Works

DESAT monitors **VDS of the MOSFET while commanded ON**. Under overcurrent, VDS rises (MOSFET exits saturation). The gate driver:
1. Blanks the measurement for 500 ns–1 µs after turn-on (masks the turn-on spike).
2. If VDS > threshold (e.g., 7–9V) after blanking → gate driver shuts off, latches FAULT.
3. Response time: typically **< 2 µs**.

At 48V with MOSFETs, the primary risk is shoot-through (not output short circuit), so the **shunt comparator approach is simpler and sufficient**. DESAT adds depth but requires a blanking circuit.

### 2.4 Pre-Charge Circuit Topology

```
Battery/PSU (+) ──── [Rprecharge 10–47 Ω, 10W] ──── [SW_bypass] ──── DC Bus (+)
                  └─────────────────────────────────────────────┘
                               (bypass switch in parallel with Rprecharge)

Sequence:
  1. SW_bypass OPEN → Connect supply through Rprecharge
  2. Monitor Vbus: wait until Vbus ≥ 0.9 × Vsupply
  3. Close SW_bypass (relay or N-ch MOSFET)
  4. Enable PWM output
```

> Never enable PWM before the bypass contactor is closed. Pre-charge resistors are not rated for continuous current.

---

## 3. Switch Technology Selection

### 3.1 Technology Comparison at 24–48V, 100–500W, 10–20 kHz

| Technology | Verdict | Reason |
|---|---|---|
| **N-ch Si MOSFET** | ✅ **Correct choice** | Low Vds → conduction loss dominated by RDS(on), which is very low at 48V. Fast switching, low gate charge, cheap. |
| **IGBT** | ❌ Wrong for this voltage | Fixed VCE(sat) 0.7–2V dominates at low bus voltage. Slow tail current at turn-off limits frequency. IGBTs are only optimal > 300V. |
| **SiC MOSFET** | ❌ Overkill | SiC advantages appear above 600V. Cost premium not justified at 48V. |
| **GaN FET** | ❌ Not justified | Complex gate drive requirements; 48V-class GaN is rare and expensive. |

### 3.2 Voltage Rating Derating Rule

**Standard: 80% derating (Vishay AN861, IPC-9592)**

```
Vds_rated ≥ Vbus_max / 0.8
```

| DC Bus Voltage | Vbus_max (with transients) | Required Vds_min | Recommended Class |
|---|---|---|---|
| 24V | ~30V | 37.5V | **60V or 80V class** |
| 48V | ~60V | 75V | **100V class** |

> The **IRFZ44N (Vds = 55V)** is too close to margin for a 48V bus — inductive switching spikes can push VDS above 55V and cause avalanche breakdown. Use **100V class**.

### 3.3 MOSFET Selection Criteria

At 100–500W, 48V: peak current = 500W / 48V ≈ 10.4A → need ID_rated > **20–25A** (2× derating).

| Parameter | Target | Reason |
|---|---|---|
| Vds rating | ≥ 100V (for 48V bus) | 80% derating rule |
| ID_rated | ≥ 20–25A | 2× current derating |
| RDS(on) at VGS=10V | < 30–50 mΩ | Conduction loss < 1% at 10A |
| Gate charge Qg | < 50 nC | Clean switching at 10–20 kHz |
| Avalanche rated (UIS) | Yes | Inductive switching without snubber |

**Candidate MOSFETs:**

| Part | Vds | ID | RDS(on) | Qg | Notes |
|---|---|---|---|---|---|
| **IRF540N** | 100V | 33A | 44 mΩ | ~72 nC | Classic, proven, easy to source anywhere |
| **IRFB3307** | 75V | 120A | 4.8 mΩ | ~220 nC | Very low RDS(on) but high Qg — use if conduction loss is priority |
| **IRLB3034** | 40V | 195A | 1.4 mΩ | ~260 nC | ❌ Too low Vds for 48V bus |
| **STP80NF55** | 55V | 80A | 8 mΩ | ~95 nC | ❌ Borderline for 48V — not recommended |

> **IRF540N** is the safe, conservative starting point for a first prototype. Widely available at MBK, JIB, Advice, or Lazada Thailand.

### 3.4 Gate Resistor

Always install a gate resistor (Rg) in series with each MOSFET gate:
- **4.7–22 Ω** for 10–20 kHz
- Damps ringing, limits gate current, slows dV/dt to reduce EMI
- Do NOT connect ESP32 GPIO directly to MOSFET gate — always through a gate driver IC

---

## 4. First Power-On Safety Checklist

### Stage 1 — Bench Setup (Before Any Power Applied)
- [ ] Current-limited bench PSU at **200% of expected peak** (e.g., 5A limit for 100W/48V)
- [ ] Oscilloscope probes on: Vbus, VGS of each MOSFET (×4), Vout, shunt voltage
- [ ] **Resistive dummy load only** — no reactive load on first tests
- [ ] Fire extinguisher nearby; no flammable materials on bench

### Stage 2 — Gate Driver + ESP32 (Before Connecting DC Bus)
- [ ] Gate driver VCC (12–15V) verified with lab supply independently
- [ ] MCPWM signals verified at ESP32 GPIO: correct frequency, dead time visible on scope (≥ 2 µs gap), no shoot-through window
- [ ] Gate driver output VGS at MOSFET gates: high-side and low-side are complementary with dead time
- [ ] FAULT pin tested: apply FAULT signal externally → confirm all PWM outputs go low within < 1 µs

### Stage 3 — DC Bus Bring-Up (Pre-charge)
- [ ] Pre-charge resistor (10–47 Ω, 10W) in series with DC bus — do NOT bypass until Vbus ≥ 90% of supply
- [ ] TVS diode (P6KE60A, 60V) installed across bus terminals
- [ ] Monitor Vbus on scope/meter during pre-charge
- [ ] Close bypass relay/switch → THEN enable PWM

### Stage 4 — Protection Circuit Verification
- [ ] Overcurrent comparator tested: inject signal above threshold → FAULT asserts → PWM shuts off in < 5 µs
- [ ] Dead time re-measured on scope at operating temperature: confirm > 1 µs margin
- [ ] UVLO check: drop gate driver VCC slowly → confirm PWM shuts off before VGS drops below MOSFET threshold (~2V)

### Stage 5 — Thermal and Mechanical
- [ ] MOSFETs mounted on heatsink with thermal compound (even at 100W, 2–5W dissipated per device)
- [ ] All high-current connections are low-inductance: short, wide PCB traces or twisted pairs for wiring
- [ ] Gate resistors (4.7–22 Ω) installed in series with each gate
- [ ] Snubber capacitors (10–100 nF, 100V film) across each MOSFET drain-source for ringing suppression

### Stage 6 — Software
- [ ] PWM enabled at **minimum duty** (m_a = 0.05) on first test — not full modulation
- [ ] Soft start ramp implemented: 200–500 ms from zero to operating m_a
- [ ] Watchdog timer active — resets MCU if control loop stalls
- [ ] Emergency stop: push-button GPIO that calls `mcpwm_timer_disable()` and drops bypass relay coil

---

## 5. Open Questions & Next Steps

| Question | Priority | How to Answer |
|---|---|---|
| DC bus voltage: 24V or 48V? | **HIGH** — drives MOSFET class, TVS rating, gate driver VCC | Design decision — Napoleon to decide based on battery pack availability |
| LCL or LC filter? | HIGH — affects output waveform quality and resonance risk | Research Report #02 (filter design) |
| Can ESP32 close inner current loop at 20 kHz with internal ADC? | MEDIUM | Empirical test: write ISR, measure execution time, check ADC noise floor |
| Gate driver PCB layout rules (power loop, gate loop minimization) | HIGH | Research Report #03 (PCB layout) |
| UCC21520 external DESAT circuit design | MEDIUM | TI reference design in UCC21520 datasheet, Section 9 |
| ESP32 MCPWM + grid PLL synchronization (for grid-connected VSG) | LOW (Phase 3) | Research after standalone mode is working |

---

## 6. Sources

| # | Title | Author / Organization | Year | URL |
|---|---|---|---|---|
| 1 | ESP-IDF MCPWM API Reference (v6.0.1 stable) | Espressif Systems | 2024 | https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/peripherals/mcpwm.html |
| 2 | MCPWM Dead Time and Fault Detection (ESP32) | circuitlabs.net | 2023 | https://circuitlabs.net/mcpwm-dead-time-and-fault-detection/ |
| 3 | 3-Phase Inverter using ESP32 as SPWM Generator | Yopie DIY | 2022 | https://yopiemaker.com/3-phase-inverter-using-esp32-as-spwm-generator/ |
| 4 | esp32-sine-inverter (GitHub) | cybernetic-research | 2023 | https://github.com/cybernetic-research/esp32-sine-inverter |
| 5 | esp32-spwm (GitHub) | FLWL | 2022 | https://github.com/FLWL/esp32-spwm |
| 6 | ESP-FAQ: ADC Sampling Rate and WiFi Interference | Espressif Systems | 2024 | https://docs.espressif.com/projects/esp-faq/en/latest/software-framework/peripherals/adc.html |
| 7 | ESP32 Forum — ADC DMA Sampling Rate Discussion | ESP32 Community | 2023 | https://esp32.com/viewtopic.php?t=36821 |
| 8 | TI UCC21520 Product Page & Datasheet | Texas Instruments | 2023 | https://www.ti.com/product/UCC21520 |
| 9 | TI UCC21530 Product Page & Datasheet | Texas Instruments | 2023 | https://www.ti.com/product/UCC21530 |
| 10 | Si827x Isolated Gate Driver Datasheet (Si8271) | Skyworks Solutions | 2023 | https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/data-sheets/Si827x.pdf |
| 11 | IR2184 Gate Driver Product Page | Infineon Technologies | 2023 | https://www.infineon.com/part/IR2184 |
| 12 | IR2184 Datasheet | Infineon Technologies | 2022 | https://www.mouser.com/datasheet/3/70/1/Infineon-IR2184(4)(S)-DataSheet-v01_00-EN.pdf |
| 13 | AND90251-D: FAD3151MXA Gate Driver Application Note | ON Semiconductor | 2022 | https://www.onsemi.com/download/application-notes/pdf/and90251-d.pdf |
| 14 | IGBT Overcurrent and Short-Circuit Protection in Industrial Motor Drives | Analog Devices | 2021 | https://www.analog.com/en/resources/technical-articles/igbt-overcurrent-and-short-circuit-protection-in-industrial-motor-drives.html |
| 15 | Short Circuit Protection for Power Inverters (App Note) | Infineon Technologies | 2020 | https://www.infineon.com/dgdl/Infineon-Short_Circuit_Protection_for_Power_Inverters-Article-v01_00-EN.pdf?fileId=5546d46254e133b401554de54b4d5be2 |
| 16 | DC Bus Pre-Charging Techniques | imperix.com | 2022 | https://imperix.com/doc/implementation/dc-bus-pre-charging-techniques |
| 17 | AN861: Power MOSFET Basics — Voltage Ratings and Derating | Vishay Intertechnology | 2019 | https://www.mouser.com/pdfdocs/Vishay_AN861.pdf |
| 18 | IGBT vs MOSFET — Which Device Fits Your Inverter/UPS Application | Invertekenergy | 2023 | https://www.invertekenergy.com/igbt-vs-mosfet-comparison-which-device-fits-your-inverter-ups-application/ |
| 19 | TN00008: Power MOSFET FAQ and Derating | Nexperia | 2021 | https://assets.nexperia.com/documents/technical-note/TN00008.pdf |
| 20 | EiceDRIVER Gate Driver IC Selection Guide | Infineon Technologies | 2018 | https://www.nexty-ele.com/nat/wp-content/uploads/sites/3/2018/02/Infineon-EiceDRIVER_Gate_Driver_ICs-ProductSelectionGuide-v01_01-EN.pdf |

---

*Research conducted: 2026-05-20 | Agent: vsg_prototype_researcher | Next report: hw_prototype_research_02.md (Filter Design — LC vs LCL)*
