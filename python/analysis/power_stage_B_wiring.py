"""
power_stage_B_wiring.py
VSG Power Stage — Approach B wiring diagram (TI DRV8302 shield).
Two panels:
  (1) DRV8302 detail: integrated gate driver + buck (5V) + current-sense driving
      6 external MOSFETs (3 half-bridge legs) in 3-PWM mode.
  (2) System overview: DRV8302 shield -> LC filter -> Y load, + ESP32 + sensing.

Output: python/plots/power_stage_B_wiring.png
NOTE: DRV8302 pins shown FUNCTIONALLY (names, not numbers) — verify vs datasheet.
"""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Circle

C_IC   = "#cfe8ff"; C_FET = "#ffe0b3"; C_PWR = "#ffd6d6"; C_PAS = "#e7f5d8"
C_MCU  = "#e6dcff"; C_LOAD = "#fff2b3"; C_BUCK = "#d8f3ef"
EDGE = "#333333"; RAILP = "#c0392b"; RAILN = "#2c3e50"; WIRE = "#444444"; SIG = "#1f77b4"


def box(ax, x, y, w, h, label, fc, fs=9, lw=1.4, weight="normal"):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.06",
                                fc=fc, ec=EDGE, lw=lw, zorder=3))
    ax.text(x + w/2, y + h/2, label, ha="center", va="center", fontsize=fs, zorder=4, weight=weight)


def wire(ax, pts, color=WIRE, lw=1.8, z=2, ls="-"):
    ax.plot([p[0] for p in pts], [p[1] for p in pts], color=color, lw=lw, zorder=z, ls=ls,
            solid_capstyle="round", solid_joinstyle="round")


def node(ax, x, y, color=WIRE, r=0.045):
    ax.add_patch(Circle((x, y), r, fc=color, ec=color, zorder=5))


def fet(ax, x, y, w, h, label):
    box(ax, x, y, w, h, label, C_FET, fs=7.5, weight="bold")


fig = plt.figure(figsize=(17, 9.2))
gs = fig.add_gridspec(1, 2, width_ratios=[1.05, 1.1], wspace=0.05)

# =====================================================================
#  PANEL 1 — DRV8302 detail driving the 3-phase bridge
# =====================================================================
ax1 = fig.add_subplot(gs[0, 0]); ax1.set_xlim(0, 11); ax1.set_ylim(0, 10); ax1.axis("off")
ax1.set_title("Panel 1  —  DRV8302 (3-PWM mode) driving 6× MOSFET bridge",
              fontsize=11.5, weight="bold", pad=10)

RAIL_T = 9.3; RAIL_B = 0.7
wire(ax1, [(0.6, RAIL_T), (10.6, RAIL_T)], color=RAILP, lw=3)
wire(ax1, [(0.6, RAIL_B), (10.6, RAIL_B)], color=RAILN, lw=3)
ax1.text(0.6, RAIL_T + 0.18, "+Vbus (40 V)", color=RAILP, fontsize=10, weight="bold")
ax1.text(0.6, RAIL_B - 0.34, "PGND", color=RAILN, fontsize=10, weight="bold")

# DRV8302 IC
dx, dy, dw, dh = 1.2, 2.6, 3.2, 5.2
box(ax1, dx, dy, dw, dh, "DRV8302\n(gate driver +\nbuck + sense)", C_IC, fs=10, weight="bold")
# PVDD top, GND bottom
wire(ax1, [(dx+0.6, dy+dh), (dx+0.6, RAIL_T)]); node(ax1, dx+0.6, RAIL_T)
ax1.text(dx+0.7, dy+dh+0.15, "PVDD", fontsize=7.5, color="#555")
wire(ax1, [(dx+0.6, dy), (dx+0.6, RAIL_B)]); node(ax1, dx+0.6, RAIL_B)
ax1.text(dx+0.7, dy-0.22, "GND", fontsize=7.5, color="#555")

