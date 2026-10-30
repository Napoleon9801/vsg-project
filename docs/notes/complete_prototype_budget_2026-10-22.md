# ประเมินงบต้นแบบ VSG ทั้งชุด — 22 ตุลาคม 2026

> อัปเดต23ต.ค.2026: Napoleon ยืนยันทุน7,200บาทและhardwareเฉพาะislanded ไม่ต่อแหล่งACภายนอก เงินส่วนตัวเพิ่มยังไม่กำหนด; อ่าน [ผลเทียบเล่มสอบและแผนงบ](D:/workspace/engineering/vsg-project/docs/notes/proposal_scope_budget_7200_2026-10-23.md) ก่อนจัดซื้อ ยอดestimateเดิมไม่ใช่งบที่ได้รับหรือคำสั่งซื้อ


**งบวางแผนประมาณ 16,000–36,000 บาท; ใช้ประมาณ 26,000 บาทเป็นจุดกลาง หรือเตรียมขอเบิกกรอบ 30,000 บาทพร้อมส่วนเผื่อเพิ่มเติมหากจำเป็น** นี่เป็น engineering estimate มีหลายวงจรยังต้องออกแบบ/ขอราคา ไม่ใช่ยอด checkout หรือเพดานรับประกัน

## ขอบเขตยอดนี้

- หนึ่งต้นแบบ Option A, islanded 40 V /100 W; ESP32 1, ADC module ราคาประหยัด 1 ที่ต้องผ่านตรวจ, ACS712 3 ตัว
- ครอบคลุม 32 IDs ที่ไม่ใช่เครื่องมือใน procurement brief ยกเว้น optional L04 รวมทั้งสองชุด resistive load, voltage sensing, independent protections, power/filter/thermal/PCB/wiring
- ยืมเครื่องมือ T01–T12 เท่าที่จำเป็นจากแล็บ โดย **สมมติว่าได้ main supply และ auxiliary rails รวม±12Vสำหรับ sensing**; ยังไม่ยืนยันรุ่น/ความพร้อมของเครื่องมือทุกตัว หากยืมไม่ได้ต้องประเมินเพิ่ม
- ESP32 ที่ยืมเพื่อนไม่ถือเป็นทรัพย์สินถาวรของโครงงาน จึงยังกันงบซื้อหนึ่งบอร์ด
- ประกอบเอง ไม่รวมค่าแรงจ้างออกแบบ/ประกอบ, ค่าบริการทดสอบภายนอก, ซอฟต์แวร์ที่ต้องซื้อใหม่ หรือ BESS
- BESS ยังไม่กำหนด capacity/interface/chemistry จึง **ยังไม่มีงบทั้งโครงงานรวม BESS ที่น่าเชื่อถือ** ไม่ใช้ราคาแบตอย่างเดียวแทน BMS/charger/converter/protection

## ตารางงบวัสดุ/ชิ้นส่วน

ทุกช่วงด้านล่างเป็น **เงินกันไว้ต่อกลุ่ม ไม่ใช่ราคาของ SKU ที่อนุมัติแล้ว** กลุ่มที่มี anchor จากร้านอยู่ในส่วนหลักฐานท้ายไฟล์ ส่วน HOLD เป็น allocation ทางวิศวกรรมที่อาจเปลี่ยนตามแบบ

