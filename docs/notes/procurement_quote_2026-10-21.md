# รายการจัดซื้อ VSG แบบคุ้มค่า — 21 ตุลาคม 2026

วันที่ตรวจ: 2026-10-21 (UTC+7)  
ผู้จัดทำ: Codex desktop / GPT-6; ตรวจทางเลือก ADC เพิ่มโดย procurement_check  
สถานะ: **SHORTLIST / ยังไม่ได้สั่งซื้อ**

## ข้อสรุปสำหรับ Napoleon

เลือก ESP32-WROOM-32E 4 MB ของ MASSMORE เป็นตัวเลือกหลักรอบแรก และซื้อสาย USB-C พร้อม ACS712 จาก ModuleMore เพื่อรวมพัสดุได้ถ้าร้านรองรับ ส่วน AD7606 ให้เก็บไว้เป็นรายการรอยืนยันวงจร ไม่ซื้อจากชื่อชิปอย่างเดียว

Napoleon ขอรายการคุ้มค่าก่อนและยังไม่กำหนดงบ จึงจัดเป็นใบเปรียบเทียบสำหรับเลือกซื้อ ไม่ใช่คำสั่งซื้อหรือการอนุมัติชำระเงิน เครื่องมือหลักยืมแล็บได้; ESP32 และ AD7606 ยังไม่มี; จำนวน ACS712 ที่มีอยู่ยังไม่ทราบ

เอกสารนี้อัปเดตการเลือกสินค้า/ราคาจากใบเปรียบเทียบเดิม โดยไม่แก้หลักฐานย้อนหลัง:

- `D:\workspace\engineering\vsg-project\docs\notes\procurement_quote_2026-10-20.md`
- สเปกและรายการครบทุกหมวด: `D:\workspace\engineering\vsg-project\docs\notes\procurement_agent_brief_2026-10-20.md`

## 1. ชุดแนะนำสำหรับเริ่มทดสอบ controller และ measurement

| ID | สินค้าและตัวเลือกที่ต้องเลือก | จำนวน | ราคาต่อหน่วย | รวมสินค้า | หลักฐาน/สถานะ |
|---|---|---:|---:|---:|---|
| C01-S | MASSMORE ESP32 38-pin, **WROOM-32E / 4 MB / CH340 / PCB antenna / USB-C** | 1 | 379 บาท* | 379 บาท* | หน้าเว็บผ่านเครื่องมืออ่านแสดง 379 บาทและ 2 ตัวเลือก; ยังไม่ได้เลือกตัวเลือกใน browser จึงต้องตรวจราคาของ 32E อีกครั้ง |
| C02-M | ModuleMore SKU-02452, USB to USB-C **data/upload cable 30 cm** | 1 | **45 บาท** | **45 บาท** | Browser สดแสดงพร้อมส่ง เตรียมสินค้า 1 วัน; ผลค้นหา 40 บาทเก่ากว่า ใช้ 45 บาทในการคำนวณ |
| C04-A | ModuleMore SKU-00318, ACS712 **20A / 100 mV/A** | 3 | **60 บาท** | **180 บาท** | Browser สดแสดงพร้อมส่ง เตรียมสินค้า 1 วัน; ซื้อเท่าจำนวนที่ขาดจริง |
| C03-S | EC buying.th, AD7606 module 8-channel / 16-bit | 1 | 1,021 บาท** | แยกไว้ | ราคาจากการตรวจ 20 ต.ค. หลังโค้ดร้าน ยังยืนยันใหม่ไม่ได้; รอเอกสารโมดูล |

\* ราคา C01 เป็นราคาที่หน้า listing แสดง ไม่ใช่ราคาที่ล็อกหลังเลือก variant หรือยอด checkout ของผู้ใช้  
\** ห้ามใช้ราคา AD7606 นี้เป็นคำรับรองราคาปัจจุบันหรือเป็นเหตุให้ซื้อก่อนตรวจวงจร

ลิงก์ตรง:

- [C01-S MASSMORE ESP32](https://shopee.co.th/บอร์ดพัฒนา-ESP32-38PIN-ชิพแท้-Espressif-ESP32-WROOM-32E-32UE-NodeMCU-32S-DevKitC-CH340-Massmore-i.5641091.26018107849)
- [C02-M สาย USB-C ModuleMore SKU-02452](https://www.modulemore.com/product/2452/สาย-usb-เป็น-usb-type-c-สำหรับอัพโหลดบอร์ด-arduino-esp32-type-c-ยาว-30cm)
- [C04-A ACS712 ModuleMore SKU-00318](https://www.modulemore.com/product/318/acs712-20a-current-sensor-module)
- [C03-S AD7606 EC buying.th](https://shopee.co.th/AD7606-Multi-channel-ADC-Analog-to-Data-Acquisition-Conversion-Module-16-bit-8-channel-Synchronization-ความถี่-200KHz-i.1633960256.49902509678)

### ยอดที่ใช้เปรียบเทียบได้

| ชุด | การคำนวณ | ยอดสินค้าประกอบการเลือก |
|---|---|---:|
| เริ่มอัปโหลด firmware: ESP32 + สาย | 379 + 45 | **424 บาท** |
| ชุดแนะนำ: เพิ่ม ACS712 3 ตัว | 379 + 45 + 3×60 | **604 บาท** |
| ชุดแนะนำ + ACS712 สำรอง 1 ตัว | 604 + 60 | **664 บาท** |
| กรณี AD7606 ผ่านการตรวจและยังได้ราคาเดิม | 604 + 1,021 | **1,625 บาท (ประมาณการแบบมีเงื่อนไข)** |

ทุกยอดยังไม่ใช่ยอดพร้อมชำระ: ไม่รวมค่าส่ง/ภาษีหรือค่าธรรมเนียมเพิ่มเติมที่ checkout อาจเรียกเก็บ และ C01 ยังต้องยืนยันราคา variant; ไม่ได้หักคูปองใหม่หรือรับประกันสิทธิส่งฟรี ขณะนี้ยังไม่มีจังหวัดปลายทางจึงไม่คำนวณยอดส่งถึงบ้าน

หากมีสาย data USB-C ใช้ได้อยู่แล้ว ตัด C02 ออกได้ 45 บาท; ถ้ามี ACS712-20A อยู่แล้ว ให้ลด C04 ตามจำนวนจริง ตัวสำรองเป็นทางเลือก ไม่รวมในชุดหลัก

## 2. เหตุผลที่เลือกและสิ่งที่ต้องเช็กก่อนสั่ง

### ESP32: MASSMORE เป็นตัวเลือกคุ้มค่าสำหรับรอบทดลอง

- เลือก **32E / 4 MB** ตามรายละเอียดตัวเลือกที่เคยตรวจจากข้อมูลผู้ใช้; อย่าเลือก 32UE ที่ต้องมีเสาอากาศภายนอก หรือเปลี่ยนเป็น S3/C3/C6 โดยไม่ทบทวน firmware
- เป็นบอร์ด third-party ที่ใช้โมดูล Espressif ตามคำอธิบายร้าน ไม่ได้ยืนยันว่า PCB ทั้งบอร์ดเป็น official Espressif DevKitC
- หน้า listing ที่อ่านวันนี้แสดง 379 บาท ส่งฟรี และช่วงส่ง 22–24 ต.ค.; เป็นค่าของหน้าที่แสดง ไม่ใช่การยืนยันส่งถึงที่อยู่ของ Napoleon
- ตรวจภาพ/รุ่นที่ส่งจริง, 38-pin layout, USB-C และหัว pin ที่ติดตั้งมา ก่อนประกอบเข้าระบบ
- GPIO2/12/15 ที่ firmware ใช้เกี่ยวข้องกับ boot strapping: ต้องตรวจการดึงระดับโดยวงจรภายนอกก่อนจ่ายไฟ ไม่จำเป็นต้องซื้อบอร์ดแพงเพื่อข้ามขั้นตอนนี้
- การเลือกซื้อบอร์ดไม่เท่ากับการรับรองว่า prototype ผ่าน hardware qualification แล้ว

### สาย USB-C: ซื้อของธรรมดาที่ส่งข้อมูลได้ก็พอ

- SKU-02452 ระบุใช้ upload Arduino/ESP32 และมี tag data cable; ราคาใน browser 45 บาท
- ยาว 30 cm เหมาะเมื่อบอร์ดอยู่ใกล้คอมพิวเตอร์ ถ้าต้องวางไกล ให้ใช้สาย data 1 m ที่มีอยู่ก่อนซื้อเพิ่ม
- ราคาค้นหา 40 บาทไม่ตรงกับหน้าร้านจริง จึงไม่ใช้ 40 บาทในใบนี้
- สาย Micro-B เดิมของตัวเลือก official DevKitC ไม่ตรงกับ USB-C ของ MASSMORE

### ACS712: ซื้อ 3 ตัวจากร้านเดียวกับสายเป็นตัวเลือกหลัก

- ModuleMore 3 ตัว = 180 บาท; รวมสายเป็นยอดร้านนี้ **225 บาทก่อนค่าส่ง**
- [ZoneMaker M029](https://www.zonemaker.com/product/541/20a-hall-current-sensor-module-acs712-20a) เป็นตัวเลือกราคาต่ำกว่า: หน้าเว็บที่เครื่องมืออ่านคืนมาแสดง 49 บาท, 9 ชิ้น, พร้อมส่ง และโปรส่งฟรี แต่ข้อมูลถูก crawl ประมาณ 2 เดือนก่อน จึงยังไม่ใช่ stock สด
- ZoneMaker 3 ตัว = 147 บาท ประหยัด 33 บาทจาก ModuleMore; หากค่าส่งเพิ่มจากการแยกร้านเกิน 33 บาท ความได้เปรียบด้านราคาจะหายไป นี่คือการคำนวณเปรียบเทียบ ไม่ใช่การยืนยันค่าส่ง
- นโยบาย ZoneMaker ที่อ่านมีข้อจำกัดการเปลี่ยน/คืนสินค้าที่ไม่ใช้และการตีมูลค่า 70%; อย่าสรุปว่าได้คืนเต็มจำนวน
- ModuleMore มีข้อความรับประกัน **7 วัน** ในรายละเอียดสินค้า แต่หมวดนโยบายด้านล่างระบุ **30 วัน** จึงบันทึกเป็นข้อมูลขัดกันและไม่รับรองระยะประกันจนร้านยืนยัน
- คำอธิบาย ModuleMore ที่ว่า ACS712 ใช้ DC เท่านั้นไม่ตรงกับ datasheet ชิป Allegro ซึ่งรองรับ AC/DC; แต่สเปกชิปไม่ได้รับรองฉนวน/ขั้วต่อของโมดูลทั้งบอร์ด
- อย่าอาศัยข้อความร้านที่บอกต่อ ESP32 analog input ได้โดยตรง: งานนี้ต้องเดิน measurement ตามแบบ AD7606 และทบทวนระดับแรงดันจริง ตรวจ offset/gain/filter ก่อนใช้ควบคุม
- 20A คือช่วงชิปตาม nominal spec ไม่ใช่หลักฐานว่าบอร์ดราคาถูกทนกระแสต่อเนื่อง 20A ได้

## 3. AD7606: สิ่งที่ยังต้องปิดให้จบก่อนสั่ง

EC buying.th ยังเป็นตัวเลือกที่ราคาอ้างอิงต่ำและสั่งใน marketplace ไทยได้ แต่หลักฐานที่มียังไม่พอระบุ revision และวงจรโมดูล หน้าเดิมแนะนำให้ซื้อก่อนแล้วค่อยขอ PDF/source ซึ่งไม่ช่วยลดความเสี่ยงซื้อผิดบอร์ด

ต้องได้เอกสารหรือภาพที่พิสูจน์อย่างน้อย:

1. ชิป **AD7606 8-channel รุ่นเดิม** ตรงกับ firmware; ถ้าเป็น B/C/-4/-6 ให้หยุดทบทวนก่อน
2. Analog supply 5 V และ digital interface/VDRIVE 3.3 V รวม buffer ที่อาจอยู่บนบอร์ด
3. SPI/serial ใช้งานจริงได้ พร้อมตำแหน่ง CS, SCLK, DOUT, BUSY, RESET และ CONVST A/B
4. ตั้ง input range **±10 V** และ oversampling disabled ได้; แจ้ง jumper/resistor ที่ต้องเปลี่ยน
5. มี schematic/manual และภาพหน้า–หลังตรงกับบอร์ดที่จะส่ง ไม่ใช่ datasheet ชิปอย่างเดียว

### ทางเลือกที่ตรวจเพิ่ม

| ทางเลือก | สิ่งที่พบ | ข้อสรุป |
|---|---|---|
| [TaiwanIOT AD7606](https://www.taiwaniot.com.tw/product/ad7606-16bits-adc-8ch-synchronization/) | NT$700 ก่อนภาษี; หน้าแสดงหมดสินค้า มีคำอธิบาย VIO และปรับ R1/R2 จาก parallel เป็น SPI | เอกสารช่วยเปรียบเทียบ แต่หมดสินค้าและยังไม่ทราบค่าส่งไทย ห้ามนำ pinout นี้ไปใช้กับบอร์ด Shopee โดยสมมติว่าเหมือนกัน |
| [ALINX AN706 ที่ FPGAPRO](https://www.fpgapro.com/product-detail/addon-modules/an706-16bit-200ksps-synchronous-sampling-ad7606-ad-module) | ผู้ตรวจย่อยพบ USD33 ไม่รวม VAT และหน้าแสดง in stock; [คู่มือผู้ผลิต](https://alinx.com/public/upload/file/AN706__User_Manual.pdf) หน้า 7 ระบุ parallel และ ±5 V | ไม่ใช่ drop-in สำหรับ firmware SPI/±10 V ปัจจุบัน ต้องตรวจ schematic/revision และงานปรับ resistor ก่อน; ค่าส่งไทยยังไม่ทราบ |

ไม่แปลงเงิน USD/NT$ เป็นบาทโดยเดาเรต และไม่รวมสินค้าที่ยังใช้ไม่ได้ตรง ๆ ในยอดแนะนำ

### ข้อความสำหรับสอบถามร้าน AD7606 — ร่างไว้ ยังไม่ได้ส่ง

> ต้องการซื้อ AD7606 module 8-channel จำนวน 1 ชิ้น ใช้กับ ESP32 logic 3.3 V ผ่าน SPI รบกวนส่งภาพบอร์ดหน้า–หลังและ schematic/manual ของ revision ที่จะจัดส่งก่อนสั่งซื้อครับ ต้องการไฟ analog 5 V, VDRIVE 3.3 V, input range ±10 V, oversampling disabled และขา CS/SCLK/DOUT/BUSY/RESET/CONVST A/B ที่เข้าถึงได้ กรุณาระบุด้วยว่าต้องย้าย jumper หรือ resistor ใด และยืนยันรหัสชิปเต็มที่ติดตั้งครับ

## 4. รายการที่ยังไม่เพิ่มในรอบนี้

- เครื่องมือหลัก: ยืมแล็บตามที่ Napoleon แจ้ง ได้แก่ oscilloscope, DC supply, multimeter และชุดบัดกรี; ต้องยืนยันเครื่องมือวัด/พิกัดจริงเมื่อเตรียมทดสอบ
- Power stage, gate drivers, filter inductors/capacitors, load banks และ protection: ใช้รายการ P/L/S ใน procurement brief เดิมเพื่อปิดสเปกก่อนเลือก SKU ไม่รวมในยอด 604 บาท
- ไม่เลือกค่าพิกัด inductor, DC-link, fuse, UV/OV, braking หรือ shutdown circuit จากราคาเป็นหลัก เพราะยังมีข้อออกแบบค้างอยู่

## 5. คำสั่งส่งต่อให้ purchasing agent

1. เปิดใบนี้ร่วมกับ procurement brief เดิม; ตรวจจำนวนของที่มีอยู่ก่อน
2. รอบแรกใช้ C01-S 32E/4 MB ×1, C02-M ×1, C04-A ×จำนวนที่ขาด (เป้าหมาย 3)
3. ถ้าเลือก MASSMORE ให้ใช้สาย USB-C; ถ้าเปลี่ยนบอร์ด ให้ตรวจ connector ใหม่
4. ตรวจตัวเลือก C01 แล้วบันทึกราคาจริง ภาษี ค่าส่ง และยอดรวมของแต่ละร้าน ห้ามถือ 604 บาทเป็นยอดพร้อมจ่าย
5. C03 คงสถานะรอเอกสารจนผ่านรายการตรวจข้างต้น ไม่เปลี่ยนเป็น AN706 หรือ ADS1115 เอง
6. ก่อนสั่งจริง ต้องมีปลายทางและยอดรวมที่ผู้ใช้ยอมรับ; user ยังไม่ได้ให้ spending cap
7. เก็บชื่อร้าน SKU/variant จำนวน ราคา ค่าส่ง สถานะออเดอร์ และใบเสร็จหลังซื้อ; อย่าเปลี่ยนจำนวนรายการเดิมในตะกร้าของผู้ใช้

## 6. หลักฐานและข้อจำกัดของการตรวจครั้งนี้

- Computer Use ตรวจ ModuleMore ACS712 และสาย USB-C ได้จริง; ไม่มีการเพิ่มตะกร้าหรือ checkout
- Shopee ใน browser เปลี่ยนไปหน้า CAPTCHA จึงไม่ได้เลือก variant หรือยืนยันยอดส่งจริง; ไม่ได้ทำ challenge
- ราคาหน้า MASSMORE อ่านได้ผ่านเครื่องมือเว็บ โดยเครื่องมือระบุ crawl วันนี้; AD7606 ใช้หลักฐานลงวันที่ 20 ต.ค. และติดป้ายย้อนหลังชัดเจน
- ไม่มีการส่งข้อความร้านค้า กรอกที่อยู่/ข้อมูลชำระเงิน หรือสั่งซื้อ
- [Espressif DevKitC documentation](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32/esp32-devkitc/user_guide.html)
- [Analog Devices AD7606 datasheet Rev. G](https://www.analog.com/media/en/technical-documentation/data-sheets/ad7606_7606-6_7606-4.pdf)
- [Allegro ACS712 datasheet Rev. 22](https://www.allegromicro.com/-/media/files/datasheets/acs712-datasheet.pdf)

**การตัดสินใจรอบนี้:** เลือกชุดราคาเปรียบเทียบ 604 บาทเป็น shortlist; ยอดซื้อจริงยังไม่ล็อก และ AD7606 ยังรอหลักฐานโมดูล

## 7. รายการเพิ่มเติม: ภาคกำลัง โหลด และอุปกรณ์ประกอบ

เพิ่มตามคำถาม Napoleon ว่า “อื่นๆ ล่ะครับ” — ตรวจแหล่งจำหน่ายวันที่ 21 ต.ค. 2026 (UTC+7) ตารางด้านล่างครอบคลุมของนอกชุด controller; เป็น candidate สำหรับจัดซื้อ ยังไม่มีการสั่งซื้อ ราคา/stock มาจากหน้าเว็บที่อ่านได้ ไม่ได้ล็อกที่ checkout

### 7.1 ชิ้นส่วนที่ระบุรุ่นและแหล่งซื้อได้แล้ว

| ID | รายการ / ร้าน | จำนวนเสนอ | ราคาและยอดสินค้า | เงื่อนไขเลือกซื้อ |
|---|---|---:|---|---|
| P01 | **IRF540NPBF TO-220 — Electronics Source** | **10 ตัว: ใช้ 6 + สำรอง 4** | 7.80 บาท/ตัวก่อน VAT; รวม **78.00 บาทก่อน VAT / 83.46 บาทรวม VAT ตามหน้าเว็บ** | ราคาขั้น 10 ตัวถูกกว่าซื้อ 8 ตัว; ตรวจ full marking และยี่ห้อ/lot ที่ส่งจริง |
| P02 | **IR2104STRPBF SOIC-8 — DigiKey Thailand** | **4 ตัว: ใช้ 3 + สำรอง 1** | 54.03 บาท/ตัว; รวม **216.12 บาท** ไม่รวมค่าขนส่ง/ภาษีที่อาจเกิด | เลือก cut tape รหัสร้าน **IR2104SPBFCT-ND**; manufacturer MPN ต้องเป็น STRPBF; PCB ต้องรองรับ SOIC-8 |
| L01 | **Arcol/Ohmite HS50 10R F, 10 Ω 50 W ±1% — RS Thailand** | **3 ตัว** | 231.15 บาท/ตัวก่อน VAT; รวม **693.45 บาทก่อน VAT** | โหลดเริ่มต้น; ซื้อพร้อมวางแผนติดแผ่นระบายความร้อน |
| L02 | **Arcol/Ohmite HS100 3R F, 3 Ω 100 W ±1% — RS Thailand** | **3 ตัว** | 456.40 บาท/ตัวก่อน VAT; รวม **1,369.20 บาทก่อน VAT** | โหลดใกล้กำลังเต็ม; เลื่อนไปซื้อช่วงทดสอบกำลังสูงได้ |
| P06 | **KEMET PHE426HR8100JR06L2, 10 µF ±5%, polypropylene, 250 VDC/160 VAC** | ใช้ 3 + สำรอง 1 | DigiKey US แสดง **USD9.36/ตัว** ขั้น 1 ชิ้น; 4 ตัว USD37.44 ก่อนค่าจัดส่ง/ภาษี | **ตัวเลือกเพื่อทบทวนเท่านั้น**: ต้องตรวจ ripple-current/frequency/temperature derating และ pitch 37.5 mm; ยังไม่อนุมัติซื้อ |

ลิงก์ตรงสำหรับ agent:

- [P01 Electronics Source IRF540NPBF](https://www.es.co.th/detail.asp?Prod=012900602)
- [P02 DigiKey IR2104STRPBF](https://www.digikey.co.th/th/products/detail/infineon-technologies/IR2104STRPBF/811428)
- [L01 RS HS50 10R F / 162-3552](https://th.rs-online.com/web/p/chassis-mount-resistors/1623552)
- [L02 RS HS100 3R F / 162-3543](https://th.rs-online.com/web/p/chassis-mount-resistors/1623543)
- [P06 DigiKey PHE426HR8100JR06L2](https://www.digikey.com/en/products/detail/kemet/PHE426HR8100JR06L2/13176742)

**การคัดความคุ้มค่า:**

- P01 ซื้อ 8 ตัวตาม brief เดิม = 8×10.26 = 82.08 บาทก่อน VAT แต่ซื้อ 10 = 78 บาทก่อน VAT จึงเสนอ 10 ตัวด้วยเหตุผลราคาขั้นบันได ไม่เพิ่มจำนวนให้กับรายการอื่นโดยอัตโนมัติ
- Electronics Source แสดงผู้ผลิตรวม “IR/INFINEON/VISHAY”; จึงเรียกว่า local supplier ที่มี listing เท่านั้น ยังไม่ได้ยืนยันสถานะ authorized distributor จากผู้ผลิตหรือรับรองแหล่งที่มาของ lot นี้
- หน้า ES ที่ผู้ตรวจย่อยอ่านแสดง stock รวม 11,266 ตัว และพร้อมส่งจากราชพฤกษ์ 10,896 ตัว; ต้องตรวจซ้ำเมื่อซื้อ
- P02 DigiKey แสดง 3,211 ตัว และเงื่อนไขส่ง 600 บาทเมื่อยอดต่ำกว่า 1,600 บาท หากซื้อ driver อย่างเดียว 4 ตัวจะเป็น **816.12 บาทก่อนภาษี/ค่าใช้จ่ายที่อาจเกิด** จึงควรรวมกับชิ้นส่วนที่จำเป็นจริงหรือคำสั่งซื้อแล็บเมื่อรายการพร้อม อย่าซื้อของเพิ่มเพื่อให้ถึงส่งฟรีอย่างเดียว
- L01/L02 RS แสดง stock คลังต่างประเทศ 818/76 ตัวตามลำดับ ไม่ใช่หลักฐานว่ามีสินค้าที่คลังไทยพร้อมส่งวันเดียวกัน
- โหลดสองชุดรวม **2,062.65 บาทก่อน VAT**; ใช้ VAT ตามหน้าเว็บ 7% จะประมาณ **2,207.04 บาทรวม VAT** ก่อนค่าส่ง (การปัดเศษที่ checkout อาจต่าง 1 สตางค์) หน้า RS ระบุส่งฟรีเมื่อซื้อเกิน 2,500 บาท; ยังไม่ถือว่าสองชุดนี้ถึงเกณฑ์
- DigiKey HS100 3R F แสดงหมด stock และรอประมาณ ม.ค. 2027 จึงเลือก RS เป็นตัวเลือกที่มีสินค้าแสดงอยู่
- ราคาของ film capacitor เป็น USD จากหน้า US ไม่ใช่ราคาส่งไทย และไม่ได้แปลงเป็นบาทหรือรวมในยอดจัดซื้อ
- สถานะผู้ผลิตที่ตรวจวันนี้: [IRF540N](https://www.infineon.com/part/IRF540N) Active/TO-220; [IR2104S](https://www.infineon.com/part/IR2104S) รุ่น STRPBF Active/Recommended, SOIC 8N อย่าสลับกับ SPBF แบบ tube หรือ DIP เพราะชื่อคล้ายกัน

### 7.2 ของประกอบราคาต่ำที่ควรเช็กสต็อกแล็บแล้วซื้อเฉพาะที่ขาด

จำนวนด้านล่างเป็นข้อเสนอสำหรับ bench preparation ไม่ใช่ BoM ของ PCB สำเร็จ และต้องเลือกขั้ว/ขนาดให้ตรงโมดูลจริง

| รายการ | จำนวนเริ่มต้นเสนอ | แหล่ง/ราคาอ้างอิง | การใช้งาน |
|---|---:|---|---|
| สาย Dupont female–female 10 cm | 1 แพ็ก 40 เส้น | ModuleMore **SKU-00752** ผลค้นหาแสดง 25 บาท (ปกติ 28); ยังไม่ยืนยัน stock/ราคาปัจจุบัน | Logic/fixture ระยะสั้น; ไม่รับรอง SPI 15 MHz โดยไม่วัด signal integrity |
| สาย Dupont male–female 10–15 cm | 1 แพ็ก 40 เส้น | ราคา UNKNOWN; เลือกตามหัวต่อจริง | Logic/fixture; ไม่ใช้เป็นทางเดินกระแส inverter |
| Male/female header 2.54 mm | อย่างละ 2 แถว แถวละ 40 pin เป็น starting stock | ราคา UNKNOWN; ถ้าหัวติดมากับบอร์ดแล้วลดจำนวน | ใช้ประกอบ fixture และ socket; ต้องตรง pitch จริง |
| ชุดท่อหดคละขนาด | 1 กล่อง 127 ชิ้น | ModuleMore **SKU-00324** หมวดสินค้าที่ index แสดง 28 บาท; ยังไม่ยืนยันหน้าสินค้าสด | หุ้มรอยต่อทั่วไป; ไม่ถือเป็นฉนวนรับรองสำหรับ node ที่ยังไม่กำหนดพิกัด |
| สาย signal แบบบัดกรี | รวม 5 เมตรเป็น starting stock | ราคา UNKNOWN; เลือกขนาดตามงาน signal | ตัดสั้นและจัด routing ตามวงจร; power wiring แยกกำหนด |
| เคเบิลไทร์และป้ายสาย | 1 แพ็ก 100 เส้น + ป้าย 20 ชิ้น | ราคา UNKNOWN | ยึดสาย/ติดชื่อเฟสและขั้ว |
| ตะกั่วบัดกรี flux และ IPA | ซื้อเฉพาะที่แล็บไม่มี | ราคา/จำนวน UNKNOWN | ของสิ้นเปลือง ไม่จำเป็นต้องซื้อหัวแร้งใหม่ |

แหล่งค้นของประกอบ:

- [ModuleMore หมวดสาย jumper/signal](https://www.modulemore.com/category/43/สายไฟ-jumper-connector-protoboard-บอร์ดทดลอง/jumper-สายจั้มเปอร์-สายสัญญาณ-สายไฟ-สาย-arduino)
- [ModuleMore ชุดท่อหด](https://www.modulemore.com/category/12/เครื่องมือช่างอิเล็กทรอนิคส์/ท่อหด)
- [ModuleMore Dupont housing/contacts SKU-02413](https://www.modulemore.com/product/2413/หัว-dupont-ผู้-เมีย-ระยะห่าง-2-54mm-1-20p) ราคา 10–41 บาทตามตัวเลือก ยังไม่เลือก package; ต้องมีคีมเข้าหัวที่ตรงถ้าซื้อแบบประกอบเอง

ไม่บวกของประกอบเหล่านี้ในยอดรวมจนยืนยัน SKU จำนวนต่อแพ็ก และของที่มีแล้ว โดยเฉพาะผลค้นหา ModuleMore มีราคา/stock เก่าที่ต่างจากหน้า browser สดได้

### 7.3 ของที่จำเป็นต่อ prototype แต่ยังไม่ควรเลือก SKU จากราคา

| ID | ต้องมีอะไร | จำนวนตามหน้าที่ | ข้อมูลที่ยังต้องปิดก่อนซื้อ |
|---|---|---:|---|
| P03 | Bootstrap diode/capacitor และ driver decoupling | 3 ชุด driver | คำนวณจาก gate charge, supply, duty, droop/leakage และ PCB |
| P04 | Gate resistor/pulldown และ gate network | 6 ชุด MOSFET | ค่า R, pulse power, turn-on/off behavior และ layout |
| P05 | **Power inductor 1.2 mH** | **3 ตัว** | Isat, Irms, DCR, core loss ที่ 10 kHz และ L ลดลงเมื่อมีกระแส; ยังไม่พบตัวที่อนุมัติได้ |
| P07 | **Damping resistor 1 Ω แบบ low-inductance** | **3 + สำรอง 1** | กำลังเฉลี่ย/pulse จากกระแส ripple; ไม่ใช้ wirewound HS ของโหลดแทนโดยอัตโนมัติ |
| P08 | Heatsink MOSFET + pad/mica + shoulder washer + screw | 6 ตำแหน่ง + spare ตามแบบ | Loss/thermal resistance และการแยกแท็บ drain; เลือกความหนา pad และแรงขันตามรุ่น |
| P09–P10 | PCB power และ logic/ADC/protection | ตาม revision และ MOQ โรงงาน | Schematic, layout, Gerber และ footprint ที่ตรวจแล้ว |
| P11 | สาย power, terminal block, ferrule/lug, กล่องและเสารอง | ตาม layout | Current/fault rating, wire size, pitch และขนาดกล่อง |
| L03 | แผ่นระบายความร้อนโหลด/ตะแกรง/พัดลมถ้าต้องใช้ | 1 assembly | ระบาย 29.4 W หรือ 98 W รวมได้ตามชุดโหลด; surface temperature |
| L04 | Inductor โหลด 1 mH | 3 ตัว ถ้าทำ R-L test | กระแสและ thermal/core loss; ไม่จำเป็นในรอบ resistive load แรก |
| S01–S02 | Phase-voltage conditioning + DC-bus sensing | 3 + 1 ช่อง | Common-mode/reference, gain, bandwidth, protection และ integration |
| S03–S06 | Hardware OCP/comparator, fault latch, rail supervision, DC UV/OV | 1 ระบบ | Threshold, delay, default-off และ interlock schematic |
| S07 | DC-link capacitors + local decoupling | 1 bank | C, ESR/ripple, voltage margin และ energy; **2200 µF ใน simulation ยังไม่ใช่ค่าซื้อ** |
| S08 | Precharge, bypass และ discharge | 1 ระบบ | Energy/pulse/time constants และอุปกรณ์ switching |
| S09 | DC fuse + holder + disconnect | 1 ระบบ | DC voltage/interruption rating และ coordination; ฟิวส์รถยนต์ 32 V ไม่ใช่ตัวเลือกสำหรับบัส 40 V |
| S10 | STOP/E-stop และ ARM | อย่างละ 1 หน้าที่ | รูปแบบ contact และ interlock; ปุ่ม STOP ไม่ใช้ตัด DC-link โดยไม่มีพิกัด |
| S11–S12 | Energy sink/braking และ snubber/TVS | ตามการออกแบบ | Returned energy และ switching transient; source-only lab supply ไม่ดูดพลังงานกลับ |

**หลักฐานว่าต้องเลือกคอยล์จากกระแสด้วย:** หน้า [DigiKey 1.2 mH](https://www.digikey.co.th/en/products/filter/fixed-inductors/1-2-mh/71) มีตัวอย่าง AIUR-06-122K ที่ 610 mA, DCR 1.5 Ω ซึ่งไม่เหมาะใช้แทน filter ที่ฐานประมาณ 3.37 A RMS/เฟสของโปรเจกต์ ตัวเลข L เท่ากันไม่ได้ทำให้ใช้แทนกันได้

### 7.4 ลำดับซื้อที่เสนอ

1. **รอบเริ่มต้น:** controller/measurement ตามส่วน 1 และของประกอบที่ขาด; หากยืนยัน lot ได้ อาจรวม IRF540NPBF 10 ตัวเป็นอะไหล่ราคาต่ำ
2. **รอบประกอบ PCB:** driver, bootstrap/gate network, PCB และ hardware protection เมื่อแบบพร้อม; รวมคำสั่งซื้อ distributor เพื่อลดค่าส่ง
3. **รอบทดสอบกำลังต่ำ:** filter ที่ผ่านการเลือกพิกัด, heatsink, ชุดโหลด 10 Ω ×3 และ DC protections ครบ ก่อนเริ่ม power test
4. **รอบใกล้กำลังเต็ม:** ชุดโหลด 3 Ω ×3 พร้อมระบบระบายความร้อน; เลื่อนได้ถ้าชุด 10 Ω ยังทดสอบไม่จบ

พิกัดโหลดอ้างอิงที่ phase voltage 14 Vpeak: 10 Ω ให้ 9.8 W/เฟส (29.4 W รวม); 3 Ω ให้ 32.67 W/เฟส (98 W รวม) ต้องยึด/ระบายความร้อนตาม [datasheet Arcol HS](https://docs.rs-online.com/adc9/0900766b816039bc.pdf) ซึ่ง HS100 ระบุ free-air ที่ 25°C เพียง 30 W จึงไม่พอสำหรับ 32.67 W/ตัวโดยอาศัยพิกัด 100 W บนชื่อสินค้าอย่างเดียว

**ยังไม่มีงบรวมทั้งเครื่องที่ยืนยันได้:** ราคา semiconductor และ load มีแหล่งอ้างอิงแล้ว แต่ magnetics, protection, PCB และ thermal assembly ยังไม่ได้กำหนดครบ จึงไม่ทำยอดรวมปลอมจากชิ้นส่วนที่ขาดอยู่

## 8. ทางเลือก AD7606 เพิ่มเติม — ตรวจ 21 ต.ค. 2026

| ร้าน / ตัวเลือก | ราคาที่พบ | หลักฐานและข้อสรุป |
|---|---|---|
| [Easyelecmodule — AD7606 Data Acquisition Module](https://easyelecmodule.com/product/ad7606-data-acquisition-module/) | **USD16.66/ชิ้น**, หน้าแสดง 5,742 in stock | **เว็บระบุส่งเฉพาะสหรัฐฯ จึงยังไม่ใช่ตัวเลือกสั่งตรงมาไทย** มีลิงก์ schematic แต่ดึงภาพมาตรวจไม่ได้; ร้านระบุ default parallel, SPI ต้อง R1=10k/R2 ไม่ติดตั้ง และ VIO รับ 3.3V/5V ยังไม่ได้ยืนยัน connector mapping หรือวงจรระดับ net |
| [thgoodstore.th — Shopee AD7606](https://shopee.co.th/AD7606-Multi-Channel-AD-Data-Collection-โมดูล-16-Bit-ADC-8-Channel-Synchronization-แรงดันไฟฟ้า-Sampling-ความถี่-200KHz-i.1477286806.42066397511) | หน้า cached ที่เปิดแสดง **531 บาท**; search snippet อีกชุดแสดง 722 บาท | เป็นร้านอื่นจาก EC buying.th แต่ราคาไม่ตรงกันและ delivery estimate หมดอายุแล้ว จึง **ยังไม่ทราบราคาปัจจุบัน**; ไม่ใช่ช่วงราคา variant ที่ยืนยันแล้ว และยังไม่มีหลักฐานวงจรโมดูล |
| [DigiKey — Analog Devices EVAL-AD7606SDZ](https://www.digikey.co.th/en/products/detail/analog-devices-inc/EVAL-AD7606SDZ/5583170) | **3,698.18 บาท**, หน้าเปิดวันนี้แสดง **14 ตัว** | บอร์ดประเมินผลจากผู้ผลิต มีคู่มือ/วงจรชัดเจน; ต้องวางแผน adapter/connector และตั้ง links สำหรับ ESP32 ไม่ใช่โมดูลแทนกันได้ทันที ราคานี้ยังไม่รวม duty/tax; ตามหน้าเว็บยอดถึงเกณฑ์ส่งฟรี แต่ checkout เป็นตัวตัดสิน |
| [Lilly Electronics — KWKJ-AD7606](https://www.lillyelectronicsllc.com/ad7606-multi-channel-ad-collector-8-ch-simultaneous-sampling-frequency-200khz) | **USD51.70**, หน้าแสดง in stock | ระบุ 8ch/16bit/SPI/3.3V และ ±10V; ยังไม่ได้ตรวจ module schematic และส่งไทย มีราคาแพงกว่าตัวเลือก Easyelecmodule จึงไม่จัดเป็นตัวเลือกคุ้มค่าอันดับแรก |

ราคาต่างประเทศไม่แปลงเป็นบาทโดยเดาอัตราแลกเปลี่ยน และยังไม่มี landed quote ส่งไทยสำหรับ Lilly ส่วน Easyelecmodule ระบุ US-only; เว็บไซต์มีลิงก์ร้าน AliExpress/Alibaba แต่ยังไม่พบหลักฐานยืนยันว่าสินค้ารุ่นเดียวกันสั่งส่งไทยได้ผ่านช่องทางนั้น

**รายละเอียดบอร์ด official:** [คู่มือ ADI UG-851](https://www.analog.com/media/en/technical-documentation/user-guides/eval-ad7605-4sdz_7606sdz_7606-6sdz_7606-4sdz_7607sdz_7608sdz.pdf) ระบุ standalone capability และ LK3 เลือก VDRIVE 3.3V ได้ แต่ default เป็น 5V; workflow USB/PC ของผู้ผลิตใช้ EVAL-SDP-CB1Z แยกต่างหาก ไม่ได้รวมในราคา 3,698.18 บาท การใช้ ESP32 แทน SDP ต้องตรวจ routing/links/connector ก่อน ไม่จำเป็นต้องสั่ง SDP โดยอัตโนมัติ

ไม่สับสน **AD7606BSTZ IC เปล่า** กับ **โมดูลประกอบ** หรือ **EVAL-AD7606SDZ**; ราคาและสิ่งที่ต้องประกอบเพิ่มต่างกัน

ข้อเสนอ ณ ตอนนี้: ถ้าเน้นความคุ้มค่า ให้ตรวจราคาปัจจุบันและเอกสารโมดูลของ thgoodstore.th เทียบกับ EC buying.th ก่อน ยังไม่มีตัวเลือกโมดูลราคาต่ำใหม่ที่ยืนยันครบทั้งราคา วงจร และการส่งไทย ส่วน official EVAL เหมาะเมื่อให้น้ำหนักกับเอกสารและแหล่งที่มาและยอมรับต้นทุน/งานต่อเพิ่ม เก็บ Easyelecmodule ไว้เป็นข้อมูลเปรียบเทียบจนกว่าจะมีช่องทางส่งไทยที่ยืนยันได้ ไม่ได้สั่งซื้อหรือส่งข้อความร้านใด
