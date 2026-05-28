"""
VSG Project - Stage 5a post-processing.

Reads matlab/vsg_stage5a_out.mat (switching abc model with SPWM at 10 kHz,
48 V DC bus, 100 W 3-phase) and produces a defense-ready figure:

  Top:    V_load_abc near the load step (clean 50 Hz fundamentals after LC)
  Mid:    V_d / V_q tracking (proves outer voltage loop)
  Bot L:  Frequency response after R_load step (Swing Eq behaviour)
  Bot R:  P_meas (3-phase total) with droop steady-state

Writes PNG to python/plots/phase5a_switching.png.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.io as sio


HERE      = Path(__file__).resolve().parent
DATA_PATH = HERE.parents[1] / "matlab" / "vsg_stage5a_out.mat"
PLOT_DIR  = HERE.parent / "plots"
PLOT_DIR.mkdir(exist_ok=True)


def load(path: Path) -> dict:
    raw = sio.loadmat(path, squeeze_me=True)
    out: dict = {}
    for k, v in raw.items():
        if k.startswith("__"):
            continue
        arr = np.asarray(v)
        if arr.ndim == 0:
            out[k] = float(arr)
        else:
            out[k] = arr
    return out


def report(d: dict) -> None:
    print("Stage 5a - switching model (48 V DC bus, SPWM 10 kHz)")
    print(f"  V_dc            : {d['V_dc']:.1f} V")
    print(f"  Mod index       : {d['V_set']/(d['V_dc']/2):.3f}")
    print(f"  V_d  sim final  : {float(d['Vload_d'][-1]):.3f} V  (set {d['V_set']:.2f} V)")
    print(f"  V_q  sim final  : {float(d['Vload_q'][-1]):+.4f} V  (should ~0)")
    print(f"  P    sim final  : {float(d['P_meas'][-1]):.2f} W")
    print(f"  P    pred post  : {float(d['P_ss_post']):.2f} W")
    print(f"  f    sim final  : {float(d['freq'][-1]):.4f} Hz")
    print(f"  Df   pred       : {float(d['df_ss_pred']):.4f} Hz")


def make_plot(d: dict, out_path: Path) -> None:
    t = d["t"]
    R_t = float(d["R_load_t"])

    fig = plt.figure(figsize=(11, 7))
    gs = fig.add_gridspec(3, 2, hspace=0.45, wspace=0.25)

    # --- (1) V_load_abc zoom window around the disturbance ---
    ax1 = fig.add_subplot(gs[0, :])
    Vabc = d["Vload_abc"]
    if Vabc.ndim == 2:
        if Vabc.shape[0] == 3:
            Va, Vb, Vc = Vabc[0], Vabc[1], Vabc[2]
        else:
            Va, Vb, Vc = Vabc[:, 0], Vabc[:, 1], Vabc[:, 2]
    else:
        Va = Vb = Vc = Vabc
    # zoom 80 ms window straddling the load step
    win = (t >= R_t - 0.02) & (t <= R_t + 0.06)
    ax1.plot(t[win] * 1e3, Va[win], label="V_a", linewidth=0.9)
    ax1.plot(t[win] * 1e3, Vb[win], label="V_b", linewidth=0.9)
    ax1.plot(t[win] * 1e3, Vc[win], label="V_c", linewidth=0.9)
    ax1.axvline(R_t * 1e3, color="k", linestyle="--", alpha=0.5, linewidth=0.8)
    ax1.set_xlabel("Time (ms)")
    ax1.set_ylabel("V_load (V)")
    ax1.set_title("Stage 5a - 3-phase load voltages around load step (R_load: 2.94 -> 2.06 ohm)")
    ax1.legend(loc="upper right", ncol=3, fontsize=8)
    ax1.grid(True, alpha=0.3)

    # --- (2) V_d / V_q tracking ---
    ax2 = fig.add_subplot(gs[1, :])
    ax2.plot(t, d["Vload_d"], label="V_d (sim)", linewidth=1.0)
    ax2.plot(t, d["Vload_q"], label="V_q (sim)", linewidth=1.0)
    ax2.axhline(d["V_set"], color="red", linestyle="--", linewidth=0.8,
                label=f"V_d_ref = {d['V_set']:.1f} V")
    ax2.axvline(R_t, color="k", linestyle="--", alpha=0.5, linewidth=0.8)
    ax2.set_xlabel("Time (s)")
    ax2.set_ylabel("V (V)")
    ax2.set_title("dq voltage tracking - inner loop holds V_d during disturbance")
    ax2.legend(loc="center right", fontsize=8)
    ax2.grid(True, alpha=0.3)

    # --- (3) Frequency ---
    ax3 = fig.add_subplot(gs[2, 0])
    f = d["freq"]
    ax3.plot(t, f, linewidth=1.0, label="f (Swing Eq)")
    ax3.axhline(d["f_base"], color="gray", linestyle=":", linewidth=0.8,
                label=f"f_base = {d['f_base']:.0f} Hz")
    ax3.axhline(d["f_base"] + d["df_ss_pred"], color="red", linestyle="--",
                linewidth=0.8, label=f"f_ss_pred = {d['f_ss_pred']:.3f} Hz")
    ax3.axvline(R_t, color="k", linestyle="--", alpha=0.5, linewidth=0.8)
    ax3.set_xlabel("Time (s)")
    ax3.set_ylabel("Frequency (Hz)")
    ax3.set_title("Frequency response (droop pulls f down on load increase)")
    ax3.legend(loc="upper right", fontsize=7)
    ax3.grid(True, alpha=0.3)

    # --- (4) Active power ---
    ax4 = fig.add_subplot(gs[2, 1])
    ax4.plot(t, d["P_meas"], linewidth=1.0, label="P_meas (3-phase)")
    ax4.axhline(d["P_ss_pre"], color="gray", linestyle=":", linewidth=0.8,
                label=f"P_pre = {d['P_ss_pre']:.1f} W")
    ax4.axhline(d["P_ss_post"], color="red", linestyle="--", linewidth=0.8,
                label=f"P_post = {d['P_ss_post']:.1f} W")
    ax4.axvline(R_t, color="k", linestyle="--", alpha=0.5, linewidth=0.8)
    ax4.set_xlabel("Time (s)")
    ax4.set_ylabel("P (W)")
    ax4.set_title("Active power - measured vs analytical")
    ax4.legend(loc="lower right", fontsize=7)
    ax4.grid(True, alpha=0.3)

    fig.suptitle("Stage 5a - VSG with full 3-phase abc switching layer (V_dc=48 V, SPWM 10 kHz)",
                 fontsize=11, fontweight="bold")
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    print(f"Plot saved : {out_path}")


def main() -> None:
    d = load(DATA_PATH)
    report(d)
    make_plot(d, PLOT_DIR / "phase5a_switching.png")


if __name__ == "__main__":
    main()
