from __future__ import annotations

import importlib.util
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import List, Optional
from multiprocessing import Process, Queue
from dataclasses import dataclass

RE_ACTION = re.compile(r"^\s*#\s*ACTION:\s*(.+?)\s*$", re.IGNORECASE)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def find_maestro_exe(hint: Optional[str] = None) -> Optional[str]:
    names = {"maestro.exe", "maestro.cmd", "maestro.bat", "maestro", "maestro studio.exe", "maestro studio"}

    def search_dir(d: Path) -> Optional[str]:
        try:
            # Collect candidate files and prefer Windows launchers when on nt
            candidates = []
            for p in d.rglob("*"):
                if not p.is_file():
                    continue
                name = p.name.lower()
                if name in names or name.startswith("maestro"):
                    candidates.append(p)
            if not candidates:
                return None
            if os.name == "nt":
                # prefer .bat/.cmd/.exe
                for ext in (".bat", ".cmd", ".exe"):
                    for p in candidates:
                        if p.suffix.lower() == ext:
                            return str(p.resolve())
            # fallback to first candidate
            return str(candidates[0].resolve())
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


def read_action_tokens(flow_path: Path) -> Optional[List[str]]:
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


def run_and_log(cmd: List[str], cwd: Path, log_path: Path, timeout: int = 120) -> int:
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


def _load_module_from_path(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load module {name} from {path}")
    mod = importlib.util.module_from_spec(spec)
    # Ensure module is registered in sys.modules before execution so decorators
    # (e.g. dataclasses) that access the module entry can find it.
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def _bmw_module():
    path = repo_root() / "scripts" / "bmw_controls.py"
    return _load_module_from_path("bmw_controls", path)


def _verify_module():
    path = repo_root() / "scripts" / "verify_radio_state.py"
    return _load_module_from_path("verify_radio_state", path)


def run_bmw_action(tokens: List[str]) -> None:
    """Execute a parsed ACTION token list using the in-repo `bmw_controls.py` module.

    Example tokens: ["swag", "media-next"]
    """
    if not tokens:
        return
    mod = _bmw_module()
    cmd = tokens[0].lower()
    if cmd == "swag":
        if len(tokens) < 2:
            raise ValueError("swag requires an action token")
        mod.action_swag(tokens[1])
    elif cmd == "workaround":
        if len(tokens) < 2:
            raise ValueError("workaround requires direction 'next' or 'previous'")
        mod.action_workaround_media_next_prev(tokens[1])
    elif cmd == "bim":
        if len(tokens) < 2:
            raise ValueError("bim requires direction 'next' or 'previous'")
        mod.action_bim_skip(tokens[1])
    elif cmd == "ehh":
        if len(tokens) < 3:
            raise ValueError("ehh requires target and enabled flag")
        target, enabled = tokens[1], tokens[2]
        prop = (
            "persist.vendor.com.bmwgroup.disable_cid_ehh"
            if target == "cid"
            else "persist.vendor.com.bmwgroup.disable_phud_ehh"
        )
        mod.setprop(prop, enabled)
    elif cmd == "ediabas-str":
        script = repo_root() / "scripts" / "ediabas_str_cycle.py"
        cmdline = [sys.executable, str(script)] + tokens[1:]
        result = subprocess.run(cmdline, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(
                "EDIABAS STR action failed. "
                f"stdout={result.stdout.strip()} stderr={result.stderr.strip()}"
            )
    elif cmd == "ediabas-str-js":
        script = repo_root() / "scripts" / "ediabas_str_cycle.js"
        cmdline = ["node", str(script)] + tokens[1:]
        result = subprocess.run(cmdline, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(
                "EDIABAS STR JS action failed. "
                f"stdout={result.stdout.strip()} stderr={result.stderr.strip()}"
            )
    elif cmd == "ediabas-str-js-api":
        script = repo_root() / "scripts" / "ediabas_str_cycle_api.js"
        cmdline = ["node", str(script)] + tokens[1:]
        result = subprocess.run(cmdline, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(
                "EDIABAS STR JS API action failed. "
                f"stdout={result.stdout.strip()} stderr={result.stderr.strip()}"
            )
    elif cmd == "ediabas-str-js-sidecar":
        script = repo_root() / "scripts" / "ediabas_str_cycle_sidecar.js"
        cmdline = ["node", str(script)] + tokens[1:]
        result = subprocess.run(cmdline, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(
                "EDIABAS STR JS sidecar action failed. "
                f"stdout={result.stdout.strip()} stderr={result.stderr.strip()}"
            )
    else:
        raise ValueError(f"Unknown ACTION command: {cmd}")


@dataclass
class ActionLog:
    path: Path

    def write(self, msg: str) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8") as f:
            f.write(msg + "\n")


def _run_in_process(func, args=(), timeout_s: int = 30) -> Optional[Exception]:
    """Run `func(*args)` in a separate process and return an Exception if one occurred, or None on success.

    Note: Running in a process avoids hanging the main interpreter and allows terminating on timeout.
    """
    q: Queue = Queue()
    # Use a top-level target to avoid pickling nested functions on Windows
    p = Process(target=_process_target, args=(func, args, q))
    p.start()
    p.join(timeout_s)
    if p.is_alive():
        try:
            p.terminate()
        except Exception:
            pass
        p.join(1)
        return TimeoutError(f"Function timed out after {timeout_s}s")

    if not q.empty():
        result = q.get()
        return result
    return None


def run_with_retries(func, args=(), retries: int = 1, retry_delay_s: float = 0.5, timeout_s: int = 30):
    last_exc = None
    for attempt in range(retries + 1):
        exc = _run_in_process(func, args=args, timeout_s=timeout_s)
        if exc is None:
            return None
        last_exc = exc
        if attempt < retries:
            time.sleep(retry_delay_s)
    return last_exc


def run_bmw_action_safe(tokens: List[str], log_path: Optional[Path] = None, timeout_s: int = 30, retries: int = 1) -> int:
    """Run a BMW action with timeout, retries and logging. Returns exit code 0 on success, 2 on failure/timeout.

    This wraps `run_bmw_action` in a separate process so device/hardware blocking calls won't hang the runner.
    """
    log = ActionLog(Path(log_path) if log_path else (repo_root() / "artifacts" / "helpers" / f"action_{int(time.time())}.log"))
    log.write("$ ACTION: " + " ".join(tokens))

    def _call(tokens_inner):
        run_bmw_action(tokens_inner)

    exc = run_with_retries(_call, args=(tokens,), retries=retries, retry_delay_s=0.5, timeout_s=timeout_s)
    if exc is None:
        log.write("[exit_code]=0")
        return 0
    else:
        log.write(f"[exit_code]=2\nERROR: {exc}")
        return 2


def _process_target(func, args, q: Queue):
    try:
        func(*args)
        q.put(None)
    except Exception as e:
        q.put(e)


def verify_radio(package: str, require_focus: bool = True, require_playing: bool = True) -> bool:
    mod = _verify_module()
    return mod.verify_radio(package, require_focus=require_focus, require_playing=require_playing)


__all__ = [
    "repo_root",
    "find_maestro_exe",
    "read_action_tokens",
    "run_and_log",
    "run_bmw_action",
    "verify_radio",
]
