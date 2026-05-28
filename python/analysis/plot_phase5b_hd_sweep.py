"""
VSG Project - Stage 5b post-processing (H-D sensitivity sweep).

Reads matlab/data/hd_sweep_results.mat (or _smoke.mat) and produces
Chapter 4 headline figures:

  F1 : 2x3 heatmap grid of (H, D) -> {RoCoF, nadir, overshoot, t_settle,
                                       f_ss, P_ss}
  F2 : f(t) overlay for H ∈ {0, 3, 5, 10} at D=20 fixed  (HEADLINE)
  F3 : f(t) overlay for D ∈ {0, 10, 40} at H=5 fixed
  CSV: summary table (30 rows for full sweep, 4 for smoke)

Outputs go to python/plots/.
"""

from __future__ import annotations

import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.colors as mcolors
import matplotlib.pyplot as plt
import numpy as np
import scipy.io as sio


HERE      = Path(__file__).resolve().parent
DATA_DIR  = HERE.parents[1] / "matlab" / "data"
PLOT_DIR  = HERE.parent / "plots"
PLOT_DIR.mkdir(exist_ok=True)

# Prefer full sweep file; fall back to smoke if only that exists
FULL_PATH  = DATA_DIR / "hd_sweep_results.mat"
SMOKE_PATH = DATA_DIR / "hd_sweep_results_smoke.mat"

if FULL_PATH.exists():
    DATA_PATH = FULL_PATH
    TAG = "phase5b"
elif SMOKE_PATH.exists():
    DATA_PATH = SMOKE_PATH
    TAG = "phase5b_smoke"
else:
    raise FileNotFoundError(
        f"Neither {FULL_PATH} nor {SMOKE_PATH} found. Run phase5b_hd_sweep.m first."
    )


def load_sweep(path: Path) -> dict:
    """Load the .mat file produced by phase5b_hd_sweep.m."""
    raw = sio.loadmat(path, squeeze_me=False, struct_as_record=False)

    H_grid = np.asarray(raw["H_grid"]).flatten()
    D_grid = np.asarray(raw["D_grid"]).flatten()

    # metrics is a MATLAB struct -> scipy.io mat_struct
    m_raw = raw["metrics"][0, 0]
    metrics = {}
    for key in ["max_RoCoF", "nadir_f", "overshoot_f", "t_settle",
                "f_ss", "P_ss"]:
        metrics[key] = np.asarray(getattr(m_raw, key))

    # ts is a struct array (nH x nD).  scipy returns as ndarray of mat_struct.
    ts_raw = raw["ts"]
    nH = len(H_grid)
    nD = len(D_grid)
    ts = np.empty((nH, nD), dtype=object)
    for i in range(nH):
        for j in range(nD):
            s = ts_raw[i, j]
            ts[i, j] = {
                "t":      np.asarray(s.t).flatten(),
                "f_inv":  np.asarray(s.f_inv).flatten(),
                "P_meas": np.asarray(s.P_meas).flatten(),
                "V_d":    np.asarray(s.V_d).flatten(),
                "delta":  np.asarray(s.delta).flatten(),
            }

    meta_raw = raw["meta"][0, 0]
    meta = {
        "T_sim":      float(np.asarray(meta_raw.T_sim).flatten()[0]),
        "R_load_t":   float(np.asarray(meta_raw.R_load_t).flatten()[0]),
        "f_base":     float(np.asarray(meta_raw.f_base).flatten()[0]),
        "smoke_only": bool(int(np.asarray(meta_raw.smoke_only).flatten()[0])),
    }

    return {
        "H_grid":  H_grid,
        "D_grid":  D_grid,
        "metrics": metrics,
        "ts":      ts,
        "meta":    meta,
    }


# ---------------------------------------------------------------------------
# F1: heatmaps
# ---------------------------------------------------------------------------

