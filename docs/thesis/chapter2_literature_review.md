# บทที่ 2: ทฤษฎีและงานวิจัยที่เกี่ยวข้อง
# (Literature Review & Theory)

> **ผู้เขียน:** ชินวัตร ดำกลาง (Napoleon)
> **โครงงาน:** Virtual Synchronous Generator (VSG) for Grid-Connected Inverter
> **สถานะ:** Draft v3 — ครบทั้ง 5 sections; เติม authors + DOI + IEEE Xplore doc# จาก IEEE Xplore แล้ว (เหลือ verify spelling 2 รายการ — ดูท้ายไฟล์)

---

## 2.1 ลักษณะระบบอินเวอร์เตอร์แบบ Grid-Following และ Grid-Forming

ในระบบโครงข่ายไฟฟ้ายุคใหม่ที่มีการเชื่อมต่อแหล่งพลังงานหมุนเวียน (Renewable Energy Sources, RES) ผ่านอินเวอร์เตอร์อิเล็กทรอนิกส์กำลังสูงขึ้นเรื่อย ๆ การจำแนกอินเวอร์เตอร์โดยพิจารณาจาก *พฤติกรรมในการเชื่อมต่อกับกริด* (grid interface behavior) ถูกแบ่งออกเป็นสองกลุ่มหลัก ได้แก่ **Grid-Following Inverter (GFL)** และ **Grid-Forming Inverter (GFM)** [Rocabert et al., 2012; Lasseter et al., 2020]

### 2.1.1 Grid-Following Inverter (GFL)

อินเวอร์เตอร์แบบ GFL ทำหน้าที่เป็น **แหล่งจ่ายกระแสควบคุมได้ (controlled current source)** โดยฉีดกระแสเข้าสู่กริดตามค่ากำลัง P, Q ที่ถูกสั่งการ การทำงานของ GFL จำเป็นต้องอ้างอิงสัญญาณแรงดันและความถี่จากกริดที่มีอยู่แล้ว ผ่านวงจร Phase-Locked Loop (PLL) เพื่อ synchronize เฟสและความถี่ ดังนั้น GFL จึง *ต้องการกริดที่แข็งแรง (stiff grid)* ในการทำงาน

**คุณลักษณะหลัก:**
- พฤติกรรมไฟฟ้า: Current source (high output impedance)
- การ synchronize: PLL-based
- ความสามารถ islanding: ไม่สามารถทำงานแบบแยกอิสระได้
- การตอบสนองทาง dynamic: รวดเร็ว (current loop bandwidth สูง)
- ข้อจำกัด: ในระบบที่มีสัดส่วน RES สูง (low short-circuit ratio, SCR < 3) PLL จะ unstable และเกิด sub-synchronous oscillation

GFL เหมาะกับสภาวะที่มี Synchronous Generator (SG) เป็น backbone ของระบบ ซึ่งเป็นกรณีของระบบไฟฟ้าแบบดั้งเดิม

### 2.1.2 Grid-Forming Inverter (GFM)

อินเวอร์เตอร์แบบ GFM ทำหน้าที่เป็น **แหล่งจ่ายแรงดันควบคุมได้ (controlled voltage source)** ที่ *กำหนด (form)* ความถี่และแรงดันอ้างอิงให้กับระบบ คล้ายกับบทบาทของ Synchronous Generator ในระบบดั้งเดิม โดย GFM สามารถทำงานทั้งโหมดเชื่อมต่อกริด (grid-connected) และโหมดเกาะ (islanded mode) ได้

**คุณลักษณะหลัก:**
- พฤติกรรมไฟฟ้า: Voltage source (low output impedance)
- การ synchronize: Self-synchronization (power-based, ไม่จำเป็นต้องใช้ PLL)
- ความสามารถ islanding: ทำงานได้
- การให้บริการ ancillary: black start, virtual inertia, voltage support, fault current contribution
- ข้อจำกัด: ต้องการการป้องกัน over-current ระดับสูง เนื่องจาก voltage source ตอบสนองต่อ disturbance ด้วยกระแสไหลพุ่ง

### 2.1.3 การเปรียบเทียบ GFL vs GFM

| ประเด็น | Grid-Following (GFL) | Grid-Forming (GFM) |
|---|---|---|
| Equivalent source | Current source | Voltage source |
| ต้องการกริดอ้างอิง | ต้องการ | ไม่จำเป็น |
| Islanding capability | ไม่ได้ | ได้ |
| Black start | ไม่ได้ | ได้ |
| Virtual inertia | ไม่มี | มี (ในกรณี VSG) |
| Fault current | จำกัด (1.1–1.2 pu) | จำกัด (ต้องการ current limiter) |
| Synchronization | PLL | Power-frequency droop / VSG / dVOC |
| ความเสถียรใน weak grid | แย่ | ดี |
| การใช้งานปัจจุบัน | แพร่หลาย (PV, wind) | กำลังขยายตัว (BESS, microgrid) |

**ตระกูลของ GFM control:** Droop Control, Virtual Synchronous Generator (VSG / VISMA / Synchronverter), Matching Control, Dispatchable Virtual Oscillator Control (dVOC) [Tayyebi et al., 2020]

โครงงานนี้ใช้แนวทาง **VSG** ซึ่งเป็น GFM ประเภทหนึ่งที่จำลองพลวัตของ SG อย่างตรงไปตรงมาผ่านสมการ swing equation ทำให้สามารถมอบ *virtual inertia* ให้กับระบบที่มีสัดส่วน RES สูงได้

---

## 2.2 หลักการทำงานของเครื่องกำเนิดไฟฟ้าซิงโครนัส
### (Synchronous Generator Fundamentals: Swing Equation, Inertia, Damping, Droop)

### 2.2.1 สมการสวิง (Swing Equation)

พฤติกรรมเชิงพลวัต (dynamic behavior) ของ Synchronous Generator (SG) อธิบายด้วยสมการการเคลื่อนที่ของโรเตอร์ (rotor equation of motion) เมื่อพิจารณา rotor inertia เป็น lumped mass สามารถเขียนได้ในรูป

$$
J \frac{d\omega_m}{dt} = T_m - T_e - D_m (\omega_m - \omega_s)
$$

โดยที่
- $J$ = moment of inertia ของโรเตอร์ + กังหัน (kg·m²)
- $\omega_m$ = mechanical angular speed (rad/s)
- $\omega_s$ = synchronous speed (rad/s)
- $T_m$ = mechanical torque จากกังหัน (N·m)
- $T_e$ = electromagnetic torque (N·m)
- $D_m$ = damping coefficient (N·m·s/rad)

เมื่อแปลงเป็นรูป **per-unit (pu)** โดยใช้ inertia constant $H$ จะได้

