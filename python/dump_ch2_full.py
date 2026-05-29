"""Dump Chapter 2 full text from 66AOS02-แก้.docx (paragraphs 64..164)."""
from docx import Document
import sys

sys.stdout.reconfigure(encoding="utf-8")
doc = Document(r"D:\workspace\engineering\vsg-project\docs\thesis\66AOS02-แก้.docx")

for i, p in enumerate(doc.paragraphs):
    if 64 <= i <= 165:
        style = p.style.name if p.style else "None"
        print(f"[{i}] ({style})")
        print(p.text)
        print()

print("=== TABLE 0 (GFL vs GFM comparison) ===")
t = doc.tables[0]
for r in t.rows:
    print(" | ".join(c.text for c in r.cells))
