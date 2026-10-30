"""Generate the reviewed VSG option-A functional diagram (not an assembly schematic)."""
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

ROOT = Path(__file__).resolve().parents[2]


def draw_box(ax, x, y, w, h, label, color='#edf3f8', size=10):
    patch = FancyBboxPatch((x, y), w, h, boxstyle='round,pad=0.025',
                          facecolor=color, edgecolor='#334155', linewidth=1.2)
    ax.add_patch(patch)
    ax.text(x+w/2, y+h/2, label, ha='center', va='center', fontsize=size)


def arrow(ax, start, end, label=None, color='#334155'):
    ax.annotate('', xy=end, xytext=start,
                arrowprops={'arrowstyle': '->', 'lw': 1.6, 'color': color})
    if label:
        ax.text((start[0]+end[0])/2, (start[1]+end[1])/2+0.12,
                label, ha='center', va='bottom', fontsize=9, color=color)


def main():
    fig, ax = plt.subplots(figsize=(15, 10))
    fig.patch.set_facecolor('white')
    ax.set(xlim=(0, 15), ylim=(0, 10))
    ax.axis('off')
    ax.text(0.2, 9.7, 'VSG option A  |  40 V DC / 100 W nominal', fontsize=20, weight='bold')
    ax.text(0.2, 9.25, 'Functional architecture and required independent shutdown', fontsize=13)
    draw_box(ax, .2, 7.6, 2.2, 1.0, 'Current-limited\nDC source', '#fef3c7')
    draw_box(ax, 3, 7.6, 2.2, 1.0, 'Fuse / precharge\nDC-link capacitor', '#fef3c7')
    draw_box(ax, 6, 7.6, 2.6, 1.0, '3 half bridges\nIRF540N + IR2104', '#fee2e2')
    draw_box(ax, 9.3, 7.6, 2.3, 1.0, 'Lf 1.2 mH\nCf 10 uF + Rd 1 ohm')
    draw_box(ax, 12.4, 7.6, 2.3, 1.0, 'Three-phase load\n14 V peak / phase', '#dcfce7')
    for start, end in [((2.4,8.1),(3,8.1)),((5.2,8.1),(6,8.1)),((8.6,8.1),(9.3,8.1)),((11.6,8.1),(12.4,8.1))]:
        arrow(ax,start,end)
    draw_box(ax, .2, 5.8, 3.1, .9, 'Separate regulated auxiliary rails\n12 V gate / 5 V sensor / 3.3 V logic', size=9)
    ax.text(.2, 5.45, 'Grounding and sequencing require board review.', fontsize=9)
    draw_box(ax, 4.1, 5.8, 2.5, .9, 'ESP32 controller\n10 kHz target', '#e0e7ff')
    draw_box(ax, 9.3, 5.8, 3.1, .9, 'AD7606 + ACS712\nVerified reset, straps and scaling')
    arrow(ax,(9.3,6.25),(6.6,6.25),'SPI / BUSY')
    arrow(ax,(10.8,7.6),(10.8,6.7),'V / I')
    arrow(ax,(5.9,6.7),(6.6,7.6),'PWM A/B/C')
    ax.plot([.2,14.7],[5.05,5.05],color='#cbd5e1',lw=1)
    ax.text(.2,4.65,'CPU-independent gate permission',fontsize=15,weight='bold')
    draw_box(ax,.2,3.15,2.5,.85,'OCP comparator\nFAULT_N active LOW','#fee2e2')
    draw_box(ax,.2,1.85,2.5,.85,'Supply / DC-bus UV/OV\nreset / fault supervision','#fee2e2')
    draw_box(ax,4,2.6,2.8,1.3,'Hardware permit latch\nFault/reset clears\nManual healthy re-arm','#fef3c7')
    arrow(ax,(2.7,3.575),(4,3.5),'clear')
    arrow(ax,(2.7,2.275),(4,2.9),'clear')
    draw_box(ax,8,3,1.7,.9,'AND','#dcfce7',size=14)
    arrow(ax,(6.8,3.3),(8,3.3),'permit')
    ax.plot([7.4,7.4,8],[4.35,3.75,3.75],color='#334155',lw=1.6)
    ax.text(7.4,4.5,'GPIO22 MCU request',fontsize=10,ha='center')
    arrow(ax,(9.7,3.45),(11,3.45),'SD_PERMIT')
    draw_box(ax,11,2.8,3.7,1.3,'All 3 IR2104 SD inputs\nLOW = both gates disabled\nHIGH = PWM permitted','#fee2e2')
    ax.text(8,2.35,'External default-LOW pulls on\nMCU request and SD permit',fontsize=9,ha='left')
    ax.text(.2,1.25,'FAULT_N also feeds GPIO34 / MCPWM F0; external 10 kohm pull-up to 3.3 V is required.',fontsize=10)
    ax.text(.2,.85,'No direct connection between comparator output and push-pull GPIO22. Logic-level margins must be checked.',fontsize=10)
    ax.text(.2,.3,'DESIGN REQUIREMENT — not an inspected PCB. See hardware_shutdown_and_bench_plan.md.  |  2026-10-20',
            fontsize=10,color='#9f1239',weight='bold')
    fig.tight_layout(pad=1.3)
    for destination in (ROOT/'python/plots/power_stage_A_wiring.png', ROOT/'docs/figures/power_stage_A_wiring.png'):
        destination.parent.mkdir(parents=True,exist_ok=True)
        fig.savefig(destination,dpi=160,facecolor='white')
        print(destination)
    plt.close(fig)


if __name__ == '__main__':
    main()
