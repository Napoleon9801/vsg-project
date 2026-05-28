"""
Generate 66AOS02 proposal defense presentation skeleton
Uses Presentation3.pptx as template (4:3, Office layouts)
Output: proposal_defense_66AOS02.pptx
Font: Leelawadee UI (Win11 built-in Thai font)
"""
from pptx import Presentation
from pptx.util import Pt, Inches, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.oxml.ns import qn
from copy import deepcopy
from lxml import etree

TEMPLATE = r"C:\Users\User\workspace\engineering\vsg-project\docs\Presentation3.pptx"
OUTPUT   = r"C:\Users\User\workspace\engineering\vsg-project\docs\proposal_defense_66AOS02.pptx"

FONT_TH = "Leelawadee UI"
NAVY    = RGBColor(0x0B, 0x1F, 0x3A)
CYAN    = RGBColor(0x00, 0xC8, 0xE6)
WHITE   = RGBColor(0xFF, 0xFF, 0xFF)
LIGHT   = RGBColor(0xE8, 0xF1, 0xF8)
GRAY    = RGBColor(0x6B, 0x7B, 0x8C)
GOLD    = RGBColor(0xFF, 0xC0, 0x4D)


# ------------------ helpers ------------------
def set_font(run, name=FONT_TH, size=None, bold=None, color=None):
    run.font.name = name
    rPr = run._r.get_or_add_rPr()
    for tag in ("latin", "ea", "cs"):
        el = rPr.find(qn(f"a:{tag}"))
        if el is None:
            el = etree.SubElement(rPr, qn(f"a:{tag}"))
        el.set("typeface", name)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.font.bold = bold
    if color is not None:
        run.font.color.rgb = color


def add_bg(slide, color=NAVY):
    bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, prs.slide_width, prs.slide_height)
    bg.line.fill.background()
    bg.fill.solid(); bg.fill.fore_color.rgb = color
    bg.shadow.inherit = False
    # move to back
    spTree = bg._element.getparent()
    spTree.remove(bg._element); spTree.insert(2, bg._element)
    return bg


def add_accent_stripe(slide, color=CYAN, height_in=0.10):
    s = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, Inches(0.85), prs.slide_width, Inches(height_in))
    s.line.fill.background(); s.fill.solid(); s.fill.fore_color.rgb = color
    s.shadow.inherit = False
    return s


def add_footer(slide, page_no, total=18):
    tb = slide.shapes.add_textbox(Inches(0.3), Inches(7.15), Inches(9.4), Inches(0.3))
    tf = tb.text_frame; tf.margin_left = tf.margin_right = 0; tf.margin_top = tf.margin_bottom = 0
    p = tf.paragraphs[0]
    r = p.add_run(); r.text = "66AOS02  |  VSG for BESS Inverter Control  |  สอบหัวข้อโครงงาน"
    set_font(r, size=9, color=GRAY)
    p2 = tf.add_paragraph(); p2.alignment = PP_ALIGN.RIGHT
    # secondary right text
    tb2 = slide.shapes.add_textbox(Inches(8.5), Inches(7.15), Inches(1.2), Inches(0.3))
    tf2 = tb2.text_frame; tf2.margin_left = tf2.margin_right = 0
    p3 = tf2.paragraphs[0]; p3.alignment = PP_ALIGN.RIGHT
    r3 = p3.add_run(); r3.text = f"{page_no} / {total}"
    set_font(r3, size=9, color=GOLD, bold=True)


def add_title(slide, text, y_in=0.20, size=22):
    tb = slide.shapes.add_textbox(Inches(0.5), Inches(y_in), Inches(9.0), Inches(0.6))
    tf = tb.text_frame; tf.margin_left = tf.margin_right = 0; tf.margin_top = tf.margin_bottom = 0
    tf.word_wrap = True
    p = tf.paragraphs[0]
    r = p.add_run(); r.text = text
    set_font(r, size=size, bold=True, color=WHITE)
    return tb


def add_notes(slide, text):
    """Attach Thai speaker notes to a slide."""
    nf = slide.notes_slide.notes_text_frame
    nf.clear()
    paras = text.strip().split("\n")
    for i, para in enumerate(paras):
        p = nf.paragraphs[0] if i == 0 else nf.add_paragraph()
        r = p.add_run(); r.text = para
        set_font(r, name=FONT_TH, size=12)
    return nf


def add_panel(slide, x_in, y_in, w_in, h_in, color=RGBColor(0x10, 0x2A, 0x4E)):
    s = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE,
                               Inches(x_in), Inches(y_in), Inches(w_in), Inches(h_in))
    s.adjustments[0] = 0.06
    s.line.color.rgb = CYAN; s.line.width = Pt(0.5)
    s.fill.solid(); s.fill.fore_color.rgb = color
    s.shadow.inherit = False
    return s


def add_bullets(slide, x_in, y_in, w_in, h_in, items, size=14, color=WHITE):
    tb = slide.shapes.add_textbox(Inches(x_in), Inches(y_in), Inches(w_in), Inches(h_in))
    tf = tb.text_frame; tf.word_wrap = True
    tf.margin_left = Inches(0.1); tf.margin_right = Inches(0.1)
    tf.margin_top = Inches(0.05); tf.margin_bottom = Inches(0.05)
    for i, it in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_after = Pt(4)
        if isinstance(it, tuple):
            head, body = it
            r1 = p.add_run(); r1.text = "▸ "; set_font(r1, size=size, bold=True, color=CYAN)
            r2 = p.add_run(); r2.text = head; set_font(r2, size=size, bold=True, color=WHITE)
            if body:
                r3 = p.add_run(); r3.text = " — " + body; set_font(r3, size=size-1, color=LIGHT)
        else:
            r1 = p.add_run(); r1.text = "▸ "; set_font(r1, size=size, bold=True, color=CYAN)
            r2 = p.add_run(); r2.text = it; set_font(r2, size=size, color=color)
    return tb


def add_text(slide, x_in, y_in, w_in, h_in, text, size=12, color=LIGHT, bold=False, align=PP_ALIGN.LEFT):
    tb = slide.shapes.add_textbox(Inches(x_in), Inches(y_in), Inches(w_in), Inches(h_in))
    tf = tb.text_frame; tf.word_wrap = True
    tf.margin_left = Inches(0.05); tf.margin_right = Inches(0.05)
    p = tf.paragraphs[0]; p.alignment = align
    r = p.add_run(); r.text = text
    set_font(r, size=size, bold=bold, color=color)
    return tb


def add_table(slide, x_in, y_in, w_in, h_in, data, header_color=CYAN, body_color=RGBColor(0x14, 0x33, 0x5C)):
    rows = len(data); cols = len(data[0])
    tbl_shape = slide.shapes.add_table(rows, cols, Inches(x_in), Inches(y_in), Inches(w_in), Inches(h_in))
    tbl = tbl_shape.table
    for ri, row in enumerate(data):
        for ci, val in enumerate(row):
            cell = tbl.cell(ri, ci)
            cell.fill.solid()
            cell.fill.fore_color.rgb = header_color if ri == 0 else body_color
            cell.margin_left = Inches(0.06); cell.margin_right = Inches(0.06)
            cell.margin_top = Inches(0.03); cell.margin_bottom = Inches(0.03)
            tf = cell.text_frame; tf.word_wrap = True
            tf.text = ""
            p = tf.paragraphs[0]
            r = p.add_run(); r.text = str(val)
            set_font(r, size=10 if ri > 0 else 11,
                     bold=(ri == 0),
                     color=NAVY if ri == 0 else WHITE)
    return tbl


def new_slide(layout_idx=6):
    slide = prs.slides.add_slide(prs.slide_layouts[layout_idx])
    add_bg(slide, NAVY)
    return slide


# ------------------ build ------------------
prs = Presentation(TEMPLATE)

# Wipe the 2 placeholder slides from template (keep theme/master/layouts)
# Must drop both the sldIdLst entry AND the slide part/rel — otherwise duplicate slide1.xml
sldIdLst = prs.slides._sldIdLst
rIds_to_drop = [sldId.rId for sldId in list(sldIdLst)]
for sldId in list(sldIdLst):
    sldIdLst.remove(sldId)
for rId in rIds_to_drop:
    prs.part.drop_rel(rId)

# ---------- 1. Cover ----------
s = new_slide()
add_accent_stripe(s, CYAN, 0.12)
add_text(s, 0.5, 0.30, 9.0, 0.5, "โครงงานวิศวกรรมไฟฟ้า 529402",
         size=14, color=CYAN, bold=True)
add_text(s, 0.5, 0.62, 9.0, 0.4, "รหัสโครงงาน 66AOS02",
         size=11, color=GOLD, bold=True)

