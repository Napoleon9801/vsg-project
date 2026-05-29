"""
Rewrite Chapter 2 of 66AOS02-แก้.docx.

Strategy:
1. Locate Heading-1 paragraph "บทที่ 2" and "บทที่ 3" by text.
2. Delete every element (paragraph + table) BETWEEN them (exclusive).
3. Insert new structured content before "บทที่ 3".

Content is defined as a list of operations:
  ('P', style, text)        — a paragraph with the given Word style
  ('T', rows_list_of_lists) — a Word table built from a 2-D Thai/English list

Equation paragraphs are styled 'Normal' but indented with leading spaces.
"""
from __future__ import annotations

import sys
from copy import deepcopy
from docx import Document
from docx.oxml.ns import qn
from docx.shared import Pt

sys.stdout.reconfigure(encoding="utf-8")

DOCX = r"D:\workspace\engineering\vsg-project\docs\thesis\66AOS02-แก้.docx"

# ============================================================================
# CONTENT — Chapter 2 in structured form
# ============================================================================

# Reusable tables ----------------------------------------------------------
GFL_VS_GFM_TABLE = [
    ["คุณสมบัติ", "GFL (Grid-Following)", "GFM (Grid-Forming)"],
    ["พฤติกรรมทางไฟฟ้า", "Current Source", "Voltage Source"],
    ["การ sync กับกริด", "ใช้ PLL", "กำหนดมุม/ความถี่เอง"],
    ["ความต้องการกริด", "ต้องการ stiff grid", "ทำงานได้ใน weak/islanded grid"],
    ["การจ่าย Inertia", "ไม่มี", "มี (Virtual Inertia)"],
    ["ความสามารถ Black-start", "ไม่ได้", "ได้"],
    ["ความซับซ้อนของการควบคุม", "ต่ำ", "สูงกว่า"],
    ["การใช้งานปัจจุบัน", "Solar PV, Wind ทั่วไป", "Microgrid, BESS, VSG"],
    ["มาตรฐานที่เกี่ยวข้อง", "IEEE 1547 (เดิม)", "IEEE 1547-2018, IEEE 2988"],
]

VSG_COMPARISON_TABLE = [
    ["แนวทาง", "ผู้เสนอ (ปี)", "ความซับซ้อนการคำนวณ", "จุดเด่น", "จุดด้อย"],
    ["VISMA", "Beck & Hesse (2007)", "สูงมาก (full-order SG)",
     "พลวัตใกล้ SG จริงที่สุด", "ต้อง DSP ระดับสูง, sensor แม่นยำ"],
    ["Synchronverter", "Zhong & Weiss (2011)", "ปานกลาง (2nd-order)",
     "self-synchronize, ไม่ต้อง PLL", "อ่อนไหวต่อ parameter mismatch"],
    ["Droop-based VSG", "De Brabandere (2007)", "ต่ำ",
     "implement ง่าย, เสถียร wide-range", "inertia เป็น 1st-order เท่านั้น"],
    ["Adaptive VSG", "Alipoor (2015)", "สูง (parameter scheduling)",
     "รองรับ disturbance ขนาดใหญ่", "ต้องการ tuning algorithm เพิ่ม"],
]


# ============================================================================
# OPERATIONS (in order)
# Each tuple: ('P', style, text)  OR  ('T', rows)
# Empty paragraphs are useful as visual separators
# ============================================================================
OPS: list = []
P  = lambda style, text: OPS.append(('P', style, text))
T  = lambda rows: OPS.append(('T', rows))
EQ = lambda text: OPS.append(('P', 'Normal', "    " + text))  # equation: indented Normal
BR = lambda: OPS.append(('P', 'Normal', ""))

# ---- Intro paragraph ----
P('Normal',
  "\tบทนี้นำเสนอทฤษฎีและงานวิจัยที่จำเป็นต่อการพัฒนาเครื่องกำเนิดไฟฟ้าซิงโครนัสเสมือน "
  "(Virtual Synchronous Generator: VSG) สำหรับควบคุมอินเวอร์เตอร์ 3 เฟส บนระบบกักเก็บพลังงานด้วยแบตเตอรี่ "
  "(Battery Energy Storage System: BESS) เนื้อหาแบ่งเป็นเจ็ดส่วน ได้แก่ (1) แนวคิดอินเวอร์เตอร์แบบ "
  "Grid-Following และ Grid-Forming (2) ทฤษฎีพื้นฐานของเครื่องกำเนิดไฟฟ้าซิงโครนัส (Synchronous Generator: SG) "
  "ซึ่งเป็นต้นแบบของ VSG (3) สถาปัตยกรรมการควบคุม VSG ในระดับอัลกอริทึม (4) ทฤษฎีไฟฟ้ากำลังสำหรับการนำ VSG "
  "ไปใช้งานจริง ครอบคลุมการแปลงพิกัด การมอดูเลต การออกแบบวงจรกรอง และการคำนวณขนาด BESS "
  "(5) งานวิจัยที่เกี่ยวข้อง (6) มาตรฐานและข้อกำหนดทางกริด และ (7) สรุปและช่องว่างทางวิชาการที่โครงงานนี้ต้องการเติมเต็ม")

# ============================================================================
# 2.1 GFL vs GFM
# ============================================================================
P('Heading 2', "2.1 อินเวอร์เตอร์แบบ Grid-Following (GFL) และ Grid-Forming (GFM)")
P('Heading 3', "2.1.1 อินเวอร์เตอร์แบบ Grid-Following (GFL)")
P('Normal',
  "\tอินเวอร์เตอร์แบบ Grid-Following ทำงานในลักษณะ \"ตามกริด\" โดยใช้ Phase-Locked Loop (PLL) "
  "ในการตรวจจับมุมเฟสและความถี่ของแรงดันกริด แล้วฉีดกระแสเข้าสู่ระบบตามมุมที่ตรวจจับได้ "
  "พฤติกรรมโดยรวมของ GFL เปรียบเสมือนแหล่งจ่ายกระแส (Current Source) ที่ต้องอาศัยกริดที่แข็งแรง (stiff grid) "
  "จึงจะสามารถทำงานได้อย่างเสถียร")