$$
2H \frac{d\Delta\omega}{dt} = P_m - P_e - D \cdot \Delta\omega
$$

โดย $\Delta\omega = (\omega - \omega_s)/\omega_s$ คือ frequency deviation ใน pu และ

$$
H = \frac{\tfrac{1}{2} J \omega_s^2}{S_{base}} \quad [\text{s}]
$$

$H$ คือ **inertia constant** ซึ่งมีหน่วยเป็นวินาที (s) ตีความได้ว่า "พลังงานจลน์ของโรเตอร์ที่ความเร็ว synchronous ÷ กำลังพิกัด" หรือ "เวลาที่เครื่องสามารถจ่ายกำลังพิกัดได้จากพลังงานจลน์อย่างเดียว" สำหรับ SG ทั่วไป $H$ มีค่าประมาณ 2–10 s

### 2.2.2 บทบาทของ Inertia ในระบบไฟฟ้า

เมื่อเกิด disturbance เช่น โหลดเพิ่มขึ้นทันที (load step) หรือเครื่องกำเนิดตัวอื่นหลุดออกจากระบบ (generator trip) สมการสวินงระบุว่า อัตราการเปลี่ยนแปลงของความถี่ (Rate of Change of Frequency, **RoCoF**) แปรผกผันกับ inertia

$$
\frac{df}{dt}\bigg|_{t=0^+} = \frac{f_0}{2H \cdot S_{base}} \cdot \Delta P
$$

ในระบบที่มี inertia ต่ำ (เช่น microgrid ที่มี RES สัดส่วนสูง) RoCoF จะสูง ทำให้:
- Protection relay ที่ใช้ RoCoF (df/dt) trip บ่อย
- Generator อื่นใน system อาจ slip pole จาก angle deviation ที่เร็วเกินกว่า governor จะตามทัน
- Frequency nadir ลึกลงและเสี่ยงต่อ under-frequency load shedding (UFLS)

นี่คือ *เหตุผลหลัก* ที่ผลักดันให้เกิดเทคโนโลยี **Virtual Inertia / Synthetic Inertia** ในอินเวอร์เตอร์

### 2.2.3 Damping

ค่า damping $D$ ในสมการสวินงมาจากสองแหล่งคือ
1. **Damper winding** ของ SG (electromagnetic damping)
2. **Frequency-sensitive load** ในระบบ (load damping)

Damping ทำหน้าที่ลด oscillation หลัง disturbance และกำหนด settling time การวิเคราะห์เชิงเล็กน้อย (small-signal analysis) ของระบบ second-order ที่ประกอบด้วย $2H$ และ $D$ จะให้

- Natural frequency: $\omega_n = \sqrt{K_s/(2H)}$ เมื่อ $K_s = dP_e/d\delta$ คือ synchronizing power coefficient
- Damping ratio: $\zeta = D / (2\sqrt{2H \cdot K_s})$

### 2.2.4 Droop Control

Primary frequency control ใน SG ทำผ่าน **governor** ที่มีลักษณะ droop characteristic

$$
\Delta f = -R_p \cdot \Delta P
$$

โดย $R_p$ คือ **frequency droop** มีหน่วย Hz/MW (หรือ pu/pu) ทั่วไปกำหนดที่ 4–5%

ในทำนองเดียวกัน Q-V droop ทำหน้าที่จัดสรร reactive power ตามแรงดัน

$$
\Delta V = -R_q \cdot \Delta Q
$$

Droop เป็น *steady-state* control ในขณะที่ inertia เป็น *transient* response ทั้งสองทำงานร่วมกันเพื่อรักษาเสถียรภาพของระบบ

---

## 2.3 โครงสร้างและอัลกอริธึมควบคุม VSG
### (VSG Control Architecture & Algorithm)

แนวคิดของ Virtual Synchronous Generator คือการ *จำลองพฤติกรรมของ SG* ด้วยซอฟต์แวร์ฝังภายในการควบคุมของอินเวอร์เตอร์ ผลลัพธ์คือ inverter ที่มีพฤติกรรมเสมือน SG ทั้งในแง่ inertia, damping, และ droop response แม้ว่าตัว hardware จะไม่มีมวลเฉื่อยทางกลก็ตาม [Beck & Hesse, 2007; Zhong & Weiss, 2011]

### 2.3.1 สถาปัตยกรรมรวม (Overall Architecture)

โดยทั่วไป VSG ประกอบด้วย 4 ระดับชั้นที่ทำงานจาก outer ไปสู่ inner loop

```
                ┌──────────────────────────────────────┐
                │  1. Power Calculation                │
                │     (P, Q จาก v_abc, i_abc)          │
                └──────────────┬───────────────────────┘
                               ▼
                ┌──────────────────────────────────────┐
                │  2. VSG Core (Virtual Swing Eq.)     │
                │     - P–ω loop (inertia + damping)   │
                │     - Q–V loop (droop / excitation)  │
                └──────────────┬───────────────────────┘
                               ▼
                ┌──────────────────────────────────────┐
                │  3. Voltage / Current Inner Loop     │
                │     (dq-frame cascaded PI control)   │
                └──────────────┬───────────────────────┘
                               ▼
                ┌──────────────────────────────────────┐
                │  4. PWM / SVPWM Modulator            │
                └──────────────────────────────────────┘
```

### 2.3.2 P–ω Loop: สมการกำลังจริง-ความถี่ (Virtual Swing Equation)

หัวใจของ VSG คือการ implement swing equation เป็นสมการเชิงอนุพันธ์ที่อินเวอร์เตอร์ solve real-time

$$
2H \frac{d\Delta\omega}{dt} = P_{ref} - P_{meas} - D_p \cdot \Delta\omega
$$

หรือในรูปที่รวม droop term

$$
2H \frac{d\Delta\omega}{dt} = P_{ref} + \frac{1}{m_p}(\omega_{ref}-\omega) - P_{meas} - D_p (\omega - \omega_g)
$$

โดยที่
- $H$ = virtual inertia constant (s)
- $D_p$ = virtual damping coefficient (pu/pu)
- $m_p$ = active power droop gain
- $\omega_g$ = grid frequency reference (จาก PLL หรือ low-bandwidth tracking)

เมื่อ integrate $\omega$ จะได้มุม voltage reference

$$
\theta_{vsg} = \int \omega \, dt
$$

มุมนี้ใช้สร้าง voltage reference $v^* = E \sin(\theta_{vsg})$ สำหรับ inner loop