# main title panel
title_tb = slide_box = s.shapes.add_textbox(Inches(0.5), Inches(1.50), Inches(9.0), Inches(2.2))
tf = title_tb.text_frame; tf.word_wrap = True
tf.margin_left = tf.margin_right = 0
p = tf.paragraphs[0]; p.alignment = PP_ALIGN.CENTER
r = p.add_run(); r.text = "การพัฒนาเครื่องกำเนิดไฟฟ้าซิงโครนัสเสมือน"
set_font(r, size=30, bold=True, color=WHITE)
p2 = tf.add_paragraph(); p2.alignment = PP_ALIGN.CENTER
r2 = p2.add_run(); r2.text = "สำหรับการควบคุมอินเวอร์เตอร์ในระบบกักเก็บพลังงานด้วยแบตเตอรี่"
set_font(r2, size=22, bold=True, color=WHITE)
p3 = tf.add_paragraph(); p3.alignment = PP_ALIGN.CENTER; p3.space_before = Pt(10)
r3 = p3.add_run(); r3.text = "Virtual Synchronous Generator for BESS Inverter Control"
set_font(r3, size=14, color=CYAN, bold=False)

# authors panel
add_panel(s, 0.8, 4.20, 8.4, 1.95, RGBColor(0x10, 0x2A, 0x4E))
add_text(s, 0.8, 4.30, 8.4, 0.35, "คณะผู้จัดทำ", size=12, color=CYAN, bold=True, align=PP_ALIGN.CENTER)
authors = [
    "นายชินวัตร  ดุมกลาง         รหัสนักศึกษา B66xxxxx",
    "นายฉัตรมงคล  นามจำปา    รหัสนักศึกษา B66xxxxx",
    "นายกิตติทัต  เจริญใจ          รหัสนักศึกษา B66xxxxx",
]
y = 4.65
for a in authors:
    add_text(s, 1.5, y, 7.0, 0.35, a, size=14, color=WHITE, align=PP_ALIGN.LEFT)
    y += 0.35
add_text(s, 0.8, 5.78, 8.4, 0.3,
         "อาจารย์ที่ปรึกษา  :  รองศาสตราจารย์ ดร.อนันท์  อุ่นศิวิไลย์",
         size=13, color=GOLD, bold=True, align=PP_ALIGN.CENTER)

add_text(s, 0.5, 6.40, 9.0, 0.3,
         "สำนักวิชาวิศวกรรมศาสตร์  มหาวิทยาลัยเทคโนโลยีสุรนารี",
         size=11, color=LIGHT, align=PP_ALIGN.CENTER)
add_text(s, 0.5, 6.70, 9.0, 0.3,
         "ภาคการศึกษาที่ 3  ปีการศึกษา 2568",
         size=11, color=LIGHT, align=PP_ALIGN.CENTER)
add_notes(s, """[เวลา ~30 วินาที — ผู้บรรยาย: ชินวัตร เปิด]
"เรียนคณะกรรมการที่เคารพ ผมนายชินวัตร ดุมกลาง พร้อมเพื่อนร่วมทีม นายฉัตรมงคล และนายกิตติทัต
วันนี้พวกเราจะนำเสนอหัวข้อโครงงานวิศวกรรมไฟฟ้ารหัส 66AOS02
เรื่อง การพัฒนาเครื่องกำเนิดไฟฟ้าซิงโครนัสเสมือนสำหรับการควบคุมอินเวอร์เตอร์ในระบบกักเก็บพลังงานด้วยแบตเตอรี่
โดยมี รศ.ดร.อนันท์ อุ่นศิวิไลย์ เป็นอาจารย์ที่ปรึกษาครับ"

จุดที่ต้องระวัง:
- ทักทายให้สั้น กระชับ ไม่เกิน 30 วินาที
- ออกเสียง Virtual Synchronous Generator ให้ชัด
- มองคณะกรรมการ ไม่ก้มดูสไลด์
""")

# ---------- 2. Outline ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "หัวข้อการนำเสนอ (Outline)")
sections = [
    ("1.  บทนำและที่มาของปัญหา", "Energy transition, system inertia, RoCoF"),
    ("2.  วัตถุประสงค์และขอบเขต", "เป้าหมาย 4 ข้อ และข้อจำกัดด้านความปลอดภัย"),
    ("3.  ทฤษฎีพื้นฐาน", "GFL/GFM, Swing Equation, VSG Architecture"),
    ("4.  งานวิจัยที่เกี่ยวข้อง", "VISMA → Synchronverter → Adaptive VSG → ช่องว่างวิจัย"),
    ("5.  วิธีดำเนินงานและการออกแบบ", "Hardware BoM, Firmware ISR, Test plan"),
    ("6.  แผนการดำเนินงานและความเสี่ยง", "Gantt 16 สัปดาห์ + Risk mitigation"),
]
add_bullets(s, 0.8, 1.40, 8.6, 5.5, sections, size=16)
add_footer(s, 2)
add_notes(s, """[เวลา ~30 วินาที — ผู้บรรยาย: ชินวัตร]
"การนำเสนอวันนี้แบ่งออกเป็น 6 ส่วนหลัก
เริ่มจากบทนำและที่มาของปัญหา ต่อด้วยวัตถุประสงค์และขอบเขต
จากนั้นจะปูพื้นทฤษฎี GFL/GFM และ Swing Equation
รวมถึงงานวิจัยที่เกี่ยวข้องและช่องว่างทางวิชาการที่เราต้องการเติมเต็ม
ปิดท้ายด้วยวิธีดำเนินงาน แผนการดำเนินงาน 16 สัปดาห์ และการบริหารความเสี่ยงครับ"

Tip: ไม่ต้องอ่านทุกบรรทัด แค่ชี้แต่ละหัวข้อแล้วบอกว่า "ใครจะเป็นคนนำเสนอส่วนใด"
""")

# ---------- 3. Energy transition ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "1.1  ที่มา : การเปลี่ยนผ่านด้านพลังงานและปัญหาแรงเฉื่อยลดลง")
add_panel(s, 0.5, 1.30, 4.4, 5.4)
add_text(s, 0.7, 1.45, 4.0, 0.4, "บริบทของระบบไฟฟ้ายุคใหม่",
         size=14, color=CYAN, bold=True)
add_bullets(s, 0.6, 1.95, 4.2, 4.7, [
    "RE penetration เพิ่มขึ้นอย่างรวดเร็ว (Solar PV, Wind)",
    "พลังงานเหล่านี้เชื่อมต่อผ่าน Inverter (GFL)",
    "ขาดมวลหมุน → ไม่มี natural inertia",
    "System Inertia (H_sys) ลดลงต่อเนื่อง",
    "ส่งผลให้ RoCoF (df/dt) สูงขึ้น",
    "เสี่ยงต่อ Frequency Instability และ Blackout",
], size=12)

add_panel(s, 5.10, 1.30, 4.40, 5.4, RGBColor(0x14, 0x33, 0x5C))
add_text(s, 5.30, 1.45, 4.0, 0.4, "กรณีศึกษา : UK Blackout (9 ส.ค. 2562)",
         size=13, color=GOLD, bold=True)
add_bullets(s, 5.20, 1.95, 4.2, 2.5, [
    "Hornsea Wind Farm (737 MW) trip กะทันหัน",
    "Little Barford CCGT (664 MW) trip ตาม",
    "RoCoF เกิน −0.125 Hz/s",
    "ความถี่ตกถึง 48.8 Hz",
    "ผู้ใช้ไฟกระทบ ~1 ล้านคน",
], size=11)
add_text(s, 5.30, 4.65, 4.0, 0.4, "บทเรียน",
         size=13, color=GOLD, bold=True)
add_bullets(s, 5.20, 5.10, 4.2, 1.6, [
    "ระบบที่มี Inverter สูงต้องการ Synthetic Inertia",
    "VSG / GFM คือทางออกระดับ inverter-level",
], size=11)
add_footer(s, 3)
add_notes(s, """[เวลา ~1.5 นาที — ผู้บรรยาย: ชินวัตร]
ประเด็นหลักที่ต้องสื่อ:
1. โลกกำลังเปลี่ยนผ่านพลังงานอย่างรวดเร็ว Solar/Wind เพิ่มขึ้นมาก
2. พลังงานเหล่านี้เชื่อมต่อผ่าน Inverter ไม่มีมวลหมุนเหมือน Synchronous Generator ของโรงไฟฟ้าฟอสซิล
3. ผลคือระบบไฟฟ้าสูญเสีย Natural Inertia ทำให้ RoCoF (df/dt) สูงขึ้น เสี่ยงต่อความไม่เสถียร

อ้างอิงเคสจริง (กล่องขวา):
- ยกกรณี UK Blackout 9 สิงหาคม 2019 เป็นตัวอย่าง ฟ้าผ่าทำให้ Hornsea Wind Farm trip 737 MW
- โรงไฟฟ้า Little Barford trip ตาม ความถี่ร่วงถึง 48.8 Hz
- คนไม่มีไฟใช้ประมาณ 1 ล้านคน ใช้เวลากู้ระบบหลายชั่วโมง
- จบประโยคด้วย: "นี่คือสิ่งที่จะเกิดบ่อยขึ้นถ้าเราไม่จัดการเรื่อง inertia"

ระวัง:
- ถ้ากรรมการถามตัวเลข RoCoF spec ให้ตอบ 0.125 Hz/s (UK) หรือ 1 Hz/s (ENTSO-E max)
- อย่าลืมว่าไทยยังไม่มี spec RoCoF ชัดเจน (PEA/MEA ยังไม่ระบุ) — เป็นจุดที่ค่อยพูดในสไลด์ 7
""")