P('Normal',
  "\tGFL เป็นรูปแบบที่ใช้กันอย่างแพร่หลายในระบบ Solar PV inverter และ Wind turbine inverter ในปัจจุบัน "
  "เนื่องจากออกแบบและควบคุมได้ง่าย ต้นทุนต่ำ แต่มีข้อจำกัดสำคัญคือ (i) ไม่สามารถจ่ายความเฉื่อย (inertia) "
  "ให้กับระบบได้ และ (ii) ไม่สามารถทำงานในโหมด Stand-alone (Islanded) ได้ "
  "ส่งผลให้ระบบที่มีสัดส่วน GFL สูงมีแนวโน้มเกิดความไม่เสถียรของความถี่และแรงดันเมื่อกริดอ่อนแอ")

P('Heading 3', "2.1.2 อินเวอร์เตอร์แบบ Grid-Forming (GFM)")
P('Normal',
  "\tอินเวอร์เตอร์แบบ Grid-Forming ทำงานในลักษณะ \"สร้างกริด\" โดยกำหนดแรงดันและความถี่อ้างอิงเอง "
  "พฤติกรรมโดยรวมของ GFM เปรียบเสมือนแหล่งจ่ายแรงดัน (Voltage Source) ที่อยู่หลังอิมพีแดนซ์ของแหล่งจ่าย "
  "(Source impedance) ทำให้สามารถทำงานได้ทั้งในโหมด grid-connected และ stand-alone")
P('Normal',
  "\tGFM สามารถจ่ายความเฉื่อยเสมือน (Virtual Inertia) ให้แก่ระบบไฟฟ้าได้ "
  "ช่วยลด Rate of Change of Frequency (RoCoF) ในช่วง disturbance "
  "และช่วยพยุงเสถียรภาพของระบบไฟฟ้าที่มีสัดส่วน Renewable Energy สูง "
  "VSG จัดเป็นรูปแบบของ GFM ที่อาศัยการเลียนแบบพลวัตของ SG ในซอฟต์แวร์ "
  "ทำให้คุณสมบัติทั้ง inertia provision และ damping ของ SG ปรากฏในอินเวอร์เตอร์โดยไม่ต้องอาศัยมวลหมุนจริง")

P('Heading 3', "2.1.3 ตารางเปรียบเทียบ GFL กับ GFM")
P('Normal',
  "\tตารางที่ 2.1 สรุปคุณสมบัติเชิงเปรียบเทียบระหว่าง GFL และ GFM "
  "ที่ต้องนำมาพิจารณาก่อนเลือกสถาปัตยกรรมการควบคุม")
T(GFL_VS_GFM_TABLE)

# ============================================================================
# 2.2 SG Fundamentals
# ============================================================================
P('Heading 2', "2.2 ทฤษฎีพื้นฐานของเครื่องกำเนิดไฟฟ้าซิงโครนัส (Synchronous Generator Fundamentals)")
P('Normal',
  "\tการออกแบบ VSG อาศัยการเลียนแบบพฤติกรรมเชิงพลวัตของเครื่องกำเนิดไฟฟ้าซิงโครนัส (SG) "
  "ดังนั้นความเข้าใจในทฤษฎีพื้นฐานของ SG จึงเป็นรากฐานสำคัญในการพัฒนา VSG ที่มีประสิทธิภาพ "
  "หัวข้อย่อยต่อไปนี้นำเสนอ Swing Equation ซึ่งเป็นสมการแกนกลาง ความเฉื่อย การหน่วง "
  "และการควบคุมแบบ Droop ที่ใช้แบ่งโหลด")

P('Heading 3', "2.2.1 สมการ Swing Equation")
P('Normal',
  "\tสมการ Swing Equation อธิบายพลวัตเชิงกลของโรเตอร์ในเครื่องกำเนิดไฟฟ้าซิงโครนัส "
  "โดยอาศัยกฎข้อที่สองของนิวตันสำหรับการหมุน เขียนในรูป per-unit ได้ดังสมการ (2.1)")
EQ("2H · (dω/dt) = P_m − P_e − D · Δω                          ... (2.1)")
P('Normal', "โดยที่")
P('Normal', "H   คือ ค่าคงที่ความเฉื่อย (Inertia constant) มีหน่วยเป็นวินาที (s) นิยามจาก H = (½ J ω₀²) / S_base")
P('Normal', "Δω  คือ ค่าเบี่ยงเบนของความเร็วเชิงมุม Δω = ω − ω₀ (rad/s หรือ pu)")
P('Normal', "P_m คือ กำลังกลที่จ่ายเข้าโรเตอร์ (Mechanical power)")
P('Normal', "P_e คือ กำลังไฟฟ้าที่จ่ายออกจากสเตเตอร์ (Electrical power)")
P('Normal', "D   คือ สัมประสิทธิ์การหน่วง (Damping coefficient) มีหน่วย pu/pu")
P('Normal',
  "\tการ integrate ω จะได้มุม θ = ∫ ω dt ซึ่ง SG ใช้เป็นมุมของแรงดันด้านสเตเตอร์ "
  "และเป็นเป้าหมายให้ VSG จำลองพฤติกรรมเดียวกันในซอฟต์แวร์")

P('Heading 3', "2.2.2 ความเฉื่อย (Inertia)")
P('Normal',
  "\tความเฉื่อยของเครื่องกำเนิดเกิดจากมวลที่หมุนของโรเตอร์ ค่า H สะท้อนถึงพลังงานจลน์ที่สะสมในโรเตอร์เทียบกับกำลังพิกัด "
  "ความเฉื่อยขนาดใหญ่ทำให้ระบบมีความสามารถในการต้านทานต่อการเปลี่ยนแปลงความถี่ (low RoCoF) ในช่วง disturbance")
P('Normal',
  "\tในระบบไฟฟ้าแบบดั้งเดิมที่ใช้ SG เป็นแหล่งจ่ายหลัก ค่า H รวมของระบบมักอยู่ในช่วง 2–6 วินาที "
  "(เครื่องประเภท turbo-generator มีค่า H ประมาณ 3 s ส่วน hydro generator มีค่า H ประมาณ 5 s) "
  "แต่ในระบบที่มีการเชื่อมต่ออินเวอร์เตอร์แบบ GFL ในสัดส่วนสูง ค่า H ของระบบจะลดลงต่ำกว่า 1 วินาทีในบางช่วง "
  "ส่งผลให้ความถี่มีโอกาสเปลี่ยนแปลงรวดเร็วและเสี่ยงต่อ frequency instability "
  "ปรากฏการณ์นี้ถูกเรียกในวรรณกรรมว่า \"low-inertia problem\" และเป็นแรงผลักดันสำคัญของการพัฒนา VSG")

