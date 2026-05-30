"""
power_stage_A_wiring.py
VSG Power Stage — Approach A wiring diagram (discrete IRF540N + IR2104 + LM393 OCP).
Two panels:
  (1) Detailed half-bridge leg (Phase A): IR2104 + bootstrap + 2x IRF540N + gate R
  (2) System overview: DC bus -> 3 legs -> LC filter -> Y load, + OCP + ESP32 + sensing

Output: python/plots/power_stage_A_wiring.png
NOTE: IR2104 pinout drawn per IRS2104 datasheet (verify before wiring).
"""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyBboxPatch, Circle

# ---- palette ----
C_IC   = "#cfe8ff"   # ICs
C_FET  = "#ffe0b3"   # MOSFETs
C_PWR  = "#ffd6d6"   # power / protection
C_PAS  = "#e7f5d8"   # passives
C_MCU  = "#e6dcff"   # ESP32
C_LOAD = "#fff2b3"
EDGE   = "#333333"
RAILP  = "#c0392b"   # +Vbus rail
RAILN  = "#2c3e50"   # PGND rail
WIRE   = "#444444"
SIG    = "#1f77b4"   # control signal


def box(ax, x, y, w, h, label, fc, fs=9, lw=1.4, weight="normal"):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.06",
                                fc=fc, ec=EDGE, lw=lw, zorder=3))
    ax.text(x + w/2, y + h/2, label, ha="center", va="center",
            fontsize=fs, zorder=4, weight=weight)


def wire(ax, pts, color=WIRE, lw=1.8, z=2, ls="-"):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    ax.plot(xs, ys, color=color, lw=lw, zorder=z, ls=ls,
            solid_capstyle="round", solid_joinstyle="round")


def node(ax, x, y, color=WIRE, r=0.045):
    ax.add_patch(Circle((x, y), r, fc=color, ec=color, zorder=5))


def fet(ax, x, y, w, h, label):
    """Simple labeled MOSFET box with D(top) G(left) S(bottom) stubs."""
    box(ax, x, y, w, h, label, C_FET, fs=8.5, weight="bold")
    ax.text(x + w/2, y + h + 0.12, "D", ha="center", va="bottom", fontsize=7.5, color="#555")
    ax.text(x - 0.12, y + h/2, "G", ha="right", va="center", fontsize=7.5, color="#555")
    ax.text(x + w/2, y - 0.12, "S", ha="center", va="top", fontsize=7.5, color="#555")


fig = plt.figure(figsize=(17, 9.2))
gs = fig.add_gridspec(1, 2, width_ratios=[1.0, 1.15], wspace=0.05)

# =====================================================================
#  PANEL 1 — Detailed Phase-A half-bridge leg
# =====================================================================
ax1 = fig.add_subplot(gs[0, 0]); ax1.set_xlim(0, 10); ax1.set_ylim(0, 10); ax1.axis("off")
ax1.set_title("Panel 1  —  Half-bridge leg (Phase A) : IR2104 + 2× IRF540N",
              fontsize=11.5, weight="bold", pad=10)

# rails
RAIL_T = 9.2; RAIL_B = 0.8
wire(ax1, [(0.8, RAIL_T), (9.4, RAIL_T)], color=RAILP, lw=3)
wire(ax1, [(0.8, RAIL_B), (9.4, RAIL_B)], color=RAILN, lw=3)
ax1.text(0.8, RAIL_T + 0.18, "+Vbus (40 V)", color=RAILP, fontsize=10, weight="bold")
ax1.text(0.8, RAIL_B - 0.34, "PGND", color=RAILN, fontsize=10, weight="bold")

