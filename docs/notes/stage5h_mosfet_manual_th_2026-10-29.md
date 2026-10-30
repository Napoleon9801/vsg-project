# คู่มือต่อและสาธิต VSG ที่ใช้ PWM ขับ MOSFET ใน Simulink

สร้างวันที่ 29 ตุลาคม 2026; ตรวจผลและจัดส่งวันที่ 30 ตุลาคม 2026 — MATLAB R2018b / Simscape Electrical Specialized Power Systems (SPS)

## ผลที่รันและตรวจแล้ว

รันวงจรครบ 3 s ที่ MaxStep 2.5 µs และรันซ้ำที่ 1.25 µs โดยเพิ่มโหลดที่ 1 s ค่าด้านล่างมาจากรอบ 2.5 µs ไม่ใช่ค่าที่กรอกเป็นเป้าหมาย:

| สิ่งที่ตรวจ | ผล |
|---|---|
| แรงดัน DC วัดระหว่างรางจริงของโมเดล | 40 V |
| ความถี่ช่วงท้าย | 49.898172 Hz |
| แรงดันเฟส A/B/C, RMS ช่วง 2.8–3 s | 9.7441 / 9.7390 / 9.7556 V |
| กระแสโหลด A/B/C, RMS ช่วง 2.8–3 s | 4.6796 / 4.6749 / 4.6830 A |
| กำลัง P ที่วงควบคุมวัด ช่วง 2.8–2.99 s | 136.0651 W; ใช้ iL จึงไม่ใช่กำลังโหลดล้วน |
| กระแส DC สูงสุดตลอดรอบ | 6.7784 A; แหล่ง DC ยังเป็น ideal voltage source |
| Gate บน–ล่างเปิดพร้อมกัน | ไม่พบในข้อมูลที่บันทึกทั้งสามคู่ |
| dead time ต่ำสุด/ค่ากลาง | ประมาณ 0.520 µs |
| ลด MaxStep ลงครึ่งหนึ่ง | ความถี่ต่าง 5.01e-7 Hz; RMS แรงดันต่างสูงสุด 0.000587% |

ผ่านเกณฑ์ **operating_screen, gate_screen, electrical_sanity_screen** และการเปรียบเทียบค่าช่วงท้ายระหว่างสอง MaxStep ที่กำหนดไว้ในสคริปต์ ผลนี้ไม่ครอบคลุมความลู่เข้าของทุก transient, EMI, switching loss หรือความร้อน

กราฟ: `D:\workspace\engineering\vsg-project\docs\figures\stage5h_mosfet_nominal_2026-10-29.png`

หลักฐาน: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\report_nominal.json`, `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\report_refined.json`, และ `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\step_refinement.json`

รอบพัฒนาครั้งแรกต่อขั้ว DC ผิดและไม่ผ่าน operating screen ได้แก้ขั้วและรันใหม่แล้ว ไฟล์ `.backup_*` เก็บผลก่อนแก้ ห้ามใช้ผลสำรองนั้นเป็นผลปัจจุบัน ส่วนคำเตือนของ SPS ว่าไม่ใช้ initial current ที่ Lf_A เป็นข้อจำกัดของ state ที่พึ่งพากันในวงจร ตรวจข้อมูลเริ่มต้นแล้ว iL และแรงดันโหลดทั้งสามเฟสเป็นศูนย์

## สิ่งที่อาจารย์ต้องการเห็น

สัญญาณที่เรียกว่า “trigger MOSFET” ในงานนี้คือสัญญาณ PWM ที่ขา Gate: วงควบคุม VSG สร้างแรงดันอ้างอิงสามเฟส จากนั้นเปรียบเทียบกับ carrier เพื่อสั่ง MOSFET บน–ล่างของอินเวอร์เตอร์ สวิตช์ต่อกับแหล่ง DC และวงจร LC/RL ผ่านพอร์ตไฟฟ้าจริงของโมเดล แล้วนำค่าที่วัดกลับเข้าวงควบคุม

โมเดลใหม่นี้ชื่อ **Stage 5h MOSFET** แยกจาก Stage 5d ซึ่งใช้ `Sign × 20` แทนแรงดันสวิตช์ ใช้วงควบคุม discrete ของ 5d เป็นฐาน ไม่ได้อ้างว่าฮาร์ดแวร์ผ่านการทดสอบแล้ว

```text
P/Q -> Swing equation + Q-V droop -> Voltage PI -> Current PI
 ↑                                                       ↓