# ---------- 4. Why GFL fails ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "1.1 (ต่อ)  เหตุใด Grid-Following Inverter ไม่เพียงพอ")
add_bullets(s, 0.7, 1.40, 8.6, 5.5, [
    ("GFL = Current Source",
     "อาศัย PLL ตรวจจับมุม/ความถี่ของกริด แล้วฉีดกระแสตาม → ต้องมีกริดแข็งแรง (stiff grid) ก่อน"),
    ("ไม่จ่าย Inertia",
     "ไม่มีพลังงานสำรองเชิงพลวัตเพื่อหน่วงการเปลี่ยนแปลงความถี่"),
    ("ทำงานในโหมด Islanded ไม่ได้",
     "เมื่อขาด stiff grid จะ trip ทันที ใช้กับ microgrid ไม่ได้"),
    ("Low SCR + High IBR → Instability",
     "ระบบที่ Short-Circuit Ratio ต่ำและสัดส่วน Inverter-Based Resource สูงจะเกิด oscillation และ control interaction"),
    ("ไม่ตอบโจทย์ Black-Start",
     "ไม่สามารถสร้างกริดขึ้นมาใหม่หลัง blackout"),
], size=14)
add_footer(s, 4)
add_notes(s, """[เวลา ~1 นาที — ผู้บรรยาย: ชินวัตร]
ขยายความว่าทำไม GFL ที่ใช้แพร่หลายในวันนี้ถึงไม่พอ:

จุดที่ต้องเน้น:
- GFL เปรียบเสมือน "แหล่งจ่ายกระแส" ไม่ใช่ "แหล่งจ่ายแรงดัน" จึงต้องอาศัยกริดที่แข็งแรงเป็น reference
- ใช้ PLL เพื่อหา phase ของกริด แต่ถ้ากริดอ่อน (SCR ต่ำ) PLL จะ unstable
- ไม่จ่าย inertia เพราะไม่มี energy reservoir + ไม่มี algorithm จำลอง
- ไม่สามารถ Stand-alone ได้ — ตัดจากกริดเมื่อไหร่จะ trip ทันที
- Black-Start ไม่ได้ ต้องรอ Synchronous Generator มา re-energize ก่อน

คำตอบสำรองหากถูกถาม:
Q: "แล้ว Solar PV ปัจจุบันใช้ได้ยังไงในไทย?"
A: "ใช้ได้ครับ เพราะระบบยังมี SG เป็นแหล่งจ่ายหลัก inertia ยังพอ แต่เมื่อเป้า RE 50% ใน 2050 จะเริ่มมีปัญหา"

Q: "SCR ต่ำคือเท่าไหร่?"
A: "ตามมาตรฐาน IEEE 1204 ระบบ Weak Grid คือ SCR < 3, Very Weak < 2 ครับ"
""")

# ---------- 5. VSG / GFM solution ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "1.1 (ต่อ)  VSG / Grid-Forming คือคำตอบ")
add_panel(s, 0.5, 1.30, 9.0, 5.5)
add_text(s, 0.7, 1.45, 8.6, 0.45, "แนวคิดหลัก",
         size=15, color=CYAN, bold=True)
add_bullets(s, 0.7, 1.95, 8.6, 1.6, [
    "เลียนแบบพฤติกรรมของ Synchronous Generator ในระดับซอฟต์แวร์ของอินเวอร์เตอร์",
    "อินเวอร์เตอร์ทำตัวเป็น Voltage Source หลัง source impedance",
    "กำหนดมุมและความถี่อ้างอิงเอง — ไม่ต้องพึ่ง PLL",
], size=13)

add_text(s, 0.7, 3.70, 8.6, 0.45, "ประโยชน์ที่ได้",
         size=15, color=GOLD, bold=True)
add_bullets(s, 0.7, 4.20, 8.6, 2.5, [
    "Virtual Inertia → ลด RoCoF ในช่วง disturbance",
    "ทำงานได้ทั้ง Grid-connected และ Stand-alone (Islanded)",
    "รองรับ Black-Start และ Fault Current Contribution",
    "ยกระดับเสถียรภาพให้กริดที่มี Renewable Energy สัดส่วนสูง",
], size=13)
add_footer(s, 5)
add_notes(s, """[เวลา ~1 นาที — ผู้บรรยาย: ชินวัตร]
สรุปแนวคิด VSG ในประโยคเดียว:
"VSG คือการเขียนซอฟต์แวร์ในอินเวอร์เตอร์ให้เลียนแบบพฤติกรรมเครื่องกำเนิดไฟฟ้าซิงโครนัส
เพื่อให้ระบบไฟฟ้าได้ inertia เสมือน โดยไม่ต้องมีมวลหมุนจริง"

ประเด็นสำคัญ:
- VSG ไม่ใช่ฮาร์ดแวร์ใหม่ทั้งหมด — เป็นการเพิ่ม algorithm ในเฟิร์มแวร์ของอินเวอร์เตอร์ที่มีอยู่
- ต้องการ energy reservoir (BESS, supercap, DC-link cap) เพื่อจ่าย transient power
- VSG เป็น subset ของ GFM — GFM ทุกตัวไม่จำเป็นต้องเป็น VSG (เช่น Droop-based GFM ไม่จำลอง SG)

ส่งต่อ slide ถัดไป:
"จากที่อธิบายมาแล้ว ผมจะนำเสนอวัตถุประสงค์ 4 ข้อของโครงงานนี้ในสไลด์ถัดไปครับ"
""")

# ---------- 6. วัตถุประสงค์ ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "1.2  วัตถุประสงค์ของโครงงาน")
add_bullets(s, 0.7, 1.40, 8.6, 5.6, [
    ("1.  ออกแบบและสร้างแบบจำลอง VSG",
     "ระบบควบคุม VSG สำหรับอินเวอร์เตอร์ 3 เฟส บน MATLAB/Simulink"),
    ("2.  เปรียบเทียบสมรรถนะ VSG vs Droop Control",
     "ศึกษาการตอบสนองเชิงพลวัตของความถี่และแรงดันไฟฟ้า"),
    ("3.  วิเคราะห์ช่วงพารามิเตอร์ H และ D ที่เหมาะสม",
     "เพื่อควบคุม RoCoF ให้สอดคล้องกับมาตรฐานกริด (IEEE 1547-2018 / 2988)"),
    ("4.  สร้างและทดสอบชุดต้นแบบฮาร์ดแวร์",
     "Inverter prototype ควบคุมด้วย ESP32 ยืนยันผลเทียบกับการจำลอง"),
], size=15)
add_footer(s, 6)
add_notes(s, """[เวลา ~1 นาที — ผู้บรรยาย: ชินวัตร]
อ่านวัตถุประสงค์ทีละข้อ พร้อมขยายความสั้น ๆ:

ข้อ 1: "Simulink เป็นเครื่องมือมาตรฐานที่ใช้ในงานวิจัย VSG ทั่วโลก เราจะสร้างโมเดล 3 เฟส"
ข้อ 2: "เปรียบเทียบกับ Droop Control ที่เป็น baseline ของระบบ inverter ปัจจุบัน"
ข้อ 3: "ค่า H ควรอยู่ในช่วง 2-10 วินาที, ค่า D ขึ้นกับเงื่อนไข RoCoF spec"
ข้อ 4: "การทดสอบฮาร์ดแวร์จริงคือจุดที่ทำให้โครงงานนี้เป็นมากกว่าแค่ simulation paper"

คำตอบสำรองหากถูกถาม:
Q: "ทำไมต้องเปรียบกับ Droop ไม่เปรียบกับ Synchronverter?"
A: "Droop เป็น industry standard และเป็น baseline ที่ผู้ใช้คุ้นเคย Synchronverter ยังเป็นแค่ academic ครับ"

Q: "ใช้ ESP32 ทำไม ไม่ใช้ DSP?"
A: "ESP32 ราคาถูก 200 บาท เทียบ TI C2000 ที่ 2,000+ บาท ถ้าทำงานได้จะเป็นการลดต้นทุนสำคัญ"
""")

