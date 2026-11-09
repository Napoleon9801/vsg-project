# Stage 5i — เพิ่ม secondary frequency control ให้กลับใกล้ 50 Hz

วันที่ 6 พฤศจิกายน 2026 (UTC+7) — Codex desktop / GPT-6

## ไฟล์ใช้งาน

โมเดลใหม่:
`D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i\vsg_stage5i_secondary.slx`

โมเดลต้นทางที่บันทึกไว้:
`D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\vsg_stage5h_mosfet_layout.slx`

Stage 5i เป็นสำเนาเพิ่มตัวควบคุมใหม่ ต้นฉบับ Stage 5h และ firmware ไม่ถูกแก้ไข การเปลี่ยนแปลงที่ยังไม่ได้ Save ใน MATLAB session อื่นไม่รวมอยู่ในสำเนานี้

## การทำงาน

เพิ่ม subsystem `Secondary_Frequency_Control` รับ omega ของ VSG และ P_set เดิม 1 pu โดยคำนวณ

```text
f = omega / (2*pi)
e = 50 - f                     [Hz]
d(delta_P)/dt = Ki * e          [pu/s]
P_ref = P_set + delta_P         [pu; base = 100 W]
```

เมื่อความถี่ต่ำกว่า 50 Hz ตัวควบคุมค่อย ๆ เพิ่ม P_ref เมื่อความถี่สูงกว่า 50 Hz จะค่อย ๆ ลด P_ref วงควบคุม droop, damping, swing equation, voltage/current PI และวงจร MOSFET เดิมยังทำงานตามเดิม จึงคืนความถี่ผ่านการปรับกำลังอ้างอิง ไม่ได้บังคับแทนค่าความถี่ในสัญญาณกราฟ

พารามิเตอร์บันทึกใน Model Workspace:

| ตัวแปร | ค่า | ความหมาย |
|---|---:|---|
| secondary_f_ref_Hz | 50 | ความถี่เป้าหมาย |
| secondary_Ki | 4 | pu/(Hz·s) |
| secondary_Ts | 0.0001 s | Discrete integrator แบบ Forward Euler |
| secondary_enable_time | 0.5 s | เริ่ม secondary หลังช่วงเริ่มต้น |
| secondary_enable | 1 | เปิด secondary; 0 คือปิดทั้งการทดลอง |
| secondary_min_pu | −0.5 | ขีดจำกัด integral correction ด้านล่าง |
| secondary_max_pu | +0.8 | ขีดจำกัด integral correction ด้านบน |

Integrator จำกัดที่ state ของตัวเองและ reset เป็นศูนย์ขณะ disabled เพื่อป้องกัน hidden windup การเปลี่ยน enable ระหว่างรันจะ reset correction ซึ่งอาจทำให้ P_ref กระโดด; ยังไม่ได้ทดสอบการสลับระหว่างรันกับวงจรกำลังเต็มชุด

ขีดจำกัด correction ทำให้ power command อยู่ในช่วง 50–180 W equivalent เมื่อ P_set=1 pu ขอบเขตนี้เป็นสมมติฐานของคำสั่งควบคุม ไม่ใช่ current protection หรือพิกัดกำลัง hardware

Reduced-order screen ที่ถือ P_load เป็น disturbance คงที่ให้ poles ประมาณ −1.212 และ −16.495 /s จึงเลือกวง secondary ที่ช้ากว่า primary; ผลนี้ไม่แทนการทดสอบ switching model ทั้งชุด

## วิธีเปิดและกด Run

ใช้ MATLAB R2018b:

```matlab
open_system('D:/workspace/engineering/vsg-project/matlab/validation_outputs/stage5i/vsg_stage5i_secondary.slx');
```

1. กด Run โดยใช้ Stop Time = 6 s ตามไฟล์
2. ดับเบิลคลิก `Scope_frequency_Hz` ใกล้ subsystem สีเขียว `Secondary_Frequency_Control`
3. กด Autoscale ใน Scope เพื่อดูเส้นตลอด 0–6 s
4. Scope PWM, output voltage, iL และ Vds เดิมยังอยู่บริเวณขวาบน

หากต้องการเปรียบเทียบเปิด/ปิด ให้ใช้ Model Explorer → เลือกโมเดล → Model Workspace แล้วเปลี่ยน `secondary_enable` ระหว่าง 1 และ 0 ก่อนกด Run อีกครั้ง

ดูผล nominal ที่บันทึกไว้โดยไม่รันใหม่:

```matlab
addpath('D:/workspace/engineering/vsg-project/matlab');
show_stage5i_results;
```

หรือรันและบันทึกผลใหม่:

```matlab
addpath('D:/workspace/engineering/vsg-project/matlab');
report = run_stage5i_secondary(6, 2.5e-6, 'manual', 1);
```

PNG และ `show_stage5i_results` อ่านผลที่บันทึกชื่อ nominal ไม่ได้อัปเดตอัตโนมัติจาก Run button; ดูผลรอบล่าสุดใน Scope/out

## ผล nominal ที่รันจริง

