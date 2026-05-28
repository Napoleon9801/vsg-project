# Defense Speaking Script — 66AOS02

**Date**: 2026-05-28 (Today) | **Time**: 11:00 | **Room**: B6103
**Committee**: รศ.ดร.อนันท์ อุ่นศิวิไลย์ (advisor) + รศ.ดร.อาทิตย์ ศรีแก้ว + รศ.ดร.บุญเรือง มะรังศรี
**Slot**: ~30 นาที (15–18 min present + 10–15 min Q&A)
**Deck**: `66AOS02-แก้.pdf` — 19 slides

---

## 📖 Acronym Glossary — ตัวย่อทั้งหมดในงาน

### 🔌 Power Electronics & Inverter

| ตัวย่อ | ขยาย | ความหมายเชิง engineer |
|---|---|---|
| **VSG** | Virtual Synchronous Generator | เครื่องกำเนิดไฟฟ้าซิงโครนัสเสมือน — algorithm ที่ทำให้ inverter เลียนแบบ SG |
| **GFM** | Grid-Forming | inverter ที่ "สร้างกริด" เอง (voltage source) |
| **GFL** | Grid-Following | inverter ที่ "ตามกริด" (current source) |
| **PWM** | Pulse Width Modulation | การปรับความกว้างพัลส์เพื่อควบคุมแรงดันเฉลี่ย |
| **SPWM** | Sinusoidal PWM | PWM ที่ใช้ sine wave เปรียบเทียบกับ triangle carrier |
| **SVPWM** | Space Vector PWM | PWM ที่มี DC bus utilization สูงกว่า SPWM 15% |
| **LC filter** | Inductor-Capacitor filter | ตัวกรองฮาร์มอนิก ฝั่งขาออกของ inverter |
| **LCL** | Inductor-Capacitor-Inductor filter | LC filter ที่เพิ่ม L อีกตัวฝั่ง grid side |
| **BESS** | Battery Energy Storage System | ระบบกักเก็บพลังงานด้วยแบตเตอรี่ |
| **DC** | Direct Current | กระแสตรง |
| **AC** | Alternating Current | กระแสสลับ |
| **MOSFET** | Metal-Oxide-Semiconductor Field-Effect Transistor | ทรานซิสเตอร์ switching ใน power stage |
| **IGBT** | Insulated-Gate Bipolar Transistor | ทรานซิสเตอร์ switching ทางเลือก (สำหรับ high power) |
| **SiC** | Silicon Carbide | วัสดุ MOSFET ประสิทธิภาพสูงสำหรับ HV |
| **GaN** | Gallium Nitride | วัสดุ MOSFET ประสิทธิภาพสูงสำหรับ HF |
| **TVS** | Transient Voltage Suppression | diode ป้องกัน voltage spike |
| **DRV8302** | (TI part number) | gate driver IC + protection สำหรับ 3-phase inverter |
| **PCC** | Point of Common Coupling | จุดเชื่อมต่อระหว่าง inverter กับกริด |

### ⚡ Power System & Grid

| ตัวย่อ | ขยาย | ความหมาย |
|---|---|---|
| **SG** | Synchronous Generator | เครื่องกำเนิดไฟฟ้าซิงโครนัสจริง (รอเตอร์หมุน) |
| **RoCoF** | Rate of Change of Frequency | อัตราการเปลี่ยนความถี่ `df/dt` หน่วย Hz/s |
| **RE** | Renewable Energy | พลังงานหมุนเวียน |
| **IBR** | Inverter-Based Resource | แหล่งจ่ายที่เชื่อมต่อผ่าน inverter (ส่วนใหญ่คือ PV/Wind) |
| **SCR** | Short-Circuit Ratio | อัตราส่วน fault current ต่อ rated current — บอกความแข็งแรงของกริด |
| **PV** | Photovoltaic | โซลาร์เซลล์ |
| **DER** | Distributed Energy Resource | แหล่งจ่ายไฟฟ้ากระจาย (PV, Wind, BESS) |
| **AVR** | Automatic Voltage Regulator | ระบบควบคุมแรงดัน excitation ของ SG |
| **FCR** | Frequency Containment Reserve | สำรองพลังงานควบคุมความถี่ |
| **FFR** | Fast Frequency Response | การตอบสนองความถี่แบบเร็ว (~1 s) |
| **H_sys** | System Inertia | inertia รวมของระบบทั้งหมด |
| **CCGT** | Combined Cycle Gas Turbine | โรงไฟฟ้ากังหันแก๊ส (ตัวอย่างใน UK case) |

### 🎛️ Control Theory

| ตัวย่อ | ขยาย | ความหมาย |
|---|---|---|
| **PI** | Proportional-Integral | controller มี gain Kp + integrator Ki |
| **PID** | Proportional-Integral-Derivative | PI + derivative term |
| **PLL** | Phase-Locked Loop | วงจรล็อกเฟส (ใช้ใน GFL หรือ initial sync ของ GFM) |
| **BW** | Bandwidth | แบนด์วิดท์ของ control loop |
| **ISR** | Interrupt Service Routine | function ที่ทำงานเมื่อ timer/event เรียก (real-time control) |
| **LPF** | Low-Pass Filter | ตัวกรองความถี่ต่ำ |
| **HPF** | High-Pass Filter | ตัวกรองความถี่สูง |
| **MPC** | Model Predictive Control | controller ขั้นสูงใช้ optimization |
| **FF** | Feedforward | term ที่ป้อนไปข้างหน้าโดยตรง (ไม่ผ่าน error) |
| **dq frame** | direct-quadrature frame | กรอบหมุนตาม θ → AC sinusoid กลายเป็น DC |
| **αβ frame** | alpha-beta frame | กรอบ stationary 2-axis (Clarke output) |
| **abc frame** | abc frame | กรอบ 3-phase ดั้งเดิม |
| **HIL** | Hardware-in-the-Loop | ทดสอบ firmware บน MCU จริง + simulator hardware |
| **OL / CL** | Open-Loop / Closed-Loop | วงเปิด / วงปิด |

### 💻 Microcontroller & Electronics

