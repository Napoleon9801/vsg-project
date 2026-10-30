# บทที่ 3: วิธีดำเนินงานและการออกแบบ
# (Methodology & System Design)

> **ผู้เขียน:** ชินวัตร ดุมกลาง (Napoleon)
> **โครงงาน:** Virtual Synchronous Generator (VSG) for Inverter Control
> **สถานะ:** ฉบับทบทวน 2026-10-20 — baseline 40 V / 100 W; การตรวจรับฮาร์ดแวร์ยังไม่เสร็จ

บทนี้นำเสนอวิธีพัฒนาระบบ VSG ควบคุมด้วย ESP32 ในโหมด grid-forming / islanded สำหรับโหลดสามเฟส โดยเชื่อมการวิเคราะห์ แบบจำลอง และเฟิร์มแวร์เข้ากับแผนทดสอบจริง ผลจำลองสนับสนุนพฤติกรรมเฉพาะกรณีที่ทดสอบ ไม่รับประกันพฤติกรรมของฮาร์ดแวร์ก่อนตรวจวงจรและวัดจริง

เอกสารอ้างอิงจุดออกแบบปัจจุบัน: `D:\workspace\engineering\vsg-project\docs\notes\design_baseline.md`

ข้อกำหนด shutdown และหลักฐานตรวจรับ: `D:\workspace\engineering\vsg-project\docs\notes\hardware_shutdown_and_bench_plan.md`

## 3.1 ภาพรวมและจุดออกแบบ

ระบบกำหนดความถี่และแรงดันให้โหลดอิสระ ไม่เชื่อมกับกริดสาธารณูปโภค ภาคกำลังหลักคือ MOSFET IRF540N กับ IR2104 แบบ bootstrap non-isolated; DRV8302 เป็นทางเลือกที่ยังต้อง qualify โมดูลจริง

**ตารางที่ 3.1** จุดออกแบบปัจจุบัน

| พารามิเตอร์ | ค่า | ขอบเขตการตีความ |
|---|---|---|
| DC bus | 40 V nominal | ต้องทดสอบ finite-source และช่วงแรงดันใช้งาน |
| แรงดันเฟส | 14 V peak = 9.8995 V RMS | แรงดันสาย 17.1464 V RMS |
| กำลัง | 100 W nominal; ฐานวิเคราะห์ 100 VA | ยังไม่ใช่ measured thermal rating |
| ความถี่ | 50 Hz | omega_s = 314.159 rad/s |
| Lf / Rf ต่อเฟส | 1.2 mH / 0.05 Ω | ต้องวัด saturation และ loss ของชิ้นส่วนจริง |
| Cf / Rd ต่อเฟส | 10 µF / 1 Ω | Rd อนุกรม Cf; resonance ประมาณ 1453 Hz |
| PWM / control | 10 kHz | ต้องวัด carrier, phase alignment และ deadline |
| H / D | 5 s / 0.5 | D คูณ deviation หน่วย rad/s |
| Rp / Rq | 0.05 / 0.05 | effective P-f slope รวมประมาณ 0.565% |
| ADC / current sensor | AD7606 / ACS712-20A | ต้อง qualify module straps และ calibrate |

ที่ nominal DC bus ได้ modulation index m = 14/(40/2) = 0.70; ยังต้องตรวจ instantaneous inverter reference และ saturation เมื่อมีโหลด/ทรานเซียนต์ ผล Stage 5a เดิมที่ 24/48 V เก็บเป็นประวัติในบทที่ 4 ไม่ใช่คำสั่งสร้างวงจรปัจจุบัน

## 3.2 รายการวัสดุและการจัดซื้อ

งบ 7,200 บาทและราคาในร่างวันที่ 2026-05-30 เป็นกรอบวางแผนเดิม ไม่ใช่ใบเสนอราคาปัจจุบัน รายการ shutdown, auxiliary supply และ BESS interface ต้องกำหนดให้ชัดก่อนรวมงบใหม่

**ตารางที่ 3.2** รายการหลักและสถานะ qualification (ราคาเดิมเป็น historical estimates วันที่ 2026-05-30)

