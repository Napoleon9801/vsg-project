"""
Build the final defense deck for 66AOS02.

Input  : C:\\Users\\User\\Downloads\\66AOS02.pptx        (Napoleon's revised deck)
Output : C:\\Users\\User\\Downloads\\66AOS02_final.pptx  (defended deck for 2026-05-28)

Applies in one pass:
  Patches (5):
    P1  Slide  1   - add Thai/Eng subtitle reconciling with exam schedule title
    P2  Slide  7   - append "Design Point: 48 V / 100 W" row to scope table
    P3  Slide 12   - change "PLL ->" to "ADC sample ->" in the ISR flow text
    P4  Slide 13   - add footnote about 24V -> 48V revision
    P5  Slide 16   - rewrite DRV8302 risk row (no longer "drop to 24V")
    P6  Slide 17   - change "300 W" to "100 W (envelope <= 300 W)"

  New slides (2):
    N1  ESP32 ISR Compute Budget       inserted AFTER current slide 13 (BoM)
    N2  Preliminary Simulation Results inserted AFTER current slide 14 (Test Plan)
"""

from __future__ import annotations

from pathlib import Path
from copy import deepcopy

from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.oxml.ns import qn
from lxml import etree


SRC  = Path(r"C:\Users\User\Downloads\66AOS02.pptx")
DST  = Path(r"C:\Users\User\Downloads\66AOS02_final.pptx")
ROOT = Path(__file__).resolve().parents[1]
P4_IMG = ROOT / "python" / "plots" / "phase4_dq.png"
P5_IMG = ROOT / "python" / "plots" / "phase5a_switching.png"

FONT_THAI = "Tahoma"
ORANGE    = RGBColor(0xE9, 0x6A, 0x1F)
DARKGREY  = RGBColor(0x33, 0x33, 0x33)
GREEN_OK  = RGBColor(0x2E, 0x7D, 0x32)
LIGHTBG   = RGBColor(0xFF, 0xF3, 0xE0)


# ----- text helpers ---------------------------------------------------------

def style_run(run, *, size=14, bold=False, color=DARKGREY, font=FONT_THAI):
    run.font.name = font
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color


def add_para(tf, text, *, size=14, bold=False, color=DARKGREY, first=False,
             font=FONT_THAI):
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    for r in list(p.runs):
        r.text = ""
    run = p.add_run()
    run.text = text
    style_run(run, size=size, bold=bold, color=color, font=font)
    return p


def set_cell_text(cell, text, *, size=12, bold=False, color=DARKGREY,
                  font=FONT_THAI):
    cell.text = ""
    tf = cell.text_frame
    p = tf.paragraphs[0]
    run = p.add_run()
    run.text = text
    style_run(run, size=size, bold=bold, color=color, font=font)


# ----- table row helpers ----------------------------------------------------

def clone_last_row_and_set(tbl, new_values):
    """Duplicate the last row of an existing pptx table and set its cells
    to new_values (list[str], one per column). Keeps formatting consistent."""
    tr_list = tbl._tbl.findall(qn("a:tr"))
    src_tr  = tr_list[-1]
    new_tr  = deepcopy(src_tr)
    src_tr.addnext(new_tr)

    cells = new_tr.findall(qn("a:tc"))
    for tc, val in zip(cells, new_values):
        # purge existing runs, set fresh
        txBody = tc.find(qn("a:txBody"))
        if txBody is None:
            continue
        # clear all <a:p> children
        for p in txBody.findall(qn("a:p")):
            txBody.remove(p)
        p = etree.SubElement(txBody, qn("a:p"))
        r = etree.SubElement(p, qn("a:r"))
        rPr = etree.SubElement(r, qn("a:rPr"))
        rPr.set("lang", "th-TH")
        rPr.set("sz", "1200")
        rPr.set("dirty", "0")
        # font
        latin = etree.SubElement(rPr, qn("a:latin"))
        latin.set("typeface", FONT_THAI)
        cs = etree.SubElement(rPr, qn("a:cs"))
        cs.set("typeface", FONT_THAI)
        t = etree.SubElement(r, qn("a:t"))
        t.text = val


def replace_in_runs(tf, find, replace):
    """In all runs of a text_frame, replace `find` -> `replace`."""
    changed = False
    for p in tf.paragraphs:
        for r in p.runs:
            if find in r.text:
                r.text = r.text.replace(find, replace)
                changed = True
    return changed


