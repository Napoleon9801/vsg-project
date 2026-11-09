# E1.2 — สาเหตุ Vrms ยุบ/เกินใน Stage 5i load cycle และทางแก้ (2026-11-10)

สถานะ: ยืนยันสาเหตุแล้วด้วย reduced model และรัน switching Simulink พร้อม estimated load-current FF แล้ว (§6) **ผลดีขึ้นมากแต่ยังไม่ผ่าน V-TR/V-REC** firmware ยังไม่ได้แก้ ผลนี้ไม่ใช่ PASS ของ transient voltage quality

## 1. สรุปสั้น

Vrms ยุบเหลือ 7.15 V (step-up ที่ 3 s) และพุ่งถึง 13.45 V (ลดโหลดที่ 7 s) **ไม่ได้เกิดจาก VSG swing, secondary restoration หรือ LC resonance** แต่เกิดจาก outer voltage PI:

1. ออกแบบ gain ให้ plant เป็น Cf อย่างเดียว: `Kp_v = 2·0.707·628·Cf = 0.00888 A/V`, `Ki_v = 628²·Cf = 3.944 A/(V·s)` (`hardware/esp32/vsg_controller/vsg_controller.ino` บรรทัด 276–278)
2. แต่ conductance ของโหลดต่อเฟส G = 1/2.94 ถึง 1/2.059 = 0.34–0.49 S **ใหญ่กว่า Kp_v ราว 40–55 เท่า** และ Cf = 10 µF (≈318 Ω ที่ 50 Hz) แทบไม่มีผล
3. ไม่มี load-current feedforward ใน `id_ref` (บรรทัด 588–589) กระแสโหลดทั้งหมดจึงต้องมาจาก integrator ของ voltage PI

ผลคือเมื่อ R เปลี่ยน กระแสจะค้างที่ค่าเดิมชั่วขณะ แรงดันจึงกระโดดเป็น `V·G_old/G_new` แล้วค่อย ๆ กลับด้วย time constant `τ ≈ (Kp_v + G_new)/Ki_v`

## 2. ตรวจสมมติฐาน: ทำนาย vs Simulink

| ค่า | Analytic | Reduced model | Simulink Stage 5i |
|---|---|---|---|
| Vrms ต่ำสุดหลัง step-up (20 ms window) | envelope 6.93 V | 7.205 V | 7.154–7.219 V |
| Vrms สูงสุดหลังลดโหลด (20 ms window) | envelope 14.14 V | 13.450 V | 13.176–13.452 V |
| τ หลัง step-up | 125 ms | 113 ms | ≈120 ms (อ่านจาก CSV 3.02→3.12 s) |
| τ หลังลดโหลด | 88 ms | 85 ms | ≈86 ms (อ่านจาก CSV 7.026→7.119 s) |

Reduced model (แกน d ต่อเฟส, current PI + Lf/Rf + load-V FF ตาม firmware, ไม่รวม dq cross-coupling และ 1 mH ของโหลด) ให้ค่าที่ตรงกับ Simulink ภายในไม่กี่ % จึงยืนยันกลไกนี้

สคริปต์: `D:\workspace\engineering\vsg-project\python\analysis\e12_voltage_loop_reduced.py`
ผล: `D:\workspace\engineering\vsg-project\python\analysis\e12_voltage_loop_reduced_results.json`

## 3. ทำไมแค่เพิ่ม gain ไม่พอ

- เพิ่ม `Kp_v` จนชนะ G (~0.5 A/V): crossover ≈ Kp_v/Cf ≈ 50,000 rad/s ซึ่งเกิน current loop (6,283 rad/s) และทำให้ cascade พัง
- เพิ่ม `Ki_v` ให้ Ki/G เร็วขึ้น: ช่วยตอนมีโหลด แต่ตอน **ไม่มีโหลด** (plant เหลือแค่ Cf) จะได้ ωn = √(Ki/Cf) ใกล้ bandwidth ของ current loop ระบบจึงเสี่ยงไม่เสถียรที่ no-load
- สรุป: ปัญหาอยู่ที่ dependence ต่อโหลด ทางแก้มาตรฐานของ cascaded grid-forming คือ **load-current feedforward** ซึ่งทำให้ PI เหลือแค่ปรับ Cf ตามที่ออกแบบไว้เดิม