> **หมายเหตุทางการออกแบบ:** การเลือกค่า $H$ และ $D_p$ ต้องสมดุล — $H$ สูงให้ frequency stability ดีแต่ทำให้ response ช้า; $D_p$ สูงลด oscillation แต่เพิ่ม steady-state error ในการแบ่งโหลด งานวิจัย adaptive VSG จำนวนมากเสนอให้ $H$, $D_p$ ปรับเปลี่ยนตามสภาวะ disturbance [Alipoor et al., 2015]

### 2.3.3 Q–V Loop: สมการกำลังรีแอกทีฟ-แรงดัน

สำหรับการควบคุม reactive power และ voltage VSG ส่วนใหญ่ใช้ droop หรือ first-order dynamic ที่จำลอง excitation system

**Static Q–V Droop:**
$$
E = E_{ref} + m_q (Q_{ref} - Q_{meas})
$$

**Dynamic Q–V (excitation emulation):**
$$
K \frac{dE}{dt} = Q_{ref} - Q_{meas} - D_q (V - V_{ref})
$$

โดย $K$ คือ virtual excitation inertia, $D_q$ คือ virtual voltage damping ทำให้แรงดันออกของอินเวอร์เตอร์มีพลวัตคล้ายกับ field winding ของ SG

### 2.3.4 Inner Voltage/Current Loop

ภายหลังได้ $\theta_{vsg}$ และ $E$ จาก outer VSG loop ระบบจะส่งผ่าน Park transform ไปเป็น $v_d^*, v_q^*$ แล้วป้อนให้กับ cascaded PI controller ในกรอบ dq

- Voltage loop (outer): $v_{dq}^* \rightarrow i_{dq}^*$
- Current loop (inner): $i_{dq}^* \rightarrow v_{converter}^*$

จากนั้นแปลงกลับด้วย inverse Park transform แล้วป้อนเข้า SVPWM/SPWM modulator ที่ความถี่สวิตชิงสูง (เช่น 5–20 kHz)

### 2.3.5 การจำลองแรงเฉื่อยและการหน่วงเสมือน

**Virtual Inertia:** มาจาก term $2H \, d\omega/dt$ — อินเวอร์เตอร์ดึงพลังงานจาก DC-link หรือ energy storage เพื่อจ่าย transient power ตามอัตราที่ swing equation กำหนด ดังนั้น VSG จึง *ต้องการแหล่งพลังงานสำรอง* (BESS, supercapacitor, หรือ over-rated DC bus capacitance) เพื่อรองรับ inertial transient

**Virtual Damping:** มาจาก term $D \cdot \Delta\omega$ — สังเคราะห์ขึ้นจากการคำนวณ ไม่ต้องการ energy reservoir เพิ่มเติม

---

## 2.4 งานวิจัยที่เกี่ยวข้อง
### (Related Works)

หัวข้อนี้ทบทวนงานวิจัย 12 ชิ้นที่เกี่ยวข้องกับการออกแบบและพัฒนา Virtual Synchronous Generator (VSG) โดยรวบรวมจากฐานข้อมูล IEEE Xplore และจัดเก็บใน NotebookLM ของผู้เขียน

> **หมายเหตุเกี่ยวกับข้อจำกัด (Limitations):** เอกสารต้นฉบับส่วนใหญ่ไม่ระบุข้อจำกัดของตนเองอย่างชัดเจน ผู้เขียนวิทยานิพนธ์จึง **อนุมาน (inferred)** ข้อจำกัดจาก scope ของการทดสอบ, hardware platform, และวิธีการ validation ที่ระบุไว้ในแต่ละ paper เพื่อใช้ในการทำ Gap Analysis โดยจะระบุชัดเจนว่าข้อใดเป็น "ไม่ระบุในต้นฉบับ" และข้อใดเป็น "อนุมาน"

### 2.4.1 ตารางสรุปงานวิจัย (Comparative Summary Table)

| # | ผู้เขียน / ปี | วิธีการ | กรณีทดสอบ / Hardware | ผลลัพธ์หลัก | ข้อจำกัด (อนุมาน) |
|---|---|---|---|---|---|
| 1 | Chang & Nguyen, 2023 | Adaptive Inertia VSG + feedforward line-impedance power sharing | PSIM + 3-inverter parallel hardware, TMS320F28335 DSP | ปรับ H ได้ adaptive, แชร์โหลด multi-inverter ได้แม่นยำ | DSP ราคาสูง; ทดสอบในไมโครกริดเล็ก; ไม่ครอบคลุม FRT |
| 2 | Cherifi et al., 2022 | VSG control สำหรับ stand-alone inverter | PSIM sim + PIL บน TI F28335 DSP | PIL ผลตรงกับ sim | PIL เท่านั้น ไม่ใช่ full hardware; ไม่ทดสอบ grid-connected mode |
| 3 | Choi, Heo, Park, 2025 | Disturbance Observer (stationary-frame filter) แก้ ADC DC bias | HIL + grid-connected VSG hardware bench | ลด synchronous oscillation จาก ADC noise | scope แคบ (เฉพาะ DC bias); ไม่ครอบคลุม large-signal disturbance |
| 4 | Hirase et al., 2022 | Field demonstration: GFM VSG + diesel SG microgrid | 125 kVA diesel + 5×20 kVA BES inverters, field site | ยืนยัน technology readiness; สอดคล้องกับ IEEE Std 2988 | hardware ระดับอุตสาหกรรม ราคาสูง; topology เฉพาะ |
| 5 | Rathnayake, Razzaghi, Bahrani, 2022 | Generalized VSG (GVSG) — closed-form gain design, seamless mode transition | Frequency-response + step-response experiment | overshoot ↓, settling time ↓ vs conventional VSG | ใช้ linearization; ไม่แสดง robustness ต่อ parameter drift |
| 6 | Chen et al., 2018 | DAE-based VSG model + HIL validation | HIL measurement vs DAE model | ยืนยันความถูกต้องของ simple swing eq. | simple model; ไม่รวม full inner current loop |
| 7 | Zhang et al., 2018 | PV-VSG control + RT-LAB HIL | RT-LAB HIL platform, PV grid-connected inverter | PV-VSG จำลอง inertia ได้ + เพิ่ม system stability | HIL only; ไม่มี physical PV hardware; ไม่ทดสอบ MPPT interaction |
| 8 | Huang et al., 2025 | Model-Free Predictive Control (ARX/RLS) inner loop + simple VSG outer | Software sim + hardware experiment | robust ต่อ parameter uncertainty; pulse-duty dynamic ดีขึ้น | algorithm ซับซ้อน, computational cost สูง; ไม่เหมาะ low-cost MCU |
| 9 | Karapanos, de Haan, Zwetsloot, 2011 | P-HIL real-time simulation | FPGA real-time + 3-phase MOSFET inverter + filter | ตั้ง P-HIL methodology เป็นบรรทัดฐาน | งานเก่า (2011); MOSFET inverter ขนาดเล็ก ไม่ scale |
| 10 | Ibrahim, Rafin, Mohammed, 2025 | VSG vs Droop comparison, 2-inverter parallel | MATLAB/Simulink → OPAL-RT HIL + TI C2000 MCU | VSG ดีกว่า Droop ใน voltage/current quality, load sharing | HIL only; 2 inverters เท่านั้น; ไม่ทดสอบ fault |
| 11 | Uddin et al., 2024 | VSG สำหรับ Back-to-Back (B2B) inverter test bench | Lab bench: 2×3-phase inverter (GFM+GFL) + LCL filter | enable power circulation testing; LCL ลด harmonic | test bench setup, ไม่ใช่ field; LCL standard, no innovation |
| 12 | Wang, Liu, Shi, Liu, 2023 | Full theoretical+experimental comparison: Droop vs VSG (focus Q-V dynamics) | Software sim + GFM inverter hardware + math analysis | รากฐานทฤษฎีว่า VSG > Droop ทั้ง P-f และ Q-V | linearized analysis; ไม่ครอบคลุม large-signal/nonlinear |

