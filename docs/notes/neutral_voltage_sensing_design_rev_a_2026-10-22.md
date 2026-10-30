# แบบ neutral และ voltage sensing — Rev A

22 ตุลาคม 2026 · Option A, islanded 40 V / 100 W · **Schematic design freeze สำหรับทำ detailed CAD/fixture; ยังไม่ release PCB หรือ power operation**

## 1. ข้อสรุปที่กำหนดแล้ว

1. รวมจุดดาว filter และโหลดเป็น **N_AC จุดเดียว**: `N_F = N_LOAD = N_AC` สำหรับ balanced Y-load ของต้นแบบนี้
2. **ไม่ hard-bond N_AC เข้ากับ DC_LINK_N, AGND, ESP32 GND หรือ PE** ไม่มี neutral wire กลับ bridge และไม่มีการเพิ่ม DC-link midpoint ในแบบนี้
3. กำหนด `AGND_SENSE` เป็น quiet reference ที่ต่อกับ `DC_LINK_N` ณ reference star ที่ออกแบบไว้ พร้อม reference ร่วมของ ADC/logic; return จาก gate/กระแสกำลังต้องไม่วิ่งผ่าน copper ของ ADC
4. วัด `OUT_A/B/C − N_AC` ด้วย difference amplifier gain **1/4** โดยใช้ OPA4197ID หนึ่งตัวสำหรับ phase 3 ช่อง และ bus-buffer อีก 1 ช่อง
5. ใช้ analog rails **+12 V / −12 V เทียบ AGND_SENSE** จาก regulated auxiliary supply แยกจาก DC bus ในรอบ bench ไม่ใช้ราง −12 V เป็น neutral
6. OUT ของ phase amplifier ไป ADC V4/V5/V6; bus-buffer ไป V7 โดย **firmware ปัจจุบันยังไม่อ่าน V7**

ไม่มีการเปลี่ยน firmware หรือ flash บอร์ดในงานนี้ ค่า `V_DIVIDER_GAIN=4` เดิมตรงกับ phase gain ที่เลือก ส่วน bus measurement ต้องมีงาน firmware แยก

![Neutral and sensing circuit overview](D:/workspace/engineering/vsg-project/hardware/sensing/rev_a/sensing_overview.png)

ไฟล์ประกอบ: [logical connection table](D:/workspace/engineering/vsg-project/hardware/sensing/rev_a/logical_connections.csv) · [BoM](D:/workspace/engineering/vsg-project/hardware/sensing/rev_a/sensing_bom.csv) · [SVG diagram](D:/workspace/engineering/vsg-project/hardware/sensing/rev_a/sensing_overview.svg) ตาราง connection เป็น named-net specification ไม่ใช่ KiCad/EDA netlist ที่ผ่าน ERC แล้ว

## 2. Neutral topology และขอบเขตการใช้

```text
SW_A → L_A → ACS_A → OUT_A ── RLOAD_A ───┐
                          └─ Rd_A ─ Cf_A ┤
SW_B → L_B → ACS_B → OUT_B ── RLOAD_B ───┤
                          └─ Rd_B ─ Cf_B ┤── N_AC [one physical star]
SW_C → L_C → ACS_C → OUT_C ── RLOAD_C ───┤
                          └─ Rd_C ─ Cf_C ┘

N_AC → dedicated sense lead → three amplifier negative-input resistor chains
AGND_SENSE → quiet reference connection → DC_LINK_N
No copper bond: N_AC ↛ AGND_SENSE / DC_LINK_N / PE
```

ใช้สาย sense ของ N_AC แยกจาก conductors รับกระแสของ load/filter และยึดขั้วไม่ให้หลวม ตำแหน่งสาย sense อยู่ที่ star จริง ไม่อาศัย ground clip ของเครื่องมือ

