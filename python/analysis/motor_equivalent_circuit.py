"""Independent steady-state induction-machine check, SI per-phase Y equivalent.

This phasor calculation is separate from the time-domain MATLAB flux equations.
It assumes balanced sinusoidal voltage, constant speed, and linear inductances.
It neither supplies a real motor rating nor validates switching/thermal behavior.
"""
from __future__ import annotations

from dataclasses import dataclass
from math import isfinite, pi, sqrt


@dataclass(frozen=True)
class Motor:
    stator_resistance: float
    rotor_resistance: float
    stator_leakage: float
    rotor_leakage: float
    magnetizing_inductance: float
    pole_pairs: int
    viscous_friction: float = 0.0


def steady_state_motor(
    phase_peak_voltage: float,
    frequency_hz: float,
    speed_rad_s: float,
    motor: Motor,
) -> dict[str, float]:
    """Return signed motoring/generating power and torque, including s=0.

    Rotor quantities are referred to the stator. There is no core-loss branch.
    Negative slip represents imposed supersynchronous operation, not a drive
    control recommendation. Torque uses mechanical synchronous angular speed.
    """
    values = (
        phase_peak_voltage, frequency_hz, speed_rad_s,
        motor.stator_resistance, motor.rotor_resistance,
        motor.stator_leakage, motor.rotor_leakage,
        motor.magnetizing_inductance, motor.viscous_friction,
    )
    if not all(isfinite(v) for v in values):
        raise ValueError("All machine inputs must be finite")
    if phase_peak_voltage < 0 or frequency_hz <= 0:
        raise ValueError("Require nonnegative voltage and positive frequency")
    if min(motor.stator_resistance, motor.rotor_resistance,
           motor.stator_leakage, motor.rotor_leakage,
           motor.magnetizing_inductance) <= 0:
        raise ValueError("Require positive resistances and inductances")
    if motor.pole_pairs < 1 or int(motor.pole_pairs) != motor.pole_pairs:
        raise ValueError("pole_pairs must be a positive integer")
    if motor.viscous_friction < 0:
        raise ValueError("Viscous friction cannot be negative")

    omega = 2 * pi * frequency_hz
    synchronous_speed = omega / motor.pole_pairs
    slip = 1 - speed_rad_s / synchronous_speed
    voltage_rms = phase_peak_voltage / sqrt(2)
    stator_impedance = motor.stator_resistance + 1j * omega * motor.stator_leakage
    magnetizing_admittance = 1 / (1j * omega * motor.magnetizing_inductance)
    rotor_admittance = slip / (
        motor.rotor_resistance + 1j * omega * motor.rotor_leakage * slip
    )
    parallel_impedance = 1 / (magnetizing_admittance + rotor_admittance)
    stator_current = voltage_rms / (stator_impedance + parallel_impedance)
    airgap_voltage = stator_current * parallel_impedance
    rotor_current = airgap_voltage * rotor_admittance
    complex_power = 3 * voltage_rms * stator_current.conjugate()
    airgap_power = 3 * abs(airgap_voltage) ** 2 * rotor_admittance.real
    stator_copper_loss = 3 * abs(stator_current) ** 2 * motor.stator_resistance
    rotor_copper_loss = 3 * abs(rotor_current) ** 2 * motor.rotor_resistance
    converted_power = airgap_power * (1 - slip)
    friction_loss = motor.viscous_friction * speed_rad_s ** 2
    return {
        "slip": slip,
        "synchronous_rpm": synchronous_speed * 60 / (2 * pi),
        "speed_rpm": speed_rad_s * 60 / (2 * pi),
        "stator_current_rms_A": abs(stator_current),
        "stator_current_peak_A": sqrt(2) * abs(stator_current),
        "rotor_current_rms_A": abs(rotor_current),
        "input_active_W": complex_power.real,
        "input_reactive_var": complex_power.imag,
        "electromagnetic_torque_Nm": airgap_power / synchronous_speed,
        "converted_mechanical_W": converted_power,
        "available_shaft_W": converted_power - friction_loss,
        "stator_copper_loss_W": stator_copper_loss,
        "rotor_copper_loss_W": rotor_copper_loss,
        "friction_loss_W": friction_loss,
        "power_identity_residual_W": complex_power.real - stator_copper_loss
        - rotor_copper_loss - converted_power,
    }


def check_saved_ideal_source():
    """Reproduce the independent ODE45 equilibrium check from saved evidence."""
    from pathlib import Path
    import hashlib
    import json

    root = Path(__file__).resolve().parents[2]
    folder = root / "matlab/validation_outputs/motor_ideal_source"
    source = folder / "ideal_source.json"
    data = json.loads(source.read_text(encoding="utf-8"))
    for item in data["source_identity"]:
        assert hashlib.sha256(Path(item["path"]).read_bytes()).hexdigest() == item["sha256"]
    p = data["parameters"]
    motor = Motor(p["Rs"], p["Rr"], p["Lls"], p["Llr"], p["Lm"], p["pole_pairs"], p["B"])
    predicted = steady_state_motor(data["voltage_peak"], data["frequency_hz"], data["speed_rad_s"], motor)
    observed = {"stator_current_rms_A": data["stator_current_rms"],
                "electromagnetic_torque_Nm": data["torque"],
                "input_active_W": data["input_power"], "available_shaft_W": data["shaft_power"]}
    errors = {key: abs(value - predicted[key]) / max(abs(predicted[key]), 1e-9)
              for key, value in observed.items()}
    edge_points = [steady_state_motor(14, 50, speed, motor)
                   for speed in [0, 100, 135, 145, 150, 2 * pi * 50 / motor.pole_pairs, 165]]
    edge_checks = {"power_identity": max(abs(v["power_identity_residual_W"]) for v in edge_points) < 1e-10,
                   "locked_shaft_zero_work": edge_points[0]["converted_mechanical_W"] == 0,
                   "synchronous_zero_torque": abs(edge_points[-2]["electromagnetic_torque_Nm"]) < 1e-12,
                   "generator_torque_sign": edge_points[-1]["electromagnetic_torque_Nm"] < 0}
    audit = {"pass": data["pass"] and all(v < 1e-6 for v in errors.values()) and all(edge_checks.values()),
             "scope": "Independent equivalent circuit vs ODE45 motor-only equilibrium; not inverter stability",
             "relative_errors": errors, "observed": observed, "predicted": predicted,
             "edge_checks": edge_checks,
             "input_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
             "python_source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (folder / "independent_phasor_check.json").write_text(json.dumps(audit, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"pass": audit["pass"], "relative_errors": errors}))
    assert audit["pass"], "Motor-only independent cross-check failed"


if __name__ == "__main__":
    check_saved_ideal_source()
