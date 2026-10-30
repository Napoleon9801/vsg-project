# Manual Simulink Rebuild — Progress Log

> บันทึกความคืบหน้า track "สร้างโมเดล Simulink ด้วยมือ" (ฝึกทักษะ + ใช้รายงานอาจารย์)
> โมเดลอ้างอิง = .slx ที่ script `phaseN_*.m` สร้างอัตโนมัติ / โมเดล manual = สร้างเองใน GUI
> ทุก stage ต้องผ่าน validator (เทียบ trace กับ reference, tolerance 1e-4) ก่อนไป stage ถัดไป

| Stage | โมเดล | สถานะ | วันที่ผ่าน | max error |
|---|---|---|---|---|
| 1 — Swing equation | `vsg_stage1_manual.slx` | ✅ PASS | 2026-07-15 | Δf 5.5e-6 Hz, Δδ 2.7e-11 rad |
| 2 — Power-angle feedback | `vsg_stage2_manual.slx` | ✅ PASS | 2026-07-16 | Δf 5.6e-6 Hz, Δδ 2.6e-6 rad |
| 3 — Islanded + droop | — | ถัดไป | — | — |
| 4 — Inverter dq | — | รอ | — | — |
| 5a–5d | — | รอ (อาจใช้ script ต่อยอด) | — | — |

---

## Stage 1 — Swing Equation ✅ (2026-07-15)

**สิ่งที่ทำ:**
- สร้าง `vsg_stage1_manual.slx` ด้วยมือใน Simulink R2018b ตามคู่มือ
  `STAGE1_MANUAL_BUILD.md` — 13 blocks: swing eq loop (Sum → Gain ω_s/2H →
  Integrator ω → damping D feedback) + integrator δ + Scope/To Workspace
- ทดสอบ: step Pm +0.1 pu ที่ t = 1 s (H = 5 s, D = 10, T_sim = 10 s)
- ตรวจด้วย `validate_stage1_manual.m` เทียบกับ `vsg_stage1_out.mat`

**ผล:**

| ปริมาณ | ทฤษฎี | ที่วัดได้ |
|---|---|---|
| Δω_ss = ΔP/D | 0.01 rad/s | 0.01 rad/s ✓ |
| f_ss | 50.00159 Hz | 50.00159 Hz ✓ |
| max \|Δf\| vs reference | < 1e-4 | **5.5×10⁻⁶ Hz** |
| max \|Δδ\| vs reference | < 1e-4 | **2.7×10⁻¹¹ rad** |

**รูปประกอบ:** `stage1_progress.png` (overlay manual vs reference —
บน: ความถี่ step ขึ้น 50 → 50.0016 Hz / ล่าง: δ ไต่เป็น ramp ถึง ~5.2°)

**ข้อสังเกต:** δ ไต่ไม่ลู่เข้า = ถูกต้องตามคาด เพราะ Stage 1 ให้ Pe คงที่
ไม่มี restoring torque — เป็น motivation ของ Stage 2 (Pe = Pmax·sin δ)

**บทเรียนที่เจอจริง:** Scope 2 สัญญาณบนแกนเดียว (314 rad/s กับ 0.09 rad)
มองอะไรไม่เห็น — ต้องแยก layout หรือ plot จาก workspace; และ Scope default
"Limit data points to last 5000" ตัด trace ช่วงต้นหาย

**ข้อความ progress ที่ส่งอาจารย์ (2026-07-16):**

> อัปเดตความคืบหน้างาน sim ครับอาจารย์
>
> ตอนนี้ผมกลับมาทำต่อ โดยเริ่มสร้างโมเดล Simulink ใหม่ด้วยตัวเองตั้งแต่
> Stage 1 ครับ (ของเดิมสร้างผ่าน script อัตโนมัติ รอบนี้ตั้งใจไล่ต่อ block
> เองทีละตัวเพื่อให้เข้าใจโครงสร้างจริง ๆ)
>
> Stage 1 — Swing equation เสร็จแล้วครับ:
> • ทดสอบ step กำลังกล +0.1 pu ที่ t = 1 s (H = 5 s, D = 10)
> • Δω steady-state = ΔP/D = 0.01 rad/s ตรงกับคำนวณมือ (f_ss = 50.0016 Hz)
> • มุม δ ไต่ไม่ลู่เข้า ตามคาด เพราะ stage นี้ยังไม่มี restoring torque
>   (Pe คงที่) — เป็นเหตุผลที่ Stage 2 ต้องปิด loop ด้วย Pe = Pmax·sin δ
> • ตรวจความถูกต้องด้วยการเทียบ trace กับโมเดลอ้างอิง คลาดเคลื่อนสูงสุด
>   5.5×10⁻⁶ Hz (รูปแนบ)
>
> ขั้นถัดไปคือ Stage 2 (power-angle feedback) ครับ จะทยอยอัปเดตเรื่อย ๆ ครับ

