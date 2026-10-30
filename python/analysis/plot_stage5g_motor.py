"""Compare exploratory damping candidates; never change firmware from this plot."""
from pathlib import Path
import hashlib
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

from plot_stage5f_motor import ROOT, FIGURES, read_case
from motor_equivalent_circuit import Motor, steady_state_motor


def main():
    data_path = ROOT / "matlab/validation_outputs/stage5g"
    source = data_path / "validation_stage5g.json"
    report = json.loads(source.read_text(encoding="utf-8"))
    for entry in report["source_identity"]:
        assert hashlib.sha256(Path(entry["path"]).read_bytes()).hexdigest() == entry["sha256"]
    traces = {"Current parameters": read_case("motor_cold_start")}
    for name in report["cases"]:
        traces[name] = read_case(name, data_path)
    fig, axes = plt.subplots(2, 2, figsize=(12.8, 8.6), layout="constrained")
    checks = {}
    for (label, (r, t, d)), color in zip(traces.items(), ["#94a3b8", "#16a34a", "#2563eb", "#9333ea"]):
        voltage = np.hypot(d["vd"], d["vq"])
        for ax, trace in zip(axes.flat, [voltage, d["rpm"], voltage, np.hypot(d["id"], d["iq"])]):
            ax.plot(t, trace, lw=1.1, label=label, color=color)
        if label == "Current parameters" or not report["cases"][label]["metrics"]["settled_operation_screen"]:
            continue
        tail = t >= t[-1] - .2
        m = r.parameters.motor
        prediction = steady_state_motor(float(np.mean(voltage[tail])), float(np.mean(d["freq"][tail])),
                                        float(np.mean(d["omega_m"][tail])),
                                        Motor(m.Rs, m.Rr, m.Lls, m.Llr, m.Lm, int(m.pole_pairs), m.B))
        observed = {"stator_current_rms_A": float(np.mean(d["stator_current_mag"][tail]) / np.sqrt(2)),
                    "electromagnetic_torque_Nm": float(np.mean(d["torque_e"][tail])),
                    "input_active_W": float(np.mean(d["P_motor"][tail]))}
        errors = {key: abs(value - prediction[key]) / max(abs(prediction[key]), 1e-9) for key, value in observed.items()}
        checks[label] = {"predicted": prediction, "observed": observed,
                         "relative_errors": errors, "pass": all(v < .03 for v in errors.values())}
    titles = ["Phase voltage magnitude", "Motor speed", "Voltage: final 0.5 s", "Inverter current magnitude"]
    units = ["V peak", "rpm", "V peak", "A peak envelope"]
    for ax, title, unit in zip(axes.flat, titles, units):
        ax.set(title=title, xlabel="Time (s)", ylabel=unit)
        ax.grid(alpha=.2)
    axes[1, 0].set_xlim(5.5, 6)
    axes[0, 0].legend(fontsize=8)
    fig.suptitle("Simulation-only voltage PI damping study\nKp x4/x8/x12; Ki x0.25. Current firmware is unchanged.", fontsize=14)
    for ext in ["png", "svg"]:
        fig.savefig(FIGURES / f"stage5g_motor_damping_2026-10-24.{ext}", dpi=170)
    plt.close(fig)
    audit = {"scope": "Independent equivalent-circuit check of settled exploratory motor cases",
             "checked_count": len(checks), "cases": checks,
             "pass": all(v["pass"] for v in checks.values()) if checks else None,
             "report_sha256": hashlib.sha256(source.read_bytes()).hexdigest()}
    (data_path / "independent_phasor_check.json").write_text(json.dumps(audit, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"checked_count": len(checks), "phasor_pass": audit["pass"]}))
    assert audit["pass"] is not False


if __name__ == "__main__":
    main()