# IR2104 driver
ir_x, ir_y, ir_w, ir_h = 1.3, 3.7, 2.5, 3.4
box(ax1, ir_x, ir_y, ir_w, ir_h, "IR2104\n(IRS2104)", C_IC, fs=10, weight="bold")
# left-side pins (control)
pin_in  = (ir_x, ir_y + 2.5)   # IN (2)
pin_sd  = (ir_x, ir_y + 1.7)   # SD (3)
pin_vcc = (ir_x, ir_y + 0.6)   # VCC (1) +12V
ax1.text(ir_x + 0.08, pin_in[1],  "IN (2)",  ha="left", va="center", fontsize=7.5)
ax1.text(ir_x + 0.08, pin_sd[1],  "SD (3)",  ha="left", va="center", fontsize=7.5)
ax1.text(ir_x + 0.08, pin_vcc[1], "VCC(1)",  ha="left", va="center", fontsize=7.5)
# right-side pins (power)
pin_vb = (ir_x + ir_w, ir_y + 3.0)  # VB (8)
pin_ho = (ir_x + ir_w, ir_y + 2.3)  # HO (7)
pin_vs = (ir_x + ir_w, ir_y + 1.6)  # VS (6)
pin_lo = (ir_x + ir_w, ir_y + 0.9)  # LO (5)
pin_com= (ir_x + ir_w, ir_y + 0.3)  # COM (4)
for p, t in [(pin_vb,"VB(8)"),(pin_ho,"HO(7)"),(pin_vs,"VS(6)"),(pin_lo,"LO(5)"),(pin_com,"COM(4)")]:
    ax1.text(p[0]-0.08, p[1], t, ha="right", va="center", fontsize=7.5)

# control inputs from ESP32 (left)
wire(ax1, [(0.2, pin_in[1]), pin_in], color=SIG, lw=1.8)
wire(ax1, [(0.2, pin_sd[1]), pin_sd], color=SIG, lw=1.8)
ax1.text(0.15, pin_in[1]+0.16, "PWM_A (GPIO25)", color=SIG, fontsize=8, ha="left")
ax1.text(0.15, pin_sd[1]-0.22, "GATE_EN (GPIO22)", color=SIG, fontsize=8, ha="left")
# +12V to VCC
wire(ax1, [(0.2, pin_vcc[1]), pin_vcc], color="#1a7d1a", lw=1.8)
ax1.text(0.15, pin_vcc[1]-0.22, "+12 V", color="#1a7d1a", fontsize=8, ha="left")

# High-side FET
hs_x, hs_y, fw, fh = 6.2, 6.0, 1.4, 1.2
fet(ax1, hs_x, hs_y, fw, fh, "IRF540N\nHS")
# D to +Vbus
wire(ax1, [(hs_x+fw/2, hs_y+fh), (hs_x+fw/2, RAIL_T)]); node(ax1, hs_x+fw/2, RAIL_T)
# Low-side FET
ls_x, ls_y = 6.2, 1.9
fet(ax1, ls_x, ls_y, fw, fh, "IRF540N\nLS")

# phase node (midpoint) between HS source and LS drain
mid_x = hs_x + fw/2
mid_y = (hs_y + (ls_y+fh)) / 2
wire(ax1, [(hs_x+fw/2, hs_y), (mid_x, mid_y)])
wire(ax1, [(ls_x+fw/2, ls_y+fh), (mid_x, mid_y)])
node(ax1, mid_x, mid_y, color="#c0392b")
ax1.text(mid_x+0.15, mid_y+0.05, "Phase A node", fontsize=8.5, color="#c0392b", weight="bold")
# output to filter
wire(ax1, [(mid_x, mid_y), (9.4, mid_y)], color="#c0392b", lw=2)
ax1.text(9.35, mid_y+0.2, "→ L_f", color="#c0392b", fontsize=9, ha="right", weight="bold")