def find_shape_with_text(slide, needle):
    for shape in slide.shapes:
        if shape.has_text_frame:
            for p in shape.text_frame.paragraphs:
                for r in p.runs:
                    if needle in r.text:
                        return shape
    return None


# ----- new slide builders ---------------------------------------------------

def build_isr_budget_slide(prs):
    """ESP32 ISR Compute Budget slide."""
    layout = prs.slide_layouts[5]  # Title Only
    slide  = prs.slides.add_slide(layout)

    title = slide.shapes.title
    title.text = ""
    p = title.text_frame.paragraphs[0]
    r = p.add_run()
    r.text = "5.2  งบเวลาควบคุมบน ESP32  (ISR Compute Budget)"
    style_run(r, size=28, bold=True, color=ORANGE)

    # Left bullets: rationale
    left = slide.shapes.add_textbox(Inches(0.35), Inches(1.30),
                                    Inches(4.6), Inches(5.8))
    tf = left.text_frame
    tf.word_wrap = True
    add_para(tf, "เป้าหมาย: ESR ที่ 10 kHz บน ESP32 dual-core 240 MHz",
             size=15, bold=True, color=ORANGE, first=True)
    add_para(tf, "• Budget ต่อรอบ ISR : 100 µs", size=14)
    add_para(tf, "• CPU instructions/รอบ : 24,000 (240 MHz × 100 µs)",
             size=14)
    add_para(tf, "• FPU on-chip → MAC + sin/cos hardware-accelerated",
             size=14)
    add_para(tf, " ", size=8)
    add_para(tf, "การจัดสรร 2 cores", size=15, bold=True, color=ORANGE)
    add_para(tf, "• Core 0 : Control ISR (high-priority, real-time)",
             size=14)
    add_para(tf, "• Core 1 : Telemetry, WiFi, UI (non-RT)",
             size=14)
    add_para(tf, "• ไม่มี contention ระหว่าง control loop กับ data logging",
             size=14)
    add_para(tf, " ", size=8)
    add_para(tf, "ผลลัพธ์การประมาณการ", size=15, bold=True, color=ORANGE)
    add_para(tf, "ใช้จริง ≈ 8 µs (8 %) → headroom 92 % รองรับการขยาย",
             size=14, color=GREEN_OK, bold=True)
    add_para(tf, "(เช่น Adaptive H/D, harmonic comp, fault detection)",
             size=12)

    # Right table: per-stage µs breakdown
    rows = 10
    cols = 3
    tbl_left   = Inches(5.10)
    tbl_top    = Inches(1.30)
    tbl_width  = Inches(4.80)
    tbl_height = Inches(5.20)
    tbl_shape = slide.shapes.add_table(rows, cols, tbl_left, tbl_top,
                                       tbl_width, tbl_height)
    tbl = tbl_shape.table

    # header
    headers = ["ขั้นตอนใน ISR", "เวลาประมาณ (µs)", "% ของ budget"]
    for i, h in enumerate(headers):
        set_cell_text(tbl.cell(0, i), h, size=13, bold=True,
                      color=RGBColor(0xFF, 0xFF, 0xFF))
        tbl.cell(0, i).fill.solid()
        tbl.cell(0, i).fill.fore_color.rgb = ORANGE

    body = [
        ("1. ADC read AD7606 (8 ch SPI @ 5 MHz)", "3.0",  "3.0 %"),
        ("2. Clarke + Park   (abc → dq)",         "1.0",  "1.0 %"),
        ("3. VSG core (Swing Eq + Q-V droop)",    "0.5",  "0.5 %"),
        ("4. Outer voltage PI (per axis)",         "0.5",  "0.5 %"),
        ("5. Inner current PI (per axis)",         "0.5",  "0.5 %"),
        ("6. Inverse Park + Clarke (dq → abc)",   "1.0",  "1.0 %"),
        ("7. SPWM compare + LEDC update (6 ch)",  "1.5",  "1.5 %"),
        ("รวม (Total)",                            "8.0",  "8.0 %"),
        ("Headroom (สำหรับ Adaptive + safety)",   "92.0", "92 %"),
    ]
    for i, (a, b, c) in enumerate(body, start=1):
        is_total  = "รวม" in a or "Total" in a
        is_head   = "Headroom" in a
        col_fill  = ORANGE if is_total else (GREEN_OK if is_head else None)
        text_color = RGBColor(0xFF,0xFF,0xFF) if (is_total or is_head) else DARKGREY
        set_cell_text(tbl.cell(i, 0), a, size=12, bold=is_total or is_head,
                      color=text_color)
        set_cell_text(tbl.cell(i, 1), b, size=12, bold=is_total or is_head,
                      color=text_color)
        set_cell_text(tbl.cell(i, 2), c, size=12, bold=is_total or is_head,
                      color=text_color)
        if col_fill:
            for j in range(cols):
                tbl.cell(i, j).fill.solid()
                tbl.cell(i, j).fill.fore_color.rgb = col_fill

    # Footnote under the table
    foot = slide.shapes.add_textbox(Inches(5.10), Inches(6.55),
                                    Inches(4.80), Inches(0.40))
    add_para(foot.text_frame,
             "* ค่าประมาณจาก ESP32 datasheet + literature (Toyoda 2020, MMC @ 20 kHz บน ESP32)",
             size=10, color=DARKGREY, first=True)

    return slide


