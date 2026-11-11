# Stage 5j: bus แบต 48 V / 12 Vrms / SVPWM 20 kHz (2026-11-11)

สถานะ: **สร้างโมเดลและรันครบ 3 เคสแล้ว (simulation เท่านั้น)** steady state และการชดเชย Vbus ผ่าน, transient รายเฟสตอนปลดโหลดยังเกิน ±10% (+13.4%)
สเปกที่ใช้: `docs\notes\spec_48v_100w_2026-11-10.md` — อาจารย์ยังไม่ได้อนุมัติการเปลี่ยน bus 40 V → 48 V และ SVPWM
เกณฑ์ V-SS / V-TR / V-REC ที่อ้างด้านล่างเป็นเกณฑ์ที่เสนอไว้ใน `e12_voltage_loop_analysis_th_2026-11-10.md` §5 ยังรออาจารย์ยืนยัน

## 1. สิ่งที่เปลี่ยนจากโมเดล E1.2 FF

ต้นทางคือ `matlab\validation_outputs\e12_ff_load_cycle\vsg_e12_ff_load_cycle.slx` (ไม่ถูกแก้) ผ่าน `apply_vsg_params` แล้วแก้เฉพาะ 5 จุดนี้ ส่วนอื่นทั้งหมดเหมือนเดิม: PI แรงดัน/กระแส, Lf 1.2 mH, Cf 10 µF, Rd 1 Ω, dead time 520 ns, H 5 s, D 0.5, Rp 0.05, secondary, load-current FF, controller Ts 100 µs

| # | จุดที่เปลี่ยน | เดิม (E1.2) | Stage 5j |
|---|---|---|---|
| 1 | Modulator | เทียบ V_ref (โวลต์) กับ carrier ±20 V คงที่ | subsystem `SVPWM_MinMax_Vdc_FF`: v0 = −(max+min)/2, duty = sat(0.5 + (v_x + v0)/Vdc_sampled, 0.03, 0.97) คำนวณที่ 10 kHz ก่อน delay 1 sample เดิม |
| 2 | Carrier | สามเหลี่ยม ±20 V, 10 kHz | สามเหลี่ยม 0..1, 20 kHz เริ่มที่ valley → controller 10 kHz ยัง sample ที่ valley และอัปเดต duty ทุก 2 carrier |
| 3 | แหล่งจ่าย DC | DC source 40 V คงที่ | Controlled Voltage Source ตาม profile เวลา (`vsg_Vdc_t`, `vsg_Vdc_v`) |
| 4 | Setpoint แรงดัน | step ที่ t = 0 | คูณ ramp 0→1 ใน `vsg_t_softstart` (ค่าเริ่มต้น 0.1 s) |
| 5 | โหลด / setpoint | 14 V peak, 2.058 Ω (+0.882 Ω) | 12 Vrms, 4.297 Ω (+1.842 Ω) → 70 W ↔ 100 W อัตราส่วน conductance 1.4286 เท่า Stage 5i |

สัญญาณ tag `V_a_ref / V_b_ref / V_c_ref` ในโมเดลนี้เป็น **duty 0..1** ไม่ใช่โวลต์แล้ว

## 2. วิธีใช้ (MATLAB R2018b)

```matlab
cd D:\workspace\engineering\vsg-project\matlab
P = vsg_stage5j_params();                 % ค่าเริ่มต้นตามสเปก 48 V / 12 Vrms / 20 kHz
run_stage5j(P,'my_case');                 % build + sim + report + กราฟ 2 รูป

P = vsg_stage5j_params('Vdc',39);                                  % bus คงที่ 39 V
P = vsg_stage5j_params('Vdc_t',[0 1 2],'Vdc_v',[54.6 54.6 39]);    % bus ตาม profile
build_stage5j(P,'my_case','open',true);   % สร้างและเปิดโมเดลดูอย่างเดียว
```

