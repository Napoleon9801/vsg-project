"""Plot saved Stage5f evidence and independently check steady motor phasors."""
from pathlib import Path
import csv
import hashlib
import json

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import loadmat

from motor_equivalent_circuit import Motor, steady_state_motor

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "matlab/validation_outputs/stage5f"
FIGURES = ROOT / "docs/figures"


def read_case(name, data_path=DATA):
    r = loadmat(data_path / f"{name}.mat", squeeze_me=True, struct_as_record=False)["result"]
    t, y = np.asarray(r.time), np.asarray(r.data)
    assert t.ndim == 1 and len(t) == y.shape[0]
    assert np.isfinite(t).all() and np.isfinite(y).all() and (np.diff(t) > 0).all()
    return r, t, {str(c): y[:, i] for i, c in enumerate(r.columns)}


def main():
    report_path = DATA / "validation_stage5f.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    for src in report["source_identity"]:
        assert hashlib.sha256(Path(src["path"]).read_bytes()).hexdigest() == src["sha256"], src["path"]
    cases = {name: read_case(name) for name in report["cases"]}
    FIGURES.mkdir(exist_ok=True, parents=True)
    labels = {
        "motor_cold_start": "Motor connected from startup",
        "motor_direct_connection": "Connect motor at 3 s",
        "motor_torque_step": "Fan torque coefficient x1.8 at 3 s",
        "motor_locked_rotor": "Rotor locked at zero speed",
        "motor_source_limit": "Connect at 3 s; source limited to 0.8 A",
        "motor_nonideal": "Assumed bridge resistance + deadtime",
    }
    panels = [
        ("Phase voltage magnitude", "V peak", lambda d: np.hypot(d["vd"], d["vq"])),
        ("Finite DC bus", "V", lambda d: d["Vdc"]),
        ("Inverter current vector magnitude", "A peak envelope", lambda d: np.hypot(d["id"], d["iq"])),
        ("Mechanical rotor speed", "rpm", lambda d: d["rpm"]),
        ("Electromagnetic torque", "N m", lambda d: d["torque_e"]),
        ("Mechanical load power", "W", lambda d: d["P_shaft_load"]),
    ]
    fig, axes = plt.subplots(3, 2, figsize=(12.8, 10), layout="constrained")
    for name, color in zip(list(labels)[:3], ["#2563eb", "#d97706", "#7c3aed"]):
        _, t, d = cases[name]
        m = report["cases"][name]
        legend = labels[name] + (f"; stops at {t[-1]:.3f} s" if m["truncated"] else "")
        for ax, (_, _, select) in zip(axes.flat, panels):
            ax.plot(t, select(d), color=color, lw=1.35, label=legend)
            if m["truncated"]:
                ax.plot(t[-1], select(d)[-1], "x", color=color, ms=7)
    for ax, (title, unit, _) in zip(axes.flat, panels):
        ax.set(title=title, xlabel="Time (s)", ylabel=unit)
        ax.grid(alpha=.2)
    axes[0, 0].legend(fontsize=8)
    fig.suptitle("VSG supplying a hypothetical low-voltage induction motor\nAveraged simulation; not a measured motor or hardware qualification", fontsize=14)
    for ext in ["png", "svg"]:
        fig.savefig(FIGURES / f"stage5f_motor_operation_2026-10-24.{ext}", dpi=170)
    plt.close(fig)

    fig, axes = plt.subplots(2, 2, figsize=(12.8, 8), layout="constrained")
    stress_panels = [panels[1], panels[2], panels[3],
                    ("Integrated energy balance residual", "J", lambda d: d["energy_residual"])]
    for name, color in zip(list(labels)[3:], ["#dc2626", "#d97706", "#0891b2"]):
        _, t, d = cases[name]
        m = report["cases"][name]
        legend = labels[name] + (f"; {m['firmware_fault']} at {t[-1]:.3f} s" if m["termination"] == "firmware_fault"
                                 else f"; model boundary at {t[-1]:.3f} s" if m["truncated"] else "; completed")
        for ax, (_, _, select) in zip(axes.flat, stress_panels):
            ax.plot(t, select(d), color=color, lw=1.3, label=legend)
            if m["truncated"]:
                ax.plot(t[-1], select(d)[-1], "x", color=color, ms=7)
    for ax, (title, unit, _) in zip(axes.flat, stress_panels):
        ax.set(title=title, xlabel="Time (s)", ylabel=unit)
        ax.grid(alpha=.2)
    axes[0, 0].legend(fontsize=7.5)
    fig.suptitle("Limits and nonideal assumptions\nCurves stop at fault/model boundary; no post-trip switch or diode model", fontsize=14)
    for ext in ["png", "svg"]:
        fig.savefig(FIGURES / f"stage5f_motor_limits_2026-10-24.{ext}", dpi=170)
    plt.close(fig)

    independent = {}
    for name, (r, t, d) in cases.items():
        m = report["cases"][name]
        if name == "rl_reference" or not m["settled_operation_screen"]:
            independent[name] = {"status": "not_applicable", "reason": "Not a completed settled motor operating point"}
            continue
        tail = t >= t[-1] - .2
        mm = r.parameters.motor
        motor = Motor(mm.Rs, mm.Rr, mm.Lls, mm.Llr, mm.Lm, int(mm.pole_pairs), mm.B)
        pred = steady_state_motor(float(np.mean(np.hypot(d["vd"][tail], d["vq"][tail]))),
                                  float(np.mean(d["freq"][tail])), float(np.mean(d["omega_m"][tail])), motor)
        observed = {
            "stator_current_rms_A": float(np.mean(d["stator_current_mag"][tail]) / np.sqrt(2)),
            "electromagnetic_torque_Nm": float(np.mean(d["torque_e"][tail])),
            "input_active_W": float(np.mean(d["P_motor"][tail])),
        }
        errors = {key: abs(value - pred[key]) / max(abs(pred[key]), 1e-9) for key, value in observed.items()}
        independent[name] = {"status": "checked", "predicted": pred, "observed": observed,
                             "relative_errors": errors, "limit_relative": .03,
                             "pass": all(v < .03 for v in errors.values())}
    rows = []
    keys = ["termination", "firmware_fault", "actual_duration", "minimum_bus", "maximum_bus",
            "peak_inverter_current", "final_rpm", "final_slip", "final_motor_input_W",
            "final_shaft_load_power", "final_bus", "max_energy_residual_J", "settled_operation_screen"]
    for name, metrics in report["cases"].items():
        rows.append({"scenario": name, **{key: metrics[key] for key in keys}})
    with (DATA / "summary.csv").open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=["scenario"] + keys)
        writer.writeheader()
        writer.writerows(rows)
    source_files = [report_path, Path(__file__), Path(__file__).with_name("motor_equivalent_circuit.py")]
    source_files += [DATA / f"{name}.mat" for name in cases]
    audit = {"scope": "Independent steady-state per-phase phasor comparison, no measured-motor validation",
             "cases": independent,
             "checked_count": sum(v["status"] == "checked" for v in independent.values()),
             "pass": (all(v.get("pass", True) for v in independent.values())
                      if any(v["status"] == "checked" for v in independent.values()) else None),
             "source_hashes": [{"path": str(p), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in source_files]}
    (DATA / "independent_phasor_check.json").write_text(json.dumps(audit, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"plots": 4, "phasor_checked": audit["checked_count"], "phasor_pass": audit["pass"]}))
    assert audit["pass"] is not False, "Inspect independent phasor cross-check"


if __name__ == "__main__":
    main()
