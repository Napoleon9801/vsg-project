# Stiff-source inertia test (simulation only, 2026-11-10)

**ขอบเขต:** เป็นการขยายใน sim เท่านั้น baseline hardware ที่อาจารย์อนุมัติยังเป็น islanded ไม่มีการออกแบบการต่อกริดจริง
**คำถาม:** ถ้า VSG ต่อกับแหล่งจ่ายภายนอกที่ความถี่ลดลง มันจะปล่อยพลังงานจาก "rotor เสมือน" ออกมาตามค่า H ที่ตั้งไว้จริงหรือไม่

ไฟล์:
- Runner: `D:\workspace\engineering\vsg-project\matlab\run_vsg_stiff_source.m` (jobs: `run_vsg_stiff_source_*_job.m`)
- วิเคราะห์: `D:\workspace\engineering\vsg-project\python\analysis\vsg_stiff_source_analysis.py`
- ผล: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\vsg_stiff_source\` (`stiff_source_energy.json`, `report_*.json`)
- รูป: `D:\workspace\engineering\vsg-project\docs\figures\vsg_stiff_source_inertia_2026-11-10.png`

## Setup
- ต้นทางคือโมเดล `vsg_e12_ff_load_cycle.slx` (Stage 5i switching + FF) คัดลอกเป็น `vsg_stiff_source.slx` ไม่ได้แก้ต้นฉบับ
- แหล่งจ่าย: Controlled Voltage Source 3 ตัวต่อ **Y แบบ floating** (ไม่มี zero-sequence path ไป DC−) 14 V peak, f_g(t) = 50 Hz แล้ว ramp −0.25 Hz/s นาน 0.8 s (Δf = −0.2 Hz) แล้วค้าง
- line ต่อเฟส: R 0.05 Ω + L (ดูแต่ละเคส) ต่อเข้าที่ PCC (โหนด Cf/โหลด)
- P_set = 0.3 pu ปิด secondary คงโหลด RL ที่ low-demand ไว้ และปรับ H ผ่าน `Gain_inv_2Hws = ωs/(2H)`
- **ข้อควรระวังที่เจอ:** บน R2018b ขั้ว `LConn1` ของ Controlled Voltage Source คือ **−** ถ้าต่อผิดแหล่งจ่ายจะกลับเฟส 180° (ตรวจจาก data ได้ corr −1.000) runner แก้แล้ว

## ผล 1: สภาพที่ใช้ทดสอบได้/ไม่ได้

| เคส | ผล |
|---|---|
| FF on, X = 0.15 pu (1.4 mH) | **แกว่งรุนแรงต่อเนื่อง** P −490…+790 W, I_grid ถึง 39 A |
| FF on, X = 0.40 pu (3.74 mH) | **ยังแกว่งรุนแรง** −230…+530 W |
| FF off, X = 0.15 pu, 4.4 s | **หลุด synchronism (pole slip)** f_vsg ไปถึง 51.2 Hz และมุมสะสมถึง **364°** |
| **FF off, X = 1 pu (9.36 mH)** | **sync ได้** นิ่งที่ ~1.5 s, P = 30.0 W = P_set, f = 50 Hz, ไม่ slip ระหว่าง ramp |

**ข้อสรุปเชิงออกแบบ:**
1. **E1.2 FF ใช้กับโหมดต่อกริดไม่ได้** เพราะ "output current" รวมกระแสกริดด้วย การ feedforward ทำให้ loop ไม่เสถียร FF ยังใช้ได้ใน islanded ตาม scope แต่ต้องปิดหรือ gate เมื่อมีแหล่งจ่ายอื่น
2. **controller เดิม (ไม่มี FF) sync กับกริดที่แข็งไม่ได้** สาเหตุเดียวกับ E1.2: conductance ของกริดผ่าน line (≈2.3 S ที่ X = 0.15 pu) ใหญ่กว่า Kp_v (0.0089) ราว 250 เท่า voltage-loop integrator จึงใช้เวลา τ ≈ 0.58 s กว่ามุม rotor จะกลายเป็นกำลังไฟฟ้า synchronizing power มาช้ากว่า swing dynamics มาก จึงแกว่งจนหลุด
3. VSG แบบ cascaded voltage/current loop ที่ออกแบบสำหรับ Cf ล้วน **ต่อได้แค่กับกริดที่อ่อน** (SCR ≈ 1) ถ้าจะต่อกริดที่แข็งต้องออกแบบ voltage loop ใหม่หรือเปลี่ยน architecture (เช่น virtual impedance) ซึ่งอยู่นอก scope islanded ปัจจุบัน

## ผล 2: Inertia ที่กริดได้รับ (X = 1 pu, FF off, 6 s, ramp 3.2–4.0 s)

วิธี: เทียบ run ที่ต่างกันแค่ H พลังงานส่วนเกินที่ VSG จ่าย `∫(P_H − P_H0.05) dt` ควรเท่ากับพลังงาน rotor ที่ปล่อยออกมา `2·ΔH·S·Δw` (Δw = 0.004 pu, S = 100 VA) ส่วนของ droop (K∫w dt) และ LPF (τf·ΔP) ตัดกันได้เพราะทุก run จบที่ P และมุมเดียวกัน

**ผลสุดท้าย (superposition)**: รันซ้ำทุก H โดยไม่มี ramp แล้วใช้ `response_H = P_ramp,H − P_noramp,H` เพื่อตัด transient ตอน start-up ออกพอดี (response ก่อน event < 5×10⁻⁵ W)

| H (s) | P ก่อน → หลัง (W) | P peak (W) | พลังงานส่วนเกิน (superposition) | ทำนาย 2ΔH·S·Δw | อัตราส่วน | หลังแก้ K-leak |
|---|---|---|---|---|---|---|
| 0.05 (อ้างอิง) | 30.0 → 100.0 | 100.1 | — | — | — | — |
| 5 | 29.8 → 100.1 | 101.6 | **3.88 J** | 3.96 J | **0.981** | 0.994 |
| 10 | 29.7 → 99.7 | 106.1 | **7.99 J** | 7.96 J | **1.004** | 0.987 |

- **พลังงานตรงกับทฤษฎีภายใน ±2% และเชิงเส้นตาม H** **นี่คือหลักฐานตรงที่สุดว่า H ในตัวควบคุมคือ inertia ที่ระบบภายนอกได้รับจริง** ไม่ใช่แค่ LPF
- ส่วนที่เหลือ ~1% สอดคล้องกับ P ที่ PCC ต่ำกว่า P_meas ของ controller 0.6–0.7%
- ไฟล์: `stiff_source_energy_superposition.json`; control runs `noramp_x100_H*` (MATLAB segfault ตอน exit **หลัง** บันทึกครบทั้ง 3 run ข้อมูลไม่เสียหาย)

### ที่มาของ "+10%" ในรอบแรก (เป็น artifact ของการวิเคราะห์)
รอบแรกได้ 4.34 J / 8.75 J (+9.5% / +10%) ตรวจสาเหตุแล้ว:
1. **Swing equation closure** ต่อ run: `2H·Δw + ∫(P_f − P_set + K·w)dt ≈ 5×10⁻⁵ pu·s` ทุก run เทอม 2H·Δw = −0.0399/−0.0795 (คาด −0.040/−0.080) → **H ถูก implement ตรงตามที่ตั้ง**
2. **ระบบยังไม่นิ่งตอน ramp เริ่ม (3.2 s)**: P_vsg ยัง drift จาก start-up (H = 0.05 ยังลดลง, H = 10 ยังเพิ่มขึ้น) วิธีเดิมลบ offset ก่อน event (−0.18/−0.29 W) เป็นค่าคงที่ตลอด 2.8 s จึงเพิ่มพลังงานเทียมราว 0.5–0.8 J ซึ่งคือ +10% ทั้งหมด ถ้าไม่ลบอะไรเลยได้ 3.83/7.95 J
3. K-term leak (มุม rotor ปลาย run ต่างกัน ±0.1°): +0.05/−0.14 J เล็กมาก
4. P_meas กับ P ที่ PCC: ต่างกันแบบ gain 0.6–0.7% ตัดกันได้ในผลต่าง (3.84 กับ 3.83 J)
บทเรียน: ใช้ superposition (มี control run) แทนการลบ baseline
- รูปร่างคล้ายเครื่องจริง: H สูงขึ้น P overshoot มากขึ้น และ f undershoot ลึกขึ้น (H = 10 ลงไปถึง 49.785 Hz ก่อนกลับมา 49.80 Hz)
- f ของ VSG ปลาย run ห่างจากกริด < 1 mHz (lock แล้ว)

## ผล 3: ข้อจำกัดสำคัญ — inertia มาช้า
พลังงาน inertia ส่วนใหญ่ออกมา **หลัง** ramp จบ (peak ราว 4.7–4.8 s ขณะที่ ramp จบที่ 4.0 s) เพราะ rotor ของ VSG ตามความถี่กริดด้วย τ ≈ K/(Ks·ωs) ≈ 177/314 ≈ 0.56 s (damping/droop K = 177 กินทุกอย่าง และกริดที่ X = 1 pu ให้ Ks ≈ 1 pu)
synchronous machine จริงบน bus แข็งจะปล่อยพลังงานนี้ **ระหว่าง** RoCoF VSG ตัวนี้ปล่อยพลังงาน **ได้ถูกจำนวน** แต่ **ช้าไป ~0.5 s** ต้นเหตุคือ D·ωs = 157 กับ coupling ที่อ่อน (ข้อเดียวกับที่พบใน black-box)

## สรุปสำหรับ thesis
1. ✅ พิสูจน์ได้ (ใน sim): ค่า H ของตัวควบคุมทำให้เกิด inertial energy ที่ระบบภายนอกรับได้จริง เชิงเส้นตาม H และตรงกับ 2ΔH·S·Δw ภายใน ±2% (superposition)
2. ⚠️ เงื่อนไข: ต่อได้แค่กับกริดที่อ่อน (X = 1 pu) และต้องปิด FF
3. ⚠️ inertia ถูกส่งช้า ~0.5 s หลัง RoCoF เพราะ damping สูงมากและ coupling อ่อน
4. ❌ ต่อกริดแข็ง (X ≤ 0.4 pu) ไม่ได้ทั้งมีและไม่มี FF

## ขั้นต่อไปที่เป็นไปได้
- ~~หาสาเหตุ +10%~~ ทำแล้ว: เป็น artifact ของ baseline (ดูหัวข้อด้านบน)
- ทดสอบที่ X = 0.5–0.7 pu เพื่อหาขอบ stability
- (ออกแบบ) ลด D หรือเปลี่ยน voltage loop/virtual impedance เพื่อให้ต่อกริดแข็งได้และส่ง inertia ทันเวลา ต้องคุยกับอาจารย์ก่อนเพราะเกิน scope islanded
