# คู่มือการออกแบบและตรวจรับฮาร์ดแวร์ VSG

ปรับปรุง 2026-10-20 — ต้นแบบ islanded 40 V DC / 100 W / 50 Hz เอกสารนี้ระบุข้อกำหนดและแผนทดสอบ ยังไม่ใช่หลักฐานว่าฮาร์ดแวร์ผ่านการตรวจรับ คำแนะนำเดิมที่ใช้บัส/ฐาน AC 24 V ถูกแทนที่ด้วยค่าปัจจุบัน

Current design authority: `D:\workspace\engineering\vsg-project\docs\notes\design_baseline.md`.
Independent shutdown circuit and acceptance evidence: `D:\workspace\engineering\vsg-project\docs\notes\hardware_shutdown_and_bench_plan.md`.
Source review: `D:\workspace\engineering\vsg-project\docs\notes\project_review_2026-10-12.md`.

## จุดออกแบบและฐาน per-unit

| รายการ | ค่าปัจจุบัน |
|---|---|
| DC bus | 40 V nominal |
| แรงดันเฟส | 14 V peak; 9.8995 V RMS |
| แรงดันสาย | 17.1464 V RMS line-to-line |
| กำลัง/ความถี่ | 100 W nominal; ฐานวิเคราะห์ 100 VA; 50 Hz |
| ฟิลเตอร์ต่อเฟส | Lf 1.2 mH, Rf 0.05 Ω, Cf 10 µF อนุกรม Rd 1 Ω |
| H / D / Rp / Rq | 5 s / 0.5 / 0.05 / 0.05 |
| PWM / control | เป้าหมาย 10 kHz ต้องวัดจริง |
| ภาคกำลังหลัก | IRF540N + IR2104; ต้องมี independent shutdown |

ที่ 100 VA และ 50 Hz ได้ Ibase = 3.3672 A RMS, Zbase = 2.94 Ω, Lbase = 9.3583 mH และ Cbase = 1082.69 µF ดังนั้น Lf = 0.1282 pu และ Cf = 0.009236 pu การมีสมการลูปนอกเหมือนกันในหน่วย pu ไม่ได้พิสูจน์ว่าการสูญเสีย ความร้อน การสวิตชิ่ง และระบบป้องกันเหมือนระบบกำลังสูงทุกประการ

พจน์ D คูณความคลาดเคลื่อนความถี่หน่วย rad/s ทำให้ effective P-f droop = 1/(20+0.5×2π×50) = 0.005647 pu/pu หรือประมาณ 0.565% แม้ Rp = 0.05 ค่า 5% จึงเป็นพารามิเตอร์ governor ไม่ใช่ความชันรวม

## แหล่งพลังงานและไฟเลี้ยง