P('Heading 3', "2.2.3 การหน่วง (Damping)")
P('Normal',
  "\tการหน่วงของ SG เกิดจากการเหนี่ยวนำใน damper winding (ขดลวดกรงกระรอกบนโรเตอร์) และการสูญเสียในแกนเหล็ก "
  "สัมประสิทธิ์การหน่วง D ทำหน้าที่ลด oscillation ของความถี่หลังเกิด disturbance "
  "หากระบบมีค่า D ต่ำเกินไป frequency response จะ oscillate นาน "
  "หากสูงเกินไปจะทำให้ steady-state load sharing ระหว่างเครื่องกำเนิดหลายเครื่องคลาดเคลื่อน "
  "การเลือกค่า D จึงเป็นการประนีประนอม (trade-off) ระหว่าง transient damping กับ steady-state accuracy")

P('Heading 3', "2.2.4 Droop Control ใน SG")
P('Normal',
  "\tระบบควบคุมของ SG ใช้ Droop control เพื่อแบ่งโหลดระหว่างเครื่องกำเนิดหลายเครื่องที่ทำงานขนานกัน "
  "โดยอาศัยลักษณะ P-f และ Q-V droop ดังสมการ (2.2) และ (2.3)")
EQ("f − f₀ = − k_p · (P − P₀)                                  ... (2.2)")
EQ("V − V₀ = − k_q · (Q − Q₀)                                  ... (2.3)")
P('Normal',
  "\tโดย k_p และ k_q เป็น droop gain ที่กำหนดอัตราการลดความถี่และแรงดันเมื่อโหลดเพิ่มขึ้น "
  "ค่าทั่วไปอยู่ในช่วง 3–5 % สำหรับ P-f droop และ 2–10 % สำหรับ Q-V droop ตามมาตรฐานกริดของแต่ละประเทศ "
  "VSG จะจำลองลักษณะ droop เหล่านี้ในซอฟต์แวร์ของอินเวอร์เตอร์ดังที่จะอธิบายในหัวข้อ 2.3")

# ============================================================================
# 2.3 VSG Control Architecture
# ============================================================================
P('Heading 2', "2.3 สถาปัตยกรรมการควบคุม Virtual Synchronous Generator (VSG Control Architecture)")
P('Normal',
  "\tVSG เป็นการนำสมการ Swing Equation และ Droop control มาประยุกต์ใช้ในซอฟต์แวร์ของอินเวอร์เตอร์ "
  "โครงสร้างทั่วไปประกอบด้วยสี่ชั้นการควบคุมที่ทำงานต่อเนื่องกัน ได้แก่ Power Calculation, VSG Core, "
  "Inner Loop และ Modulator")

P('Heading 3', "2.3.1 โครงสร้างการควบคุมโดยรวม")
P('Normal', "\tโครงสร้างการควบคุม VSG ทำงานแบบ cascaded ตามลำดับการส่งสัญญาณดังนี้")
P('List Paragraph', "Power Calculation — คำนวณ P และ Q จากแรงดันและกระแสที่จุดเชื่อมต่อ (PCC) โดยใช้ผลคูณในกรอบ dq หลังการแปลงพิกัด")
P('List Paragraph', "VSG Core (Virtual Swing Equation) — ประกอบด้วย P-ω loop (inertia + damping) และ Q-V loop (droop / excitation) ทำหน้าที่กำหนดมุมและขนาดของแรงดันอ้างอิง")
P('List Paragraph', "Voltage / Current Inner Loop — Cascaded PI controller ในกรอบ dq พร้อม decoupling feedforward")
P('List Paragraph', "PWM / SVPWM Modulator — สร้างสัญญาณสวิตชิงให้กับ power stage ที่ความถี่ 5–20 kHz ตามชนิดอุปกรณ์ที่เลือก")

P('Heading 3', "2.3.2 P-ω Loop: ลูปกำลังจริง–ความถี่")
P('Normal',
  "\tหัวใจของ VSG คือการ implement Swing Equation เป็นสมการเชิงอนุพันธ์ที่อินเวอร์เตอร์แก้แบบ real-time "
  "ดังสมการ (2.4) ซึ่งเป็นรูปแบบพื้นฐาน และสมการ (2.5) ซึ่งรวม droop term เข้ามาด้วย")
EQ("2H · (dω/dt) = P_ref − P_meas − D · (ω − ω_g)              ... (2.4)")
EQ("2H · (dω/dt) = P_ref + k_p·(ω_g − ω) − P_meas − D·(ω − ω_g)   ... (2.5)")
P('Normal', "โดยที่")
P('Normal', "H   คือ Virtual inertia constant (s)")
P('Normal', "D   คือ Virtual damping coefficient (pu/pu)")
P('Normal', "k_p คือ Active power droop gain (pu)")
P('Normal', "ω_g คือ Grid frequency reference (จาก PLL หรือ low-bandwidth tracking)")
P('Normal',
  "\tเมื่อ integrate ω จะได้มุมแรงดันอ้างอิง θ = ∫ ω dt "
  "ซึ่งใช้สร้าง voltage reference E∠θ สำหรับ inner loop")
P('Normal',
  "\tหมายเหตุทางการออกแบบ: การเลือกค่า H และ D ต้องสมดุล H สูงให้ frequency stability ดี "
  "แต่ทำให้ response ช้าและกินพลังงานจาก DC-link มาก ส่วน D สูงลด oscillation แต่เพิ่ม steady-state error "
  "ในการแบ่งโหลด งานวิจัย Adaptive VSG (Alipoor et al., 2015) เสนอให้ H และ D ปรับเปลี่ยนตามสภาวะ disturbance "
  "โครงงานนี้ใช้ค่าคงที่ H = 5, D = 0.5 ที่ได้จากการ sensitivity sweep ในระยะที่ 5 ของการจำลอง "
  "ซึ่งจะอธิบายในบทที่ 4")

P('Heading 3', "2.3.3 Q-V Loop: ลูปกำลังรีแอกทีฟ–แรงดัน")
P('Normal',
  "\tสำหรับการควบคุม Reactive Power และ Voltage VSG ส่วนใหญ่ใช้ Droop "
  "หรือ first-order dynamic ที่จำลอง excitation system ของ SG")