คำว่า floating ในที่นี้หมายถึง **ไม่มี hard bond** เท่านั้น sensing network สร้างทางตัวต้านทานไป reference จึงไม่ใช่ galvanic isolation ที่ common-mode เฉลี่ย 20 V และสามเฟสสมดุล วงจรดึงกระแสจาก neutral รวมประมาณ 1.2 mA และจาก phase-side networks รวมประมาณ 1.2 mA อีกส่วนหนึ่ง

ที่ balanced ideal three-wire operating point ใช้ projection `v_SW_xN = v_pole_x − mean(v_pole_A,B,C)` เพื่อลบ common-mode ของ switching poles นี่ไม่ใช่ `OUT_x−N_AC` หลัง filter โดยตรง; ยังต้องผ่าน dynamics ของ L และ Rd-Cf ด้วย Source model เดิมใช้ grounded neutral กับ ideal phase sources ดังนั้น **ยังอ้าง switching common-mode/ripple equivalence ไม่ได้** ต้องเพิ่ม floating-star/zero-sequence และ parasitic/sensing loading ใน model ก่อนใช้ตัดสิน common-mode stress ไม่แก้ model เดิมเงียบ ๆ

Rev A นี้ไม่อนุมัติ grid connection, external neutral-earth bond, neutral conductor กลับแหล่งอื่น, single-phase load operation หรือ unbalanced-load performance ทั้งหมดนั้นต้อง review topology/control ใหม่

## 3. Operating envelope ของ sensing board

เป็นข้อกำหนดออกแบบ ไม่ใช่ผลวัดว่าภาคกำลังอยู่ในช่วงนี้แล้ว:

| ตัวแปร | ช่วงที่เลือกสำหรับ normal sensing |
|---|---|
| OUT_x และ N_AC แต่ละเส้นเทียบ AGND_SENSE | −2 ถึง +50 V |
| OUT_x − N_AC | ±24 V สูงสุดสำหรับช่วง normal ที่เลือก |
| Phase ADC output | ±6 V; ที่ nominal ±14 V phase ได้ ±3.5 V |
| OPA input node ตาม ideal circuit | OUT_x/5 = −0.4 ถึง +10 V |
| Analog supply | ±12 V, tolerance ±5%; rail magnitude 11.4–12.6 V |
| Bus measurement | 0–50 V → 0–5 V; nominal 40 V → 4 V |
| Fault calculation envelope | ทุก source input จำกัด magnitude 60 V สำหรับคำนวณ bounded DC injection เท่านั้น |

60 V ไม่ใช่ continuous bus approval และไม่ใช่ surge/ESD withstand rating ห้ามใช้ผลคำนวณนี้แทน TVS/snubber/rail supervision ของระบบ ถ้า waveform จริงออกนอก normal envelope ให้หยุดและ review ไม่ขยายช่วงจาก absolute maximum rating

## 4. วงจร phase หนึ่งช่อง — ทำซ้ำ 3 ชุด

```text
OUT_x ── 10k ─ 10k ─ 10k ─ 10k ── P_x ──→ U1 +IN
                                      │
                                  10k || Cgx
                                      │
                                  AGND_SENSE

N_AC  ── 10k ─ 10k ─ 10k ─ 10k ── M_x ──→ U1 −IN
                                      │
                                  10k || Cfx
                                      │
                               U1 OUT = V_SENSE_x
```

- Resistors ทุกตัวใน gain network: **10.000 kΩ, ±0.01%, ≤5 ppm/°C, 0805, ≥0.25 W**; candidate ที่ตรวจ family spec แล้ว `Vishay PLT0805Z1002LBTS` ตรวจ stock/price และ termination ก่อนสั่ง
- ใช้ **10 ตัวต่อเฟส = 30 ตัว**; input 40 kΩ แต่ละข้างสร้างจาก 4 ตัวอนุกรมเพื่อใช้ค่าเดียวและแบ่ง working voltage
- `Cgx = Cfx = 1.0 nF C0G/NP0 ≥50 V`, absolute tolerance ≤1%, **จับคู่ให้ต่างกันไม่เกิน 0.1%** ด้วยวิธีวัดที่ uncertainty เพียงพอ; วางคู่ใกล้กันและ routing สมมาตร ห้ามแทน X7R ตามค่า capacitance อย่างเดียว
- Cgx ขนาน resistor 10 kΩ จาก +IN ลง AGND; Cfx ขนาน feedback resistor 10 kΩ ไม่ใช่ capacitor ต่อคร่อม +IN/−IN