| ตัวย่อ | ขยาย | ความหมาย |
|---|---|---|
| **MCU** | Microcontroller Unit | ไมโครคอนโทรลเลอร์ |
| **ESP32** | Espressif 32-bit MCU | MCU dual-core 240 MHz ของ Espressif |
| **WROOM** | Wireless ROM (Espressif naming) | ตัว module ของ ESP32 ที่มี shielding |
| **ADC** | Analog-to-Digital Converter | แปลงสัญญาณ analog เป็น digital |
| **DAC** | Digital-to-Analog Converter | แปลง digital เป็น analog |
| **SPI** | Serial Peripheral Interface | bus 4-wire (MOSI/MISO/SCK/CS) |
| **UART** | Universal Asynchronous Receiver-Transmitter | serial 2-wire ไม่ต้องใช้ clock |
| **I2C** | Inter-Integrated Circuit | bus 2-wire (SDA/SCL) สำหรับ sensor |
| **GPIO** | General-Purpose Input/Output | pin ที่ตั้งค่าได้เป็น in/out |
| **FPU** | Floating-Point Unit | hardware คำนวณ float (อยู่ใน ESP32) |
| **LEDC** | LED Controller | module PWM ของ ESP32 |
| **MCPWM** | Motor Control PWM | module PWM ขั้นสูงของ ESP32 (รองรับ dead-time) |
| **IDE** | Integrated Development Environment | สภาพแวดล้อมเขียน code |
| **CCS** | Code Composer Studio | IDE ของ TI สำหรับ C2000 |
| **PCB** | Printed Circuit Board | แผงวงจรพิมพ์ |
| **LDO** | Low-Dropout Regulator | regulator ที่ทำงานได้แม้ V_in ใกล้ V_out |
| **USB** | Universal Serial Bus | สาย/พอร์ทมาตรฐาน |
| **WiFi** | Wireless Fidelity | network ไร้สาย 2.4/5 GHz |
| **TI** | Texas Instruments | ผู้ผลิตชิปเซมิคอนดักเตอร์ |
| **AD** | Analog Devices | ผู้ผลิตชิป analog/data converter |

### 🔧 Sensors & Components

| ตัวย่อ | ขยาย | ความหมาย |
|---|---|---|
| **AD7606** | (AD part number) | ADC 16-bit, 8-channel, simultaneous sampling |
| **ACS712** | (Allegro part number) | hall-effect current sensor |
| **LM393** | (TI part number) | dual comparator IC |
| **BMS** | Battery Management System | ระบบจัดการแบตเตอรี่ (OV/UV/OC protection) |
| **OV** | Over-Voltage | แรงดันเกิน |
| **UV** | Under-Voltage | แรงดันต่ำ |
| **OC** | Over-Current | กระแสเกิน |
| **OT** | Over-Temperature | อุณหภูมิเกิน |
| **LiFePO4** | Lithium Iron Phosphate | แบตเตอรี่ลิเทียมเหล็กฟอสเฟต (ปลอดภัย ทนทาน) |
| **LiPo** | Lithium Polymer | แบตเตอรี่ลิเทียมโพลิเมอร์ |
| **Sendust** | (alloy name) | วัสดุแกน inductor (Fe-Si-Al alloy) |

### 📐 Standards & Organizations

| ตัวย่อ | ขยาย | ความหมาย |
|---|---|---|
| **IEEE** | Institute of Electrical and Electronics Engineers | สถาบันมาตรฐานหลัก |
| **IEEE 1547** | (standard) | มาตรฐาน DER interconnection |
| **IEEE 2988** | (standard) | มาตรฐาน GFM inverter (กำลังพัฒนา) |
| **IEEE 519** | (standard) | มาตรฐาน harmonic limit |
| **IEC** | International Electrotechnical Commission | สถาบันมาตรฐาน EU |
| **IEC 61400-27** | (standard) | dynamic model ของ wind turbine |
| **ENTSO-E** | European Network of Transmission System Operators for Electricity | องค์กร TSO ของยุโรป |
| **PEA** | Provincial Electricity Authority | การไฟฟ้าส่วนภูมิภาค |
| **MEA** | Metropolitan Electricity Authority | การไฟฟ้านครหลวง |
| **EGAT** | Electricity Generating Authority of Thailand | การไฟฟ้าฝ่ายผลิต |
| **THD** | Total Harmonic Distortion | ปริมาณฮาร์มอนิก (% ของ fundamental) |
| **SCADA** | Supervisory Control and Data Acquisition | ระบบควบคุมและเก็บข้อมูลกริด |

### 🛠️ Software & Tools

| ตัวย่อ | ขยาย | ความหมาย |
|---|---|---|
| **MATLAB** | Matrix Laboratory | โปรแกรมคำนวณเชิงตัวเลขของ MathWorks |
| **Simulink** | Simulation Link | โมเดล block diagram ของ MATLAB |
| **Simscape** | (MATLAB toolbox) | physical modeling toolbox |
| **VS Code** | Visual Studio Code | text editor ของ Microsoft |
| **PlatformIO** | (extension name) | embedded development extension ของ VS Code |
| **HDMI** | High-Definition Multimedia Interface | สาย video/audio |
| **SUT** | Suranaree University of Technology | มหาวิทยาลัยเทคโนโลยีสุรนารี |

### 📊 Performance Metrics & KPIs

| ตัวย่อ | ขยาย | ความหมาย |
|---|---|---|
| **KPI** | Key Performance Indicator | ตัวชี้วัดผลการทำงาน |
| **BoM** | Bill of Materials | รายการอุปกรณ์ |
| **rms** | Root Mean Square | ค่า rms ของสัญญาณ |
| **pk** | Peak | ค่ายอด |
| **EVM** | Error Vector Magnitude | ตัววัดคุณภาพ modulation |
| **ACPR** | Adjacent Channel Power Ratio | (RF metric) |

### 🔣 Math & Greek Symbols

