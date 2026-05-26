"""
VSG Project — Stage 1 post-processing.

Reads `matlab/vsg_stage1_out.mat` written by `phase1_swing_equation.m`,
computes the classical swing-equation metrics (nadir, RoCoF, steady-state
deviation), and writes a PNG plot to `python/plots/phase1_swing.png`.

Run from anywhere — paths are anchored to this file's location.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")          # headless backend — no GUI window required
import matplotlib.pyplot as plt
import numpy as np
import scipy.io as sio


HERE      = Path(__file__).resolve().parent
DATA_PATH = HERE.parents[1] / "matlab" / "vsg_stage1_out.mat"
PLOT_DIR  = HERE.parent / "plots"
PLOT_DIR.mkdir(exist_ok=True)


def load_simulation_data(path: Path) -> dict:
    raw = sio.loadmat(path, squeeze_me=True)
    return {
        "t":            np.asarray(raw["t"]).flatten(),
        "omega":        np.asarray(raw["omega"]).flatten(),
        "delta":        np.asarray(raw["delta"]).flatten(),
        "freq":         np.asarray(raw["freq"]).flatten(),
        "Pe":           np.asarray(raw["Pe_vec"]).flatten(),
        "H":            float(raw["H"]),
        "D":            float(raw["D"]),
        "f_base":       float(raw["f_base"]),
        "Pm_initial":   float(raw["Pm_initial"]),
        "Pm_step":      float(raw["Pm_step"]),
        "Pm_step_time": float(raw["Pm_step_time"]),
    }


def compute_metrics(d: dict) -> dict:
    f, t   = d["freq"], d["t"]
    f_base = d["f_base"]

    # RoCoF — sample over a 100 ms window starting at the step instant
    t_step = d["Pm_step_time"]
    mask   = (t >= t_step) & (t <= t_step + 0.1)
    if mask.sum() >= 2:
        rocof = np.polyfit(t[mask], f[mask], 1)[0]   # Hz/s
    else:
        rocof = float("nan")

    f_min = float(f.min())
    metrics = {
        "f_nadir":  f_min,
        "t_nadir":  float(t[f.argmin()]),
        "nadir_dev": f_base - f_min,
        "f_ss":     float(f[-1]),
        "ss_dev":   float(f[-1] - f_base),
        "rocof":    float(rocof),
    }

    print("Stage 1 metrics")
    print(f"  Nadir          : {metrics['f_nadir']:.4f} Hz at t = {metrics['t_nadir']:.3f} s")
    print(f"  Nadir deviation: {metrics['nadir_dev']:+.4f} Hz")
    print(f"  Steady-state   : {metrics['f_ss']:.4f} Hz  ({metrics['ss_dev']:+.4f} Hz)")
    print(f"  RoCoF (100 ms) : {metrics['rocof']:+.4f} Hz/s")
    return metrics


def plot_results(d: dict, m: dict) -> Path:
    f_base = d["f_base"]
    t_step = d["Pm_step_time"]

    fig, axes = plt.subplots(2, 1, figsize=(10, 7), sharex=True)
    fig.suptitle(
        f"VSG Stage 1 — Swing-Equation Response  [H = {d['H']:g} s, D = {d['D']:g}]",
        fontsize=13, fontweight="bold",
    )

    ax = axes[0]
    ax.plot(d["t"], d["freq"], color="steelblue", linewidth=1.8, label="f(t)")
    ax.axhline(f_base, color="red",  linestyle="--", linewidth=1, label=f"f_s = {f_base:g} Hz")
    ax.axvline(t_step, color="gray", linestyle=":",  linewidth=1, label=f"ΔP_m = +{d['Pm_step']:g} pu")
    ax.scatter([m["t_nadir"]], [m["f_nadir"]], color="red", zorder=5, label="nadir")
    ax.set_ylabel("Frequency (Hz)")
    ax.set_title(f"Frequency response — nadir {m['nadir_dev']:+.3f} Hz, steady-state {m['ss_dev']:+.3f} Hz")
    ax.legend(loc="best")
    ax.grid(True, alpha=0.4)

    ax = axes[1]
    ax.plot(d["t"], np.degrees(d["delta"]), color="mediumpurple", linewidth=1.8)
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_ylabel("Rotor angle δ (deg)")
    ax.set_xlabel("Time (s)")
    ax.set_title("Virtual rotor angle δ(t)")
    ax.grid(True, alpha=0.4)

    plt.tight_layout()
    out = PLOT_DIR / "phase1_swing.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Plot saved : {out}")
    return out


if __name__ == "__main__":
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"{DATA_PATH} not found — run matlab/phase1_swing_equation.m first."
        )
    data    = load_simulation_data(DATA_PATH)
    metrics = compute_metrics(data)
    plot_results(data, metrics)