# left logic pins (from ESP32 + config R)
left_pins = [
    (dy+4.6, "INH_A ← PWM_A (25)", SIG),
    (dy+4.1, "INH_B ← PWM_B (26)", SIG),
    (dy+3.6, "INH_C ← PWM_C (27)", SIG),
    (dy+3.0, "EN_GATE ← GPIO22", SIG),
    (dy+2.5, "M_PWM = 3-PWM mode", "#777"),
    (dy+2.0, "DTC ─ R 100kΩ → 350ns", "#1a7d1a"),
    (dy+1.5, "OC_ADJ ─ R (OC thresh)", "#1a7d1a"),
    (dy+0.9, "nFAULT → GPIO34", "#c0392b"),
    (dy+0.5, "nOCTW → GPIO39", "#c0392b"),
]
for yy, t, c in left_pins:
    wire(ax1, [(0.2, yy), (dx, yy)], color=c, lw=1.4)
    ax1.text(0.18, yy+0.12, t, color=c, fontsize=7.3, ha="left")

# buck output (5V to ESP32)
box(ax1, dx+0.2, dy-2.0+0.0, 0.0, 0.0, "", C_BUCK)  # placeholder noop
box(ax1, 0.5, 0.9, 1.9, 0.55, "Buck → 5V\n(powers ESP32)", C_BUCK, fs=7)
wire(ax1, [(dx+0.3, dy), (dx+0.3, 1.45), (2.4, 1.45)], color="#0e8f7e", lw=1.6)

# right gate outputs -> 3 legs
gh = [("A", 7.0), ("B", 5.0), ("C", 3.0)]
for ph, yc in gh:
    # GH/GL labels
    ax1.text(dx+dw+0.05, yc+0.55, f"GH_{ph}", fontsize=7, color="#555", ha="left")
    ax1.text(dx+dw+0.05, yc-0.55, f"GL_{ph}", fontsize=7, color="#555", ha="left")
    # HS / LS FETs
    fx = 6.6
    fet(ax1, fx, yc+0.35, 1.3, 0.8, f"M_H{ph}")
    fet(ax1, fx, yc-1.15, 1.3, 0.8, f"M_L{ph}")
    # gate wires from DRV
    wire(ax1, [(dx+dw, yc+0.55), (fx, yc+0.75)], color="#b06a00", lw=1.3)
    wire(ax1, [(dx+dw, yc-0.55), (fx, yc-0.75)], color="#b06a00", lw=1.3)
    # bus / gnd
    wire(ax1, [(fx+0.65, yc+1.15), (fx+0.65, RAIL_T)], color="#bbb", lw=1.1); node(ax1, fx+0.65, RAIL_T)
    wire(ax1, [(fx+0.65, yc-1.15), (fx+0.65, RAIL_B)], color="#bbb", lw=1.1); node(ax1, fx+0.65, RAIL_B)
    # phase node
    midy = yc - 0.0
    wire(ax1, [(fx+0.65, yc+0.35), (fx+0.65, midy)], color="#c0392b")
    wire(ax1, [(fx+0.65, yc-0.35), (fx+0.65, midy)], color="#c0392b")
    node(ax1, fx+0.65, midy, color="#c0392b")
    wire(ax1, [(fx+0.65, midy), (10.6, midy)], color="#c0392b", lw=2)
    ax1.text(10.55, midy+0.18, f"→ L_f ({ph})", color="#c0392b", fontsize=8, ha="right", weight="bold")

# current sense note
box(ax1, 4.7, 0.95, 1.6, 0.6, "shunt + SOx\n(current sense)", C_PWR, fs=6.8)
ax1.text(5.5, 2.4,
         "3-PWM: ESP32 sends 3 PWM → DRV8302 makes 6 gates\n+ dead-time (DTC=100kΩ→350ns) internally.",
         ha="center", va="bottom", fontsize=8, color="#444")

ax1.text(5.5, 0.15, "DRV8302 pins shown functionally (names, not numbers) — verify vs datasheet. Max PVDD 60 V → 40 V safe.",
         ha="center", va="bottom", fontsize=8.2, color="#444")

# =====================================================================
#  PANEL 2 — System overview
# =====================================================================
ax2 = fig.add_subplot(gs[0, 1]); ax2.set_xlim(0, 12); ax2.set_ylim(0, 10); ax2.axis("off")
ax2.set_title("Panel 2  —  System overview : DRV8302 shield → LC filter → Y load",
              fontsize=11.5, weight="bold", pad=10)

