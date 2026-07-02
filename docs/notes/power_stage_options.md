# VSG Power Stage — Two Documented Approaches

> **Created:** 2026-05-30 — ภาคกำลัง 2 แนวทางที่รองรับคู่กัน
> **ของที่เหมือนกันทั้ง 2 ทาง (ไม่ต้องเลือก):** ESP32 control core, เฟิร์มแวร์ `vsg_controller.ino`
> (ขับ 3 MCPWM A-channel เหมือนกัน), บัส DC 40 V, $V_{set}$ 14 V (m=0.70), ฟิลเตอร์ $L_f$ 1.2 mH /
> $C_f$ 10 µF / $R_d$ 1 Ω, AD7606 + ACS712-20A, การควบคุม Option A (Stage 5c)
> **ต่างกันแค่:** ภาค MOSFET + วงจรขับเกต + แหล่งที่มาของสัญญาณ fault/dead-time

---

## ภาพรวมการเลือก

| มิติ | A: ดิสครีต IRF540N + IR2104 | B: DRV8302 shield |
|---|---|---|
| ต้นทุนภาคกำลัง | **~450 ฿** (+สำรอง ~200) | ~1,000–1,500 ฿ |
| พังแล้วฟื้น | เปลี่ยน MOSFET ~20 ฿/ตัว | เสียทั้งบอร์ด ~1,200 ฿ |
| โอกาสพัง | สูงกว่า (เดินสายเอง) | ต่ำกว่า (ป้องกันในตัว) |
| เวลาสร้าง | นานกว่า (PCB/protoboard เอง) | เร็ว (เสียบใช้) |
| หาของในไทย | เร็ว (ของ local) | ช้า (สั่งนอก) |
| การแยกกราวด์ | ❌ bootstrap (non-isolated) | ❌ bootstrap เช่นกัน |
| dead-time | IR2104 ภายใน ~520 ns | DTC resistor → ~350 ns |
| OCP | สร้างเอง (LM393 + shunt) | ในตัว (VDS sense) |
| current sense | ใช้ ACS712 ภายนอก | มี shunt amp ในตัว (+ACS712) |
| เรียนรู้ power electronics | สูง (ออกแบบเอง) | ต่ำ (กล่องดำ) |
| **เหมาะกับ** | **งบจำกัด + พังออกเอง** | **เน้นเร็ว/เสี่ยงต่ำ + มีงบ** |

**คำแนะนำตามงบ 7,200 ฿:** เริ่ม **A (ดิสครีต)** — ฟื้นถูก เริ่มได้เร็วเพราะของหาในไทยได้ ถ้าภายหลังอยากได้ความสะดวก/ลดความเสี่ยงค่อยซื้อ B มาเสริม (เฟิร์มแวร์รองรับทั้งคู่ สลับด้วย `#define`)

---

## แนวทาง A — ดิสครีต IRF540N + IR2104

### A.1 สถาปัตยกรรม
```
                 +Vbus(40V)
                    │
        ┌───────────┼───────────┬───────────┐
      [IRF540N HS] [HS]        [HS]     ← 3 ขา × ตัวบน
        │           │           │
   ┌──IR2104──┐ ┌IR2104┐  ┌IR2104┐   ← 1 ตัว/เฟส (HO,LO + dead-time ~520ns)
   │ IN  SD   │
  PWM_A  EN          ↑ IN=PWM_B,C   SD=common EN
      [IRF540N LS] [LS]        [LS]     ← 3 ขา × ตัวล่าง
        │           │           │
        └─ A ─┐ └─ B ─┐ └─ C ─┐  → ออกไป L_f → C_f+R_d → โหลด
              shunt (OCP) → LM393 → ESP32 FAULT pin
                    │
                  PGND
```
- MOSFET 6 ตัว (สะพาน 3 เฟส 2-ระดับ), IR2104 1 ตัว/เฟส รับ 1 PWM แล้วสร้าง HO/LO + dead-time เอง
- bootstrap: ไดโอด UF4007 + cap ~1 µF/ตัว ป้อนไฟ high-side
- gate resistor 22 Ω อนุกรมทุกเกต

### A.2 BoM (ราคาไทยประมาณ)
| รายการ | สเปก | จำนวน | ฿ |
|---|---|---|---|
| IRF540N (+สำรอง 6) | 100 V, 33 A, 44 mΩ | 12 | 250 |
| IR2104 (+สำรอง 1) | half-bridge, dead-time ~520 ns | 4 | 150 |
| bootstrap diode UF4007 | fast recovery | 3 | 30 |
| bootstrap cap 1 µF 50 V | film/ceramic | 3 | 20 |
| gate resistor 22 Ω | | 6 | 10 |
| LM393 + shunt + passives (OCP) | comparator | 1 ชุด | 80 |
| pull-up 10 kΩ → 3.3 V (สาย OCP_FAULT) | **บังคับ** — GPIO34 ไม่มี internal pull-up และ LM393 เป็น open-collector | 1 | 5 |
| **รวม** | | | **~545** |

