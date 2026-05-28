# VSG Control Architecture — Detailed Explanation

**Project**: 66AOS02 — Virtual Synchronous Generator for BESS Inverter Control
**Owner**: Napoleon (Chinnawat Dumklang)
**Purpose**: Deep-dive defense reference for the 4-layer cascaded VSG control
**Last update**: 2026-05-28 (defense day)

---

## 🎯 Big Picture — ทำไมต้องมี VSG Control?

**ปัญหา**: Inverter เป็นแค่ "สวิตช์ไฟฟ้า" — ไม่มี rotor, ไม่มี physics ที่ทำให้ความถี่เสถียร

**Synchronous Generator (SG) จริง**:
- มี **rotor หมุน** (มวล) → เก็บพลังงานจลน์ → ต้านการเปลี่ยนความถี่ ⇒ **inertia**
- มี **damper winding** → ลด oscillation ⇒ **damping**
- มี **AVR / governor** → ปรับ V, f ⇒ **droop control**

**VSG**: เลียนแบบทั้ง 3 อย่างใน **software** ที่ทำงานใน ESP32

| SG (จริง)        | VSG (ใน firmware)                |
|------------------|----------------------------------|
| Rotor mass `J`   | `2H · dω/dt` term (สมการ Swing) |
| Damper winding   | `D · Δω` term                    |
| AVR + Governor   | Q-V loop + P-f droop             |
| Stator winding   | LC filter + inverter bridge      |
| Mechanical `Pm`  | `P_set` (operator command)       |

---

## 🧅 ทำไมต้องเป็น 4 ชั้น Cascaded?

**คำตอบสั้น**: เพราะธรรมชาติของระบบมี **3 timescale ที่ต่างกัน 1000 เท่า**

| ปรากฏการณ์                             | Timescale           | ใครจัดการ             |
|----------------------------------------|---------------------|-----------------------|
| Switching ripple                       | 100 µs (10 kHz)     | Layer 4 PWM           |
| Voltage / current ติดตาม ref           | 1 – 10 ms           | Layer 3 Inner PI      |
| Frequency response (Swing Eq)          | 500 ms – 2 s        | Layer 2 VSG Core      |
| Power measurement                      | 100 µs              | Layer 1 Power Calc    |

**กฎ Cascaded**: แต่ละชั้นต้องเร็วกว่าชั้นที่อยู่บน **อย่างน้อย 10 เท่า** (decade rule) → ไม่ interact กัน → stable

```
                    ┌─────────────────────────────┐
                    │  ภายใน ISR @ 10 kHz บน ESP32 │
                    └─────────────────────────────┘

  จาก ADC          ↓ V_abc, i_abc (วัดจริง)
  ┌──────────────────────────────────────────────┐
  │ Layer 1 │ Power Calculation                  │
  │         │ คำนวณ P = 1.5·V_d·i_d  ,  Q = ...  │
  └──────────────────────────────────────────────┘
                    ↓ P, Q (instantaneous)
  ┌──────────────────────────────────────────────┐
  │ Layer 2 │ VSG Core (Swing Equation) ─ OUTER  │
  │         │ P-ω loop : 2H·dω/dt = P_set − P    │
  │         │            − D·Δω − (1/m_p)·Δω      │
  │         │ Q-V loop : K_v·dV/dt = Q_set − Q   │
  └──────────────────────────────────────────────┘
                    ↓ V_d_ref, ω_ref, θ_ref
  ┌──────────────────────────────────────────────┐
  │ Layer 3 │ Inner V/I Loop ─ Cascaded PI in dq │
  │         │ Voltage PI (BW 100 Hz) → i_ref     │
  │         │ Current PI (BW 1 kHz)  → V_inv_ref │
  └──────────────────────────────────────────────┘
                    ↓ V_inv_d_ref, V_inv_q_ref
  ┌──────────────────────────────────────────────┐
  │ Layer 4 │ Modulator (Inverse Park + SPWM)    │
  │         │ V_inv_dq → V_inv_abc               │
  │         │ เทียบกับ 10 kHz triangle carrier   │
  └──────────────────────────────────────────────┘
                    ↓ 6 × PWM gate signals
                    └──→ DRV8302 (hardware)
```

