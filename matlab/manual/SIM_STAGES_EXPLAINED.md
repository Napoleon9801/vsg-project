# VSG Simulation — อธิบายทุก Stage (1 → 5d): ทำอะไร ทำไม ได้อะไร

> เอกสารสรุปสำหรับทบทวน/อธิบายอาจารย์ — อ้างอิงจาก script จริงใน
> `D:\workspace\engineering\vsg-project\matlab\` (สถานะ ณ 2026-07-15)
>
> **แนวคิดรวมของทั้ง chain:** สร้าง VSG ทีละชั้น (incremental build) —
> แต่ละ stage เพิ่มความจริงเข้าไป 1 ชั้น แล้วพิสูจน์ว่าชั้นใหม่ทำงานถูก
> ก่อนไปชั้นถัดไป ปลายทางคือ controller ที่ discrete เหมือน firmware ESP32
> ทุกประการ เพื่อให้มั่นใจก่อนจ่ายไฟจริงว่า "ถ้า sim ไม่พัง บอร์ดก็ไม่ควรพัง"

---

## ภาพรวม chain

| Stage | Script | เพิ่มอะไร | โหมด | ผลหลัก |
|---|---|---|---|---|
| 1 | `phase1_swing_equation.m` | Swing equation เพียว | — | Δω_ss = ΔP/D ✓ |
| 2 | `phase2_power_angle.m` | Pe = Pmax·sin δ | Grid-connected | swing 2nd-order, δ 28.4°→31.6° |
| 3 | `phase3_droop_control.m` | P-f droop (governor) | **Islanded** | f_ss = 49.75 Hz ตรง −R_p·ΔP |
| 4 | `phase4_inverter_dq.m` | Inverter เฉลี่ย + LC + V/I PI + Q-V droop (dq) | Islanded | Δf = −0.7 Hz ตามคาด |
| 5a | `phase5a_switching_abc.m` | abc จริง + SPWM 10 kHz + bridge สวิตช์ | Islanded | ควบคุมผ่านชั้น switching ได้ |
| 5b | `phase5b_hd_sweep.m` | กวาด H×D 30 เคส | Islanded | เลือก H=5, D=0.5 |
| 5c | `phase5c_tuned.m` | R_d damping + dq decoupling FF | Islanded | f_ss 49.89 Hz, ringing หาย |
| 5d | `phase5d_discrete.m` | controller เป็น discrete เหมือน firmware | Islanded | **PASS — gain ปลอดภัยขึ้น bench** |

ฐานระบบทุก stage: S_base = 100 VA, f_base = 50 Hz (V_dc เริ่ม 24 V → ล็อกที่ **40 V** ตั้งแต่ 2026-05-30)

ทุก script ทำงานแบบเดียวกัน: **สร้างโมเดล .slx อัตโนมัติ → รัน → เซฟผลเป็น .mat**
แล้ว Python (`python/`) เอาไปวาดรูปสำหรับ Chapter 4

---

## Stage 1 — Pure Swing Equation

**คำถามที่ตอบ:** integrator core ของ VSG (สมการ swing) ให้ผลตอบสนอง H/D
ตรงทฤษฎีไหม

**สมการ:**
```
(2H/ω_s)·dω/dt = Pm − Pe − D·(ω − ω_s)
dδ/dt          = ω − ω_s
```

**Setup:** H = 5 s, D = 10, Pe = ค่าคงที่ 1.0 pu, step Pm 1.0 → 1.1 pu ที่ t = 1 s, T_sim = 10 s

**สิ่งที่เกิด:** ระบบเป็น first-order ใน ω (ไม่มี oscillation) —
ΔP ส่วนเกินถูกดูดโดยเทอม damping อย่างเดียว:

- Δω_ss = ΔP/D = 0.1/10 = 0.01 rad/s → f_ss = 50.0016 Hz ✓
- δ ไต่เป็น **ramp ไม่ลู่เข้า** — ไม่ใช่บั๊ก แต่เป็นการชี้ปัญหา:
  ไม่มี restoring torque เพราะ Pe ไม่ขึ้นกับ δ → เป็นเหตุผลของ Stage 2

**บทเรียน:** โครง swing eq + การต่อ integrator ถูกต้อง แต่ระบบเปิด loop
ทาง δ ยังใช้งานจริงไม่ได้

---

## Stage 2 — Power-Angle Feedback (Grid-Connected SG)

**คำถามที่ตอบ:** ปิด loop ด้วยความสัมพันธ์ power-angle แล้วได้ swing dynamics
แบบเครื่อง synchronous จริงไหม

**สิ่งที่เปลี่ยน:** แทน Pe คงที่ด้วย
```
Pe(δ) = (E·V/X)·sin δ = Pmax·sin δ        (E=1.05, V=1, X=0.5 → Pmax = 2.1 pu)
```
และลด D จาก 10 → **0.3** (D=10 ให้ ζ≈4.1 overdamped จนมองไม่เห็น swing;
0.3 ให้ ζ≈0.62 และใกล้ระดับจริงของ prototype 100 VA)

**ทฤษฎีที่ตรวจ:** linearise รอบจุดสมดุล →
```
ω_n = √(Pmax·cos δ_eq / (2H/ω_s)) ≈ 7.62 rad/s   (f_d ≈ 1.21 Hz)
ζ   ≈ 0.62
```

**สิ่งที่เกิด:** step Pm +0.1 pu → δ สวิงจาก 28.44° overshoot แล้วลู่เข้า
31.59° (~3 ลูกคลื่น คาบ ~0.83 s) ส่วน ω กลับมาที่ 50 Hz **พอดี** —
คราวนี้ δ เป็นตัวรับ ΔP แทนความถี่

**บทเรียน:** เมื่อ grid-connected ความถี่คืนสู่ synchronous เสมอ
พลังงานส่วนเกินไปอยู่ที่มุม δ — นี่คือพฤติกรรม SG ที่ VSG ต้องเลียนแบบ

**gotcha สำคัญ:** IC ของ Int_delta ต้องเริ่มที่ δ_eq = asin(Pm/Pmax)
ไม่งั้น Pe(0) = 0 ระบบวิ่งหนีตั้งแต่ก่อน step

---

## Stage 3 — Islanded + P-f Droop (นี่คือ loop ที่ลง ESP32)

**คำถามที่ตอบ:** ตอน islanded (ไม่มี grid ให้พิง) VSG แบ่ง/รับโหลดด้วย droop
ได้ตรงตำรา IEEE ไหม

**สิ่งที่เปลี่ยน:**
- **เอา Pe = Pmax·sin δ ออก** — islanded ไม่มี infinite bus ให้ sync ด้วย
  Pe กลายเป็นโหลดจริง P_load (step ได้)
- เพิ่ม **P-f droop** (เลียน governor ของโรงไฟฟ้า):
  ```
  Pm = P_set + (1/(R_p·ω_s))·(ω_s − ω)      R_p = 0.05 (droop 5%)
  ```
- D = 0 ชั่วคราว เพื่อให้ผลตรงสูตรตำรา Δf = −R_p·ΔP เป๊ะ (Stage 4-5 ค่อยใส่คืน)

**สิ่งที่เกิด:** โหลด step +0.1 pu ที่ t = 1 s →
- Δf_ss = −R_p·ΔP·f_base = −0.05·0.1·50 = **−0.25 Hz → f_ss = 49.75 Hz** ✓
- dynamics เป็น first-order, τ = (2H/ω_s)/(1/(R_p·ω_s)) = 0.50 s ✓

**บทเรียน:** ตอน islanded ความถี่ **ไม่กลับ** 50 Hz — มันจงใจค้าง offset
ไว้เป็น "สัญญาณบอกโหลด" ให้เครื่องอื่นแบ่งกำลังกัน นี่คือ primary
frequency response และคือ control loop แกนหลักที่ port ลง firmware

---

## Stage 4 — ชั้นไฟฟ้าเต็มรูปแบบใน dq (Average Model)

**คำถามที่ตอบ:** เอา swing + droop ไปคุม **วงจรจริง** (inverter + LC filter +
โหลด) ผ่าน cascaded control ได้ไหม — ยังไม่มี PWM (นั่นคือ Stage 5)

**สิ่งที่เพิ่ม (ทั้งหมดในเฟรม dq ที่หมุนตาม ω ของ VSG เอง):**
- Plant: inverter ในอุดมคติ (แหล่งจ่ายแรงดันตามคำสั่ง) → L_f 1.2 mH /
  C_f 10 µF (f_res ≈ 1.45 kHz) → โหลด RL (R 1.91 Ω, L 1 mH ≈ 100 W)
- **Cascaded V-I control:** voltage loop PI (BW ~100 Hz) ครอบ current loop
  PI (BW ~1 kHz) — แยก bandwidth ห่างกัน 10 เท่า ตามตำรา
- **Q-V droop:** V_d_ref = V_set − R_q·(Q_meas − Q_set) — ฝั่งแรงดันคู่กับ
  P-f droop ฝั่งความถี่
- Outer loop = Stage 3 เดิม แต่ P ที่ป้อนคือ **P ที่วัดจริง** จากวงจร ไม่ใช่ step นามธรรม

**Disturbance:** current sink 2 A เสียบขนานโหลดที่ t = 0.2 s (ΔP ≈ 28 W)
→ Δf_ss ≈ −0.05·0.28·50 = **−0.7 Hz** ✓

**บทเรียน:** ลำดับชั้นควบคุม droop → V loop → I loop ทำงานร่วมกันได้
โดย bandwidth ไม่ตีกัน (~80 blocks)

---

## Stage 5a — ชั้น Switching จริง (abc + SPWM 10 kHz)

**คำถามที่ตอบ:** controller เดิม (dq) รอดไหมเมื่อคลื่นที่ป้อนวงจรไม่ใช่
sine สวย ๆ แต่เป็นคลื่นสี่เหลี่ยม ±V_dc/2 สับที่ 10 kHz

**สิ่งที่เพิ่ม (signal path เต็ม):**
```
dq refs → inverse Park(δ) → V_abc_ref → เทียบ triangle 10 kHz (SPWM)
→ behavioural 2-level bridge (±V_dc/2) → LC filter 3 เฟส → โหลด RL
→ วัด V,I → forward Park(δ) → กลับเข้า PI + power calc
```
- f_sw = 10 kHz = ความถี่ MCPWM ที่จะใช้บน ESP32 จริง
- bridge เป็น behavioural (ยังไม่มี dead-time / R_on) — พอสำหรับพิสูจน์ control
- pure Simulink ไม่ใช้ Simscape → รันได้บน R2018b base

**Design point ล็อก (2026-05-30):** **V_dc = 40 V**, V_ac_peak = 14 V
(m = 0.70 อยู่ในย่าน linear SPWM), R_load = 2.94 Ω → P ≈ 100 W (3 เฟส)
ประวัติ V_dc: 24 V → 48 V (24 V overmodulate เพราะ V_dc/2 = 12 < 14) → 40 V

**Disturbance:** R_load ลดเหลือ 70% ที่กำหนดเวลาไว้ → ΔP ≈ +40 W

**หมายเหตุ:** baseline 5a รัน D=0, T_sim 1.5 s → ค่า f ตอนจบเป็นแค่
mid-transient ไม่ใช่ steady state; ตัวเทียบ SS จริงคือ
`phase5a_rerun_matched.m` (T_sim 3 s, D = 0.5, จุดออกแบบ 40 V ตรงกับ 5c/5d)

---

## Stage 5b — H-D Parametric Sweep (ที่มาของค่า H=5, D=0.5)

**คำถามที่ตอบ:** ควรตั้ง virtual inertia (H) กับ damping (D) เท่าไหร่

**วิธี:** รันโมเดล 5a ซ้ำ **30 เคส** — H ∈ {0,1,3,5,7,10} × D ∈ {0,0.5,1,2,5}
วัด: max RoCoF, frequency nadir, overshoot, settling time, f_ss, P_ss
(ใช้ `Simulink.SimulationInput.setBlockParameter` override ทีละเคส
เพราะ script สร้างโมเดลแบบ bake ตัวเลขเป็น literal ใน block)

**ผล:** เลือก **H = 5, D = 0.5** — RoCoF 2.5 Hz/s, settle 0.24 s,
nadir ~49.9 Hz

**บทเรียนระหว่างทาง:** grid D เดิม {0,5,10,20,40} overdamped หมดทุกเคสที่
D≥5 (Δf < 5 mHz มองอะไรไม่เห็น) ต้องลดสเกลลงมาเป็น {0,0.5,1,2,5} —
สอดคล้องกับที่ Stage 2 เจอว่า D หลักสิบมันแรงเกินสำหรับระบบนี้

---

## Stage 5c — Tuning: R_d Damping + dq Decoupling Feedforward

**คำถามที่ตอบ:** แก้จุดอ่อน 2 จุดของ 5a ที่จะ "กัด" ตอนขึ้นฮาร์ดแวร์จริง

**ปัญหา 1 — LC filter ring ที่ 1.45 kHz:** ζ ของ filter ใน 5a ≈ 0.23%
(แทบไม่มี damping) โหลด step ทีไร V_load สั่นให้เห็นเลย
→ **แก้:** ใส่ R_d = 1 Ω อนุกรมกับ C_f → ζ ≈ 4.6% (ดีขึ้น 20 เท่า)
เลือก 1 Ω เพราะใหญ่กว่านี้จะฉีด PWM ripple เข้า V_load แทน (trade-off)

**ปัญหา 2 — current PI สู้ cross-coupling เอง:** ในเฟรม dq แกน d/q พันกัน
ด้วยเทอม ±ω·L_f·i และ PI ต้องแบก V_load ทุก cycle
→ **แก้:** feedforward ที่ปลาย PI:
```
V_inv_d_ref = PI_d + V_load_d − ω·L_f·i_L_q
V_inv_q_ref = PI_q + V_load_q + ω·L_f·i_L_d
```
PI เลยเห็น plant เป็น R-L สะอาด ๆ

**ผลสำคัญ (สูตร SS ที่ถูกต้องเมื่อ D ≠ 0):**
```
Δω_pu = −ΔP_pu / (1/R_p + D·ω_s)
```
ที่ D = 0.5: เทอม D·ω_s ≈ 157 **ใหญ่กว่าเทอม droop 1/R_p = 20 ราว 8 เท่า**
→ droop สุทธิที่เห็นจริง ≈ 0.56% ไม่ใช่ 5% → f_ss ≈ **49.89 Hz**
(ตรงกับ sweep 5b cell H5/D0.5 = 49.896 Hz) — จุดนี้ต้องเล่าใน Ch.4/Ch.6
เพราะมันเปลี่ยนความหมายของ "droop 5%" ที่ตั้งไว้

---

## Stage 5d — Controller แบบ Discrete เหมือน Firmware (ด่านสุดท้ายก่อน bench)

**คำถามที่ตอบ:** firmware จริงบน ESP32 ไม่ใช่ระบบต่อเนื่อง — sample 10 kHz,
forward-Euler, มี delay หนึ่งคาบ PWM แล้ว phase margin ที่หายไปทำ loop พังไหม

**ทำไมต้องกังวล:**
- ZOH + compute delay ≈ 1.5·Ts = 150 µs → phase lag **~54°** ที่ BW 1 kHz
- fs/BW = 10 kHz/1 kHz = 10 เท่า = ขั้นต่ำตามตำราสำหรับ discretisation
- LC resonance (1.45 kHz, ζ 4.6%) อยู่เหนือ BW แค่ 1.45 เท่า
- ถ้า loop discrete ring ตรงนี้ = ring บนบอร์ดจริง → รู้ก่อนฟรี ๆ ดีกว่า MOSFET ไหม้

**วิธี (surgical transform — โหลด 5c มาแปลง ไม่สร้างใหม่):** แปลงเฉพาะ
controller ส่วน plant (bridge, LC, โหลด, carrier) คงต่อเนื่อง:
1. PI ทั้ง 4 ตัว → discrete forward-Euler, Ts = 100 µs (ตรง firmware)
2. Integrator ของ swing eq → Discrete-Time Integrator forward-Euler
3. สัญญาณวัด dq → **ZOH 10 kHz** (= AD7606 sample พร้อมกันทุก tick)
4. P/Q → **discrete LPF 5 Hz** ด้วยค่า K = 0.00313176 **ตัวเดียวกับใน
   `vsg_controller.ino` เป๊ะ** (5c ป้อน P/Q ดิบ ซึ่ง firmware ไม่เคยทำ)
5. V_abc_ref → Unit Delay 1 tick (duty ที่เขียนคาบนี้มีผลคาบหน้า)

**สิ่งที่จงใจไม่ใส่ (บันทึกไว้สำหรับ Ch.5/6):** dead-time IR2104 520 ns
(0.52% ของ Ts), quantisation AD7606 (0.3 mV), saturation/anti-windup
(ไม่ active ที่ step นี้), DC-bus dynamics (ถือว่า 40 V แข็ง)

**เกณฑ์ตัดสิน + ผล (2026-07-02): PASS ทุกข้อ**
- f_ss ต่างจาก 5c ระดับ mHz (outer loop ไม่กระทบ) ✓
- ripple ของ i_L_d / V_load_d ไม่โตขึ้นจาก 5c ✓
- ไม่มี oscillation โตขึ้นหลังโหลด step ✓

**ความหมาย:** ค่า gain ชุดที่อยู่ใน firmware ตอนนี้ **ปลอดภัยพอจะขึ้น bench**
— นี่คือหลักฐานที่ Ch.6 จะใช้เทียบกับผลวัดจริง

---

## สรุปเส้นเรื่องทั้งหมดในย่อหน้าเดียว

เราเริ่มจากสมการ swing เปล่า ๆ (S1) พิสูจน์ว่า integrator ถูก แล้วปิด loop
แบบ grid-connected ด้วย Pe(δ) จนได้ swing แบบ SG จริง (S2) จากนั้นสลับเป็น
โหมด islanded ใส่ P-f droop ซึ่งเป็น loop จริงของ grid-forming VSG (S3)
เอา loop นั้นไปคุมวงจรไฟฟ้าจริงผ่าน cascaded V-I control ในเฟรม dq (S4)
เติมชั้น switching SPWM 10 kHz แบบเดียวกับ ESP32 (S5a) กวาดหา H, D
ที่เหมาะสม → H=5, D=0.5 (S5b) แก้ LC ringing ด้วย R_d และปลด burden ของ
PI ด้วย decoupling feedforward พร้อมพบว่า D·ω_s ครอบงำ droop 8 เท่า (S5c)
สุดท้ายแปลง controller เป็น discrete ตรงตาม firmware ทุก quirk แล้วผ่าน —
จึงสรุปได้ว่า design point 40 V / H=5 / D=0.5 พร้อม gain ชุดปัจจุบัน
**พร้อมสำหรับ hardware bench** และงานถัดไปคือ Chapter 6 เทียบผลวัดจริงกับ 5d

## สถานะ manual-build track (ฝึกมือใน Simulink GUI)

- Stage 1 manual: `vsg_stage1_manual.slx` — **PASS** (2026-07-15, max |Δf| 5.5e-6 Hz)
- Stage 2 manual: คู่มืออยู่ที่ `STAGE2_MANUAL_BUILD.md` — รอสร้าง
- ตัวตรวจ: `validate_stage1_manual.m` / `validate_stage2_manual.m`