def plot_heatmaps(d: dict, out_path: Path) -> None:
    H_grid = d["H_grid"]
    D_grid = d["D_grid"]
    m = d["metrics"]

    keys_titles = [
        ("max_RoCoF",   "max |df/dt|  (Hz/s)"),
        ("nadir_f",     "nadir f  (Hz)"),
        ("overshoot_f", "|nadir - f_ss|  (Hz)"),
        ("t_settle",    "t_settle  (s)"),
        ("f_ss",        "f_ss  (Hz)"),
        ("P_ss",        "P_ss  (W)"),
    ]

    nH = len(H_grid)
    nD = len(D_grid)

    fig, axes = plt.subplots(2, 3, figsize=(13, 7.5))
    for ax, (key, title) in zip(axes.flat, keys_titles):
        Z = m[key].copy()
        # max_RoCoF in H=0 row is a numerical-derivative artifact of the
        # near-algebraic swing eq (H_eff = 0.01). Mask it so the colorbar
        # spans only physically meaningful values.
        if key == "max_RoCoF" and 0 in H_grid.tolist():
            i0 = int(np.where(H_grid == 0)[0][0])
            Z[i0, :] = np.nan
            norm = mcolors.LogNorm(vmin=np.nanmin(Z[Z > 0]),
                                    vmax=np.nanmax(Z))
        else:
            norm = None
        im = ax.imshow(
            Z, aspect="auto", origin="lower",
            extent=[-0.5, nD - 0.5, -0.5, nH - 0.5],
            interpolation="nearest", cmap="viridis", norm=norm,
        )
        for i in range(nH):
            for j in range(nD):
                val = Z[i, j]
                orig = m[key][i, j]
                if np.isnan(val):
                    txt = "—" if key == "max_RoCoF" else "NaN"
                else:
                    txt = f"{orig:.2f}"
                ax.text(j, i, txt, ha="center", va="center",
                        color="white", fontsize=7)
        ax.set_xticks(range(nD))
        ax.set_xticklabels([f"{v:g}" for v in D_grid])
        ax.set_yticks(range(nH))
        ax.set_yticklabels([f"{v:g}" for v in H_grid])
        ax.set_xlabel("D")
        ax.set_ylabel("H")
        ax.set_title(title, fontsize=10)
        fig.colorbar(im, ax=ax, shrink=0.85)

    fig.suptitle(
        "Stage 5b - H-D sensitivity heatmaps (islanded VSG, R_load step)",
        fontsize=12, fontweight="bold",
    )
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    print(f"  F1 heatmaps : {out_path}")


# ---------------------------------------------------------------------------
# F2: inertia overlay  (HEADLINE)
# ---------------------------------------------------------------------------

def plot_inertia_overlay(d: dict, out_path: Path) -> None:
    H_grid = d["H_grid"]
    D_grid = d["D_grid"]
    ts     = d["ts"]
    meta   = d["meta"]

    # Pick H values present in the grid; for smoke runs we may have a subset
    H_pick_target = [0, 3, 5, 10]
    H_pick = [h for h in H_pick_target if h in H_grid.tolist()]
    if not H_pick:
        print("  F2 skipped: no requested H values present in sweep")
        return

    # D=0 fixed: headline figure — at D=0 the inertia effect is most
    # dramatic. H=0 (pure droop) shows instant frequency step; H>0 shows
    # progressively slower, smoother nadir characteristic of VSG.
    D_fix = 0
    if D_fix not in D_grid.tolist():
        D_fix = float(D_grid[np.argmin(np.abs(D_grid - 0))])
    j_fix = int(np.where(D_grid == D_fix)[0][0])

    fig, ax = plt.subplots(figsize=(10, 5.5))
    colors = ["tab:red", "tab:orange", "tab:green", "tab:blue"]
    # f_ss reference: use H=0 case (settles fast → most representative of
    # true post-disturbance steady state). High-H low-D cases are still
    # settling at T_sim=3s so their reported f_ss is biased high.
    i_ref = int(np.where(H_grid == 0)[0][0]) if 0 in H_grid.tolist() else 0
    f_ss_ref = float(d["metrics"]["f_ss"][i_ref, j_fix])
    for k, h_val in enumerate(H_pick):
        i = int(np.where(H_grid == h_val)[0][0])
        rec = ts[i, j_fix]
        label = f"H = {h_val}" + (" (droop only)" if h_val == 0 else "")
        ax.plot(rec["t"], rec["f_inv"], linewidth=1.7,
                color=colors[k % len(colors)], label=label)

    ax.axhline(f_ss_ref, color="k", linestyle=":", linewidth=0.8,
               alpha=0.6, label=f"droop f_ss = {f_ss_ref:.3f} Hz")
    ax.axvline(meta["R_load_t"], color="k", linestyle="--", linewidth=0.9,
               alpha=0.7, label=f"R_load step @ t = {meta['R_load_t']:.1f} s")
    # Crop to disturbance window — exclude model startup artifact (0-0.5s).
    ax.set_xlim(meta["R_load_t"] - 0.1, meta["T_sim"])
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("f (Hz)")
    ax.set_title(
        f"Inertial response: H=0 (Droop) vs VSG with H>0  (D={D_fix} fixed)",
        fontweight="bold",
    )
    ax.grid(True, alpha=0.3)
    ax.legend(loc="lower right", fontsize=9)

    fig.tight_layout()
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    print(f"  F2 overlay  : {out_path}")