---

## 📥 Layer 1 — Power Calculation

**Input**: `V_abc` (3 phases), `i_abc` (3 phases) — instantaneous values
**Output**: `P` (active), `Q` (reactive) — instantaneous values

### ขั้นตอน

```
V_abc, i_abc  ─→ Clarke Transform (abc → αβ)
              ─→ Park Transform (αβ → dq)  [ใช้ θ จาก Layer 2]
              ─→ คำนวณ P, Q ในกรอบ dq
```

### สมการสำคัญ

**Park (amplitude-invariant)**:

```
[V_d]     [cos(θ)    cos(θ-120°)   cos(θ+120°)] [V_a]
[V_q]= ⅔ [-sin(θ)   -sin(θ-120°)  -sin(θ+120°)] [V_b]
[V_0]     [ ½         ½              ½         ] [V_c]
```

**Power ใน dq frame**:

```
P = (3/2) · (V_d · i_d + V_q · i_q)
Q = (3/2) · (V_d · i_q - V_q · i_d)
```

### ทำไมต้องเป็น dq ไม่ใช่ abc?

- AC sinusoid ใน abc → กลายเป็น **DC constant** ใน dq frame (เมื่อ θ sync กับ grid)
- DC → ทำ PI control ง่ายมาก (error → 0 ตรงๆ)
- ถ้าใช้ abc → ต้อง track sinusoid → PI ไม่ converge เป๊ะ

**ใน Stage 5a ที่ steady state**:
- `V_d = 14 V` (DC, ติดตาม ref)
- `V_q ≈ 0` (Park rotor alignment ถูก)
- `P = 1.5 × 14 × i_d ≈ 100 W`

---

## 🧠 Layer 2 — VSG Core (Swing Equation)

**หัวใจของระบบทั้งหมด**

**Input**: `P_meas` (จาก L1), `Q_meas`, `P_set`, `V_set`, `Q_set`, `ω_grid_ref`
**Output**: `θ` (มุม), `V_d_ref` (แรงดันคำสั่ง) → ส่งไป Layer 3

### สมการ P-ω loop (สำคัญสุด)

```
            ┌── inertia term ──┐  ┌─ damping ─┐  ┌─── droop ───┐
2H · dω/dt = (P_set - P_meas)/S - D · (ω - ω₀) - (1/m_p) · (ω - ω₀)
```

**Integrate ω → θ**:

```
θ = ∫ ω dt    (มุมไฟฟ้าใช้ใน Park transform)
```

### ความหมายเชิงฟิสิกส์

- **`2H` term**: virtual inertia — ต่อต้านการเปลี่ยน ω (จากค่า `J · dω/dt` ของ rotor จริง)
- **`D` term**: virtual damping — ลด oscillation
- **`1/m_p` term**: droop — steady-state load sharing (5% → m_p = 0.05)
- **`P_set − P_meas`**: power imbalance — driving force

### ทำไมต้องมี 3 terms?

```
ถ้ามีแค่ inertia       → oscillate ไม่หยุด (เหมือนลูกตุ้มไม่มีแรงต้าน)
ถ้ามีแค่ damping       → ช้า, ไม่ขยับเลย
ถ้ามีแค่ droop         → steady-state error
ทั้ง 3 รวมกัน          → ตอบสนองเหมือน SG จริง (second-order + droop)
```

### Q-V loop (เสริม)

```
K_v · dV/dt = (Q_set - Q_meas) - D_q · ΔV - (1/m_q) · (V - V₀)
```

โครงสร้างเดียวกับ P-ω แต่:
- คุม **แรงดัน** (ไม่ใช่ความถี่)
- เลียนแบบ **field winding + AVR** ของ SG
- ทำงาน slower กว่า P-ω เพราะ AVR ปกติช้ากว่า governor

### Output ของ Layer 2

```
θ        → ส่งไป Park / iPark ของ Layer 1 และ Layer 4
V_d_ref  → ส่งไป Layer 3 (Outer V PI)
V_q_ref  = 0 → ส่งไป Layer 3 (เราต้องการ aligned d-axis)
```

