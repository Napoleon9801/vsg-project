# Defense Q&A Bank — 66AOS02
**Source proposal**: `docs/โปรเจคท์-66AOS02-1.docx` (paragraphs P1–P188, Tables 0–3)
**Prepared**: 2026-05-27 — covers "ทุกตัวหนังสือที่เขียนมา" per อ.Kowgonk Oval (2026-05-25)
**Use**: defend every claim in the proposal. Each Q lists the proposal anchor it attacks.

---

## ⚠️ CRITICAL INCONSISTENCIES TO RECONCILE BEFORE DEFENSE

| # | Issue | Proposal says | Current design | Risk if asked |
|---|---|---|---|---|
| C1 | DC bus voltage | "ไม่เกิน 60 V" (P51) | 48 V actual | LOW — within envelope. Answer: "60V คือ safety upper bound, 48V คือ design point" |
| C2 | Rated power | "ไม่เกิน 300 W" (P51, P61) | 100 W total 3-phase | LOW — within envelope. Same answer pattern |
| C3 | Battery | "LiFePO4 24V 10Ah" (Table 2 R3) | Needs 4×12V = 48V stack | **HIGH** — BoM mismatch. Must update before submission |
| C4 | MCU | "ESP32" (P147, P186) + "CCS/Arduino IDE" (P49) | ESP32 primary, C2000 contingency | LOW — answer: dual-track per advisor advice |
| C5 | Filter inductor | "1.5 mH ≥5A" (Table 1 R5) | Stage 4–5a sim uses L_f=1mH | MED — need to recompute resonance with chosen value |
| C6 | Switching freq | "5–20 kHz" (P128), "10 kHz ISR" (P186) | Stage 5a uses 10 kHz | OK — consistent |
| C7 | Q-V loop equation | Referenced (P119–123) but no figure | Implemented in Stage 4 | Be ready to draw |
| C8 | Equations P82–P97, P110, P112, P123, P125 | Empty equation placeholders | Have full equations in code | **Insert before submission** |

---

# Section 1 — บทคัดย่อ + Ch.1 (Introduction)

## Q1.1 อะไรคือ Virtual Synchronous Generator (VSG) อธิบายในประโยคเดียว
**A**: VSG คืออัลกอริทึมควบคุมที่ทำให้ power inverter เลียนแบบพฤติกรรมเชิงพลวัตของเครื่องกำเนิดไฟฟ้าซิงโครนัส โดยจำลอง Swing Equation (`J·dω/dt = Pm − Pe − D·Δω`) ในซอฟต์แวร์ของ MCU เพื่อสร้าง **virtual inertia** และ **virtual damping** ให้กับโครงข่ายที่มี renewable penetration สูง

## Q1.2 ทำไมต้องเป็น Grid-Forming ไม่ใช่ Grid-Following (อ้าง P39–41)
**A**: GFL ทำงานเป็น current source ที่ "ตามกริด" ผ่าน PLL — ต้องการ stiff grid และไม่ให้ inertia. GFM ทำงานเป็น voltage source ที่กำหนดมุม/ความถี่เอง → ทำงานได้ทั้ง grid-connected และ islanded + จ่าย synthetic inertia ได้. **ในระบบ high-RE penetration ที่กำลังโตอย่างประเทศไทย GFM เป็น enabler ของการเพิ่มสัดส่วน RE โดยไม่สูญเสีย frequency stability**

## Q1.3 RoCoF คืออะไร เกณฑ์ในมาตรฐานเท่าไร (อ้าง P40)
**A**: Rate of Change of Frequency = `df/dt` หน่วย Hz/s
- IEEE 1547-2018: trip threshold ที่ ±2 Hz/s (default)
- ENTSO-E grid code: ระบบ EU ต้องทน ±1 Hz/s โดยไม่ trip
- Thai PEA/MEA: ยังไม่ระบุชัดเจน — ใช้ค่ายุโรปเป็น reference
- **target ของโปรเจค**: |RoCoF| < 0.5 Hz/s หลัง load step 20%

## Q1.4 inertia ของ SG ทั่วไปเท่าไร ระบบ inverter-dominated ลดลงเท่าไร (อ้าง P89–90)
**A**: H ของ SG จริงอยู่ในช่วง **2–6 วินาที** (turbo gen ~3s, hydro ~5s). ระบบที่มี GFL inverter penetration > 50% → H_effective ลดลง < 1 s บางช่วง — เกิด frequency nadir แรงและ RoCoF สูง. นี่คือ "low-inertia problem" ที่ VSG แก้

