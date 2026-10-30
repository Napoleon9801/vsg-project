# Stage 1 — สร้าง Swing Equation ด้วยมือใน Simulink (R2018b)

> เป้าหมาย: สร้าง `vsg_stage1_manual.slx` ด้วยมือใน Simulink GUI ให้ได้ผลตรงกับ
> โมเดลอ้างอิง `vsg_stage1.slx` (ที่ script `phase1_swing_equation.m` สร้างอัตโนมัติ)
> แล้วตรวจด้วย `validate_stage1_manual.m`
>
> **ห้ามตั้งชื่อไฟล์ว่า `vsg_stage1.slx`** — script auto-build จะปิด/เขียนทับมันทุกครั้งที่รัน
> ใช้ชื่อ `vsg_stage1_manual.slx` เท่านั้น

---

## 0. สมการที่กำลังจะต่อ

```
(2H / ω_s) · dω/dt = Pm − Pe − D·(ω − ω_s)     ... swing equation
dδ/dt              = ω − ω_s                    ... angle equation
```

| ตัวแปร | ค่า | ความหมาย |
|---|---|---|
| H | 5 s | virtual inertia constant |
| D | 10 | damping coefficient (คูณกับ ω−ω_s หน่วย rad/s) |
| f_base | 50 Hz | ความถี่กริดไทย |
| ω_s | 2π·50 ≈ 314.159 rad/s | synchronous speed |
| Pm | 1.0 pu → step เป็น 1.1 pu ที่ t = 1 s | กำลังกล (reference) |
| Pe | 1.0 pu คงที่ | โหลดไฟฟ้า (Stage 1 ยังไม่มี feedback จาก δ) |
| T_sim | 10 s | ระยะจำลอง |

จัดรูปสำหรับต่อบล็อก (integrator รับ dω/dt เข้าไป):

```
dω/dt = (ω_s / 2H) · [ (Pm − Pe) − D·(ω − ω_s) ]
δ     = ∫ (ω − ω_s) dt
```

## 1. เปิด MATLAB + โมเดลเปล่า

1. เปิด MATLAB R2018b (`D:\MATLAB1\bin\matlab.exe`)
2. `cd D:\workspace\engineering\vsg-project\matlab`
3. Home → New → Simulink Model → Blank Model
4. Save ทันทีเป็น `D:\workspace\engineering\vsg-project\matlab\vsg_stage1_manual.slx`

## 2. วางบล็อก (ลากจาก Library Browser หรือพิมพ์ชื่อบล็อกกลางแคนวาสแล้ว Enter)

| # | บล็อก | Library | ตั้งชื่อบล็อก | พารามิเตอร์ |
|---|---|---|---|---|
| 1 | Step | Sources | `Pm` | Step time = `1.0`, Initial value = `1.0`, Final value = `1.1` |
| 2 | Constant | Sources | `Pe` | Value = `1.0` |
| 3 | Constant | Sources | `omega_s` | Value = `2*pi*50` |
| 4 | Sum | Math Operations | `Sum_PmPe` | List of signs = `+-` |
| 5 | Sum | Math Operations | `Sum_swing` | List of signs = `+-` |
| 6 | Gain | Math Operations | `Gain_inv_2Hws` | Gain = `2*pi*50/(2*5)` (= ω_s/2H ≈ 31.4159) |
| 7 | Integrator | Continuous | `Int_omega` | **Initial condition = `2*pi*50`** (สำคัญ! ω เริ่มที่ synchronous) |
| 8 | Sum | Math Operations | `Sum_dev` | List of signs = `+-` |
| 9 | Gain | Math Operations | `Gain_D` | Gain = `10` |
| 10 | Integrator | Continuous | `Int_delta` | Initial condition = `0` |
| 11 | Scope | Sinks | `Scope_omega_delta` | Number of input ports = `2` (ไอคอนเฟือง → Number of Input Ports) |
| 12 | To Workspace | Sinks | `ToWS_omega` | Variable name = `omega_ts`, Save format = **Timeseries** |
| 13 | To Workspace | Sinks | `ToWS_delta` | Variable name = `delta_ts`, Save format = **Timeseries** |

> Save format ของ To Workspace **ต้องเป็น Timeseries** — ตัวตรวจคำตอบและ Python
> pipeline อ่าน format นี้ (ค่า default ของ R2018b เป็น Array ต้องเปลี่ยนเอง)