# ---------- 7. ขอบเขต ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "1.3  ขอบเขตและข้อจำกัดของโครงงาน")
scope_data = [
    ["หัวข้อ", "รายละเอียด"],
    ["เครื่องมือจำลอง", "MATLAB / Simulink (R2026a)"],
    ["ไมโครคอนโทรลเลอร์", "ESP32-WROOM-32D  (เป้าหมายหลัก)"],
    ["IDE / Toolchain", "Arduino IDE + VS Code (PlatformIO)"],
    ["พิกัด DC Bus", "≤  60 VDC"],
    ["พิกัดกำลังไฟฟ้า", "≤  300 W"],
    ["BESS", "LiFePO4  24 V  10 Ah"],
    ["โหมดทดสอบ", "Grid-connected (Weak Grid) + Islanded"],
    ["ไม่ครอบคลุม", "THD เชิงลึก, Thermal/Switching Loss"],
]
add_table(s, 0.6, 1.40, 8.8, 5.4, scope_data)
add_footer(s, 7)
add_notes(s, """[เวลา ~1 นาที — ผู้บรรยาย: ชินวัตร]
ขอบเขตที่ต้องเน้น (เพราะกรรมการจะถามแน่ ๆ):

1. "DC Bus ≤ 60 V — ต่ำกว่า SELV (Safety Extra-Low Voltage) จึงปลอดภัยสำหรับการทดลองในห้อง lab"
2. "300 W — เพียงพอจะแสดง dynamic response แต่ไม่ใหญ่จนต้องใช้ Power Stage ราคาแพง"
3. "ESP32 เป็น primary — ถ้าไม่ผ่าน timing budget เรามีแผนสำรองเป็น C2000 (อยู่ใน slide ความเสี่ยง)"
4. "BESS LiFePO4 24V/10Ah = 240 Wh — เพียงพอสำหรับ transient response 5-10 นาทีต่อรอบทดสอบ"
5. "ทดสอบทั้ง Grid-connected (weak grid) และ Islanded — เพื่อแสดงว่า VSG ทำได้ทั้งสองโหมด"

สิ่งที่ "ไม่ครอบคลุม" จงใจระบุ:
- THD เชิงลึก: ใช้ filter ออกแบบมาตรฐานพอ ไม่ลงรายละเอียดทุก harmonic
- Thermal/Switching loss: ไม่มี thermal camera + lab time ไม่พอ

คำตอบสำรอง:
Q: "ทำไมไม่ทำ 380 V / 3-Phase จริง?"
A: "ขั้นต้นเน้น proof-of-concept ก่อนครับ ถ้าผ่านแล้วงานต่อยอดสามารถ scale up ได้"

[ปิดท้าย: ส่งต่อให้ผู้บรรยาย B (ฉัตรมงคล)]
""")

# ---------- 8. GFL vs GFM table ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "2.1  เปรียบเทียบ Grid-Following (GFL) vs Grid-Forming (GFM)")
gfl_gfm = [
    ["คุณสมบัติ", "GFL (Grid-Following)", "GFM (Grid-Forming)"],
    ["พฤติกรรมทางไฟฟ้า", "Current Source", "Voltage Source"],
    ["การ Sync กับกริด", "ใช้ PLL", "กำหนดมุม/ความถี่เอง"],
    ["ความต้องการกริด", "ต้องการ stiff grid", "ทำงานใน weak / islanded ได้"],
    ["การจ่าย Inertia", "ไม่มี", "มี (Virtual Inertia)"],
    ["Black-Start", "ไม่ได้", "ได้"],
    ["ความซับซ้อนการควบคุม", "ต่ำ", "สูงกว่า"],
    ["การใช้งานปัจจุบัน", "Solar PV, Wind ทั่วไป", "Microgrid, BESS, VSG"],
    ["มาตรฐานเกี่ยวข้อง", "IEEE 1547 (เดิม)", "IEEE 1547-2018, IEEE 2988"],
]
add_table(s, 0.4, 1.35, 9.2, 5.5, gfl_gfm)
add_footer(s, 8)
add_notes(s, """[เวลา ~1.5 นาที — ผู้บรรยาย: ฉัตรมงคล เปิดส่วนทฤษฎี]
"สวัสดีครับ ผมฉัตรมงคล จะนำเสนอส่วนทฤษฎีและงานวิจัยที่เกี่ยวข้องครับ
ก่อนจะลงรายละเอียด VSG ขอเปรียบเทียบ Grid-Following กับ Grid-Forming ก่อน"

อ่านตารางแบบเลือกจุดสำคัญ ไม่อ่านทุกแถว:
1. "พฤติกรรมไฟฟ้า: GFL เป็นแหล่งจ่ายกระแส GFM เป็นแหล่งจ่ายแรงดัน"
2. "Sync: GFL ต้องใช้ PLL ตามกริด, GFM กำหนดเอง"
3. "Inertia: GFL ไม่มี, GFM มี → จุดเปลี่ยนสำคัญ"
4. "Black-start: เฉพาะ GFM ทำได้"
5. "การใช้งาน: GFL เหมาะ Solar/Wind ปัจจุบัน, GFM เหมาะ Microgrid/BESS"

ข้อคิดสำคัญที่ต้องสื่อ:
"GFL ทำได้ดีในกริดที่มี SG เป็นหลัก แต่เมื่อ inverter เกิน 50% ของระบบ
เราต้องการ GFM อย่างน้อย 30-40% ของ inverter ทั้งหมด เพื่อรักษาเสถียรภาพ"

คำตอบสำรอง:
Q: "Inverter เดียวกัน switch โหมด GFL ↔ GFM ได้ไหม?"
A: "ได้ครับ ทำได้ในฮาร์ดแวร์เดียวกัน เปลี่ยนแค่ control firmware (ซึ่งคือสิ่งที่งานวิจัย DOE GFM Consortium กำลังพัฒนา)"
""")

# ---------- 9. Swing Equation ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "2.2  ทฤษฎีพื้นฐาน : สมการ Swing Equation")
add_panel(s, 0.6, 1.30, 8.8, 2.2)
add_text(s, 0.8, 1.55, 8.4, 0.5,
         "สมการพลวัตของโรเตอร์ในเครื่องกำเนิดไฟฟ้าซิงโครนัส",
         size=13, color=CYAN, bold=True, align=PP_ALIGN.CENTER)
add_text(s, 0.8, 2.20, 8.4, 0.8,
         "2H · (dω/dt)  =  Pm  −  Pe  −  D · Δω",
         size=24, color=GOLD, bold=True, align=PP_ALIGN.CENTER)
add_text(s, 0.8, 3.05, 8.4, 0.3,
         "(หน่วย per-unit ของระบบไฟฟ้า)",
         size=11, color=LIGHT, align=PP_ALIGN.CENTER)

add_text(s, 0.7, 3.70, 8.6, 0.4, "ความหมายของแต่ละพจน์",
         size=14, color=CYAN, bold=True)
add_bullets(s, 0.7, 4.15, 8.6, 2.7, [
    ("H", "Inertia Constant  [s]  —  พลังงานจลน์สะสมต่อกำลังพิกัด"),
    ("ω, Δω", "ความถี่เชิงมุมและส่วนเบี่ยงเบน  [rad/s หรือ pu]"),
    ("Pm", "กำลังกลที่จ่ายเข้าโรเตอร์  (Mechanical Power)"),
    ("Pe", "กำลังไฟฟ้าที่จ่ายออก  (Electrical Power)"),
    ("D", "Damping Coefficient  —  หน่วง oscillation"),
], size=12)
add_footer(s, 9)
add_notes(s, """[เวลา ~1.5 นาที — ผู้บรรยาย: ฉัตรมงคล]
"สมการ Swing Equation คือหัวใจของ VSG เพราะอินเวอร์เตอร์จะคำนวณสมการนี้ real-time
แล้วใช้ผลลัพธ์เป็น angle reference สำหรับ PWM"

อธิบายสมการทีละพจน์:
- "ฝั่งซ้าย 2H · (dω/dt) คือ inertial term — โมเมนต์ความเฉื่อยคูณอัตราเปลี่ยนความถี่"
- "ฝั่งขวา Pm - Pe คือ power imbalance — กำลังเข้าลบกำลังออก"
- "D · Δω คือ damping term — หน่วงการเปลี่ยนแปลงตามขนาดของ speed deviation"

อินทูชั่นทางฟิสิกส์:
"ถ้า Pm > Pe → โรเตอร์เร่งความเร็ว → ω เพิ่ม → frequency เพิ่ม
ถ้า Pm < Pe → โรเตอร์ชะลอ → frequency ลด
ค่า H ใหญ่ = เร่ง/ชะลอช้า = frequency ไม่กระเด้งแรง = ดีต่อเสถียรภาพ"

คำตอบสำรอง:
Q: "ทำไมใช้ H ไม่ใช้ J?"
A: "H เป็น per-unit normalize ด้วยกำลังพิกัด ทำให้เปรียบเทียบระหว่างเครื่องต่างขนาดได้ง่าย ครับ J = 2H·S_base / ω_base²"

Q: "H ทั่วไปของ SG อยู่ที่เท่าไหร่?"
A: "Thermal plant 3-7 วินาที, Hydro 2-4 วินาที, Gas turbine 4-9 วินาทีครับ"
""")

# ---------- 10. VSG architecture ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "2.3  สถาปัตยกรรมการควบคุม VSG  (4 ชั้น Cascaded)")