## Q1.5 ทำไมไม่ใช่ "ESS-supercapacitor-based inertia" หรือ FACTS อื่น
**A**: 3 เหตุผล:
1. **VSG ใช้อินเวอร์เตอร์ที่มีอยู่แล้ว** — ไม่ต้องลงทุนฮาร์ดแวร์เพิ่ม เปลี่ยนแค่ firmware
2. **VSG ทำ frequency + voltage support พร้อมกัน** — supercap inertia ทำเฉพาะ inertia
3. **VSG เข้ากับ BESS ที่ระบบไฟฟ้ามีอยู่แล้ว** — BESS + GFM เป็น industry standard (Tesla Hornsdale, Hawaiian Electric เป็นต้น)

## Q1.6 วัตถุประสงค์ 4 ข้อ — ลำดับความสำคัญ (อ้าง P42–46)
**A**: ลำดับ priority สำหรับ 16 สัปดาห์:
1. **(P43) สร้างแบบจำลอง MATLAB/Simulink** — base ของทุกอย่าง ✅ Stages 1–5a เสร็จแล้ว
2. **(P45) วิเคราะห์ค่า H, D ที่เหมาะสม** — sensitivity sweep (ต้อง add)
3. **(P44) เปรียบเทียบ VSG vs Droop** — comparison run
4. **(P46) ฮาร์ดแวร์ต้นแบบ** — risk สูงสุด, ถ้าเวลาไม่พอจะลดเหลือ HIL

## Q1.7 ขอบเขต "ไม่เกิน 60V / 300W" — เลือกเลขนี้ด้วยเหตุผลอะไร (อ้าง P51)
**A**:
- **60V** = below SELV threshold (UL: 60 VDC) → no high-voltage permit ที่ห้องแลป
- **300W** = ทดสอบ load step ได้ทั้ง resistive (rheostat 100Ω/200W ตาราง) และ inductive โดยไม่ trip breaker 3A
- **48V/100W actual** = headroom สำหรับ debug + Stage-5a สิมแล้ว modulation index = 0.58 อยู่ใน linear range

## Q1.8 ทำไม "ไม่ครอบคลุม THD detail" (อ้าง P55) ทั้งที่ THD สำคัญต่อ grid code
**A**: ไม่ใช่ ignore แต่ scope จำกัด:
- ใช้ LC filter design มาตรฐาน (f_res ~1.45 kHz, switching 10 kHz → attenuation 40 dB ที่ fsw)
- จะ verify THD < 5% ขั้นต่ำตาม IEEE 519 แต่จะไม่ optimize harmonic compensation algorithm (selective harmonic elimination, repetitive control)
- **ถ้ามีเวลาเหลือ** จะวัด FFT บน scope แล้ว report — ไม่ใช่ deliverable หลัก

## Q1.9 ทำไม "ไม่ครอบคลุม Thermal/Switching Loss" (อ้าง P56)
**A**: 100 W operation ใต้ pulse heatsink rating MOSFET (IRF540N: 70°C/W junction-to-case) — ไม่ใกล้ thermal limit. Switching loss ~2W per device ที่ 10 kHz/12A — ใช้ derating factor 2× จาก datasheet ปลอดภัย ถ้าจะ optimize loss ต้องไปใช้ SiC/GaN ซึ่งอยู่นอกขอบเขต

---

# Section 2 — Ch.2 Theory & Literature

## Q2.1 เขียน Swing Equation แบบเต็ม + อธิบายทุกตัวแปร (อ้าง P80–87)
**A**: 
```
2H · dω/dt = Pm − Pe − D·Δω    (pu form)
```
| ตัวแปร | หน่วย | ความหมาย |
|---|---|---|
| H | s | inertia constant = ½·J·ω₀² / S_base |
| ω | pu (or rad/s) | angular velocity |
| Pm | pu | mechanical input power (= P_ref ใน VSG) |
| Pe | pu | electrical output power (วัดจากจุด PCC) |
| D | pu/pu | damping coefficient |
| Δω | pu | ω − ω₀ |

**สำคัญ**: integrate ω → ได้ θ (angle); θ ใช้สร้าง voltage reference. ใน VSG, J ไม่มีอยู่จริง — เป็นแค่ค่าใน firmware