| รายการ | จำนวนวางแผน | ราคาเดิม (บาท) | สิ่งที่ต้องตรวจเพิ่ม |
|---|---|---|---|
| ESP32-WROOM-32 รวมสำรอง | 2 | 300 | บอร์ดจริง, GPIO และ timing |
| IRF540N รวมสำรอง | 12 | 250 | Switching overshoot, loss, heatsink |
| IR2104 รวมสำรอง | 4 | 150 | Supply, bootstrap, dead-time และ shutdown |
| Bootstrap diode/cap/gate resistor | 1 ชุด | 100 | คำนวณจาก gate charge, duty และ layout |
| AD7606 module | 1 | 1,500 | RESET, RANGE, OS, VDRIVE และ channel mapping |
| ACS712-20A | 3 | 180 | Calibration, noise และ current range |
| Lf 1.2 mH | 3 | 450 | Saturation/ripple/thermal rating ของชิ้นส่วนจริง |
| Cf 10 µF film รวมสำรอง | 4 | 250 | AC voltage และ ripple rating |
| Rd 1 Ω | 3 | 100 | Pulse/continuous dissipation และ cooling |
| OCP comparator/shunt + hardware latch/AND/supervisor | 1 ชุด | ต้องเสนอราคาใหม่ | Independent shutdown และ sensing coverage |
| Divider/filter/conditioning | 1 ชุด | 120 | Input common mode, gain และ bandwidth |
| DC-link capacitors | 1 ชุด | 150 | Ripple, transient rating, pre-charge energy |
| Auxiliary regulated supplies | ตามวงจรจริง | ต้องเสนอราคาใหม่ | Generic LM2596 ต่อจากบัส 40 V โดยตรงไม่ได้รับอนุมัติ |
| Bus protection/pre-charge/fuse/discharge | 1 ชุด | ต้องเสนอราคาใหม่ | Clamp voltage/energy และ DC switching rating |
| Load bank | 3 เฟส | 400 | อุณหภูมิและพิกัดตาม duration |
| PCB/heatsink/connectors/wiring | 1 ชุด | 500 | Layout, insulation, current rating |
| Multimeter ถ้ายังไม่มี | 1 | 200 | เครื่องมือจริงและ measurement category |
| BESS + interface/charger/BMS | ยังไม่กำหนด | ต้องเสนอราคาใหม่ | ห้ามสมมติ pack voltage หรือ direct parallel |

อุปกรณ์แล็บที่วางแผนใช้ ได้แก่ adjustable current-limited DC supply, oscilloscope และ differential/isolated measurement ที่เหมาะสม ต้องยืนยันรายการจริงก่อนทดลอง ไม่มีการยืนยัน availability ในเอกสารนี้

**ตารางที่ 3.3** ภาคกำลังหลักและทางเลือก

| ประเด็น | A: IRF540N + IR2104 | B: DRV8302 module |
|---|---|---|
| สถานะ | แนวทางหลัก; วงจรจริงยังต้องตรวจรับ | ทางเลือก; ยังไม่มี exact module qualification |
| Gate drive | Non-isolated bootstrap, UVLO/internal dead-time | ตรวจโหมดและวงจรของบอร์ดจริง |
| Fault shutdown | Comparator → hardware latch → AND กับ MCU_REQUEST → SD | ต้องพิสูจน์ default-off และ latched shutdown เทียบเท่า |
| พิกัดใช้งาน | ตรวจจาก waveform/thermal evidence | ห้ามใช้ chip rating แทน board rating |

รายละเอียด: `D:\workspace\engineering\vsg-project\docs\notes\power_stage_options.md`

## 3.3 ขั้นตอนการดำเนินงานวิจัย