การวัด vd/vq/id/iq <- Park + ZOH <- วงจรไฟฟ้า <- MOSFET <- PWM + dead time
                                                       ↑
                                 inverse Park + Unit Delay 100 us
```

## ไฟล์และวิธีเปิด

- โมเดล: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\vsg_stage5h_mosfet.slx`
- สคริปต์สร้าง: `D:\workspace\engineering\vsg-project\matlab\build_stage5h_mosfet.m`
- สคริปต์รัน/บันทึกผล: `D:\workspace\engineering\vsg-project\matlab\run_stage5h_mosfet.m`
- สคริปต์แสดงผล: `D:\workspace\engineering\vsg-project\matlab\show_stage5h_results.m`

เปิดโมเดลที่สร้างแล้วและดับเบิลคลิก `Gate_Driver_and_MOSFET_Circuit` เพื่อดูอุปกรณ์:

```matlab
addpath('D:/workspace/engineering/vsg-project/matlab');
open_system('D:/workspace/engineering/vsg-project/matlab/validation_outputs/stage5h/vsg_stage5h_mosfet.slx');
```

รันเต็มพร้อมบันทึกข้อมูลและเปิดกราฟ:

```matlab
report = run_stage5h_mosfet(3,2.5e-6,'nominal');
show_stage5h_results('nominal');
```

ไม่ต้องรัน `build_stage5h_mosfet` ทุกครั้ง เพราะคำสั่งนี้สร้างโมเดลใหม่จาก Stage 5d และแทนที่ไฟล์ Stage 5h พร้อมสำรองไฟล์เก่า หากต่อเองให้ Save As ชื่อ `vsg_stage5h_manual.slx` เพื่อเก็บงานของตนเอง และกด Run ในโมเดลนั้น สคริปต์ `run_stage5h_mosfet` รันเฉพาะโมเดลอ้างอิง Stage 5h

## 1. เลือกบล็อกให้เป็นตระกูลเดียวกัน

ใช้ Library Browser หรือพิมพ์ `powerlib` ใน Command Window เพื่อเปิด SPS ของ R2018b แล้วเลือก:

| หมวดใน powerlib | บล็อก | จำนวน/หน้าที่ |
|---|---|---|
| Power Electronics | Mosfet | 6 ตัว: A_HIGH/A_LOW, B_HIGH/B_LOW, C_HIGH/C_LOW |
| Electrical Sources | DC Voltage Source | 1 ตัว 40 V |
| Elements | Ground | อ้างอิง DC− |
| Elements | Series RLC Branch | เลือกชนิด RL/RC/R ตามตารางด้านล่าง |
| Elements | Breaker | 3 ตัว bypass ตัวต้านทานเพิ่ม |
| Measurements | Current Measurement | 3 วัด iL, 3 วัด iload, 1 วัด Idc |
| Measurements | Voltage Measurement | 3 วัด Vphase, 3 วัด Vpole, 1 วัด Vds, 1 วัด N_AC |
| หน้าแรก | powergui | 1 ตัว ตั้ง Continuous / 50 Hz |

บล็อก SPS นี้รับสาย Simulink 0/1 ที่ `g` โดยตรง จึงไม่ใช้ Simulink-PS Converter ที่ Gate อย่าผสมพอร์ต SPS กับ MOSFET อีกตระกูลใน Simscape Foundation ซึ่งมีวิธีต่อและการอ้างอิงต่างกัน

## 2. ต่ออินเวอร์เตอร์ทีละเฟส

ทำเฟส A ก่อน แล้วทำ B/C ด้วยรูปแบบเดียวกัน:

```text
DC+ ---- D [MOSFET_A_HIGH] S ---- จุดสวิตช์ A ---- D [MOSFET_A_LOW] S ---- DC−
                                      |
                               Current Measurement iL_A
                                      |
                              Lf 1.2 mH + Rf 0.05 Ω
                                      |
                               จุดเอาต์พุตเฟส A
                                 /             \
                      Rd 1 Ω + Cf 10 µF       โหลด RL
                                 \             /
                                    N_AC
```

MOSFET บน: Drain ต่อ DC+, Source ต่อจุดสวิตช์เฟส ส่วน MOSFET ล่าง: Drain ต่อจุดสวิตช์เฟส, Source ต่อ DC− แหล่งจ่ายทั้งสามขาใช้ DC+ / DC− ชุดเดียวกัน

ให้ดูเครื่องหมาย `+`/`−` บนบล็อกแหล่งจ่ายเสมอ: ใน R2018b บล็อก DC Voltage Source มีพอร์ตภายใน LConn เป็น `−` และ RConn เป็น `+` ซึ่งต่างจาก Current Measurement ที่ LConn เป็น `+` การเดาจากด้านซ้าย/ขวาอย่างเดียวทำให้กลับขั้วได้

รวมปลายล่างของแขนง Rd–Cf และโหลดทุกเฟสที่ **N_AC จุดเดียว** ไม่ต่อ N_AC ตรงกับ DC− Ground ของโมเดลอยู่ฝั่ง DC− จุดดาว AC จึงลอยตามวงจรสามสาย

Current Measurement มีเครื่องหมายบอกทิศ: ตั้งทิศบวกจากอินเวอร์เตอร์ไปหาโหลด ส่วน Voltage Measurement ของเฟสให้ขั้ว `+` อยู่ที่เอาต์พุตหลัง Lf และขั้ว `−` ที่ N_AC

## 3. ตั้งค่าภาคกำลัง

| อุปกรณ์ | ค่าในโมเดล | ความหมาย |
|---|---|---|
| แหล่ง DC | 40 V | แหล่งแรงดันอุดมคติ ยังไม่จำกัดกระแส |
| Filter RL แต่ละเฟส | R=0.05 Ω, L=1.2e-3 H | ต่ออนุกรมจากจุดสวิตช์ไปยังเอาต์พุต |
| Filter RC แต่ละเฟส | R=1 Ω, C=10e-6 F | R ต่ออนุกรม C เป็นแขนงขนานจากเอาต์พุตไป N_AC |
| Load RL แต่ละเฟส | R=2.058 Ω, L=1e-3 H | เป็นแขนงหลักของโหลด |
| Load extra R | 0.882 Ω | ต่ออนุกรมกับ Load RL ก่อนกลับ N_AC |
| MOSFET Ron | 0.044 Ω | ค่าศึกษาการนำกระแส ไม่ใช่แบบจำลองอุปกรณ์ที่รับรองแล้ว |
| MOSFET Lon | 0 H | ไม่มีอินดักแตนซ์ไดโอดในโมเดล |
| MOSFET diode Rd/Vfd | 0.01 Ω / 0.8 V | สมมติฐานศึกษา ไม่ใช่พารามิเตอร์ที่วัดจากบอร์ด |
| MOSFET snubber Rs/Cs | 1e5 Ω / inf | ตัวต้านทานช่วยการคำนวณ ไม่ใช่การเลือก snubber บนบอร์ด |
| Breaker Ron | 0.001 Ω | ทำให้ R หลัง step สูงกว่า 2.058 Ω เล็กน้อย |
| Breaker snubber | 1e6 Ω / inf | มี leakage เล็กน้อยแม้เปิด |

`Rd` ในหน้าต่าง MOSFET เป็นความต้านทานไดโอด ส่วน `Rd=1 Ω` ของวงจรกรองเป็นคนละอุปกรณ์ อย่าสลับกัน

## 4. ต่อการเพิ่มโหลดที่ 1 วินาที

ต่อ Breaker คร่อมตัวต้านทาน extra 0.882 Ω ทุกเฟส ตั้ง External control=on และ Initial state=0 ป้อน Step เดียวกันเข้า Breaker ทั้งสาม: Time=1, Before=0, After=1