# ---------------------------------------------------------------------------
# F3: damping overlay
# ---------------------------------------------------------------------------

def plot_damping_overlay(d: dict, out_path: Path) -> None:
    H_grid = d["H_grid"]
    D_grid = d["D_grid"]
    ts     = d["ts"]
    meta   = d["meta"]

    # D progression: 0 (undamped, visible oscillation) → 0.5 (moderate) →
    # 2 (over-damped, near-flat). Spans the full damping regime in the
    # revised grid {0, 0.5, 1, 2, 5}.
    D_pick_target = [0, 0.5, 2]
    D_pick = [dv for dv in D_pick_target if dv in D_grid.tolist()]
    if not D_pick:
        print("  F3 skipped: no requested D values present in sweep")
        return

    if 5 in H_grid.tolist():
        H_fix = 5
    else:
        H_fix = int(H_grid[np.argmin(np.abs(H_grid - 5))])
    i_fix = int(np.where(H_grid == H_fix)[0][0])

    fig, ax = plt.subplots(figsize=(10, 5.5))
    colors = ["tab:red", "tab:green", "tab:blue"]
    for k, d_val in enumerate(D_pick):
        j = int(np.where(D_grid == d_val)[0][0])
        rec = ts[i_fix, j]
        ax.plot(rec["t"], rec["f_inv"], linewidth=1.7,
                color=colors[k % len(colors)], label=f"D = {d_val}")

    ax.axvline(meta["R_load_t"], color="k", linestyle="--", linewidth=0.9,
               alpha=0.7, label=f"R_load step @ t = {meta['R_load_t']:.1f} s")
    # Crop to disturbance window — exclude model startup artifact (0-0.5s).
    ax.set_xlim(meta["R_load_t"] - 0.1, meta["T_sim"])
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("f (Hz)")
    ax.set_title(
        f"Damping effect on frequency response  (H={H_fix} fixed)",
        fontweight="bold",
    )
    ax.grid(True, alpha=0.3)
    ax.legend(loc="lower right", fontsize=9)

    fig.tight_layout()
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    print(f"  F3 overlay  : {out_path}")


# ---------------------------------------------------------------------------
# CSV
# ---------------------------------------------------------------------------

def write_summary_csv(d: dict, out_path: Path) -> None:
    H_grid = d["H_grid"]
    D_grid = d["D_grid"]
    m      = d["metrics"]

    with open(out_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["H", "D", "max_RoCoF_Hz_per_s", "nadir_f_Hz",
                    "overshoot_f_Hz", "t_settle_s", "f_ss_Hz", "P_ss_W"])
        for i, h_val in enumerate(H_grid):
            for j, d_val in enumerate(D_grid):
                w.writerow([
                    f"{h_val:g}", f"{d_val:g}",
                    f"{m['max_RoCoF'][i,j]:.4f}",
                    f"{m['nadir_f'][i,j]:.4f}",
                    f"{m['overshoot_f'][i,j]:.4f}",
                    f"{m['t_settle'][i,j]:.4f}",
                    f"{m['f_ss'][i,j]:.4f}",
                    f"{m['P_ss'][i,j]:.4f}",
                ])
    print(f"  CSV summary : {out_path}")


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main() -> None:
    print(f"Stage 5b post-processing  (source: {DATA_PATH.name})")
    d = load_sweep(DATA_PATH)

    plot_heatmaps(d,         PLOT_DIR / f"{TAG}_F1_heatmaps.png")
    plot_inertia_overlay(d,  PLOT_DIR / f"{TAG}_F2_inertia_overlay.png")
    plot_damping_overlay(d,  PLOT_DIR / f"{TAG}_F3_damping_overlay.png")
    write_summary_csv(d,     PLOT_DIR / f"{TAG}_hd_sweep_summary.csv")

    print("Done.")


if __name__ == "__main__":
    main()