## 4. ทางเลือก feedforward (reduced model)

| Case | Vrms 20 ms หลัง step-up | Vrms 20 ms หลังลดโหลด | τ | ต้องเพิ่ม hardware? |
|---|---|---|---|---|
| ปัจจุบัน (ไม่มี FF) | 7.205 V (−27%) | 13.450 V (+36%) | 113/85 ms | — |
| Ideal i_o FF, F=1 | 9.487 V (−4.2%) | 10.442 V (+5.5%) | 4.1/3.4 ms | ต้องมี sensor ฝั่งโหลด |
| **i_L estimate FF, F=1, LPF 1 kHz** | **9.252 V (−6.5%)** | **10.759 V (+8.7%)** | **6.1/4.9 ms** | **ไม่ต้อง** |
| i_L estimate FF, F=1, LPF 500 Hz | 9.069 V (−8.4%) | 10.994 V (+11.1%) | 7.6/6.2 ms | ไม่ต้อง |
| i_L estimate FF, F=1, LPF 200 Hz | 8.652 V (−12.6%) | 11.486 V (+16.0%) | 11/9 ms | ไม่ต้อง; ช่วง 50 ms สุดท้ายยังแกว่ง 0.025 V ต้องตรวจ damping |
| i_L estimate FF, F=0.75 (ทุก LPF) | ≈7.7–7.8 V | ≈12.6–12.7 V | ≈31/22 ms | ไม่ต้อง; ไม่พอ |

`i_o_est = LPF(i_L − Cf·dv/dt)` ใน dq frame ใช้แค่ i_L (V1–V3) และ v (V4–V6) ที่วัดอยู่แล้ว

เรื่องช่อง ADC: AD7606 ใช้ V1–V3 = i_L, V4–V6 = phase V, V7 = bus เหลือแค่ V8 ว่าง โหลดแบบ floating neutral ต้องใช้ load-current sensor อย่างน้อย 2 ตัว จึง **ใส่ ideal i_o FF ไม่ได้ถ้าไม่เปลี่ยน channel map** (เช่น ย้าย i_L ไปเหลือ 2 ตัว ซึ่งจะเสีย redundancy ของ overcurrent protection) ทางเลือก i_L-estimate จึงเหมาะกับ BoM ปัจจุบันที่สุด

ข้อจำกัดของ reduced model: ไม่มี PWM ripple, ADC quantization/delay 1 tick, dq cross-coupling, ผลของ FF ต่อ P/Q measurement และ VSG swing, และไม่มี saturation `Iref_max` ผลจึงต้องยืนยันใน switching Simulink ก่อนสรุปผ่าน

## 5. เกณฑ์ acceptance ที่เสนอ (ต้องให้อาจารย์ยืนยันก่อนปรับ gain)

ฐาน: 9.8995 V RMS ต่อเฟส (14 V peak) วัดแบบเดียวกับ Stage 5i คือ trailing 20 ms RMS ที่ขั้วโหลดเทียบ load neutral

| ID | เกณฑ์ | ปัจจุบัน |
|---|---|---|
| V-SS | Steady state ทุกเฟสอยู่ใน ±2% (9.70–10.10 V) ที่โหลด 0–136 W | ผ่าน (9.746–9.797 V); ยังไม่มีเคส no-load |
| V-TR | Transient สำหรับ step 97↔136 W อยู่ใน ±10% (8.91–10.89 V) | **ไม่ผ่าน** (7.15 / 13.45 V) |
| V-REC | กลับเข้า ±2% ภายใน 40 ms (2 cycle) หลัง step | **ไม่ผ่าน** (≈ 4τ ≈ 450 ms) |
| V-NL | ไม่มี oscillation/instability ที่ no-load และระหว่าง step 0↔100 W | ยังไม่ได้ทดสอบ |
| F-REC | ความถี่ (internal) กลับเข้า 50±0.005 Hz ตาม Stage 5i เดิม และ FF ต้องไม่ทำให้แย่ลง | ผ่านแล้ว (≈2.9 s) |