| กลุ่ม / IDs | จำนวน/ขอบเขต | ต่ำ (บาท) | สูง (บาท) | ฐานประมาณ |
|---|---|---:|---:|---|
| Controller/ADC/current sensors C01–C04 | ESP32+USB+AD7606 module+ACS712×3 | 1,600 | 2,100 | อิง shortlistเดิม1,625บาทแบบมีเงื่อนไข; ADCยังไม่ยืนยัน |
| MOSFET/driver P01–P02 | ซื้อMOSFET10ตัว/ใช้6; driver4ตัว/ใช้3 | 300 | 500 | มีราคาหน้าร้าน; ไม่รวมค่าส่งในกลุ่ม |
| Bootstrap/gate networks P03–P04 | driver3ชุด/gate6ชุด | 150 | 400 | allocation; ยังเลือกค่าครบไม่ได้ |
| Filter inductors P05 | 1.2mH×3 ที่พิกัดเหมาะกับแบบ | 1,500 | 3,600 | allocationรวม3ตัว; ยังไม่มีqualifiedquote |
| Filter capacitors/damping P06–P07 | ใช้3+สำรอง1ของแต่ละชนิด | 400 | 1,000 | allocation; ripple/powerพิกัดยังต้องตรวจ |
| Phase/bus voltage sensing S01–S02 | RevA3phase+bus,precisionparts,outputselection,localdecoupling | 1,800 | 4,000 | allocationปรับตามแบบใหม่; ไม่รวมPCBหรือS05supervisorซ้ำ |
| Independent protections S03–S06/S10 | OCP/latch/AND/rail-supervisor/UVOV/ARM/STOP/feedback | 700 | 2,000 | allocation; exactthresholds/MPNยังค้าง |
| DC-link/precharge/discharge/fuse S07–S09 | 1ระบบรวมdisconnect/bypassตามแบบ | 1,000 | 2,500 | allocation; ยังไม่ใช้Cจากsimulationเป็นBoM |
| Brake/energy sink/transient S11–S12 | braking R+switch/control+thermalและsnubberตามแบบ | 600 | 1,800 | allocationไม่ใช่TVSตัวเดียว; ไม่รวมBESS |
| PCB P09–P10 | powerและlogic/sensing/protection board sets ตามMOQ | 800 | 2,200 | ค่าผลิตรอบแรก; re-spinอยู่ในcontingency |
| MOSFET cooling P08 | heatsink/pads/washer/fasteners6ตำแหน่ง | 300 | 800 | allocationแยกจากโหลด |
| Resistive loads L01–L02 | 10Ω50W×3 และ3Ω100W×3 | 2,207 | 2,600 | anchorรวมVAT≈2,207.04; ปัดเป็นงบ |
| Load cooling/guard L03 | heatsink/plate/fan/guardของโหลด | 400 | 1,000 | allocation |
| Power wires/connectors/enclosure P11 | 1assembly | 600 | 1,400 | allocationรวมconnectorsของsensing ไม่ซื้อซ้ำ |
| Signal headers/passives/consumables C05–C06 | สายlogic,reset/strapfixture,flux/tin/heatshrinkตามที่ขาด | 200 | 500 | functionalprotectionpassivesอยู่ในS03–S06แล้ว |
| **รวมกลุ่มสินค้า/วัสดุ** | | **12,557** | **26,400** | ไม่มีการคิดภาษี7%ซ้ำทั้งยอด |

## ค่าใช้จ่ายและเงินเผื่อ

| รายการ | ต่ำ | สูง | ความหมาย |
|---|---:|---:|---|
| กลุ่มสินค้า/วัสดุข้างต้น | 12,557 | 26,400 | บางanchorรวมVATแล้ว; allocationอื่นเป็นเงินวางแผน |
| ค่าส่งรวมหลายร้าน | 500 | 1,500 | allowance; คิดจริงตามorder/ปลายทาง |
| เผื่อVAT/import/handlingที่ราคาบางร้านยังไม่รวม | 400 | 1,500 | allowanceไม่ใช่คำนวณอากรจริง; ห้ามบวกVATซ้ำกับใบเสนอราคาที่รวมแล้ว |
| **ก่อนcontingency** | **13,457** | **29,400** | |
| Contingency20% | 2,691.40 | 5,880 | redesign/re-spin/เสียระหว่างbring-up/ราคาผันผวน; ไม่ใช่อะไหล่ที่รวมไว้แล้ว |
| **รวมคำนวณ** | **16,148.40** | **35,280** | ความละเอียดทศนิยมเป็นผลรวมเท่านั้น ไม่ใช่ความแม่นยำของestimate |
| **กรอบสื่อสารแบบปัด** | **ประมาณ16,000** | **ประมาณ36,000** | ไม่รับประกันupperbound |

จุดกลางทางคณิตศาสตร์≈25,714บาท จึงใช้26,000บาทสำหรับวางแผน; หากขอเบิก30,000บาทจะมีพื้นที่มากกว่าค่ากลาง แต่ยังไม่ครอบคลุมทุกความเสี่ยงด้านแบบหรือBESS

