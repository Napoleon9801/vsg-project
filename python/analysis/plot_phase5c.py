"""
VSG Project - Stage 5c post-processing.

Compares Stage 5c (R_d damping + dq feedforward) against Stage 5a
(untuned baseline). Both share the same outer VSG loop, plant, and
load step — only the inner control architecture and filter damping
differ:

  Stage 5a : R_f only (zeta ~ 0.002), no FF              -> baseline
  Stage 5c : R_d = 5 Ohm series w/ C_f (zeta ~ 0.23) +   -> tuned
             V_load + omega*L_f cross-coupling FF in
             inner current loop

Disturbance times differ between the two runs (5a at t=0.2s, 5c at
t=1.0s) so we align both on t' = t - R_load_t for the overlays.

Outputs to python/plots/:
  phase5c_compare_Vload.png   (3-phase voltage near disturbance)
  phase5c_compare_iLdq.png    (d-axis + q-axis current tracking)
  phase5c_compare_f_P.png     (frequency + active power — control sanity)
"""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.io as sio


HERE     = Path(__file__).resolve().parent
DATA_DIR = HERE.parents[1] / "matlab"
PLOT_DIR = HERE.parent / "plots"
PLOT_DIR.mkdir(exist_ok=True)

PATH_5A_ORIG    = DATA_DIR / "vsg_stage5a_out.mat"
PATH_5A_MATCHED = DATA_DIR / "vsg_stage5a_matched_out.mat"
PATH_5C         = DATA_DIR / "vsg_stage5c_out.mat"

# Prefer the matched-operating-point baseline if available — it isolates
# the R_d + FF effect from the H/D effect by sharing the 5c op-point.
if PATH_5A_MATCHED.exists():
    PATH_5A = PATH_5A_MATCHED
    BASELINE_TAG = "5a matched (H=5, D=0.5)"
else:
    PATH_5A = PATH_5A_ORIG
    BASELINE_TAG = "5a original (H=5, D=0)"


def _flat(arr) -> np.ndarray:
    return np.asarray(arr).flatten()


def _scalar(arr) -> float:
    return float(np.asarray(arr).flatten()[0])


def load_run(path: Path) -> dict:
    raw = sio.loadmat(path, squeeze_me=True, struct_as_record=False)
    out = {
        "t":         _flat(raw["t"]),
        "freq":      _flat(raw["freq"]),
        "Vload_d":   _flat(raw["Vload_d"]),
        "Vload_q":   _flat(raw["Vload_q"]),
        "iL_d":      _flat(raw["iL_d"]),
        "iL_q":      _flat(raw["iL_q"]),
        "Vload_abc": np.asarray(raw["Vload_abc"]),
        "iL_abc":    np.asarray(raw["iL_abc"]),
        "P_meas":    _flat(raw["P_meas"]),
        "Q_meas":    _flat(raw["Q_meas"]),
        "R_load_t":  _scalar(raw["R_load_t"]),
        "H":         _scalar(raw["H"]),
        "D":         _scalar(raw["D"]),
        "L_f":       _scalar(raw["L_f"]),
        "C_f":       _scalar(raw["C_f"]),
        "R_f":       _scalar(raw["R_f"]),
        "f_res":     _scalar(raw["f_res"]),
        "f_base":    _scalar(raw["f_base"]),
    }
    # R_d / zeta_filter only exist in 5c
    out["R_d"]         = _scalar(raw["R_d"])         if "R_d" in raw else 0.0
    out["zeta_filter"] = _scalar(raw["zeta_filter"]) if "zeta_filter" in raw else \
                         out["R_f"] / 2 * np.sqrt(out["C_f"] / out["L_f"])
    return out


