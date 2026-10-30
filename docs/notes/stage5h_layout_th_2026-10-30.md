# Stage 5h — โมเดลจัดระเบียบสำหรับดูวงจรและนำเสนอ

วันที่ 30 ตุลาคม 2026 (UTC+7) — Codex desktop / GPT-6

ไฟล์ที่จัดแล้ว:
`D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\vsg_stage5h_mosfet_layout.slx`

เป็นสำเนาจากไฟล์ที่บันทึกไว้บนดิสก์ ไม่รวมการแก้ไขที่ยังไม่ได้ Save ใน MATLAB session อื่น และไม่ทับต้นฉบับ:
`D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\vsg_stage5h_mosfet.slx`

## วิธีเปิดและดู

เปิด MATLAB R2018b แล้วใช้:

```matlab
open_system('D:/workspace/engineering/vsg-project/matlab/validation_outputs/stage5h/vsg_stage5h_mosfet_layout.slx');
```

- หน้าแรกแบ่งเป็น 10 หมวด ตั้งแต่ VSG, voltage/current control, inverse Park, electrical plant, measurement และ workspace logging
- Scope สีเขียวอยู่มุมขวาบน: `Scope_gates_6`, `Scope_V_load_abc`, `Scope_i_L_abc`, `Scope_Vds_A_high`
- ดับเบิลคลิก `Gate_Driver_and_MOSFET_Circuit` เพื่อดูวงจรเฟส A/B/C สามแถว จาก PWM/deadtime ทางซ้ายไป MOSFET/filter/load ทางขวา
- กด Run เพื่อจำลอง 3 วินาทีตามค่าที่บันทึกในโมเดล แล้วเปิด Scope ที่ต้องการ
- การทดสอบจัดวางครั้งนี้ใช้ 0.02 วินาทีชั่วคราวผ่าน SimulationInput; ไม่เปลี่ยน StopTime=3 ของไฟล์ที่บันทึก
- คำเตือน initial current ของ Lf_Rf_A และ unused omega_s_const เป็นคำเตือนเดิมของต้นฉบับ

## สิ่งที่เปลี่ยนและหลักฐาน

จัดตำแหน่ง/ขนาด/สี/ตัวอักษรของ block 297 ตัว เพิ่มหัวข้อ และวาดเส้นเชื่อมใหม่จาก terminal sets ของต้นฉบับ แก้ block logging ที่ทับกัน โดยรักษา hierarchy, SID, parameters และการเชื่อมต่อเดิม

ตรวจเทียบ XML พบว่า parameter ของ block และ configuration ตรงกันทุกส่วนที่ตรวจ สัญญาณแบบมีทิศทางและ electrical net sets ตรงกัน และไม่มีกรอบ block ซ้อนกัน ยกเว้นข้อมูลภาพและ default `ScopeSpecificationString` ที่ MATLAB เติมเมื่อเปิดไฟล์ ซึ่งไม่นับเป็นการเปลี่ยนตรรกะ ผู้ตรวจอิสระตรวจ model/system properties และ membership เพิ่มเติมแล้วตรงกัน

รันทั้งต้นฉบับและสำเนาจัดวางช่วง 0–0.02 วินาที: timeseries ทั้ง 23 ชุดมีเวลาและข้อมูลตรงกัน (max absolute difference = 0) เป็น startup regression ไม่ใช่การรันผล 3 วินาทีใหม่

หลักฐาน:

- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\layout_verification_2026-10-30.json`
- `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\layout_smoke_comparison_2026-10-30.json`
- `D:\workspace\engineering\vsg-project\docs\figures\stage5h_layout_overview_2026-10-30.png`
- `D:\workspace\engineering\vsg-project\docs\figures\stage5h_layout_circuit_2026-10-30.png`

ภาพทั้งสองส่งออกโดย MATLAB ด้วย `print -r0` และตรวจด้วยสายตาว่าครบแล้ว; การ export ด้วย `-r120` ในเครื่องนี้เคยแสดง block ไม่ครบ การจับภาพหน้าต่างด้วย computer-use ไม่สำเร็จเพราะ window binding error จึงใช้ภาพ export จาก MATLAB ตรวจแทน

## สร้างการจัดวางซ้ำ

ตัวสร้างโมเดลเดิม `D:\workspace\engineering\vsg-project\matlab\build_stage5h_mosfet.m` ยังสร้าง layout เดิม หากมีการเพิ่ม/ลบ block ต้องปรับแผนจัดวางก่อน ไม่ควรใช้แผนเดิมโดยอัตโนมัติ

แผนจัดวางสร้างโดย `D:\workspace\engineering\vsg-project\python\analysis\plan_stage5h_layout.py` และบันทึกที่ `D:\workspace\engineering\vsg-project\matlab\validation_outputs\stage5h\layout_plan_2026-10-30.json` ใช้ `D:\workspace\engineering\vsg-project\matlab\layout_stage5h_mosfet.m` สร้างสำเนา และใช้ `D:\workspace\engineering\vsg-project\python\analysis\verify_stage5h_layout.py` ตรวจเทียบ

ไฟล์สำรองต้นฉบับมีชื่อ `vsg_stage5h_mosfet.before_layout_*.slx` ในโฟลเดอร์ Stage 5h สำเนา `_layout.slx.backup_*` บางชุดเป็นผลระหว่างจัดวาง ให้ใช้ไฟล์ `_layout.slx` และรายงานล่าสุดสำหรับนำเสนอ