| สัญลักษณ์ | ขยาย | ความหมาย |
|---|---|---|
| **ω** (omega) | angular frequency | ความถี่เชิงมุม (rad/s); `ω = 2πf` |
| **Δω** | delta omega | ส่วนเบี่ยงเบนของ ω จาก ω_0 |
| **θ** (theta) | electrical angle | มุมไฟฟ้าที่ใช้ใน Park transform; `θ = ∫ω dt` |
| **δ** (delta) | rotor angle | มุม rotor สัมพัทธ์ |
| **ζ** (zeta) | damping ratio | อัตราหน่วง (ζ = 0.707 → critically damped) |
| **ω_n** | natural frequency | ความถี่ธรรมชาติของระบบ 2nd order |
| **τ** (tau) | time constant | เวลาคงที่ของ exponential response |
| **H** | inertia constant | inertia constant (วินาที) |
| **D** | damping coefficient | สัมประสิทธิ์การหน่วง |
| **J** | moment of inertia | โมเมนต์ความเฉื่อย (kg·m²) |
| **m_p** | active power droop | droop gain ของ P-f loop |
| **m_q** | reactive power droop | droop gain ของ Q-V loop |
| **R_p** | active droop coefficient | = m_p / 100 (5% droop → R_p = 0.05) |
| **K_v** | excitation inertia | virtual inertia ของ Q-V loop |
| **m_idx** | modulation index | `V_peak / (V_dc/2)` — ควรน้อยกว่า 1 |
| **f** | frequency | ความถี่ (Hz) |
| **Δf** | delta frequency | ส่วนเบี่ยงเบนของ f จาก f_0 (50 Hz) |
| **p.u.** | per unit | หน่วย normalized (= ค่าจริง / ค่า base) |
| **S** | apparent power | กำลังประจักษ์ (VA) |
| **P** | active power | กำลังจริง (W) |
| **Q** | reactive power | กำลังรีแอกทีฟ (VAR) |
| **V_d, V_q** | d-axis, q-axis voltage | แรงดันในกรอบ dq |
| **i_d, i_q** | d-axis, q-axis current | กระแสในกรอบ dq |
| **V_dc** | DC bus voltage | แรงดัน DC bus |
| **V_set** | voltage setpoint | แรงดันเป้าหมาย |
| **P_set** | active power setpoint | กำลังจริงเป้าหมาย |
| **P_meas** | measured active power | กำลังที่วัดได้ |
| **L_f** | filter inductor | inductor ใน LC filter |
| **C_f** | filter capacitor | capacitor ใน LC filter |
| **R_d** | damping resistor | ตัวต้านทาน damp LC resonance |
| **R_load** | load resistance | ความต้านทานโหลด |
| **R_f** | filter parasitic resistance | ความต้านทานปรสิตของ L_f |
| **f_sw** | switching frequency | ความถี่ switching ของ PWM (10 kHz) |
| **f_res** | resonance frequency | ความถี่ resonance ของ LC = `1/(2π√LC)` |
| **K_p, K_i** | PI gains | proportional gain, integral gain |
| **Pm** | mechanical power | กำลังกล (input ของ SG) |
| **Pe** | electrical power | กำลังไฟฟ้า (output ของ SG) |

### 🔬 Research Methodology

| ตัวย่อ | ขยาย | ความหมาย |
|---|---|---|
| **VISMA** | Virtual Synchronous Machine | algorithm VSG รุ่นแรก (Beck 2007) |
| **MMC** | Modular Multilevel Converter | inverter หลายระดับ |
| **DAB** | Dual Active Bridge | DC-DC converter แบบ bidirectional |

### 🖥️ Processing Hardware (เพิ่มเติม)

| ตัวย่อ | ขยาย | ความหมาย |
|---|---|---|
| **DSP** | Digital Signal Processor | ชิปประมวลผลสัญญาณดิจิทัล — เร็วกว่า MCU ทั่วไป มี hardware MAC |
| **DSC** | Digital Signal Controller | DSP + MCU peripherals (เช่น TI C2000) |
| **FPGA** | Field-Programmable Gate Array | ชิปที่ตั้งค่า logic ได้ — เร็วสุดสำหรับ parallel processing |
| **ASIC** | Application-Specific Integrated Circuit | ชิป custom สำหรับงานเฉพาะ |
| **C2000** | (TI part family) | TMS320F28xxx series — DSC ของ TI สำหรับ motor/power control |
| **F28379D** | (TI part number) | DSC ที่นิยมใน VSG literature (200 MHz dual-core) |
| **TWDT** | Task Watchdog Timer | timer ของ ESP32 — รีบูตอัตโนมัติถ้า task hang |
| **IWDT** | Interrupt Watchdog Timer | watchdog ใน ISR ของ ESP32 |
| **MAC** | Multiply-Accumulate | คำสั่ง hardware-accelerated สำหรับ DSP |
| **WROOM-32D** | (Espressif part) | module ของ ESP32 รุ่นที่ Napoleon ใช้ |

### 📏 Units — หน่วยที่ใช้บ่อย

| หน่วย | ขยาย | ใช้กับ |
|---|---|---|
| **W, kW, MW** | Watt | active power (P) |
| **VA, kVA** | Volt-Ampere | apparent power (S) — `S² = P² + Q²` |
| **VAR, kVAR** | Volt-Ampere Reactive | reactive power (Q) |
| **Hz, kHz, MHz** | Hertz | ความถี่ |
| **rad/s** | radian per second | ความถี่เชิงมุม `ω = 2πf` |
| **s, ms, µs, ns** | second | เวลา |
| **A, mA** | Ampere | กระแส |
| **V, mV, VDC, VAC** | Volt (DC/AC) | แรงดัน |
| **Ω, kΩ, MΩ** | Ohm | ความต้านทาน |
| **H, mH, µH** | Henry | inductance |
| **F, µF, nF, pF** | Farad | capacitance |
| **dB, dBm** | Decibel | gain / power ratio |
| **°C, K** | Celsius, Kelvin | อุณหภูมิ |
| **pu, p.u.** | per unit | normalized = ค่าจริง / ค่า base |
| **%** | percent | เช่น droop 5% = R_p = 0.05 |
| **LSB** | Least Significant Bit | resolution ของ ADC/PWM |
| **bit** | binary digit | resolution (เช่น 16-bit ADC = 65536 ระดับ) |
| **SPS, kSPS** | Samples Per Second | sampling rate ของ ADC |

### ⚠️ Hardware Convention Symbols

| สัญลักษณ์ | ขยาย | ความหมาย |
|---|---|---|
| **nFAULT** | active-low FAULT signal | สัญญาณ fault ที่ "0 = fault, 1 = OK" |
| **/CS** หรือ **CS̄** | Chip Select (active-low) | pin เลือก IC บน SPI bus |
| **MISO** | Master In, Slave Out | data line ใน SPI (slave → master) |
| **MOSI** | Master Out, Slave In | data line ใน SPI (master → slave) |
| **SCK** หรือ **SCLK** | Serial Clock | นาฬิกาของ SPI |
| **VCC, VDD** | supply voltage (positive) | แรงดันบวก |
| **VSS, GND** | ground / 0V | กราวด์ |
| **PWM_EN** | PWM Enable | สัญญาณเปิด-ปิด PWM (จาก protection) |
| **Vth** | Threshold Voltage | แรงดัน threshold ของ MOSFET หรือ comparator |
| **Vds, Vgs, Vsd** | drain-source, gate-source voltage | แรงดันของ MOSFET |
| **Ids, Igs** | drain/gate current | กระแสของ MOSFET |
| **Rds(on)** | drain-source resistance (ON) | ความต้านทาน MOSFET ตอนนำกระแส |