EQ("K · (dE/dt) = Q_ref − Q_meas − D_q · (E − E_ref)           ... (2.6)")
EQ("หรือรูป Droop:   E − E₀ = − k_q · (Q − Q₀)                 ... (2.7)")
P('Normal',
  "\tโดย K คือ virtual excitation inertia และ D_q คือ virtual voltage damping "
  "ทำให้แรงดันออกของอินเวอร์เตอร์มีพลวัตคล้ายกับ field winding ของ SG จริง "
  "โครงงานนี้เลือกใช้รูปแบบ Droop ตามสมการ (2.7) เนื่องจากความเรียบง่ายและเสถียรกว่า "
  "ในการทำงานในโหมด islanded ที่ Q-V coupling ไม่แข็งแรงเท่าโหมด grid-connected")

P('Heading 3', "2.3.4 การจำลองความเฉื่อยและการหน่วงเสมือน")
P('Normal',
  "\tVirtual Inertia มาจากเทอม 2H · (dω/dt) ในสมการ (2.4)–(2.5) "
  "อินเวอร์เตอร์ดึงพลังงานจาก DC-link หรือ energy storage "
  "เพื่อจ่าย transient power ตามอัตราที่ Swing Equation กำหนด "
  "ดังนั้น VSG จึงต้องการแหล่งพลังงานสำรอง (BESS, supercapacitor หรือ over-rated DC bus capacitance) "
  "เพื่อรองรับ inertial transient รายละเอียดการคำนวณขนาด BESS จะกล่าวในหัวข้อ 2.4.5")
P('Normal',
  "\tVirtual Damping มาจากเทอม D · (ω − ω_g) ซึ่งสังเคราะห์ขึ้นจากการคำนวณในซอฟต์แวร์ "
  "ไม่ต้องการ energy reservoir เพิ่มเติม เนื่องจากเป็นเพียงการปรับลด P_ref ตาม Δω แบบ proportional")

# ============================================================================
# 2.4 NEW — Power Electronics for VSG
# ============================================================================
P('Heading 2', "2.4 ทฤษฎีไฟฟ้ากำลังสำหรับการนำ VSG ไปใช้งาน (Power Electronics for VSG Implementation)")
P('Normal',
  "\tหัวข้อ 2.3 อธิบายอัลกอริทึม VSG ในระดับนามธรรม การนำไปใช้งานจริงในวงจรอินเวอร์เตอร์ 3 เฟส "
  "ต้องอาศัยการแปลงพิกัดอ้างอิง การมอดูเลตสัญญาณสวิตชิ่ง การออกแบบวงจรกรอง และการกำหนดขนาดแหล่งจ่ายฝั่ง DC "
  "หัวข้อย่อยต่อไปนี้ครอบคลุมทฤษฎีพื้นฐานของแต่ละองค์ประกอบที่โครงงานนี้นำไปใช้ในระยะการจำลองและฮาร์ดแวร์")

P('Heading 3', "2.4.1 การแปลงพิกัดอ้างอิง: Clarke และ Park Transforms")
P('Normal',
  "\tระบบ 3 เฟส abc แทนสัญญาณด้วยเวกเตอร์สามมิติที่ขึ้นกับเวลา "
  "การควบคุมในกรอบนี้โดยตรงทำได้ยากเพราะตัวแปรเปลี่ยนแปลงตามไซน์ตลอดเวลา "
  "การแปลงพิกัดจึงถูกนำมาใช้เพื่อให้ตัวแปรกลายเป็นค่าคงที่ในสภาวะคงตัว ทำให้ใช้ตัวควบคุม PI แบบมาตรฐานได้")
P('Normal',
  "\tClarke Transform (abc → αβ) เป็นการแปลงสามเฟสที่สมมาตรให้อยู่ในกรอบสองแกนคงที่ "
  "(Stationary Reference Frame) ในรูปแบบ amplitude-invariant ดังสมการ (2.8)")
EQ("v_α = (2/3) · (v_a − v_b/2 − v_c/2)                        ... (2.8a)")
EQ("v_β = (2/3) · ( (√3/2)·v_b − (√3/2)·v_c )                  ... (2.8b)")
P('Normal',
  "\tPark Transform (αβ → dq) หมุนกรอบ αβ ด้วยมุม θ ที่ติดตามกริด "
  "ทำให้สัญญาณ AC ความถี่หลักกลายเป็น DC ในกรอบ dq ดังสมการ (2.9)")
EQ("v_d =  v_α · cos θ + v_β · sin θ                           ... (2.9a)")
EQ("v_q = −v_α · sin θ + v_β · cos θ                           ... (2.9b)")
P('Normal',
  "\tการควบคุมในกรอบ dq มีข้อดีสำคัญสามประการ คือ (i) PI controller มี zero steady-state error สำหรับสัญญาณ DC "
  "(ii) สามารถ decouple การควบคุม active power กับ reactive power ได้ผ่านองค์ประกอบ d และ q ตามลำดับ "
  "และ (iii) ลด computational load เพราะตัวแปรเปลี่ยนแปลงช้า "
  "ทำให้สามารถใช้ ESP32 ซึ่งมี clock 240 MHz รันลูปที่ 10 kHz ได้")
P('Normal',
  "\tในการคำนวณกำลังจริงและกำลังรีแอกทีฟในกรอบ dq รูปแบบ amplitude-invariant ใช้สมการ "
  "P = (3/2) · (v_d · i_d + v_q · i_q) และ Q = (3/2) · (v_d · i_q − v_q · i_d) "
  "ตัวประกอบ 3/2 เป็นผลจาก amplitude-invariant scaling "
  "ซึ่งต้องระวังในการตั้ง R_load ของแบบจำลองเพื่อให้ได้ P รวมตามต้องการ")

P('Heading 3', "2.4.2 อินเวอร์เตอร์ 3 เฟส 2-Level และ Sinusoidal PWM")
P('Normal',
  "\tโครงงานนี้ใช้อินเวอร์เตอร์ 3 เฟส 2-Level (Two-Level Voltage Source Inverter: VSI) "
  "ที่ประกอบด้วย MOSFET 6 ตัวต่อในรูปแบบ Three-Phase Bridge "
  "แต่ละขาเฟส (leg) ประกอบด้วย MOSFET คู่บน-ล่างที่ทำงานสลับกันแบบ complementary "
  "โดยมี dead-time ป้องกัน shoot-through")
