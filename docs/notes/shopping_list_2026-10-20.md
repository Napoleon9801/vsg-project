# รายการจัดซื้อ VSG — 2026-10-20

จัดทำโดย Codex desktop / GPT-6 ร่วมกับ VSG prototype research subagent

ฉบับละเอียดสำหรับส่งให้ AI agent จัดซื้อ: [procurement_agent_brief_2026-10-20.md](D:/workspace/engineering/vsg-project/docs/notes/procurement_agent_brief_2026-10-20.md) — มีรหัสรายการ เงื่อนไขตรวจสินค้า แบบฟอร์ม quote และขั้นตอนบันทึกคำสั่งซื้อ

Napoleon ยืนยันว่ายังไม่มี ESP32 และ AD7606 ส่วนเครื่องมือหลักยืมแล็บได้ จึงให้ความสำคัญกับชิ้นส่วนต้นแบบก่อน ไม่รวมราคาเก่าจาก BoM เป็นราคาปัจจุบัน และยังไม่มีการสั่งซื้อ

ฐานออกแบบ: islanded สามเฟส 40 V DC / 100 W nominal / 14 V peak ต่อเฟส / 50 Hz; ภาคกำลัง A ใช้ IRF540N + IR2104 อ้างอิง `D:\workspace\engineering\vsg-project\docs\notes\design_baseline.md`

## 1. ชุดแรกสำหรับเริ่มทดสอบ controller และ ADC

| รายการ | จำนวนซื้อ | เงื่อนไขเลือก |
|---|---:|---|
| ESP32-DevKitC-32E / WROOM-32E, flash 4 MB | 1 บอร์ด; สำรองอีก 1 ถ้างบพอ | ESP32 classic พร้อม USB-UART และขาครบ; ไม่แทนด้วย S3/C3/C6 โดยไม่ port/test firmware |
| สาย USB แบบรับส่งข้อมูล | 1–2 เส้น | ให้ตรงพอร์ตบอร์ด; DevKitC V4 ทางการใช้ Micro-B |
| AD7606 module รุ่นดั้งเดิม 8 ช่อง | 1 บอร์ด | ตรวจ schematic และรายการด้านล่างก่อนกดซื้อ; ไม่ซื้อเฉพาะ IC เปล่าถ้ายังไม่มี PCB |
| ACS712-20A module | ใช้ 3; ซื้อ 4 รวมสำรอง | รุ่น ±20 A, sensitivity 100 mV/A; เช็ก marking, filter และขั้วต่อของโมดูล |
| Header/socket, สายสัญญาณสั้น, test point | 1 ชุด | ตรวจ pitch ของบอร์ดจริง; สาย Dupont ใช้เฉพาะทดลอง logic ไม่ใช้ส่งกระแสภาคกำลัง |
| ชุด resistor/capacitor สำหรับวงจร logic และการทดลอง conditioning | 1 ชุดเล็ก | ใช้ค่าตาม schematic ในขั้นออกแบบ; ชุดทดลองไม่ใช่วงจรวัดที่ผ่านการตรวจรับแล้ว |

