# ร้านไทยและ marketplace shortlist สำหรับ VSG — 29 ตุลาคม 2026

Runner/model: Codex desktop / GPT-6. AD7606/inductor research: engineering evidence reviewer.
สถานะ: หาร้าน/เทียบสินค้าเท่านั้น ยังไม่ได้สั่งซื้อ ใส่ตะกร้า หรือติดต่อผู้ขาย
Baseline40V/100W islanded ใช้Stage5dอ้างอิง; ไม่เปลี่ยนfirmwareหรือแบบเพื่อให้เข้ากับสินค้าโดยอัตโนมัติ

## สินค้าที่พบ

| สินค้า/จำนวน | ร้านและลิงก์ตรง | ราคาที่พบ | หลักฐานการส่ง/ราคา | สถานะก่อนซื้อ |
|---|---|---:|---|---|
| ESP32-WROOM-32E4MB38pin USB-C x1 | [MASSMORE / Shopee](https://shopee.co.th/product/5641091/26018107849) |369บาทในindexed listing; historical379ไม่ถือว่าราคาสด | Browserเปิดรายละเอียดได้ ระบุส่งจากเชียงใหม่และมี32E/32UE; จากนั้นเว็บredirectให้loginจึงยืนยันราคาตัวเลือกไม่ได้ | เลือก32E4MB,ตรวจราคาvariantในแอป; ไม่ใช่S3/C3/C6 ไม่ถือthird-partyPCBเป็นofficialDevKitC |
| ACS712-20A x3 | [ModuleMore](https://www.modulemore.com/product/318/acs712-20a-current-sensor-module) |60/ตัว;180รวม | Browserสดแสดง60บาทและพร้อมส่ง | รุ่น20Aตามscaling; ต้องcalibrate/ตรวจmoduleก่อนfeedback; ไม่ถือ20Aเป็นพิกัดบอร์ดต่อเนื่อง |
| USB-Cdata30cm x1ถ้ายังไม่มี | [ModuleMore SKU02452](https://www.modulemore.com/product/2452/สาย-usb-เป็น-usb-type-c-สำหรับอัพโหลดบอร์ด-arduino-esp32-type-c-ยาว-30cm) |45บาทหลักฐาน21ต.ค.; ไม่ตรวจราคาสดรอบนี้ | เก็บไว้เป็นconditional ไม่รวมว่าverifiedtoday | ใช้สายdataที่มีอยู่ได้ |
| IRF540NTO220 x10 ใช้6สำรอง4 | [ArduinoAll/AllNewStep](https://www.allnewstep.com/product/1129/mosfte-irf540n) |15/ตัว;150รวม | Browserสดแสดง15บาทพร้อมส่ง; ร้านไทย | ร้านระบุIRF540N; ยังไม่พิสูจน์manufacturertraceabilityหรือlotauthenticity ไม่ใช้headlinecurrentเป็นพิกัดระบบ |
| IR2104 DIP/SMD x4 ใช้3สำรอง1 | [KABO Electronic / Shopee](https://shopee.co.th/product/755103386/25041382141) |127–131/ตัว;508–524รวมก่อนส่วนลด | indexed productpage; ร้านกรุงเทพ/ชื่อสินค้าพร้อมส่งไทย; ไม่verifiedcheckout | ขอรหัสเต็ม/marking/เลือกSMDตรงSOIC8PCB ไม่ถือDIPแทนได้หรือข้อความoriginalเป็นหลักฐานของแท้ |
| Load10Ω50W x3 | [CVC-PP / Lazada](https://www.lazada.co.th/products/pdp-i5305316694.html) |44/ตัว;132รวม | Browserสดเลือก50W/10Rแล้วราคา44; รายละเอียดระบุพร้อมจัดส่งที่ไทย | ยังไม่มีmanufacturerderating/thermalqualification; ต้องตรวจmount/heatsink/ค่าRจริง |
| Load3Ω100W x3 | [CVC-PP / Lazada](https://www.lazada.co.th/products/pdp-i5305316694.html) |120/ตัว;360รวม | Browserสดเลือก100Wแล้ว3R ราคา120; มีตัวเลือกจริง | เช่นเดียวกัน ไม่ใช่3Ωที่รับ100Wได้โดยไม่มีเงื่อนไขระบายความร้อน |
| Load50Wหลายค่าincl10R ทางเลือก | [เทคโนโลยี UyghurUyghur / Shopee](https://shopee.co.th/product/196639923/19088757101) |42ในindexed page | ไม่ทราบประเทศต้นทาง; deliverywindowเก่า ไม่รับรองราคาvariant | เก็บเป็นleadรอง ไม่รวมในdomesticverifiedbasket |

ราคาไม่รวมค่าส่งจริงถึงNapoleon ภาษีที่ร้านอาจยังไม่รวม หรือคูปองผู้ใช้ หน้าสินค้าLazadaเลือกที่อยู่defaultกรุงเทพ10110และแสดงส่ง29บาท; ไม่ใช้เป็นค่าส่งถึงผู้ใช้ ไม่อ้างdeliverydateเก่าในindexedShopeeเป็นกำหนดส่งจริง

## AD7606: พบราคาต่ำลง แต่ยังไม่ยืนยันส่งจากไทยและเข้ากับfirmware

| ร้าน | ลิงก์ | ราคาบนหน้าที่ดึงมา | ข้อจำกัด |
|---|---|---:|---|
| thgoodstore.th / Shopee | https://shopee.co.th/product/1477286806/42066397511 |531บาท (searchsnippetอีกจุด722) | indexedcopyมีdeliverywindowเก่า; ship-fromไม่ระบุ |
| hejunkeji.th / Shopee | https://shopee.co.th/product/307980131/26187745007 |799บาท | indexedcopyมีdeliverywindowเก่า; ship-fromไม่ระบุ |

ชื่อร้านลงท้าย.thไม่ได้แปลว่าของอยู่ไทย ทั้งสองเป็นleadที่ต้องตรวจ originalAD7606ครบ8ช่อง, serialmode,AVCC5V/VDRIVE3.3V,±10V,OSoff,RESET/CONVST/BUSY/CS/SCLK/DOUTและschematicของrevisionจริง ไม่สรุปว่าผ่านหรือใช้ราคา531แทนADCที่qualifiedแล้ว

## คอยล์ฟิลเตอร์: ร้านไทยสำหรับขอแบบ/ราคา

- [KV Electronics — output filter](https://kv-electronics.com/products/inductor/output-filter.html), ที่อยู่สมุทรปราการ; รับcustominductance/current/formfactorตามหน้าเว็บ ช่วงสินค้า1uH–10mH/Isat0.5–50Aเป็นportfolioไม่ใช่สเปกชิ้นเดียว ยังไม่มีราคา/MOQ/part1.2mHที่อนุมัติ ต้องสอบถามงานAC50Hz+PWM10kHzและcurrentenvelopeของโครงงานโดยเฉพาะ
- [MPI-NEO](https://mpineo.com/th/), ผู้ผลิตcoils/inductorsสมุทรสาคร เป็นleadขอราคา ยังไม่มีquoteหรือยืนยันรับ3ตัว
- ตัดออก: [ElectronicsSource1.2mH](https://www.es.co.th/detail.asp?Prod=021900492) ราคา4.58ก่อนVATเป็นคอยล์210mA/DCR6.6ohm ไม่เหมาะกับfilterนี้ แม้ค่าmHตรง
- ตัดออกจากdrop-in: AIRD-03-122Kที่พบrated2A/Isat3.7A/DCR462mohm ไม่ใช่ตัวแทนที่qualifiedสำหรับbaseline อย่าซื้อcommon-modechokeจากค่า1.2mH5Aเพียงอย่างเดียว

## ผลต่องบ

โหลดCVC-PPสองชุดราคาหน้าเว็บรวม3*44+3*120=492บาทก่อนส่ง เทียบanchorRSเดิม2207.04รวมVAT ต่างรายการสินค้า1715.04บาท อย่างไรก็ดีเป็นต่างยี่ห้อ/เอกสาร/เงื่อนไขthermal ไม่ใช่replacementที่ตรวจรับแล้วหรือเงินประหยัดถึงมือแน่นอน ต้องตรวจภาษี/ส่งและqualification

หากคงทุกallocationเดิมและแทนเฉพาะloadline2207ด้วย492ในlowbudget จะได้(12557-2207+492+900)*1.2=14090.40บาท เป็นsensitivityเท่านั้น ไม่ใช่quoteใหม่หรือคำรับรองรวมโครงงาน ยังไม่ได้ลดด้วยราคาชิ้นอื่นเพื่อไม่ผสมราคาindex/variantunknownเป็นยอดรับรอง

ชิ้นส่วนMOSFET15บาทไทยไม่ได้แปลว่าถูกกว่าanchorauthorizeddistributorเดิมทุกตัว; เป้าหมายคือlandedcost/availability/traceability ไม่เลือกmarketplaceอัตโนมัติ ค่าส่งและfootprintdriverสำคัญ

ยังขาดqualifiedquotesสำหรับfiltercapacitors/damping,voltageconditioning,independentprotection,DC-link/precharge/energyhandling,PCBและthermal/wiring ไม่รับรองงบ7200ครบจากpartialshortlistนี้

## วิธีใช้shortlist

ให้ความสำคัญกับMASSMORE32E,ModuleMore,ArduinoAllและCVC-PPเป็นร้านเปรียบเทียบในไทย; KABOเป็นdriverleadที่ต้องเลือกpackage ส่วนAD7606และคอยล์ยังHOLDรายละเอียด ไม่มีการถามร้านหรือสั่งซื้อให้ผู้ใช้ ใช้inventoryแล็บเมื่อมีข้อมูลเพื่อตัดรายการซื้อซ้ำ

BrowserShopeeเปิดรายละเอียดMASSMOREได้ก่อนredirectlogin ไม่พยายามข้ามข้อจำกัด; Lazadaอ่านและเลือกvariantได้ ราคาคูปอง/stockขั้นcheckoutยังไม่ยืนยัน