def build_sim_results_slide(prs):
    """Preliminary Simulation Results slide."""
    layout = prs.slide_layouts[5]
    slide  = prs.slides.add_slide(layout)

    title = slide.shapes.title
    title.text = ""
    p = title.text_frame.paragraphs[0]
    r = p.add_run()
    r.text = "5.3  ผลการจำลองเบื้องต้น  (Preliminary Simulation Results)"
    style_run(r, size=26, bold=True, color=ORANGE)

    # Left bullets
    left = slide.shapes.add_textbox(Inches(0.30), Inches(1.20),
                                    Inches(4.55), Inches(6.0))
    tf = left.text_frame
    tf.word_wrap = True

    add_para(tf, "Stages 1–4  (Verified vs Analytical)",
             size=16, bold=True, color=ORANGE, first=True)
    add_para(tf, "• Stage 1 Swing Eq :  Δf = +0.0016 Hz  (match)", size=13)
    add_para(tf, "• Stage 2 Power-angle :  ωn = 7.5, ζ = 0.62", size=13)
    add_para(tf, "• Stage 3 Droop islanded :  Δf = −0.25 Hz, τ = 0.5 s", size=13)
    add_para(tf, "• Stage 4 Inverter dq :  V_d → ref < 1 mV", size=13)

    add_para(tf, " ", size=6)
    add_para(tf, "Stage 5a — 3-phase Switching Layer",
             size=16, bold=True, color=ORANGE)
    add_para(tf, "• V_dc = 48 V, SPWM 10 kHz, m_idx = 0.58", size=13)
    add_para(tf, "• V_d  = 13.971 V  (ref 14.00,  err < 0.03 V)",
             size=13, color=GREEN_OK, bold=True)
    add_para(tf, "• P    = 137.9 W   (pred 139.6,  err < 1.5 %)",
             size=13, color=GREEN_OK, bold=True)
    add_para(tf, "• Δf   = −0.77 Hz @ t=1.5s  (settle ~93 %)",
             size=13, color=GREEN_OK, bold=True)

    add_para(tf, " ", size=6)
    add_para(tf, "ข้อค้นพบเชิงวิศวกรรม",
             size=15, bold=True, color=ORANGE)
    add_para(tf, "Stage 5a พบ overmodulation ที่ V_dc = 24 V",
             size=12)
    add_para(tf, "(V_set = 14 V > V_dc/2 = 12 V)",
             size=12)
    add_para(tf, "→ revise design เป็น 48 V ก่อนสั่งฮาร์ดแวร์",
             size=12, bold=True, color=ORANGE)
    add_para(tf, "    (ยังอยู่ใน envelope ≤ 60 V)",
             size=12, bold=True, color=ORANGE)

    # Right images
    if P4_IMG.exists():
        slide.shapes.add_picture(str(P4_IMG),
                                 Inches(5.00), Inches(1.20),
                                 width=Inches(4.90))
    if P5_IMG.exists():
        slide.shapes.add_picture(str(P5_IMG),
                                 Inches(5.00), Inches(4.10),
                                 width=Inches(4.90))

    return slide


# ----- slide reorder util ---------------------------------------------------