Ideal transfer:

`V_SENSE_x(s) = 0.25 × [OUT_x(s) − N_AC(s)] / (1 + s × 10 kΩ × 1 nF)`

DC reconstruction: `Vphase = 4 × Vadc`; การ calibration จริงต้องประเมิน offset/gain เพิ่มโดยไม่เปลี่ยน sign หรือ channel order

## 5. U1 pin map — OPA4197ID, SOIC-14 top view

จาก TI OPAx197 datasheet pin-functions table; ยึด pin-1 marker และ package drawing เมื่อสร้าง footprint

| U1 pin | หน้าที่ | Net |
|---:|---|---|
| 1 | OUT A | V_SENSE_A |
| 2 | −IN A | M_A |
| 3 | +IN A | P_A |
| 4 | V+ | APLUS12 |
| 5 | +IN B | P_B |
| 6 | −IN B | M_B |
| 7 | OUT B | V_SENSE_B |
| 8 | OUT C | V_SENSE_C |
| 9 | −IN C | M_C |
| 10 | +IN C | P_C |
| 11 | V− | AMINUS12 |
| 12 | +IN D | BUS_DIV |
| 13 | −IN D | V_SENSE_BUS |
| 14 | OUT D | V_SENSE_BUS; ต่อกลับ pin13 เป็น voltage follower |

ไม่ใช้ pin map ของ OPA197 single หรือ OPA2197 dual แทน quad

## 6. S02 bus sensing ที่เพิ่มได้บนช่องที่สี่

```text
DC_LINK_P ── [9 × 10k in series] ── BUS_DIV ──→ U1 pin12
                                      │
                                   10k || 10nF
                                      │
                                  AGND_SENSE
U1 pin14 ↔ pin13 → V_SENSE_BUS → output-selection contact → ADC V7
```

ใช้ precision 10 kΩ ชนิดเดียวกับ phase 10 ตัวเพิ่ม รวม phase+bus **40 ตัว**; bus capacitor 10 nF C0G ≥50 V, ±5% ได้สำหรับ low-bandwidth telemetry

Divider ratio=0.1, Thevenin resistance=9 kΩ, pole≈1.768 kHz จึงต้องใช้ `Vbus = Vadc ×10` เมื่อเพิ่ม firmware อ่านช่อง7 แต่ยังไม่ถือเป็น DC UV/OV hardware protection และไม่ใช้ร่วม comparator โดยเพิ่มโหลดเข้า BUS_DIV โดยไม่คำนวณใหม่

## 7. Analog rails, decoupling และ bounded back-power current

ที่ U1: 100 nF ceramic ≥25 V จาก pin4 ลง AGND และ pin11 ลง AGND ใกล้ supply pins; bulk 4.7 µF ≥25 V อย่างละหนึ่งที่ทั้งสอง rail (negative-rail electrolytic: ขั้วบวกอยู่ AGND) ใช้ regulator/supply ที่รองรับ load และ startup ตามจริง

เพิ่ม **1 kΩ ±1%, 0.5 W bleeder** จาก APLUS12→AGND และ AGND→AMINUS12 อย่างละตัว ค่ากำลัง nominal 0.144 W/ตัว; ที่12.6 VและRmin990Ω≈0.16036 W/ตัว; เว้นพื้นที่ความร้อน

Bound แบบ DC nominal-R: `6×60/40k + 60/90k ≈ 9.67 mA` เมื่อรวมinputRต่ำลง0.01%และbleederสูงขึ้น1% ได้ off-rail bound≈9.765 V; bleederที่12 Vยังดึงได้อย่างน้อย11.88 mA จึงจำกัดDC rail riseภายใต้สมมติฐานนี้ แต่ railที่ไม่มีไฟยังอาจยกขึ้นใกล้9.765 V **ไม่ได้เป็นศูนย์หรือ valid supply** ห้ามกล่าวว่าแก้power-off safetyครบแล้ว; supervisorต้องตรวจแหล่งจ่ายจริงและreject phantom power

