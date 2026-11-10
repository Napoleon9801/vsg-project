# ไฟล์ parameter กลางของ VSG (2026-11-10)

ปรับค่าหลักของโมเดล islanded VSG ได้จากที่เดียว โดยค่าที่ผูกกันจะคำนวณให้อัตโนมัติ

- `D:\workspace\engineering\vsg-project\matlab\vsg_params.m` ใช้กำหนดค่าที่ปรับได้ แสดงสรุป และเตือนเมื่อค่าที่ตั้งเข้ากันไม่ได้
- `D:\workspace\engineering\vsg-project\matlab\apply_vsg_params.m` ใช้สร้างโมเดลที่ใช้ค่าเหล่านั้น (copy มาจาก `vsg_e12_ff_load_cycle.slx` โดยไม่แตะต้นฉบับ)
- `D:\workspace\engineering\vsg-project\matlab\test_vsg_params.m` ใช้ทดสอบว่าโมเดลที่ได้เทียบเท่าโมเดลเดิม

## วิธีใช้ (MATLAB R2018b)

```matlab
cd D:\workspace\engineering\vsg-project\matlab
P = vsg_params('H',10, 't_step_up',2, 't_step_down',5, 'stop_time',8);
apply_vsg_params(P,'h10_steps','open',true);   % เปิดโมเดลใน Simulink แล้วกด Run
```

โมเดลจะถูกสร้างไว้ที่ `matlab\validation_outputs\vsg_params\vsg_param_<label>.slx` พร้อม `<model>_params.json` ที่เก็บค่าที่ใช้