layers = [
    ("1. Power Calculation", "คำนวณ P, Q จากแรงดัน v_abc และกระแส i_abc ที่จุดเชื่อมต่อ"),
    ("2. VSG Core (Swing Equation)", "P–ω loop (Virtual Inertia + Damping) และ Q–V loop (Droop / Excitation)"),
    ("3. Voltage / Current Inner Loop", "Cascaded PI controller ใน dq-frame"),
    ("4. PWM / SVPWM Modulator", "สร้างสัญญาณ Gate Drive ที่ความถี่สวิตชิ่ง 5–20 kHz"),
]
y = 1.40
for head, body in layers:
    add_panel(s, 0.6, y, 8.8, 1.20, RGBColor(0x14, 0x33, 0x5C))
    add_text(s, 0.85, y + 0.10, 8.3, 0.45, head, size=15, color=CYAN, bold=True)
    add_text(s, 0.85, y + 0.55, 8.3, 0.6, body, size=12, color=LIGHT)
    # arrow between blocks
    if y < 5.5:
        ar = s.shapes.add_shape(MSO_SHAPE.DOWN_ARROW, Inches(4.85), Inches(y + 1.21),
                                Inches(0.30), Inches(0.18))
        ar.line.fill.background(); ar.fill.solid(); ar.fill.fore_color.rgb = GOLD
        ar.shadow.inherit = False
    y += 1.35
add_footer(s, 10)
add_notes(s, """[เวลา ~1.5 นาที — ผู้บรรยาย: ฉัตรมงคล]
"VSG ในซอฟต์แวร์ของอินเวอร์เตอร์ทำงานแบบ 4 ชั้น เรียงต่อกัน (cascaded)"

อธิบายทีละชั้น (ใช้นิ้วชี้ทีละกล่อง):
1. "ชั้นแรก Power Calculation — รับค่าแรงดันและกระแสจาก ADC มาคำนวณ P, Q instantaneous"
2. "ชั้นที่สอง VSG Core — นำ P, Q ที่ได้ ไปใส่ใน Swing Equation (P-ω) และ Q-V Droop"
3. "ชั้นที่สาม Inner Loop — PI controller ใน dq-frame คุม voltage และ current ให้ตาม reference"
4. "ชั้นที่สี่ SVPWM Modulator — แปลง duty cycle 3 เฟส เป็น gate signal 6 ตัวที่ความถี่ 10-20 kHz"

จุดที่ต้องเน้น:
"การแยกชั้นแบบนี้สำคัญเพราะแต่ละชั้นทำงานที่ bandwidth ต่างกัน:
- Outer loop (VSG Core) ~10-50 Hz
- Inner loop ~500 Hz - 1 kHz
- SVPWM ~10-20 kHz
ทำให้ tune ง่ายและ stability วิเคราะห์ได้แม่นยำ"

คำตอบสำรอง:
Q: "ทำไม VSG ต้องมี Inner Loop ทั้งที่ SG จริงไม่มี?"
A: "เพราะ inverter ไม่มี physical winding ที่ limit current ตามธรรมชาติ ต้อง software limit ด้วย current loop ครับ"
""")

# ---------- 11. Literature timeline ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "2.4  งานวิจัยที่เกี่ยวข้องและช่องว่างทางวิชาการ")
lit = [
    ("VISMA  (Beck & Hesse, 2007)",
     "Full-order SG emulation — แม่นยำสูง แต่ต้องการการคำนวณและ sensor มาก"),
    ("Synchronverter  (Zhong & Weiss, 2011)",
     "ลด VISMA เป็น second-order Swing Eq + excitation emulation, self-sync ไม่ต้องใช้ PLL"),
    ("Droop-based VSG  (De Brabandere, 2007)",
     "P-f + Q-V droop + LPF — ง่าย เหมาะกับ microgrid แต่ได้ inertia แค่ first-order"),
    ("Adaptive VSG  (Alipoor et al., 2015)",
     "ปรับ H และ D ตาม disturbance — รองรับเหตุการณ์ได้ดีกว่า fixed parameter"),
    ("GFM Comparison  (D'Arco & Suul, 2014)",
     "Synchronverter ใกล้ SG ที่สุด แต่ sensitive ต่อ parameter mismatch"),
    ("ENTSO-E (2020) / IEEE 2988",
     "กำหนด requirement ของ GFM : inertia, fault current, black-start, islanded operation"),
]
add_bullets(s, 0.6, 1.35, 8.9, 4.5, lit, size=12)

add_panel(s, 0.6, 6.05, 8.9, 1.0, RGBColor(0x4A, 0x2E, 0x10))
add_text(s, 0.8, 6.15, 8.6, 0.35, "ช่องว่างทางวิชาการที่โครงงานนี้เติมเต็ม",
         size=12, color=GOLD, bold=True)
add_text(s, 0.8, 6.50, 8.6, 0.50,
         "งานวิจัย VSG ส่วนใหญ่ใช้ DSP (TI C2000) — การ implement บน ESP32 (low-cost dual-core MCU) ยังเป็นช่องว่าง",
         size=11, color=WHITE)
add_footer(s, 11)
add_notes(s, """[เวลา ~2 นาที — ผู้บรรยาย: ฉัตรมงคล สไลด์ที่สำคัญที่สุดของช่วงทฤษฎี]
"การพัฒนา VSG มี evolution ที่ชัดเจน 5 ขั้นใหญ่ ๆ ครับ"

ไล่ตามลำดับเวลา:
1. "VISMA (2007) — รุ่นแรกสุด จำลอง full-order SG model แม่นมากแต่ใช้ CPU หนัก"
2. "Synchronverter (2011) — ลดให้ง่ายลง ใช้ Swing Eq อย่างเดียว ไม่ต้อง PLL → นี่คือพื้นฐานของ VSG สมัยใหม่"
3. "Droop-based VSG (2007) — เลียนแบบ inertia ด้วย LPF ง่ายแต่ได้แค่ first-order"
4. "Adaptive VSG (2015) — H และ D ปรับเปลี่ยนได้ตามขนาด disturbance"
5. "GFM Comparison (2014) — งานสำคัญที่เปรียบเทียบ 3 แนว"

ช่องว่างทางวิชาการ (ที่ต้องเน้น):
"จากการทบทวนวรรณกรรม งาน VSG ส่วนใหญ่ implement บน DSP เช่น TI C2000 หรือ TMS320
แต่ ESP32 ที่ราคา 1/10 และเป็น dual-core ARM Cortex มี FPU ในตัว
ยังไม่มีงานวิจัยที่ implement Full VSG บน ESP32 อย่างจริงจัง — นี่คือช่องว่างที่งานเราจะเติมเต็ม"

คำตอบสำรอง:
Q: "Synchronverter กับ VSG ต่างกันยังไง?"
A: "Synchronverter เป็น subset ของ VSG ที่ Self-synchronize ได้โดยไม่ต้องใช้ PLL ครับ ถือเป็น VSG แบบ pure"

Q: "ทำไมต้อง Adaptive VSG?"
A: "เพราะ Fixed H, D ให้ผลลัพธ์ trade-off — H สูงดี transient แต่ steady-state ช้า, Adaptive เปลี่ยนตามสถานการณ์ได้"

[ปิดท้าย: ส่งต่อให้ผู้บรรยาย C (กิตติทัต)]
""")

# ---------- 12. System block diagram ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "3.0  ภาพรวมระบบ : Power Stage + Control Stage")

# Power stage row
def block(x, y, w, h, label, sub="", fill=RGBColor(0x14, 0x33, 0x5C), line=CYAN):
    sh = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(x), Inches(y), Inches(w), Inches(h))
    sh.adjustments[0] = 0.10
    sh.line.color.rgb = line; sh.line.width = Pt(1.0)
    sh.fill.solid(); sh.fill.fore_color.rgb = fill
    sh.shadow.inherit = False
    tf = sh.text_frame; tf.word_wrap = True
    tf.margin_top = Inches(0.05); tf.margin_bottom = Inches(0.05)
    p = tf.paragraphs[0]; p.alignment = PP_ALIGN.CENTER
    r = p.add_run(); r.text = label; set_font(r, size=11, bold=True, color=WHITE)
    if sub:
        p2 = tf.add_paragraph(); p2.alignment = PP_ALIGN.CENTER
        r2 = p2.add_run(); r2.text = sub; set_font(r2, size=9, color=CYAN)

def arrow(x, y, w=0.4, h=0.25, color=GOLD):
    sh = s.shapes.add_shape(MSO_SHAPE.RIGHT_ARROW, Inches(x), Inches(y), Inches(w), Inches(h))
    sh.line.fill.background(); sh.fill.solid(); sh.fill.fore_color.rgb = color
    sh.shadow.inherit = False