### 💡 Tips การใช้

1. **อ่านก่อนสอบ**: ดูตัวย่อทุกตัวที่อาจถูกถาม
2. **ถ้าลืม**: ดูจาก slide ที่เกี่ยวข้อง — บอก committee ว่า "ขออนุญาตค้นใน slide ก่อนตอบครับ"
3. **ตัวย่อสำคัญที่ committee จะถาม**: VSG, GFM, GFL, RoCoF, SCR, IBR, BESS, PI, PLL, LC, BoM, IEEE 1547

---

## 🎤 Timing Budget Overview

| Slide | หัวข้อ | เวลา |
|---|---|---|
| 1 | Title | 30 s |
| 2 | Outline | 30 s |
| 3 | ที่มา + UK case | 90 s |
| 4 | GFL ไม่พอ | 60 s |
| 5 | VSG คือคำตอบ | 45 s |
| 6 | วัตถุประสงค์ | 60 s |
| 7 | ขอบเขต | 60 s |
| 8 | GFL vs GFM | 45 s |
| 9 | Swing Equation | 90 s |
| 10 | VSG Architecture 4 ชั้น | 90 s |
| 11 | งานวิจัยที่เกี่ยวข้อง | 90 s |
| 12 | ภาพรวมระบบ | 60 s |
| 13 | BoM | 60 s |
| 14 | Test Plan + KPI | 60 s |
| 15 | Gantt | 45 s |
| 16 | Risk | 60 s |
| 17 | ผลที่คาด | 45 s |
| 18 | จบการนำเสนอ | 15 s |
| 19 | Q&A | — |
| **รวม** | | **~16 min** |

---

## ⚠️ 3 จุดอ่อนของ deck ที่ต้องระวัง

1. **BESS spec ไม่ตรง 3 จุด**: slide 7 = 24V 6Ah, slide 12 = 24V 10Ah, slide 13 = 24V 6Ah → **ถ้ากรรมการถาม ตอบว่า "ขออภัยครับ slide 12 พิมพ์ผิด — ค่าจริงคือ 24V 6Ah ตาม BoM ใน slide 13"**
2. **Title ไม่ตรง schedule**: เปิดเรื่องด้วย opening line ใน slide 1 ตามด้านล่าง
3. **Risk row DRV8302**: บอกว่าจะลดเป็น 24V — ตอนนี้คุณใช้ 24V อยู่แล้ว → ถ้าถาม ตอบว่า "เลือก 24V เป็น baseline แล้วครับ เป็น risk ที่ accepted"

---

## 📜 SLIDE 1 — Title (30 วินาที)

### Opening line (สำคัญ — เปิดสบายแล้วเปิดเรื่อง mismatch ก่อนกรรมการถาม)

> "สวัสดีครับท่านคณะกรรมการ ผมนายชินวัตร ดุมกลาง รหัส B66xxxxx ครับ พร้อมเพื่อนในทีมอีก 2 คน คือ นายฉัตรมงคล นามจำปา และ นายกิตติทัต เจริญใจ ครับ
>
> **เรียนกรรมการครับ** — ชื่อโครงงานในตารางสอบที่ระบุว่า 'Grid-Forming Inverter Prototype for Microgrid' ตรงกับชื่อในเล่มข้อเสนอนี้นะครับ — เป็นเรื่องเดียวกัน เพราะ VSG = Virtual Synchronous Generator คือ algorithm ของ Grid-Forming Inverter ตัวหนึ่ง ครับ
>
> โครงงานนี้อยู่ภายใต้การดูแลของท่าน รองศาสตราจารย์ ดร.อนันท์ อุ่นศิวิไลย์ ครับ"

**Transition**: "ขออนุญาตเริ่มต้นด้วย outline ของการนำเสนอครับ"

---

## 📜 SLIDE 2 — Outline (30 วินาที)

> "ผมแบ่งการนำเสนอเป็น 6 หัวข้อหลักครับ
>
> **(ชี้แต่ละหัวข้อ)** เริ่มจาก **บทนำและที่มาของปัญหา**, ตามด้วย **วัตถุประสงค์และขอบเขต**, **ทฤษฎีพื้นฐาน**, **งานวิจัยที่เกี่ยวข้อง**, **วิธีดำเนินงานและการออกแบบ** ซึ่งจะรวม BoM และ Test plan, และปิดท้ายด้วย **แผนการดำเนินงานและความเสี่ยง** ครับ"

**Transition**: "เริ่มจากที่มาของปัญหาครับ"

---

## 📜 SLIDE 3 — ที่มา + UK Blackout (90 วินาที — สำคัญ ตั้ง stage)

### Part 1: บริบทระบบไฟฟ้ายุคใหม่ (40 วินาที)

> "ในปัจจุบัน ระบบไฟฟ้าทั่วโลกกำลังเปลี่ยนผ่านจากโรงไฟฟ้าฟอสซิลไปสู่พลังงานหมุนเวียน เช่น Solar PV และ Wind อย่างรวดเร็วครับ
>
> ปัญหาคือ พลังงานเหล่านี้ **เชื่อมต่อผ่าน inverter แบบ Grid-Following** ซึ่งไม่มีมวลหมุนเหมือน synchronous generator แบบดั้งเดิม
>
> ผลที่ตามมาคือ **System Inertia หรือ H_sys ของระบบลดลง** → ทำให้ **RoCoF หรือ Rate of Change of Frequency สูงขึ้น** → ระบบเสี่ยงต่อ Frequency Instability และ Blackout ครับ"

### Part 2: UK Blackout case (40 วินาที — โชว์ evidence)

