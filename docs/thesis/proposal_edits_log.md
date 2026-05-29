# Proposal 66AOS02 — Edit Log

**File edited**: `docs/thesis/66AOS02-แก้.docx`
**Backups**:
- `66AOS02-แก้.backup-2026-05-28.docx` (before round-1 BoM + equation fills)
- `66AOS02-แก้.backup-2026-05-29-before-ch2-rewrite.docx` (before Ch.2 rewrite)

**Edit rounds**:
1. **2026-05-28** — BoM + equation/symbol fills (22 edits, script `apply_proposal_edits.py`)
2. **2026-05-29** — Ch.2 full rewrite (1 chapter, 142 ops, script `rewrite_ch2.py`)

---

# Round 1 — 2026-05-28 (22 edits)

**Script**: `python/apply_proposal_edits.py` (reproducible — re-run on the backup to redo)
**Total edits**: 22

Edits reconcile the proposal against the post-Stage-5a design pivot (24 V → 48 V) and fill in 9 missing equations + 10 missing variable symbols flagged in `docs/notes/defense_qa_bank.md` (issues C3, C5, C8).

> All equations are written as **plain ASCII/Unicode** so they survive python-docx writes. Once approved, Napoleon should re-typeset them with Word's Equation Editor for the final submission look.

---

## 1. Hardware BoM updates (Tables 1–2)

### E1 — Table 1, Row 5 (`L_f` filter inductor) — fixes C5
| Field | Before | After |
|---|---|---|
| รหัสพาร์ท/ข้อมูลจำเพาะ | `1.5 mH, ทนกระแส >= 5 A` | `1.0 mH, ทนกระแส >= 5 A` |

**Reason**: Stage 4 & 5a simulation uses `L_f = 1.0 mH`. Keeping 1.5 mH in BoM would force a re-run + new resonance frequency calc. Cleaner to bring BoM in line with sim. Resonance stays at **f_res ≈ 1.45 kHz**, switching at **10 kHz**, attenuation **~40 dB** — all targets met.

### E2 — Table 2, Row 3 (`Battery`) — fixes C3 (HIGH RISK)
| Field | Before | After |
|---|---|---|
| รหัสพาร์ท/ข้อมูลจำเพาะ | `LiFePO4 Battery 24 V, 10 Ah` | `LiFePO4 Battery 12 V 10 Ah ต่ออนุกรม 4 ก้อน (รวม 48 V 10 Ah)` |
| จำนวน | `1 ชุด` | `4 ก้อน (1 ชุด stack)` |

**Reason**: Stage 5a found V_d = 14 V peak phase exceeded V_dc/2 = 12 V linear SPWM range on a 24 V bus → overmodulation. Switching to V_dc = 48 V gives modulation index 14/24 = 0.58 (comfortable linear range). 48 V is also the **C2000 + GaN contingency option** already named in the proposal — no scope rewrite needed.

> ⚠️ **Other BoM rows are still consistent** with the 48 V design:
> - DC Power Supply (0–60 V, 5 A) — covers 48 V ✓
> - DRV8302 Shield — rated up to 60 V ✓
> - ACS712-05B (±5 A) — fine at 48 V/100 W (I_max ≈ 2.4 A peak) ✓

---

## 2. Equations inserted (Section 2.2 + 2.3)

Originally these paragraphs were empty placeholders that Word would have rendered as MathType equation objects. python-docx returned `''` for all of them — they were never filled in.

### E3.1 — Eq. (2.1) Swing Equation @ para[80] · §2.2.1

```
2H · (dω/dt) = P_m − P_e − D·Δω                          ... (2.1)
```

### E3.2 / E3.3 — Eq. (2.2)/(2.3) P-f & Q-V droop (SG) @ para[94], [95] · §2.2.4

```
f − f_0 = − k_p · (P − P_0)                              ... (2.2)
V − V_0 = − k_q · (Q − Q_0)                              ... (2.3)
```

### E3.4 — Eq. (2.4) VSG core swing @ para[108] · §2.3.2

```
2H · (dω/dt) = P_ref − P_meas − D·(ω − ω_g)              ... (2.4)
```

### E3.5 — Eq. (2.5) VSG swing with droop term @ para[110] · §2.3.2

```
2H · (dω/dt) = P_ref + k_p·(ω_g − ω) − P_meas − D·(ω − ω_g)   ... (2.5)
```

### E3.6 / E3.7 — Eq. (2.6)/(2.7) Q-V dynamic + droop alt @ para[120], [121] · §2.3.3

```
K · (dE/dt) = Q_ref − Q_meas − D_q·(E − E_ref)           ... (2.6)
หรือรูป Droop:   E − E_0 = − k_q · (Q − Q_0)             ... (2.7)
```

### E3.8 / E3.9 — Eq. (2.8)/(2.9) Inner d/q current loop @ para[125], [126] · §2.3.4