## ทางเลือกที่เปลี่ยนยอด

| ทางเลือก | ผลต่อยอด |
|---|---|
| ใช้official EVAL-AD7606SDZแทนโมดูลประมาณ1,021บาท | ราคาอ้างอิง21ต.ค.3,698.18บาท ต่าง≈2,677บาทก่อนค่าต่อadapter/ภาษี; กันเพิ่มประมาณ3,000–4,000บาทเป็นallowanceไม่ใช่quoteใหม่ |
| เพิ่มR-L load L04 | กันเพิ่ม1,500–3,600บาทสำหรับคอยล์3ตัวก่อนค่าส่ง/เผื่อ; ไม่ใช่คอยล์P05ชุดเดียวกัน |
| ยืมโหลดresistiveสองชุดและชุดระบายความร้อนได้จริง | ลดรายการL01–L03ตามที่ไม่ต้องซื้อ; ไม่หักโดยไม่มีinventory |
| มีESP32/สาย/ACS712เป็นของตนเองแล้ว | หักเฉพาะจำนวนที่ตรวจแล้ว; ของยืมเพื่อนไม่หักอัตโนมัติ |
| ยืมaux±12Vหรือdifferentialprobeไม่ได้ | ต้องเพิ่มราคาตามรุ่นที่ผ่านrequirements; ยังไม่เดาราคาทดแทน |
| เพิ่มBESSเต็มระบบ | ยังประเมินไม่ได้จนกำหนดcapacityและinterface; แยกคำขอเบิก |

หากต้องลดงบ ให้เลื่อนชุดโหลด3ΩและR-Ltest หรือยืมของแล็บที่ตรงสเปก ไม่ตัดprotection/voltageconditioning/thermalเพื่อให้ยอดเท่าราคา shortlistเดิม

## หลักฐานราคาที่ตรวจและข้อจำกัด

ตรวจหน้าเว็บ22ต.ค.2026:

- [DigiKey IR2104STRPBF](https://www.digikey.co.th/th/products/detail/infineon-technologies/IR2104STRPBF/811428):54.03บาท/ตัวที่quantity1; ซื้อ4=216.12บาทก่อนค่าใช้จ่ายเพิ่มเติม หน้าเว็บระบุส่ง600บาทถ้ายอดต่ำกว่า1,600บาท
- [RS HS50 10R F](https://th.rs-online.com/web/p/chassis-mount-resistors/1623552):231.15บาท/ตัวก่อนVAT; ×3=693.45บาท
- [RS HS100 3R F](https://th.rs-online.com/web/p/chassis-mount-resistors/1623543):456.40บาท/ตัวก่อนVAT; ×3=1,369.20บาท รวมโหลดก่อนVAT2,062.65บาท; ใช้อัตรารวมที่หน้าเว็บแสดงเทียบแล้วรวม≈2,207.04บาท (checkoutอาจต่างการปัดเศษ)
- [ModuleMore ACS712-20A](https://www.modulemore.com/product/318/acs712-20a-current-sensor-module):หน้าอ่านได้แสดง60บาท/ตัว; ×3=180บาท สต็อก/variantยืนยันตอนสั่ง

Historical anchorsจาก20–21ต.ค.เก็บใน [procurement quote](D:/workspace/engineering/vsg-project/docs/notes/procurement_quote_2026-10-21.md): ESP32 379บาท, USB45บาท, AD7606 1,021บาทแบบมีเงื่อนไข, MOSFET10ตัว83.46บาทตามVATที่ใช้ในquoteเดิม ไม่รับรองราคาวันcheckout

**ยอด4,131.62บาทที่เคยแจ้งเป็นpriced shortlistบางรายการ** งบใหม่นี้ไม่ได้เอายอดนั้นบวกตารางซ้ำ แต่แจกแจง32IDsใหม่ให้ครอบคลุมส่วนที่ยังขาด โดยvoltagefront-end/protection/magnetics/PCB/thermalเพิ่มขึ้นตามscopeจริง

ไม่มีการสั่งซื้อ ติดต่อร้าน หรือผูกพันการใช้เงินจากการจัดทำestimateนี้