ก่อน step: กระแสผ่าน 2.058+0.882 = 2.94 Ω หลัง step: Breaker bypass ตัว 0.882 Ω เหลือประมาณ 2.059 Ω โดยยังใช้ Lload ตัวเดิม กระแสใน L จึงต่อเนื่อง วิธีนี้ต่างจากการเพิ่มโหลด RL ชุดใหม่ทั้งแขนง

## 5. สร้าง PWM และ Gate ทั้งหกช่อง

ใช้ Repeating Sequence ตัวเดียว: Time `[0 5e-5 1e-4]`, Output `[-20 20 -20]` ได้ carrier 10 kHz แรงดันอ้างอิงแต่ละเฟสหลัง Unit Delay ยังมีหน่วยโวลต์

1. Relational Operator `>` เปรียบเทียบ Vphase_ref กับ carrier เป็น upper_request
2. Logical Operator `NOT` สร้าง lower_request
3. ทำ turn-on delay ให้แต่ละ request โดยให้ปิดได้ทันที แต่ต้องรอ 520 ns ก่อนเปิด
4. ต่อ upper_gate เข้า `g` ของ MOSFET บน และ lower_gate เข้า `g` ของ MOSFET ล่าง

วงจร timer ที่ใช้จริงต่อหนึ่ง Gate:

```text
Constant 1 -> Integrator (External reset = level, IC=0) -> เปรียบเทียบ >= 520e-9
                     ↑ reset                                   |
request -> NOT ------+                         request -> AND --+--> g
```

ตอน request=0 จะ reset timer และ Gate เป็น 0; ตอน request=1 timer เริ่มนับ จนผ่านเวลาที่กำหนด Gate จึงเป็น 1 นี่เป็นแบบจำลอง dead time ไม่ใช่วงจร IR2104

ไม่ใช้ Transport Delay ต่อเข้า AND ตรง ๆ เพราะ interpolation ของสัญญาณต่อเนื่องอาจทำให้ช่วงเว้นคลาดเคลื่อน ต้องตรวจ edge-to-edge ในผลซิมด้วย

ลำดับเวกเตอร์ Gate ที่บันทึกคือ `[AH AL BH BL CH CL]` ใช้ Scope ดูทีละคู่และซูมระดับไมโครวินาที ตรวจ `upper AND lower = 0` พร้อมวัดช่วงที่ทั้งคู่เป็น 0

**การโยงไปฮาร์ดแวร์ Option A:** firmware ส่ง PWM 3 ช่องเข้า IN ของ IR2104 จำนวน 3 ตัว แต่ละ driver สร้าง HO/LO สำหรับ MOSFET บน–ล่าง จึงได้สัญญาณ Gate รวม 6 ช่อง โมเดลนี้แสดง 6 ช่องหลังการสร้าง complementary/dead time ไม่ได้กำหนดให้ ESP32 ต้องส่ง PWM อิสระ 6 ช่อง และสัญญาณ logic ของโมเดลไม่ใช่แรงดันที่ใช้ขับ Gate จริง

## 6. ต่อกลับเข้าวงควบคุม Stage 5d

| ขาออกวงจรไฟฟ้า | เชื่อมกลับไปที่ |
|---|---|
| Vphase A/B/C เทียบ N_AC | Mux abc -> Park transform ของแรงดัน |
| iL A/B/C ก่อนแยกไป C/โหลด | Mux abc -> Park transform ของกระแส |
| iload A/B/C | การบันทึกและ Scope ของโหลด |
| P/Q | คำนวณจาก vd/vq และ iLd/iLq ตาม Stage 5d |

ใช้มุม `theta = integral(omega)` และ Park แบบ amplitude-invariant: d ใช้ cosine, q ใช้ negative sine, ตัวคูณ forward=2/3 สัญญาณ dq ทั้งสี่ผ่าน ZOH ที่ 100 µs ก่อนเข้า PI, feedforward และ P/Q

PI ทั้งสี่เป็น Discrete-time / Forward Euler / 100 µs วงแรงดัน P=0.0088799, I=3.9438; วงกระแส P=7.5396, I=314.15 ตามค่าที่บันทึกใน Stage 5d ส่วน P/Q LPF ใช้ numerator `[0.00313176 0]`, denominator `[1 -0.99686824]` และ sample time 100 µs