def _phase_pick(arr_abc: np.ndarray) -> np.ndarray:
    """Return phase-a column of an Nx3 array (or itself if already 1D)."""
    a = np.asarray(arr_abc)
    if a.ndim == 1:
        return a
    # MATLAB To Workspace + Timeseries can land as Nx3 or 3xN. Pick the
    # axis of length 3.
    if a.shape[1] == 3:
        return a[:, 0]
    if a.shape[0] == 3:
        return a[0, :]
    raise ValueError(f"Unexpected Vload_abc shape {a.shape}")


def plot_vload_compare(d5a: dict, d5c: dict, out_path: Path) -> None:
    """3-phase V_load around disturbance — ringing reduction story."""
    fig, axes = plt.subplots(1, 2, figsize=(13, 5), sharey=True)

    for ax, d, label in zip(axes, [d5a, d5c], ["Stage 5a (untuned)",
                                                "Stage 5c (R_d + FF)"]):
        t_rel = d["t"] - d["R_load_t"]
        Va = d["Vload_abc"]
        if Va.ndim == 2 and Va.shape[1] == 3:
            ax.plot(t_rel, Va[:, 0], "r-", linewidth=0.8, label="V_a")
            ax.plot(t_rel, Va[:, 1], "g-", linewidth=0.8, label="V_b")
            ax.plot(t_rel, Va[:, 2], "b-", linewidth=0.8, label="V_c")
        elif Va.ndim == 2 and Va.shape[0] == 3:
            ax.plot(t_rel, Va[0, :], "r-", linewidth=0.8, label="V_a")
            ax.plot(t_rel, Va[1, :], "g-", linewidth=0.8, label="V_b")
            ax.plot(t_rel, Va[2, :], "b-", linewidth=0.8, label="V_c")
        else:
            ax.plot(t_rel, Va, linewidth=0.8, label="V_a (1D)")

        ax.axvline(0, color="k", linestyle="--", linewidth=0.9, alpha=0.6,
                   label="R_load step")
        ax.set_xlim(-0.005, 0.025)
        ax.set_xlabel("t - R_load_t  (s)")
        ax.set_title(f"{label}\n"
                     f"$\\zeta$ = {d['zeta_filter']:.3f}, "
                     f"R_d = {d['R_d']:.1f} $\\Omega$",
                     fontsize=10)
        ax.grid(True, alpha=0.3)
        ax.legend(loc="upper right", fontsize=8, ncol=2)

    axes[0].set_ylabel("V_load (V)")
    fig.suptitle(
        "Stage 5c vs 5a — LC filter damping at disturbance "
        f"(f_res ~ {d5a['f_res']:.0f} Hz)",
        fontsize=12, fontweight="bold",
    )
    fig.tight_layout(rect=[0, 0, 1, 0.94])
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    print(f"  V_load compare : {out_path}")


def plot_iLdq_compare(d5a: dict, d5c: dict, out_path: Path) -> None:
    """i_L_d and i_L_q around disturbance — current tracking + decoupling."""
    fig, axes = plt.subplots(2, 1, figsize=(11, 7), sharex=True)

    for d, label, color5a, color5c in [(d5a, "5a", "tab:red", None),
                                         (d5c, "5c", None, "tab:blue")]:
        t_rel = d["t"] - d["R_load_t"]
        col = color5a if color5a is not None else color5c
        suffix = label
        axes[0].plot(t_rel, d["iL_d"], color=col, linewidth=1.4,
                     label=f"i_Ld ({suffix})")
        axes[1].plot(t_rel, d["iL_q"], color=col, linewidth=1.4,
                     label=f"i_Lq ({suffix})")

    for ax, ylab in zip(axes, ["i_L_d (A)", "i_L_q (A)"]):
        ax.axvline(0, color="k", linestyle="--", linewidth=0.9, alpha=0.6)
        ax.set_xlim(-0.05, 0.5)
        ax.set_ylabel(ylab)
        ax.grid(True, alpha=0.3)
        ax.legend(loc="best", fontsize=9)

    axes[1].set_xlabel("t - R_load_t  (s)")
    fig.suptitle(
        "Stage 5c vs 5a — inner current loop tracking around R_load step",
        fontsize=12, fontweight="bold",
    )
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    print(f"  iLdq compare   : {out_path}")