## 3. ต่อสาย

```
Pm ──(+)┐
        ├─ Sum_PmPe ──(+)┐
Pe ──(−)┘                ├─ Sum_swing ── Gain_inv_2Hws ── Int_omega ──┬──(+)┐
                         │                                            │     ├─ Sum_dev ──┬── Gain_D ──┐
              (−)────────┴──────────────── Gain_D ◄──────────────────────────────────────┘           │
                          (สาย feedback เส้นนี้คือเส้นเดียวกับด้านขวา)                                  │
omega_s ──(−)─ Sum_dev                                                                               ...
```

ต่อทีละเส้นตามตารางนี้ (ลากจาก output → input):

| จาก | ไป |
|---|---|
| `Pm` | `Sum_PmPe` ขา `+` |
| `Pe` | `Sum_PmPe` ขา `−` |
| `Sum_PmPe` | `Sum_swing` ขา `+` |
| `Sum_swing` | `Gain_inv_2Hws` |
| `Gain_inv_2Hws` | `Int_omega` |
| `Int_omega` | `Sum_dev` ขา `+` |
| `omega_s` | `Sum_dev` ขา `−` |
| `Sum_dev` | `Gain_D` |
| `Gain_D` | `Sum_swing` ขา `−`  ← **นี่คือ damping feedback loop** |
| `Sum_dev` | `Int_delta`  (แตกกิ่งจากสายเดิม: ลากจากกลางสายด้วย Ctrl+ลาก) |
| `Int_omega` | `Scope_omega_delta` ch 1 |
| `Int_delta` | `Scope_omega_delta` ch 2 |
| `Int_omega` | `ToWS_omega` |
| `Int_delta` | `ToWS_delta` |

จุดที่คนพลาดบ่อย:
- ทิศของ Sum: ดับเบิลคลิกดูว่าขาไหนเป็น `+` ขาไหนเป็น `−` ถ้าสลับ ω จะวิ่งผิดทาง
- `Int_omega` ลืมตั้ง IC = `2*pi*50` → ω เริ่มจาก 0 ระบบพุ่งทันที
- Loop `Gain_D → Sum_swing` เป็น algebraic-loop-free เพราะผ่าน integrator แล้ว — ถ้า Simulink ฟ้อง algebraic loop แปลว่าต่อผิดจุด

## 4. ตั้ง Solver

Model Settings (Ctrl+E) → Solver:

| ช่อง | ค่า |
|---|---|
| Stop time | `10` |
| Type | Variable-step |
| Solver | `ode45` |
| Max step size | `1e-3` |
| Relative tolerance | `1e-6` |
| Absolute tolerance | `1e-8` |

## 5. รัน + ตรวจ

1. กด **Run** (Ctrl+T) แล้วเปิด Scope ดู:
   - ch1 (ω): เริ่ม 314.159 rad/s → ที่ t=1s กระโดดขึ้นแบบ first-order (ไม่มี overshoot เพราะ Stage 1 ไม่มี power-angle feedback จึงเป็นระบบอันดับ 1 ใน ω) → นิ่งที่ ~314.169 rad/s
   - ch2 (δ): ก่อน t=1s แบนที่ 0 → หลัง step ไต่เป็นเส้นตรง (ramp) ไม่ลู่เข้า — **นี่คือพฤติกรรมที่ถูกต้องของ Stage 1** เพราะยังไม่มี Pe(δ) feedback (Stage 2 จะแก้ตรงนี้)
2. ตัวเลขคาดหวัง: Δω_ss = ΔP/D = 0.1/10 = **0.01 rad/s** → f_ss ≈ **50.00159 Hz**
3. รันตัวตรวจใน Command Window:
   ```matlab
   cd D:\workspace\engineering\vsg-project\matlab
   validate_stage1_manual
   ```
   ต้องขึ้น `PASS` ทั้ง ω และ δ (เทียบกับ `vsg_stage1_out.mat` ของโมเดลอ้างอิง)

## 6. เก็บงาน

โมเดล manual เป็นไฟล์ฝึกมือ — ไม่ต้อง commit (.slx ถูก gitignore อยู่แล้ว)
สิ่งที่ commit คือคู่มือนี้ + ตัวตรวจ ซึ่งอยู่ใน `matlab/manual/` และ `matlab/`
