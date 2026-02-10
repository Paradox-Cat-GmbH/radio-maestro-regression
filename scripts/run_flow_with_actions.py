#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Runs a Maestro YAML flow, optionally executes a host-side BMW input action (SWAG/BIM/etc),
# then validates backend state via ADB (audio focus + media session).
#
# Action markers live in YAML as comments:
#   # ACTION: swag media-next
#   # ACTION: workaround next
#   # ACTION: bim next
#   # ACTION: ehh cid true

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

RE_ACTION = re.compile(r"^\s*#\s*ACTION:\s*(.+?)\s*$", re.IGNORECASE)
EXPECTED_PACKAGE = "com.bmwgroup.apinext.tunermediaservice"


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def timestamp_dir() -> str:
    return time.strftime("%Y-%m-%d_%H%M%S")


def find_maestro_exe(hint: str | None) -> str | None:
    # Resolve Maestro CLI executable from file/dir/name or PATH.
    # Accepts: maestro.exe / maestro.cmd / maestro.bat / maestro
    names = {"maestro.exe", "maestro.cmd", "maestro.bat", "maestro"}

    def search_dir(d: Path) -> str | None:
        try:
            for p in d.rglob("*"):
                if p.is_file() and p.name.lower() in names:
                    return str(p.resolve())
        except Exception:
            return None
        return None

    if hint:
        p = Path(hint)
        if p.exists():
            if p.is_file():
                return str(p.resolve())
            if p.is_dir():
                hit = search_dir(p)
                if hit:
                    return hit
        w = shutil.which(hint)
        if w:
            return w

    w = shutil.which("maestro")
    if w:
        return w
    return None


def read_action_tokens(flow_path: Path) -> list[str] | None:
    for line in flow_path.read_text(encoding="utf-8").splitlines():
        m = RE_ACTION.match(line)
        if m:
            tokens = m.group(1).strip().split()
            if not tokens:
                return None
            if tokens[0].lower() in {"manual", "none"}:
                return None
            return tokens
    return None


def run_and_log(cmd: list[str], cwd: Path, log_path: Path) -> int:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8") as f:
        f.write("$ " + " ".join(cmd) + "\n\n")
        p = subprocess.Popen(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        assert p.stdout is not None
        for line in p.stdout:
            f.write(line)
        rc = p.wait()
        f.write(f"\n[exit_code]={rc}\n")
    return rc


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("flow", help="Path to Maestro YAML flow (relative to repo root or absolute).")
    ap.add_argument("--artifacts", default=None, help="Artifacts base dir (default: artifacts/runs/<timestamp>)")
    ap.add_argument("--no-validate", action="store_true", help="Skip backend validation step.")
    ap.add_argument("--no-action", action="store_true", help="Ignore any '# ACTION:' marker.")
    args = ap.parse_args()

    root = repo_root()

    flow_path = Path(args.flow)
    if not flow_path.is_absolute():
        flow_path = (root / flow_path).resolve()

    if not flow_path.exists():
        print(f"Flow not found: {flow_path}", file=sys.stderr)
        return 2

    artifacts_base = Path(args.artifacts).resolve() if args.artifacts else (root / "artifacts" / "runs" / timestamp_dir())
    test_dir = artifacts_base / "demo" / flow_path.stem
    test_dir.mkdir(parents=True, exist_ok=True)

    maestro_hint = os.environ.get("MAESTRO_CMD") or "maestro"
    maestro_exe = find_maestro_exe(maestro_hint)
    if not maestro_exe:
        print(
            "Maestro CLI not found. Set MAESTRO_CMD to the CLI executable or its folder.\n"
            "Example:\n  setx MAESTRO_CMD \"%USERPROFILE%\\Desktop\\maestro\\bin\"",
            file=sys.stderr,
        )
        return 3

    maestro_output = test_dir / "maestro_output"
    maestro_log = test_dir / "maestro.log"
    rc = run_and_log([maestro_exe, "test", str(flow_path), "--test-output-dir", str(maestro_output)], cwd=root, log_path=maestro_log)
    if rc != 0:
        return rc

    if not args.no_action:
        tokens = read_action_tokens(flow_path)
        if tokens:
            action_log = test_dir / "action.log"
            rc = run_and_log([sys.executable, str(root / "scripts" / "bmw_controls.py"), *tokens], cwd=root, log_path=action_log)
            if rc != 0:
                return rc
            time.sleep(0.8)

    if not args.no_validate:
        verify_log = test_dir / "verify.log"
        if os.name == "nt":
            verify_cmd = ["cmd", "/c", str(root / "scripts" / "run_check.bat")]
        else:
            verify_cmd = [sys.executable, str(root / "scripts" / "verify_radio_state.py"),
                          "--package", EXPECTED_PACKAGE, "--require-focus", "--require-playing"]
        rc = run_and_log(verify_cmd, cwd=root, log_path=verify_log)
        if rc != 0:
            return rc

    (test_dir / "SUMMARY.txt").write_text(
        f"FLOW={flow_path.name}\nMAESTRO={maestro_exe}\nARTIFACTS={test_dir}\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