def plot_f_P_compare(d5a: dict, d5c: dict, out_path: Path) -> None:
    """f(t) and P(t) around disturbance — outer-loop sanity check."""
    fig, axes = plt.subplots(2, 1, figsize=(11, 7), sharex=True)

    pairs = [
        (d5a, f"5a (D={d5a['D']:.1f}, no FF, R_d=0)", "tab:red"),
        (d5c, f"5c (D={d5c['D']:.1f}, FF on, R_d={d5c['R_d']:.1f})", "tab:blue"),
    ]
    for d, label, color in pairs:
        t_rel = d["t"] - d["R_load_t"]
        axes[0].plot(t_rel, d["freq"],   color=color, linewidth=1.4,
                     label=f"f  {label}")
        axes[1].plot(t_rel, d["P_meas"], color=color, linewidth=1.4,
                     label=f"P  {label}")

    axes[0].axhline(d5a["f_base"], color="k", linestyle=":",
                    linewidth=0.8, alpha=0.6, label=f"f_n = {d5a['f_base']:.0f} Hz")

    for ax in axes:
        ax.axvline(0, color="k", linestyle="--", linewidth=0.9, alpha=0.6)
        ax.set_xlim(-0.1, 2.0)
        ax.grid(True, alpha=0.3)
        ax.legend(loc="best", fontsize=9)

    axes[0].set_ylabel("f (Hz)")
    axes[1].set_ylabel("P (W)")
    axes[1].set_xlabel("t - R_load_t  (s)")
    fig.suptitle(
        "Stage 5c vs 5a — outer loop (frequency + active power)",
        fontsize=12, fontweight="bold",
    )
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    print(f"  f/P compare    : {out_path}")


def print_summary(d5a: dict, d5c: dict) -> None:
    print("\n=== Stage 5a vs 5c summary ===")
    print(f"  5a: H={d5a['H']:.1f}, D={d5a['D']:.2f}, "
          f"R_d=0,    zeta={d5a['zeta_filter']:.4f}")
    print(f"  5c: H={d5c['H']:.1f}, D={d5c['D']:.2f}, "
          f"R_d={d5c['R_d']:.1f}, zeta={d5c['zeta_filter']:.4f}")

    # Ringing peak-to-peak amplitude estimate in V_load (phase a) within
    # the 20 ms after disturbance.
    for d, tag in [(d5a, "5a"), (d5c, "5c")]:
        t_rel = d["t"] - d["R_load_t"]
        mask = (t_rel >= 0) & (t_rel <= 0.02)
        Va = _phase_pick(d["Vload_abc"])
        seg = Va[mask] if mask.sum() else Va
        if seg.size:
            ripple = float(seg.max() - seg.min())
            print(f"  {tag}: V_load,a peak-to-peak 0-20 ms post-disturb "
                  f"= {ripple:.2f} V")


def main() -> None:
    missing = [p for p in [PATH_5A, PATH_5C] if not p.exists()]
    if missing:
        for p in missing:
            print(f"  MISSING: {p}")
        print("Run phase5a_switching_abc.m and phase5c_tuned.m first.")
        return

    print(f"Stage 5c comparison plots")
    print(f"  baseline   : {PATH_5A.name}  [{BASELINE_TAG}]")
    print(f"  tuned      : {PATH_5C.name}")

    d5a = load_run(PATH_5A)
    d5c = load_run(PATH_5C)

    plot_vload_compare(d5a, d5c, PLOT_DIR / "phase5c_compare_Vload.png")
    plot_iLdq_compare(d5a, d5c,  PLOT_DIR / "phase5c_compare_iLdq.png")
    plot_f_P_compare(d5a, d5c,   PLOT_DIR / "phase5c_compare_f_P.png")

    print_summary(d5a, d5c)
    print("Done.")


if __name__ == "__main__":
    main()