add_text(s, 0.5, 1.30, 9.0, 0.35, "Power Stage", size=13, color=GOLD, bold=True)
block(0.50, 1.75, 1.55, 0.85, "DC Source\n0–60V / 5A", fill=RGBColor(0x1C, 0x4A, 0x80))
arrow(2.10, 2.05)
block(2.55, 1.75, 1.55, 0.85, "BESS\nLiFePO4 24V 10Ah", fill=RGBColor(0x1C, 0x4A, 0x80))
arrow(4.15, 2.05)
block(4.60, 1.75, 1.85, 0.85, "DRV8302 Bridge\n3-Phase Inverter", fill=RGBColor(0x2E, 0x5C, 0x10))
arrow(6.50, 2.05)
block(6.95, 1.75, 1.45, 0.85, "LC Filter\nLf 1.5mH / Cf 15µF", fill=RGBColor(0x2E, 0x5C, 0x10))
arrow(8.45, 2.05)
block(8.90, 1.75, 1.00, 0.85, "Load\n3-Φ Y", fill=RGBColor(0x2E, 0x5C, 0x10))

# Sensor row
add_text(s, 0.5, 3.00, 9.0, 0.35, "Sensing", size=13, color=GOLD, bold=True)
block(2.55, 3.45, 1.55, 0.70, "ACS712 ×3\nI_abc", fill=RGBColor(0x4A, 0x2E, 0x10))
block(4.60, 3.45, 1.85, 0.70, "Voltage Divider\nV_abc", fill=RGBColor(0x4A, 0x2E, 0x10))
block(6.95, 3.45, 1.45, 0.70, "AD7606 ADC\n16-bit, 8-ch", fill=RGBColor(0x4A, 0x2E, 0x10))

# Control stage
add_text(s, 0.5, 4.45, 9.0, 0.35, "Control Stage", size=13, color=GOLD, bold=True)
block(0.50, 4.90, 9.00, 1.85,
      "ESP32-WROOM-32D",
      "ISR @ 10 kHz  :  PLL → Park (abc→dq) → VSG Core (Swing Eq + Q-V Droop) → "
      "Inner PI Loop → Inverse Park → SVPWM → 6 × Gate Drive",
      fill=RGBColor(0x10, 0x35, 0x5C), line=GOLD)

add_text(s, 0.5, 6.85, 9.0, 0.3,
         "หมายเหตุ : ใส่ Galvanic Isolation + Fuse + E-Stop + DC-link cap ระหว่าง power stage และ control stage",
         size=10, color=GOLD, align=PP_ALIGN.CENTER)
add_footer(s, 12)
add_notes(s, """[เวลา ~2 นาที — ผู้บรรยาย: กิตติทัต เปิดส่วนวิธีดำเนินงาน]
"สวัสดีครับ ผมกิตติทัต จะนำเสนอวิธีดำเนินงานและการออกแบบครับ
เริ่มจากภาพรวมระบบที่แบ่งเป็น 3 ส่วน: Power Stage, Sensing และ Control Stage"

ไล่ตามทิศทางการไหลของพลังงาน (จากซ้ายไปขวา):
1. "DC Power Supply 0-60V/5A → ผ่าน BESS LiFePO4 24V/10Ah ที่ทำหน้าที่ buffer พลังงาน"
2. "เข้า DRV8302 ซึ่งเป็น 3-Phase MOSFET Bridge ทำหน้าที่ switching"
3. "ผ่าน LC Filter ที่ออกแบบ Lf 1.5 mH + Cf 15 µF ตัด harmonic"
4. "ออกสู่ AC Load 3 เฟส แบบ Y-balanced"

ส่วน Sensing:
"ใช้ ACS712 วัดกระแสแต่ละเฟส, Voltage Divider วัดแรงดัน
ทั้งหมดเข้า ADC AD7606 ซึ่งเป็น 16-bit 8-channel แบบ simultaneous sampling"

ส่วน Control:
"ESP32 รัน ISR ที่ 10 kHz ทำ algorithm ครบทั้ง PLL → Park → VSG Core → Inner PI → SVPWM
ออก 6 channel ของ Gate Drive ไป DRV8302"

หมายเหตุสำคัญ (กล่องล่าง):
"ตามที่อาจารย์กรุณาให้คำแนะนำ เราจะใส่ Galvanic Isolation, Fuse, E-Stop และ DC-link cap
เพื่อความปลอดภัยในการทำงานในห้อง lab"

คำตอบสำรอง:
Q: "ทำไม BESS อยู่หลัง DC Supply?"
A: "BESS ทำหน้าที่ buffer transient power เร็ว ๆ ส่วน DC Supply ให้ steady-state power ครับ"
""")

# ---------- 13. Hardware BoM ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "3.1  รายการอุปกรณ์ฮาร์ดแวร์หลัก  (Bill of Materials)")
bom = [
    ["#", "อุปกรณ์", "Part / Spec", "หน้าที่", "จำนวน"],
    ["1", "MCU", "ESP32-WROOM-32D", "VSG algorithm + 3-Φ PWM", "1"],
    ["2", "Power Bridge", "DRV8302 Shield", "3-Φ Inverter", "1"],
    ["3", "ADC", "AD7606 (16-bit, 8-ch sim.)", "อ่าน V/I พร้อมกัน", "1"],
    ["4", "Current Sensor", "ACS712-05B  (±5 A)", "วัด I_abc แต่ละเฟส", "3"],
    ["5", "Filter L", "1.5 mH, Sendust core, ≥5 A", "L-filter ขาออก", "3"],
    ["6", "Filter C", "15 µF AC Polypropylene", "C-filter (2 ตัว/เฟส)", "6"],
    ["7", "Damping R", "1 Ω, 25 W Al-clad", "อนุกรมกับ Cf", "3"],
    ["8", "BESS", "LiFePO4  24 V / 10 Ah", "Energy reservoir", "1"],
    ["9", "DC Supply", "0–60 V / 5 A", "Primary DC source", "1"],
    ["10", "AC Load", "Slide Rheostat 0–100 Ω / 200 W", "Balanced-Y load", "3"],
]
add_table(s, 0.3, 1.30, 9.4, 5.4, bom)
add_text(s, 0.3, 6.78, 9.4, 0.3,
         "TODO เพิ่ม : MOSFET part/V-I rating, DC-link cap, gate-driver isolation, fuse + E-stop  (เพื่อ safety review)",
         size=10, color=GOLD, align=PP_ALIGN.CENTER)
add_footer(s, 13)
add_notes(s, """[เวลา ~1 นาที — ผู้บรรยาย: กิตติทัต]
"BoM มีทั้งหมด 10 รายการหลัก แบ่งเป็น 3 กลุ่ม:
- Control: ESP32, AD7606
- Power: DRV8302, BESS, DC Supply
- Sensing: ACS712, Voltage Divider
- Passive: L, C, R, Load"

จุดที่ต้องเน้น (ราคารวมประมาณ):
- ESP32 ~200 บาท
- DRV8302 Shield ~1,500 บาท
- AD7606 module ~2,500 บาท
- LiFePO4 24V/10Ah ~3,500 บาท
- รวมประมาณ 12,000-15,000 บาท

ข้อจำกัด (กล่องล่าง — ระบุไว้ให้กรรมการเห็น):
"ตามที่ระบุไว้ในสไลด์ BoM ยังต้องเพิ่ม MOSFET, gate-driver isolation, fuse, E-stop
เพื่อ safety review ก่อนเริ่ม integration จริง"

คำตอบสำรอง:
Q: "DRV8302 รับได้ที่ V/I เท่าไหร่?"
A: "DRV8302 รองรับ 6-60V, 30A สูงสุดครับ พอดีกับขอบเขต 60V/300W ของเรา"

Q: "ทำไมเลือก AD7606 ไม่ใช้ ADC ในตัว ESP32?"
A: "ADC ใน ESP32 เป็น 12-bit, non-simultaneous ส่วน AD7606 เป็น 16-bit, simultaneous sampling จำเป็นสำหรับ 3-phase synchronous sampling ครับ"

Q: "ทำไม ACS712 ±5A พอที่ 300W?"
A: "300W ÷ (√3 × 24V) ≈ 7.2A peak — ACS712-20B (±20A) ปลอดภัยกว่า ต้องปรับครับ"
[Note: ระวังจุดนี้ — ACS712-05B อาจไม่พอที่ peak current]
""")

# ---------- 14. Firmware ISR timing ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "3.2  สถาปัตยกรรมเฟิร์มแวร์ + ISR Timing Budget")

add_text(s, 0.6, 1.30, 8.8, 0.4, "ISR @ 10 kHz  →  มีเวลา 100 µs ต่อรอบ",
         size=14, color=CYAN, bold=True)

isr = [
    ["บล็อกการคำนวณ", "เวลาประมาณ (µs)", "หมายเหตุ"],
    ["1. ADC Read (AD7606 × 6 ch)", "~12", "SPI @ 20 MHz"],
    ["2. Clarke + Park Transform (abc→dq)", "~5", "trig table lookup"],
    ["3. PLL หรือ SRF tracking", "~8", "low-bandwidth"],
    ["4. VSG Core (Swing Eq + Q–V Droop)", "~10", "P–ω + Q–V loops"],
    ["5. Inner PI (Vdq, Idq)", "~8", "cascaded PI"],
    ["6. Inverse Park + SVPWM Update", "~10", "duty 6 channels"],
    ["7. Protection (OC, OV, T)", "~5", "comparator-style"],
    ["รวม", "~58 µs  (จาก 100 µs)", "margin ~42 µs สำหรับ logging"],
]
add_table(s, 0.4, 1.85, 9.2, 4.6, isr)
add_text(s, 0.4, 6.55, 9.2, 0.5,
         "ทางเลือกสำรอง : ถ้า ESP32 ไม่พอให้ลดเป็น 5 kHz หรือย้ายไป TI C2000 (DSP)",
         size=11, color=GOLD, align=PP_ALIGN.CENTER, bold=True)