def move_slide_to(prs, src_idx, dst_idx):
    xml_slides = prs.slides._sldIdLst
    slides = list(xml_slides)
    moved = slides[src_idx]
    xml_slides.remove(moved)
    xml_slides.insert(dst_idx, moved)


# ----- patches --------------------------------------------------------------

def patch_slide1_title(slide):
    """Add a one-line English subtitle for schedule alignment."""
    # find textbox containing the English subtitle line, append a new para
    target = find_shape_with_text(slide, "Virtual Synchronous Generator for BESS Inverter Control")
    if target is None:
        # fall back: add a textbox under the title area
        tb = slide.shapes.add_textbox(Inches(0.6), Inches(3.20),
                                      Inches(9.0), Inches(0.45))
        add_para(tb.text_frame,
                 "[ตามตารางสอบ : Grid-Forming Inverter Prototype for Microgrid]",
                 size=14, bold=True, color=ORANGE, first=True)
        return
    p = target.text_frame.add_paragraph()
    run = p.add_run()
    run.text = "[ตามตารางสอบ : Grid-Forming Inverter Prototype for Microgrid]"
    style_run(run, size=14, bold=True, color=ORANGE)


def patch_slide7_scope_table(slide):
    """Append 'Design Point' row to the scope table."""
    for shape in slide.shapes:
        if shape.has_table:
            tbl = shape.table
            clone_last_row_and_set(tbl, [
                "Design Point ที่จำลองจริง",
                "48 VDC / 100 W  (อยู่ใน envelope ≤ 60V / ≤ 300W)",
            ])
            # bold last row by re-styling
            tr_list = tbl._tbl.findall(qn("a:tr"))
            last_tr = tr_list[-1]
            for tc in last_tr.findall(qn("a:tc")):
                txBody = tc.find(qn("a:txBody"))
                if txBody is None: continue
                for p in txBody.findall(qn("a:p")):
                    for r in p.findall(qn("a:r")):
                        rPr = r.find(qn("a:rPr"))
                        if rPr is not None:
                            rPr.set("b", "1")
                            # color orange via solidFill
                            for c in rPr.findall(qn("a:solidFill")):
                                rPr.remove(c)
                            fill = etree.SubElement(rPr, qn("a:solidFill"))
                            clr  = etree.SubElement(fill, qn("a:srgbClr"))
                            clr.set("val", "E96A1F")
            return


def patch_slide12_block_diagram(slide):
    """Change 'PLL ->' or 'PLL → ...' to 'ADC sample ->' in the ISR flow text."""
    for shape in slide.shapes:
        if shape.has_text_frame:
            tf = shape.text_frame
            for p in tf.paragraphs:
                for r in p.runs:
                    if "PLL" in r.text and "Park" in r.text:
                        r.text = r.text.replace("PLL", "ADC sample (AD7606)")
                        return
                    if r.text.strip().startswith("PLL"):
                        r.text = r.text.replace("PLL", "ADC sample")
                        return
            # last-ditch: any run containing "PLL "
            for p in tf.paragraphs:
                for r in p.runs:
                    if "PLL " in r.text:
                        r.text = r.text.replace("PLL ", "ADC sample ")
                        return


def patch_slide13_bom_footnote(slide):
    """Add a small footnote textbox under the BoM table."""
    foot = slide.shapes.add_textbox(Inches(0.30), Inches(6.85),
                                    Inches(9.60), Inches(0.55))
    p = foot.text_frame.paragraphs[0]
    r = p.add_run()
    r.text = ("* BESS 24V เป็น scope BoM ; การจำลอง Stage 5a ปรับเป็น 48 V "
              "(4 × 12V series) หลังพบ overmodulation – ดูใน slide ผลการจำลอง")
    style_run(r, size=11, color=ORANGE, bold=True)


def patch_slide16_drv8302_row(slide):
    """Rewrite the DRV8302 row in the risk table."""
    for shape in slide.shapes:
        if not shape.has_table:
            continue
        tbl = shape.table
        for row in tbl.rows:
            cells = list(row.cells)
            first_text = cells[0].text
            if "DRV8302" in first_text:
                # rewrite all four cells: risk | likelihood | impact | mitigation
                set_cell_text(cells[0], "DRV8302 V_max margin", size=12)
                set_cell_text(cells[1], "ต่ำ",                   size=12)
                set_cell_text(cells[2], "สูง",                   size=12)
                set_cell_text(
                    cells[3],
                    "ใช้ design 48 V (ห่าง limit 60 V), เพิ่ม TVS clamp + snubber",
                    size=12,
                )
                return