### คำสั่งเดียว: สร้างโมเดล + sim + กราฟ
```matlab
P = vsg_params('H',10, 't_step_up',1, 't_step_down',2, 'stop_time',3);
run_vsg_params(P,'demo_h10');      % เสร็จแล้วจะเปิดรูปให้เอง ('show',false = ไม่เปิด)
```
- ใช้เวลาราว **50 วินาทีต่อเวลาจำลอง 1 วินาที** (3 s ≈ 2.5 นาที, 11 s ≈ 9 นาที)
- ผลที่ได้ใน `matlab\validation_outputs\vsg_params\`:
  - `plot_<label>.png` กราฟแบบเดียวกับ `docs\figures\e12_output_overview_2026-11-10.png`
  - `results_<label>.mat` สัญญาณที่ย่อแล้ว (grid 1 ms + waveform ดิบรอบ ๆ step)
  - `report_<label>.json` เก็บค่าที่ตั้ง ค่าที่คำนวณได้ และค่าที่นิ่งแล้วของแต่ละช่วง
- ที่ command window จะพิมพ์ตารางช่วงละบรรทัด (V+, I, P, Q, f) ออกมาด้วย
- กราฟวาดด้วย `python\analysis\plot_vsg_output.py` ซึ่ง MATLAB เรียกผ่าน `system('python ...')` ถ้า python ไม่อยู่ใน PATH ให้ส่ง `'python','C:\path\python.exe'` เข้าไป ผล .mat จะยังถูกบันทึกแม้พลอตไม่สำเร็จ
- ทดสอบแล้ว (H = 10, step ที่ 1/2 s, 3 s): 153 s, I 3.31 → 4.68 → 3.31 A, f ของ rotor ต่ำสุด 49.915 Hz

หลังสร้างแล้วจะแก้ค่าในโมเดลตรง ๆ ก็ได้ ไปที่ **Modeling → Model Explorer → Model Workspace** แล้วแก้ตัวแปร `vsg_*` (เช่น `vsg_H`) ค่าที่ผูกกัน (ωs/2H, carrier ฯลฯ) จะตามไปเองเพราะ block เขียนเป็นสูตร แต่วิธีนี้**ข้ามการตรวจของ `vsg_params`** ไป

## ค่าที่ปรับได้

| ชื่อ | ค่าเริ่มต้น | ความหมาย | ค่าที่ผูกกันซึ่งโมเดลคำนวณให้ |
|---|---|---|---|
| `Vdc` | 40 V | แรงดัน DC link | carrier ±Vdc/2 ทำให้ gain ของ inverter = 1 จึงไม่ต้องจูน PI ใหม่ |
| `Vrms` | 9.8995 V | แรงดันเฟสที่ต้องการ (14 V peak) | V_set = Vrms·√2 |
| `f0` | 50 Hz | ความถี่ระบบ | ωs ทั้ง 9 จุด, ωCf ของ FF, f_ref ของ secondary |
| `H` | 5 s | inertia | ωs/(2H) |
| `D` | 0.5 | damping (คูณ Δω ที่หน่วยเป็น rad/s) | K = 1/Rp + D·ωs |
| `Rp` | 0.05 | P–f droop | −1/(Rp·ωs) |
| `Dq` | 0.007 V/var | Q–V droop | |
| `S` | 100 VA | ฐานกำลัง | P_to_pu = 1/S |
| `P_set_pu`, `Q_set` | 1 pu, 0 var | setpoint | |
| `f_lpf_PQ` | 5 Hz | LPF ของการวัด P/Q | สัมประสิทธิ์ discrete ที่ Ts = 100 µs |
| `R_load`, `L_load` | 2.058 Ω, 1 mH | โหลดที่ต่ออยู่ตลอด (ต่อเฟส) | |
| `R_step` | 0.882 Ω | R ที่อนุกรมอยู่และถูก bypass ตอน step | โหลดจะ**เพิ่ม**ที่ `t_step_up` และ**ลด**กลับที่ `t_step_down` |
| `t_step_up`, `t_step_down` | 3 s, 7 s | เวลา step โหลด (ใส่ `Inf` = ไม่มี step) | |
| `stop_time` | 11 s | เวลาจำลอง | |
| `secondary_on`, `secondary_Ki` | 1, 4 | secondary frequency control | |
| `ff_on` | 1 | load-current FF จาก E1.2 (ใช้ได้เฉพาะ islanded) | |

**ค่าที่ไม่ได้อยู่ในไฟล์นี้** (เปลี่ยนแล้วต้องออกแบบ controller ใหม่): Lf/Rf 1.2 mH/0.05 Ω, Cf/Rd 10 µF/1 Ω, PI ของ voltage loop (0.00888/3.944) และ current loop (7.54/314.15), Ts 100 µs, carrier 10 kHz, ข้อมูล MOSFET, deadtime 520 ns

## สิ่งที่ `vsg_params` เตือน
- modulation เกิน 80% หรือ 100% ของ Vdc/2 (โมเดล**ไม่มี** modulation/current limit)
- damping ของ secondary loop ζ = K/(2√(2H·Ki·f0)) ต่ำกว่า 0.7 พร้อมเสนอ Ki ที่ทำให้ ζ = 1 (เช่น ถ้า D = 0 จะได้ K = 20, ζ = 0.22 และ Ki ที่ควรใช้ ≈ 0.2)
- กำลังที่ secondary ต้องชดเชยเกินขอบเขต [−0.5, 0.8] pu ซึ่งทำให้ความถี่กลับไม่ถึง f0
- step แรกอยู่ในช่วง start-up (< 0.7 s) หรืออยู่หลัง stop_time
- ตัวเลขกำลังและกระแสของโหลดในสรุปคำนวณที่แรงดัน setpoint ส่วนแรงดันจริงต่ำกว่าราว 1% (9.80 เทียบกับ 9.90 V) ค่าจริงจึงต่ำกว่าที่สรุปไว้ราว 1–2%

## ผลการทดสอบ (`test_vsg_params.m`, 0.8 s ต่อ run, ผลอยู่ที่ `validation_outputs\vsg_params\test_vsg_params.json`)

| การทดสอบ | ผล |
|---|---|
| ค่า parameter ทั้ง 36 ตัวที่ default เทียบกับโมเดลเดิม | ต่างกันมากสุด 1.9×10⁻⁶ (relative) มาจากตัวเลขที่ปัดไว้ในโมเดลเดิม เช่น 314.1593 เทียบกับ 2π·50 |
| แรงดันโหลด default เทียบกับโมเดลเดิม (0.05–0.8 s) | ต่างกันมากสุด 12 mV, RMS 0.95 mV (เทียบกับ 14 V peak) |
| Vdc 60 V เทียบกับ 40 V (Vrms ช่วง 0.5–0.8 s) | ต่างกัน 0.21% แสดงว่าการปรับ carrier ตาม Vdc ทำให้ controller ไม่เปลี่ยน |
| step ที่ 0.40/0.60 s | Irms 3.31 → 4.68 → 3.31 A ทำงานตามเวลาที่ตั้ง |
| ไฟล์ต้นฉบับ | hash ไม่เปลี่ยน |

## ข้อจำกัด
- รองรับ step โหลดได้แค่ 1 คู่ (ขึ้น/ลง) ตามโครงสร้าง breaker เดิม ถ้าต้องการหลาย step ต้องเปลี่ยน logic ที่สั่ง breaker
- breaker ตัดที่ current zero ของแต่ละเฟส จึงมี V0 สั้น ๆ ตอน step ลง (ดู `e12_voltage_loop_analysis_th_2026-11-10.md`)
- runner เดิม (`run_e12_ff_load_cycle.m`, `run_vsg_stiff_source.m`) ยังใช้โมเดลเดิมเหมือนเดิม ไม่ได้ถูกแก้