### A.3 การป้องกัน
- **Dead-time:** IR2104 ภายใน ~520 ns (ไม่พึ่งซอฟต์แวร์)
- **OCP ฮาร์ดแวร์:** shunt → LM393 comparator → MCPWM FAULT pin (<1 µs) — **ต้องสร้างเอง**
- **Current-limit ที่ supply** ~3–4 A (ฟรี, สำคัญสุด)
- ไม่มี UVLO/OTP ในตัว → ต้องระวังตอน bring-up

### A.4 พิน ESP32
| สัญญาณ | GPIO | หมายเหตุ |
|---|---|---|
| PWM_A/B/C | 25/26/27 | → IN ของ IR2104 แต่ละตัว |
| GATE_EN | 22 | → SD ร่วมของ IR2104 ทั้ง 3 (**verify polarity**) |
| OCP_FAULT | 34 | ← LM393 (active LOW) — **ต้องมี external pull-up 10 kΩ → 3.3 V**: GPIO34–39 เป็น input-only ไม่มี internal pull-up และ LM393 เป็น open-collector; firmware ผูกขานี้เข้า MCPWM hardware fault F0 (one-shot force-low, <1 µs, latch ในชิป) + software poll สำรอง |

### A.5 ข้อควรระวัง
- เดินสาย **gate loop ให้สั้น** (พื้นที่ลูปเล็ก) ลด ringing/EMI ที่ 10 kHz
- bootstrap ต้องมี duty สลับเพื่อชาร์จ cap — soft-start เริ่ม duty ต่ำช่วยได้
- ตรวจ **SD polarity ของ IR2104** จาก datasheet ก่อน (enable vs shutdown level)
- bootstrap = non-isolated → **อย่าจับตัวนำขณะมีไฟ**

---

## แนวทาง B — TI DRV8302 shield

### B.1 สถาปัตยกรรม
บอร์ดสำเร็จ: DRV8302 ขับ MOSFET 6 ตัวบนบอร์ด มี buck (จ่าย 5 V ให้ ESP32), current-shunt amp 2 ช่อง, และชุดป้องกันในตัว ESP32 ขับ **3-PWM mode** (3 สัญญาณ) ชิปสร้าง complementary + dead-time เอง

### B.2 BoM
| รายการ | สเปก | จำนวน | ฿ |
|---|---|---|---|
| DRV8302 MOSFET shield | 8–60 V, 30 A peak, buck+sense+protect | 1 | 1,000–1,500 |
| R_DTC 100 kΩ (dead-time) | → ~350 ns | 1 | 5 |
| R_OC (OC_ADJ threshold) | ตั้ง OCP | 1 | 5 |
| **รวม** | | | **~1,010–1,510** |

### B.3 การป้องกัน (ในตัว)
- **OCP:** ตรวจ $V_{DS}$ ของ MOSFET, ตั้ง threshold ผ่าน OC_ADJ
- **UVLO:** ไม่ทำงานถ้าบัสต่ำกว่าเกณฑ์
- **OTP:** ตัดที่ junction >150°C
- **Dead-time:** DTC resistor 100 kΩ → ~350 ns
- ⚠ พิกัดสูงสุด 60 V → ที่ 40 V ปลอดภัย (derate 67%) แต่ **ห้ามไป 48 V** (transient อาจทะลุ)

### B.4 พิน ESP32
| สัญญาณ | GPIO | หมายเหตุ |
|---|---|---|
| PWM_A/B/C | 25/26/27 | → IN1/2/3 (3-PWM mode) |
| EN_GATE | 22 | → EN_GATE (active HIGH = enable) |
| nFAULT | 34 | ← active LOW |
| nOCTW | 39 | ← overcurrent/temp warning (optional) |

### B.5 ข้อควรระวัง
- ตั้ง **3-PWM mode** (ไม่ใช่ 6-PWM) ให้ตรงเฟิร์มแวร์
- ตั้ง OC_ADJ ให้ทริปเหนือกระแสพีคโหลด (~6.5 A) แต่ต่ำกว่าพิกัด MOSFET
- บอร์ด DRV8302 แท้หายาก/รอนาน — สั่งล่วงหน้า

---

## การสลับในเฟิร์มแวร์

ที่หัวไฟล์ `vsg_controller.ino`:
```c
#define POWER_STAGE  POWER_STAGE_IR2104    // แนวทาง A (budget)
// #define POWER_STAGE  POWER_STAGE_DRV8302 // แนวทาง B (shield)
```
Control core, SPWM, ลูป PI, AD7606 **เหมือนกันทุกบรรทัด** — `#define` เปลี่ยนแค่ความหมายของพิน fault/enable + อ่าน nOCTW (เฉพาะ DRV8302)

---

## สรุปเส้นทางแนะนำ
1. **เริ่ม A (ดิสครีต)** ภายในงบ — ของหาในไทยได้, ฟื้นถูก, ได้เรียนรู้
2. ถ้า A เดินสายแล้วเจอปัญหา EMI/พังบ่อย หรืออยากเร่งเวลา → ซื้อ **B (DRV8302)** มาเสริม สลับ `#define` ใช้เฟิร์มแวร์เดิม
3. ทั้ง 2 ทดสอบเทียบกับ `vsg_stage5c_out.mat` ได้เหมือนกัน (control core เดียวกัน)