ESP32-DevKitC รุ่น WROOM-32E เป็นตัวเลือก classic ESP32 ที่มีเอกสารทางการ โค้ดปัจจุบันใช้ Arduino-ESP32 2.0.17; รุ่น C3/S3/C6 ไม่ใช่ตัวแทนที่ใช้โค้ดเดิมได้โดยอัตโนมัติ [Espressif board guide](https://documentation.espressif.com/esp-dev-kits/en/latest/esp32/esp32-devkitc/user_guide.html)

AD7606 ดั้งเดิมเป็น ADC 16-bit, 8 ช่อง simultaneous, 200 kSPS ใช้ analog supply 5 V และ VDRIVE ที่เลือก 3.3 V ได้ ตัว IC ไม่ได้แยกวงจรแบบ galvanic isolation [Analog Devices AD7606](https://www.analog.com/en/products/ad7606.html)

เงื่อนไข AD7606 ที่ต้องได้จากร้าน:

- เป็น AD7606 8 ช่องจริง ไม่ใช่ AD7606-6, AD7606-4 หรือ ADS1115
- มี schematic หรือเอกสารการตั้ง jumper/strap ของบอร์ดรุ่นนั้น
- ตั้ง serial interface และ VDRIVE = 3.3 V ได้ โดย analog supply ยังถูกต้อง
- เข้าถึง BUSY, CONVST, RESET, CS, SCLK และ DOUT ได้
- ตั้ง RANGE เป็น ±10 V ตาม firmware ปัจจุบันได้ และตั้ง oversampling ได้
- มีวิธีสร้าง RESET หลังเปิดเครื่อง; ไม่สมมติว่าทุกโมดูลทำให้แล้ว
- ไม่เปลี่ยนเป็น AD7606B โดยอัตโนมัติ แม้ผู้ผลิตระบุ pin compatibility; ต้องตรวจ timing/configuration ก่อน

ACS712 ใช้ 5 V และรุ่น 20 A มี sensitivity 100 mV/A; การตรวจ module PCB/filter/terminal ยังจำเป็น [Allegro ACS712 datasheet](https://www.allegromicro.com/-/media/files/datasheets/acs712-datasheet.pdf)

## 2. ภาคกำลังและโหลด — ขอราคา/ตรวจรุ่นก่อนสั่ง

จำนวนต่อไปนี้คือแผนสำหรับต้นแบบหนึ่งเครื่อง ไม่ใช่การอนุมัติวงจรให้จ่ายไฟได้ทันที

| รายการ | จำนวน | สเปกหรือเงื่อนไขจัดซื้อ |
|---|---:|---|
| IRF540NPBF, TO-220 | ใช้ 6; ซื้อ 8–10 | ซื้อจากแหล่งตรวจสอบได้; ใช้ gate driver และ thermal design จริง |
| IR2104STRPBF, SOIC-8 | ใช้ 3; ซื้อ 4–5 | ต้องตรง footprint PCB; ถ้าจะใช้ DIP ต้องเลือก ordering code ใหม่และตรวจ lifecycle |
| Bootstrap diode/capacitor, gate resistor, gate pulldown, driver decoupling | 3 driver / 6 gate ชุดย่อย | ปิดค่าจาก gate charge, supply, duty และ layout ก่อนซื้อ; ไม่ใช้ค่าทั่วไปเป็น final design |
| Filter inductor 1.2 mH | 3 | ขอ L-versus-current, Isat, Irms, DCR และ core-loss/temperature ขณะ PWM; ค่า Rf จำลอง 0.05 Ω ไม่ใช่ข้อเท็จจริงของคอยล์ซื้อมา |
| Filter capacitor 10 µF polypropylene film | ใช้ 3; ซื้อ 4 | เลือก power/pulse-capable part จาก AC/ripple/frequency rating; 100 VDC ขึ้นไปเป็นเพียงเกณฑ์คัดกรองเริ่มต้น ไม่แทนการตรวจ ripple/thermal |
| Damping resistor 1 Ω แบบ low-inductance | ใช้ 3; ซื้อ 4 | กำลังวัตต์/pulse rating ยังต้องคำนวณจาก ripple จริงก่อนสั่ง |
| โหลดเริ่มต้น 10 Ω, 50 W chassis mount | 3 | ต่อแบบ Y จะเป็นประมาณ 29.4 W รวมที่ 14 V peak ต่อเฟส; ต้องติดตั้งระบายความร้อนตาม datasheet |
| โหลดใกล้ nominal 3.0 Ω, 100 W chassis mount | 3 | ต่อแบบ Y จะเป็นประมาณ 98 W รวม หรือ 32.7 W/ตัว; ค่าใกล้ Rload 2.94 Ω จำลองแต่ไม่เท่ากัน |
| Heatsink + ฉนวน TO-220 + insulating shoulder washer + thermal compound | 1 ชุดสำหรับ MOSFET 6 ตัว | เลือกขนาดหลังประเมิน loss/layout; อย่าให้แท็บ drain ต่างโหนดลัดผ่าน heatsink |
| แผ่นระบายความร้อนโหลด/พัดลม/ตะแกรงกันสัมผัส | 1 ชุด | แยกพิกัดความร้อนจากชุด MOSFET; จับคู่ resistor mount กับ datasheet |
| PCB ภาคกำลังและ PCB logic/ADC | ตามแบบที่ตรวจแล้ว | สั่งหลัง schematic/layout review; ไม่ใช้ solderless breadboard เป็น power bridge |
| Terminal block, สายกำลัง, ferrule/lug, heat-shrink, standoff, กล่อง | 1 ชุด | กำหนดขนาดสาย/ขั้ว/ระยะตามกระแส, fault envelope และ layout จริงก่อนเลือก |

IRF540N เป็น MOSFET 100 V; ค่า headline current ไม่ใช่พิกัดกระแสต่อเนื่องของบอร์ดต้นแบบ [Infineon IRF540N](https://www.infineon.com/part/IRF540N)

ตรวจสถานะ ordering code แล้ว: IR2104STRPBF แบบ SOIC เป็นตัวเลือก Active/Recommended; IR2104PBF แบบ PDIP และ IR2104SPBF แบบ tube มีสถานะ Not for New Design ตามรายการของผู้ผลิต จึงต้องระบุรหัสเต็มในใบสั่งซื้อและจับคู่ footprint [Infineon IR2104S](https://www.infineon.com/part/IR2104S), [Infineon IR2104](https://www.infineon.com/part/IR2104)

Isat และ Irms ของ inductor เป็นคนละข้อจำกัด และแต่ละผู้ผลิตอาจใช้เกณฑ์เปอร์เซ็นต์ L ลดลงต่างกัน ต้องขอทั้งสองค่า ไม่สั่ง “1.2 mH 5 A” โดยไม่มีกราฟรองรับ [Coilcraft current ratings](https://www.coilcraft.com/en-us/resources/application-notes/basics-of-inductor-selection-%28from-electronic-desi/)

โหลด resistive ที่เสนอเป็นชุดทดสอบเริ่มต้น ใช้ P_total = 3 × (14/√2)² / R ไม่รวม reactive current ของโหลด R-L จำลอง หากต้องการเทียบกับโมเดลเดิมที่มี load inductance 1 mH/เฟส ต้องจัดหาเพิ่มและตรวจพิกัดแยก ไม่ถือว่าโหลด R ล้วนเทียบเท่า R-L เดิม

ตัวต้านทาน chassis-mount ต้องติดตั้ง heatsink/chassis ตาม datasheet จึงจะใช้พิกัดวัตต์ที่ระบุได้ ตรวจ derating ของรุ่นจริง [Vishay RH/NH](https://www.vishay.com/docs/30201/rhnh.pdf)

## 3. ของจำเป็นที่ยังต้องปิดแบบก่อนกำหนดรหัสซื้อ

| ชุดวงจร | จำนวนหน้าที่ | งานที่ต้องปิดก่อนซื้อ |
|---|---:|---|
| Voltage sensing/conditioning | 3 เฟส + 1 ช่อง DC bus ที่วางแผนเพิ่ม | phase-to-neutral/common-mode, reference, divider/amplifier/isolation ที่เหมาะสม; ช่อง Vdc ยังไม่ถูกใช้งานใน firmware ปัจจุบัน |
| Hardware OCP | 1 ระบบ ครอบคลุม failure modes | sensor/shunt, comparator, reference, hysteresis/blanking และ fault coverage; ACS712 feedback ไม่แทนวงจรนี้โดยอัตโนมัติ |
| Fault latch + AND/level interface + power supervisor | 1 ระบบ | fault-dominant, default-off, logic margin กับ IR2104, reset/ARM behavior |
| DC-bus UV/OV interlock | 1 ระบบ | ช่วงแรงดัน, threshold/hysteresis, latch และ sensing ที่ตรวจได้ |
| DC-link capacitor bank + local high-frequency decoupling | 1 ชุด | C, ripple current, ESR, voltage/transient margin และ physical layout; 2200 µF ใน Stage 5e เป็นสมมติฐาน ไม่ใช่ BoM ที่ล็อกแล้ว |
| Precharge/bypass + discharge + DC fuse/holder + disconnect | 1 ชุด | คำนวณ energy/time, resistor pulse, DC interrupt rating; ไม่ใช้ฟิวส์รถยนต์ 32 V โดยอัตโนมัติบนบัส 40 V |
| STOP/E-stop + deliberate ARM switch | 1 ชุด | เลือก contacts ตามวงจร interlock; ไม่สมมติว่าปุ่มตัวเล็กตัด DC-link current ได้ |
| Energy sink/brake + snubber/TVS ตามแบบ | 1 ระบบ | ช่วงแรงดันและ energy; TVS ไม่แทน sustained energy sink |

แผนวงจรและตรวจรับอยู่ที่ `D:\workspace\engineering\vsg-project\docs\notes\hardware_shutdown_and_bench_plan.md`

ยังไม่ซื้อแบตเตอรี่/BMS/charger/DC-DC interface จนกว่าจะปิดช่วงแรงดันและ power flow ของ BESS; ไม่ซื้อ DRV8302 มาซ้ำกับภาคกำลัง A เว้นแต่ตัดสินใจเปลี่ยนแนวทาง; ไม่ซื้อ LM2596 ทั่วไปมาเลี้ยงจากบัส nominal 40 V โดยตรง

## 4. รายการขอยืมแล็บ

| เครื่องมือ | จำนวน | ความสามารถที่ต้องตรวจ |
|---|---:|---|
| Adjustable DC bench supply แบบ CC/CV | 1 | ต้องได้ 40 V; แนะนำเครื่องช่วง 0–60 V ที่จ่าย 40 V ได้ราว 4–5 A เป็น capacity สำหรับการพัฒนา ไม่ใช่ค่าตั้ง current limit ครั้งแรก; ตรวจ power envelope |
| Auxiliary regulated supply | 1 ชุด | จ่าย 12 V gate driver และ 5 V sensors/ADC ได้; logic 3.3 V ตามบอร์ด; พิกัดรวม/grounding/power sequencing ต้องตรวจ |
| Oscilloscope | 1 | แนะนำ 4 ช่อง, 100 MHz, ≥1 GSa/s ตามโหมดที่ใช้ และ export waveform/CSV ได้ |
| Differential probe ที่เหมาะกับ switching node | อย่างน้อย 1; 2 ถ้าวัด VGS high/low พร้อมกัน | ตรวจ common-mode/differential rating, bandwidth/CMRR และ sensitivity สำหรับ VGS; passive ×10 ไม่ใช่ differential probe |
| Passive probes + ground springs | ตามช่อง scope | ใช้กับจุดอ้างอิงที่ถูกต้อง; สายกราวด์ scope ไม่ต่อ switching node |
| Multimeter | 1–2 | DC voltage, resistance/continuity; สายและ input protection สภาพดี |
| LCR meter | 1 | วัด L/C/R เริ่มต้น; การวัด small-signal อย่างเดียวไม่พิสูจน์ Isat |
| Current probe | 1 ถ้ามี | เป็นหลักฐานกระแสอิสระจาก sensor firmware; bandwidth ต้องพอสำหรับเหตุการณ์ที่วัด |
| Function generator / pulse source | 1 | ทดสอบ response ของ ADC/logic/protection ตาม fixture |
| Thermocouple/temperature logger | 1 ชุด | ดูความร้อน resistor, inductor, heatsink; IR camera เป็นทางเลือก |
| Soldering station + fume extraction + hand tools | 1 ชุด | หัวแร้งปรับอุณหภูมิ, flux, solder wick, คีมตัด/ปอก/ย้ำ, แว่นตา |
| Logic analyzer | ทางเลือก | ต้องรองรับอัตรา SPI ที่ใช้พร้อม sampling margin; ไม่ซื้อรุ่นช้าเพียงเพื่อ decode 15 MHz |

เครื่องจ่าย 0–30 V ช่องเดียวไม่ถึงจุดออกแบบ 40 V การต่อหลายช่องอนุกรมต้องเป็นรุ่นที่คู่มือรองรับ และกระแสพิกัดไม่บวกกันในอนุกรม เครื่องมือที่ยืมได้ยังต้องยืนยันรุ่นจริง

การวัด high-side gate ต้องวัด gate-to-source ด้วยอุปกรณ์ที่รองรับ floating measurement; ไม่ยกสายดินของ oscilloscope [Tektronix floating measurements](https://www.tek.com/en/documents/technical-brief/floating-oscilloscope-measurements-and-operator-protection)

## ลำดับใช้เงิน

1. ซื้อ ESP32 classic + สายข้อมูล และหา AD7606 module ที่มีเอกสารตรงข้อกำหนด
2. ซื้อ current sensors/อุปกรณ์ logic แล้วทดสอบ ADC, PWM, calibration ด้วยเครื่องมือแล็บ
3. ขอราคาคอยล์และเลือก power parts ให้ตรง PCB พร้อมปิด voltage sensing/protection schematic
4. สั่ง PCB/filter/load/cooling และประกอบเมื่อแบบครบ
5. BESS เป็นชุดซื้อภายหลังตาม interface ที่เลือก

ยังไม่ตีราคารวม เพราะไม่มีงบที่ผู้ใช้กำหนดและยังไม่ได้ตรวจใบเสนอราคาจริงของโมดูล/คอยล์/PCB ชุดรายการนี้แยกสิ่งที่สั่งได้ออกจากหน้าที่วงจรที่ยังต้องออกแบบ เพื่อไม่ให้ซื้อผิดแล้วเปลี่ยนภายหลัง
