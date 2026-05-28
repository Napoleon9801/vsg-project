"""
Generate a defense-ready wiring diagram for the 66AOS02 VSG hardware:

  DC Supply -> Fuse -> Pre-charge relay -> BESS (48V) -> DC-link cap
  -> DRV8302 3-phase bridge -> 3 x (L_f -> i_L sense -> [C_f || R_d] -> load)

  Sensing:
     V_abc divider  -->  AD7606 (16-bit, 8-ch SPI)  -->  ESP32 (SPI)
     I_abc (ACS712) -->  AD7606

  Control:
     ESP32 --> 6 x PWM (LEDC) --> DRV8302 gate driver
     ESP32 --> Relay control (soft-start)
     OC comparator (hardware) --> nFAULT pin --> ESP32

Outputs python/plots/wiring_diagram.png
"""

from __future__ import annotations
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mp
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, ConnectionPatch


HERE  = Path(__file__).resolve().parent
PLOTS = HERE.parent / "plots"
PLOTS.mkdir(exist_ok=True)
OUT   = PLOTS / "wiring_diagram.png"

# Colour palette
POWER_FACE  = "#FFE0B2"   # orange-ish for power components
POWER_EDGE  = "#E65100"
SENSE_FACE  = "#E1F5FE"   # cyan for sensing
SENSE_EDGE  = "#01579B"
CTRL_FACE   = "#E8F5E9"   # green for control
CTRL_EDGE   = "#1B5E20"
PROT_FACE   = "#FFEBEE"   # red for protection
PROT_EDGE   = "#B71C1C"
WIRE_PWR    = "#C62828"   # red for power wires
WIRE_GND    = "#212121"   # black for ground
WIRE_SIG    = "#1565C0"   # blue for signals
WIRE_PWM    = "#6A1B9A"   # purple for PWM


def box(ax, x, y, w, h, label, sub=None, face=POWER_FACE, edge=POWER_EDGE,
        fs_title=10, fs_sub=8):
    rect = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.04,rounding_size=0.08",
        linewidth=1.4, edgecolor=edge, facecolor=face,
    )
    ax.add_patch(rect)
    if sub:
        ax.text(x + w/2, y + h*0.62, label,
                ha="center", va="center", fontsize=fs_title,
                fontweight="bold", color="#000")
        ax.text(x + w/2, y + h*0.28, sub,
                ha="center", va="center", fontsize=fs_sub, color="#333")
    else:
        ax.text(x + w/2, y + h/2, label,
                ha="center", va="center", fontsize=fs_title,
                fontweight="bold")


def arrow(ax, p1, p2, color=WIRE_PWR, lw=1.8, label=None,
          label_pos=0.5, label_off=(0, 0.10), arrow=True):
    style = "->" if arrow else "-"
    ax.annotate(
        "", xy=p2, xytext=p1,
        arrowprops=dict(arrowstyle=style, color=color, lw=lw,
                        shrinkA=0, shrinkB=0),
    )
    if label:
        x = p1[0] + (p2[0] - p1[0]) * label_pos + label_off[0]
        y = p1[1] + (p2[1] - p1[1]) * label_pos + label_off[1]
        ax.text(x, y, label, fontsize=7.5, color=color,
                ha="center", va="bottom",
                bbox=dict(boxstyle="round,pad=0.15",
                          fc="white", ec="none", alpha=0.85))


def bus_h(ax, x1, x2, y, color=WIRE_PWR, lw=2.0):
    ax.plot([x1, x2], [y, y], color=color, lw=lw, solid_capstyle="round")


def bus_v(ax, x, y1, y2, color=WIRE_PWR, lw=2.0):
    ax.plot([x, x], [y1, y2], color=color, lw=lw, solid_capstyle="round")


def dot(ax, x, y, color="#000"):
    ax.plot(x, y, "o", color=color, markersize=4)


