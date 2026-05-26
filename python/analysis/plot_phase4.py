"""
VSG Project — Stage 4 post-processing.

Reads `matlab/vsg_stage4_out.mat` written by `phase4_inverter_dq.m`,
plots the full dq state set (V_C, i_L, i_load), measured P & Q, and the
P-f droop characteristic with operating-point shift. Verifies the
steady-state numbers against analytical predictions.

Writes a PNG to `python/plots/phase4_dq.png`.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.io as sio


HERE      = Path(__file__).resolve().parent
DATA_PATH = HERE.parents[1] / "matlab" / "vsg_stage4_out.mat"
PLOT_DIR  = HERE.parent / "plots"
PLOT_DIR.mkdir(exist_ok=True)


def load(path: Path) -> dict:
    raw = sio.loadmat(path, squeeze_me=True)
    out: dict = {}
    for k, v in raw.items():
        if k.startswith("__"):
            continue
        arr = np.asarray(v)
        out[k] = arr.flatten() if arr.ndim > 0 else float(arr)
    return out


def report(d: dict) -> None:
    f_base   = float(d["f_base"])
    f_final  = float(d["freq"][-1])
    print("Stage 4 — analytical vs simulated")
    print(f"  Filter resonance     : {float(d['f_res']):.0f} Hz")
    print(f"  Predicted SS  P      : {float(d['P_ss0']):.2f} W  (target {float(d['P_base']):.0f} W)")
    print(f"  Sim final     V_d    : {float(d['VCd'][-1]):.3f} V  (set {float(d['V_set']):.2f} V)")
    print(f"  Sim final     V_q    : {float(d['VCq'][-1]):+.4f} V  (should be ~0)")
    print(f"  Sim final     P      : {float(d['P_meas'][-1]):.2f} W")
    print(f"  Sim final     Q      : {float(d['Q_meas'][-1]):.2f} VAR")
    print(f"  Sim final     f      : {f_final:.4f} Hz   Df = {f_final - f_base:+.4f} Hz")
    print(f"  Analytical    Df_ss  : {float(d['df_ss_pred']):+.4f} Hz")


def plot_results(d: dict) -> Path:
    t        = d["t"]
    f_base   = float(d["f_base"])
    t_step   = float(d["I_disturb_t"])

    fig, axes = plt.subplots(4, 2, figsize=(13, 11))
    fig.suptitle(
        f"VSG Stage 4 — Average-Model VSG (dq, cascaded V-I + Q-V droop)  "
        f"[Vdc={float(d['V_dc']):g}V, R_p={float(d['R_p'])*100:g}%, "
        f"f_res={float(d['f_res']):.0f}Hz]",
        fontsize=11, fontweight="bold",
    )

    # 1) Frequency
    ax = axes[0, 0]
    ax.plot(t, d["freq"], color="steelblue", linewidth=1.4)
    ax.axhline(f_base, color="red", linestyle="--", linewidth=1)
    ax.axhline(float(d["f_ss_pred"]), color="green", linestyle="--", linewidth=1)
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_ylabel("f (Hz)"); ax.grid(True, alpha=0.4); ax.set_title("Frequency")

    # 2) Terminal voltage V_C
    ax = axes[0, 1]
    ax.plot(t, d["VCd"],    color="blue",   linewidth=1.4, label="V_C_d")
    ax.plot(t, d["Vd_ref"], color="red",    linewidth=1.0, linestyle="--", label="V_d_ref (Q-V droop)")
    ax.plot(t, d["VCq"],    color="purple", linewidth=1.0, label="V_C_q")
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_ylabel("V (V)"); ax.grid(True, alpha=0.4); ax.set_title("Terminal voltage (dq)")
    ax.legend(loc="best", fontsize=8)

    # 3) Active power
    ax = axes[1, 0]
    ax.plot(t, d["P_meas"], color="darkgreen", linewidth=1.4)
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_ylabel("P (W)"); ax.grid(True, alpha=0.4); ax.set_title("Measured active power")

    # 4) Reactive power
    ax = axes[1, 1]
    ax.plot(t, d["Q_meas"], color="purple", linewidth=1.4)
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_ylabel("Q (VAR)"); ax.grid(True, alpha=0.4); ax.set_title("Measured reactive power")

    # 5) Filter inductor currents
    ax = axes[2, 0]
    ax.plot(t, d["iLd"], color="blue",   linewidth=1.2, label="i_L_d")
    ax.plot(t, d["iLq"], color="purple", linewidth=1.2, label="i_L_q")
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_ylabel("i_L (A)"); ax.grid(True, alpha=0.4); ax.set_title("Filter inductor currents")
    ax.legend(loc="best", fontsize=8)

    # 6) Load currents
    ax = axes[2, 1]
    ax.plot(t, d["iloadd"], color="blue",   linewidth=1.2, label="i_load_d")
    ax.plot(t, d["iloadq"], color="purple", linewidth=1.2, label="i_load_q")
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_ylabel("i_load (A)"); ax.grid(True, alpha=0.4); ax.set_title("Load currents")
    ax.legend(loc="best", fontsize=8)

    # 7) Droop characteristic with operating point
    ax = axes[3, 0]
    R_p    = float(d["R_p"])
    P_base = float(d["P_base"])
    P_set  = 1.0
    P_axis = np.linspace(0, 1.5 * P_base, 200)
    f_line = f_base - R_p * (P_axis / P_base - P_set) * f_base
    ax.plot(P_axis, f_line, color="black", linewidth=1.3, label=f"{R_p*100:g}% droop")
    ax.plot(float(d["P_ss0"]), f_base, marker="o", markersize=10, color="green", label="initial OP", linestyle="none")
    ax.plot(float(d["P_meas"][-1]), float(d["freq"][-1]), marker="*",
            markersize=14, color="red", label="final OP (sim)", linestyle="none")
    ax.annotate("", xy=(float(d["P_meas"][-1]), float(d["freq"][-1])),
                xytext=(float(d["P_ss0"]), f_base),
                arrowprops=dict(arrowstyle="->", color="gray", lw=1.5, alpha=0.7))
    ax.set_xlabel("P (W)"); ax.set_ylabel("f (Hz)")
    ax.grid(True, alpha=0.4); ax.set_title("P-f droop characteristic")
    ax.legend(loc="best", fontsize=8)

    # 8) Q-V relationship
    ax = axes[3, 1]
    ax.scatter(d["Q_meas"], d["VCd"], s=2, alpha=0.4, color="steelblue")
    ax.plot(d["Q_meas"][-1], d["VCd"][-1], marker="*", markersize=14, color="red")
    ax.set_xlabel("Q (VAR)"); ax.set_ylabel("V_C_d (V)")
    ax.grid(True, alpha=0.4); ax.set_title("Q-V trajectory (droop in action)")

    plt.tight_layout()
    out = PLOT_DIR / "phase4_dq.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Plot saved : {out}")
    return out


if __name__ == "__main__":
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"{DATA_PATH} not found - run matlab/phase4_inverter_dq.m first."
        )
    data = load(DATA_PATH)
    report(data)
    plot_results(data)