```
V_d* = K_p·(i_d* − i_d) + K_i·∫(i_d* − i_d)dt − ω·L_f·i_q + V_d_ff   ... (2.8)
V_q* = K_p·(i_q* − i_q) + K_i·∫(i_q* − i_q)dt + ω·L_f·i_d + V_q_ff   ... (2.9)
```

Inner loop uses **dq decoupling feedforward** (`±ω·L_f·i_dq`) — matches Stage 5c (`phase5c_tuned.m`) implementation.

---

## 3. Variable symbols prepended (where docx had missing symbol slots)

The "โดยที่" definition lines all had a leading whitespace where the variable symbol was supposed to live (MathType inline object that python-docx couldn't render).

### §2.2.1 Swing equation — para[82]–[86]

| para | Before | After |
|---|---|---|
| 82 | ` คือ ค่าคงที่ความเฉื่อย…` | `H  คือ ค่าคงที่ความเฉื่อย…` |
| 83 | ` คือ ค่าเบี่ยงเบนของความเร็วเชิงมุม…` | `Δω คือ ค่าเบี่ยงเบนของความเร็วเชิงมุม…` |
| 84 | `  คือ กำลังกล…` | `P_m คือ กำลังกล…` |
| 85 | `  คือ กำลังไฟฟ้า…` | `P_e คือ กำลังไฟฟ้า…` |
| 86 | ` คือ สัมประสิทธิ์การหน่วง…` | `D  คือ สัมประสิทธิ์การหน่วง…` |

### §2.3.2 VSG core vars — para[112]–[115]

| para | Before | After |
|---|---|---|
| 112 | ` คือ Virtual inertia constant (s)` | `H   คือ Virtual inertia constant (s)` |
| 113 | `  คือ Virtual damping coefficient (pu/pu)` | `D   คือ Virtual damping coefficient (pu/pu)` |
| 114 | `  คือ Active power droop gain` | `k_p คือ Active power droop gain` |
| 115 | `  คือ Grid frequency reference…` | `ω_g คือ Grid frequency reference…` |

### §2.3.3 Q-V description — para[122]

| Before | After |
|---|---|
| `โดย  คือ virtual excitation inertia และ  คือ virtual voltage damping…` | `โดย K คือ virtual excitation inertia และ D_q คือ virtual voltage damping…` |

---

## 4. NOT TOUCHED (out of automated scope — needs manual / future work)

| Item | Why deferred |
|---|---|
| **Figure 3.1 block diagram** (para[178] caption only, no figure) | Needs Visio/Draw.io rendering — flag for manual insert |
| **Table 3 Gantt cells** (rows 2–7 all empty) | Advisor priority #1 but needs schedule decisions — Napoleon to fill weeks per phase |
| **บทคัดย่อ P26** | Stays at high-level overview, 24/48 V detail not appropriate at abstract level |
| **ขอบเขต P50 "≤60V/300W"** | Stays as safety envelope (48 V/100 W lives inside this) |
| **ประโยชน์ P60 "ขนาด 300 วัตต์"** | Could be refined to "100 W (within 300 W envelope)" — minor, defer |
| **In-line equation re-typesetting via Word Equation Editor** | python-docx cannot author OMML/MathML cleanly — plain-text now, MathType later |

---

## 5. Reproducibility

To re-apply on a fresh copy:

```powershell
# Restore from backup if needed
Copy-Item "D:\workspace\engineering\vsg-project\docs\thesis\66AOS02-แก้.backup-2026-05-28.docx" `
          "D:\workspace\engineering\vsg-project\docs\thesis\66AOS02-แก้.docx" -Force

# Re-run edits
D:\workspace\engineering\vsg-project\python\.venv\Scripts\python.exe `
  D:\workspace\engineering\vsg-project\python\apply_proposal_edits.py
```

Scripts:
- `python/inspect_proposal_docx.py` — dump paragraph indices + tables for recon
- `python/apply_proposal_edits.py` — apply all 22 edits + print before/after diff

---

## 6. Pre-defense checklist (post-edit)

| Check | Status |
|---|---|
| BoM 48 V battery (was Table 2 R3, now Table 3 R3 post-Ch.2 rewrite) | ✅ |
| L_f BoM matches sim (was Table 1 R5, now Table 2 R5) | ✅ |
| Swing Equation (2.1) | ✅ |
| P-f / Q-V droop SG (2.2)/(2.3) | ✅ |
| VSG core (2.4)/(2.5) | ✅ |
| Q-V VSG (2.6)/(2.7) | ✅ |
| Inner loop dq (2.8)/(2.9) → renumbered (2.13)/(2.14) after Ch.2 rewrite | ✅ |
| Variable symbols H, Δω, P_m, P_e, D, k_p, ω_g, K, D_q | ✅ |
| Figure 3.1 block diagram | ⚠️ TODO manual |
| Gantt Table 3 (now Table 4 post-Ch.2 rewrite) weeks | ⚠️ TODO manual |
| Word Equation Editor re-typeset | ⚠️ TODO before final submit |

---

# Round 2 — 2026-05-29 (Ch.2 full rewrite)

**Script**: `python/rewrite_ch2.py` (reproducible — restore from backup-2026-05-29 then re-run)
**Markdown draft**: `docs/thesis/chapter2_rewrite.md` (review-friendly source of truth)
**Operations**: 140 paragraphs + 2 tables inserted; 102 old elements deleted.

## Structural change: 2.1–2.5 → 2.1–2.7

| Old | New | Status |
|---|---|---|
| 2.1 GFL vs GFM | **2.1 GFL vs GFM** | ✅ tightened, table preserved |
| 2.2 SG Fundamentals | **2.2 SG Fundamentals** | ✅ dangling symbols fixed (H, D references) |
| 2.3 VSG Control Architecture | **2.3 VSG Control Architecture** | ✅ duplicated content removed |
| 2.4 Related Work | **2.4 Power Electronics for VSG** | ✨ **NEW SECTION** |
| 2.5 Standards | **2.5 Related Work** (renumbered) | ✅ + new comparison table 2.2 |
| — | **2.6 Standards** (renumbered) | ✅ |
| — | **2.7 Summary & Academic Gap** | ✨ **NEW SECTION** |

## New §2.4 — Power Electronics for VSG Implementation

This section fills the practical-engineering gap between abstract VSG algorithm and a working hardware:

- **2.4.1 Clarke + Park Transforms** (eq. 2.8, 2.9) — abc↔αβ↔dq math + amplitude-invariant rationale
- **2.4.2 Three-phase 2-Level VSI + SPWM** (eq. 2.10) — modulation index, the 24V→48V pivot story explained
- **2.4.3 LCL filter + Passive Damping** (eq. 2.11, 2.12) — resonance formula + R_d damping ratio + PWM-injection trade-off
- **2.4.4 dq Decoupling Feedforward** (eq. 2.13, 2.14) — cross-coupling cancellation, links to Stage 5c results
- **2.4.5 BESS Sizing** (eq. 2.15, 2.16) — inertial transient power and energy formulas with project numbers

## New §2.7 — Academic Gap

Four-bullet contribution statement positioning the project against literature:
1. VSG on low-cost MCU (ESP32 vs DSP)
2. End-to-end MATLAB → hardware chain at sub-kW
3. BESS + VSG integration with open documentation
4. Thai grid-code reference prototype

## Equation numbering map (old → new)

| Original | After Round 1 | After Ch.2 rewrite |
|---|---|---|
| Swing Eq | (2.1) | (2.1) — unchanged |
| P-f SG droop | (2.2) | (2.2) — unchanged |
| Q-V SG droop | (2.3) | (2.3) — unchanged |
| VSG swing | (2.4) | (2.4) — unchanged |
| VSG swing + droop | (2.5) | (2.5) — unchanged |
| Q-V VSG dynamic | (2.6) | (2.6) — unchanged |
| Q-V VSG droop | (2.7) | (2.7) — unchanged |
| Inner d-axis | (2.8) | **(2.13)** — renumbered |
| Inner q-axis | (2.9) | **(2.14)** — renumbered |
| NEW Clarke (αβ from abc) | — | **(2.8a, 2.8b)** |
| NEW Park (dq from αβ) | — | **(2.9a, 2.9b)** |
| NEW Modulation index | — | **(2.10)** |
| NEW LC resonance | — | **(2.11)** |
| NEW Damping ratio ζ | — | **(2.12)** |
| NEW BESS power sizing | — | **(2.15)** |
| NEW BESS energy sizing | — | **(2.16)** |

## Table index map

| Index | Content | Source |
|---|---|---|
| Table 0 | GFL vs GFM | rebuilt in Round 2 (was original Table 0 in pre-rewrite) |
| Table 1 | VSG variants comparison (NEW) | **added in Round 2** |
| Table 2 | BoM main (ESP32, MOSFET, sensor, filter…) | preserved (was Table 1) |
| Table 3 | BoM continued (R_d, divider, **battery**, PSU, rheostat) | preserved (was Table 2) |
| Table 4 | Gantt | preserved (was Table 3) |

## Files added in Round 2

- `python/dump_ch2_full.py` — recon dumper for Ch.2 paragraphs
- `python/rewrite_ch2.py` — full Ch.2 surgery (delete old, insert new)
- `docs/thesis/chapter2_rewrite.md` — markdown draft of the new Ch.2 (review-friendly)

## What still TODO after Round 2

| Item | Why deferred |
|---|---|
| **Word Equation Editor re-typeset** | python-docx writes plain text; MathType pass before final submit |
| **Figure 3.1 block diagram** | still caption-only — needs manual Visio/Draw.io insert |
| **Gantt Table 4 cell fills** | needs schedule decisions per phase |
| **Defense_qa_bank.md update** | paragraph anchors (P-numbers) all shift with rewrite — regenerate from new docx |
| **References / Bibliography** | citations (Beck, Zhong, Alipoor, D'Arco) referenced inline but no formal bib section yet |