---

## ⚡ Layer 3 — Cascaded V/I Inner PI

### โครงสร้าง 2 ชั้นย่อย

```
        V_d_ref (from L2)
                ↓
      ┌────────────────┐
      │ Outer Voltage  │  ← BW 100 Hz
      │  PI controller │
      └────────────────┘
                ↓ i_d_ref
      ┌────────────────┐
      │ Inner Current  │  ← BW 1 kHz
      │  PI controller │
      └────────────────┘
                ↓ V_inv_d_ref
         ส่งไป Layer 4
```

### Outer Voltage PI (ช้ากว่า)

```
e_V       = V_d_ref - V_d_meas              (error)
i_d_ref   = Kp_V · e_V + Ki_V · ∫e_V dt     (PI output = current command)
```

**Tuning** (จาก Stage 5a):
- ω_n_outer = 628 rad/s ≈ 100 Hz
- `Kp_V = 2 · ζ · ω_n · C_f = 8.88e-3`
- `Ki_V = ω_n² · C_f = 3.94`
- ζ = 0.707 = critically damped

**หน้าที่**: ทำให้ `V_d` ติด ref → ใช้ `i_d` เป็น actuator

### Inner Current PI (เร็วกว่า 10x)

```
e_i           = i_d_ref - i_d_meas
V_inv_d_ref   = Kp_I · e_i + Ki_I · ∫e_i dt
```

**Tuning**:
- ω_n_inner = 6283 rad/s ≈ 1 kHz
- `Kp_I = ω_n · L_f = 7.54`
- `Ki_I = Kp_I · R_f / L_f = 314`

**หน้าที่**: ทำให้ `i_d` ติด ref ที่ outer สั่ง → ใช้ `V_inv` (PWM duty) เป็น actuator

### ทำไม Cascaded ไม่ใช่ single loop?

1. **Current limiting ง่าย** — ใส่ saturation ที่ `i_d_ref` (output ของ outer) → จำกัด current ป้องกัน MOSFET ระเบิด
2. **Tuning อิสระ** — tune inner ก่อน → assume inner perfect → tune outer
3. **Disturbance rejection** — ถ้า load step disturbance → inner loop "งับ" ทันใน 1 ms → outer แทบไม่รู้สึก

### Decoupling Feedforward (ยังไม่ใส่ใน Stage 5a — flag ใน defense)

```
V_inv_d = PI_d - ω·L·i_q + V_C_d    (← cross-coupling ออก)
V_inv_q = PI_q + ω·L·i_d + V_C_q
```

**ทำไมต้องมี**:
- ในกรอบ dq, current เฟส d กับ q **coupled กัน** ด้วย `ω · L`
- ถ้าไม่ decouple → inner loop ต้อง "ปราบ" cross-coupling เอง → ช้า + steady-state error
- Stage 5a มี **5% offset** เพราะยังไม่ใส่ตัวนี้

---

## 🎛️ Layer 4 — Modulator (Inverse Park + SPWM)

**Input**: `V_inv_d_ref`, `V_inv_q_ref` (จาก L3), `θ` (จาก L2)
**Output**: 6 × PWM gate signals

### ขั้นตอน

**1. Inverse Park**: `V_inv_dq + θ → V_inv_abc` (3-phase sinusoid)

```
V_inv_a = V_inv_d · cos(θ)       - V_inv_q · sin(θ)
V_inv_b = V_inv_d · cos(θ-120°)  - V_inv_q · sin(θ-120°)
V_inv_c = V_inv_d · cos(θ+120°)  - V_inv_q · sin(θ+120°)
```

**2. SPWM**: เทียบ `V_inv_abc` กับ triangle carrier 10 kHz

```
ถ้า V_inv_x > V_carrier  →  upper switch ON, lower OFF
ถ้า V_inv_x < V_carrier  →  upper switch OFF, lower ON
```

**3. Dead time insertion** (ฮาร์ดแวร์): กัน shoot-through 100 – 500 ns

**4. Output** → 6 PWM signals (3 phase × upper + lower)

### Modulation Index

