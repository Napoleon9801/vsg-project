"""Compile and execute actual shared C++ safety policies; no board or Arduino needed."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile


def main():
    source = Path(__file__).with_name("safety_policy_test.cpp").resolve()
    with tempfile.TemporaryDirectory(prefix="vsg-policy-tests-") as directory:
        build = Path(directory)
        executable = build / ("safety_policy_test.exe" if os.name == "nt" else "safety_policy_test")
        compiler = shutil.which("g++") or shutil.which("clang++")
        if compiler:
            subprocess.run([compiler, "-std=c++11", "-Wall", "-Wextra", "-Werror",
                            str(source), "-o", str(executable)], check=True)
        elif os.name == "nt":
            vswhere = Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Microsoft Visual Studio/Installer/vswhere.exe"
            installation = subprocess.check_output([
                str(vswhere), "-latest", "-products", "*", "-requires",
                "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
                "-property", "installationPath"], text=True).strip()
            if not installation:
                raise RuntimeError("No host C++ compiler installed")
            devcmd = Path(installation) / "Common7/Tools/VsDevCmd.bat"
            script = build / "compile.cmd"
            script.write_text(
                f'@echo off\ncall "{devcmd}" -arch=x64 -host_arch=x64 >nul\n'
                f'if errorlevel 1 exit /b 1\n'
                f'cl /nologo /EHsc /std:c++14 /W4 /WX "{source}" '
                f'/Fe:"{executable}" /Fo:"{build / "policy.obj"}"\n', encoding="utf-8")
            subprocess.run(["cmd.exe", "/d", "/c", str(script)], cwd=build, check=True)
        else:
            raise RuntimeError("Install a host C++ compiler to run these tests")
        subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