> "**ขอยกกรณีศึกษา UK Blackout วันที่ 9 สิงหาคม 2562** เป็นตัวอย่างชัดเจนครับ
>
> วันนั้น Hornsea Wind Farm ขนาด 737 เมกะวัตต์ trip กะทันหัน ตามด้วย Little Barford CCGT 664 เมกะวัตต์ trip ตาม
>
> **RoCoF เกิน −0.125 Hz ต่อวินาที** ความถี่ตกถึง 48.8 Hz และผู้ใช้ไฟกระทบประมาณ 1 ล้านคนทั่ว UK ครับ
>
> นี่คือตัวอย่างจริงที่แสดงว่า **ระบบไฟฟ้าที่มี inverter penetration สูงต้องการ synthetic inertia** ครับ
>
> และ **VSG หรือ Grid-Forming Inverter คือทางออกในระดับ inverter-level** ที่จะแก้ปัญหานี้ครับ"

**Transition**: "แต่ทำไม Grid-Following inverter ที่ใช้กันอยู่จึงไม่เพียงพอ?"

---

## 📜 SLIDE 4 — Grid-Following ไม่เพียงพอ (60 วินาที)

> "GFL inverter มี 5 ข้อจำกัดสำคัญครับ
>
> **(1)** ตัวมันเองเป็น **Current Source** ที่อาศัย PLL ตรวจจับมุมและความถี่ของกริด — **ต้องมี stiff grid อยู่ก่อน** ถึงจะทำงานได้
>
> **(2)** **ไม่จ่าย Inertia** — ไม่มี dynamic energy reserve เพื่อหน่วงการเปลี่ยนแปลงความถี่
>
> **(3)** **ทำงาน Islanded ไม่ได้** — ขาด stiff grid ก็ trip ทันที → ใช้กับ microgrid ไม่ได้
>
> **(4)** **Low SCR + High IBR → Instability** — ระบบที่ Short-Circuit Ratio ต่ำ และสัดส่วน Inverter-Based Resource สูง จะเกิด oscillation และ control interaction ระหว่าง inverter ด้วยกัน
>
> **(5)** **ไม่ตอบโจทย์ Black-Start** — ไม่สามารถสร้างกริดขึ้นมาใหม่หลัง blackout ครับ
>
> ทั้ง 5 ข้อนี้คือเหตุผลที่ระบบไฟฟ้ายุคใหม่ต้องการ inverter ประเภทใหม่"

**Transition**: "และนั่นคือ Grid-Forming Inverter หรือ VSG ครับ"

---

## 📜 SLIDE 5 — VSG คือคำตอบ (45 วินาที)

> "**แนวคิดหลักของ VSG** คือการเลียนแบบพฤติกรรมของ Synchronous Generator ในระดับ software ของ inverter ครับ
>
> inverter จะทำตัวเป็น **Voltage Source** หลัง source impedance — และ **กำหนดมุมและความถี่อ้างอิงเอง** โดยไม่ต้องพึ่ง PLL ในโหมด islanded
>
> ผลที่ได้คือ:
> **(1)** **Virtual Inertia** ลด RoCoF ในช่วง disturbance
> **(2)** ทำงานได้ทั้ง **Grid-connected และ Stand-alone**
> **(3)** รองรับ **Black-Start และ Fault Current Contribution**
> **(4)** ยกระดับเสถียรภาพให้กับกริดที่มี Renewable Energy สัดส่วนสูง"

**Transition**: "ด้วยเหตุนี้ จึงนำมาสู่วัตถุประสงค์ 4 ข้อของโครงงานครับ"

---

## 📜 SLIDE 6 — วัตถุประสงค์ (60 วินาที)

> "ผมตั้งวัตถุประสงค์ไว้ 4 ข้อครับ — เรียงจากต้นน้ำ-ปลายน้ำ
>
> **ข้อ 1** ออกแบบและสร้างแบบจำลอง VSG สำหรับอินเวอร์เตอร์ 3 เฟส บน MATLAB/Simulink — เป็น **base ของทุกอย่าง** ที่ทำเสร็จก่อน
>
> **ข้อ 2** เปรียบเทียบสมรรถนะ VSG กับ Droop Control แบบดั้งเดิม — เพื่อวัดข้อดีของ inertia ที่ VSG ให้
>
> **ข้อ 3** วิเคราะห์ช่วงพารามิเตอร์ **H และ D ที่เหมาะสม** เพื่อควบคุม RoCoF ให้สอดคล้องกับ standard
>
> **ข้อ 4** สร้างและทดสอบ **ชุดต้นแบบฮาร์ดแวร์** ควบคุมด้วย ESP32 ยืนยันผลกับการจำลอง — เป็น deliverable สุดท้ายครับ"

**(ถ้าจะแสดง confidence)**:
> "เรียนคณะกรรมการครับว่า ข้อ 1 ที่เกี่ยวกับ MATLAB/Simulink model — **ผมเริ่มทำไปแล้วในขั้นต้น** และมีผลที่ verify กับ analytical ครับ ส่วนที่เหลือ 3 ข้ออยู่ใน Gantt 16 สัปดาห์ที่จะนำเสนอภายหลังครับ"

**Transition**: "ต่อไปคือขอบเขตและข้อจำกัดของโครงงานครับ"

---

## 📜 SLIDE 7 — ขอบเขต (60 วินาที)

> "**ขอบเขตของโครงงาน** — สรุปในตารางครับ
>
> **(ชี้แต่ละบรรทัด)**
> - เครื่องมือจำลอง: **MATLAB / Simulink**
> - ไมโครคอนโทรลเลอร์: **ESP32-WROOM-32D เป็นเป้าหมายหลัก** — ราคาประหยัด, dual-core 240 MHz, มี FPU ในตัว
> - IDE: Arduino IDE + VS Code PlatformIO
> - **DC Bus ไม่เกิน 60 VDC** และ **กำลังไฟฟ้าไม่เกิน 300 W** — เป็นเพดาน safety ที่กำหนดเพื่อความปลอดภัยในการปฏิบัติงานในห้องปฏิบัติการ
> - **BESS: 24 V / 6 Ah LiFePO4** เป็น energy reservoir สำหรับ inertial transient
> - **โหมดทดสอบ: Islanded** เป็นหลักครับ
> - **ไม่ครอบคลุม**: THD เชิงลึก และ Thermal/Switching Loss — เพราะอยู่นอก scope ของ control validation"

**(ถ้ามีคำถามเชิงรุก)**:
> "ทั้งเพดาน 60V/300W เป็น **safety envelope** ส่วน design point จริงจะเลือกตามผลจำลองในแต่ละ stage ครับ"

**Transition**: "ก่อนเข้าทฤษฎี ขอเปรียบเทียบ GFL กับ GFM ให้ชัดอีกครั้ง"

---

## 📜 SLIDE 8 — GFL vs GFM (45 วินาที)