เริ่มทดสอบด้วยแหล่งจ่าย DC ปรับค่าและจำกัดกระแสได้ พร้อม auxiliary supply ที่ควบคุมแรงดันแยกต่างหาก ตรวจกราวด์/สายดิน/USB/เครื่องมือก่อนเชื่อมต่อ ไม่อนุมัติ generic LM2596 module ต่อจากบัส nominal 40 V โดยตรง เพราะ recommended input ceiling ไม่เหลือ margin สำหรับแรงดันสูงขึ้น ดู [TI datasheet](https://www.ti.com/lit/ds/symlink/lm2596.pdf)

BESS ยังคงเป็นขอบเขตโครงงาน แต่ chemistry, cell count, BMS, charger, กระแส และวงจรเชื่อมต่อยังไม่ได้ qualify ห้ามนำแบตเตอรี่ 24 V ขนานกับแหล่งจ่าย 40 V และห้ามถือว่า SLA 12 V สามลูกเป็นแหล่งจ่าย regulated 40 V ต้องออกแบบ interface หรือ validate ช่วงแรงดันใหม่ทั้งหมด

แหล่งจ่ายแบบ source-only อาจรับพลังงานย้อนกลับไม่ได้ ต้อง qualify sink/braking path ก่อน load rejection; TVS ไม่ใช่ตัวรับพลังงานต่อเนื่อง ออกแบบ pre-charge, fuse, DC switch และ discharge จากค่าชิ้นส่วนจริง ตรวจแรงดันบัสด้วยมิเตอร์ก่อนสัมผัส ไม่ใช้เวลารอคงที่แทนการวัด

## Independent shutdown

IR2104 เป็น bootstrap แบบ non-isolated มี UVLO และ internal dead-time ตาม [Infineon datasheet](https://www.infineon.com/assets/row/public/documents/24/49/infineon-ir2104-ds-en.pdf) แต่ต้องวัด gate waveform และ dead-time ของวงจรจริง

SD LOW ปิดทั้ง HO และ LO; SD HIGH อนุญาต switching ส่วน IN LOW อย่างเดียวอาจทำให้ LO เปิดอยู่ จึงต้องมีวงจร:

    SD_PERMIT = MCU_REQUEST AND HARDWARE_PERMIT

GPIO22 ส่งเพียง MCU_REQUEST เข้าวงจร AND; HARDWARE_PERMIT มาจาก latch ที่เริ่มต้น disabled และถูก clear แบบ asynchronous จาก comparator fault หรือ supply supervisor จัด external pull-down ให้ MCU_REQUEST และ SD_PERMIT เป็น LOW เมื่อ reset/ไม่มีไฟ Fault ที่หายไปเองหรือปุ่ม ARM ที่กดค้างต้องไม่ทำให้กลับมาสวิตชิ่งโดยอัตโนมัติ ห้ามต่อ GPIO22 ตรงข้ามวงจร latch ไปยัง SD

GPIO34 ใช้รับ fault และ MCPWM F0; เมื่อเป็น open-collector branch ต้องมี external pull-up ไป 3.3 V ห้ามชอร์ตเอาต์พุต comparator เข้ากับ GPIO push-pull ต้องตรวจ logic margin, power sequencing และการดับ logic supply ขณะที่ driver ยังมีไฟ ตามแผน shutdown

Threshold, sensing coverage, blanking และ total trip delay ต้องออกแบบและวัดจากวงจรจริง ไม่อ้าง end-to-end OCP ต่ำกว่า 1 µs จากความเร็ว MCPWM เพียงอย่างเดียว DRV8302 เป็นทางเลือกที่ยังต้องตรวจ schematic และ rating ของโมดูลจริง

## การวัดและลำดับตรวจรับ

ใช้ AD7606 + ACS712-20A ตรวจ RESET, RANGE, OS, serial mode, VDRIVE, ลำดับช่อง และ signed scale ของโมดูลจริง Calibrate offset/gain ก่อนเปิดภาคกำลัง ทดสอบ BUSY stuck HIGH และ stuck LOW แยกกัน

จัด gate loop และ commutation loop ให้สั้น แยกทางกระแส switching ออกจาก measurement return ตรวจฉนวน drain tab เมื่อใช้ heatsink ร่วม ตรวจ inductor saturation/loss และ capacitor ripple rating จากชิ้นส่วนจริง ใช้ differential/isolated probe ที่เหมาะสมวัด HO เทียบ VS; ห้ามคีบกราวด์สโคปที่ต่อ earth ลง switching node

1. ตรวจวงจรขณะไม่มีไฟและ default-off เมื่อ MCU ไม่มีไฟ/reset
2. ใช้ auxiliary supply เท่านั้น ทดสอบ independent fault latch และทั้งสอง gate ปิดโดยไม่พึ่ง CPU
3. วัด dry-run PWM 10 kHz, phase alignment, control worst-case time/missed ticks และ ADC calibration; gate request ต้อง LOW
4. Inject fault ระหว่าง standby/bootstrap/soft-start แล้วตรวจว่า FAULT ไม่ถูกเขียนทับและไม่ restart เอง
5. เมื่อมีหลักฐานผ่านจึงเพิ่มระดับพลังงานทีละขั้น พร้อมบันทึก current limit, load, overshoot และอุณหภูมิ
6. ผลจำลองหลัง load step ประมาณ 136 W เป็น overload เทียบกับ nominal 100 W ต้อง qualify thermal/electrical envelope ก่อนทดลองจริง

การทดสอบ physical ทั้งหมดเป็น PENDING จนมีไฟล์หลักฐาน HIL/bench ยังไม่ถือว่าเสร็จจากการ compile หรือ simulation ราคาในเอกสารเดิมวันที่ 2026-05-30 เป็นเพียง historical estimate

รายงาน simulation validation และขอบเขตผล Stage 5d/5e: `D:\workspace\engineering\vsg-project\docs\notes\simulation_validation_2026-10-13.md`.
รายงานระบุช่องว่าง DC-bus protection: source-current limiting อาจทำให้ bus sag โดยไม่เกิด overcurrent/thermal trip ต้อง qualify undervoltage/overvoltage interlock หรือออกแบบ sensing/protection เพิ่มก่อนใช้งานจริง โดยไม่เดา threshold หรือ ADC scale จาก study assumptions