---

### 2.4.2 สรุปงานวิจัยแต่ละชิ้น (Per-Paper Summary)

#### Paper 1 — Adaptive Inertia VSG with Even Power Sharing (Chang & Nguyen, 2023)
- **วิธีการ:** ออกแบบ VSG ที่สามารถปรับค่า virtual inertia $H$ ได้แบบ adaptive ตามสภาวะ disturbance ผสมกับกลไก feedforward ของ line impedance เพื่อให้การแบ่งโหลดระหว่างอินเวอร์เตอร์เท่ากัน
- **จุดเด่น:** ยืนยัน multi-inverter operation บน hardware DSP 3 ตัว แก้ deficiency ของ fixed-H VSG ที่ไม่สามารถปรับตัวได้
- **ข้อจำกัด (อนุมาน):** TMS320F28335 ราคาประมาณ 3,000 บาท/ตัว — scale-up cost สูง; การทดสอบจำกัดในไมโครกริดเล็ก; ไม่มี FRT scenario; ไม่ได้เปรียบเทียบกับ heterogeneous inverter
- **ความเกี่ยวข้อง:** Adaptive inertia เป็นทิศทางสำคัญ — โครงงานนี้สามารถต่อยอด adaptive scheme อย่างง่ายบน low-cost MCU

#### Paper 2 — Stand-Alone Inverter VSG Control (Cherifi et al., 2022)
- **วิธีการ:** ออกแบบ VSG สำหรับ stand-alone (islanded) inverter ทดสอบผ่าน Processor-in-the-Loop (PIL) บน TI F28335
- **จุดเด่น:** Proof-of-concept ของการ deploy VSG บน DSP จริง ใช้เป็น baseline ของ islanded mode
- **ข้อจำกัด (อนุมาน):** PIL เท่านั้น — ไม่ใช่ inverter hardware เต็ม ดังนั้น parasitic effect ของ PWM/dead-time/measurement noise ยังไม่ถูกพิสูจน์; ไม่ครอบคลุม grid-connected mode
- **ความเกี่ยวข้อง:** Reference สำหรับ Phase 1 (sim-only) ของโครงงาน — ใช้เป็น benchmark ก่อนต่อ hardware

#### Paper 3 — Disturbance Observer for DC Bias Rejection (Choi, Heo, Park, 2025)
- **วิธีการ:** ใช้ disturbance observer แบบ stationary-frame filter แทน Extended State Observer (ESO) เพื่อกำจัด DC bias ที่หลุดจาก ADC ของ measurement
- **จุดเด่น:** แก้ปัญหาเฉพาะที่เกิดบ่อยใน VSG hardware จริง (synchronous oscillation จาก ADC noise) — งานวิจัย simulation มักมองข้าม
- **ข้อจำกัด (อนุมาน):** ขอบเขตแคบ — แก้แค่ DC bias ไม่ครอบคลุม disturbance อื่น เช่น harmonic distortion, frequency drift, sensor offset
- **ความเกี่ยวข้อง:** **สำคัญต่อ Phase 2 ของโครงงาน** เนื่องจาก ESP32 ADC มี DC bias และ INL/DNL เด่นชัด — pattern แก้ปัญหานี้นำมาประยุกต์ใช้ได้

#### Paper 4 — Field Demo: VSG + Diesel SG Microgrid (Hirase et al., 2022)
- **วิธีการ:** Field deployment ของระบบไมโครกริด: diesel SG 125 kVA + BES-inverter VSG 5 ชุด ชุดละ 20 kVA
- **จุดเด่น:** หลักฐานยืนยัน VSG พร้อมใช้งานจริงในสนาม (technology readiness level สูง) สอดคล้องกับการพัฒนา IEEE Std 2988
- **ข้อจำกัด (อนุมาน):** ระดับอุตสาหกรรม; hardware ราคาแพง; topology เฉพาะ (diesel + multiple BES); ไม่ replicate ใน lab/นิสิตได้
- **ความเกี่ยวข้อง:** Reference สำหรับ Chapter 5 (Discussion) — แสดงว่า scale-up จาก lab prototype ไป field deployment เป็นไปได้

#### Paper 5 — Generalized VSG (Rathnayake, Razzaghi, Bahrani, 2022)
- **วิธีการ:** Generalized VSG (GVSG) สำหรับ GFM ที่เปลี่ยน mode (grid-connected ↔ stand-alone) ได้ smooth พร้อม closed-form gain design
- **จุดเด่น:** Closed-form design ทำให้ engineer คำนวณ gain ได้โดยไม่ต้อง trial-and-error; overshoot และ settling time ดีกว่า conventional VSG
- **ข้อจำกัด (อนุมาน):** Linearization assumption — robustness ต่อ parameter drift และ large-signal disturbance อาจลดลง
- **ความเกี่ยวข้อง:** Reference สำหรับ gain tuning ใน Chapter 3 (Design)

#### Paper 6 — DAE-Based VSG + HIL Validation (Chen et al., 2018)
- **วิธีการ:** สร้างแบบจำลอง Differential-Algebraic Equation (DAE) ของ VSG เปรียบเทียบกับการควบคุม Droop ยืนยันด้วย HIL
- **จุดเด่น:** Methodology benchmark sim vs. hardware ที่เป็นระบบ
- **ข้อจำกัด (อนุมาน):** Model อย่างง่าย ไม่ครอบคลุม inner current loop เต็มรูปแบบ — benchmark ได้แค่ outer dynamics (P-ω)
- **ความเกี่ยวข้อง:** Phase 1 (MATLAB simulation) ของโครงงานสามารถ adopt approach DAE สำหรับ validate Simulink model