ค่า ±10% และ 40 ms เป็น **เกณฑ์ของโปรเจคที่เสนอเอง** ไม่ได้อ้างตามมาตรฐาน หากต้องการอ้างมาตรฐาน ให้ตรวจ dynamic output curve ของ IEC 62040-3 (UPS) จากต้นฉบับก่อนใช้ตัวเลข

## 6. ผล Simulink rerun (switching model, 2026-11-10)

Runner: `D:\workspace\engineering\vsg-project\matlab\run_e12_ff_load_cycle.m` (job `run_e12_ff_load_cycle_nominal_job.m`)
ต้นทาง: `vsg_stage5i_load_cycle.tested_nominal.slx` (ไม่ได้แก้ต้นฉบับ) โดยเพิ่ม `i_ref += F·(LPF₁ₖHz(i_L,dq) + [+ωCf·vq; −ωCf·vd])` ที่ 10 kHz จาก ZOH samples เดิม
ผล: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\e12_ff_load_cycle\` (`analysis_nominal_ff1.json`, `curves_nominal_ff1.csv`, `e12_comparison.json`)
รูป: `D:\workspace\engineering\vsg-project\docs\figures\e12_ff_vs_baseline_2026-11-10.png`
ตัวเปรียบเทียบ: `D:\workspace\engineering\vsg-project\python\analysis\e12_compare_ff_load_cycle.py` (ใช้ pipeline RMS เดียวกับ Stage 5i)

**Equivalence:** F=0 smoke 0.1 s เทียบกับ Stage 5i smoke เดิม ได้ max |ΔV| = 0.33 mV (relative 3.3×10⁻⁵, RMS ต่างกัน ≤2.5 µV, ΔI ≤37 µA) ไม่ bit-exact เพราะเพิ่ม block แล้ว ode23tb เดินคนละ step path แต่ผ่าน tolerance 10⁻⁴ ที่ตั้งไว้

**Nominal 11 s (F=1, LPF 1 kHz):** wall time 538.6 s, signals finite ครบ, execution_pass = true

| เกณฑ์ | Baseline Stage 5i | FF (Simulink) | Reduced model ทำนาย |
|---|---|---|---|
| V-SS (±2%) | ผ่าน 9.746–9.797 V | ผ่าน 9.744–9.799 V | — |
| Vmin หลังเพิ่มโหลด (A/B/C) | 7.22/7.19/7.15 V | 9.27/9.39/**8.97** V | 9.25 V |
| Vmax หลังเพิ่มโหลด | — | 10.53/10.62/10.71 V | — |
| Vmin หลังลดโหลด | — | 8.93/9.05/**8.75** V | — |
| Vmax หลังลดโหลด | 13.31/13.45/13.18 V | 10.03/10.43/**11.40** V | 10.76 V |
| V-TR (±10% = 8.91–10.89 V) | ไม่ผ่าน | **ไม่ผ่าน** (8.75 V, 11.40 V) | — |
| V-REC (เข้า ±2% ภายใน 40 ms) | ไม่ผ่าน (ไม่เข้า / 237 ms) | **ไม่ผ่าน** (121 / 87 ms) | ≈10 ms |
| F-REC (50±0.005 Hz) | 2.92 / 2.88 s | 2.69 / 2.69 s | — |
| f min/max | 49.916 / 50.089 Hz | 49.906 / 50.093 Hz | — |

### สิ่งที่เห็นจากผล

1. **FF ช่วยมาก แต่ยังไม่ผ่านเกณฑ์** excursion ลดจาก −27%/+36% เหลือประมาณ −12%/+15% (เฟสที่แย่ที่สุด) และ phase A อยู่ใน ±6% ส่วน slow mode ที่ τ≈100 ms หายไปแล้ว
2. **ผลแย่สุดเกิดเฉพาะบางเฟสภายใน ~10 ms หลัง event** (phase C 11.40 V ที่ 7.010 s และ 8.97 V ที่ 3.008 s) ตรวจแล้วใน §6.1: ที่ 7 s เกิดจาก breaker staggering จริง ส่วนที่ 3 s ไม่ใช่
3. **ทิศของ transient กลับข้าง** หลังเพิ่มโหลด แรงดันยุบสั้น ๆ แล้ว overshoot (~10.5–10.7 V) ส่วนหลังลดโหลดจะยุบลง แสดงว่าตอนนี้ dynamics ถูกกำหนดโดย voltage PI + FF lag ไม่ใช่ load conductance แล้ว
4. **ความถี่ VSG เปลี่ยนไปในทิศที่ถูกต้องทางกายภาพ** baseline มีความถี่ *ขึ้น* ตอนเพิ่มโหลด เพราะแรงดันยุบจน P จริงลดลง ส่วน FF ทำให้ f ลงตอนเพิ่มโหลดและขึ้นตอนลดโหลดเหมือนเครื่องจักรซิงโครนัส ข้อนี้สำคัญสำหรับ thesis เพราะผล inertia/frequency ของ baseline ถูกบิดด้วย voltage collapse
5. **V-REC แบบ ±2% ของ 9.8995 V เปราะ** เพราะ steady state ที่โหลดสูงอยู่ 9.744 V (−1.6% จาก Q-V droop) ห่างขอบล่างแค่ 0.045 V ripple เล็ก ๆ ก็นับว่าหลุดได้ ควรพิจารณาวัด recovery เทียบกับค่า steady ใหม่หลัง event (เช่น ±2% ของค่า post-event)
6. **Reduced model ประเมินดีเกินจริง** (10.76 V เทียบกับ 11.40 V) เพราะเป็นแบบเฟสเดียวสมดุล ไม่มี breaker staggering, delay 1 tick, Q-V droop และ coupling

### 6.1 ตรวจสมมติฐาน breaker staggering

สคริปต์: `D:\workspace\engineering\vsg-project\python\analysis\e12_breaker_check.py`
ผล: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\e12_ff_load_cycle\e12_breaker_check.json`
รูป: `D:\workspace\engineering\vsg-project\docs\figures\e12_breaker_sequence_2026-11-10.png`