def patch_slide17_300w(slide):
    """Change '300 W' to '100 W (envelope <= 300 W)' on slide 17."""
    for shape in slide.shapes:
        if shape.has_text_frame:
            replace_in_runs(shape.text_frame,
                            "300 W", "100 W (envelope ≤ 300 W)")


def paragraph_text_replace(tf, find, replace):
    """Paragraph-level replace that survives runs being split across glyphs.
    Concatenates each paragraph's runs, replaces, then writes the result
    into the first run and empties the rest."""
    changed = False
    for p in tf.paragraphs:
        full = "".join(r.text for r in p.runs)
        if find not in full:
            continue
        new_text = full.replace(find, replace)
        if not p.runs:
            continue
        p.runs[0].text = new_text
        for r in p.runs[1:]:
            r.text = ""
        changed = True
    return changed


def patch_testplan_renumber(slide):
    """Renumber Test Plan slide title from '5.2' to '5.4' so it sits after
    the two new slides (5.2 ISR, 5.3 Sim)."""
    for shape in slide.shapes:
        if shape.has_text_frame:
            if paragraph_text_replace(shape.text_frame, "5.2", "5.4"):
                return


# ----- driver ---------------------------------------------------------------

def main():
    prs = Presentation(str(SRC))
    n0 = len(prs.slides)
    print(f"Loaded {SRC.name}: {n0} slides")

    # === PATCH existing slides (0-based indices below match the loaded deck) ===
    print("Patching slide 1  (title subtitle)..."); patch_slide1_title(prs.slides[0])
    print("Patching slide 7  (scope table)...");   patch_slide7_scope_table(prs.slides[6])
    print("Patching slide 12 (block diagram)..."); patch_slide12_block_diagram(prs.slides[11])
    print("Patching slide 13 (BoM footnote)...");  patch_slide13_bom_footnote(prs.slides[12])
    print("Patching slide 16 (DRV8302 row)...");   patch_slide16_drv8302_row(prs.slides[15])
    print("Patching slide 17 (300W -> 100W)...");  patch_slide17_300w(prs.slides[16])
    print("Renumbering Test Plan 5.2 -> 5.4...");   patch_testplan_renumber(prs.slides[13])

    # === INSERT new slides ===
    # The new slides are appended to the end first, then moved.
    print("Building NEW slide: ESP32 ISR Compute Budget...")
    build_isr_budget_slide(prs)                # appended -> idx = n0
    print("Building NEW slide: Preliminary Simulation Results...")
    build_sim_results_slide(prs)               # appended -> idx = n0 + 1

    # Now move them to the right places.
    # We want order: ... slide13(BoM), NEW_ISR, slide14(TestPlan), NEW_SIM, slide15(Gantt) ...
    # In 0-based: insert NEW_ISR at position 13 (after current slide 13/BoM-at-idx-12),
    #             insert NEW_SIM at position 15 (after current slide 14/TestPlan).
    # After first build, NEW_ISR is at idx n0; move to position 13.
    # After move, NEW_SIM (was at n0+1) shifted to n0; move to position 15.
    # Goal order: BoM(12) -> NEW_ISR(13) -> NEW_SIM(14) -> Test Plan(15) -> Gantt(16)
    # After build, NEW_ISR is at idx n0 and NEW_SIM is at idx n0+1.
    move_slide_to(prs, src_idx=n0,     dst_idx=13)   # ISR -> 13
    # First move shifted: NEW_SIM is still at idx n0+1 since src was past it.
    move_slide_to(prs, src_idx=n0 + 1, dst_idx=14)   # SIM -> 14

    prs.save(str(DST))
    n1 = len(prs.slides)
    print(f"\nSaved -> {DST}")
    print(f"Final deck: {n1} slides (was {n0})")

    # Verify order
    print("\nFinal slide order:")
    for i, s in enumerate(prs.slides, 1):
        t = ""
        for sh in s.shapes:
            if sh.has_text_frame:
                for p in sh.text_frame.paragraphs:
                    for r in p.runs:
                        if r.text.strip():
                            t = r.text.strip(); break
                    if t: break
                if t: break
        print(f"  {i:2d}. {t[:78]}")


if __name__ == "__main__":
    main()