#### Paper 7 — PV-VSG via RT-LAB HIL (Zhang et al., 2018)
- **วิธีการ:** ทดสอบ PV inverter ที่ใช้ VSG control ผ่าน RT-LAB HIL
- **จุดเด่น:** แสดงว่า PV inverter สามารถ provide virtual inertia ได้เหมือน SG เพิ่ม system stability
- **ข้อจำกัด (อนุมาน):** HIL อย่างเดียว ไม่มี physical PV hardware; ไม่ทดสอบ MPPT interaction กับ VSG ภายใต้ partial shading; ไม่ครอบคลุม DC-link dynamics เต็มรูปแบบ
- **ความเกี่ยวข้อง:** ไม่ตรงกับ scope ของโครงงาน (โครงงานไม่ใช่ PV-specific) แต่ยืนยันว่า VSG เป็น domain-agnostic

#### Paper 8 — Model-Free Predictive Control + VSG (Huang et al., 2025)
- **วิธีการ:** ใช้ Model-Free Predictive Control (RLS-based ARX) สำหรับ inner loop ผสมกับ simple VSG outer loop
- **จุดเด่น:** Robust ต่อ parameter uncertainty; pulse-duty dynamic characteristics ดีขึ้น
- **ข้อจำกัด (อนุมาน):** Algorithm ซับซ้อน ต้องการ computational power สูง — ไม่เหมาะ low-cost MCU เช่น ESP32
- **ความเกี่ยวข้อง:** ไม่ตรงกับ Phase 2 (low-cost hardware) แต่แสดง state-of-the-art ของ inner loop design — flag ไว้เป็น future direction

#### Paper 9 — P-HIL Real-Time Simulation (Karapanos et al., 2011)
- **วิธีการ:** Power Hardware-in-the-Loop (P-HIL) ผ่าน FPGA real-time simulator + 3-phase MOSFET inverter ตัวจริง
- **จุดเด่น:** งาน foundational ที่ตั้ง P-HIL methodology สำหรับ VSG เป็นบรรทัดฐาน
- **ข้อจำกัด (อนุมาน):** งานเก่า (2011); MOSFET inverter ขนาดเล็ก ไม่ scale ถึง utility level; technology FPGA สมัยนั้น expensive
- **ความเกี่ยวข้อง:** Historical reference + methodology baseline สำหรับ Phase 3 (hardware testing) ของโครงงาน

#### Paper 10 — VSG vs Droop on OPAL-RT HIL (Ibrahim et al., 2025)
- **วิธีการ:** จำลองอินเวอร์เตอร์ 2 ตัวขนานกันใน MATLAB/Simulink → deploy บน OPAL-RT HIL ร่วมกับ TI C2000
- **จุดเด่น:** Comparison ละเอียดของ VSG vs Droop ในแง่ voltage/current quality, load sharing
- **ข้อจำกัด (อนุมาน):** HIL only ไม่ใช่ physical inverter; 2 inverters เท่านั้น ไม่ scale; ไม่ทดสอบ fault scenarios
- **ความเกี่ยวข้อง:** **สำคัญ** — workflow คล้ายโครงงาน (MATLAB → HIL → hardware) ใช้เป็น reference ของ comparison metrics

#### Paper 11 — VSG for Back-to-Back Inverter Test Bench (Uddin et al., 2024)
- **วิธีการ:** ใช้ VSG บน test bench ที่อินเวอร์เตอร์ 2 ตัวต่อ back-to-back สำหรับ power-circulation testing
- **จุดเด่น:** Regenerative testing ประหยัดพลังงานในการทดสอบต่อเนื่อง; LCL filter ลด harmonic
- **ข้อจำกัด (อนุมาน):** Test bench setup ไม่ใช่ field deployment; LCL filter เป็น standard ไม่ใช่ innovation; B2B ไม่สะท้อน weak grid scenario
- **ความเกี่ยวข้อง:** B2B testing methodology น่าสนใจสำหรับ Phase 3 — ประหยัดพลังงานในการทดสอบยาว

#### Paper 12 — Full Comparison: Droop vs VSG with Q-V Dynamics (Wang et al., 2023)
- **วิธีการ:** Theoretical + experimental comparison ของ Droop และ VSG focus ที่ P-f และ Q-V dynamics ทั้ง stand-alone และ grid-connected
- **จุดเด่น:** ให้พื้นฐานทฤษฎีอย่างสมบูรณ์ว่า VSG เหนือกว่า Droop ในทั้งสองมิติ
- **ข้อจำกัด (อนุมาน):** Linearized analysis เป็นหลัก ไม่ครอบคลุม large-signal/nonlinear behavior
- **ความเกี่ยวข้อง:** Reference สำคัญสำหรับ Chapter 2 และ Chapter 5 — รากฐานทฤษฎีในการเลือก VSG เหนือ Droop

---

### 2.4.3 การวิเคราะห์ช่องว่างทางวิจัย (Gap Analysis)

จากการทบทวนงานวิจัย 12 ชิ้นข้างต้น สามารถระบุรูปแบบ (pattern) และช่องว่างที่ปรากฏซ้ำ ๆ ได้ดังนี้

#### Gap 1: Hardware Platform — DSP ราคาสูงครอบงำ literature

- **ข้อเท็จจริง:** ทุก paper ที่ระบุ MCU/DSP ใช้ TI TMS320F28335 หรือ TI C2000 family (~3,000–5,000 บาท/ตัว) หรือ FPGA-class hardware; **ไม่มี paper ใดใน 12 ชิ้นนี้ใช้ low-cost platform เช่น ESP32 (~150–300 บาท) หรือ STM32F1/F4 ระดับล่าง**
- **เหตุผลทางเทคนิค:** VSG ต้องการ fast inner current loop (1–10 kHz bandwidth) + floating-point math + ADC ความเร็วสูงพร้อม sync กับ PWM — TI C2000 ออกแบบมาเฉพาะงานนี้ (มี HRPWM, ADC trigger-on-PWM, hardware EPWM)
- **โอกาส:** ESP32-S3 มี FPU, dual-core 240 MHz, ADC 12-bit ในตัว, ราคาถูกหลายเท่า — มีศักยภาพแต่ยังไม่ถูกพิสูจน์ในวรรณกรรม VSG
- **ทิศทางที่โครงงานนี้จะเติม:** Demonstrating feasibility ของ ESP32 สำหรับ VSG **outer loop** (P-ω, Q-V) โดยอาจ delegate inner current loop ให้ analog circuit หรือลด switching frequency ลงในระดับที่ ESP32 รับได้ (~2–5 kHz)