## Q2.2 H กับ J ต่างกันยังไง
**A**: 
- **J** = moment of inertia (kg·m²) — physical quantity
- **H** = inertia constant (s) = พลังงานจลน์ที่ rated speed / rated power = `½ J ω₀² / S_base`
- H มีหน่วยเป็นวินาที สื่อความหมายว่า "ถ้า full power output ถูกใช้เพื่อ accelerate rotor, ใช้เวลา 2H วินาที จาก standstill ถึง rated speed"
- ใน VSG ใช้ H เพราะ scale ไม่ขึ้นกับ MVA — เปรียบเทียบระหว่างเครื่องต่างขนาดได้

## Q2.3 D damping มาจากไหนใน SG จริง vs VSG (อ้าง P91–92)
**A**: 
- **SG**: damper winding (squirrel cage บน rotor) + eddy current ใน iron core → induced torque ต้าน rotor speed deviation
- **VSG**: synthetic — เป็นแค่ `D·Δω` term ใน software → ไม่ต้องการ energy storage เพิ่ม (ต่างจาก inertia ที่ต้องการ DC-side energy)

## Q2.4 ความสัมพันธ์ระหว่าง Droop gain (m) กับ D
**A**: 
- Steady-state droop: `Δf = m·ΔP` (m = droop coefficient, e.g. 5% → m = 0.05)
- ที่ steady-state, `dω/dt = 0` → Swing Eq กลายเป็น `Pm − Pe = D·Δω` → `Δω = ΔP/D` → `m = 1/D` (pu)
- ดังนั้น **D = 1/m**. 5% droop → D = 20 pu/pu
- **ผมเลือก D = 20** (สำหรับ 5% droop) ตาม practice ของ industrial generators

## Q2.5 ทำไม VSG ต้องมี Energy Storage ทาง DC side (อ้าง P130)
**A**: inertial transient power
```
P_inertial = 2H · (dω/dt) · S_base
```
ต้องไหลออกจริง — มาจาก DC link cap, battery, หรือ supercap
- **PV-only** ไม่ได้ — แผงโซลาร์เป็น current-limited source, จ่าย transient ไม่ได้
- **BESS** = best fit: ทำได้ทั้ง bidirectional + sustain transient
- โปรเจคนี้ใช้ **4×12V LiFePO4 stack** (revised จาก 24V single stack ตาม design point 48V)

## Q2.6 เปรียบเทียบ VISMA / Synchronverter / Droop-based VSG (อ้าง P135–144)
| | Order | PLL ต้องไหม | Complexity | สำคัญ |
|---|---|---|---|---|
| VISMA (Beck 2007) | Full SG (4th–7th order) | ต้องการ | สูงมาก | ความ accurate สูง แต่ MCU ต้อง real-time |
| Synchronverter (Zhong 2011) | 2nd order | **ไม่ต้อง** (self-sync) | ปานกลาง | reference design สำหรับ industry |
| Droop-VSG (De Brabandere 2007) | 1st order (LPF + droop) | ต้องการบ้าง | ต่ำ | simple แต่ inertia เป็น 1st-order, ไม่เลียน SG จริง |

**โปรเจคนี้ใช้** = Synchronverter-style (2nd order swing eq + Q-V droop) — balance ระหว่าง fidelity และ ESP32 compute budget

## Q2.7 Adaptive VSG (Alipoor 2015) คืออะไร ทำไมไม่ใช้
**A**: Adaptive VSG ปรับ H, D ตาม |dω/dt| — ใช้ H สูงตอน disturbance แรง, H ต่ำตอน return-to-steady. ดีกว่า fixed-parameter จาก benchmark studies
- **ไม่ใช้ใน Phase 1** ตามคำแนะนำอาจารย์ (2026-05-26 13:07): "เริ่มจากโมเดลง่ายก่อน → Fixed-parameter VSG ก่อน แล้วค่อยพัฒนาเป็น Adaptive หากเวลาลงตัว"
- ใน Ch.5 จะระบุ Adaptive VSG เป็น future work