# gate resistors HO->HS gate, LO->LS gate
rg1x = (pin_ho[0]+hs_x)/2 + 0.3
box(ax1, rg1x-0.35, pin_ho[1]-0.16, 0.7, 0.32, "Rg 22Ω", C_PAS, fs=7)
wire(ax1, [pin_ho, (rg1x-0.35, pin_ho[1])])
wire(ax1, [(rg1x+0.35, pin_ho[1]), (hs_x, hs_y+fh/2)])
rg2x = (pin_lo[0]+ls_x)/2 + 0.3
box(ax1, rg2x-0.35, pin_lo[1]-0.16, 0.7, 0.32, "Rg 22Ω", C_PAS, fs=7)
wire(ax1, [pin_lo, (rg2x-0.35, pin_lo[1])])
wire(ax1, [(rg2x+0.35, pin_lo[1]), (ls_x, ls_y+fh/2)])
# VS to phase node, COM to PGND
wire(ax1, [pin_vs, (mid_x-0.0, mid_y)], color="#888", ls="--", lw=1.4)
wire(ax1, [pin_com, (pin_com[0]+0.3, pin_com[1]), (pin_com[0]+0.3, RAIL_B)], color="#888")
node(ax1, pin_com[0]+0.3, RAIL_B)
# LS source to PGND
wire(ax1, [(ls_x+fw/2, ls_y), (ls_x+fw/2, RAIL_B)]); node(ax1, ls_x+fw/2, RAIL_B)

# bootstrap diode + cap (VCC->VB, VB-VS)
bd_y = ir_y + ir_h + 0.5
box(ax1, ir_x+0.4, bd_y, 1.0, 0.34, "D_boot", C_PAS, fs=7)
wire(ax1, [pin_vcc, (pin_vcc[0]-0.0, bd_y+0.17), (ir_x+0.4, bd_y+0.17)], color="#888")
wire(ax1, [(ir_x+1.4, bd_y+0.17), (pin_vb[0]+0.4, bd_y+0.17), (pin_vb[0]+0.4, pin_vb[1]), pin_vb], color="#888")
ax1.text(pin_vb[0]+0.5, (pin_vb[1]+pin_vs[1])/2, "C_boot\n1µF", fontsize=7, ha="left", va="center", color="#555")
wire(ax1, [(pin_vb[0]+0.4, pin_vb[1]), (pin_vb[0]+0.4, pin_vs[1]), (pin_vs[0], pin_vs[1])], color="#bbb", ls=":")

ax1.text(5.0, 0.15,
         "Each of 3 legs = 1× IR2104 + 2× IRF540N.  IR2104 makes HO/LO complementary\n"
         "with internal ~520 ns dead-time (anti shoot-through). Verify SD polarity vs datasheet.",
         ha="center", va="bottom", fontsize=8.2, color="#444")

# =====================================================================
#  PANEL 2 — System overview
# =====================================================================
ax2 = fig.add_subplot(gs[0, 1]); ax2.set_xlim(0, 12); ax2.set_ylim(0, 10); ax2.axis("off")
ax2.set_title("Panel 2  —  System overview : DC bus → 3 legs → LC filter → Y load",
              fontsize=11.5, weight="bold", pad=10)

# DC bus section (left)
box(ax2, 0.3, 6.6, 2.7, 2.6,
    "DC SUPPLY 0–60V\n(set 40V, Ilim 3–4A)\n+ 3×SLA 12V buffer\n+ Cbus + TVS P6KE60A\n+ Rprecharge 10Ω", C_PWR, fs=8)
# bus rails
wire(ax2, [(3.0, 8.6), (11.4, 8.6)], color=RAILP, lw=3)
wire(ax2, [(3.0, 1.0), (11.4, 1.0)], color=RAILN, lw=3)
ax2.text(3.05, 8.78, "+Vbus 40V", color=RAILP, fontsize=8.5, weight="bold")
ax2.text(3.05, 0.66, "PGND", color=RAILN, fontsize=8.5, weight="bold")
wire(ax2, [(1.65, 6.6), (1.65, 1.0)], color=RAILN, lw=2)   # supply- to PGND
wire(ax2, [(1.65, 9.2), (1.65, 8.6)], color=RAILP, lw=2)   # supply+ to +Vbus (visual)