---

## Stage 2 — Power-Angle Feedback ✅ (2026-07-16)

**สิ่งที่ทำ:**
- Save As จาก `vsg_stage1_manual.slx` แล้วแก้ 5 จุดตาม `STAGE2_MANUAL_BUILD.md`:
  ลบ Pe constant / เพิ่ม `Sin_delta` + `Gain_Pmax` (2.1) ปิด loop เข้า
  `Sum_PmPe` ขา − / `Gain_D` 10 → 0.3 / `Int_delta` IC = asin(1.0/2.1) /
  StopTime = 5 s
- ตรวจด้วย `validate_stage2_manual.m` เทียบกับ `vsg_stage2_out.mat`

**ผล:**

| ปริมาณ | อ้างอิง | ที่วัดได้ |
|---|---|---|
| δ_final | 31.588° | 31.588° ✓ |
| δ_peak (overshoot) | 31.842° | 31.842° ✓ |
| f_peak | 50.0323 Hz | 50.0323 Hz ✓ |
| f_final | 50.0000 Hz (กลับ synchronous) | 50.0000 Hz ✓ |
| max \|Δf\| vs reference | < 1e-4 | **5.6×10⁻⁶ Hz** |
| max \|Δδ\| vs reference | < 1e-4 | **2.6×10⁻⁶ rad** |

**รูปประกอบ:** `stage2_progress.png` — 3 ช่อง: ความถี่สวิงแล้วกลับ 50 Hz /
δ 28.44° → overshoot 31.84° → นิ่ง 31.59° / Pe ลู่เข้า 1.1 pu ตาม Pm ใหม่

**บั๊กที่เจอ + วิธีเจอ:** validate รอบแรก FAIL — ทุก trace เป็นศูนย์
สาเหตุ: สายเข้า `ToWS_omega`/`ToWS_delta` หลุดทั้งคู่ระหว่างจัดผัง
(Simulink ตีความ input ที่ไม่ต่อเป็น 0 โดยไม่ error — มีแค่ warning ตอน sim)
โครงสร้าง loop ทั้งหมดถูกอยู่แล้ว ต่อสาย 2 เส้นคืนแล้วผ่านทันที
→ บทเรียน: warning "Input port not connected" ตอนรัน = ต้องกลับไปดู ไม่ใช่ข้าม

**ฟิสิกส์ที่ยืนยันได้จาก stage นี้:** เมื่อ grid-connected ความถี่กลับ 50 Hz
เสมอ พลังงานส่วนเกินไปอยู่ที่มุม δ (28.44° → 31.59°) — ต่างจาก Stage 1
ที่ความถี่ค้าง offset เพราะไม่มี restoring torque

**ร่างข้อความ progress ส่งอาจารย์:**

> อัปเดตครับอาจารย์ — Stage 2 (power-angle feedback) เสร็จแล้วครับ
> ปิด loop ด้วย Pe = Pmax·sin δ (grid-connected กับ infinite bus ผ่าน X = 0.5 pu)
> ผล step +0.1 pu: δ สวิงจาก 28.44° → 31.59° (overshoot 31.84°, ζ ≈ 0.62
> ตรง linearised prediction) และความถี่กลับ 50 Hz พอดี ต่างจาก Stage 1
> ที่ค้าง offset — ยืนยันพฤติกรรม synchronous machine ที่ VSG เลียนแบบครับ
> เทียบ trace กับโมเดลอ้างอิงคลาดเคลื่อนสูงสุด 5.6×10⁻⁶ Hz (รูปแนบ)
> ถัดไป Stage 3: โหมด islanded + P-f droop ครับ

---

<!-- Stage 3 entry: เพิ่มที่นี่หลัง validate ผ่าน -->
