# ใบตรวจสายและตรวจรับ VSG — แบบฟอร์มยังไม่ได้ทดสอบ

วันที่จัดทำ 22 ตุลาคม 2026 · ใช้คู่กับ [คู่มือต่อวงจร](D:/workspace/engineering/vsg-project/docs/notes/wiring_manual_th_2026-10-22.md)

**ทุกช่องเริ่ม PENDING ไม่ถือเป็นผล PASS** คัดลอกไฟล์นี้แยกตาม assembly/run แล้วกรอกค่าจริง เก็บรูปและ oscilloscope/raw data ที่ตรวจย้อนกลับได้

## A. ระบุ assembly

| รายการ | ค่าจริง / หลักฐาน |
|---|---|
| Run ID / วันที่เวลา UTC+7 | PENDING |
| ผู้ประกอบ / ผู้ตรวจ | PENDING |
| Schematic revision / PCB revision | PENDING |
| ESP32 board/module marking + รูปหน้า/หลัง | PENDING |
| ADC chip/module/revision + schematic | PENDING |
| ACS712 marking และ board filter 3 ตัว | PENDING |
| Driver / MOSFET MPN, manufacturer, lot | PENDING |
| Firmware SHA-256 / build flags / toolchain | PENDING |
| DC source รุ่น / sink capability / output-earth relationship | PENDING |
| Aux supplies รุ่น / current limit / earth relationship | PENDING |
| Scope/probes รุ่น / differential rating / calibration | PENDING |
| Meter/reference source/uncertainty | PENDING |
| Evidence folder แบบ absolute path | PENDING |

## B. สาย logic และ ADC

ระบุ connector:pin จริงทั้งสองฝั่ง อย่าเขียนเพียง GPIO number แล้วนับตำแหน่ง header เอง ตรวจขณะไม่มีไฟและ capacitor discharge แล้ว

| ID | สัญญาณตามแบบ | ขั้วต้นทางจริง | ขั้วปลายทางจริง | Continuity / shorts / polarity | ผู้ตรวจ / รูป |
|---|---|---|---|---|---|
| D01 | GPIO15 → CS | PENDING | PENDING | PENDING | PENDING |
| D02 | GPIO14 → RD/SCLK | PENDING | PENDING | PENDING | PENDING |
| D03 | DOUTA → GPIO12 | PENDING | PENDING | PENDING | PENDING |
| D04a | GPIO2 → CONVST A | PENDING | PENDING | PENDING | PENDING |
| D04b | trigger เดียวกัน → CONVST B | PENDING | PENDING | PENDING | PENDING |
| D05 | BUSY → GPIO4 | PENDING | PENDING | PENDING | PENDING |
| D06 | hardware RESET source → RESET | PENDING | PENDING | PENDING | PENDING |
| D07 | GPIO13 ไม่ต่อ ADC data input | PENDING | NC ที่ยืนยัน | PENDING | PENDING |
| D08 | 3.3 V → VDRIVE | PENDING | PENDING | PENDING | PENDING |
| D09 | analog 5 V → module AVCC supply | PENDING | PENDING | PENDING | PENDING |
| D10 | ADC/MCU signal return ตาม grounding drawing | PENDING | PENDING | PENDING | PENDING |
| C01 | GPIO25 → qualified interface → IN_A | PENDING | PENDING | PENDING | PENDING |
| C02 | GPIO26 → qualified interface → IN_B | PENDING | PENDING | PENDING | PENDING |
| C03 | GPIO27 → qualified interface → IN_C | PENDING | PENDING | PENDING | PENDING |
| C04 | GPIO22 → MCU_REQUEST ของ permit | PENDING | PENDING | PENDING | PENDING |
| C05 | 3.3 V FAULT_N branch → GPIO34 | PENDING | PENDING | PENDING | PENDING |
| C06a | SD_PERMIT → SD_A | PENDING | PENDING | PENDING | PENDING |
| C06b | SD_PERMIT → SD_B | PENDING | PENDING | PENDING | PENDING |
| C06c | SD_PERMIT → SD_C | PENDING | PENDING | PENDING | PENDING |

## C. ADC configuration