# three legs
leg_x = 3.7
for i, ph in enumerate(["A", "B", "C"]):
    ly = 6.3 - i*1.9
    box(ax2, leg_x, ly, 2.4, 1.4, f"LEG {ph}\nIR2104 + 2×IRF540N", C_FET, fs=8)
    # to +Vbus and PGND
    wire(ax2, [(leg_x+1.2, ly+1.4), (leg_x+1.2, 8.6)], color="#bbb", lw=1.2)
    wire(ax2, [(leg_x+1.2, ly), (leg_x+1.2, 1.0)], color="#bbb", lw=1.2)
    # phase out -> filter
    wire(ax2, [(leg_x+2.4, ly+0.7), (7.0, ly+0.7)], color="#c0392b", lw=2)
    box(ax2, 7.0, ly+0.45, 1.0, 0.5, f"L_f {ph}\n1.2mH", C_PAS, fs=7)
    wire(ax2, [(8.0, ly+0.7), (9.2, ly+0.7)], color="#c0392b", lw=2)
    node(ax2, 9.2, ly+0.7, color="#c0392b")
    # Cf+Rd to neutral
    box(ax2, 9.0, ly+0.05, 0.5, 0.42, "Cf\nRd", C_PAS, fs=6.5)
    # load
    wire(ax2, [(9.2, ly+0.7), (10.4, ly+0.7)], color="#c0392b", lw=2)

box(ax2, 10.4, 1.7, 1.3, 4.2, "3φ Y\nLOAD\n(rheostat\n0–100Ω\n200W)", C_LOAD, fs=8)

# PWM in / EN from ESP32 (left of legs)
for i, gp in enumerate(["25", "26", "27"]):
    ly = 6.3 - i*1.9
    wire(ax2, [(2.9, ly+0.95), (leg_x, ly+0.95)], color=SIG, lw=1.6)
ax2.text(2.85, 6.3+1.15, "PWM A/B/C", color=SIG, fontsize=7.5, ha="right")

# OCP block (bottom)
box(ax2, 3.7, 1.5, 2.4, 1.0, "OCP\nshunt + LM393\ncomparator", C_PWR, fs=8)
wire(ax2, [(4.9, 1.5), (4.9, 1.0)], color="#888")          # senses PGND return
wire(ax2, [(3.7, 2.0), (2.6, 2.0)], color=SIG, lw=1.6)     # -> ESP32 fault
ax2.text(2.55, 2.0, "→ FAULT", color=SIG, fontsize=7.5, ha="right", va="center")

# sensing: ACS712 -> AD7606 (top right under load)
box(ax2, 6.6, 8.0, 2.0, 1.1, "3× ACS712-20A\n(phase current)", C_PWR, fs=7.5)
box(ax2, 8.9, 8.0, 2.5, 1.1, "AD7606\n16-bit ADC (SPI)", C_IC, fs=8)
wire(ax2, [(8.6, 8.55), (8.9, 8.55)], color="#888")
wire(ax2, [(6.6, 8.55), (5.6, 8.55), (5.6, 7.0)], color="#888", lw=1.2)  # taps phases (symbolic)

# ESP32 block (bottom-left)
box(ax2, 0.3, 1.5, 2.3, 3.4,
    "ESP32-WROOM-32\n\nMCPWM 10kHz\nPWM 25/26/27\nGATE_EN 22\nOCP_FAULT 34\nSPI→AD7606", C_MCU, fs=8)
wire(ax2, [(2.6, 4.4), (8.9, 4.4), (8.9, 8.0)], color="#9b59b6", lw=1.4, ls="--")  # SPI to AD7606
ax2.text(5.0, 4.55, "SPI (HSPI)", color="#9b59b6", fontsize=7.5)

fig.suptitle("VSG Power Stage — Approach A : discrete IRF540N + IR2104 + LM393 OCP  (40 V / 100 W, sim-faithful Option A)",
             fontsize=13, weight="bold", y=0.99)

out = os.path.join(os.path.dirname(__file__), "..", "plots", "power_stage_A_wiring.png")
out = os.path.abspath(out)
os.makedirs(os.path.dirname(out), exist_ok=True)
fig.savefig(out, dpi=160, bbox_inches="tight", facecolor="white")
print("saved:", out)