box(ax2, 0.3, 6.6, 2.7, 2.6,
    "DC SUPPLY 0–60V\n(set 40V, Ilim 3–4A)\n+ 3×SLA 12V buffer\n+ Cbus + TVS P6KE60A\n+ Rprecharge 10Ω", C_PWR, fs=8)
wire(ax2, [(3.0, 8.6), (11.4, 8.6)], color=RAILP, lw=3)
wire(ax2, [(3.0, 1.0), (11.4, 1.0)], color=RAILN, lw=3)
ax2.text(3.05, 8.78, "+Vbus 40V", color=RAILP, fontsize=8.5, weight="bold")
ax2.text(3.05, 0.66, "PGND", color=RAILN, fontsize=8.5, weight="bold")

# DRV8302 shield (integrated) block
box(ax2, 3.6, 3.0, 3.0, 4.2,
    "DRV8302 SHIELD\n\n• DRV8302 driver\n• 6× MOSFET bridge\n• buck → 5V (ESP32)\n• current-sense\n• OCP/UVLO/dead-time\n  (in-chip)", C_IC, fs=8.5)
wire(ax2, [(5.1, 7.2), (5.1, 8.6)], color="#bbb", lw=1.4)
wire(ax2, [(5.1, 3.0), (5.1, 1.0)], color="#bbb", lw=1.4)

# phases out -> filter -> load
for i, ph in enumerate(["A", "B", "C"]):
    ly = 6.3 - i*1.4
    wire(ax2, [(6.6, ly), (7.4, ly)], color="#c0392b", lw=2)
    box(ax2, 7.4, ly-0.25, 0.95, 0.5, f"L_f {ph}", C_PAS, fs=7)
    wire(ax2, [(8.35, ly), (9.3, ly)], color="#c0392b", lw=2); node(ax2, 9.3, ly, color="#c0392b")
    box(ax2, 9.1, ly-0.55, 0.45, 0.4, "Cf\nRd", C_PAS, fs=6.3)
    wire(ax2, [(9.3, ly), (10.3, ly)], color="#c0392b", lw=2)
box(ax2, 10.3, 3.0, 1.3, 4.0, "3φ Y\nLOAD\n(rheostat\n0–100Ω\n200W)", C_LOAD, fs=8)

# ESP32
box(ax2, 0.3, 1.3, 2.4, 3.6,
    "ESP32-WROOM-32\n\nMCPWM 10kHz\nPWM 25/26/27\nEN_GATE 22\nnFAULT 34\nnOCTW 39\nSPI→AD7606\n(5V from shield buck)", C_MCU, fs=7.8)
# PWM/EN to shield
wire(ax2, [(2.7, 4.4), (3.6, 4.4)], color=SIG, lw=1.6)
ax2.text(2.75, 4.55, "PWM/EN", color=SIG, fontsize=7.3)
# nFAULT back
wire(ax2, [(3.6, 3.5), (2.7, 3.5)], color="#c0392b", lw=1.5)
ax2.text(2.75, 3.32, "nFAULT/nOCTW", color="#c0392b", fontsize=7, ha="left")
# buck 5V back
wire(ax2, [(3.6, 5.0), (3.1, 5.0), (3.1, 5.6), (1.5, 5.6), (1.5, 4.9)], color="#0e8f7e", lw=1.4)
ax2.text(2.0, 5.72, "5V buck", color="#0e8f7e", fontsize=7)

# sensing
box(ax2, 6.9, 8.0, 2.0, 1.1, "3× ACS712-20A\n(phase current)", C_PWR, fs=7.5)
box(ax2, 9.1, 8.0, 2.3, 1.1, "AD7606\n16-bit ADC", C_IC, fs=8)
wire(ax2, [(8.9, 8.55), (9.1, 8.55)], color="#888")
wire(ax2, [(2.7, 2.6), (9.1, 2.6), (9.1, 8.0)], color="#9b59b6", lw=1.4, ls="--")
ax2.text(5.5, 2.74, "SPI (HSPI) → AD7606", color="#9b59b6", fontsize=7.5)

fig.suptitle("VSG Power Stage — Approach B : TI DRV8302 shield (integrated)  (40 V / 100 W, sim-faithful Option A)",
             fontsize=13, weight="bold", y=0.99)

out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "plots", "power_stage_B_wiring.png"))
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=160, bbox_inches="tight", facecolor="white")
print("saved:", out)