def main():
    fig, ax = plt.subplots(figsize=(15, 9.5))
    ax.set_xlim(0, 30)
    ax.set_ylim(0, 19)
    ax.set_aspect("equal")
    ax.axis("off")

    # === Title block =======================================================
    ax.text(15, 18.4, "VSG Hardware Wiring Diagram  —  66AOS02  (48 V DC / 100 W)",
            ha="center", fontsize=14, fontweight="bold", color="#E65100")
    ax.text(15, 17.85,
            "Power chain (top)  |  Sensing chain (middle)  |  ESP32 control + protection (bottom)",
            ha="center", fontsize=9, color="#555", style="italic")

    # =======================================================================
    # ROW 1 — POWER STAGE (y ~ 13 - 16.5)
    # =======================================================================
    y_pwr = 14.3
    bh    = 1.7  # box height

    # DC Supply
    box(ax, 0.4,  y_pwr, 2.4, bh, "DC Supply",
        "0-60V / 5A", POWER_FACE, POWER_EDGE)
    # Fuse + pre-charge
    box(ax, 3.3,  y_pwr, 2.0, bh, "Fuse + Relay",
        "5A + Pre-charge", PROT_FACE, PROT_EDGE)
    # BESS pack
    box(ax, 5.8,  y_pwr, 2.6, bh, "BESS Pack",
        "4×12V LiFePO4\n(48V/10Ah)", POWER_FACE, POWER_EDGE)
    # BMS
    box(ax, 8.9,  y_pwr, 1.6, bh, "BMS",
        "OV / UV / OC", PROT_FACE, PROT_EDGE)
    # DC-link cap + TVS
    box(ax, 11.0, y_pwr, 2.0, bh, "DC-link",
        "Bulk Cap\n+ TVS 60V", POWER_FACE, POWER_EDGE)
    # 3-phase bridge
    box(ax, 13.5, y_pwr, 3.2, bh, "DRV8302 Shield",
        "6 × MOSFET\n3-Φ bridge", POWER_FACE, POWER_EDGE)
    # L_f (per phase)
    box(ax, 17.2, y_pwr+0.5, 1.7, bh-0.5,
        "L_f  1.5 mH", "× 3 phases",
        POWER_FACE, POWER_EDGE)
    # C_f + R_d snubber
    box(ax, 19.4, y_pwr+0.5, 2.0, bh-0.5,
        "C_f 15 µF + R_d 1 Ω",
        "× 3 phases", POWER_FACE, POWER_EDGE)
    # 3-phase load
    box(ax, 21.9, y_pwr, 2.6, bh, "3-Φ Y Load",
        "Rheostat\n0-100 Ω / 200 W",
        POWER_FACE, POWER_EDGE)

    # Power-chain bus on top
    pwr_y = y_pwr + bh - 0.3
    # connect boxes left-to-right with red bus
    arrow(ax, (2.8, pwr_y), (3.3, pwr_y), WIRE_PWR, label="48 V+")
    arrow(ax, (5.3, pwr_y), (5.8, pwr_y), WIRE_PWR)
    arrow(ax, (8.4, pwr_y), (8.9, pwr_y), WIRE_PWR)
    arrow(ax, (10.5, pwr_y), (11.0, pwr_y), WIRE_PWR)
    arrow(ax, (13.0, pwr_y), (13.5, pwr_y), WIRE_PWR, label="V_DC")
    arrow(ax, (16.7, pwr_y), (17.2, pwr_y+bh/2), WIRE_PWR, label="V_inv,abc")
    arrow(ax, (18.9, pwr_y+bh/2), (19.4, pwr_y+bh/2), WIRE_PWR, label="i_L")
    arrow(ax, (21.4, pwr_y+bh/2), (21.9, pwr_y), WIRE_PWR, label="V_load,abc")

    # GND return bus underneath the power row
    gnd_y = y_pwr - 0.20
    bus_h(ax, 0.4, 24.5, gnd_y, WIRE_GND, lw=2.2)
    ax.text(0.4, gnd_y - 0.32, "GND (common chassis)", fontsize=8,
            color=WIRE_GND, fontweight="bold")
    # vertical drops to GND from each power block
    for xd in (1.6, 4.3, 7.1, 9.7, 12.0, 15.1, 23.2):
        bus_v(ax, xd, gnd_y, y_pwr, WIRE_GND, lw=1.2)
        dot(ax, xd, gnd_y, WIRE_GND)

    # =======================================================================
    # ROW 2 — SENSING CHAIN (y ~ 7 - 11)
    # =======================================================================
    y_sense = 9.5

    # Voltage divider (V_abc)
    box(ax, 17.2, y_sense, 2.0, 1.4,
        "V-Divider", "R1 + R2\n× 3 phases", SENSE_FACE, SENSE_EDGE)
    # ACS712 current sensors
    box(ax, 19.6, y_sense, 2.0, 1.4,
        "ACS712-05B", "Hall, ±5 A\n× 3 phases", SENSE_FACE, SENSE_EDGE)
    # AD7606
    box(ax, 13.5, y_sense, 3.0, 1.4, "AD7606",
        "16-bit, 8-ch\nSimultaneous ADC\n5 MHz SPI",
        SENSE_FACE, SENSE_EDGE, fs_sub=7.5)

    # Sense tap arrows (load side V and inductor current i_L)
    # From V_load_abc node to voltage divider
    arrow(ax, (22.4, y_pwr), (18.2, y_sense + 1.4),
          WIRE_SIG, lw=1.3, label="V_a, V_b, V_c", label_off=(-1, 0.2))
    # From i_L node to ACS712
    arrow(ax, (19.6, y_pwr+bh/2-0.3), (20.6, y_sense + 1.4),
          WIRE_SIG, lw=1.3, label="i_a, i_b, i_c", label_off=(0.5, 0.2))
    # V-divider -> AD7606 (3 channels)
    arrow(ax, (17.2, y_sense + 0.7), (16.5, y_sense + 1.0),
          WIRE_SIG, lw=1.3, label="3 ch")
    # ACS712 -> AD7606 (3 channels)
    arrow(ax, (19.6, y_sense + 0.4), (16.5, y_sense + 0.4),
          WIRE_SIG, lw=1.3, label="3 ch", label_off=(0, -0.25))
    # DC bus voltage sense → AD7606 (1 channel)
    arrow(ax, (12.0, y_pwr), (15.0, y_sense + 1.4),
          WIRE_SIG, lw=1.0, label="V_DC", label_off=(-0.5, 0.1))

    # =======================================================================
    # ROW 3 — ESP32 + PROTECTION (y ~ 2 - 6)
    # =======================================================================
    y_ctrl = 3.5
    # ESP32 main MCU
    box(ax, 13.2, y_ctrl, 3.6, 2.0, "ESP32-WROOM-32D",
        "Dual-core 240 MHz, FPU\nCore 0: control ISR @10 kHz\nCore 1: telemetry/WiFi",
        CTRL_FACE, CTRL_EDGE, fs_sub=7.5)
    # 5 V / 3.3 V LDO
    box(ax, 9.4, y_ctrl + 0.5, 2.2, 1.4,
        "LDO 5V / 3.3V", "powers ESP32 + sensors",
        CTRL_FACE, CTRL_EDGE)
    # OC comparator
    box(ax, 17.5, y_ctrl + 0.5, 2.3, 1.4,
        "OC Comparator", "LM393\nthreshold 4.5 A",
        PROT_FACE, PROT_EDGE)
    # Gate-drive enable / nFAULT
    box(ax, 20.2, y_ctrl + 0.5, 2.0, 1.4,
        "nFAULT logic",
        "trip → PWM_EN\nresets to ESP32",
        PROT_FACE, PROT_EDGE)
    # Telemetry sink (laptop)
    box(ax, 5.2, y_ctrl + 0.5, 3.2, 1.4,
        "Laptop / Serial Plotter",
        "USB-UART or WiFi\nlogs V_d, P, freq",
        CTRL_FACE, CTRL_EDGE, fs_sub=7.5)

    # SPI bus AD7606 ↔ ESP32
    arrow(ax, (14.5, y_sense), (14.5, y_ctrl + 2.0),
          WIRE_SIG, lw=1.8, label="SPI (CS/CLK/MISO)")
    # ESP32 → DRV8302 (6 PWM)
    arrow(ax, (15.0, y_ctrl + 2.0), (15.0, y_pwr),
          WIRE_PWM, lw=2.0, label="6 × PWM\n(LEDC 10 kHz)",
          label_off=(2.0, -3.0))
    # ESP32 → relay control (pre-charge bypass)
    arrow(ax, (13.2, y_ctrl + 1.0), (4.3, y_pwr),
          WIRE_PWM, lw=1.2, label="relay CTRL", label_off=(-3, 0))
    # ESP32 → LDO power
    arrow(ax, (11.6, y_ctrl + 1.2), (13.2, y_ctrl + 1.2),
          WIRE_PWR, lw=1.4, label="3.3 V")
    # ESP32 ↔ telemetry sink
    arrow(ax, (13.2, y_ctrl + 0.7), (8.4, y_ctrl + 0.7),
          WIRE_SIG, lw=1.2, label="UART / WiFi")
    # OC comparator: input from ACS712 (any phase OR-ed)
    arrow(ax, (20.6, y_sense), (18.6, y_ctrl + 1.9),
          WIRE_SIG, lw=1.1, label="|i_max|",
          label_off=(0.4, -0.6))
    # OC comparator → nFAULT logic
    arrow(ax, (19.8, y_ctrl + 1.2), (20.2, y_ctrl + 1.2),
          PROT_EDGE, lw=1.6)
    # nFAULT → DRV8302 PWM_EN
    arrow(ax, (21.2, y_ctrl + 1.9), (16.7, y_pwr),
          PROT_EDGE, lw=1.4, label="PWM_EN", label_off=(0.5, 0))
    # nFAULT → ESP32 (notify)
    arrow(ax, (20.2, y_ctrl + 1.0), (16.8, y_ctrl + 1.2),
          PROT_EDGE, lw=1.1, label="nFAULT IRQ", label_off=(0, -0.25))

    # =======================================================================
    # LEGEND
    # =======================================================================
    leg_y = 1.0
    ax.text(0.5, leg_y + 0.65, "Legend:", fontsize=10, fontweight="bold")
    items = [
        (WIRE_PWR,  "Power (V+ / V_DC)"),
        (WIRE_GND,  "GND return"),
        (WIRE_SIG,  "Analog / digital signal"),
        (WIRE_PWM,  "PWM gate / control"),
        (PROT_EDGE, "Protection / fault"),
    ]
    for i, (c, name) in enumerate(items):
        xpos = 0.5 + i * 5.4
        ax.plot([xpos, xpos + 0.6], [leg_y, leg_y], color=c, lw=2.5)
        ax.text(xpos + 0.75, leg_y, name, fontsize=9, va="center")

    # Section labels (left side)
    ax.text(0.2, y_pwr + bh + 0.4, "POWER STAGE",
            fontsize=11, fontweight="bold", color=POWER_EDGE)
    ax.text(0.2, y_sense + 1.6, "SENSING",
            fontsize=11, fontweight="bold", color=SENSE_EDGE)
    ax.text(0.2, y_ctrl + 2.2, "CONTROL & PROTECTION",
            fontsize=11, fontweight="bold", color=CTRL_EDGE)

    plt.tight_layout()
    plt.savefig(OUT, dpi=180, bbox_inches="tight",
                facecolor="white")
    print(f"Saved: {OUT}")


if __name__ == "__main__":
    main()