นี่ไม่จำลอง internal protection diodes, capacitive spikes, dynamic rail collapse, resistor faults หรือทุก partial-power state ผลทั้งหมดนั้นเป็น bench/interface acceptance ตามหมวด12

## 8. Output interface ไป ADC และ default-ground selection

ไม่เพิ่ม RC series บน Vx โดยสุ่ม เพราะ AD7606 ระบุ matched series resistance บน VxGND ด้วย หลายโมดูล hard-tie VxGND ลง AGND จึงต้องอ่านวงจรโมดูลจริงก่อนเพิ่ม network ใด ๆ

Rev A ใช้ output link 0 Ω และสายสั้น; ให้ total capacitance ที่ opamp เห็นรวม module/cableอยู่ในขอบเขตที่ตรวจความเสถียรได้ ห้ามอนุมานจากการอ่านแรงดัน DC เพียงอย่างเดียว

เลือก K1/K2 เป็น **G6K-2P-Y DC5 non-latching DPDT** สำหรับ default-ground signal selection (สอง relay ครบสี่ช่อง):

| Contact | COM | NC เมื่อ coil ไม่ทำงาน | NO เมื่ออนุญาต connect |
|---|---|---|---|
| K1 pole A | ADC V4 | AGND_SENSE | V_SENSE_A ผ่าน0Ω |
| K1 pole B | ADC V5 | AGND_SENSE | V_SENSE_B ผ่าน0Ω |
| K2 pole A | ADC V6 | AGND_SENSE | V_SENSE_C ผ่าน0Ω |
| K2 pole B | ADC V7 | AGND_SENSE | V_SENSE_BUS ผ่าน0Ω |

เพิ่ม100 kΩจาก COM แต่ละ pole ลง AGND เพื่อไม่ให้ ADC input ลอยระหว่าง contact transition และเพิ่มโหลดเล็กน้อย ขา contact ใน manufacturer drawing เป็น **bottom view** และ coil มี polarity; ต้อง map footprint จาก drawing จริงก่อน fabrication ไม่เดาหมายเลขขาจากด้านบน

ขับ **หนึ่ง 2N3904 ต่อหนึ่ง relay**: emitter→AGND, collector→coil−, coil+→5V_RELAY; base ผ่าน1 kΩจาก `AFE_CONNECT_DRIVE`, base-emitter100 kΩ; flyback1N4148 anodeที่collector/cathodeที่coil+ ทำซ้ำสองชุด Outputของ S05 interface ต้อง source base currents รวมได้ตาม saturation calculation ไม่ต่อ raw open-drain signal ตรงแล้วหวังให้ drive ได้

`AFE_CONNECT_DRIVE` เป็น external qualified rail-good interface มี default LOW; ต้อง healthy ทั้ง analog±12, ADC5V, VDRIVE3.3 และไม่มี shutdown request **ไม่ใช้ GPIO เปิดทิ้งไว้** แยกจาก fast gate shutdown

S05/permit integration ต้องบังคับลำดับ: rails healthy → connect contacts → รอ operate/bounce/AFE settling ตามค่าที่ตรวจจริง → ยืนยันข้อมูลวัดสดและสมเหตุผล → จึงอนุญาต ARM/gate permit การปล่อย ADC รับ0 VจากNCระหว่าง startup ไม่ใช่หลักฐานว่าแรงดันoutputเป็น0จริง ทุกrail faultต้องยกเลิก gate permitทันทีผ่านhardwareและยกเลิกmeasurement-valid; relayใช้จัดการsignalตามลำดับเพิ่มเติม ไม่ใช้เป็นตัวตัดfaultหลัก ยังต้องimplement state/feedbackและsettling criteriaใน S05/firmware integrationก่อนrelease