#### Gap 2: Validation Chain Discontinuity

- **ข้อเท็จจริง:** Papers ส่วนใหญ่จบที่ขั้นใดขั้นหนึ่ง:
  - Pure simulation/DAE only: 1 paper (Paper 6 จะ pair กับ HIL)
  - Simulation + PIL: 1 paper (Paper 2)
  - HIL only: 4 papers (Papers 6, 7, 10 + part of 9)
  - Hardware bench / Field: 5 papers (Papers 1, 3, 4, 8, 11, 12)
- **ช่องว่าง:** **ไม่มี paper ใดที่นำเสนอ full chain** ตั้งแต่ MATLAB → HIL → physical prototype พร้อมเปรียบเทียบ output ของแต่ละขั้นในระบบเดียวกัน
- **ทิศทางที่โครงงานนี้จะเติม:** เนื่องจาก roadmap ของโครงงานคือ MATLAB Phase 1 → HIL Phase 2 → physical prototype Phase 3 การแสดง **consistency** ของ swing equation behavior ตลอด pipeline จะเป็น contribution ที่ฟิตกับ educational/research context

#### Gap 3: Fault Ride-Through (FRT) Underexplored

- **ข้อเท็จจริง:** ในงานวิจัย 12 ชิ้น **ไม่มีการทดสอบ LVRT/HVRT ตามมาตรฐาน IEEE 1547-2018 อย่างเป็นระบบ**; Paper 4 (Hirase et al., 2022) กล่าวถึง IEEE Std 2988 แต่ไม่ลงรายละเอียด FRT testing
- **เหตุผล:** FRT ต้องการ current limiter ที่ออกแบบดี + fault detection logic — เป็นโจทย์ engineering ยุ่งยากที่ส่วนใหญ่ skip
- **ทิศทางที่โครงงานนี้จะเติม:** ถ้ายังไม่อยู่ใน Phase 1 อาจวาง roadmap ให้ Phase 3 หรือ future work รวม simple LVRT scenario (voltage sag 0.5 pu, 150 ms) ตาม IEEE 1547-2018 Cat. III

#### Gap 4: Adaptive vs Fixed Parameters

- **ข้อเท็จจริง:** Paper 1 (2023) เป็น paper เดียวที่นำเสนอ **adaptive inertia**; ส่วนที่เหลือใช้ fixed $H$, $D$ ที่ตั้งค่าครั้งเดียว
- **เหตุผล:** Fixed parameters ง่ายต่อการ analysis แต่ไม่ optimal สำหรับ operating conditions ที่หลากหลาย (load light vs heavy, grid stiff vs weak)
- **ทิศทางที่โครงงานนี้จะเติม:** ถ้าโครงงานเริ่มจาก fixed parameters ใน Phase 1 อาจเสนอ adaptive scheme อย่างง่าย (lookup table หรือ rule-based) ใน Phase 2

#### Gap 5: Multi-VSG Interaction

- **ข้อเท็จจริง:** Paper 1 (3 inverters parallel), Paper 4 (5 BES inverters + diesel), Paper 10 (2 inverters parallel) เป็นเพียง 3 paper ที่ทดสอบ multi-VSG; ส่วนที่เหลือเป็น single-VSG หรือ VSG+SG
- **ช่องว่าง:** การศึกษา interaction ระหว่าง VSG หลายตัวที่มี parameter **ต่างกัน** (heterogeneous VSG) ยังจำกัด — Paper 1 และ 10 ใช้ identical inverters
- **ทิศทางที่โครงงานนี้จะเติม:** Multi-VSG อาจ out-of-scope สำหรับ Phase 1 — ระบุเป็น future work / Chapter 5 (Discussion)

#### Gap 6: Limited Q-V Dynamic Analysis

- **ข้อเท็จจริง:** Papers ส่วนใหญ่ focus ที่ P-f dynamics; Paper 12 (Wang et al., 2023) เป็น paper เดียวที่ให้น้ำหนักเท่ากันกับ Q-V dynamics
- **ทิศทางที่โครงงานนี้จะเติม:** ใน implementation ควรให้ Q-V loop เป็นส่วนสำคัญ ไม่ใช่ afterthought; ใช้ dynamic Q-V (excitation emulation) แทน static Q-V droop ตามที่เสนอใน Section 2.3.3

---

### 2.4.4 สรุปช่องว่างที่โครงงานนี้จะเติม (Specific Contributions of This Thesis)

จาก Gap Analysis ข้างต้น โครงงานนี้มีศักยภาพในการมีส่วนร่วม (contribution) ในประเด็นต่อไปนี้

1. **Cost-effective VSG implementation บน low-cost MCU** — เติม **Gap 1** โดย demonstrate feasibility ของ ESP32 (หรือ MCU ราคาใกล้เคียง) สำหรับ VSG outer loop ซึ่งเป็น gap หลักของ literature ที่ใช้ TI C2000/FPGA
2. **End-to-end validation pipeline (MATLAB → HIL → physical)** — เติม **Gap 2** โดยแสดง consistency ของ VSG behavior ตลอด development chain
3. **Educational reproducibility** — Hardware และ source code ที่ accessible สำหรับ undergrad engineering สามารถ replicate ได้ในงบประมาณนิสิต — bridge ระหว่าง academic research กับ educational outreach

> **หมายเหตุ:** Gap 3 (FRT), Gap 4 (adaptive), Gap 5 (multi-VSG), Gap 6 (Q-V dynamics) สามารถ scope เป็น future work หรือ Phase 4 ของโครงงานได้ — ขึ้นกับเวลาและทรัพยากร

---

## 2.5 มาตรฐานและข้อกำหนดกริด
### (Grid Codes and Interconnection Standards)

### 2.5.1 IEEE Std 1547-2018 — Standard for Interconnection and Interoperability of Distributed Energy Resources (DER)

มาตรฐาน IEEE 1547-2018 เป็นมาตรฐานสากลที่กำหนดข้อกำหนดทางเทคนิคสำหรับการเชื่อมต่อ Distributed Energy Resources (รวมถึงอินเวอร์เตอร์) เข้ากับ Electric Power System (EPS) มีการ revise ครั้งใหญ่จากฉบับปี 2003 โดยเพิ่มข้อกำหนดที่สำคัญต่อ VSG/GFM ดังนี้

**Performance Categories (Category I, II, III):**
- **Category I** — minimum capability สำหรับระบบที่มี DER สัดส่วนต่ำ
- **Category II** — สำหรับ bulk system stability
- **Category III** — สำหรับระบบที่ต้องการ ride-through และ ancillary support ระดับสูง

