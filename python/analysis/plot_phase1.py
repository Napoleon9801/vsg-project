"""
VSG Phase 1 — Post-processing and plotting from MATLAB simulation output.
Reads phase1_swing.mat exported from vsg_swing_sim.m.
"""

import numpy as np
import matplotlib
matplotlib.use("Agg")  # non-interactive — saves PNG without opening a GUI window
import matplotlib.pyplot as plt
import scipy.io as sio
from pathlib import Path

DATA_PATH = Path(__file__).parents[2] / "matlab" / "data" / "phase1_swing.mat"
PLOT_PATH = Path(__file__).parents[1] / "plots"
PLOT_PATH.mkdir(exist_ok=True)


def load_simulation_data(path: Path) -> dict:
    data = sio.loadmat(path)
    return {
        "t":     data["t"].flatten(),
        "omega": data["omega"].flatten(),
        "delta": data["delta"].flatten(),
        "freq":  data["freq"].flatten(),
        "Pe":    data["Pe"].flatten(),
    }


def compute_metrics(d: dict) -> None:
    f_min = d["freq"].min()
    t_min = d["t"][d["freq"].argmin()]
    steady = d["freq"][-1]
    nadir = 50.0 - f_min

    print(f"Frequency nadir    : {f_min:.4f} Hz at t = {t_min:.3f} s")
    print(f"Frequency deviation: -{nadir:.4f} Hz")
    print(f"Steady-state freq  : {steady:.4f} Hz")


def plot_results(d: dict) -> None:
    fig, axes = plt.subplots(2, 1, figsize=(10, 7), sharex=True)
    fig.suptitle("VSG Phase 1 — Swing Equation Response", fontsize=13, fontweight="bold")

    axes[0].plot(d["t"], d["freq"], color="steelblue", linewidth=1.8, label="f(t)")
    axes[0].axhline(50.0, color="red", linestyle="--", linewidth=1, label="f_n = 50 Hz")
    axes[0].axvline(1.0,  color="gray", linestyle=":", linewidth=1, label="Load step")
    axes[0].set_ylabel("Frequency (Hz)")
    axes[0].set_title("Frequency Response to 20% Load Step at t = 1 s")
    axes[0].legend()
    axes[0].grid(True, alpha=0.4)

    axes[1].plot(d["t"], np.degrees(d["delta"]), color="mediumpurple", linewidth=1.8)
    axes[1].axvline(1.0, color="gray", linestyle=":", linewidth=1)
    axes[1].set_ylabel("Rotor Angle δ (deg)")
    axes[1].set_xlabel("Time (s)")
    axes[1].set_title("Virtual Rotor Angle δ(t)")
    axes[1].grid(True, alpha=0.4)

    plt.tight_layout()
    out = PLOT_PATH / "phase1_swing.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Plot saved to {out}")


if __name__ == "__main__":
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"Run vsg_swing_sim.m in MATLAB first to generate {DATA_PATH}"
        )
    d = load_simulation_data(DATA_PATH)
    compute_metrics(d)
    plot_results(d)