> "ตารางเปรียบเทียบ 8 คุณสมบัติครับ — สรุปสั้น ๆ
>
> **GFL** = Current source, ต้องใช้ PLL, ต้องการ stiff grid, ไม่มี inertia, Black-start ไม่ได้, แต่ control ง่าย และใช้แพร่หลายใน Solar PV และ Wind
>
> **GFM (ที่ผมทำ)** = Voltage source, **กำหนดมุม/ความถี่เอง**, ทำงานใน weak/islanded ได้, **มี Virtual Inertia**, Black-start ได้, control ซับซ้อนกว่า, ใช้ใน Microgrid และ BESS
>
> **มาตรฐานที่เกี่ยวข้อง**: GFM ครอบคลุมโดย IEEE 1547-2018 และ IEEE 2988 ที่กำลังพัฒนาครับ"

**Transition**: "ตัวสมการหลักของ VSG คือ Swing Equation ครับ"

---

## 📜 SLIDE 9 — Swing Equation (90 วินาที — equation slide สำคัญ)

> "นี่คือสมการหลักของระบบ — **Swing Equation** ในรูป per-unit ครับ
>
> **(เขียนตามสมการบนกระดาน หรือชี้บน slide)**:
>
> **`2H · dΔω/dt = Pm - Pe - D · Δω`**
>
> **ขอแยกอธิบายทุกพจน์ครับ**:
> - **`H`** = Inertia Constant หน่วยเป็นวินาที — สื่อความหมายว่าพลังงานจลน์ที่เก็บใน rotor เทียบกับกำลังพิกัด — SG จริงทั่วไป H ประมาณ **2-6 วินาที**
> - **`Δω`** = ส่วนเบี่ยงเบนของความเร็วเชิงมุมจาก ω_0 (synchronous speed)
> - **`Pm`** = กำลังกลที่จ่ายเข้า rotor — ใน VSG = **P_set** ที่ operator สั่ง
> - **`Pe`** = กำลังไฟฟ้าที่จ่ายออก — วัดจริงที่จุด PCC
> - **`D`** = Damping Coefficient หน่วง oscillation
>
> **ความสำคัญของสมการนี้คือ** — VSG ของผมจะ **implement สมการนี้แบบ real-time** ใน firmware ESP32 ทำให้ inverter มี dynamic behavior เหมือน synchronous generator จริง
>
> **เมื่อ integrate ω จะได้มุม θ** ที่ใช้เป็น reference สร้าง voltage output ครับ"

**(ถ้ามีเวลาเหลือ)**:
> "การปรับค่า H ให้สูง → frequency stability ดีขึ้น แต่ response ช้าลง — เป็น trade-off ที่จะวิเคราะห์ใน parameter sweep ครับ"

**Transition**: "สมการนี้ implement ใน ESP32 ผ่าน 4 ชั้น cascaded ครับ"

---

## 📜 SLIDE 10 — VSG Architecture 4 ชั้น (90 วินาที)

> "สถาปัตยกรรม VSG ที่ผมออกแบบมี **4 ชั้น cascaded** ครับ — ทำงานต่อเนื่องใน ISR เดียวที่ 10 kHz
>
> **Layer 1 — Power Calculation**: รับ V_abc และ i_abc จาก ADC → คำนวณ P และ Q ที่จุดเชื่อมต่อ — instantaneous, ทำทุก ISR
>
> **Layer 2 — VSG Core (Swing Equation)**: หัวใจของระบบครับ — แบ่งเป็น **P-f loop** ทำ Virtual Inertia + Damping และ **Q-V loop** ทำ Droop และ Excitation emulation
>
> **Layer 3 — Voltage / Current Inner Loop**: Cascaded PI controller ในกรอบ dq — **outer voltage PI bandwidth 100 Hz** + **inner current PI bandwidth 1 kHz** ห่าง decade rule
>
> **Layer 4 — PWM / SVPWM Modulator**: สร้างสัญญาณ gate drive ที่ความถี่ switching 10 kHz ส่งไปยัง DRV8302
>
> **เหตุผลที่แบ่ง 4 ชั้น cascaded** คือ — แต่ละชั้นทำงานที่ **timescale ต่างกัน 10 เท่า** → ไม่ interact กัน → tune แยกอิสระ → stability พิสูจน์ได้ครับ"

**Transition**: "แนวคิด VSG มีงานวิจัยรองรับครับ"

---

## 📜 SLIDE 11 — งานวิจัยที่เกี่ยวข้อง (90 วินาที)

> "ผมอ้างอิงงานวิจัย 5 ชิ้นหลักครับ — เรียงตามวิวัฒนาการของ VSG
>
> **(1) VISMA** โดย Beck และ Hesse ปี 2007 — เป็น Full-order SG emulation ใช้ตัวแปร state 4-7 ตัว — **แม่นยำสูง** แต่ต้องการการคำนวณและ sensor มาก
>
> **(2) Synchronverter** โดย Zhong และ Weiss ปี 2011 — ลด VISMA เป็น **second-order Swing Equation + excitation emulation** ที่สำคัญคือ **self-sync** ไม่ต้องใช้ PLL — **โครงงานของผมใช้ approach นี้** เพราะ balance ระหว่าง fidelity กับ complexity
>
> **(3) Droop-based VSG** โดย De Brabandere ปี 2007 — ใช้ P-f และ Q-V droop รวมกับ low-pass filter — **ง่าย** เหมาะกับ microgrid แต่ได้ inertia แค่ first-order
>
> **(4) Adaptive VSG** โดย Alipoor ปี 2015 — ปรับ H และ D ตาม disturbance — รองรับเหตุการณ์ได้ดีกว่า fixed parameter — **ใส่ใน future work** หากเวลาพอ
>
> **(5) GFM Comparison** โดย D'Arco และ Suul ปี 2014 — สรุปว่า Synchronverter ใกล้ SG ที่สุด แต่ sensitive ต่อ parameter mismatch
>
> **ช่องว่างของโครงงานนี้** — งานวิจัยส่วนใหญ่ implement บน DSP เช่น TI C2000 หรือ FPGA ที่ราคาสูง **โครงงานนี้พิสูจน์ว่า ESP32 ที่ราคาประหยัดทำได้** เป็น contribution หลักครับ"

**Transition**: "ต่อไปเป็นวิธีดำเนินงานและการออกแบบครับ"

---

