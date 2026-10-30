# บทที่ 5: การออกแบบฮาร์ดแวร์ต้นแบบ
# (Hardware Prototype Design)

> **ผู้เขียน:** ชินวัตร ดุมกลาง (Napoleon)
> **สถานะ:** ฉบับทบทวน 2026-10-20 — จุดออกแบบ 40 V / 100 W; hardware qualification PENDING

บทนี้แปลงโครงสร้างควบคุมที่ศึกษาใน simulation เป็นข้อกำหนดฮาร์ดแวร์สำหรับ islanded VSG การ compile หรือผลจำลองเฉพาะกรณีไม่ใช่การรับรองวงจรจริง เอกสารนี้ไม่ใช่ approved assembly drawing และไม่รายงาน bench/HIL ที่ยังไม่ได้ทำ

เอกสารอ้างอิงจุดออกแบบปัจจุบัน: `D:\workspace\engineering\vsg-project\docs\notes\design_baseline.md`

ข้อกำหนด shutdown และหลักฐานตรวจรับ: `D:\workspace\engineering\vsg-project\docs\notes\hardware_shutdown_and_bench_plan.md`

## 5.1 ภาพรวมสถาปัตยกรรม

แหล่งจ่าย DC ที่ปรับค่าและจำกัดกระแสได้จ่ายผ่าน pre-charge/bypass และ DC-link ไปยังสะพานสามเฟส ตัวเหนี่ยวนำ Lf ต่ออนุกรมแต่ละเฟส; แขนง Cf อนุกรม Rd ต่อจากจุดเอาต์พุตไปยัง neutral ของฟิลเตอร์ตามแบบจำลอง โหลดต่อที่จุดเอาต์พุต ไม่ได้ต่ออนุกรมผ่าน Cf/Rd ระบบ AD7606 วัดสัญญาณที่ผ่าน conditioning แล้วส่งให้ ESP32

BESS เป็นแหล่งพลังงานตามขอบเขตโครงงาน แต่ interface ยังต้องออกแบบ/qualify จึงไม่แสดง battery direct-parallel เป็นวงจรพร้อมสร้าง ใช้ auxiliary supply ที่ควบคุมแรงดันแยกสำหรับการทดสอบแรก

## 5.2 ฐาน per-unit และขอบเขตการเทียบระบบ

**ตารางที่ 5.1** ค่าฐานของต้นแบบ 100 VA, 50 Hz

| ปริมาณ | นิยาม | ค่า |
|---|---|---|
| Vphase_peak | ค่าอ้างอิง dq | 14 V |
| Vphase_RMS | 14/sqrt(2) | 9.8995 V |
| Vbase_LL | sqrt(3/2)*14 | 17.1464 V RMS |
| Ibase | 100/(sqrt(3)*Vbase_LL) | 3.3672 A RMS |
| Zbase | Vbase_LL²/100 | 2.94 Ω |
| Lbase | Zbase/(2*pi*50) | 9.3583 mH |
| Cbase | 1/(2*pi*50*Zbase) | 1082.69 µF |

**ตารางที่ 5.2** ค่าออกแบบที่ใช้กับฐานนี้

| พารามิเตอร์ | ค่า |
|---|---|
| Vdc / Pnom / f | 40 V / 100 W / 50 Hz |
| Lf / Rf | 1.2 mH (0.1282 pu) / 0.05 Ω |
| Cf / Rd | 10 µF (0.009236 pu) / 1 Ω อนุกรม Cf |
| H / D / Rp / Rq | 5 s / 0.5 / 0.05 / 0.05 |
| PWM/control target | 10 kHz |

แบบจำลองใช้กำลัง pu แต่ omega เป็น rad/s:

$$\frac{2H}{\omega_s}\dot\omega=P_{set,pu}+\frac{1-\omega/\omega_s}{R_p}-P_{e,pu}-D(\omega-\omega_s)$$

