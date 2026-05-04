"""
VSG Phase 2 — Post-processing: Secondary Frequency Restoration & Q-V Droop.
Reads phase2_power_control.mat exported from vsg_phase2_sim.m.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import scipy.io as sio
from pathlib import Path

DATA_PATH = Path(__file__).parents[2] / "matlab" / "data" / "phase2_power_control.mat"
PLOT_PATH = Path(__file__).parents[1] / "plots"
PLOT_PATH.mkdir(exist_ok=True)


def load(path: Path) -> dict:
    raw = sio.loadmat(path)
    return {k: raw[k].flatten() for k in
            ["t", "freq_p1", "freq_p2", "Pm_p2", "delta_p2", "E_p2", "Q_p2", "Pe_p2"]}


def print_metrics(d: dict) -> None:
    for label, freq in [("Phase 1 (no secondary)", d["freq_p1"]),
                        ("Phase 2 (with secondary)", d["freq_p2"])]:
        nadir     = freq.min()
        t_nadir   = d["t"][freq.argmin()]
        steady    = freq[-1]
        deviation = 50.0 - nadir
        print(f"\n{label}")
        print(f"  Nadir          : {nadir:.4f} Hz  at t = {t_nadir:.3f} s")
        print(f"  Deviation      : -{deviation:.4f} Hz")
        print(f"  Steady-state   : {steady:.4f} Hz")

    pm_final = d["Pm_p2"][-1]
    print(f"\nSecondary controller — final Pm : {pm_final:.2f} W  (ref was 500 W, load stepped to 600 W)")


def plot(d: dict) -> None:
    fig, axes = plt.subplots(3, 1, figsize=(11, 9), sharex=True)
    fig.suptitle("VSG Phase 2 — Active Power Control & Secondary Frequency Restoration",
                 fontsize=13, fontweight="bold")

    # ── Frequency comparison ────────────────────────────────────────────────
    ax = axes[0]
    ax.plot(d["t"], d["freq_p1"], color="tomato",     lw=1.5, ls="--", label="Phase 1 (no secondary)")
    ax.plot(d["t"], d["freq_p2"], color="steelblue",  lw=2.0,          label="Phase 2 (with secondary)")
    ax.axhline(50.0, color="black",  lw=0.8, ls=":",  label="f_n = 50 Hz")
    ax.axvline(1.0,  color="gray",   lw=0.8, ls=":",  label="Load step t = 1 s")
    ax.set_ylabel("Frequency (Hz)")
    ax.set_title("Frequency Response — Phase 1 vs Phase 2")
    ax.legend(loc="lower right", fontsize=9)
    ax.grid(True, alpha=0.35)

    # ── Pm adaptation ───────────────────────────────────────────────────────
    ax = axes[1]
    ax.plot(d["t"], d["Pm_p2"], color="seagreen", lw=2.0)
    ax.axhline(500, color="gray",  lw=0.8, ls="--", label="Pm_ref = 500 W")
    ax.axhline(600, color="red",   lw=0.8, ls="--", label="Load = 600 W")
    ax.axvline(1.0, color="gray",  lw=0.8, ls=":")
    ax.set_ylabel("Pm (W)")
    ax.set_title("Virtual Mechanical Power Pm(t) — Secondary Controller Output")
    ax.legend(loc="lower right", fontsize=9)
    ax.grid(True, alpha=0.35)

    # ── Rotor angle ─────────────────────────────────────────────────────────
    ax = axes[2]
    ax.plot(d["t"], np.degrees(d["delta_p2"]), color="mediumpurple", lw=2.0)
    ax.axvline(1.0, color="gray", lw=0.8, ls=":")
    ax.set_ylabel("δ (deg)")
    ax.set_xlabel("Time (s)")
    ax.set_title("Virtual Rotor Angle δ(t)")
    ax.grid(True, alpha=0.35)

    plt.tight_layout()
    out = PLOT_PATH / "phase2_power_control.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"\nPlot saved to {out}")


if __name__ == "__main__":
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"Run vsg_phase2_sim.m in MATLAB first to generate {DATA_PATH}"
        )
    d = load(DATA_PATH)
    print_metrics(d)
    plot(d)