## Q2.8 IEEE 1547-2018 vs IEEE 2988 ต่างกันยังไง (อ้าง P157–160)
**A**:
- **IEEE 1547-2018**: standard สำหรับ DER connection — required behavior: voltage/freq ride-through, reactive power, voltage regulation. **อนุญาตให้ GFM แต่ไม่ require**
- **IEEE 2988** (draft): standard เฉพาะ GFM — define virtual inertia, voltage-source behavior, black-start, fault current. **ยังไม่ ratified** จึงเป็น guideline reference

## Q2.9 มาตรฐาน Thai PEA/MEA ครอบคลุม GFM/VSG ไหม (อ้าง P166)
**A**: **ไม่ครอบคลุม** — PEA/MEA Interconnection Code (latest 2022) ระบุเฉพาะ GFL behavior: anti-islanding ต้อง trip ใน 2s, no synthetic inertia requirement, no GFM clause. นี่คือ **gap หนึ่งที่โปรเจคชี้ให้เห็น** — เป็น contribution ทาง policy implication

## Q2.10 ช่องว่างทางวิชาการของโปรเจคนี้คืออะไร (อ้าง P154)
**A**: 3 จุด:
1. **Low-cost MCU VSG** — literature ส่วนใหญ่ใช้ DSP (TI C2000, F28379D) หรือ FPGA. ESP32 ที่ราคา ~$5 vs $50+ ของ DSP ยังไม่มี benchmark publication ที่ครบ
2. **End-to-end MATLAB → HIL → physical chain** at sub-kW educational scale — ส่วนใหญ่งานวิจัยจบที่ simulation หรือ HIL เฉพาะส่วน
3. **Educational reproducibility** — open-source firmware + Simulink model + BoM ที่ทำตามได้

---

# Section 3 — Ch.3 Methodology

