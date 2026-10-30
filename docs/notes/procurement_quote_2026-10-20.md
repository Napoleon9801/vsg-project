# VSG Procurement Quote — 2026-10-20

Prepared: 2026-10-20 UTC+7  
Runner/model: Codex desktop / GPT-6 (exact variant not exposed)  
Scope: First-pass sourcing for C01–C04 in `D:\workspace\engineering\vsg-project\docs\notes\procurement_agent_brief_2026-10-20.md`. This is a research quote, not a cart confirmation or purchase order. No seller was contacted and no order was placed.

## Decision summary

No item is `READY` for payment today. The user-provided MASSMORE listing details identify an ESP32-WROOM-32E/4 MB option, but the exact seller board/pin map and module marking remain unverified; the listed USB-C port also makes the previously identified Micro-B cable incompatible with this clone. The live AD7606 Shopee page now verifies listing claims and price but still lacks revision-specific module evidence. The user has now matched the ACS712 specs to Shopee candidate C04-S: its advertised supply/range/sensitivity match the target, but actual chip marking and board filter/thermal details remain unverified. ESP32 and AD7606 are confirmed not owned; ACS712 inventory remains unconfirmed. No inventory/receipts list was found under the project tree. The user has not supplied a spending cap, delivery deadline, or shipping address, so those must remain unknown while sourcing continues.

The Mouser Thailand cart now confirms the exact official ESP32-DevKitC-32E (WROOM-32E, 4 MB) at ฿340.20, one dispatching now. UPS Worldwide Express Saver is ฿600, so the cart subtotal is ฿940.20 before import charges. Mouser states duty, customs and taxes are collected at delivery; it also flags possible export documentation and shipment delays. DigiKey Thailand showed ฿328.80, zero stock and 252 expected 19 April 2027. A Thai Micro-B data cable candidate is in stock, but at ฿380 and with delivery charge not stated. AD7606 retail candidates lack the specific module schematic/revision and VDRIVE/reset evidence required by the brief. ACS712 module candidates state the expected transfer sensitivity but do not adequately document the exact board, output filter, stock, or returns.

## Candidate table