**Frequency / Voltage Ride-Through (FRT/VRT):**
- DER ต้องทำงานต่อเนื่องผ่าน frequency event ในช่วง 57.0–61.2 Hz (Cat. III)
- ต้องรับมือ voltage dip ลึกถึง 0 pu เป็นเวลา 0.16 s (LVRT) และแรงดันเกินถึง 1.20 pu เป็นเวลาที่กำหนด (HVRT)

**Frequency Response (Frequency-Watt):**
- กำหนดให้ DER ต้องลด active power เมื่อ over-frequency และเพิ่มเมื่อ under-frequency
- Droop range: 0.02–0.10 (2–10%) เริ่ม respond ที่ deadband 0.036 Hz (Cat. III)

**Voltage Regulation (Volt-VAR / Volt-Watt):**
- DER ต้องสามารถจ่ายและดูดซับ reactive power ตาม Q-V characteristic ที่กำหนด

> **หมายเหตุ:** IEEE 1547 ไม่ระบุว่าต้องเป็น GFL หรือ GFM แต่ Cat. III ต้องการสมรรถนะที่ GFM/VSG ทำได้ดีกว่า GFL อย่างชัดเจน [IEEE Std 1547-2018]

### 2.5.2 ข้อกำหนด RoCoF ที่ยอมรับได้

Rate of Change of Frequency (RoCoF) เป็นพารามิเตอร์สำคัญในการประเมินผลกระทบของ low-inertia system มาตรฐานในระดับสากลกำหนดดังนี้

| ภูมิภาค / Grid Operator | RoCoF limit |
|---|---|
| ENTSO-E (Continental Europe) | 1.0 Hz/s |
| UK National Grid | 1.0 Hz/s (เดิม 0.125 Hz/s) |
| Ireland EirGrid | 1.0 Hz/s |
| Australia AEMO | 1.0–2.0 Hz/s (ขึ้นกับ region) |
| IEEE 1547-2018 (Cat. III) | ride-through 3.0 Hz/s |

VSG ช่วยลด RoCoF ของระบบโดยการ inject inertial power ทันทีที่ disturbance เกิด ทำให้ system รักษา RoCoF ให้อยู่ในเกณฑ์ของ grid code

### 2.5.3 Fault Ride-Through (FRT) Requirements

**Low Voltage Ride-Through (LVRT):**
- เมื่อแรงดันที่จุดเชื่อมต่อ (Point of Connection, POC) ลดลงต่ำกว่า nominal อินเวอร์เตอร์ต้องไม่ disconnect และต้อง inject reactive current เพื่อช่วยพยุงแรงดัน
- Reactive current ที่กำหนด: $I_q \geq k \cdot (\Delta V / V_n)$ โดย $k = 2.0$ pu/pu สำหรับ German Grid Code

**High Voltage Ride-Through (HVRT):**
- เมื่อแรงดันสูงขึ้นชั่วคราว (เช่น load rejection) อินเวอร์เตอร์ต้อง absorb reactive power

**LVRT/HVRT envelope:** กำหนดเป็น V-t curve ที่อินเวอร์เตอร์ต้อง remain connected (ดู IEEE 1547-2018 Figure H.5, H.6)

### 2.5.4 Grid Code ของประเทศไทย

ระบบไฟฟ้าในประเทศไทยกำกับดูแลโดยสามหน่วยงานหลัก
- **EGAT** (การไฟฟ้าฝ่ายผลิตแห่งประเทศไทย) — transmission
- **PEA** (การไฟฟ้าส่วนภูมิภาค) — distribution ต่างจังหวัด
- **MEA** (การไฟฟ้านครหลวง) — distribution กรุงเทพและปริมณฑล

**ข้อกำหนดการเชื่อมต่อ Solar PV (ปัจจุบัน):**
- กลุ่มผู้ผลิตไฟขนาดเล็กมาก (VSPP): กำลังไม่เกิน 10 MW
- ต้องผ่านการรับรองมาตรฐาน IEC 61727 หรือ IEEE 1547
- ต้อง implement Anti-Islanding Protection ตาม IEEE 1547 / IEC 62116

> ⚠️ **หมายเหตุสำคัญ:** ข้อกำหนด Grid Code ของไทยมีการ revise อย่างต่อเนื่อง ผู้เขียนแนะนำให้ตรวจสอบเอกสารฉบับล่าสุดจาก:
> - "ข้อกำหนดการเชื่อมต่อระบบโครงข่ายไฟฟ้า" ของ PEA (ฉบับล่าสุด: www.pea.co.th)
> - "Grid Code" ของ MEA สำหรับผู้ผลิตไฟขนาดเล็กในเขตกรุงเทพฯ
> - ระเบียบของ กกพ. (คณะกรรมการกำกับกิจการพลังงาน) ที่เกี่ยวกับการเชื่อมต่อ DER
>
> ผมจะไม่ยืนยันตัวเลขเฉพาะ (เช่น LVRT envelope ของไทย) ในที่นี้ เพราะอาจมีการเปลี่ยนแปลง และผมไม่ได้เข้าถึงเอกสาร grid code ฉบับจริง

### 2.5.5 สรุปข้อกำหนดที่เกี่ยวข้องกับ VSG โดยตรง

| ข้อกำหนด | ค่ามาตรฐาน | ผลต่อ VSG design |
|---|---|---|
| RoCoF withstand | ≥ 1.0 Hz/s (Cat. III: 3.0 Hz/s) | กำหนด minimum virtual inertia $H$ |
| Frequency droop | 4–5% | กำหนด $m_p$ ใน VSG controller |
| LVRT depth | ≥ 0.0 pu @ 150 ms | ต้องมี current limiter ที่ทนได้ |
| Reactive current support | $k \geq 2.0$ pu/pu | กำหนด Q–V loop gain |
| Anti-islanding | IEEE 1547 / IEC 62116 | grid-connected mode detection |

---

## เอกสารอ้างอิง (References)