P('Normal',
  "\tการมอดูเลตใช้ Sinusoidal PWM (SPWM) ซึ่งเปรียบเทียบสัญญาณอ้างอิงไซน์ (modulating signal) "
  "กับคลื่นสามเหลี่ยม (carrier) ที่ความถี่ f_sw = 10 kHz "
  "ผลที่ได้คือสัญญาณ PWM ที่มีดิวตี้ไซเคิลเฉลี่ยเป็นไปตามสัญญาณอ้างอิง "
  "ค่าแรงดันเอาต์พุตเฟสต่อกึ่งกลาง (phase-to-midpoint) เฉลี่ยใน 1 รอบสวิตช์เท่ากับ "
  "V_inv = (V_dc/2) · sign(V_ref − V_carrier) "
  "เมื่อ V_ref คือสัญญาณอ้างอิงที่ส่งจาก inner loop")
P('Normal', "\tดัชนีการมอดูเลต (Modulation Index) นิยามดังสมการ (2.10)")
EQ("m_a = V_ref_peak / (V_dc / 2)                              ... (2.10)")
P('Normal',
  "\tในย่าน linear (m_a ≤ 1) แรงดันเอาต์พุตที่ความถี่หลักจะเป็นสัดส่วนตรงกับ V_ref โดยไม่มีฮาร์มอนิกเพิ่ม "
  "หาก m_a > 1 จะเกิด overmodulation ที่ทำให้เอาต์พุตถูก clip "
  "และเกิดฮาร์มอนิกอันดับต่ำ (5th, 7th, ...) "
  "ซึ่งทำให้คุณภาพไฟฟ้าเสื่อมลงอย่างมีนัยสำคัญ")
P('Normal',
  "\tข้อกำหนดนี้เป็นเหตุผลที่โครงงานเลือกระดับแรงดัน DC bus เท่ากับ 48 V (จากเดิมที่วางแผนไว้ 24 V) "
  "เนื่องจาก V_d เป้าหมายที่ 14 V peak ต้องการ V_dc/2 ≥ 14 V กล่าวคือ V_dc ≥ 28 V "
  "การเลือก V_dc = 48 V จึงให้ m_a ≈ 0.58 ซึ่งอยู่ในย่าน linear อย่างปลอดภัย "
  "ระดับนี้ยังเป็น contingency option ที่ได้ระบุไว้ในข้อเสนอโครงงานตั้งแต่ต้น")

P('Heading 3', "2.4.3 วงจรกรอง LCL และการหน่วงแบบพาสซีฟ")
P('Normal',
  "\tเอาต์พุตของอินเวอร์เตอร์ SPWM มีฮาร์มอนิกความถี่สูงที่ f_sw และ multiples ของ f_sw "
  "ที่ต้องกรองออกก่อนจ่ายให้โหลด วงจรกรองที่นิยมใช้คือ LCL filter "
  "ซึ่งให้ attenuation 60 dB/decade เหนือความถี่ resonance "
  "เทียบกับ L filter ที่ให้เพียง 20 dB/decade")
P('Normal',
  "\tอย่างไรก็ตามในระยะ prototyping ขนาดเล็ก สามารถใช้ LC filter อันดับสองที่ออกแบบง่ายกว่า "
  "โดยมีความถี่ resonance ตามสมการ (2.11)")
EQ("f_res = 1 / (2π · √(L_f · C_f))                            ... (2.11)")
P('Normal',
  "\tตัวอย่างเช่น L_f = 1.0 mH, C_f = 12 µF ให้ f_res ≈ 1.45 kHz "
  "ซึ่งอยู่ระหว่างความถี่หลัก (50 Hz) และความถี่สวิตช์ (10 kHz) "
  "ตามหลักการที่ฮาร์มอนิกที่ความถี่สวิตช์จะถูกลดทอนประมาณ 40 dB ที่ 10 kHz")
P('Normal',
  "\tวงจร LC ที่ไม่มีการหน่วงจะมี ζ ต่ำมาก (~0.002 ตามค่า ESR ของขดลวด) "
  "ทำให้เกิด resonant ringing รุนแรงในระหว่าง transient "
  "วิธีหนึ่งคือเพิ่ม passive damping resistor R_d ต่ออนุกรมกับ C_f ดังสมการ (2.12)")
EQ("ζ = (R_d / 2) · √(C_f / L_f)                               ... (2.12)")
P('Normal',
  "\tตัวอย่างที่ R_d = 1 Ω, L_f = 1.0 mH, C_f = 12 µF ได้ ζ ≈ 0.055 ซึ่งเพิ่มจากค่า ESR-only ประมาณ 20 เท่า "
  "ข้อแลกของวิธี series R_d คือกระแสฮาร์มอนิกของ C_f (ซึ่งมีองค์ประกอบที่ f_sw) จะสร้างแรงดันตกคร่อม R_d "
  "กลายเป็นสัญญาณรบกวนใน V_load การเลือก R_d จึงเป็นการประนีประนอมระหว่าง damping กับ PWM injection "
  "ในโครงงานนี้เลือก R_d = 1 Ω หลังจากทดสอบที่ R_d = 5 Ω แล้วพบว่า inject สัญญาณ 10 kHz ขนาด ~5 V "
  "เข้า V_load มากเกินไป")

P('Heading 3', "2.4.4 dq Decoupling Feedforward ในลูปกระแสภายใน")
P('Normal',
  "\tหลังจาก outer VSG loop กำหนด V_ref แล้ว ระบบจะแปลง V_load และกระแส i_L ผ่าน Park transform "
  "เป็น V_load_d, V_load_q, i_L_d, i_L_q เพื่อป้อนให้ cascaded PI controller ในกรอบ dq "
  "การเขียนสมการ KVL ฝั่งอินเวอร์เตอร์ในกรอบ dq พบว่าแรงดันที่ PI ต้องสร้าง (V_inv*) "
  "มี cross-coupling term ระหว่างแกน d และ q ผ่าน ω · L_f ดังสมการ (2.13)–(2.14)")
EQ("V_d* = K_p·(i_d* − i_d) + K_i·∫(i_d* − i_d)dt − ω·L_f·i_q + V_load_d   ... (2.13)")
EQ("V_q* = K_p·(i_q* − i_q) + K_i·∫(i_q* − i_q)dt + ω·L_f·i_d + V_load_q   ... (2.14)")
P('Normal',
  "\tเทอม ∓ω · L_f · i_dq เรียกว่า dq decoupling feedforward "
  "ทำให้ลูปกระแส d และ q เป็นอิสระต่อกัน (decoupled) ตัวควบคุมจึง tune แบบ SISO ได้ "
  "ส่วนเทอม V_load_d/q เรียกว่า load voltage feedforward "
  "ช่วยลด overshoot และ steady-state error เมื่อโหลดเปลี่ยนแปลงอย่างรวดเร็ว")