```
m_idx = V_peak_phase / (V_dc / 2)
      = 14 / (48 / 2)
      = 0.58       ← อยู่ใน linear range (< 1)
```

**ถ้า `m_idx > 1`** → overmodulation → clipping → harmonics

**Stage 5a finding**: ที่ V_dc = 24 V → `m_idx = 14 / 12 = 1.17 > 1` → เกิน → revise เป็น 48 V

---

## 🔄 Concrete Example — Load Step ที่ t = 0.2 s

Trace event step-by-step ผ่าน 4 layers เพื่อเห็น cascaded behavior ชัด

```
t = 0.20s   ⚡ R_load: 2.94 → 2.06 Ω  (-30%)

t = 0.2 + 0.001 ms (1 µs)  → ฮาร์ดแวร์ตอบสนอง
  • V at C_f node เริ่ม drop เพราะ cap discharge เข้า load
  • Current i_L เริ่มเพิ่มเพราะ R น้อยลง

t = 0.2 + 100 µs (next ISR)  → L1 sees it
  • ADC sample: V_d ดิ๊ปลง, i_d เพิ่ม
  • L1: P = 1.5 · V_d · i_d ≈ 138 W (เพิ่มจาก 100)

t = 0.2 + 1 ms  → L3 Inner Current PI activates
  • i_d เพิ่ม → i_d_ref ยังเดิม → error → PI ปรับ V_inv_d_ref ขึ้น
  • PWM duty cycle เพิ่ม → MOSFET เปิดนานขึ้น
  • Current loop "งับ" disturbance ใน 1 ms

t = 0.2 + 10 ms  → L3 Outer Voltage PI activates
  • V_d ยังต่ำกว่า ref → PI สั่ง i_d_ref เพิ่ม
  • Voltage loop ดึง V_d กลับขึ้นมาที่ 14 V
  • Voltage loop "ฟื้น" disturbance ใน 10 ms

t = 0.2 + 100 ms  → L2 VSG Core sees P imbalance
  • P_meas = 138 > P_set = 100
  • Swing Eq: ω เริ่มลดลง (เพราะ inverter ส่งกำลังมากกว่าที่ "engine" จ่ายให้)
  • ω drops slowly with τ ≈ 500 ms

t = 1.5 s  → ระบบ settle เกือบเต็ม
  • V_d = 14 V (locked โดย L3)
  • P = 138 W (กำหนดโดย load impedance + V)
  • f = 49.23 Hz (lowered โดย droop)
  • ทุก ISR ของ 4 layers cycle ต่อเนื่อง ที่ 10 kHz
```

**Key insight**: **L3 (inner loop) ปกป้อง L2 (outer loop) จาก fast transient** — L2 เห็นแต่ "slow average" → response เหมือน SG จริง

---

## 🎯 Key Takeaways

### 5 ประโยคที่ต้องท่องได้

1. **"VSG เลียนแบบ Swing Equation ของ SG ใน software ESP32"**
2. **"4 layer cascaded ทำงานที่ timescale ต่างกัน 10 เท่า → stable + ออกแบบ tune แยกได้"**
3. **"L1 measure → L2 outer (slow inertia) → L3 inner (fast V/I) → L4 PWM"**
4. **"Inner loop ปกป้อง outer loop จาก fast transient → outer 'เห็น' system เหมือน SG จริง"**
5. **"dq frame ทำให้ AC sinusoid → DC → PI control converge ตรงๆ"**

### ตัวเลขที่ต้องจำ

| Quantity                       | Value                        |
|--------------------------------|------------------------------|
| `H` (virtual inertia)          | **5 s**                      |
| Droop `m_p`                    | **5% (R_p = 0.05)**           |
| Inner I loop BW                | **1 kHz**                    |
| Outer V loop BW                | **100 Hz**                   |
| VSG outer time constant        | **~500 ms**                   |
| Modulation index @ 48V         | **0.58** (linear range)      |
| Cascaded decade rule           | **10x separation** ระหว่างชั้น |

---

## 🛡️ Q&A พร้อมตอบ (Control-specific)

