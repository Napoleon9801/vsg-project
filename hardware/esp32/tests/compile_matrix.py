"""Compile-only checks in disposable copies. NEVER uploads or addresses a board."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ACKNOWLEDGEMENTS = (
    "VSG_EXTERNAL_SHUTDOWN_VERIFIED",
    "VSG_ADC_RESET_AND_STRAPS_VERIFIED",
    "VSG_BOARD_WIRING_VERIFIED",
    "VSG_DC_BUS_PROTECTION_VERIFIED",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", default=r"C:\Program Files\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe")
    parser.add_argument("--data", default=r"D:\tools\arduino-cli-data")
    parser.add_argument("--temp-root", default=r"D:\tools\tmp")
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent / "vsg_controller"
    env = dict(os.environ, ARDUINO_DIRECTORIES_DATA=str(Path(args.data).resolve()))
    temp_root = Path(args.temp_root).resolve()
    temp_root.mkdir(parents=True, exist_ok=True)
    cases = [("dry-default", {}, True),
             ("real-locked", {"DRY_RUN_NO_POWER_STAGE": 0}, False)]
    qualified = {"DRY_RUN_NO_POWER_STAGE": 0, **{key: 1 for key in ACKNOWLEDGEMENTS}}
    for omitted in ACKNOWLEDGEMENTS:
        cases.append(("missing-" + omitted, {key: value for key, value in qualified.items()
                                            if key != omitted}, False))
    cases.append(("real-A-compile-only", qualified, True))
    cases.append(("dry-B", {"POWER_STAGE": 2}, True))
    cases.append(("real-B-compile-only", {**qualified, "POWER_STAGE": 2}, True))
    cases.append(("invalid-power-stage", {"POWER_STAGE": 999}, False))
    with tempfile.TemporaryDirectory(prefix="vsg-compile-", dir=temp_root) as directory:
        root = Path(directory)
        for name, defines, should_compile in cases:
            sketch = root / name / "vsg_controller"
            shutil.copytree(source, sketch)
            ino = sketch / "vsg_controller.ino"
            ino.write_text("\n".join(f"#define {key} {value}" for key, value in defines.items())
                           + "\n" + ino.read_text(encoding="utf-8"), encoding="utf-8")
            result = subprocess.run([
                args.cli, "compile", "--fqbn", "esp32:esp32:esp32", "--warnings", "all",
                "--build-path", str(root / "build"), str(sketch)],
                env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                encoding="utf-8", errors="replace")
            output = result.stdout
            if should_compile:
                if result.returncode:
                    raise RuntimeError(f"{name} unexpectedly failed:\n{output}")
                if "warning:" in output.lower():
                    raise RuntimeError(f"{name} has compiler warnings:\n{output}")
                print(f"PASS {name}: compile succeeded, no compiler warnings", flush=True)
                for line in output.splitlines():
                    if line.startswith(("Sketch uses", "Global variables")):
                        print("  " + line, flush=True)
            else:
                expected = "Unsupported POWER_STAGE:" if name == "invalid-power-stage" else "REAL POWER LOCKED:"
                if result.returncode == 0 or expected not in output:
                    raise RuntimeError(f"{name} did not fail at the readiness guard:\n{output}")
                print(f"PASS {name}: expected {expected} refusal", flush=True)
    print("Original sketch and default DRY_RUN=1 were not modified; nothing uploaded.")


if __name__ == "__main__":
    main()