P('Normal',
  "\tโครงงานนี้ implement สมการ (2.13)–(2.14) ใน Stage 5c ของการจำลอง "
  "พบว่าให้ peak current reduction ~6 % และ V_q residual reduction ~10 % "
  "เทียบกับ baseline ที่ไม่มี feedforward (ดูบทที่ 4)")

P('Heading 3', "2.4.5 BESS เป็นแหล่งพลังงานฝั่ง DC และการคำนวณขนาด")
P('Normal',
  "\tVSG ต้องการแหล่งพลังงานที่สามารถจ่ายและรับพลังงานสองทิศทางในระยะ transient "
  "ตามอัตราที่ Swing Equation กำหนด ระบบกักเก็บพลังงานด้วยแบตเตอรี่ (BESS) "
  "ที่ใช้เคมี Lithium Iron Phosphate (LiFePO₄) ตอบโจทย์เนื่องจาก "
  "(i) รองรับการคายและประจุได้ตามต้องการ (ii) มี internal resistance ต่ำพอที่จะจ่าย pulse current "
  "ในช่วงมิลลิวินาที (iii) มีอายุการใช้งานยาวเหมาะกับ cycling จากการตอบสนอง transient บ่อยครั้ง")
P('Normal',
  "\tการคำนวณขนาดกำลัง BESS สำหรับการรองรับ inertial transient ที่กำลังพิกัด S_base "
  "และการเปลี่ยนแปลงความถี่สูงสุด Δω_max ในช่วงเวลา Δt ใช้สมการ (2.15)")
EQ("P_inertial = 2H · (Δω_max / Δt) × S_base                   ... (2.15)")
P('Normal',
  "\tสำหรับโครงงานนี้ S_base = 100 W, H = 5, Δω_max = 0.02 pu (1 Hz ที่ 50 Hz base), Δt = 0.5 s "
  "ได้ P_inertial = 4 W ซึ่งเป็น overhead เพียงเล็กน้อยเมื่อเทียบกับ P_ref = 100 W "
  "ดังนั้น BESS ที่จ่ายได้ ~110–120 W (มี headroom 10–20 %) ก็เพียงพอสำหรับ worst-case operation")
P('Normal',
  "\tการคำนวณขนาดพลังงาน BESS เพื่อรองรับการจ่ายต่อเนื่องที่ rated power เป็นเวลา t_run ใช้สมการ (2.16)")
EQ("E_BESS ≥ P_ref · t_run / η                                 ... (2.16)")
P('Normal',
  "\tที่ P_ref = 100 W, t_run = 30 นาที (สำหรับการทดสอบ bench), η = 0.92 (DC-DC + inverter combined) "
  "ได้ E_BESS ≥ 54 Wh โครงงานนี้เลือก 4 × LiFePO₄ 12 V 10 Ah ต่ออนุกรม (480 Wh) "
  "ที่ให้ buffer มากเกินความจำเป็นเพื่อรองรับการทดสอบ load step ซ้ำหลายรอบโดยไม่ต้องชาร์จระหว่างเซสชัน")

# ============================================================================
# 2.5 Related Work (was 2.4)
# ============================================================================
P('Heading 2', "2.5 งานวิจัยที่เกี่ยวข้องกับ VSG (Related Work on VSG)")
P('Normal',
  "\tงานวิจัยเกี่ยวกับ VSG พัฒนาอย่างต่อเนื่องตั้งแต่ต้นทศวรรษ 2000 จนถึงปัจจุบัน "
  "โดยสามารถแบ่งกลุ่มแนวคิดหลักได้ดังนี้")

P('Heading 3', "2.5.1 VISMA (Virtual Synchronous Machine)")
P('Normal',
  "\tBeck และ Hesse (2007) เป็นกลุ่มแรก ๆ ที่นำเสนอแนวคิด Virtual Synchronous Machine (VISMA) "
  "โดยจำลองสมการ full-order ของ SG ลงในไมโครคอนโทรลเลอร์ของอินเวอร์เตอร์ "
  "ทำให้ inverter มีพฤติกรรมแม่นยำเทียบเท่า SG ทางคณิตศาสตร์ "
  "ข้อดีคือพฤติกรรมใกล้เคียง SG จริงที่สุด ข้อจำกัดคือใช้การคำนวณสูงและต้องการ sensor ที่แม่นยำ "
  "ส่งผลให้ต้องใช้ DSP ระดับสูงเช่น TI C2000 หรือ FPGA")

P('Heading 3', "2.5.2 Synchronverter")
P('Normal',
  "\tZhong และ Weiss (2011) เสนอ Synchronverter ซึ่งเป็นการลดทอน VISMA ให้อยู่ในรูปที่เรียบง่ายขึ้น "
  "โดยใช้สมการ Swing Equation แบบ second-order ร่วมกับ excitation emulation "
  "ทำให้ inverter ทำงานเป็น voltage source ที่ self-synchronize กับกริดได้โดยไม่ต้องใช้ PLL "
  "แนวคิดนี้กลายเป็นพื้นฐานของ VSG สมัยใหม่จำนวนมาก รวมถึงโครงงานนี้")

P('Heading 3', "2.5.3 Droop-based VSG")
P('Normal',
  "\tDe Brabandere et al. (2007) และงานต่อ ๆ มา ใช้ P-f และ Q-V droop ร่วมกับ low-pass filter "
  "เพื่อสร้าง inertial response เทียม โครงสร้างนี้ง่ายและเหมาะกับ microgrid "
  "แต่ inertia ที่ได้มีลักษณะ first-order ไม่ใช่ second-order เหมือน SG จริง "
  "จึงไม่สามารถจำลองพฤติกรรม power-angle ของ SG ได้สมบูรณ์")

