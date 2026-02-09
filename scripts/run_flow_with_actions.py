import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

RE_ACTION = re.compile(r"^\s*#\s*ACTION:\s*(.+?)\s*$", re.IGNORECASE)

EXPECTED_PACKAGE = "com.bmwgroup.apinext.tunermediaservice"
EXPECTED_STATE = "Playing"

def repo_root() -> Path:
    # scripts/ -> repo root
    return Path(__file__).resolve().parent.parent

def run_cmd(cmd: list[str], cwd: Path | None = None, log_file: Path | None = None) -> int:
    text = f"$ {' '.join(cmd)}\n"
    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        log_file.write_text(text, encoding="utf-8")
    p = subprocess.Popen(cmd, cwd=str(cwd) if cwd else None, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out_lines = []
    while True:
        line = p.stdout.readline()
        if not line and p.poll() is not None:
            break
        if line:
            out_lines.append(line)
    rc = p.wait()
    if log_file:
        with log_file.open("a", encoding="utf-8") as f:
            f.writelines(out_lines)
            f.write(f"\n[exit_code]={rc}\n")
    else:
        sys.stdout.write(''.join(out_lines))
        sys.stdout.flush()
    return rc

def parse_action(flow_path: Path) -> list[str] | None:
    for line in flow_path.read_text(encoding="utf-8").splitlines():
        m = RE_ACTION.match(line)
        if m:
            action = m.group(1).strip()
            if action.lower() in {"none", "manual"}:
                return None
            return action.split()
    return None

def default_artifacts_dir() -> Path:
    ts = time.strftime("%Y-%m-%d_%H%M%S")
    return repo_root() / "artifacts" / "runs" / ts

def main() -> int:
    ap = argparse.ArgumentParser(description="Run a Maestro flow, optionally inject BMW input, then validate Radio via ADB.")
    ap.add_argument("flow", help="Path to the Maestro YAML flow")
    ap.add_argument("--artifacts", default=str(default_artifacts_dir()), help="Where to store logs/artifacts")
    ap.add_argument("--no-validate", action="store_true", help="Skip backend validation (audio focus + media session)")
    args = ap.parse_args()

    root = repo_root()
    flow_path = (root / args.flow).resolve() if not os.path.isabs(args.flow) else Path(args.flow).resolve()
    if not flow_path.exists():
        print(f"Flow not found: {flow_path}", file=sys.stderr)
        return 2

    artifacts_dir = Path(args.artifacts).resolve()
    artifacts_dir.mkdir(parents=True, exist_ok=True)

    test_name = flow_path.stem
    flow_log = artifacts_dir / f"{test_name}__maestro.log"
    action_log = artifacts_dir / f"{test_name}__action.log"
    validate_log = artifacts_dir / f"{test_name}__validate.log"

    # 1) Run Maestro flow
    # Use --test-output-dir to co-locate Maestro artifacts with this run.
    maestro_out_dir = artifacts_dir / "maestro_output"
    # Allow overriding the Maestro CLI executable via environment variable `MAESTRO_CMD`.
    # Example: set MAESTRO_CMD=C:\path\to\maestro.exe
    maestro_exe = os.environ.get("MAESTRO_CMD", "maestro")
    # Validate that the Maestro executable is resolvable. If MAESTRO_CMD points to
    # a GUI application (e.g. "Maestro Studio.exe") it will likely fail; provide
    # a helpful message instead of a cryptic FileNotFoundError.
    import shutil
    maestro_resolved = shutil.which(maestro_exe) if maestro_exe else None
    if maestro_resolved is None and not Path(maestro_exe).exists():
        print(f"Maestro executable not found: '{maestro_exe}'.\n\nPlease install the Maestro CLI or set the MAESTRO_CMD environment variable to the full path of the Maestro CLI executable. Example (PowerShell):\nsetx MAESTRO_CMD \"C:\\\\path\\\\to\\\\maestro.exe\"")
        return 3
    maestro_cmd = [maestro_exe, "test", str(flow_path), f"--test-output-dir={maestro_out_dir}", "--format=junit"]
    rc = run_cmd(maestro_cmd, cwd=root, log_file=flow_log)
    if rc != 0:
        return rc

    # 2) Optional BMW input injection based on '# ACTION:' comment
    action = parse_action(flow_path)
    if action:
        # Example: ['swag', 'media-next']
        mode = action[0].lower()
        key = action[1].lower() if len(action) > 1 else ""
        if mode in {"swag", "bim", "workaround"}:
            cmd = [sys.executable, str(root / "scripts" / "bmw_controls.py"), "inject", "--mode", mode, "--key", key]
        else:
            # unknown action; log it and continue
            cmd = ["cmd", "/c", "echo", f"Unknown ACTION: {' '.join(action)}"]
        rc = run_cmd(cmd, cwd=root, log_file=action_log)
        if rc != 0:
            return rc

    # 3) Backend validation
    if not args.no_validate:
        validate_cmd = [sys.executable, str(root / "scripts" / "verify_radio_state.py"), "--package", EXPECTED_PACKAGE, "--state", EXPECTED_STATE]
        rc = run_cmd(validate_cmd, cwd=root, log_file=validate_log)
        if rc != 0:
            return rc

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