**ยังไม่ claim ว่า relay นี้ป้องกัน ADC power-loss ครบ:** release delay, flyback และ contact bounce อาจช้ากว่า ADC AVCC collapse ต้องวัด/ออกแบบ hold-up หรือ faster isolation ก่อน release; การ kill gate ไม่ทำให้ analog output หายทันที Relay datasheet ให้ minimum-load reference10 µA/10 mV; หลังเพิ่ม100 kΩได้ประมาณ35 µAที่3.5 V แต่ใกล้ zero crossingต่ำกว่านั้น จึงต้อง qualify low-level contact reliability ไม่ใช้ค่าข้างต้นเป็น guarantee

## 9. Connector contract สำหรับ detailed CAD

เลขต่อไปนี้เป็น **ขั้วที่กำหนดให้บอร์ดใหม่ของเรา** ไม่ใช่หมายเลข header ของ AD7606 ที่ซื้อ:

| Connector | Pin → Net | หมายเหตุ |
|---|---|---|
| J1 sense inputs | 1 OUT_A; 2 OUT_B; 3 OUT_C; 4 N_AC; 5 DC_LINK_P; 6 AGND_SENSE | connector voltage/spacingต้องรองรับ envelope; resistor chainsใกล้ทางเข้า |
| J2 analog supply | 1 APLUS12; 2 AGND_SENSE; 3 AMINUS12 | keyed, ห้ามสลับกลับ |
| J3 ADC harness | 1 ADC_V4; 2 AGND; 3 ADC_V5; 4 AGND; 5 ADC_V6; 6 AGND; 7 ADC_V7; 8 AGND | mapปลาย ADCจริงทีหลัง; signal-returnอยู่ติดกัน |
| J4 control/relay | 1 5V_RELAY; 2 AGND; 3 AFE_CONNECT_DRIVE | external S05 interface; defaultLOW |

ห้าม hot-plug harness ตอน busมีพลังงาน อย่าเพิ่ม N_AC ลงใน ground-pair ของ J3 แผงที่อยู่คนละระยะต้อง review loop area/EMI และground dropอีกครั้ง

## 10. ผลตรวจคำนวณที่รันแล้ว

สคริปต์ [validate_design.py](D:/workspace/engineering/vsg-project/hardware/sensing/rev_a/validate_design.py), ผล [analytical_results.json](D:/workspace/engineering/vsg-project/hardware/sensing/rev_a/analytical_results.json) และ [frequency_response.csv](D:/workspace/engineering/vsg-project/hardware/sensing/rev_a/frequency_response.csv)

**14 analytical checks ผ่าน**: transfer/polarity, operating envelope, frequency-response identity7จุด, resistor corners, DC-injection/bleeder/resistor-power arithmetic และ balanced-neutral algebra ไม่ใช่ SPICE, PCB ERC/DRC หรือ physical tests

| ผล ideal/limited model | ค่า |
|---|---:|
| Phase differential pole | 15.915 kHz |
| Added phase lag @50 Hz | −0.180° |
| Added phase lag @1 kHz | −3.595° |
| Attenuation @10 kHz | เพียง −1.445 dB |
| Worst resistor-only error ที่25°C ใน sweepที่กำหนด | 12.80 mV referred phase |
| เมื่อเพิ่ม independent TCR cornersที่ΔT25°C | 28.80 mV referred phase |
| AC CM error ที่10 kHz,20 VpeakCM, C pair mismatch≤0.1% | ประมาณ10.36 mV referred phase |

ตัวเลข errorไม่รวม ADC, opamp, connector, source impedance หรือ layout ความแม่นยำทั้งระบบต้องวัดเอง; ห้ามเรียกว่า16-bit accuracyเพราะใช้ ADC16bit

**Anti-aliasing ยังไม่ปิดจาก poleนี้:** เลือก1nFเพื่อจำกัด added loop delayและกำหนดAC matching แต่ที่sampling10kSPS filterนี้และinternal ADC filterไม่ได้รับประกัน alias rejection ต้องศึกษาการอ่านสัมพันธ์PWM/sidebandsและphase marginก่อนreleaseclosedloop ไม่เพิ่มcapacitorจนดูนิ่งโดยไม่คำนวณloopdelayใหม่