| เรื่อง | ต้องได้ | ค่าจริง/ภาพ/trace |
|---|---|---|
| Serial straps | PAR/SER/BYTE SEL=1, DB15/BYTE SEL=0 ตาม actual module mapping | PENDING |
| RANGE | ±10 V | PENDING |
| OS2:0 | 000 | PENDING |
| VDRIVE และ output buffers | 3.3 V compatible | PENDING |
| RESET | power-up pulse ตาม datasheet; inactive ก่อนอ่าน | PENDING |
| ADC supplies/reference/STBY | ตาม schematic ที่อนุมัติ | PENDING |
| Boot strap interaction | ESP32 boot ได้ทุก power sequence ที่กำหนด | PENDING |
| SPI | mode 2, measured SCLK/timing; V1…V6 จาก DOUTA | PENDING |
| BUSY | assertion/completion และ stuck-HIGH/LOW detection | PENDING |

## D. สาย analog

| Channel | สัญญาณ | Connector:pin จริง | Analog return/reference จริง | รูป/continuity |
|---|---|---|---|---|
| V1 | ACS_A VOUT | PENDING | PENDING | PENDING |
| V2 | ACS_B VOUT | PENDING | PENDING | PENDING |
| V3 | ACS_C VOUT | PENDING | PENDING | PENDING |
| V4 | S01 phase A conditioning output | PENDING | PENDING | PENDING |
| V5 | S01 phase B conditioning output | PENDING | PENDING | PENDING |
| V6 | S01 phase C conditioning output | PENDING | PENDING | PENDING |
| V7 | Unused หรือ future bus; firmware ปัจจุบันไม่อ่าน | PENDING | PENDING | PENDING |
| V8 | Unused | PENDING | PENDING | PENDING |

## E. ตรวจภาคกำลังทุกเฟส

แต่ละช่องต้องมีผลตรวจจริง ไม่ใช้เครื่องหมายเดียวแทนทั้งสามเฟส

| การเชื่อมต่อ/ตรวจ | A | B | C |
|---|---|---|---|
| DC_LINK_P → QH Drain | PENDING | PENDING | PENDING |
| QH Source ↔ QL Drain ↔ SW ↔ driver VS | PENDING | PENDING | PENDING |
| QL Source → DC_LINK_N ตาม power-return layout | PENDING | PENDING | PENDING |
| HO → gate resistor → QH Gate | PENDING | PENDING | PENDING |
| LO → gate resistor → QL Gate | PENDING | PENDING | PENDING |
| Gate-source pulldown ของ QH อ้างอิง QH Source | PENDING | PENDING | PENDING |
| Gate-source pulldown ของ QL อ้างอิง QL Source | PENDING | PENDING | PENDING |
| VCC/COM decoupling และ return | PENDING | PENDING | PENDING |
| Bootstrap diode anode=VDRV, cathode=VB | PENDING | PENDING | PENDING |
| CBOOT คร่อม VB–VS | PENDING | PENDING | PENDING |
| SW → L → ACS primary → OUT | PENDING | PENDING | PENDING |
| ACS positive current direction จาก bridge ไป output | PENDING | PENDING | PENDING |
| OUT → Rd อนุกรม Cf → N_F | PENDING | PENDING | PENDING |
| OUT → load branch → N_LOAD | PENDING | PENDING | PENDING |
| Voltage sense ที่ OUT ตาม reference ที่อนุมัติ | PENDING | PENDING | PENDING |
| MOSFET tab/heatsink insulation หลังขันจริง | PENDING | PENDING | PENDING |
| Wire gauge/length/connector torque/rating | PENDING | PENDING | PENDING |

## F. DC input / protection / grounding

| งานตรวจ | schematic reference + ค่าจริง + ผล |
|---|---|
| N_F / N_LOAD relation และไม่มีการ bond ลง DC−/PE โดยไม่ได้ออกแบบ | PENDING |
| AGND/DGND/COM/DC return/USB/PE drawing | PENDING |
| Fuse และ DC disconnect rating/interrupt capability | PENDING |
| Precharge resistor/pulse rating, bypass/interlock | PENDING |
| DC-link capacitance/voltage/ESR/ripple/local decoupling | PENDING |
| Discharge path และวิธีวัด residual voltage | PENDING |
| Bus sensing + independent UV/OV threshold/hysteresis | PENDING |
| OCP sensing coverage/threshold/hysteresis/blanking | PENDING |
| Async-clear latch, MCU_REQUEST/SD_PERMIT default-off | PENDING |
| Aggregate/latched-fault feedback ไป MCU; แยก startup unarmed จาก trip; ไม่มี output contention | PENDING |
| ARM debounce/edge + held-button behavior | PENDING |
| STOP/E-stop clear/inhibit behavior | PENDING |
| Driver/logic rail supervision และ rail-loss response | PENDING |
| Energy sink/backfeed/load-rejection plan | PENDING |
| Load/semiconductor/inductor thermal assembly | PENDING |

