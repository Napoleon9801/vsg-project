"""
Apply BoM + equation edits to 66AOS02-แก้.docx.

Each edit function returns (location, before, after) tuples for the changelog.
"""
from docx import Document
from copy import deepcopy
from datetime import datetime
import sys

DOCX = r"D:\workspace\engineering\vsg-project\docs\thesis\66AOS02-แก้.docx"

sys.stdout.reconfigure(encoding="utf-8")

doc = Document(DOCX)
changes = []


def set_para_text_preserve_format(para, new_text):
    """Replace paragraph text but keep paragraph-level formatting (alignment, style).

    Any inline equation/image objects in the runs will be removed — acceptable here
    since target paragraphs are empty equation slots or symbol-missing lines.
    """
    if para.runs:
        first = para.runs[0]
        for r in para.runs[1:]:
            r._element.getparent().remove(r._element)
        first.text = new_text
    else:
        para.add_run(new_text)


def edit_para(idx, new_text, label):
    para = doc.paragraphs[idx]
    before = para.text
    set_para_text_preserve_format(para, new_text)
    changes.append((label, f"para[{idx}]", before, new_text))


def edit_table_cell(table_idx, row, col, new_text, label):
    cell = doc.tables[table_idx].rows[row].cells[col]
    before = cell.text
    # Clear all paragraphs, write into the first
    first_para = cell.paragraphs[0]
    # Remove extra paragraphs
    for p in cell.paragraphs[1:]:
        p._element.getparent().remove(p._element)
    set_para_text_preserve_format(first_para, new_text)
    changes.append((label, f"Table {table_idx} R{row}C{col}", before, new_text))


# ===========================================================================
# EDIT 1 — Table 1 Row 5 (Filter inductor L_f): 1.5 mH → 1.0 mH
# ===========================================================================
edit_table_cell(
    1, 5, 2,
    "1.0 mH, ทนกระแส >= 5 A",
    "E1: L_f mismatch (sim uses 1.0 mH)",
)

# ===========================================================================
# EDIT 2 — Table 2 Row 3 (Battery): 24V single → 4×12V stack = 48V
# ===========================================================================
edit_table_cell(
    2, 3, 2,
    "LiFePO4 Battery 12 V 10 Ah ต่ออนุกรม 4 ก้อน (รวม 48 V 10 Ah)",
    "E2a: Battery spec 24V → 48V stack",
)
edit_table_cell(
    2, 3, 4,
    "4 ก้อน (1 ชุด stack)",
    "E2b: Battery qty 1→4",
)

# ===========================================================================
# EDIT 3 — Insert plain-text equations into empty equation slots
# ===========================================================================
# 2.2.1 Swing Equation — slot at para[80]
edit_para(
    80,
    "    2H · (dω/dt) = P_m − P_e − D·Δω                          ... (2.1)",
    "E3.1: Swing Equation (2.1)",
)

# 2.2.4 Droop SG P-f and Q-V — slots at para[94] and [95]
edit_para(
    94,
    "    f − f_0 = − k_p · (P − P_0)                              ... (2.2)",
    "E3.2: P-f droop (2.2)",
)
edit_para(
    95,
    "    V − V_0 = − k_q · (Q − Q_0)                              ... (2.3)",
    "E3.3: Q-V droop (2.3)",
)

# 2.3.2 P-f Loop — slot at para[108]
edit_para(
    108,
    "    2H · (dω/dt) = P_ref − P_meas − D·(ω − ω_g)              ... (2.4)",
    "E3.4: VSG core swing (2.4)",
)

# 2.3.2 with droop term — slot at para[110]
edit_para(
    110,
    "    2H · (dω/dt) = P_ref + k_p·(ω_g − ω) − P_meas − D·(ω − ω_g)   ... (2.5)",
    "E3.5: VSG swing+droop (2.5)",
)

# 2.3.3 Q-V Loop — slots at para[120] and [121]
edit_para(
    120,
    "    K · (dE/dt) = Q_ref − Q_meas − D_q·(E − E_ref)           ... (2.6)",
    "E3.6: Q-V dynamic (2.6)",
)
edit_para(
    121,
    "    หรือรูป Droop:   E − E_0 = − k_q · (Q − Q_0)             ... (2.7)",
    "E3.7: Q-V droop alt (2.7)",
)

# 2.3.4 Inner Loop — slots at para[125] and [126]
edit_para(
    125,
    "    V_d* = K_p·(i_d* − i_d) + K_i·∫(i_d* − i_d)dt − ω·L_f·i_q + V_d_ff   ... (2.8)",
    "E3.8: Inner d-axis (2.8)",
)
edit_para(
    126,
    "    V_q* = K_p·(i_q* − i_q) + K_i·∫(i_q* − i_q)dt + ω·L_f·i_d + V_q_ff   ... (2.9)",
    "E3.9: Inner q-axis (2.9)",
)

# ===========================================================================
# EDIT 4 — Prepend missing symbols to "โดยที่" lines (variable definitions)
# ===========================================================================
# 2.2.1 vars at para[82]..[86]
edit_para(82,  "H  คือ ค่าคงที่ความเฉื่อย (Inertia constant) มีหน่วยเป็นวินาที (s)", "E4.1: prepend H")
edit_para(83,  "Δω คือ ค่าเบี่ยงเบนของความเร็วเชิงมุม (rad/s หรือ pu)",              "E4.2: prepend Δω")
edit_para(84,  "P_m คือ กำลังกลที่จ่ายเข้าโรเตอร์ (Mechanical power)",                "E4.3: prepend P_m")
edit_para(85,  "P_e คือ กำลังไฟฟ้าที่จ่ายออกจากสเตเตอร์ (Electrical power)",         "E4.4: prepend P_e")
edit_para(86,  "D  คือ สัมประสิทธิ์การหน่วง (Damping coefficient)",                  "E4.5: prepend D")

# 2.3.2 vars at para[112]..[115]
edit_para(112, "H   คือ Virtual inertia constant (s)",                                "E4.6: prepend H")
edit_para(113, "D   คือ Virtual damping coefficient (pu/pu)",                         "E4.7: prepend D")
edit_para(114, "k_p คือ Active power droop gain",                                     "E4.8: prepend k_p")
edit_para(115, "ω_g คือ Grid frequency reference (จาก PLL หรือ low-bandwidth tracking)", "E4.9: prepend ω_g")

# 2.3.3 vars at para[122]
edit_para(
    122,
    "\tโดย K คือ virtual excitation inertia และ D_q คือ virtual voltage damping ทำให้แรงดันออกของอินเวอร์เตอร์มีพลวัตคล้ายกับ field winding ของ SG",
    "E4.10: fill K + D_q in Q-V description",
)

# ===========================================================================
# SAVE
# ===========================================================================
doc.save(DOCX)

# ===========================================================================
# PRINT SUMMARY
# ===========================================================================
print(f"\n=== APPLIED {len(changes)} EDITS at {datetime.now():%Y-%m-%d %H:%M:%S} ===\n")
for label, loc, before, after in changes:
    print(f"[{label}]  {loc}")
    print(f"  BEFORE: {before!r}")
    print(f"  AFTER : {after!r}")
    print()
