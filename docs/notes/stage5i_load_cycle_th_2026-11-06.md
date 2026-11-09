# Stage 5i — ทดสอบเพิ่มและลดโหลด: P, f, Vrms, Irms

วันที่ 6 พฤศจิกายน 2026 (UTC+7) — Codex desktop / GPT-6

รันจริงครบ 11 s โดยเปิด Secondary สั่งเพิ่มโหลดที่ 3 s และลดกลับที่ 7 s ระบบกลับสู่จุดทำงานเดิมได้ แต่พบแรงดัน RMS ยุบและเกินชัดเจนช่วงเปลี่ยนโหลด จึงไม่ควรใช้ผลนี้สรุปว่าคุณภาพแรงดันช่วง transient ผ่านแล้ว

## กราฟและไฟล์ใช้งาน

- ภาพรวม: `D:\workspace\engineering\vsg-project\docs\figures\stage5i_load_cycle_nominal_2026-11-06.png`
- ภาพซูม RMS: `D:\workspace\engineering\vsg-project\docs\figures\stage5i_load_cycle_rms_zoom_nominal_2026-11-06.png`
- โมเดล: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i_load_cycle\vsg_stage5i_load_cycle.slx`
- ผลวัด: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i_load_cycle\results_nominal.mat`
- CSV กราฟ: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i_load_cycle\curves_nominal.csv`

## เงื่อนไขและนิยาม

- MATLAB R2018b; SPS MOSFET 6 ตัว; DC40 V; V_set14 V peak ต่อเฟส; solver MaxStep2.5 us
- R โหลดต่อเฟสประมาณ2.94 →2.059 →2.94 ohm (ค่า2.059รวมผล bypass Ron); Lโหลด1 mH; วงจรLCและprimary/secondaryเดิมไม่เปลี่ยน
- เส้นแนวตั้ง3และ7sเป็นเวลาคำสั่งbreaker ไม่ได้อ้างว่าทั้งสามเฟสตัดกระแสพร้อมกันพอดี โดยเฉพาะbreaker opening
- P ในกราฟเป็นกำลังจริงรวมสามเฟสที่ขั้วโหลด: sum(v_phase*i_load_phase), เฉลี่ยหน้าต่างย้อนหลัง20 ms
- เส้นประ P_ref เป็นคำสั่งกำลังบนฐาน100 W; P_meas เดิมของตัวควบคุมใช้กระแสiL จึงต่างจาก P ที่โหลดได้รับ
- f เป็นomega/(2*pi)ของvirtual rotorภายใน ยังไม่ได้วัดความถี่จากแรงดันขาออกด้วยestimatorอิสระ
- Vrms เป็นแรงดันเฟสต่อนิวทรัลลอยที่โหลดหลังLC; Irms เป็นกระแสแขนโหลด ไม่ใช่กระแสตัวเหนี่ยวนำfilter
- บันทึกV/Iทุก5 us (200kHz); คำนวณผลคูณ/กำลังสองจากpiecewise-linear samplesแล้วอินทิเกรตตามเวลา ใช้หน้าต่างย้อนหลัง20msคงที่ตามคาบพิกัด50Hz กราฟเริ่มที่20msซึ่งเป็นหน้าต่างแรกที่ครบ
- กราฟแสดงทุก1ms; ค่าสูงสุด/ต่ำสุดของRMSที่รายงานเป็นค่าบนกริดนี้ ไม่ใช่instantaneous voltage peak

## ค่าช่วงท้ายของแต่ละสถานะ

P/fเป็นค่าเฉลี่ยตามเวลา; RMSในตารางคำนวณตลอดหน้าต่าง0.4sโดยตรง

| สถานะ | หน้าต่าง (s) | Pโหลด (W) | fภายใน (Hz) | Vrms A/B/C (V) | Irms A/B/C (A) |
|---|---|---:|---:|---|---|
| ก่อนเพิ่มโหลด | 2.6–3.0 | 96.812663 | 50.000436 | 9.796147/9.796714/9.796972 | 3.312925/3.313116/3.313199 |
| โหลดสูง | 6.6–7.0 | 135.224888 | 49.998270 | 9.745523/9.746180/9.746369 | 4.678624/4.678900/4.679023 |
| หลังลดโหลดกลับ | 10.6–11.0 | 96.812632 | 50.001658 | 9.796629/9.796299/9.796914 | 3.313090/3.312978/3.313169 |

## สิ่งที่พบช่วงเปลี่ยนโหลด

- เพิ่มโหลด: Vrmsต่ำสุดA/B/C = 7.218751 / 7.187008 / 7.154213 V ที่ปลายหน้าต่างRMSประมาณ3.020–3.021s
- ลดโหลด: VrmsสูงสุดA/B/C = 13.306272 / 13.451616 / 13.176102 V ที่ปลายหน้าต่างRMSประมาณ7.023–7.030s
- เพิ่มโหลด: fต่ำสุด49.915930 Hz; กลับเข้าช่วง50±0.005Hzตั้งแต่5.9179sจนถึงเหตุการณ์ถัดไป (หลังสั่งเพิ่ม2.9179s)
- ลดโหลด: fสูงสุด50.089475 Hz; กลับเข้าช่วง50±0.005Hzตั้งแต่9.8812sจนจบ11s (หลังสั่งลด2.8812s)
- จึงแสดงการกลับสู่สมดุลและsecondary restorationทั้งสองทิศได้ในกรณีนี้ แต่แรงดันช่วงเปลี่ยนโหลดเป็นประเด็นที่ต้องตรวจวงแรงดัน/กระแสและผลของLCต่อ ไม่ได้ปรับgainเพื่อกลบผลการทดสอบ
- ช่วงโหลดสูงรับกำลังจริงประมาณ135.22W ซึ่งสูงกว่าเป้าหมายhardware100W; เป็นsimulation stress case ไม่ใช่พิกัดhardwareที่พิสูจน์แล้ว

## การตรวจผลและข้อจำกัด

- โครงสร้างยืนยัน338blockเดิมและวงจรกำลังเดิม; เพิ่มเฉพาะคำสั่งลดโหลด/รวมคำสั่ง/log และปรับlogging
- execution_passหมายถึงข้อมูลครบ finite และคำสั่งโหลดตรงเวลา ไม่ได้หมายถึงผ่านข้อกำหนดแรงดันtransient
- `independent_checks_nominal.json`: ตรวจRMS/Pด้วยวิธีuniform reconstruction2usอิสระ, การเปลี่ยนP/I, จุดทำงานหลังลดกลับ และค่าเฉลี่ยความถี่ ผ่าน9ข้อ
- `transient_rms_verification.json`: ตรวจRMSที่จุดยุบ/เกินทั้ง6จุดอิสระ ต่างจากกราฟไม่เกิน0.000017V จึงไม่ใช่ความผิดพลาดในการคำนวณกราฟ
- `logging_resolution_check.json`: เทียบlogging5usกับข้อมูลStage5iเดิมที่ละเอียดกว่าในช่วงเพิ่มโหลดและsteady state; Vrmsต่างสูงสุด0.0001293V, Pเฉลี่ยต่างสูงสุด0.001608W ข้อนี้ไม่ใช่การรันsolver refinementเต็มรอบload-cycleใหม่
- ไม่ได้รันhalved-MaxStepครบ11sสำหรับกรณีใหม่นี้ และไม่ได้ตรวจthermal/EMI/hardware
- การรันเต็มครั้งแรกเกิดmemory allocation errorและไม่มีผลครบ เก็บlogล้มเหลวไว้ แล้วรันใหม่โดยเก็บV/Iแบบ200kHz, ตัดrawgate/DCpulse logging และปิดtime/outputloggingที่ไม่ใช้ ผลสำเร็จอยู่ในrun_bounded_retry_20261106.log
- จึงไม่อ้างผลgate overlap/deadtimeใหม่สำหรับรอบนี้ แม้วงgateเดิมจะผ่านการตรวจในStage5iก่อนหน้า

## เปิดกราฟซูมใน MATLAB โดยไม่รันใหม่

```matlab
addpath('D:/workspace/engineering/vsg-project/matlab');
show_stage5i_load_cycle('nominal');
```

ไฟล์Figureที่บันทึกไว้: `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5i_load_cycle\stage5i_load_cycle_nominal.fig`

## รันเอง

เปิดโมเดลload-cycleแล้วกดRun (StopTime11s) ได้โดยตรง; ข้อมูลรอบRunอยู่ในSimulationOutput/out แต่PNG/CSV/Figureที่ส่งนี้เป็นผลnominalที่บันทึกไว้ ไม่อัปเดตอัตโนมัติจากปุ่มRun

หากต้องการสร้างผลใหม่พร้อมบันทึกเป็นไฟล์ ให้ปิดเฉพาะโมเดลload-cycleก่อนใช้runner (runnerสร้างสำเนาจากStage5iและสำรองไฟล์เดิม):

```matlab
addpath('D:/workspace/engineering/vsg-project/matlab');
report = run_stage5i_load_cycle(2.5e-6,'manual',11);
```

แล้วคำนวณกราฟจากผลmanualในPowerShell:

```powershell
python D:\workspace\engineering\vsg-project\python\analysis\plot_stage5i_load_cycle.py --label manual
python D:\workspace\engineering\vsg-project\python\analysis\check_stage5i_load_cycle.py --label manual
```

จากนั้นเปิดในMATLABด้วย `show_stage5i_load_cycle('manual')`.

ไฟล์ต้นทางStage5iและfirmwareไม่ได้แก้ไข ไม่ได้flashหรือทดสอบวงจรจริง ข้อมูลทุกไฟล์ของการทดลองนี้อยู่ไดรฟ์D