## 11. BoM และงบ

ดู [sensing_bom.csv](D:/workspace/engineering/vsg-project/hardware/sensing/rev_a/sensing_bom.csv) จำนวนใช้จริงแยกสำรองและรายการที่ยังต้องตรวจ footprint/MPN

ค่าตัวต้านทานแม่นยำ, precision opamp, contact selection และ rail-loss interface ทำให้ไม่ควรประเมิน S01/S02 จากราคา divider moduleไม่กี่สิบบาท **กันงบ S01/S02 ประมาณ1,800–4,000บาท** เป็น engineering allowance ยังไม่ใช่ใบเสนอราคาชิ้นส่วน ทั้งนี้ PCB อยู่ใน P10 และ S05 supervisorอยู่ใน protection budget ไม่บวกซ้ำ

## 12. เงื่อนไข release ที่ยังต้องทำจริง

| Gate | สิ่งที่ต้องปิด | สถานะ |
|---|---|---|
| R-A | AD7606 module schematic, input network/VxGND, actual header map | PENDING |
| R-B | S05±rail/ADC-rail monitoring, phantom-power rejection, ADC hold-up/disconnect timing รวม relay/flyback/bounce | PENDING DESIGN/TEST |
| R-C | Low-level contact reliabilityหรือเลือก electronic interfaceที่ผ่านแบบแทน | PENDING |
| R-D | Differential±14Vที่หลายCM, CM-onlysweep, offset/gain/temp/channel/sign, open N sense/faultinjection | PENDING |
| R-E | PWM common-mode transients, alias residual, AC matching/loop margins รวมADC/current-sensor delay | PENDING MODEL/TEST |
| R-F | CAD footprint review/ERC/DRCและassemblyinspection | PENDING |

Open N_AC sense leadอาจให้ค่า plausibleแต่ผิด ไม่ถือว่าการอ่านได้หรือcalibrationศูนย์ตรวจพบได้ ต้องมี fault-injectionและตัดสิน diagnostic/connector reliabilityก่อนrunกำลัง

ขั้นตอนทันทีที่ทำได้: ทำCADตามnamed netsและprototypeเฉพาะAFEด้วยlow-energy isolated reference source, ADC/rail fixtureที่reviewแล้ว ก่อนเชื่อมกับinverterจริง ผลทดสอบต้องเทียบerror budgetและแยกจากdesign arithmetic

## 13. แหล่งอ้างอิง

- [TI OPAx197 datasheet](https://www.ti.com/lit/ds/symlink/opa197.pdf): pinfunctions, supply/input behaviorและข้อจำกัด; ตรวจ22ต.ค.2026
- [Vishay PLT datasheet](https://www.vishay.com/docs/60030/plt.pdf): tolerance/TCR/power/workingvoltageของfamily; exactpart procurementยังต้องยืนยัน
- [Analog Devices AD7606 Rev.G](https://www.analog.com/media/en/technical-documentation/data-sheets/ad7606_7606-6_7606-4.pdf): analoginput/seriesresistancematching/power-down
- [Omron G6K datasheet](https://omronfs.omron.com/en_US/ecb/products/pdf/en-g6k.pdf): coil/contact/minimumload/bottom-viewdrawing
- Project sources: [baseline](D:/workspace/engineering/vsg-project/docs/notes/design_baseline.md), [firmware](D:/workspace/engineering/vsg-project/hardware/esp32/vsg_controller/vsg_controller.ino), [model](D:/workspace/engineering/vsg-project/matlab/phase5c_tuned.m)

**สถานะสรุป:** เลือก neutral topology และ freeze signal-chain values แล้ว; system integration/PCB releaseยังติดR-A…R-F จึงไม่ใช้คำว่าhardware-readyหรือปิดแบบทั้งเครื่องแล้ว