| Q                                                            | A |
|--------------------------------------------------------------|---|
| **"ทำไมเลือก H = 5?"**                                       | 5 s อยู่ในช่วง H ของ SG จริงที่ 2–6 s; H สูงให้ frequency stability ดีแต่ response ช้า; ใน Ch.4 จะ sweep H = 2–10 หา optimal |
| **"ทำไม BW outer 100 Hz, inner 1 kHz?"**                     | Decade rule — inner ต้องเร็วกว่า outer 10x; switching 10 kHz → inner 1 kHz → outer 100 Hz → VSG ~0.3 Hz; แต่ละชั้นห่าง 1 decade → stable + decoupled |
| **"ทำไม Park transform ใช้ amplitude-invariant ไม่ใช่ power-invariant?"** | Amplitude-invariant (factor 2/3) ทำให้ `V_d, i_d` มีค่าเท่า peak ของ `V_abc, i_abc` — debug ง่าย; power-invariant (factor √(2/3)) ต้องคูณ √(3/2) ทุกครั้งที่อ่าน scope |
| **"ถ้า PLL ไม่มี ใช้ θ จากไหน?"**                            | θ มาจาก integrate ω ของ Swing Eq → ใน islanded mode, VSG เป็น master ของ angle; ใน grid-connected ตอน sync ใช้ PLL แค่ initial alignment แล้วปิด |
| **"PI gain คำนวณจากอะไร?"**                                  | Pole placement — assume plant เป็น 1st-order (RL load หรือ C_f), เลือก ω_n_desired แล้ว `Kp = ω_n · L`, `Ki = Kp · R / L`; แสดง derivation ใน Ch.3 |
| **"ทำไม V_q = 0 ไม่ใช่ V_d = 0?"**                           | Convention — เลือก d-axis aligned กับ peak ของ `V_a` (ที่ θ = 0) → q-axis lagging 90°; ที่ steady-state, voltage vector อยู่บน d-axis → `V_d = magnitude`, `V_q = 0` |
| **"Swing Eq เป็น 2nd order ทำไมไม่ใช้ PI?"**                 | Swing Eq เป็น integrator (`dω/dt = ...`) + damping → equivalent กับ PI alone ในรูป frequency response แต่ semantic ดีกว่า: parameter (H, D) มีความหมายเชิงฟิสิกส์ — ปรับ tuning intuitive กว่า |
| **"Stage 5a มี 5% offset มาจากไหน?"**                        | จากการไม่ใส่ decoupling feedforward `−ω·L·i_q` + `V_C_d`; cross-coupling ระหว่าง d-q axis ทำให้ inner PI ต้อง "ปราบ" เอง → steady-state error; จะ add ก่อน port ลง ESP32 |
| **"ทำไม Stage 5a ใช้ D = 0?"**                               | Baseline ใช้ pure droop term `1/m_p` เพื่อ isolate effect ของ droop; ใน Ch.4 sensitivity sweep จะ vary D = 0 – 50 หา optimal region — ข้อนี้ตรงกับ advisor feedback #3 (เตรียมชุดค่า H, D หลายชุด) |
| **"Cascaded PI saturate แล้วทำไง — มี anti-windup ไหม?"**   | มีครับ — output ของ outer V PI (= i_d_ref) saturate ที่ ±4 A → กัน MOSFET ; integrator ของ outer ใส่ clamping anti-windup เมื่อ saturated; inner I PI saturate ที่ V_inv ± V_dc/2 (modulation limit) |

---

## 📂 ที่มา / Reference

- **MATLAB simulation**: `matlab/phase5a_switching_abc.m`
- **Outputs verified**: `matlab/vsg_stage5a_out.mat`
- **Plot**: `python/plots/phase5a_switching.png`
- **Slide ที่ใช้**: 5.2 ISR Budget, 5.3 Sim Results, 5.1.1 Wiring Diagram, slide 10 (3.1 VSG Architecture)
- **Defense Q&A bank**: `docs/notes/defense_qa_bank.md`

---

**Last word**: ถ้าจำไม่ได้ทั้งหมด — จำ **5 ประโยค** + **ตัวเลข 7 ตัว** ก็พอ defend ได้ครับ
