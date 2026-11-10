# VSG black-box identification จากขั้วโหลด (2026-11-10)

คำถาม: ถ้าคนนอกวัดได้แค่แรงดันและกระแสที่ขั้วโหลด เขาจะสรุปได้ไหมว่านี่คือเครื่องที่ทำตัวเหมือน synchronous machine ด้วยค่าที่เราตั้ง (H = 5 s, K = 1/Rp + D·ωs = 177.08 pu, P-LPF 5 Hz, secondary Ki = 4 pu/(Hz·s))

**คำตอบสั้น: ได้บางส่วน** K (damping+droop) และ Ki (secondary) ระบุได้ แต่ **H ระบุไม่ได้** จากการทดสอบ islanded load step

ข้อมูล: E1.2 FF run (`results_nominal_ff1.mat` บันทึก V/I 200 kHz ไว้ secondary เปิด) ไม่ได้รัน sim ใหม่
สคริปต์: `D:\workspace\engineering\vsg-project\python\analysis\e12_blackbox_vsg_id.py`
ผล: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\e12_ff_load_cycle\e12_blackbox_id.json`
รูป: `D:\workspace\engineering\vsg-project\docs\figures\e12_blackbox_vsg_id_2026-11-10.png`

## วิธี

- **f ที่ขั้ว**: มุมของ Clarke space vector `θ = atan2(vβ, vα)` แล้ว `f = [θ(t) − θ(t−20 ms)]/(2π·20 ms)` ไม่ใช้ state ของ controller เลย
- **P ที่ขั้ว**: `Σ v·i` ที่โหลด เฉลี่ยทีละ 0.5 ms
- **โมเดล black-box** (SG + governor droop + AGC): `2H dw/dt = Pm − pf − K·w`, `τf dpf/dt = P − pf`, `dPm/dt = −Ki·50·w` เริ่มที่สมดุล แล้วเอา output ผ่านค่าเฉลี่ย 20 ms แบบเดียวกับตัววัด
- fit แบบ output-error จากจุดเริ่ม 3 จุด และทำ cross-validation (fit event 3 s แล้วทำนาย event 7 s) พร้อม profile scan ของ H

## ผล

### 0. Code check (ใช้ ω ภายในและ P_meas ของ controller จึงเป็น tautology)
fit กลับได้ H = 4.993, K = 177.47, Ki = 4.005 (ตั้งไว้ 5 / 177.08 / 4) **ยืนยันว่าตัว fit ถูก**

### 1. Terminal voltage angle แกว่งหลัง load step ← พบใหม่
ราว 120 ms หลังแต่ละ step มุมแรงดันที่ขั้วแกว่งที่ประมาณ 25 Hz ทำให้ f ที่ขั้วกระโดด **±1–1.6 Hz** (rotor ขยับแค่ ~0.09 Hz) และ P ที่ขั้ว ring ตาม (86→170→127→136 W) นี่คือ dynamics ของ voltage loop + FF จาก E1.2 ไม่ใช่การเคลื่อนที่ของ rotor
ผลคือ (a) ช่วงเวลาที่ inertia ควรแสดงตัว (τm ≈ 56 ms) ถูกกลบด้วยสัญญาณที่ใหญ่กว่า 10 เท่า (b) relay RoCoF ที่ขั้วจะเห็น spike ใหญ่มาก (c) synchronous machine จริงไม่ควรแสดงพฤติกรรมนี้ จึงเป็นอีกเหตุผลที่ต้องเพิ่ม damping ให้ voltage loop
นอกช่วงนี้ f ที่ขั้วตรงกับ f ของ rotor: RMS 4.7 mHz (max 56 mHz จาก spike เล็ก ๆ ของ PWM/ตัววัด) ยืนยันว่าความถี่ที่ขั้ว = ความถี่ของ virtual rotor (grid-forming)
fit จึงตัด 150 ms หลังแต่ละ event ออกจาก residual

### 2. ค่าที่ fit ได้ (ตัด 150 ms หลัง event, ทั้งสอง event)
| พารามิเตอร์ | ตั้งไว้ | ช่วงที่ fit ได้ (3 จุดเริ่ม) | ระบุได้ไหม |
|---|---|---|---|
| K = 1/Rp + D·ωs | 177.08 | 158–174 (−2 ถึง −11%) | ได้ แต่ trade กับ H |
| Ki (secondary) | 4.0 | 3.86–3.87 (−3%) | **ได้** (SE ≈0.5%) |
| H | 5 | 3×10⁻⁸ ถึง 5.7 | **ไม่ได้** |
| τf (P-LPF) | 32 ms | 6–75 ms | **ไม่ได้** |
| residual RMS | — | 4.76 mHz ทุกจุดเริ่ม | — |

### 3. Profile scan ของ H (fix H แล้ว fit K, τf, Ki ใหม่)
| H fixed | 0.05 | 0.5 | 1 | 2.8 | 5 | 10 | 20 |
|---|---|---|---|---|---|---|---|
| RMS (mHz) | 4.763 | 4.762 | 4.763 | 4.770 | 4.765 | 5.347 | 8.882 |
| τf ที่ fit ได้ (ms) | 73 | 71 | 68 | 52 | 20 | 0 | 0 |

**กราฟ cost แบนตั้งแต่ H = 0.05 ถึง 5** ข้อมูลที่ขั้วบอกได้แค่ว่า H ≲ 5–8 s (ตัด H ≥ 10 ทิ้งได้) ที่ fit ได้คือผลรวม lag (τm + τf ≈ 75–90 ms) ไม่ใช่การแบ่งระหว่าง inertia กับ filter ตรงกับทฤษฎีที่ว่า P→ω = −1/(K(1+τm s)(1+τf s)) สมมาตรใน τm, τf และ droop + LPF สมมูลกับ VSG (D'Arco & Suul, IEEE Trans. Smart Grid 2014 ตรวจต้นฉบับก่อนอ้าง)

### 4. Cross-validation
fit จาก event 3 s แล้วทำนาย event 7 s ได้ RMS 5.08 mHz (ค่าที่ตั้ง 5.59, แบบสลับ H = 2.8/τf = 56 ms ได้ 5.79) โมเดล generalize ได้ แต่ทั้งสามชุดดีพอ ๆ กัน
droop-like (H = 0.05) ที่ K, τf เท่าค่าที่ตั้ง ได้ 5.72 mHz เทียบกับ 4.81 mHz → แยกได้ **เฉพาะเมื่อรู้ τf ล่วงหน้า** ถ้าให้ τf เป็นอิสระ droop + LPF fit ได้ดีเท่ากัน

## สรุปสำหรับ thesis

1. จากขั้วโหลด islanded **พิสูจน์ได้**: เป็น grid-forming source ที่ความถี่ขั้วเท่ากับ virtual rotor, มี P–f droop/damping K ≈ 160–174 pu และมี secondary restoration Ki ≈ 3.9
2. **พิสูจน์ไม่ได้**: ว่ามี inertia H = 5 s เพราะ (a) H กับ LPF แลกกันได้ (b) τm = 2H/K ≈ 56 ms เร็วเกินไป จึงจมอยู่ใต้ voltage-angle ringing ±1 Hz ที่ยาว ~120 ms
3. ต้นเหตุเชิงออกแบบ: D คูณ Δω ในหน่วย rad/s ทำให้ D·ωs = 157 กิน K เกือบทั้งหมด inertia จึงมี τ แค่ ~56 ms ถ้าอยากให้ inertia เห็นได้จากขั้ว ต้องให้ τm ≫ τf และ ≫ transient ของ voltage loop (เช่น τm ≥ 0.3–0.5 s) ซึ่งหมายถึงการลด D (หรือเพิ่ม H) เป็นการตัดสินใจเชิงออกแบบที่ต้องคุยกับอาจารย์
4. ทดสอบที่จะพิสูจน์ inertia ได้จริงคือการต่อกับแหล่งจ่ายที่สอง (stiff source ที่ ramp ความถี่ ให้ VSG จ่าย ΔP ≈ −2H·df/dt) หรือ benchmark กับ SPS Synchronous Machine

## ข้อจำกัด
- secondary เปิดอยู่และไม่มี run ที่ปิด secondary
- P ที่ขั้วต่างจาก P_meas ราว 0.6% (Cf/Rd) ส่วนนี้ถูกดูดไปอยู่ใน K/H
- P ที่ขั้วมี ripple ~100 Hz ±2 W ใน steady state บ่งว่ามี negative sequence เล็กน้อย ยังไม่ได้ตรวจสาเหตุ
- ใช้ step เดียวขนาด ΔP ≈ 0.385 pu ไม่ใช่ PRBS/chirp ซึ่งให้ข้อมูลเชิงความถี่ดีกว่า