โครงสร้างโหลดในโมเดล (อ่านจาก block): แต่ละเฟสคือ `Load_RL` 2.058 Ω + 1 mH อนุกรมกับ `Load_Extra_R` 0.882 Ω ที่มี SPS `Breaker` (Ron 1 mΩ, external control) bypass อยู่ star ของ Cf และ star ของโหลดต่อกันที่ N_AC ซึ่งลอยเทียบกับ DC− (มีแค่ voltage measurement) SPS Breaker **ปิดทันทีเมื่อได้คำสั่ง** แต่ **เปิดที่ current zero ของแต่ละเฟส**

วิธีตรวจ: (1) หาเวลาสลับของแต่ละเฟสจาก residual `(v − 2.058·i − L·di/dt)/i` ซึ่งได้ ≈0.882 เมื่อ R เสริมอยู่ในวงจร และ ≈0.001 เมื่อถูก bypass (2) แยก V+, V−, V0 ด้วย 50 Hz DFT หน้าต่าง 20 ms

| | 3 s (เพิ่มโหลด) | 7 s (ลดโหลด) |
|---|---|---|
| เวลาสลับ A/B/C (FF run) | 0.0025/0.0025/0.0025 ms (พร้อมกัน) | 7.31/3.91/**0.38** ms (staggered) |
| V0 (zero seq.) สูงสุด | ≈0 V (4×10⁻¹¹) | **0.40 V** คงที่ตลอดช่วง stagger |
| V− สูงสุด | 0.37 V (baseline 0.44 V) | 0.54 V |
| V+ min–max (FF) | 9.17–10.60 V → **อยู่ใน ±10%** | 8.94–10.43 V → **อยู่ใน ±10%** |
| เฟสแย่สุด (FF) | 8.97–10.71 V | 8.74–**11.40** V |

**สรุป:**
- **7 s: สมมติฐานถูก** phase C เปิดก่อน (0.38 ms) จึงเป็นเฟสเดียวที่มี R เสริมอยู่ราว 3–7 ms N_AC (floating) เลื่อนจน V0 = 0.40 V และแรงดัน phase-to-N ของ C สูงสุด (11.40 V) ขณะที่ V+ อยู่แค่ 10.43 V ส่วนนี้คือ unbalance ที่ dq controller แบบ positive-sequence ควบคุมไม่ได้
- **3 s: สมมติฐานผิด** breaker ปิดพร้อมกันทั้งสามเฟสและ V0 = 0 phase C ที่ 8.97 V (ต่ำกว่าขอบ 8.91 V แค่ 0.06 V) มาจากการกระจายระหว่างเฟสตาม point-on-wave ของ transient ที่ไม่ stationary ในหน้าต่าง 20 ms V− = 0.37 V ระดับนี้ก็เกิดใน baseline ที่ step สมดุลเช่นกัน (0.44 V) จึงเป็น artifact ของหน้าต่าง ไม่ใช่ unbalance จริง
- **ถ้าวัดด้วย positive sequence FF ผ่าน V-TR ±10% ทั้งสอง event** แต่ถ้าวัดต่อเฟสยังไม่ผ่าน การเลือกนิยามนี้เป็นเรื่องของ spec ไม่ใช่ปัญหาของ controller
- stagger ที่ current zero ไม่ใช่แค่ artifact ของโมเดล contactor/breaker จริงก็ดับ arc ที่ current zero ของแต่ละเฟสเหมือนกัน การลดผลนี้ต่อเฟสต้องใช้ negative/zero-sequence control หรือเปลี่ยนการจัดการ neutral ซึ่งเกิน scope ของ E1.2 ปัจจุบัน

### Start-up (smoke 0.1 s)
โมเดลสั่ง V_set = 14 V แบบ step ตั้งแต่ t=0 (ไม่มี E ramp 2 s เหมือน firmware) baseline ดูนุ่มนวลเพราะ voltage loop ช้า เมื่อใส่ FF จะ overshoot ถึง **19.85 V peak (+42%) ที่ 14 ms** แล้วแกว่ง 13–15.5 V จน ~0.1 s
ผลคือ FF ต้องเปิดหลัง soft-start หรือใช้คู่กับ E ramp และ start-up ของโมเดลนี้ไม่ใช่ตัวแทนของ hardware

### Crash ระหว่างรัน
ครั้งแรกของ 11 s (01:02:24) MATLAB R2018b crash ด้วย heap corruption 0xc0000374 ช่วงท้าย sim ใกล้ขั้น finalize log (ครั้ง baseline ก็เคยเจอ memory allocation error) แก้ด้วยการเปลี่ยน log V/I 200 kHz เป็น `Structure With Time` แทน Timeseries จากนั้นรันผ่าน log อยู่ที่ `run_e12_20261110_crash_heap.log`

## 7. ขั้นต่อไป

1. ขอให้อาจารย์ยืนยันเกณฑ์ใน §5 (อย่างน้อย V-TR / V-REC) และนิยาม recovery (เทียบ nominal หรือเทียบ post-event steady state)
2. ~~Simulink copy + FF F=1 LPF 1 kHz~~ ทำแล้ว (§6) ดีขึ้นมากแต่ยังไม่ผ่าน V-TR/V-REC
3. ~~ตรวจสมมติฐาน breaker staggering~~ ทำแล้ว (§6.1): ที่ 7 s ถูก ที่ 3 s ผิด และ V+ ผ่าน ±10% ทั้งสอง event **ต้องให้อาจารย์ตัดสินว่า V-TR วัดต่อเฟสหรือวัด positive sequence**
4. ลดผลของ PI ต่อ excursion ที่เหลือ เช่น เพิ่ม ωCf decoupling ใน voltage loop ให้ตรง firmware (โมเดลไม่มีส่วนนี้ แต่ firmware มี) ลอง LPF 2–3 kHz หรือ lead compensation ของ delay 1 tick และใส่ `Iref_max` saturation ให้ตรง firmware
5. เพิ่มเคส no-load และ 0↔100 W เพื่อปิด V-NL และทดสอบ start-up พร้อม E ramp
6. ถ้าผ่าน ค่อย port เข้า firmware ในโหมด DRY_RUN พร้อม host test และอัปเดต Stage 5d discrete check เพราะ FF เปลี่ยนโครงสร้าง loop