## G. Calibration — ทำสำเนาตารางเพิ่มต่อจุดทดสอบ

| Channel | Reference input + uncertainty | Raw count | ADC voltage | Converted physical value | Error | Supply / temperature | PASS/FAIL/evidence |
|---|---|---|---|---|---|---|---|
| V1 / ia | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| V2 / ib | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| V3 / ic | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| V4 / va | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| V5 / vb | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |
| V6 / vc | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |

กำหนด tolerance/uncertainty budget ก่อนวัด: **PENDING** ตรวจศูนย์ ค่าบวก และค่าลบสำหรับช่องที่ออกแบบรองรับ bipolar โดยใช้อุปกรณ์อ้างอิงที่เหมาะสม ไม่ส่ง negative voltage เข้า pin ที่ไม่รองรับ การตรวจ channel order ให้กระตุ้นทีละช่อง

## H. Acceptance evidence

| Test | เกณฑ์ที่ต้องบันทึก | ผล/ไฟล์หลักฐาน |
|---|---|---|
| MCU off/reset/USB unplug | SD LOW; gates disabled; no restart | PENDING |
| Logic rail loss แต่ driver rail ยังอยู่ | final SD disabled | PENDING |
| PWM carrier / phase carriers | target 10 kHz, aligned carriers | PENDING |
| Control response | account every cycle; worst-case <100 µs; document budget/counters | PENDING |
| ADC reset/handshake | correct reset/BUSY/CS/SCLK/DOUT timing | PENDING |
| ADC stuck HIGH / stuck LOW | FAULT; no gate enable | PENDING |
| Zero-current + signed gain calibration | matches predefined error budget | PENDING |
| Independent OCP pulse with CPU unavailable | latch clears; measure comparator→SD→both VGS | PENDING |
| UV / OV / STOP / rail supervision | independent latched shutdown | PENDING |
| ARM held during fault/recovery | no automatic re-arm | PENDING |
| Fault during standby/bootstrap/soft-start | no fault overwrite or restart | PENDING |
| Gate waveform / bootstrap / dead-time | within selected parts' reviewed limits | PENDING |
| First energy-limited test | signed operating envelope + measurements | PENDING |

## I. แผน powered run — ต้องกรอกก่อนจ่ายบัส

| Parameter | Approved value / rationale |
|---|---|
| Vbus start/max และ independent UV/OV thresholds | PENDING |
| Supply current limit/power envelope | PENDING |
| Load connection/resistance/power rating/cooling | PENDING |
| OCP threshold / measured trip delay | PENDING |
| VGS/VDS/ADC-input stop limits | PENDING |
| Temperature stop limits + sensor positions | PENDING |
| Run duration / increase steps / stop procedure | PENDING |
| Returned-energy capability | PENDING |
| ผู้ตรวจ / วันที่ / evidence review | PENDING |

หลัง STOP ต้องตัดแหล่งพลังงานตามแบบ รอ discharge แล้ววัด residual voltage ก่อนจับวงจร ไม่ใช้จำนวนวินาทีคงที่เป็นหลักฐานว่าไม่มีพลังงาน

## J. Release decision

- [ ] ไม่มี HOLD ที่เกี่ยวกับ operating point นี้
- [ ] Schematics/netlist/BoM/assembly ตรง revision ที่ลงชื่อ
- [ ] Evidence T0–T6 ตรวจครบ; diagnostic ใช้ข้อมูลจริง ไม่ใช่ dry-run synthetic values
- [ ] Fault/rail loss/held ARM/default-off ผ่านตามหลักฐาน
- [ ] Powered test envelope กรอกครบและได้รับการตรวจทางวิศวกรรม
- [ ] Firmware readiness flags สะท้อน evidence จริง ไม่ได้เปลี่ยนเพื่อข้าม guard

**สถานะเริ่มต้น: NOT RELEASED — physical qualification PENDING**