| ID | Item / exact candidate | Seller and direct listing | Qty | Published goods price | Shipping / tax / landed total | Status | Evidence gaps / next action |
|---|---|---|---:|---:|---|---|---|
| C01-A | Espressif ESP32-DevKitC-32E, classic ESP32-WROOM-32E, 4 MB; official board, Micro-B | [Mouser Thailand listing](https://th.mouser.com/en/ProductDetail/Espressif/ESP32-DevKitC-32E?qs=GedFDFLaBXFpgD0kAZWDrQ%3D%3D) | 1 | ฿340.20 | UPS Worldwide Express Saver ฿600; cart subtotal ฿940.20 before duty/customs/taxes due at delivery | SOURCE | Browser verified one unit dispatches now, embeds ESP32-WROOM-32E with 4 MB flash. Mouser flags possible U.S. export documentation and shipment delays. Board revision/header package details still need confirmation. |
| C01-B | Espressif ESP32-DevKitC-32E; official distributor Thailand | [DigiKey Thailand](https://www.digikey.co.th/th/products/detail/espressif-systems/ESP32-DEVKITC-32E/12091810) | 1 | ฿328.80 | Shipping/tax checkout total: UNKNOWN | REJECTED for first round | Latest reviewed listing showed 0 in stock and 252 expected 19 Apr 2027. Not a near-term source unless lead time is acceptable and stock changes. |
| C02-A | USB-A to Micro-B USB 2.0 cable, StarTech UUSBHAUB1M, 1 m | [Maxtech Thailand](https://maxtech.co.th/StarTech.com_UUSBHAUB1M.html) | 1 | ฿380.00 | Shipping/tax: UNKNOWN | REVIEW | Page showed 332 in stock and 7–10 working-day delivery; connector and USB 2.0 data description match the official DevKitC V4 Micro-B port. Confirm delivery fee and that a cable is not included with the selected board/order. High price relative to generic cables. |
| C03-A | AD7606 module listing, seller model SNE-TB143-202603E / Interpower, 8-channel simultaneous 16-bit module, ±10/±5 V claimed | [Alibaba listing](https://www.alibaba.com/product-detail/AD7606-8-Channel-16-Bit-Simultaneous_1601715311036.html) | 1 | USD 11.36 | Shipping negotiated; import taxes/fees and landed total UNKNOWN | REVIEW | Listing claims 8-channel 16-bit simultaneous sampling and 1-piece MOQ, but no revision-specific schematic/manual, chip-marking evidence, 3.3 V VDRIVE setting, serial pin access, reset source, CONVST wiring, or OS strap evidence was found. Not approved for checkout. Obtain photos of both sides and schematic/manual for the exact dispatched revision, then review against all C03 checks in the brief. |
| C03-B | AD7606 8-channel SPI module advertised as Arduino-compatible; board revision unspecified | [Plexishop listing](https://www.plexishop.it/en/8-channel-adc-module-for-arduino-ad7606.html) | 1 | EUR 41.50 incl. VAT shown | Thailand delivery and import charges UNKNOWN | REJECTED for first round | Listing describes AD7606, 8-channel, ±10/±5 V and SPI, and showed one ready to dispatch, but no module schematic, 3.3 V digital rail details, reset/strap evidence, or Thailand shipping proof was available. Higher listed cost does not resolve compatibility gaps. |
| C04-A | ACS712-20A current sensor module, SKU-00318; seller claims Allegro ACS712ELCTR-20A, ±20 A, 100 mV/A, 5 V | [ModuleMore](https://www.modulemore.com/product/318/acs712-20a-current-sensor-module) | 3 main + 1 spare (separate) | ฿60 each shown; ฿180 for 3 or ฿240 for 4 before unknown charges | Shipping and tax treatment/landed total UNKNOWN | REVIEW | Listing claims expected chip, sensitivity and supply. Board marking/photo, output filter capacitor value, terminal/copper-path assessment, stock, warranty/returns, and shipping quote remain unverified. Inventory of ACS712 modules also remains unconfirmed; do not buy until checked. Spare shown separately. |
| C04-B | ACS712-20A module, seller listing claims ±20 A and 100 mV/A; variant/marking not established | [ZoneMaker](https://www.zonemaker.com/product/541/20a-hall-current-sensor-module-acs712-20a) | 3 main + 1 spare (separate) | ฿49 each shown; ฿147 for 3 or ฿196 for 4 | Listing showed free shipping promotion; final checkout/tax amount UNKNOWN | REVIEW | Page snapshot showed 9 available. Exact chip marking, board filter, terminal construction and return terms not established. Not selected over ModuleMore; use only as a candidate if seller supplies the requested evidence. |

## Cost buckets

### A — Required first-round items

| Planned line | Current quote basis | Goods subtotal | Landed subtotal |
|---|---|---:|---:|
| C01 ×1 | Mouser official DevKitC-32E, browser-confirmed Thailand basket | ฿340.20 | ฿940.20 before import charges |
| C02 ×1 | Maxtech StarTech Micro-B data cable candidate | ฿380.00 | UNKNOWN |
| C03 ×1 | No qualified candidate | NOT READY | UNKNOWN |
| C04 ×3 | ModuleMore candidate, pending inventory and board evidence | ฿180.00 | UNKNOWN |

Order-ready total: **UNKNOWN**. No `READY` lines. The displayed goods prices are not a payable total and use mixed USD/THB; no exchange-rate conversion, delivery allocation, tax or duty has been invented.

### B — Optional spare

C01 spare ×1: ฿340.20 goods at the same Mouser listing snapshot; freight, import duty/tax and landed total UNKNOWN.  
C04 spare ×1: ฿60.00 at ModuleMore, landed cost UNKNOWN.  
Neither spare is included in the required subtotal.

### C — Power stage items

Not quoted for checkout in this pass. Keep power parts conditional on the PCB and design review; see the `Pxx` entries in `D:\workspace\engineering\vsg-project\docs\notes\shopping_list_2026-10-20.md` and sections 6–9 of the procurement brief.

### D — HOLD_DESIGN

Keep voltage-sensing/conditioning, independent hardware OCP and fault latch, DC-bus UV/OV interlock, DC-link capacitor bank, precharge/discharge/fuse/disconnect, STOP/ARM, energy sink/braking/snubber, and BESS interface out of the payable cart until their circuit, ratings, and compatibility are closed. Quote requests may be made after the relevant specifications are available.

### E — BORROW from the lab

Oscilloscope, differential probe, 40 V-capable CC/CV source, auxiliary supplies, multimeter, LCR meter, current probe, function generator, thermocouple/logger, soldering tools and logic analyzer remain `BORROW`; actual models, availability and loan date are unconfirmed. No new instruments added to the purchase total.

## Inventory result

- Confirmed absent from the brief: ESP32 and AD7606.
- Not confirmed: ACS712 modules, headers/sockets, wires, passive components, and power-stage/filter components.
- Project-tree search found no inventory, receipt, purchase, or stock record for these items. This is not proof that Napoleon owns none; check the physical parts and lab inventory before ordering C04/C05/C06 or any other repeated part.

## Technical checks and purchasing constraints

- C01 is the Espressif classic ESP32 DevKitC-32E / WROOM-32E, 4 MB target. Do not substitute S3/C3/C6 or an undocumented clone. The official DevKitC V4 uses Micro-B; verify selected board revision and cable inclusion.
- C03 is not ready until the exact board revision has documented AD7606 (not -6/-4), 5 V analog supply, configurable 3.3 V VDRIVE, serial interface, BUSY/CONVST/RESET access or documented power-up reset, selectable ±10 V range, disabled oversampling setting, input path, and usable connector pinout. Listing text alone does not pass these checks.
- C04 must be the ±20 A variant with 100 mV/A sensitivity and 5 V supply to match firmware constants. Module listing claims are not verification of the chip marking or continuous current capability of the board copper.
- The AD7606 is not galvanic isolation and does not provide voltage conditioning or independent protection.
- No seller was messaged; no checkout or order was submitted. Mouser cart contains one ESP32 board for quote review. A signed-in Shopee tab showed 5 pre-existing cart items before the search; no items were added or removed. Search redirected to Shopee traffic verification, which was not completed. No shipping address or payment data was accessed.

## Sources checked on 2026-10-20 UTC+7

- Manufacturer: [Espressif DevKitC documentation](https://documentation.espressif.com/projects/esp-dev-kits/en/latest/esp32/esp32-devkitc/user_guide.html); [Analog Devices AD7606 product page](https://www.analog.com/en/products/ad7606.html) and [AD7606 datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/ad7606_7606-6_7606-4.pdf); [Allegro ACS712 datasheet](https://www.allegromicro.com/-/media/files/datasheets/acs712-datasheet.pdf).
- Seller/stock/price listings: [Mouser ESP32-DevKitC-32E](https://www.mouser.com/en/ProductDetail/Espressif-Systems/ESP32-DevKitC-32E?mgh=1&qs=GedFDFLaBXFpgD0kAZWDrQ%3D%3D); [DigiKey Thailand ESP32-DevKitC-32E](https://www.digikey.co.th/th/products/detail/espressif-systems/ESP32-DEVKITC-32E/12091810); [Maxtech cable](https://maxtech.co.th/StarTech.com_UUSBHAUB1M.html); [Alibaba AD7606 candidate](https://www.alibaba.com/product-detail/AD7606-8-Channel-16-Bit-Simultaneous_1601715311036.html); [Plexishop AD7606 candidate](https://www.plexishop.it/en/8-channel-adc-module-for-arduino-ad7606.html); [ModuleMore ACS712 module](https://www.modulemore.com/product/318/acs712-20a-current-sensor-module); [ZoneMaker ACS712 module](https://www.zonemaker.com/product/541/20a-hall-current-sensor-module-acs712-20a).
- Import charges: [Mouser sales terms](https://th.mouser.com/th/saleterms/) state international VAT and brokerage fees are the customer's responsibility at delivery. Exact charges depend on final shipment details and remain UNKNOWN here.

## To close the quote into an order

1. Check physical and lab inventory, especially ACS712 count, before fixing quantities.
2. Select the board and confirm whether its package includes a USB data cable.
3. Request exact AD7606 module photos and revision-matched schematic/manual; hold purchase unless every C03 requirement is supported.
4. Confirm candidate stock, shipping to the user's confirmed address, tax/international charges, delivery estimate, and return terms at checkout.
5. Set a purchase cap and acceptable delivery conditions before any order confirmation. Do not place HOLD_DESIGN items in the payable cart.

## Browser verification update — 2026-10-20 UTC+7

- Rechecked the existing Mouser Thailand cart in the browser: exact ESP32-DevKitC-32E, quantity 1, ฿340.20; UPS Worldwide Express Saver ฿600; subtotal ฿940.20. Taxes/customs are collected at delivery. The page warns of shipment delays and possible export documentation. No checkout was submitted.
- Shopee's signed-in home showed 5 items already in the cart. A product search redirected to its traffic verification page; no challenge was attempted and no cart item was changed. I restored the browser to the signed-in Shopee home page; the five-item cart remains untouched.
- No address or payment details were entered. Order status remains NOT ORDERED; no READY candidate was established for C01–C04.

## Shopee search candidates — 2026-10-20 UTC+7

These are sourcing leads, not approved-to-order options. Shopee result cards were read through the signed-in browser and indexed product pages. Opening a product detail in the browser failed; no option was selected and no item was added to any cart.

| ID | Candidate listing | Shopee snapshot | Match assessment | Status |
|---|---|---|---|---|
| C01-S | [MASSMORE ESP32 38-pin DevKitC/NodeMCU-32S, CH340](https://shopee.co.th/%E0%B8%9A%E0%B8%AD%E0%B8%A3%E0%B9%8C%E0%B8%94%E0%B8%9E%E0%B8%B1%E0%B8%92%E0%B8%99%E0%B8%B2-ESP32-38PIN-%E0%B8%8A%E0%B8%B4%E0%B8%9E%E0%B9%81%E0%B8%97%E0%B9%89-Espressif-ESP32-WROOM-32E-32UE-NodeMCU-32S-DevKitC-CH340-Massmore-i.5641091.26018107849) | Listing snapshot ฿379; search card showed 224 sold, 5.0 rating, Chiang Mai, 2-3-day delivery. User-pasted option details identify ESP32-WROOM-32E / 4 MB / CH340 (PCB antenna) and 32UE / 4 MB / CH340 (U.FL, no antenna); board description says USB-C. | The 32E/4 MB option matches the MCU/module class and flash target. Still a third-party clone: request clear module/board photos and an exact 38-pin map covering firmware GPIOs; confirm shipped variant. Because firmware uses GPIO2, GPIO12 and GPIO15, check external circuit loading of classic ESP32 strapping pins before connecting peripherals at reset. Existing Micro-B C02 candidates do not fit this USB-C board; select a USB-C data cable if this board is chosen. | REVIEW |
| C02-S | [Vention USB 2.0 A to Micro-B data cable](https://shopee.co.th/Vention-%E0%B8%AA%E0%B8%B2%E0%B8%A2%E0%B8%8A%E0%B8%B2%E0%B8%A3%E0%B9%8C%E0%B8%88-Micro-USB-2A-%E0%B8%AA%E0%B8%B2%E0%B8%A2%E0%B9%81%E0%B8%88%E0%B9%87%E0%B8%84%E0%B9%80%E0%B8%81%E0%B9%87%E0%B8%95-PVC-%E0%B8%97%E0%B8%99%E0%B8%97%E0%B8%B2%E0%B8%99%E0%B9%83%E0%B8%99%E0%B8%9B%E0%B8%B1%E0%B8%88%E0%B8%88%E0%B8%B8%E0%B8%9A%E0%B8%B1%E0%B8%99%E0%B9%80%E0%B8%82%E0%B9%89%E0%B8%B2%E0%B8%81%E0%B8%B1%E0%B8%99%E0%B8%94%E0%B9%89%E0%B8%A7%E0%B8%A2%E0%B9%82%E0%B8%97%E0%B8%A3%E0%B8%A8%E0%B8%B1%E0%B8%9E%E0%B8%97%E0%B9%8C%E0%B8%A1%E0%B8%B7%E0%B8%AD%E0%B8%96%E0%B8%B7%E0%B8%AD-Xiaomi-Samsung-i.285714215.28951232340) | Indexed range ฿71-184 (another option displayed ฿69); free shipping, Fulfilled by Shopee, 15-day returns, Vention Global Store 4.9/100% chat response. Crawl showed an expired delivery estimate; recheck live checkout. | Listing title claims USB 2.0 A-to-Micro-B and 480 Mbps data sync, matching official DevKitC V4's Micro-B data link. Exact length/variant and price are not verified; unsuitable if the selected board is USB-C. | REVIEW |
| C03-S | [EC buying.th AD7606 8-channel, 16-bit module, 200 kHz](https://shopee.co.th/AD7606-Multi-channel-ADC-Analog-to-Data-Acquisition-Conversion-Module-16-bit-8-channel-Synchronization-Sampling-%E0%B8%84%E0%B8%A7%E0%B8%B2%E0%B8%A1%E0%B8%96%E0%B8%B5%E0%B9%88-200KHz-i.1633960256.49902509678) | Live Shopee page 2026-10-20: ฿1,021 after displayed shop-code discount; two color options; in stock; free shipping; estimated delivery 27–31 Oct; seller EC buying.th, 4.9 rating, 2k seller ratings, 97% chat response. | Page and user-provided duplicate text copies claim AD7606, DC 5 V, 3.3 V logic, 8 simultaneous channels, 16 bit, 200 kSPS/channel, SPI/parallel, ±5/±10 V. However, listing says to contact seller after purchase for module PDF/source code, has no engineering files, and explicitly warns that chip features are reference only and may not exist on the module. No revision-specific schematic/photos, VDRIVE implementation, wiring/pin map, reset/CONVST/BUSY access, ±10 V selection, or OS=0 evidence. Listing's oversampling choices omit a clearly documented disabled setting. Keep REVIEW; do not order until seller provides and these documents pass C03 checks. |
| C04-S | [ACS712-20A current sensor module](https://shopee.co.th/ACS712-20A-current-sensor-module-i.132454846.5516669325) | Earlier listing snapshot: ฿75 and free shipping; seller 4.9 and 72% chat response. Snapshot was indexed 2 months ago and delivery estimate has passed, so recheck live price/stock. User confirms the pasted description is from this candidate and claims Thailand stock. | User-provided detail text advertises 4.5–5.5 V supply, ±20 A range and 100 mV/A, matching C04 nominal requirements; it also lists Connection Detail, datasheet and Arduino sample code. The physical board/module marking, exact downloadable connection document, FILTER capacitor, output pin/access, terminal/copper path and thermal suitability remain unverified. REVIEW; check inventory before buying and inspect downloads/photos before qualification. | REVIEW |

### Shopee conclusion

- Closest Shopee controller candidate: C01-S, with user-pasted listing details identifying the 32E/4 MB option; still review-only pending board/module photos, pin map, and strapping-pin loading check. Its USB-C port requires a USB-C data cable. C02-S Micro-B is suitable only if the official Micro-B DevKitC candidate is selected.
- AD7606 candidate C03-S remains not checkout-ready; the live page confirms the claimed top-line specs and price but not the module implementation. Obtain front/back board photos and revision-specific schematic/manual, especially VDRIVE, serial pins, range straps, reset/CONVST/BUSY, and OS=0.
- ACS712 candidate C04-S now has user-provided listing details that match the target supply/range/sensitivity and advertise supporting downloads; inspect those downloads and board photos, verify marking/filter/current path, and confirm inventory before purchase.
- Shopee product-detail pages were accessible in this follow-up. No seller was contacted, no CAPTCHA was attempted, no item was added to the cart, and no checkout/order was submitted.
