"""
VSG Project — Stage 3 post-processing.

Reads `matlab/vsg_stage3_out.mat` written by `phase3_droop_control.m`,
extracts droop-response metrics (steady-state Δf, time constant from
exponential fit, power-balance check) and verifies them against the
textbook droop equation. Writes a PNG to `python/plots/phase3_droop.png`.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy.io as sio


HERE      = Path(__file__).resolve().parent
DATA_PATH = HERE.parents[1] / "matlab" / "vsg_stage3_out.mat"
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


def fit_tau(t: np.ndarray, y: np.ndarray, y_inf: float, t_step: float) -> float:
    """First-order exponential fit on the post-step transient.

    Model: y(t) = y_inf + (y0 - y_inf) * exp(-(t - t_step) / tau)
    Returns tau in seconds, or NaN if the fit fails.
    """
    mask = t >= t_step
    tw, yw = t[mask], y[mask]
    if len(tw) < 3:
        return float("nan")
    y0 = float(yw[0])
    # ln((y - y_inf)/(y0 - y_inf)) = -(t - t_step)/tau
    denom = y0 - y_inf
    if abs(denom) < 1e-12:
        return float("nan")
    arg = (yw - y_inf) / denom
    valid = arg > 1e-6
    if valid.sum() < 3:
        return float("nan")
    coef = np.polyfit(tw[valid] - t_step, np.log(arg[valid]), 1)
    slope = coef[0]
    if slope >= 0:
        return float("nan")
    return float(-1.0 / slope)


def measure(d: dict) -> dict:
    f_base = float(d["f_base"])
    t      = d["t"]
    freq   = d["freq"]
    Pm     = d["Pm"]
    t_step = float(d["P_load_t"])

    df_ss_sim = float(freq[-1] - f_base)
    Pm_ss_sim = float(Pm[-1])
    tau_sim   = fit_tau(t, freq, f_base + float(d["df_ss"]), t_step)

    return {
        "df_ss_sim":   df_ss_sim,
        "f_ss_sim":    float(freq[-1]),
        "Pm_ss_sim":   Pm_ss_sim,
        "tau_sim":     tau_sim,
        "df_err_mHz":  (df_ss_sim - float(d["df_ss"])) * 1000.0,
        "Pm_err_pu":   Pm_ss_sim - float(d["Pm_ss_pred"]),
    }


def report(d: dict, m: dict) -> None:
    print("Stage 3 - analytical vs simulated")
    print(f"  R_p = {float(d['R_p'])*100:.2f} %%")
    print(f"  Df_ss : analytical = {float(d['df_ss']):+.4f} Hz   sim = {m['df_ss_sim']:+.4f} Hz   err = {m['df_err_mHz']:+.2f} mHz")
    print(f"  f_ss  : analytical = {float(d['f_ss_pred']):.4f} Hz   sim = {m['f_ss_sim']:.4f} Hz")
    print(f"  Pm_ss : analytical = {float(d['Pm_ss_pred']):.4f} pu  sim = {m['Pm_ss_sim']:.4f} pu  err = {m['Pm_err_pu']:+.4f} pu")
    print(f"  tau   : analytical = {float(d['tau_pred']):.4f} s     sim = {m['tau_sim']:.4f} s")


def plot_results(d: dict, m: dict) -> Path:
    f_base = float(d["f_base"])
    t_step = float(d["P_load_t"])
    R_p    = float(d["R_p"])
    P_set  = float(d["P_set"])
    f_ss   = float(d["f_ss_pred"])
    Pm_ss  = float(d["Pm_ss_pred"])

    fig, axes = plt.subplots(3, 1, figsize=(10, 10))
    fig.suptitle(
        f"VSG Stage 3 - Islanded Droop Response  "
        f"[R_p={R_p*100:g}%%, H={float(d['H']):g}s, "
        f"tau_pred={float(d['tau_pred']):.2f}s]",
        fontsize=12, fontweight="bold",
    )

    # Plot 1: frequency
    ax = axes[0]
    ax.plot(d["t"], d["freq"], color="steelblue", linewidth=1.8, label="f(t)")
    ax.axhline(f_base, color="red",   linestyle="--", linewidth=1, label=f"f_base = {f_base:g} Hz")
    ax.axhline(f_ss,   color="green", linestyle="--", linewidth=1, label=f"f_ss_pred = {f_ss:.3f} Hz")
    ax.axvline(t_step, color="gray",  linestyle=":",  linewidth=1, label="load step")
    ax.set_xlabel("Time (s)"); ax.set_ylabel("Frequency (Hz)"); ax.grid(True, alpha=0.4)
    ax.set_title(f"Frequency response - sim Df_ss = {m['df_ss_sim']:+.4f} Hz  (err = {m['df_err_mHz']:+.2f} mHz)")
    ax.legend(loc="best", fontsize=9)

    # Plot 2: power balance
    ax = axes[1]
    Pm_pred_curve = P_set + (Pm_ss - P_set) * (1 - np.exp(-(d["t"] - t_step) / float(d["tau_pred"]))) * (d["t"] >= t_step)
    P_load_series = float(d["P_load_init"]) + float(d["P_load_step"]) * (d["t"] >= t_step)
    ax.plot(d["t"], d["Pm"],         color="darkgreen", linewidth=1.8, label="P_m(t) sim (droop output)")
    ax.plot(d["t"], Pm_pred_curve,   color="black",     linewidth=1.0, linestyle=":", label="P_m(t) analytical 1st-order")
    ax.plot(d["t"], P_load_series,   color="darkred",   linewidth=1.5, linestyle="--", label="P_load(t)")
    ax.axvline(t_step, color="gray", linestyle=":", linewidth=1)
    ax.set_xlabel("Time (s)"); ax.set_ylabel("Power (pu)"); ax.grid(True, alpha=0.4)
    ax.set_title("Power balance - droop output catches up with load")
    ax.legend(loc="best", fontsize=9)

    # Plot 3: droop characteristic
    ax = axes[2]
    P_axis = np.linspace(0, 2, 100)
    f_line = f_base - R_p * (P_axis - P_set) * f_base
    ax.plot(P_axis, f_line, color="black", linewidth=1.4, label=f"droop curve ({R_p*100:g}%%)")
    ax.plot(P_set, f_base, marker="o", markersize=12, color="green", linestyle="none",
            label=f"initial OP ({P_set:.2f} pu, {f_base:g} Hz)")
    ax.plot(float(d["Pm"][-1]), float(d["freq"][-1]),
            marker="*", markersize=16, color="red", linestyle="none",
            label=f"final OP sim ({float(d['Pm'][-1]):.3f} pu, {float(d['freq'][-1]):.3f} Hz)")
    # Arrow showing trajectory
    ax.annotate("", xy=(float(d["Pm"][-1]), float(d["freq"][-1])),
                xytext=(P_set, f_base),
                arrowprops=dict(arrowstyle="->", color="gray", lw=1.5, alpha=0.7))
    ax.set_xlabel("Active Power P (pu)"); ax.set_ylabel("Frequency f (Hz)"); ax.grid(True, alpha=0.4)
    ax.set_title(f"Droop characteristic - operating-point shift along the curve")
    ax.legend(loc="best", fontsize=9)
    ax.set_xlim(0, 2); ax.set_ylim(47, 53)

    plt.tight_layout()
    out = PLOT_DIR / "phase3_droop.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Plot saved : {out}")
    return out


if __name__ == "__main__":
    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"{DATA_PATH} not found - run matlab/phase3_droop_control.m first."
        )
    data    = load(DATA_PATH)
    metrics = measure(data)
    report(data, metrics)
    plot_results(data, metrics)