## 📜 SLIDE 12 — ภาพรวมระบบ (60 วินาที)

> "ภาพรวมระบบของผมแบ่งเป็น **Power Stage และ Control Stage** ครับ
>
> **Power Stage** (ชี้จากซ้ายไปขวา): **BESS** 24V 6Ah → **DRV8302 Bridge** ทำหน้าที่ 3-phase inverter → **LC Filter** ตัด switching harmonic → **3-phase Y Load**
>
> **(หากกรรมการจ้อง BESS spec บน diagram)** — *"ขออภัยครับ ตัวเลขใน diagram อาจไม่ตรงกับ BoM — ค่าจริงคือ 24V 6Ah ตามที่ระบุใน slide ถัดไปครับ"*
>
> **Sensing Stage**: **Voltage Divider** วัด V_abc และ **ACS712 ×3** วัด I_abc แต่ละเฟส → ส่งเข้า **AD7606 ADC** ที่เป็น 16-bit 8-channel **simultaneous sampling** สำคัญสำหรับ Park transform
>
> **Control Stage**: **ESP32-WROOM-32D** เป็นหัวใจ — รัน ISR ที่ 10 kHz, ส่ง PWM 6 ช่องกลับไปยัง DRV8302
>
> ทั้งระบบทำงานใน loop closed-loop control ครับ"

**Transition**: "รายการอุปกรณ์ทั้งหมดอยู่ใน BoM ครับ"

---

## 📜 SLIDE 13 — BoM (60 วินาที)

> "BoM ของระบบฮาร์ดแวร์มี **10 รายการ** ครับ — ขอชี้ที่สำคัญ
>
> **(1)** ESP32-WROOM-32D เป็น MCU หลัก
> **(2)** DRV8302 Shield เป็น 3-phase bridge — รวม gate driver + MOSFET พร้อม fault protection ในตัว
> **(3)** AD7606 ADC 16-bit, 8-channel — เลือกเพราะ **simultaneous sampling** ที่ phase relationship สำคัญสำหรับ Park transform
> **(4)** ACS712-05B ตรวจวัดกระแสได้ ±5 A ต่อเฟส
> **(5)** Filter L: 1.5 mH Sendust core
> **(6)** Filter C: 15 µF AC Polypropylene 2 ตัวต่อเฟส
> **(7)** Damping R: 1Ω 25W อนุกรมกับ Cf เพื่อ damp LC resonance
> **(8)** BESS LiFePO4 **24V 6Ah** เป็น energy reservoir
> **(9)** DC Supply 0-60V/5A สำหรับ test bench
> **(10)** AC Load รีโอสตัท 0-100Ω 200W ปรับโหลดได้
>
> **ค่า LC คำนวณให้ resonance อยู่ระหว่าง grid fundamental 50 Hz และ switching 10 kHz** ครับ"

**Transition**: "ต่อไปคือแผนการทดสอบและตัวชี้วัดครับ"

---

## 📜 SLIDE 14 — Test Plan + KPI (60 วินาที)

> "แผนการทดสอบมี **4 สถานการณ์** ครับ
>
> **(1) Step Load Change** — เพิ่ม-ลดโหลด 50% แบบทันที — วัด **RoCoF, Frequency Nadir, Settling Time**
>
> **(2) Islanded Mode** — operate แบบ stand-alone — วัด **Voltage Stability และ Black-Start capability**
>
> **(3) Parameter Sweep H, D** — sweep H ระหว่าง 2-10 วินาที และ D ระหว่าง 5-50 pu — หา **Optimal Region สำหรับ RoCoF spec** — เป็นการตอบวัตถุประสงค์ข้อ 3
>
> **(4) VSG vs Droop Compare** — ใช้ step load เดียวกัน — เทียบ frequency response ระหว่าง 2 algorithm — ตอบวัตถุประสงค์ข้อ 2
>
> **เกณฑ์ผ่าน Acceptance Criteria** ครับ:
> - **RoCoF ≤ 0.5 Hz ต่อวินาที** — สอดคล้อง IEEE 1547-2018
> - **Frequency Nadir อยู่ในช่วง 49.5 – 50.5 Hz** ที่ step load ไม่เกิน 50%
> - **Settling time ไม่เกิน 2 วินาที**"

**Transition**: "แผนการดำเนินงานทั้งหมดอยู่ใน Gantt chart ครับ"

---

## 📜 SLIDE 15 — Gantt 16 สัปดาห์ (45 วินาที)

> "**Gantt Chart 16 สัปดาห์** ครอบคลุม 4 เดือน — ตุลาคม ถึง มกราคม ครับ
>
> แบ่งงานเป็น 6 phases:
> - **W1-2** ศึกษาทฤษฎีและเอกสารที่เกี่ยวข้อง
> - **W3-4** การจำลองสถานการณ์บนซอฟต์แวร์ MATLAB/Simulink
> - **W5-6** ออกแบบระบบฮาร์ดแวร์และวงจรวัด
> - **W7-9** พัฒนา firmware ควบคุมบน ESP32
> - **W10-12** ประกอบและทดสอบกับฮาร์ดแวร์จริง
> - **W13-16** วิเคราะห์ผลและเขียนรายงานสรุป
>
> **เป้าหมายสุดท้าย** — มี physical prototype ทำงานได้จริง + รายงานสมบูรณ์ภายในสิ้นเดือนมกราคมครับ"

**(ถ้าจะเสริม confidence)**:
> "เรียนคณะกรรมการครับ — ผมเริ่ม phase 1 และ phase 2 ในระดับ simulation ไปแล้วก่อนเริ่ม semester เพื่อเตรียมความพร้อม"

**Transition**: "แต่ทุกแผนมีความเสี่ยง — ผมเตรียมแผนสำรองไว้ครับ"

---

## 📜 SLIDE 16 — Risk + Mitigation (60 วินาที)

> "ผมระบุความเสี่ยงหลัก 6 ข้อ พร้อมแผนสำรองครับ
>
> **(1) ESP32 ISR overrun ที่ 10 kHz** — โอกาสกลาง / impact สูง → **ลดเป็น 5 kHz หรือใช้ TI C2000 + CCS เป็น contingency**
>
> **(2) DRV8302 ไม่ทนที่ 60 V** — โอกาสต่ำ / impact สูง → **scope รองคือ ลดเป็น 24 V / 100 VA** — ซึ่งสอดคล้องกับ BESS 24V ที่ผมเลือก
>
> **(3) LC Filter resonance ไม่ตรงคำนวณ** — กลาง/กลาง → **ใส่ damping R และวัด Bode plot ใหม่**
>
> **(4) BESS over-current** — ต่ำ/สูง → **Fuse + BMS + soft-start** ทั้ง 3 layers
>
> **(5) Hardware delay ส่งของช้า** — กลาง/กลาง → **fallback คือ defend ด้วยผลจำลองอย่างเดียว**
>
> **(6) RoCoF ไม่ผ่าน spec** — กลาง/กลาง → **ปรับ H, D ใหม่ + ใช้ Adaptive VSG เป็น future work**"