วงกระแสใช้ `vd_cmd = PI_d + vd - omega*Lf*iq` และ `vq_cmd = PI_q + vq + omega*Lf*id` แล้ว inverse Park และ Unit Delay 100 µs ก่อนส่งเข้า PWM

## 7. ตั้ง solver และตรวจผล

โมเดลอ้างอิงตั้ง ode23tb, variable-step, MaxStep=2.5e-6 s, RelTol=1e-4, AbsTol=1e-6, StopTime=3 s และ powergui Continuous เวลา 100 µs เป็น sample time ของ controller ไม่ใช่ขนาดก้าวของภาคกำลัง

ผลถูกบันทึกแยกตามชื่อ label ใน `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h` เช่น `results_nominal.mat` และ `report_nominal.json` แต่ละสัญญาณมี time ของตนเอง

หากต้องการตรวจความไวต่อ solver step:

```matlab
reportFine = run_stage5h_mosfet(3,1.25e-6,'refined');
```

เปรียบเทียบ frequency, RMS voltage/current และ dead time ของ nominal/refined การที่รันจบโดยไม่ error เพียงอย่างเดียวไม่ยืนยันว่าผลลู่เข้าหรือวงควบคุมมีเสถียรภาพ

## 8. ลำดับสาธิตให้อาจารย์

1. เปิด subsystem ให้เห็นแหล่ง DC, MOSFET ทั้งหก, L/C, โหลด และสาย Gate
2. เปิด Scope ของ Gate แล้วซูมคู่บน–ล่าง เห็น PWM และ dead time
3. แสดง Vds ของ MOSFET A บน: การเปิด Gate ทำให้ Vds ลดลงตามการนำกระแส ส่วนตอนปิดมีแรงดันคร่อมอุปกรณ์
4. แสดงแรงดันและกระแสสามเฟสหลังตัวกรอง
5. แสดงการเปลี่ยนโหลดที่ 1 s พร้อมความถี่และแรงดัน dq ก่อน–หลัง
6. อธิบายการแบ่งงานลงฮาร์ดแวร์: ESP32 คำนวณ VSG/PWM, IR2104 ขับ Gate, ภาคกำลังสร้าง AC, เซนเซอร์ส่งค่ากลับ

สิ่งที่ได้พิสูจน์จากโมเดลนี้คือการทำงานร่วมกันของ controller, switching logic และวงจรไฟฟ้าตามสมมติฐานที่กำหนด ขา `g` เป็นคำสั่ง logic ไม่ใช่แรงดัน Vgs ที่วัดจริง จึงยังไม่ได้พิสูจน์ bootstrap, gate charge, switching loss, ความร้อน, ADC timing หรือระบบ shutdown ของบอร์ด

**ความต่างจาก Stage 5d ที่ต้องบอกอาจารย์:** จุดดาว AC ลอย, MOSFET มี Ron/diode, มี dead time และ leakage จาก numerical snubber ค่า `V_inv_a` เดิมที่สืบทอดมาใน logger ของโมเดลใหม่นี้เป็น pole-to-DCminus ประมาณ 0–40 V ไม่ใช่สัญญาณ ±20 V ของโมเดลเก่า แรงดันเฟสใช้งานต้องอ่าน `Vload_abc` เทียบ N_AC

โหลดหลัง step เป็นการทดสอบเกินฐาน 100 W โดยตั้งใจ ไม่ใช่การรับรองว่าต้นแบบจ่ายกำลังระดับนั้นต่อเนื่องได้

## แหล่งอ้างอิง

- โมเดล Stage 5d: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5d\vsg_stage5d.slx`
- พารามิเตอร์ SPS ที่อ่านจากเครื่อง: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\library_probe.json`
- เอกสาร R2018b: `D:\MATLAB1\help\physmod\sps\powersys\ref\mosfet.html`
- [MathWorks: SPS Mosfet](https://jp.mathworks.com/help/simscape-electrical/powersys/ref/mosfet.html) — ใช้ประกอบความหมายของ logic gate และ macro model; หน้าต่างของรุ่นใหม่อาจต่างจาก R2018b