แปลงเป็น normalized frequency แล้ว damping เท่ากับ D*omega_s ทำให้ $R_{eff}=1/(1/R_p+D\omega_s)=0.005647$ pu/pu หรือประมาณ 0.565% Rp = 0.05 เป็น governor parameter เท่านั้น ฐาน AC นี้ไม่เท่ากับ DC bus และไม่ใช่ฐาน AC 24 V ของร่างเดิม

การใช้ H, normalized damping และ disturbances เดียวกันทำให้สมการลูปนอกบางส่วนเทียบกันได้ แต่ไม่ได้พิสูจน์ว่า switching dynamics, losses, thermal limits, source dynamics หรือ protection เหมือนระบบ 10 kVA/MW ทุกประการ ต้องกำหนด similarity ของส่วนที่ต้องการศึกษาแยกกัน

## 5.3 ภาคกำลังและ gate driver

แนวทางหลัก A ใช้ IRF540N หกตัวกับ IR2104 สามตัว IR2104 เป็น bootstrap non-isolated มี UVLO และ internally set dead-time; ค่า typical ประมาณ 520 ns จาก datasheet ไม่ใช่ measured dead-time ของวงจรนี้ ตรวจ gate charge, bootstrap voltage, gate resistance, parasitics, overshoot และความร้อนจริงก่อนกำหนด operating envelope