1. ศึกษาสมการสวิง การกำหนดหน่วย damping และฐาน per-unit พร้อมขอบเขตการเทียบขนาดระบบ
2. สร้างแบบจำลองจาก Stage 1–5c และพัฒนา Stage 5d สำหรับ discrete controller เก็บ metadata และ timestamp ของทุกสัญญาณ; Stage 5e เป็น robustness extension ที่ต้องแสดง model fidelity และผลแต่ละกรณี
3. ออกแบบภาคกำลัง ระบบวัด independent latched shutdown และ source/energy sink พร้อมวงจรที่ตรวจสอบได้
4. พัฒนา ESP32 บน Arduino-ESP32 2.0.17: timer ISR แจ้ง control task; task ทำ floating-point control/ADC/PWM และเป็นเจ้าของ state transition ไม่คำนวณลูปเต็มใน ISR
5. ทดสอบ software/compile ตามขอบเขต แล้วตรวจ bare-board timing, ADC และ independent fault shutdown ก่อน staged powered bench; HIL และ physical bench เป็นหลักฐานแยกกันและยังไม่เสร็จ
6. วิเคราะห์ผลที่มี provenance ตรงกัน พร้อมรายงานข้อจำกัด; ไม่คัดลอก historical PASS เป็นการผ่านของ revision ใหม่

Manual learning track แยกจาก scripted models: มีบันทึก Stage 1–2 ผ่าน และ Stage 3 เป็นขั้นถัดไป ไม่ถือว่าการมี scripted Stage 5d แทนความคืบหน้าการประกอบโมเดลด้วยตนเอง

## 3.4 โครงสร้างและหน่วยของระบบควบคุม

ใช้ Park แบบ amplitude-invariant จึงได้ $P=1.5(v_di_d+v_qi_q)$ สมการสวิงที่ใช้อ้างอิงคือ

$$\frac{2H}{\omega_s}\frac{d\omega}{dt}=P_{set,pu}+\frac{1-\omega/\omega_s}{R_p}-P_{e,pu}-D(\omega-\omega_s)$$

เมื่อ omega ใช้ rad/s และกำลังเป็น pu ค่า D = 0.5 จึงมี effective damping ในฐาน normalized frequency เท่ากับ D*omega_s และ effective static P-f slope เป็น

$$R_{eff}=\frac{1}{1/R_p+D\omega_s}=\frac{1}{20+0.5(2\pi50)}=0.005647\;\mathrm{pu/pu}$$

จึงไม่เรียกความชันรวมว่า 5% เมื่อต้องการแยกผล inertia ให้เทียบ H ที่ D/effective slope เดียวกัน Q-V droop ใช้ $E=14-D_qQ$ และ $D_q=0.05(14)/100=0.007$ V/VAR เมื่อฐาน Q = 100 VAR

ลูป V-I cascade มี design bandwidth 100 Hz และ 1 kHz พร้อม decoupling/load-voltage feedforward และ SPWM 10 kHz ต้องเทียบ discretization, delay, saturation และ anti-windup กับเฟิร์มแวร์โดยตรง การเทียบเฉพาะสมการลูปนอกไม่พิสูจน์พฤติกรรมทั้งระบบขนาดใหญ่

## 3.5 งานต่อยอดและเกณฑ์หลักฐาน

Active damping เป็นงานต่อยอดแยกจาก Stage 5d ซึ่งเป็น discrete-controller model ปัจจุบัน ควรแก้ data export, limits, source dynamics และ fault handling ก่อนเพิ่ม advanced control การย้ายไป TI C2000 หรือภาคกำลังแรงดันอื่นต้องมีเหตุผลจาก measured timing/measurement limits และทดสอบใหม่ ไม่อนุมานว่าเปลี่ยนบอร์ดแล้วผ่านทันที

BESS ยังคงอยู่ใน scope แต่ chemistry, cell count, BMS, charger และ interface ยังไม่ qualify เริ่มด้วยแหล่งจ่ายจำกัดกระแสและ auxiliary rails แยก; ห้ามขนานแบตเตอรี่ 24 V กับบัส 40 V และต้องมี energy sink ที่ qualify ก่อน load rejection

ผลตรวจรับจริงและการเปรียบเทียบกับ simulation จะเขียนในบทผลทดลองเมื่อมี raw evidence; ขณะนี้ยังไม่อ้างผล HIL หรือ powered bench

รายงาน simulation validation และขอบเขตผล Stage 5d/5e: `D:\workspace\engineering\vsg-project\docs\notes\simulation_validation_2026-10-13.md`.