add_footer(s, 14)
add_notes(s, """[เวลา ~2 นาที — ผู้บรรยาย: กิตติทัต — สไลด์ตอบคำถาม "ESP32 ทันไหม"]
"สไลด์นี้สำคัญมากครับ เพราะเป็นการพิสูจน์ว่า ESP32 สามารถรัน VSG ที่ 10 kHz ได้"

อธิบายตารางทีละบล็อก:
1. "ADC Read 12 µs — SPI ที่ 20 MHz × 6 channel × 16 bit"
2. "Clarke + Park ~5 µs — ใช้ lookup table ของ sin/cos ลดการคำนวณ"
3. "PLL/SRF tracking ~8 µs — Low-bandwidth ไม่ใช่ทุก cycle"
4. "VSG Core ~10 µs — Swing Eq (1 integral) + Q-V Droop"
5. "Inner PI ~8 µs — 2 PI controllers (Vdq, Idq)"
6. "Inverse Park + SVPWM ~10 µs — duty update 6 channel"
7. "Protection ~5 µs — Compare กระแส/แรงดันกับ threshold"

รวม = 58 µs จาก 100 µs ที่มี
เหลือ margin ~42 µs สำหรับ:
- Communication overhead
- Data logging
- Background task (WiFi if needed)

ประเด็นสำคัญที่ต้องสื่อ:
"ESP32 ที่ 240 MHz dual-core มี FPU ที่ทำ floating-point ในชั้นเดียว
ค่าประมาณนี้มาจาก benchmarking ของ ESP32 ที่เผยแพร่ใน Espressif documentation
ถ้าจริง ๆ แล้วช้ากว่านี้ เรามี contingency plan อยู่ใน slide ความเสี่ยง"

ทางเลือกสำรอง (กล่องล่าง):
"ถ้า 10 kHz ไม่ไหว → ลดเป็น 5 kHz (margin 142 µs)
ถ้ายังไม่พอ → ย้ายไป TI C2000 LaunchPad (ใช้ CCS ที่ระบุใน scope)"

คำตอบสำรอง:
Q: "ตัวเลขนี้มาจาก measurement จริงหรือเดา?"
A: "ตอนนี้เป็น estimation จาก Espressif benchmark + paper ของคนที่ใช้ ESP32 ทำ motor control ครับ
จะ verify จริงในระยะที่ 4 (เฟิร์มแวร์) ถ้าเกิน budget จะปรับแผนทันที"
""")

# ---------- 15. Test plan ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "3.3  แผนการทดสอบและตัวชี้วัด (Test Plan + KPI)")

test = [
    ["สถานการณ์ทดสอบ", "เงื่อนไข", "ตัวชี้วัด (KPI)"],
    ["1. Step Load Change", "เพิ่ม-ลดโหลด 50% ทันที", "RoCoF, Frequency Nadir, Settling Time"],
    ["2. Weak Grid Operation", "เชื่อมต่อกริดที่ SCR ต่ำ", "Voltage/Current THD, P/Q tracking"],
    ["3. Islanded Mode", "ตัดออกจากกริด — Stand-alone", "Voltage Stability, Black-Start"],
    ["4. Parameter Sweep H, D", "H = 2–10 s, D = 5–50 pu/pu", "Optimal Region สำหรับ RoCoF spec"],
    ["5. VSG vs Droop Compare", "ใช้ Step Load เดียวกัน", "เทียบ Frequency Response ทั้งสอง"],
]
add_table(s, 0.3, 1.35, 9.4, 4.0, test)

add_panel(s, 0.5, 5.55, 9.0, 1.5)
add_text(s, 0.7, 5.65, 8.6, 0.35, "เกณฑ์ผ่าน (Acceptance Criteria)",
         size=13, color=GOLD, bold=True)
add_bullets(s, 0.7, 6.05, 8.6, 1.0, [
    "RoCoF  ≤  0.5 Hz/s  (สอดคล้อง IEEE 1547-2018)",
    "Frequency Nadir อยู่ใน 49.5 – 50.5 Hz  ที่ step load ≤ 50%",
    "Settling time  ≤  2 s",
], size=11)
add_footer(s, 15)
add_notes(s, """[เวลา ~1.5 นาที — ผู้บรรยาย: กิตติทัต]
"แผนการทดสอบมี 5 สถานการณ์ ครอบคลุมทั้ง dynamic และ steady-state"

อธิบายแต่ละสถานการณ์:
1. "Step Load Change — ทดสอบ inertial response ที่ดีที่สุด เพราะ disturbance ชัด"
2. "Weak Grid — ทดสอบความสามารถในการ stable ที่ SCR ต่ำ"
3. "Islanded Mode — ทดสอบว่า VSG ทำงานเดี่ยวได้จริง ตัดจากกริดแล้วไม่ trip"
4. "Parameter Sweep — สแกน H และ D หา optimal region ตามเงื่อนไข RoCoF"
5. "เปรียบเทียบ VSG vs Droop — ใช้ test condition เดียวกัน แสดงความเหนือกว่าของ VSG"

KPI ที่ใช้:
- RoCoF (Rate of Change of Frequency) — ตัวชี้วัด inertia
- Frequency Nadir — จุดต่ำสุดของความถี่หลัง disturbance
- Settling Time — เวลาที่ frequency กลับเข้าใกล้ nominal
- THD — ดูคุณภาพไฟฟ้า output
- P/Q tracking error — ดูความแม่นยำของ power control

เกณฑ์ผ่าน (กล่องล่าง):
"เกณฑ์เหล่านี้อ้างอิงจาก IEEE 1547-2018:
- RoCoF ≤ 0.5 Hz/s
- Nadir อยู่ใน 49.5-50.5 Hz
- Settling ≤ 2 วินาที"

คำตอบสำรอง:
Q: "Step Load ขนาดเท่าไหร่ที่จะใช้?"
A: "เริ่มที่ 20% step แล้วเพิ่มเป็น 50% ครับ — ไม่เกิน 50% เพราะ DC supply อาจไม่ทันชาร์จกลับ"

Q: "Weak Grid จะ simulate ยังไง?"
A: "ต่อ inductor 5-10 mH คั่นระหว่าง VSG กับ grid emulator ทำให้ SCR ลดลง"
""")

# ---------- 16. Gantt chart ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "4.1  แผนการดำเนินงาน  (Gantt Chart 16 สัปดาห์)")

gantt = [
    ["ระยะ / งาน", "ต.ค.\nW1-4", "พ.ย.\nW5-8", "ธ.ค.\nW9-12", "ม.ค.\nW13-16"],
    ["1. ศึกษาทฤษฎี + เอกสาร", "███", "█", "", ""],
    ["2. จำลองสถานการณ์ Simulink", "█", "███", "█", ""],
    ["3. ออกแบบฮาร์ดแวร์ + วงจรวัด", "", "██", "██", ""],
    ["4. พัฒนาเฟิร์มแวร์ ESP32", "", "█", "███", "█"],
    ["5. ประกอบ + ทดสอบกับฮาร์ดแวร์", "", "", "█", "███"],
    ["6. วิเคราะห์ผล + เขียนรายงาน", "", "", "", "███"],
]
add_table(s, 0.3, 1.35, 9.4, 5.0, gantt)

add_text(s, 0.3, 6.50, 9.4, 0.5,
         "ผู้รับผิดชอบ :   นายชินวัตร = (1)(2)(6)    นายฉัตรมงคล = (3)(5)    นายกิตติทัต = (4)(5)",
         size=11, color=CYAN, align=PP_ALIGN.CENTER, bold=True)