P('Heading 3', "2.5.4 Adaptive VSG")
P('Normal',
  "\tAlipoor et al. (2015) เสนอ Adaptive VSG ที่ปรับค่า H และ D ตามขนาดของ frequency deviation "
  "โดยใช้ค่า dω/dt เป็นสัญญาณตัดสินใจ ทำให้ระบบรองรับ disturbance ได้ดีกว่า fixed-parameter VSG "
  "งานวิจัยกลุ่มนี้พัฒนาต่อด้วย Fuzzy logic, Model Predictive Control (MPC) และ data-driven approach "
  "โครงงานนี้ใช้ค่า H, D คงที่ตามผลการ sensitivity sweep "
  "แต่สถาปัตยกรรมเปิดทางให้ขยายเป็น adaptive ในงานวิจัยต่อยอด")

P('Heading 3', "2.5.5 GFM Control Comparison (D'Arco & Suul, 2014)")
P('Normal',
  "\tD'Arco และ Suul (2014) เปรียบเทียบ Droop control, Synchronverter และ VSG-based control ในกริดอ่อน "
  "พบว่า Synchronverter ให้ frequency response ที่ใกล้เคียง SG มากที่สุด แต่อ่อนไหวต่อ parameter mismatch "
  "ส่วน droop-based control เสถียรกว่าใน wide-range operation "
  "ผลการวิจัยนี้สนับสนุนการเลือกใช้สถาปัตยกรรมแบบ Synchronverter-like ในโครงงาน")

P('Heading 3', "2.5.6 ENTSO-E และมาตรฐาน GFM ล่าสุด")
P('Normal',
  "\tรายงาน ENTSO-E (2020) ระบุถึงความจำเป็นในการใช้ GFM converters ในระบบที่มีสัดส่วน "
  "inverter-based generation สูง โดยกำหนดคุณสมบัติที่จำเป็นได้แก่ inertia provision, "
  "fault current contribution, black-start capability และ stable operation in islanded mode "
  "สอดคล้องกับ IEEE 1547-2018 และ IEEE 2988 ที่อยู่ระหว่างพัฒนา")

P('Heading 3', "2.5.7 สรุปเปรียบเทียบ VSG variants")
P('Normal',
  "\tตารางที่ 2.2 สรุปคุณสมบัติเชิงเปรียบเทียบของ VSG variants หลัก "
  "เพื่อช่วยในการเลือกสถาปัตยกรรมที่เหมาะสมกับเป้าหมายของโครงงาน")
T(VSG_COMPARISON_TABLE)

# ============================================================================
# 2.6 Standards (was 2.5)
# ============================================================================
P('Heading 2', "2.6 มาตรฐานและข้อกำหนดทางกริดที่เกี่ยวข้อง (Relevant Grid Standards and Codes)")
P('Normal',
  "\tการพัฒนา VSG ต้องคำนึงถึงมาตรฐานที่ใช้ในระบบไฟฟ้าทั้งระดับสากลและระดับประเทศ ดังต่อไปนี้")

P('Heading 3', "2.6.1 IEEE 1547-2018")
P('Normal',
  "\tIEEE 1547-2018 เป็นมาตรฐานสำหรับการเชื่อมต่อ Distributed Energy Resources (DER) เข้ากับระบบจำหน่าย "
  "กำหนดคุณสมบัติด้าน voltage/frequency ride-through, reactive power capability, voltage regulation "
  "และอนุญาตให้ DER ทำงานในโหมด Grid-Forming ได้ภายใต้เงื่อนไขเฉพาะ "
  "มาตรฐานนี้กำหนด default RoCoF trip threshold ที่ ±2 Hz/s "
  "ซึ่งใช้เป็นเกณฑ์อ้างอิงในการประเมินผล VSG ของโครงงาน")

P('Heading 3', "2.6.2 IEEE 2988 (กำลังพัฒนา)")
P('Normal',
  "\tIEEE 2988 เป็นมาตรฐานเฉพาะสำหรับ Grid-Forming Inverters ที่อยู่ระหว่างการพัฒนา "
  "กำหนดคุณสมบัติพื้นฐาน เช่น virtual inertia provision, voltage source behavior, "
  "black-start support, fault current contribution และการประสานงานกับ SG ในระบบไฟฟ้าผสม")

P('Heading 3', "2.6.3 IEC 61400-27")
P('Normal',
  "\tIEC 61400-27 กำหนดโมเดลพลวัตของ wind turbine generators สำหรับการศึกษาเสถียรภาพระบบ "
  "มีส่วนที่เกี่ยวข้องกับ converter-interfaced generation ซึ่งเป็นพื้นฐานในการเปรียบเทียบ "
  "behavior ระหว่าง GFL กับ GFM/VSG")

P('Heading 3', "2.6.4 ENTSO-E Grid Code")
P('Normal',
  "\tENTSO-E (European Network of Transmission System Operators for Electricity) "
  "ได้ออกข้อกำหนดเกี่ยวกับ converter-based generation ใน high-penetration scenario "
  "โดยเฉพาะการ provide synthetic inertia, Fast Frequency Response (FFR) "
  "และ Frequency Containment Reserve (FCR) "
  "มาตรฐาน EU ส่วนใหญ่กำหนด RoCoF threshold ที่ ±1 Hz/s ซึ่งเข้มงวดกว่า IEEE 1547")

P('Heading 3', "2.6.5 มาตรฐานไทย: PEA และ MEA Interconnection Code")
P('Normal',
  "\tการไฟฟ้าส่วนภูมิภาค (PEA) และการไฟฟ้านครหลวง (MEA) "
  "กำหนดมาตรฐานการเชื่อมต่อ DER เข้ากับระบบจำหน่ายภายในประเทศ "
  "ครอบคลุม voltage regulation, anti-islanding protection, harmonic limit (IEEE 519 derived) และ power quality "
  "ในปัจจุบันมาตรฐานไทยยังไม่ได้ระบุข้อกำหนดเฉพาะของ GFM/VSG "
  "จึงเป็นช่องว่างที่งานวิจัยนี้ต้องการเติมเต็มในระดับ academic prototype")

# ============================================================================
# 2.7 Summary + Academic Gap (NEW)
# ============================================================================
P('Heading 2', "2.7 สรุปและช่องว่างทางวิชาการ (Summary and Academic Gap)")
P('Normal', "\tจากการทบทวนทั้งหมดสามารถสรุปได้ดังนี้")
P('List Paragraph',
  "VSG เป็นหนึ่งในแนวทาง Grid-Forming ที่มีศักยภาพสูงสุดในการให้ virtual inertia "
  "และยกระดับเสถียรภาพของระบบไฟฟ้าที่มี renewable penetration สูง")