## Q3.1 ทำไมเลือก ESP32 (ไม่ใช่ TI C2000) (อ้าง P147, Table 1 R1)
**A**: 4 เหตุผล:
1. **Cost**: ESP32 ~150฿ vs C2000 dev kit ~3,500฿
2. **Compute headroom พอ**: ESP32 ที่ 240 MHz dual-core, Stage-5a control loop ที่ 10 kHz ใช้ ~30% CPU (Park/iPark + dual-PI + SPWM gen)
3. **WiFi built-in** → data telemetry ไม่ต้อง add module (matches advisor advice #4)
4. **Educational impact**: ESP32 มีในห้องเรียนทั่วไป → reproducibility สูง
- **Risk**: PWM resolution 16-bit ที่ 10 kHz = 8 LSB ต่อ duty cycle step (vs C2000 ที่ 12-bit ที่ similar freq). Mitigate ด้วย dithering หรือ raise to 11-bit + 20 kHz

## Q3.2 ทำไมเลือก AD7606 (อ้าง Table 1 R3)
**A**: 
- **Simultaneous sampling 8-channel 16-bit** — ต้องการ V_abc + I_abc + V_dc + I_dc พร้อมกัน เพื่อรักษา phase relationship (สำคัญสำหรับ Park transform)
- ESP32 internal ADC: 12-bit, มี crosstalk, ไม่ simultaneous → ไม่เพียงพอ
- SPI interface (5 MHz) → read 8ch ที่ 10 kSPS ใช้ ~10% bus
- **Alternative ที่พิจารณา**: ADS131M08 (delta-sigma, 24-bit) ดีกว่าแต่แพงกว่า 3× — overkill สำหรับ 100W

## Q3.3 ACS712-05B วัด ±5A — เกินช่วงโหลด 100W/48V ไหม
**A**: คำนวณ:
- I_phase RMS @ 100W 3-phase / 14V peak ≈ **2.4 A_RMS / 3.4 A_peak**
- ACS712-05B range ±5A → headroom 47%
- ระหว่าง transient (load step): I_peak อาจถึง 4–5A → ใกล้ limit แต่ยังไม่ saturate
- **Mitigation**: ใช้ over-current trip ที่ 4.5A (software) ก่อน sensor saturate
- **Alternative**: ACS712-20B (±20A) มี sensitivity ต่ำกว่า 4× → resolution loss

## Q3.4 LC filter design — ทำไม L=1.5 mH, C=15 µF (อ้าง Table 1 R5–R6)
**A**: f_resonance = `1/(2π·√(LC))` = `1/(2π·√(1.5e-3 × 15e-6))` ≈ **1.06 kHz**
- ระหว่าง grid fundamental (50 Hz) และ switching (10 kHz) — เป็น decade rule
- Attenuation at fsw = `(fsw/fr)²` ≈ 88× → 39 dB
- **issue**: damping ζ ≈ 0.23% (ที่ R_f=50mΩ) → ringing แรง → **ต้องมี R_d = 1Ω series with C_f** (Table 2 R1 — มีในตารางแล้ว)
- **MISMATCH**: Stage 4/5a sim ใช้ L=1 mH ไม่ใช่ 1.5 mH — ต้อง re-run sim ด้วย 1.5 mH หรือเปลี่ยน BoM

## Q3.5 ทำไม f_switching = 10 kHz (อ้าง P186)
**A**: trade-off:
- **สูงเกินไป (>20 kHz)**: switching loss สูง, ESP32 PWM resolution ตก
- **ต่ำเกินไป (<5 kHz)**: audible, LC ใหญ่, ripple สูง
- **10 kHz**: 200× fundamental → sufficient harmonic separation, MOSFET loss ~2W ที่ I=4A acceptable, อยู่นอก audible band, ESP32 hardware PWM (LEDC) supports up to 40 MHz/16-bit

## Q3.6 cascaded PI bandwidth ที่ใช้ (อ้าง P125)
**A**:
- **Inner current loop**: BW = 1 kHz (1/10 ของ fsw) — fast tracking, decoupled from outer
- **Outer voltage loop**: BW = 100 Hz (1/10 ของ inner) — แยก timescale ป้องกัน interaction
- **VSG outer (P-ω)**: equivalent BW จาก H = 5s → ω_n ≈ 1 rad/s = 0.16 Hz — slow electromechanical scale
- ทั้ง 3 loops แยก decade-by-decade → no interaction (classic time-scale separation)

## Q3.7 SPWM vs SVPWM — โปรเจคใช้อะไร (อ้าง P106, P128)
**A**: 
- **Stage 5a (current)**: ใช้ SPWM (sine-triangle) — implement ง่าย, modulation index max = 1 (linear)
- **Phase 2 firmware**: จะ upgrade เป็น SVPWM — เพิ่ม DC bus utilization 15% (max m_i = 2/√3 ≈ 1.15)
- **ทำไมเริ่มจาก SPWM**: pedagogical clarity + debug ง่ายกว่า — match advisor "เริ่มจากง่ายก่อน"

## Q3.8 Soft-start design (อ้าง P186)
**A**: เพื่อหลีกเลี่ยง inrush current ตอน startup:
- Ramp V_d_ref จาก 0 → 14V ใน 200 ms (linear)
- DC pre-charge: relay + 10Ω current-limiting resistor → ปล่อยให้ DC link cap charge ก่อน 100 ms → bypass relay
- ทั้งหมดเป็น ISR-level state machine ไม่ต้อง main loop

## Q3.9 over-current protection (อ้าง P186)
**A**: **Two layers**:
1. **Hardware**: comparator (LM393) เปรียบเทียบ ACS712 output กับ threshold = 4.5A → drive PWM_DISABLE pin โดยตรง — response < 1 µs
2. **Software**: ใน ISR ตรวจ |i_L_d|, |i_L_q| > 4A → set OC_FLAG, disable PWM, trip relay
- **Why two**: software 10 kHz = 100 µs latency, ไม่ทันสำหรับ short-circuit. Hardware layer คือ true safety

## Q3.10 unbalanced fault — โปรเจคจะทดสอบไหม
**A**: **ไม่ครอบคลุม** ใน Phase 1 (ตรงตาม scope P52: step load change เท่านั้น)
- เหตุผล: unbalanced fault ต้องใช้ negative-sequence control (PNSC), เพิ่ม complexity 2× firmware
- **อย่างไรก็ตาม** simulation จะรวม load asymmetry (เฟส A 33%, B 33%, C 33% → step phase A เพิ่ม 50%) เป็น sensitivity test

## Q3.11 ทำไม BESS 24V 10Ah พอ (อ้าง Table 2 R3) — เทียบกับ rated 100W
**A**: **ตรวจสอบ**:
- 100 W × 16-week sim run = peak 100W demand × ระยะเวลา transient (~1s) = ~28 mWh per event
- 24V × 10Ah = 240 Wh — overkill 8500× สำหรับ transient
- เลือกขนาดนี้เพราะ: (1) มาตรฐาน LiFePO4 module ขนาดเล็กสุด, (2) BMS built-in, (3) buffer สำหรับ regenerative load
- **ISSUE**: ถ้า design point เป็น 48V ต้องใช้ 4×12V → ต้องอัปเดต BoM

## Q3.12 อธิบาย Gantt 6 phases (อ้าง Table 3, P182–188)
| สัปดาห์ | Phase | Status |
|---|---|---|
| 1–2 | ศึกษาทฤษฎี | ✅ done |
| 3–6 | Simulation MATLAB/Simulink | ✅ Stages 1–5a done |
| 7–9 | Hardware design + filter | ⏳ pending |
| 9–12 | ESP32 firmware | ⏳ pending |
| 11–14 | Integration + test | ⏳ pending |
| 14–16 | Analysis + report | ⏳ pending |
- **Risk**: weeks 7–12 มี dependency บน hardware procurement (LC inductor custom-wound) — buffer 1 สัปดาห์

## Q3.13 ISR ที่ 10 kHz — ESP32 ทำได้จริงไหม (อ้าง P186)
**A**: คำนวณ instruction budget:
- 10 kHz → 100 µs per cycle
- ESP32 @ 240 MHz → 24,000 instructions per ISR
- **ใช้จริง**: Clarke + Park + dual-PI + iPark + iClarke + SPWM = ~600 ops × 2 cycles/op (FPU) = 1,200 cycles ≈ 5 µs (5% headroom)
- ใช้ Core 0 dedicated สำหรับ control ISR, Core 1 สำหรับ WiFi telemetry + UI
- **ทดสอบ**: เคยมี literature (Toyoda 2020) ทำ MMC control ที่ 20 kHz บน ESP32

---

# Section 4 — Equations to memorize

## E1: Swing Equation (pu form)
```
2H · (dω/dt) = Pm − Pe − D·(ω − ω₀)
```

## E2: VSG core (with droop)
```
2H · (dω/dt) = P_ref − P_meas − D_p·(ω − ω_g) − (1/m_p)·(ω − ω₀)
```

## E3: Q-V loop
```
K_v · (dV/dt) = Q_ref − Q_meas − D_q·V − (1/m_q)·(V − V₀)
```

## E4: Inner PI current loop (dq frame)
```
V_inv_d = Kp_i·(i_d_ref − i_d) + Ki_i·∫(i_d_ref − i_d)dt − ω·L·i_q + V_C_d
V_inv_q = Kp_i·(i_q_ref − i_q) + Ki_i·∫(i_q_ref − i_q)dt + ω·L·i_d + V_C_q
```
**Decoupling terms** = `±ω·L·i_q` (cross-coupling cancel)
**Feedforward** = `V_C_d, V_C_q` (faster ref tracking)

## E5: Park Transform (amplitude-invariant)
```
[V_d]   [cos(θ)   cos(θ−120°)  cos(θ+120°)]   [V_a]
[V_q] = (2/3) ·[-sin(θ)  -sin(θ−120°) -sin(θ+120°)] · [V_b]
[V_0]          [1/2      1/2          1/2        ]   [V_c]
```
**สำคัญ**: ใช้ factor 2/3 → power = (3/2)·(V_d·i_d + V_q·i_q)

## E6: LC filter
```
f_r = 1/(2π√(LC)), ζ = (R/2)·√(C/L)
```
ที่ L=1.5mH, C=15µF, R=50mΩ → f_r=1.06 kHz, ζ=0.0024 (under-damped!)
**ต้องการ R_d = 1Ω** → ζ ใหม่ = 0.05 (ยอมรับได้)

---

# Section 5 — Likely "trap" questions

## T1: "ถ้า ESP32 crash ระหว่าง operation ทำยังไง"
**A**: 3 layers:
1. Hardware OC trip (LM393) — ตัดไฟแม้ MCU ตาย
2. Watchdog timer ESP32 (TWDT, 1s) — auto-reboot
3. Relay open ถ้าไม่มี PWM heartbeat 100 ms → fail-safe

## T2: "PLL ต้องไหม ถ้าใช้ Synchronverter (claim self-sync)"
**A**: Synchronverter self-syncs in **grid-connected**, แต่ใน Phase 1 ผมใช้ **islanded mode primarily** + grid-connected เป็น Stage 5b. ใน islanded ไม่มีอะไรให้ sync — VSG เป็น master. Stage 5b จะ implement low-bandwidth PLL (50 Hz bandwidth) เพื่อ initial sync ก่อน close breaker

## T3: "ทำไมไม่ใช้ SiC MOSFET ที่ 100kHz switching"
**A**: 100W/48V ไม่ต้องการ — Si MOSFET (IRF540N) มี Rds_on 44mΩ → loss 0.7W ที่ 4A. SiC จะลดได้แค่ 0.2W → ไม่คุ้ม 5× cost. SiC คุ้มเมื่อ V > 200V หรือ I > 50A

## T4: "RoCoF ที่วัดได้ — แม่นยำแค่ไหน วัดยังไง"
**A**: คำนวณจาก derivative ของ θ (output ของ Swing Equation integrator) — exact ภายใน firmware. ถ้าวัดจากภายนอกใช้ instantaneous frequency = (1/2π)·(dθ/dt) ของ V_load — มี noise sensitivity → ใช้ moving average 10ms window

## T5: "Adaptive VSG vs ทำไมไม่ใช้ ML/AI"
**A**: ML-based VSG ต้องการ training data ที่มี ground truth optimal H,D — ยังไม่มี dataset standard. นอกจากนี้ MCU constrained → ใช้ rule-based adaptive (Alipoor 2015) มี better stability guarantee. ML คือ future work

## T6: "ถ้าให้คะแนน innovation 3/5 ทำยังไงจะเพิ่ม"
**A** (ตาม advisor feedback 2026-05-26 13:19):
- Focus contribution บน **ESP32 + reproducibility** angle ไม่ใช่ algorithm novelty
- Add **parameter optimization study** (Pareto front ของ H, D vs RoCoF, settling time, overshoot) — Ch.4 sensitivity
- Document **failure modes ที่พบ** (e.g., overmodulation discovery ของ Stage 5a) — engineering lesson sharing

## T7: "ทำไม VSG ไม่ใช้ direct synchronization (อ้างอิงมุม θ จาก grid)"
**A**: ใน weak grid, grid θ มี jitter + harmonic → VSG จะ propagate noise. Self-sync ผ่าน power balance (Synchronverter) เสถียรกว่า. PLL approach ใช้ใน grid-following เท่านั้น

## T8: "ทดสอบกับ real grid ห้องแลปไหม"
**A**: **ไม่** — proposal P53 ระบุ "weak grid mode" คือ simulated weak grid (R+L source impedance) ไม่ใช่ public grid. Anti-islanding ของ PEA ห้าม inject เข้า real grid โดยไม่มี protective relay/permit

---

# Section 6 — สิ่งที่ "ต้องแก้ในเล่ม" ก่อน defense

1. **P51 / P61**: เพิ่มประโยคว่า "60V/300W = safety envelope; ผลการ simulation Stage 5a ใช้ design point 48V/100W"
2. **Table 2 R3**: เปลี่ยน "24V 10Ah" → "48V (4×12V series) 10Ah"
3. **P82–P125 equations**: ใส่สมการจริง (เห็นว่าเป็น placeholder ใน .docx)
4. **Table 1 R5**: ระบุ "L_f = 1.5 mH (sim 1.0 mH — to reconcile)" หรือ rerun sim
5. **เพิ่ม Table 3 cell shading** สำหรับ Gantt — ปัจจุบันเป็น empty cells
6. **เพิ่ม Figure 3.1 actual block diagram** (P179 placeholder)
7. **เพิ่ม sensitivity sweep plan ใน Ch.4** ตาม advisor feedback #3

---

# Section 7 — Defense flow strategy

**Opening (2 min)**:
1. Problem: low inertia → frequency instability
2. Solution: VSG via inverter firmware
3. Scope: 48V/100W ESP32 prototype
4. Contribution: reproducible educational platform

**During Q&A**:
- ถ้าถาม equation → เขียนบนกระดาน (ฝึก E1–E6)
- ถ้าถาม BoM → ชี้ Table 1/2 + อธิบาย sizing (Q3.2–3.5)
- ถ้าถาม timeline → ชี้ Table 3 + Q3.12
- ถ้าถาม novelty → Q2.10 (3 gaps)
- ถ้า trap question → admit limitation + reference future work

**Closing**: ระบุ commitment 16 สัปดาห์ + sub-deliverables checklist

---

**Last update**: 2026-05-27 (matches Stage 5a sim results + 48V/100W design pivot)