add_footer(s, 16)
add_notes(s, """[เวลา ~1 นาที — ผู้บรรยาย: กิตติทัต]
"แผนงาน 16 สัปดาห์ แบ่งเป็น 6 ระยะ มีการ overlap ระหว่างระยะเพื่อ pipeline งาน"

จุดที่ต้องเน้น:
- "ระยะ 1-2 ทำพร้อมกัน — ทฤษฎีและ simulation ไปด้วยกัน เพราะ Simulink ต้องการความเข้าใจทฤษฎีก่อน"
- "ระยะ 3-4 overlap — ออกแบบฮาร์ดแวร์เริ่มก่อน เฟิร์มแวร์ตามมา"
- "ระยะ 5 (ทดสอบ) อยู่ใน 3 สัปดาห์สุดท้าย เป็นจุดเสี่ยงที่สุด ถ้าฮาร์ดแวร์มาช้าจะกระทบ"
- "ระยะ 6 (รายงาน) ทำต่อเนื่องตั้งแต่สัปดาห์ที่ 14"

ผู้รับผิดชอบ (กล่องล่าง):
"ผู้บรรยายแต่ละคนรับผิดชอบงานตามที่ถนัด:
- ชินวัตร = ทฤษฎี + simulation + รายงาน (background ทฤษฎีแน่น)
- ฉัตรมงคล = ฮาร์ดแวร์ + ทดสอบ (background hardware)
- กิตติทัต = เฟิร์มแวร์ + ทดสอบ (background embedded)"

[หมายเหตุ: ให้ Napoleon ปรับการมอบหมายตามจริง]

คำตอบสำรอง:
Q: "ถ้าระยะใดล่าช้าจะทำยังไง?"
A: "เรามี risk plan ในสไลด์ถัดไป สำหรับแต่ละกรณีครับ"

Q: "ทำไมระยะ 5 มีแค่ 3 สัปดาห์?"
A: "เพราะ test cases เป็น automated test runs ไม่ต้อง manual operation นานครับ"
""")

# ---------- 17. Risk & contingencies ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "4.2  ความเสี่ยงและแผนสำรอง  (Risk & Mitigation)")

risk = [
    ["ความเสี่ยง", "โอกาส", "ผลกระทบ", "แผนสำรอง"],
    ["ESP32 ISR overrun ที่ 10 kHz", "กลาง", "สูง", "ลดเป็น 5 kHz หรือใช้ TI C2000 + CCS"],
    ["DRV8302 ไม่ทนที่ 60 V", "ต่ำ", "สูง", "ลดลงเป็น 24 V / 100 VA (scope รอง)"],
    ["LC Filter resonance ไม่ตรงคำนวณ", "กลาง", "กลาง", "ใส่ damping R + วัด BodePlot ใหม่"],
    ["BESS over-current", "ต่ำ", "สูง", "ใส่ Fuse + BMS + soft-start"],
    ["Hardware delay (ส่งของช้า)", "กลาง", "กลาง", "สอบด้วยผลจำลองอย่างเดียว"],
    ["RoCoF ไม่ผ่าน spec ใน Weak Grid", "กลาง", "กลาง", "ปรับ H, D ใหม่ + Adaptive VSG"],
    ["Sensor noise → instability", "กลาง", "กลาง", "Hardware LPF + Digital MA filter"],
]
add_table(s, 0.3, 1.35, 9.4, 5.5, risk)
add_footer(s, 17)
add_notes(s, """[เวลา ~1.5 นาที — ผู้บรรยาย: กิตติทัต]
"เราระบุ 7 risk หลัก แต่ละตัวมี mitigation ชัดเจน"

โฟกัส 3 risk ที่สำคัญที่สุด (ไม่ต้องอ่านทุกแถว):

1. "ESP32 ISR overrun — ความเสี่ยงสูงสุด เพราะถ้าไม่ทันจะส่งผลทุกอย่าง
   Mitigation: ลดความถี่เป็น 5 kHz หรือย้ายไป TI C2000 + CCS"

2. "DRV8302 ไม่ทนที่ 60V — Datasheet บอก 60V max แต่ derate เพื่อความปลอดภัย
   Mitigation: ลด DC bus เป็น 24V กำลังเป็น 100 VA"

3. "Hardware delay — ปัจจัยภายนอก ควบคุมไม่ได้
   Mitigation: ถ้าฮาร์ดแวร์ไม่มา ส่งแค่ผล simulation ก่อน hardware integration ทำตอน final defense"

ประเด็นที่ต้องสื่อ:
"การมี risk plan แสดงให้กรรมการเห็นว่าเราคิดถึง failure modes ไม่ใช่ assume ว่าทุกอย่างจะ smooth
และมีแผน B ทุกข้อ"

คำตอบสำรอง:
Q: "ทำไมโอกาส ESP32 overrun เป็น 'กลาง' ไม่ใช่ 'สูง'?"
A: "เพราะมีงาน ESP32 motor control ที่รัน 10-20 kHz สำเร็จแล้ว แต่ VSG คำนวณหนักกว่า motor control ครับ"

Q: "ถ้า ESP32 พอ scale up ไปขนาดใหญ่ได้ไหม?"
A: "ในระดับนี้ (300W) ใช่ครับ แต่ scale ไป kW จะเริ่มจำกัดที่ ADC throughput และ PWM resolution ไม่ใช่ CPU"
""")

# ---------- 18. Deliverables + Q&A ----------
s = new_slide()
add_accent_stripe(s)
add_title(s, "5.  ผลที่คาดว่าจะได้รับ และคำถาม–คำตอบ")

add_text(s, 0.6, 1.30, 8.8, 0.45, "ผลที่คาดว่าจะได้รับ",
         size=15, color=CYAN, bold=True)
add_bullets(s, 0.6, 1.80, 8.8, 3.5, [
    ("Simulink Model", "แบบจำลอง VSG ที่แม่นยำสำหรับใช้อ้างอิงเชิงวิชาการ"),
    ("Parameter Guideline", "ระเบียบวิธีจูน H, D สำหรับวิศวกรไฟฟ้านำไปใช้"),
    ("Hardware Prototype", "ชุดต้นแบบ 300 W ควบคุมด้วย ESP32 ที่ทำงานได้จริง"),
    ("Grid Stability Contribution", "แนวทางเพิ่มเสถียรภาพให้กับ Weak Grid และ Microgrid"),
    ("Knowledge Transfer", "องค์ความรู้ GFM/VSG บน MCU ราคาประหยัด เผยแพร่ในไทย"),
], size=13)

add_panel(s, 1.5, 5.50, 7.0, 1.6, RGBColor(0x1C, 0x4A, 0x80))
add_text(s, 1.5, 5.85, 7.0, 0.6, "Q  &  A",
         size=32, color=GOLD, bold=True, align=PP_ALIGN.CENTER)
add_text(s, 1.5, 6.55, 7.0, 0.4, "ขอบคุณคณะกรรมการที่ให้ข้อเสนอแนะครับ",
         size=14, color=WHITE, align=PP_ALIGN.CENTER)
add_footer(s, 18)
add_notes(s, """[เวลา ~1 นาที — ผู้บรรยาย: ทั้ง 3 คนปิดร่วมกัน]

ผู้บรรยาย A (ชินวัตร): "สรุปผลที่คาดว่าจะได้รับ 5 ข้อ — เน้นว่าเป็นทั้ง academic contribution และ practical output"

อ่านสั้น ๆ:
1. Simulink Model ที่เปิดให้คนอื่นใช้อ้างอิงได้
2. Guideline การจูน H, D ที่เป็นรูปธรรม
3. Hardware Prototype 300W ที่ทำงานได้จริง
4. แสดง contribution ต่อ Grid Stability
5. Knowledge transfer ของการใช้ ESP32 ใน GFM ในไทย

ปิดท้าย:
"ทั้งหมดนี้คือโครงงานของเราครับ ขอบคุณคณะกรรมการที่สละเวลารับฟัง
ขอเปิดให้กรรมการสอบถาม / ให้คำแนะนำครับ"

[เตรียมตัวสำหรับ Q&A 10-15 นาที]

คำถามที่กรรมการมักถามใน proposal defense:
1. "ทำไมเลือกหัวข้อนี้?" — ตอบ: gap ในไทย + ความสนใจส่วนตัว + อุปกรณ์มีพร้อม
2. "ความใหม่ (novelty) อยู่ที่ไหน?" — ตอบ: ESP32 + Thai grid context + low-cost approach
3. "ถ้าไม่สำเร็จจะทำยังไง?" — ตอบ: มี contingency plan ใน slide ความเสี่ยง
4. "วัด RoCoF ยังไงในระบบ 300W?" — ตอบ: ใช้ frequency estimation algorithm จาก voltage zero-cross
5. "BESS 240Wh พอไหม?" — ตอบ: พอสำหรับ transient response ไม่ใช่ continuous run
6. "ทำไมไม่ใช้ FPGA?" — ตอบ: FPGA เกินความจำเป็น + curve learning สูง + cost สูงกว่า ESP32 มาก
7. "จะ publish ที่ไหน?" — ตอบ: ECTI หรือ IEEE PES Asia-Pacific (ถ้าผลออกดี)

Tip สำหรับ Q&A:
- ฟังคำถามให้จบก่อนตอบ
- ถ้าไม่เข้าใจ ขอให้กรรมการอธิบายอีกครั้ง
- ถ้าตอบไม่ได้ บอกตรง ๆ ว่า "ยังไม่ได้พิจารณาเรื่องนี้ จะกลับไปศึกษาเพิ่มครับ"
- อย่าเถียงกรรมการ ให้รับคำแนะนำเป็น input
""")

# ------------------ save ------------------
prs.save(OUTPUT)
print(f"OK  ->  {OUTPUT}")
print(f"Total slides: {len(prs.slides)}")