**(ถ้ามีคำถาม "ทำไม ESP32 พอแน่")**:
> "ตามการประมาณการ ESP32 ที่ 240 MHz dual-core มี budget 100 microsecond ต่อ ISR — control loop ใช้ประมาณ 8 microsecond → headroom 92% ครับ"

**Transition**: "และสุดท้าย คือผลที่คาดว่าจะได้รับครับ"

---

## 📜 SLIDE 17 — ผลที่คาดว่าจะได้รับ (45 วินาที)

> "Deliverable 5 อย่างครับ
>
> **(1) Simulink Model** — แบบจำลอง VSG ที่แม่นยำสำหรับใช้อ้างอิงเชิงวิชาการต่อในอนาคต
>
> **(2) Parameter Guideline** — ระเบียบวิธีจูน H และ D สำหรับวิศวกรไฟฟ้านำไปประยุกต์ใช้จริง
>
> **(3) Hardware Prototype** — **ชุดต้นแบบ 100 W อยู่ใน envelope ไม่เกิน 300 W** ควบคุมด้วย ESP32 — ทำงานได้จริงในห้องปฏิบัติการ
>
> **(4) Grid Stability Contribution** — แนวทางเพิ่มเสถียรภาพให้กับ Weak Grid และ Microgrid ในระดับ inverter-level
>
> **(5) Knowledge Transfer** — องค์ความรู้ GFM/VSG บน **MCU ราคาประหยัด** เผยแพร่ในประเทศไทย — ลดอุปสรรคการเข้าถึงเทคโนโลยีนี้"

**Transition**: "สิ่งนี้คือ summary ของโครงงานทั้งหมดครับ"

---

## 📜 SLIDE 18 — จบการนำเสนอ (15 วินาที)

> "นี่คือการนำเสนอทั้งหมดครับ — **ขอบคุณคณะกรรมการที่สละเวลามาฟังครับ ผมยินดีรับฟังข้อเสนอแนะและตอบคำถามครับ**"

**(หยุดสักครู่ ยิ้ม รอ committee เริ่ม Q&A)**

---

## 📜 SLIDE 19 — Q&A

**ไม่ต้องพูดอะไรเพิ่มในการเปิด Q&A — ปล่อยให้ committee นำ**

---

# 🎯 Closing Tips ก่อนพูดจริง

## 1. ตัวเลขที่ต้องจำให้ขึ้นใจ

| ค่า | จำนวน |
|---|---|
| H (inertia) | **5 s** |
| Droop | **5%** (R_p = 0.05) |
| f_switching | **10 kHz** |
| Inner I PI BW | **1 kHz** |
| Outer V PI BW | **100 Hz** |
| ESP32 clock | **240 MHz** |
| ISR budget | **100 µs** |
| ใช้จริง | **8 µs** (8%) |
| BESS | **24 V / 6 Ah** |
| RoCoF KPI | **≤ 0.5 Hz/s** |
| Frequency Nadir | **49.5 – 50.5 Hz** |
| Settling time | **≤ 2 s** |

## 2. คำถาม **likely** ที่ Committee ถามแน่

1. "ESP32 ที่ 10 kHz ทำได้จริงเหรอ?" → **A**: 8 µs / 100 µs budget = 8% (slide 16 risk row 1 mitigation)
2. "ทำไมใช้ ESP32 ไม่ใช้ DSP?" → **A**: ราคาประหยัด 10x + เป้าหมายเผยแพร่ในไทย (slide 17 deliverable 5)
3. "RoCoF เกณฑ์ 0.5 Hz/s มาจากไหน?" → **A**: IEEE 1547-2018 (slide 14 Acceptance criteria)
4. "ตอนนี้ทำอะไรเสร็จแล้ว?" → **A**: Phase 1-2 ระดับ simulation เริ่มแล้ว, มี analytical verification
5. "16 สัปดาห์พอจริงเหรอ?" → **A**: เริ่ม phase 1-2 ล่วงหน้า + risk mitigation 6 ข้อ + fallback ทุก phase
6. "BESS 24V 6Ah พอสำหรับ inertial transient ไหม?" → **A**: 24V × 6Ah = 144 Wh / 100W transient × 1s = สำรอง 5000× → over-spec
7. "ทำไม VSG ไม่ใช่ adaptive?" → **A**: ตามคำแนะนำอาจารย์ที่ปรึกษา "fixed-parameter ก่อน → adaptive ถ้าเวลาพอ" (advisor feedback 2026-05-26)

## 3. ถ้าจน — ใช้ "Bridge to advisor"

> "เป็นคำถามที่ดีครับ — ในส่วนนี้ผมจะหารือกับอาจารย์ที่ปรึกษาเพิ่มเติม และนำมา revise ในขั้นถัดไปครับ"

## 4. ห้ามทำ

- ❌ **อย่ายอมรับ "ไม่ได้คิด"** — เปลี่ยนเป็น "ยังไม่ได้สรุป — จะ verify ในขั้นถัดไป"
- ❌ **อย่าตอบเร็วเกินไป** — หยุดคิด 2-3 วินาที ก่อนตอบ — committee จะเห็นว่าคุณ thoughtful
- ❌ **อย่าใช้คำว่า "อะ" "เออ"** บ่อยเกินไป — ฝึก pause แทน
- ❌ **อย่า defend แบบ aggressive** — committee จะ probe คือต้อง welcome questions

---

## 🎤 Final mantra ก่อนเดินเข้าห้อง

> "ผมเตรียมมาดีแล้ว ผมรู้ทุกตัวเลข ผมรู้ทุกสมการ ผมรู้ scope ของตัวเอง — committee อยากเห็นผมตอบได้อย่างมั่นใจ ไม่ใช่ตอบแบบสมบูรณ์แบบ"

**สู้ๆ Napoleon! 💪 11:00 พบกัน!**