DC = 40 V, V_set = 14 V peak, โหลดเพิ่มที่ 1 s, Stop Time = 6 s, MaxStep = 2.5 us:

| รายการ | ผล |
|---|---:|
| ความถี่ sample สุดท้ายที่ 6 s | 49.9996122 Hz |
| ความถี่เฉลี่ยช่วง 5.6–6.0 s | 49.9994965 Hz |
| ความถี่ต่ำสุดหลังโหลดเพิ่ม | 49.9179124 Hz ที่ 1.4688 s |
| เวลาที่เข้าช่วง 50 ± 0.005 Hz และอยู่ต่อเนื่องจนจบ | 3.8998 s |
| ระยะคืนความถี่หลังโหลดเพิ่ม | 2.8998 s |
| error สูงสุดตลอด 1 s สุดท้าย | 0.0013148 Hz |
| แรงดันโหลด RMS เฟส A/B/C | 9.745595 / 9.745995 / 9.746540 V |
| กระแสโหลด RMS เฟส A/B/C | 4.678639 / 4.678819 / 4.679091 A |
| กำลัง P ที่วัดเฉลี่ย | 136.0476 W |
| P_ref sample สุดท้าย | 1.3591654 pu ≈ 135.9165 W equivalent |
| จำนวน sample ที่ gate บน–ล่างเปิดพร้อมกัน A/B/C | 0 / 0 / 0 |
| deadtime ต่ำสุดที่วัดได้ | ประมาณ 0.520 us |

ค่า RMS และกำลังเฉลี่ยในตารางใช้ช่วง 5.6–6.0 s กำลัง P วัดด้วย iL จึงรวมผลของทาง filter ตามโมเดลเดิม ผลหลังเพิ่มโหลดยังเป็นการทดลองประมาณ136 W ซึ่งเกิน nominal100 W เดิม ไม่ได้เพิ่มพิกัด hardware ด้วยการเพิ่มตัวควบคุม

## หลักฐานการตรวจ

- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i\secondary_limits_test_2026-11-06.json`: 10 ข้อผ่านจากการรัน subsystem จริง ได้แก่ enable/reset, gain/time units, ขีดจำกัดทั้งสองด้าน และ unwind เมื่อ error กลับทิศ
- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i\structure_verification_2026-11-06.json`: block เดิม297 ตัวและการเชื่อมต่อวงจรกำลังไม่เปลี่ยน อนุญาตเฉพาะเพิ่ม secondary/telemetry และเปลี่ยน StopTime3→6; ตรวจและบันทึก default Multibody configuration ที่ MATLAB เติมแต่โมเดลไม่ได้ใช้อย่างเจาะจง
- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i\report_nominal.json`: finite, gate, electrical sanity, voltage, correction bounds และ restoration ผ่าน
- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i\independent_result_checks_2026-11-06.json`: ตรวจค่าจาก MAT อิสระ; ต้องดู `refinement_available` ก่อนสรุปว่ามีผล halved-step
- `D:\workspace\engineering\vsg-project\docs\figures\stage5i_secondary_frequency_2026-11-06.png`: กราฟจากข้อมูลจริง; เส้น Stage5h สิ้นสุด3sตามข้อมูลเดิม ไม่ต่อเส้นสมมติถึง6s

ผลนี้ยืนยัน secondary restoration สำหรับกรณีโหลดเพิ่มที่ทดสอบใน simulation ยังไม่ได้ทดสอบ load removal กับวงจรกำลังเต็มชุด, hardware, gate-driver electrical behavior หรือ thermal limits

## ผลตรวจความละเอียดที่เสร็จแล้ว

รันซ้ำครบ6sด้วย MaxStep1.25us ผ่านเกณฑ์ทั้งหมดเช่นเดียวกับรอบ2.5us:

- ความถี่เฉลี่ยช่วง5.6–6s = 49.999496486 Hz
- ทั้งสองรอบเข้าช่วง50±0.005Hzต่อเนื่องตั้งแต่3.8998sจนจบ
- ความถี่บนกริด100usตลอด0–6sต่างกันสูงสุด7.412e−7Hz
- ค่าเฉลี่ยความถี่ท้ายการทดลองต่างกัน1.004e−8Hz
- RMSแรงดัน/กระแสต่างกันสูงสุด0.002123% /0.002117%
- รอบละเอียดบันทึก clamp-state เพิ่มเติม: ไม่ชนขีดจำกัด Integral ตลอดการทดลอง

ไฟล์ผลรอบละเอียด:
`D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i\results_refined.mat`
`D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i\report_refined.json`

รายงานอิสระมี `refinement_available=true`, `pass=true` และผ่าน10ข้อ ผลนี้รองรับความสอดคล้องของความถี่และค่า RMS ที่ตรวจ ไม่ใช่การตรวจ THD/EMI/thermal ครบทุกด้าน

สำเนาโมเดลที่ใช้ทดสอบจริงและ hash ก่อนจัดหัวข้อ/มุมมองสุดท้ายอยู่ที่:
`D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i\vsg_stage5i_secondary.tested_2026-11-06.slx`
`D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i\run_provenance_2026-11-06.json`
