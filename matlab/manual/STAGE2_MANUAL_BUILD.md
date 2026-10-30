# Stage 2 — Power-Angle Feedback ด้วยมือใน Simulink (R2018b)

> เป้าหมาย: สร้าง `vsg_stage2_manual.slx` โดย**ต่อยอดจาก Stage 1 ที่เพิ่งผ่าน**
> แล้วตรวจด้วย `validate_stage2_manual.m` (เทียบกับ `vsg_stage2_out.mat`)
>
> **ห้ามตั้งชื่อ `vsg_stage2.slx`** — script auto-build เขียนทับเหมือนเดิม

---

## 0. อะไรเปลี่ยนจาก Stage 1 (the why)

Stage 1 มีปัญหา: Pe เป็นค่าคงที่ → step Pm แล้ว ω ลอยหนี ω_s ไปเลย δ ไต่เป็น ramp
ไม่มีแรงดึงกลับ (restoring torque)

Stage 2 **ปิด loop** โดยแทน Pe คงที่ด้วยสมการ power-angle ของเครื่อง synchronous
ที่ต่อผ่าน reactance X เข้า infinite bus:

```
Pe(δ) = (E·V / X) · sin(δ) = Pmax · sin(δ)
```

พอ δ โต → Pe โต → ไปหัก Pm ใน swing equation → ดึง ω กลับหา ω_s
ผลคือระบบกลายเป็น **second-order ใน δ** — มี oscillation แบบ classic swing:

```
(2H/ω_s)·δ̈ + D·δ̇ + Pmax·cos(δ_eq)·Δδ = ΔPm
ω_n = √( Pmax·cos(δ_eq) / (2H/ω_s) )
ζ   = D / ( 2·√( (2H/ω_s)·Pmax·cos(δ_eq) ) )
```

| พารามิเตอร์ | ค่า | หมายเหตุ |
|---|---|---|
| H | 5 s | เท่าเดิม |
| **D** | **0.3** | ⚠️ เปลี่ยนจาก 10! (D=10 ให้ ζ≈4.1 overdamped จนไม่เห็น swing — 0.3 ให้ ζ≈0.62 เห็น ~3 ลูกคลื่นชัด และใกล้ค่าจริงของ prototype 100 VA) |
| E | 1.05 pu | internal EMF |
| V | 1.00 pu | infinite bus |
| X | 0.50 pu | coupling reactance |
| Pmax | E·V/X = **2.1 pu** | ขีดจำกัดส่งกำลัง |
| Pm | 1.0 → 1.1 pu ที่ t = 1 s | เท่าเดิม |
| **T_sim** | **5 s** | สั้นลงจาก 10 s |
| **δ(0)** | asin(1.0/2.1) ≈ **0.49607 rad (28.437°)** | ⚠️ IC ของ Int_delta ต้องเริ่มที่จุดสมดุล ไม่งั้น Pe(0)=0 ระบบวิ่งหนีก่อน step จะมาถึง |

ค่าคาดหวัง (small-signal): δ_eq 28.44° → 31.59°, ω_n ≈ 7.62 rad/s (f_d ≈ 1.21 Hz), ζ ≈ 0.62

## 1. เริ่มจากของเดิม

1. เปิด `vsg_stage1_manual.slx` → **File → Save As** → `vsg_stage2_manual.slx`
   (โฟลเดอร์เดิม `D:\workspace\engineering\vsg-project\matlab\`)

## 2. แก้ 5 จุด

### 2.1 ลบ Pe constant
ลบบล็อก `Pe` (Constant) ทิ้ง — สายที่เข้า `Sum_PmPe` ขา `−` จะหายไปด้วย

### 2.2 เพิ่ม feedback path ใหม่ (หัวใจของ Stage 2)
วาง 2 บล็อกใต้ `Int_delta`:

| บล็อก | Library | ชื่อ | พารามิเตอร์ |
|---|---|---|---|
| Trigonometric Function | Math Operations | `Sin_delta` | Function = `sin` |
| Gain | Math Operations | `Gain_Pmax` | Gain = `1.05*1.00/0.50` (= 2.1) |

ต่อสาย:
- `Int_delta` → `Sin_delta` (แตกกิ่งจากสายที่ไป Scope/ToWS ได้ — Ctrl+ลากจากกลางสาย)
- `Sin_delta` → `Gain_Pmax`
- `Gain_Pmax` → `Sum_PmPe` ขา `−`  ← **เส้นนี้คือการปิด loop** (Pe ย้อนกลับมาหัก Pm)

### 2.3 แก้ Gain_D
ดับเบิลคลิก `Gain_D` → Gain = `0.3` (จากเดิม 10)

### 2.4 แก้ IC ของ Int_delta
ดับเบิลคลิก `Int_delta` → Initial condition = `asin(1.0/2.1)` (พิมพ์นิพจน์ได้เลย)

### 2.5 แก้ Stop time
Model Settings (Ctrl+E) → Stop time = `5` (solver อื่นเหมือนเดิม: ode45, MaxStep 1e-3, RelTol 1e-6, AbsTol 1e-8)

## 3. โครงสร้างสุดท้ายที่ควรได้

```
Pm ──(+)┐
        ├─ Sum_PmPe ──(+)┐
   (−)──┘                ├─ Sum_swing ── Gain_inv_2Hws ── Int_omega ─┬─► Sum_dev ─┬─► Gain_D ──(−)► Sum_swing
    ▲              (−)───┘                                           │  (ω)  (−)◄─ omega_s     │
    │                                                                ▼           └─► Int_delta ─┬─► Scope ch2 / ToWS_delta
    │                                                            Scope ch1 / ToWS_omega        │
    └──── Gain_Pmax ◄── Sin_delta ◄────────────────────────────────────────────────────────────┘
          (Pe = 2.1·sin δ)                 ★ loop ใหม่ของ Stage 2
```

เช็คลิสต์ก่อนรัน: บล็อกทั้งหมด 14 ตัว (Stage 1 มี 13, ลบ Pe ออก 1, เพิ่ม Sin+Gain 2)
To Workspace ยังชื่อ `omega_ts` / `delta_ts` format Timeseries เหมือนเดิม

## 4. รัน + ตรวจ

1. Run แล้วดู Scope:
   - ω: กระเพื่อมเป็นคลื่นหน่วง ~3 ลูก (T_d ≈ 0.83 s) แล้วกลับมานิ่งที่ **ω_s พอดี**
     (ต่างจาก Stage 1 ที่ค้าง offset ไว้ — เพราะตอนนี้ δ เป็นคนรับ ΔP แทน)
   - δ: สวิงจาก 28.44° เด้งเกิน (overshoot) แล้วลู่เข้า **31.59°**
2. รันตัวตรวจ:
   ```matlab
   cd D:\workspace\engineering\vsg-project\matlab
   validate_stage2_manual
   ```
   ต้องได้ PASS ทั้ง 2 trace

จุดพลาดบ่อยของ Stage 2:
- ลืมแก้ IC ของ `Int_delta` → กราฟ δ ดิ่งลงลึกตั้งแต่ t=0 ก่อน step มาถึง (ระบบไม่ได้เริ่มที่สมดุล)
- `Gain_Pmax` ต่อเข้า `Sum_PmPe` ขา `+` แทน `−` → positive feedback ระบาย δ วิ่งหนีไม่กลับ
- ลืมแก้ `Gain_D` เหลือ 10 → กราฟไม่มี oscillation เลย (overdamped) — validator จะ FAIL ชัดเจน