SD LOW ปิด HO และ LO; SD HIGH อนุญาตให้ขับ complementary outputs ส่วน IN LOW อย่างเดียวอาจเปิด LO ได้ ตรวจ polarity และอุปกรณ์จริงตาม [Infineon IR2104 datasheet](https://www.infineon.com/assets/row/public/documents/24/49/infineon-ir2104-ds-en.pdf)

ทางเลือก B คือ DRV8302 module ต้องตรวจ exact module schematic, MOSFET/capacitor ratings, buck, 3-PWM mode, fault/enable logic และ cooling ก่อนใช้งาน ไม่ใช้พิกัดชิปแทนพิกัดบอร์ด ไม่ถือว่า changing POWER_STAGE ทำให้ฮาร์ดแวร์ใหม่ผ่านการตรวจรับ

## 5.4 ระบบวัดและรับสัญญาณ

AD7606 + ACS712-20A เป็น baseline ตรวจ module RESET/power-up pulse, RANGE, OS straps, serial mode, VDRIVE, channel order, signed scale และ input conditioning จากบอร์ดจริง ค่าพิน ESP32 ใน source ไม่ใช่ header pinout ของโมดูล ADC

**ตารางที่ 5.3** หลักฐานการวัดที่ต้องมี

| รายการ | หลักฐาน |
|---|---|
| Zero-current offset / current gain | Raw ADC และ reference current รายช่อง |
| Voltage gain/common mode | Reference voltage และ divider/conditioning จริง |
| Conversion handshake | CONVST → BUSY assert → BUSY complete |
| Fault injection | BUSY stuck HIGH และ stuck LOW ทำให้ fault |
| Timing | ADC/control execution time และ missed-tick record |

ระบบวัดต้องไม่ saturate ในช่วง fault ที่ต้องตรวจ และต้องบันทึก noise/bandwidth การตั้ง software scale อย่างเดียวไม่ยืนยันความแม่นยำ

## 5.5 ฟิลเตอร์และบัส DC

**ตารางที่ 5.4** องค์ประกอบและสิ่งที่ต้อง qualify

| ส่วน | Baseline / requirement |
|---|---|
| LC + damping | 1.2 mH, 10 µF, 1 Ω; resonance ประมาณ 1453 Hz |
| Inductor | วัด saturation, ripple current, copper/core loss และอุณหภูมิ |
| Capacitor / Rd | ตรวจ ripple/pulse/continuous rating และ cooling |
| DC-link | เลือก capacitance/ripple/voltage จาก bus energy และ transient จริง |
| Pre-charge/discharge | คำนวณ pulse energy, time constant, switch/fuse และวัด residual voltage |
| Energy sink | Qualify ก่อน load rejection; source-only supply อาจรับกำลังย้อนกลับไม่ได้ |

ไม่ใช้ generic LM2596 module ต่อจาก nominal 40 V bus โดยตรง เพราะ recommended input ceiling ไม่เหลือ upward margin ([TI LM2596 datasheet](https://www.ti.com/lit/ds/symlink/lm2596.pdf)) เริ่มด้วย regulated auxiliary rails แยก หากใช้ bus-fed converter ต้องตรวจ input/transient rating ของโมดูลทั้งชุด

BESS ยังไม่กำหนด chemistry/cell count/BMS/charger/interface ห้ามต่อ battery 24 V ขนานกับ supply 40 V; nominal 36/48 V pack ไม่ใช่ regulated 40 V source ต้อง qualify interface หรือช่วง bus ใหม่ TVS เป็น transient clamp ไม่ใช่ sustained energy sink และต้องเลือกจาก clamp voltage/energy จริง ไม่ใช่ชื่อพาร์ท

## 5.6 Independent hardware shutdown

**ตารางที่ 5.5** ระบบป้องกันและขอบเขตหน้าที่

| ระบบ | หน้าที่ |
|---|---|
| Comparator + independent latch | Clear permit โดยไม่พึ่ง CPU และค้าง disabled หลัง fault หาย |
| AND permit logic | SD_PERMIT = MCU_REQUEST AND HARDWARE_PERMIT |
| External default-LOW / supervisor | ปิด gate เมื่อ MCU reset/unpowered หรือ logic rail ผิดปกติ |
| MCPWM fault / software FAULT | ชั้นเสริม; force PWM LOW ไม่แทนการปิดทั้ง HO/LO |
| Driver UVLO / dead-time | ตรวจวงจรจริง; ไม่แทน OCP และ thermal qualification |
| Current limit / fuse / pre-charge | ลดพลังงาน/ป้องกันตามขอบเขต ไม่แทน gate shutdown |

GPIO22 เป็น MCU_REQUEST เข้าวงจร permit ไม่ต่อ SD โดยตรง Comparator fault เข้า asynchronous CLEAR ของ latch และไป GPIO34/MCPWM F0 ผ่าน interface ที่ตรวจแล้ว; GPIO34 ต้องมี external pull-up 3.3 V สำหรับ open-collector branch ห้ามชอร์ต comparator กับ GPIO push-pull

Latch ต้องเริ่ม cleared และต้อง deliberate ARM ใหม่เมื่อ inputs healthy โดย MCU_REQUEST LOW; ปุ่ม ARM ที่ค้างหรือ fault ที่หายเองต้องไม่ทำให้ restart ตรวจ logic HIGH margin, power sequencing, propagation และกรณี driver supply อยู่แต่ logic supply หาย Threshold, sensing coverage, blanking และ total trip delay ยังต้อง qualify ไม่อ้าง end-to-end OCP <1 µs

## 5.7 เฟิร์มแวร์ ESP32

Source: `D:\workspace\engineering\vsg-project\hardware\esp32\vsg_controller\vsg_controller.ino`

ใช้ Arduino-ESP32 2.0.17 legacy APIs; การย้าย major version ต้อง port และตรวจใหม่ Timer ISR ส่ง task notification ส่วน high-priority control task ทำ ADC/SPI, floating-point control, PWM และ runtime state transitions

**ตารางที่ 5.6** การเชื่อมแบบจำลองกับ implementation

| ส่วน | การตรวจความสอดคล้อง |
|---|---|
| Swing/droop | หน่วย omega, power และ integration method |
| dq V-I cascade | Gains, decoupling, current/voltage limits และ anti-windup |
| PWM | เป้าหมาย 10 kHz, duty convention, phase alignment และ measured dead-time |
| Startup/fault | เจ้าของ state เพียง task เดียว; FAULT ไม่ถูก startup เขียนทับ |
| ADC/timing | Fresh conversion, calibrated scale, worst-case <100 µs และ missed ticks |

DRY_RUN_NO_POWER_STAGE = 1 เป็น default และ gate request ต้อง LOW การเริ่ม PWM หลัง force-low ต้อง initialize valid duties แล้ว restore generator actions อย่าง explicit; duty update เพียงอย่างเดียวไม่พอสำหรับ pinned driver Readiness flags ต้องอ้างหลักฐาน physical ที่ทำแล้ว ไม่ใช่ทดแทนการทดสอบ

## 5.8 ลำดับตรวจรับและเริ่มระบบ

1. ตรวจ continuity, polarity, discharge, grounding และ default-off เมื่อไม่มีไฟ MCU
2. Auxiliary-only: วัด SD, HO/LO และ independent latch เมื่อ fault/reset/logic power loss; ต้องไม่ restart เอง
3. Dry-run: วัด PWM, ADC, control timing และ fault ระหว่าง standby/bootstrap/soft-start
4. เมื่อมีหลักฐานผ่าน จึง pre-charge และเพิ่มระดับ DC energy แบบ current-limited ตาม test plan พร้อม load/thermal limits
5. ทดสอบ load rejection และ overload เมื่อ energy sink กับ operating envelope ผ่าน qualification แล้ว

Normal stop และ emergency trip เป็นคนละเส้นทาง: emergency fault ต้อง shutdown ทันทีผ่าน hardware path ไม่รอ software ramp ตรวจ bus residual voltage ด้วยมิเตอร์ก่อนทำงานต่อ วัด HO-to-VS ด้วย differential/isolated equipment ที่เหมาะสม ห้ามต่อ earth-referenced scope ground เข้าสวิตชิ่งโหนด

## 5.9 วัสดุ งบประมาณ และหลักฐาน

**ตารางที่ 5.7** สถานะรายการวัสดุ

| รายการ | แหล่งข้อมูล/สถานะ |
|---|---|
| Primary BoM | ตาราง 3.2 ใน `D:\workspace\engineering\vsg-project\docs\thesis\chapter3_methodology.md` |
| ราคาเดิม | Historical estimates วันที่ 2026-05-30; ไม่ใช่ current quotations |
| Shutdown/auxiliary/BESS | ต้อง finalize วงจรและเสนอราคาใหม่ |
| Hardware evidence | PENDING: waveform, calibration, thermal และ fault records |

เก็บ source revision, build flags, toolchain, wiring revision, instruments และ raw data ในแต่ละ run ผล load step เดิมประมาณ 136 W เป็น overload เทียบ nominal 100 W ไม่ใช่คำอนุญาตให้ใช้งานต่อเนื่องระดับนั้น

## 5.10 สถานะความสอดคล้องและงานที่เหลือ

**ตารางที่ 5.8** ประเด็นที่ตัดสินแล้วและที่ยังเปิด

| ประเด็น | สถานะ |
|---|---|
| 40 V / 14 V peak phase / 100 W | Current design baseline |
| Lf/Cf/Rd = 1.2 mH/10 µF/1 Ω | Current baseline; physical component qualification ยังต้องทำ |
| Stage 5d | Discrete-controller model; active damping เป็นงานต่อยอดต่างหาก |
| Stage 5e | Robustness extension; ระบุ fidelity/cases ใน validation report ไม่ใช้ averaged result เป็น switching proof |
| BESS/interface/energy sink | ยังไม่ qualify |
| HIL/bench/Chapter 6 results | ยังไม่มีหลักฐาน physical completion |

ร่าง DOCX เดิมเป็น historical drafts; review copies ที่สร้างใหม่ต้องมีวันที่/ที่มา ผลจำลองและข้อจำกัดในบทที่ 4 เป็นฐานออกแบบ ไม่ใช่ผลตรวจรับฮาร์ดแวร์

รายงาน simulation validation และขอบเขตผล Stage 5d/5e: `D:\workspace\engineering\vsg-project\docs\notes\simulation_validation_2026-10-13.md`.
รายงานระบุช่องว่าง DC-bus protection: source-current limiting อาจทำให้ bus sag โดยไม่เกิด overcurrent/thermal trip ต้อง qualify undervoltage/overvoltage interlock หรือออกแบบ sensing/protection เพิ่มก่อนใช้งานจริง โดยไม่เดา threshold หรือ ADC scale จาก study assumptions