เคสที่รันในเอกสารนี้: `run_stage5j_job('nominal' | 'bus_sweep' | 'smoke' | 'smoke_step')`
ผลอยู่ที่ `matlab\validation_outputs\stage5j\` (`report_<case>.json`, `results_<case>.mat`, `plot_<case>*.png`)
เวลารัน: ประมาณ 90–135 s ของนาฬิกาต่อ 1 s ของ simulation (MaxStep 2.5 µs)

พารามิเตอร์ใหม่: `Vdc_t`, `Vdc_v`, `fsw` (ต้องเป็นจำนวนเท่าของ 10 kHz), `duty_min`, `duty_max`, `t_softstart` ที่เหลือใช้ชื่อเดียวกับ `vsg_params`
ข้อควรระวัง: `t_step_up` / `t_step_down` ใส่ `Inf` ไม่ได้ (Step block ไม่รับ) ให้ใส่ค่าที่เกิน `stop_time` แทน

## 3. ผล

### 3.1 nominal: 48 V, 11 s, โหลด 70 → 100 W ที่ 3 s, กลับ 70 W ที่ 7 s

| ช่วง | V+ rms | I rms | P | f rotor (เฉลี่ย 40% ท้ายช่วง) |
|---|---|---|---|---|
| 0–3 s | 11.969 V | 1.947 A | 69.8 W | 50.010 Hz |
| 3–7 s | 11.951 V | 2.773 A | 99.2 W | 49.998 Hz |
| 7–11 s | 11.969 V | 1.947 A | 69.8 W | 50.002 Hz |

Transient (rms หน้าต่าง 20 ms, % เทียบ setpoint 12 V):

| Event | Vrms รายเฟส | V+ (positive sequence) | เวลากลับเข้า ±2% ของ setpoint | f rotor |
|---|---|---|---|---|
| เพิ่มโหลด 3 s | −6.1% … +5.4% | −4.2% … +4.6% | V+ 32 ms, เฟสแย่สุด 47 ms | ต่ำสุด 49.932 Hz |
| ปลดโหลด 7 s | −7.2% … **+13.4%** (เฟส B 13.60 V ที่ +11 ms) | −5.0% … +4.1% | V+ 34 ms, เฟสแย่สุด 36 ms | สูงสุด 50.071 Hz |

- Duty 0.133–0.867 ไม่ชน clamp เลย (0 จาก 108,500 sample)
- Ripple กระแส Lf: สูงสุด 0.215 A p-p, median 0.130 A p-p (20 ms สุดท้าย หักองค์ประกอบ 50 Hz ออก) ค่าประมาณในสเปก Vdc/(4·Lf·fsw) = 0.50 A ที่ 48 V สูงกว่าที่ sim ได้
- THD แรงดันโหลด 1.23% (0.2 s สุดท้าย, Hann, ถึง 100 kHz); เฉพาะ ≤ 2 kHz = 1.17%
- กำลัง DC 71.05 W, กำลังออก 69.83 W → 98.3% **นับเฉพาะ conduction, Rf, Rd** โมเดล MOSFET ไม่มี switching loss
- V0 ขึ้น 0.73 V เฉพาะตอนปลดโหลด 7 s ซึ่งเป็นลักษณะเดียวกับ breaker เปิดไม่พร้อมกันที่พบใน E1.2 §6.1 แต่ **ยังไม่ได้ตรวจเวลาเปิด breaker ของ run นี้**

### 3.2 bus_sweep: โหลด 100 W ตั้งแต่ 0.8 s, bus 54.6 V → 39 V ระหว่าง 1.5–2.5 s (15.6 V/s)

- V+ ก่อน ramp 11.950 V, ระหว่าง ramp 11.947–11.957 V, หลัง ramp 11.955 V → เปลี่ยนไม่เกิน 0.01 V ตลอดช่วง bus 54.6 → 39 V
- Duty 0.212–0.788 ที่ 54.6 V และ 0.101–0.899 ที่ 39 V ไม่ชน clamp; ที่ 39 V ใช้ 81% ของขีดจำกัด SVPWM (รวม duty clamp แล้ว)
- ที่ 39 V / 99.2 W: กระแส Lf peak 3.98 A, ripple สูงสุด 0.216 A p-p, THD 0.90%, DC เข้า 101.6 W (2.60 A)
- Bus ขั้นต่ำที่ยังทำแรงดันได้ที่ 100 W จากการคำนวณ = 31.8 V (ไม่มี headroom ของ voltage loop; สเปกใช้ 34.5 V ที่เผื่อ 10%)

### 3.3 Start-up: มี / ไม่มี soft-start (48 V, 0.4 s)

| | แรงดัน peak ตอน start | Vrms สูงสุด | กระแสโหลด peak |
|---|---|---|---|
| soft-start 0.1 s (`smoke`) | 17.55 V (103% ของ 16.97 V) | 12.19 V | 2.84 A |
| step ทันที (`smoke_step`) | 24.58 V (145%) | 15.54 V | 3.99 A |

## 4. เทียบเกณฑ์ที่เสนอ (ยังไม่ใช่เกณฑ์ที่อาจารย์อนุมัติ)

| เกณฑ์ | ผล Stage 5j nominal | E1.2 FF (40 V, 97 ↔ 136 W) |
|---|---|---|
| V-SS ±2% | ผ่าน: 11.951–11.970 V (−0.41% … −0.25%) | ผ่าน |
| V-TR ±10% รายเฟส | เพิ่มโหลดผ่าน; **ปลดโหลดไม่ผ่าน** (+13.4%) | ไม่ผ่าน (−11.6% / +15.2%) |
| V-TR ±10% วัด V+ | ผ่านทั้งสอง event (−5.0% … +4.6%) | ผ่าน (−9.7% … +7.1%) |
| V-REC 40 ms | V+ ผ่าน (32 / 34 ms); รายเฟส 47 / 36 ms → **เพิ่มโหลดไม่ผ่าน** | ไม่ผ่าน (121 / 87 ms) |

สองคอลัมน์นี้เทียบ controller กันตรง ๆ ไม่ได้: gain เท่ากันแต่โหลดต่างกัน (4.3 Ω เทียบ 2.06 Ω ต่อเฟส) และแรงดันฐานต่างกัน ผลที่ดีขึ้นจึงยังแยกไม่ได้ว่ามาจากอะไร
ค่า rms ใช้หน้าต่าง 20 ms จึงมี delay ของหน้าต่างรวมอยู่ในเวลา recovery ด้วย

## 5. สิ่งที่โมเดลนี้ยังไม่มี

- Bus เป็นแหล่งจ่ายอุดมคติตาม profile: ไม่มีความต้านทานภายในแบต, BMS, DC-link capacitor หรือ returned energy
- Vdc ที่ controller ใช้เป็นค่า sample อุดมคติ: ไม่มี filter, divider, ADC quantization
- ไม่มี current limit และ PI ไม่มี anti-windup (เหมือน E1.2) duty clamp จึงเป็น saturation เดียวในลูป
- ไม่มี dead-time compensation; MOSFET เป็นสวิตช์ Ron 44 mΩ ไม่มี switching loss
- Rd ยังเป็น 1 Ω ยังไม่ได้จูนใหม่ตามที่สเปกข้อ 7 ระบุ และยังไม่ได้รันเคส no-load
- ยังไม่ได้ทดสอบ H/D sweep หรือ stiff-source inertia ที่ฐานแรงดันใหม่
- ยังไม่มี hardware qualification ใด ๆ

## 6. งานถัดไป

1. แจ้งอาจารย์: bus แบต 48 V, SVPWM, 12 Vrms พร้อมผล Stage 5j นี้ และขอคำตัดสิน V-TR (รายเฟสหรือ V+) กับนิยาม recovery
2. ตรวจเวลาเปิด breaker ตอน 7 s ของ run นี้ (ใช้ `python\analysis\e12_breaker_check.py` เป็นต้นแบบ) เพื่อยืนยันว่า +13.4% มาจาก unbalance
3. เคส no-load และ 0 ↔ 100 W, จูน Rd
4. เพิ่ม model ของแบต (R ภายใน + DC-link C) เมื่อได้ข้อมูลจากร้าน และ Vdc sensing filter
5. วัด Isat ของ Lf (peak ที่ 100 W = 3.98 A + ripple)

## 7. ไฟล์

- `matlab\vsg_stage5j_params.m`, `build_stage5j.m`, `run_stage5j.m`, `run_stage5j_job.m`
- `python\analysis\plot_stage5j.py` (กราฟ bus / duty / ripple); กราฟภาพรวมใช้ `plot_vsg_output.py` เดิม
- `docs\figures\stage5j_nominal_overview_2026-11-11.png`, `stage5j_nominal_bus_pwm_2026-11-11.png`, `stage5j_bus_sweep_overview_2026-11-11.png`, `stage5j_bus_sweep_bus_pwm_2026-11-11.png`
- หมายเหตุ: `report_nominal.json` ช่อง ripple ถูกคำนวณซ้ำจาก `results_nominal.mat` ด้วย algorithm เดียวกัน เพราะ runner ตอนนั้นใช้ความถี่ที่เป็น NaN (แก้ใน `run_stage5j.m` แล้ว); การคำนวณซ้ำแบบเดียวกันให้ค่าตรงกับ report ของ `bus_sweep` และ `smoke`