P('List Paragraph',
  "สถาปัตยกรรมแบบ Synchronverter (Zhong & Weiss, 2011) เป็นพื้นฐานที่นิยมและให้พลวัตใกล้เคียง SG จริง")
P('List Paragraph',
  "การนำ VSG ไปใช้งานต้องอาศัยความรู้ไฟฟ้ากำลังครบวงจร ตั้งแต่การแปลงพิกัด, SPWM, "
  "การออกแบบ LC/LCL filter พร้อม damping ไปจนถึงการกำหนดขนาด BESS")
P('List Paragraph',
  "มาตรฐานสากลที่เกี่ยวข้อง (IEEE 1547-2018, IEEE 2988, ENTSO-E) "
  "เริ่มกำหนดข้อกำหนดเฉพาะของ GFM แต่มาตรฐานไทยยังไม่ระบุชัดเจน")
P('Normal', "\tช่องว่างทางวิชาการที่โครงงานนี้ต้องการเติมเต็ม")
P('List Paragraph',
  "VSG บนไมโครคอนโทรลเลอร์ต้นทุนต่ำ — งานวิจัยส่วนใหญ่ใช้ DSP ระดับสูง (TI C2000, FPGA) "
  "ส่วนการ implement บน ESP32 (240 MHz, dual-core, ราคาประมาณ 200 บาท) ยังเป็นพื้นที่ที่มีงานวิจัยจำกัด "
  "การพิสูจน์ feasibility ที่ระดับ 10 kHz ISR "
  "จะเปิดทางให้ VSG ใช้งานในระดับ educational และ small-scale microgrid ได้กว้างขึ้น")
P('List Paragraph',
  "การทดสอบครบวงจร MATLAB → Hardware ที่ระดับ sub-kW — "
  "งานวิจัยที่ปรากฏในวรรณกรรมส่วนใหญ่หยุดที่ระดับการจำลองหรือ Hardware-in-the-Loop (HIL) "
  "การส่งต่อจากการจำลองสู่ฮาร์ดแวร์จริงที่ระดับ 100 W มีคุณค่าทางการศึกษาในการ identify "
  "ปัญหาเชิงปฏิบัติเช่น overmodulation, LC ringing, sensor noise ที่การจำลองสะอาดไม่ครอบคลุม")
P('List Paragraph',
  "การบูรณาการ BESS กับ VSG ในสภาพแวดล้อมการศึกษา — แม้ BESS + GFM จะเป็น industry standard "
  "(Tesla Hornsdale, Hawaiian Electric) แต่ open-source documentation ที่ระบุ BoM, "
  "สมการการคำนวณขนาด และผลการทดสอบที่ทำซ้ำได้ ยังขาดแคลน "
  "โครงงานนี้จะ document ทุกองค์ประกอบเพื่อให้นักศึกษารุ่นต่อไปสามารถนำไป replicate ได้")
P('List Paragraph',
  "มาตรฐานไทย — การสร้าง reference prototype ที่สอดคล้องกับ IEEE 1547-2018 ในประเทศไทย "
  "จะเป็น input ทางวิชาการสำหรับการพัฒนา grid code ของ PEA/MEA ในอนาคต "
  "โดยเฉพาะส่วนที่เกี่ยวข้องกับ GFM และ synthetic inertia")
P('Normal',
  "\tในบทถัดไปจะอธิบายวิธีดำเนินงานที่ออกแบบขึ้นเพื่อเติมเต็มช่องว่างทั้งสี่ประการนี้ "
  "ตั้งแต่การจำลองด้วย MATLAB/Simulink การออกแบบฮาร์ดแวร์ 48 V / 100 W "
  "การพัฒนาเฟิร์มแวร์บน ESP32 ไปจนถึงการทดสอบเปรียบเทียบกับการควบคุมแบบ Droop ดั้งเดิม")


# ============================================================================
# EXECUTION
# ============================================================================
print(f"Total operations to insert: {len(OPS)}")
para_count = sum(1 for o in OPS if o[0] == 'P')
table_count = sum(1 for o in OPS if o[0] == 'T')
print(f"  Paragraphs: {para_count}")
print(f"  Tables: {table_count}")

doc = Document(DOCX)
body = doc.element.body

# ---- Find Ch.2 and Ch.3 anchor paragraphs by text ----
ch2_anchor = None
ch3_anchor = None
for p_elem in body.iterchildren(qn('w:p')):
    text = ''.join((t.text or '') for t in p_elem.iter(qn('w:t'))).strip()
    if text.startswith('บทที่ 2') and ch2_anchor is None:
        ch2_anchor = p_elem
    elif text.startswith('บทที่ 3') and ch3_anchor is None:
        ch3_anchor = p_elem
        break

assert ch2_anchor is not None, "Could not locate 'บทที่ 2' heading"
assert ch3_anchor is not None, "Could not locate 'บทที่ 3' heading"
print(f"Located Ch.2 anchor and Ch.3 anchor")

# ---- Delete all siblings between ch2_anchor and ch3_anchor (exclusive both) ----
removed = 0
current = ch2_anchor.getnext()
while current is not None and current is not ch3_anchor:
    nxt = current.getnext()
    body.remove(current)
    current = nxt
    removed += 1
print(f"Removed {removed} elements between Ch.2 and Ch.3 anchors")

# ---- Insert new operations before ch3_anchor ----
inserted_p = 0
inserted_t = 0
for op in OPS:
    if op[0] == 'P':
        _, style_name, text = op
        new_para = doc.add_paragraph(text, style=style_name)
        p_elem = new_para._p
        body.remove(p_elem)            # detach from end
        ch3_anchor.addprevious(p_elem)  # re-insert before Ch.3
        inserted_p += 1
    elif op[0] == 'T':
        _, rows = op
        n_rows = len(rows)
        n_cols = len(rows[0])
        tbl = doc.add_table(rows=n_rows, cols=n_cols)
        tbl.style = 'Table Grid' if 'Table Grid' in [s.name for s in doc.styles] else 'Normal Table'
        for ri, row in enumerate(rows):
            for ci, val in enumerate(row):
                tbl.rows[ri].cells[ci].text = str(val)
        tbl_elem = tbl._tbl
        body.remove(tbl_elem)
        ch3_anchor.addprevious(tbl_elem)
        inserted_t += 1
print(f"Inserted {inserted_p} paragraphs + {inserted_t} tables before Ch.3")

doc.save(DOCX)
print(f"\nSaved: {DOCX}")