### Foundational Works (ที่อ้างใน Section 2.1, 2.2, 2.3)
- Beck, H.-P., & Hesse, R. (2007). *Virtual synchronous machine*. 9th International Conference on Electrical Power Quality and Utilisation (EPQU).
- Zhong, Q.-C., & Weiss, G. (2011). *Synchronverters: Inverters that mimic synchronous generators*. IEEE Transactions on Industrial Electronics, 58(4), 1259–1267.
- Rocabert, J., Luna, A., Blaabjerg, F., & Rodríguez, P. (2012). *Control of power converters in AC microgrids*. IEEE Transactions on Power Electronics, 27(11), 4734–4749.
- Driesen, J., & Visscher, K. (2008). *Virtual synchronous generators*. IEEE PES General Meeting.
- D'Arco, S., & Suul, J. A. (2014). *Equivalence of virtual synchronous machines and frequency-droops for converter-based microgrids*. IEEE Transactions on Smart Grid, 5(1), 394–395.
- Bevrani, H., Ise, T., & Miura, Y. (2014). *Virtual synchronous generators: A survey and new perspectives*. International Journal of Electrical Power & Energy Systems, 54, 244–254.
- Tayyebi, A., Groß, D., Anta, A., Kupzog, F., & Dörfler, F. (2020). *Frequency stability of synchronous machines and grid-forming power converters*. IEEE Journal of Emerging and Selected Topics in Power Electronics, 8(2), 1004–1018.
- Alipoor, J., Miura, Y., & Ise, T. (2015). *Power system stabilization using virtual synchronous generator with alternating moment of inertia*. IEEE Journal of Emerging and Selected Topics in Power Electronics, 3(2), 451–458.
- Lasseter, R. H., Chen, Z., & Pattabiraman, D. (2020). *Grid-forming inverters: A critical asset for the power grid*. IEEE Journal of Emerging and Selected Topics in Power Electronics, 8(2), 925–935.

### Reviewed Papers (Section 2.4)

1. Chang, G. W., & Nguyen, K. T. (2023). *A New Adaptive Inertia-Based Virtual Synchronous Generator with Even Inverter Output Power Sharing in Islanded Microgrid*. **IEEE Transactions on Industrial Electronics**, vol. 71, no. 9, pp. 10693–10703. DOI: [10.1109/TIE.2023.3327515](https://doi.org/10.1109/TIE.2023.3327515) (IEEE Xplore #10329423)

2. Cherifi, A., Chouder, A., Kessal, A., Hadjkkadour, A., Aillane, A., & Louassaa, K. (2022). *Control of Stand-Alone Inverter using Virtual Synchronous Generator*. **2022 2nd International Conference of Advanced Technology in Electronic and Electrical Engineering (ICATEEE)**, M'sila, Algeria, 26–27 Nov 2022. DOI: [10.1109/ICATEEE57445.2022.10093091](https://doi.org/10.1109/ICATEEE57445.2022.10093091) (IEEE Xplore #10093091)
   > ⚠️ **Verify spelling:** "Hadjkkadour" จาก Semantic Scholar metadata — อาจเป็น "Hadjkaddour" ตรวจสอบกับ PDF first page

3. Choi, S., Heo, G.-S., & Park, Y. (2025). *Utilization of a Disturbance Observer for Enhancing Robustness Against DC Biases in a Virtual Synchronous Generator*.

4. Hirase, Y., et al. (2022). *Field Demonstration of Parallel Operation of Virtual Synchronous Controlled Grid-Forming Inverters and a Diesel Synchronous Generator in a Microgrid*.

5. Rathnayake, D., Razzaghi, R., & Bahrani, B. (2022). *Generalized Virtual Synchronous Generator Control Design for Renewable Power Systems*.

6. Chen, J., Liu, M., O'Loughlin, C., Milano, F., & O'Donnell, T. (2018). *Modelling, Simulation and Hardware-in-the-Loop Validation of Virtual Synchronous Generator Control in Low Inertia Power System*. **2018 Power Systems Computation Conference (PSCC)**, Dublin, Ireland, 11–15 June 2018, pp. 1–7. DOI: [10.23919/PSCC.2018.8442998](https://doi.org/10.23919/PSCC.2018.8442998) (IEEE Xplore #8442998)

7. Zhang, X., Dong, W., Gan, J., & Yao, G. (2018). *Hardware in Loop Simulation Test of Photovoltaic Virtual Synchronous Generator*. **2018 2nd IEEE Conference on Energy Internet and Energy System Integration (EI2)**, Beijing, China, 20–22 Oct 2018, pp. 1–6. DOI: [10.1109/EI2.2018.8582262](https://doi.org/10.1109/EI2.2018.8582262) (IEEE Xplore #8582262)
   > ⚠️ **Verify given names:** Surname + initial ยืนยันแล้ว แต่ given name เต็ม ๆ ควรตรวจสอบจาก PDF first page

8. Huang, M., Zhang, H., Wang, K., Yao, Z., & Wu, W. (2025). *Model-Free Predictive Control Based on RLS Algorithm for Grid-Forming Inverters With Virtual Synchronous Generator*.

9. Karapanos, V., de Haan, S. W. H., & Zwetsloot, K. H. (2011). *Real time simulation of a power system with VSG hardware in the loop*.

10. Ibrahim, A. M., Rafin, S. M. S. H., & Mohammed, O. A. (2025). *Evaluation of Virtual Synchronous Generator and Droop Control in Microgrids Using Real-Time Hardware-in-the-Loop for Inverter-Based Resources*.

11. Uddin, S. M. M., Heidari, R., Braslavsky, J., & Mohy-Ud-Din, G. (2024). *Modelling and Design of Virtual Synchronous Generator Control for Back-to-Back Inverter Testing in Renewable Energy Systems*. **2024 IEEE 34th Australasian Universities Power Engineering Conference (AUPEC)**, Sydney, Australia, Nov 2024. DOI: [10.1109/AUPEC62273.2024.10807621](https://doi.org/10.1109/AUPEC62273.2024.10807621) (IEEE Xplore #10807621)

12. Wang, J., Liu, Z., Shi, Y., & Liu, J. (2023). *A Full Comparison between Droop Control and Virtual Synchronous Generator Control Considering Reactive Power Dynamics in Grid-Forming Inverters*.

### Standards
- IEEE Std 1547-2018. *Standard for Interconnection and Interoperability of Distributed Energy Resources with Associated Electric Power Systems Interfaces*.
- IEEE Std 2988 (under development). *Recommended Practice for Virtual Synchronous Generators (VSG) Connected to AC Grid*.
- IEC 61727. *Photovoltaic (PV) systems – Characteristics of the utility interface*.
- IEC 62116. *Utility-interconnected photovoltaic inverters – Test procedure of islanding prevention measures*.

> ⚠️ **Action required (สำหรับ final submission):**
> 1. **Paper 2 (Cherifi et al., 2022):** ตรวจสอบการสะกด "Hadjkkadour" กับ PDF first page (อาจเป็น "Hadjkaddour")
> 2. **Paper 7 (Zhang et al., 2018):** ยืนยัน given name เต็มของผู้แต่งทั้ง 4 คน (X. Zhang, W. Dong, J. Gan, G. Yao) จาก PDF first page
> 3. **IEEE Std 2988:** ตรวจสอบสถานะ ณ ปัจจุบัน (under development หรือ finalized แล้ว) ก่อนอ้างใน Section 2.4.2 (Paper 4) และ Section 2.5

---

*— End of Chapter 2 Draft v1 —*
