from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path


DEFAULT_EDIABAS_BIN = Path(r"C:\EC-Apps\EDIABAS\BIN")
DEFAULT_ACTION_PAD = "SET_PAD"
DEFAULT_ACTION_WOHNEN = "SET_WOHNEN"
DEFAULT_ACTION_PARKING = "SET_PARKING"
DEFAULT_TOOL32_PRG = "IPB_APP1.prg"
DEFAULT_TOOL32_JOB = "STEUERN_ROUTINE"
DEFAULT_TOOL32_ARG_PAD = "ARG;ZUSTAND_FAHRZEUG;STR;0x07"
DEFAULT_TOOL32_ARG_WOHNEN = "ARG;ZUSTAND_FAHRZEUG;STR;0x05"
DEFAULT_TOOL32_ARG_PARKING = "ARG;ZUSTAND_FAHRZEUG;STR;0x01"


@dataclass
class StepResult:
    state: str
    action_name: str
    returncode: int
    log_file: str
    started_at: float
    ended_at: float
    stdout: str
    stderr: str


def _resolve_tool64cli(ediabas_bin: Path, explicit_tool: str | None) -> Path:
    if explicit_tool:
        tool = Path(explicit_tool)
        if tool.exists():
            return tool
        raise FileNotFoundError(f"Tool executable not found: {tool}")

    candidate = ediabas_bin / "Tool64Cli.exe"
    if candidate.exists():
        return candidate

    raise FileNotFoundError(
        f"Tool64Cli.exe not found in {ediabas_bin}. "
        "Install/point to Tool64 CLI or pass --tool64cli explicitly."
    )


def _resolve_tool32(ediabas_bin: Path, explicit_tool: str | None) -> Path:
    if explicit_tool:
        tool = Path(explicit_tool)
        if tool.exists():
            return tool
        raise FileNotFoundError(f"Tool executable not found: {tool}")

    candidate = ediabas_bin / "tool32.exe"
    if candidate.exists():
        return candidate

    raise FileNotFoundError(
        f"tool32.exe not found in {ediabas_bin}. "
        "Install/point to Tool32 or pass --tool32 explicitly."
    )


def _run_subprocess(cmd: list[str], cwd: Path, timeout_s: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        capture_output=True,
        text=True,
        timeout=timeout_s,
    )


def _append_jsonl(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(payload, ensure_ascii=False) + "\n")


def smoke_test_cli(tool64cli: Path, ediabas_bin: Path, timeout_s: int) -> None:
    result = _run_subprocess([str(tool64cli), "--help"], cwd=ediabas_bin, timeout_s=timeout_s)
    if result.returncode != 0:
        raise RuntimeError(
            f"Tool64Cli --help failed (rc={result.returncode}). stderr={result.stderr.strip()}"
        )


def smoke_test_tool32(tool32: Path) -> None:
    if not tool32.exists():
        raise RuntimeError(f"tool32 not found: {tool32}")


def diagnose_environment(
    mode: str,
    ediabas_bin: Path,
    tool64cli_path: str | None,
    tool32_path: str | None,
    probe_action: str | None,
    timeout_seconds: int,
    output_dir: Path,
) -> int:
    output_dir.mkdir(parents=True, exist_ok=True)
    report_path = output_dir / "diagnose_report.txt"
    lines: list[str] = []

    lines.append("EDIABAS DIAGNOSE REPORT")
    lines.append(f"timestamp={time.strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"ediabas_bin={ediabas_bin}")
    lines.append(f"mode={mode}")

    tool64cli: Path | None = None
    tool32: Path | None = None

    try:
        if mode in {"tool64cli", "auto"}:
            tool64cli = _resolve_tool64cli(ediabas_bin, tool64cli_path)
            lines.append(f"tool64cli=FOUND:{tool64cli}")
    except Exception as e:
        lines.append(f"tool64cli=ERROR:{e}")

    try:
        if mode in {"tool32", "auto"}:
            tool32 = _resolve_tool32(ediabas_bin, tool32_path)
            lines.append(f"tool32=FOUND:{tool32}")
    except Exception as e:
        lines.append(f"tool32=ERROR:{e}")

    if tool64cli is not None:
        help_cmd = [str(tool64cli), "--help"]
        help_result = _run_subprocess(help_cmd, cwd=ediabas_bin, timeout_s=timeout_seconds)
        lines.append(f"tool64cli_help_rc={help_result.returncode}")
        if help_result.stdout:
            lines.append("tool64cli_help_stdout_begin")
            lines.extend((help_result.stdout or "").splitlines()[:40])
            lines.append("tool64cli_help_stdout_end")
        if help_result.stderr:
            lines.append("tool64cli_help_stderr_begin")
            lines.extend((help_result.stderr or "").splitlines()[:40])
            lines.append("tool64cli_help_stderr_end")

        if probe_action:
            probe_log = output_dir / "diagnose_probe_action.log"
            probe = run_tool64_action(
                tool64cli=tool64cli,
                ediabas_bin=ediabas_bin,
                action_name=probe_action,
                output_file=probe_log,
                timeout_s=timeout_seconds,
            )
            lines.append(f"tool64cli_probe_action={probe_action}")
            lines.append(f"tool64cli_probe_rc={probe.returncode}")
            lines.append(f"tool64cli_probe_log={probe.log_file}")
            if probe.stdout:
                lines.append("tool64cli_probe_stdout_begin")
                lines.extend(probe.stdout.splitlines()[:40])
                lines.append("tool64cli_probe_stdout_end")
            if probe.stderr:
                lines.append("tool64cli_probe_stderr_begin")
                lines.extend(probe.stderr.splitlines()[:40])
                lines.append("tool64cli_probe_stderr_end")

    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"OK: Diagnose report generated: {report_path}")
    return 0


def run_tool64_action(
    tool64cli: Path,
    ediabas_bin: Path,
    action_name: str,
    output_file: Path,
    timeout_s: int,
) -> StepResult:
    output_file = output_file.resolve()
    output_file.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(tool64cli),
        "--actionName",
        action_name,
        "--outputFile",
        str(output_file),
        "--overwrite",
    ]

    started = time.time()
    result = _run_subprocess(cmd, cwd=ediabas_bin, timeout_s=timeout_s)
    ended = time.time()

    return StepResult(
        state="",
        action_name=action_name,
        returncode=result.returncode,
        log_file=str(output_file),
        started_at=started,
        ended_at=ended,
        stdout=(result.stdout or "").strip(),
        stderr=(result.stderr or "").strip(),
    )


def run_tool32_action(
    tool32: Path,
    ediabas_bin: Path,
    prg_name: str,
    job_name: str,
    argument: str,
    output_file: Path,
    timeout_s: int,
) -> StepResult:
    output_file.parent.mkdir(parents=True, exist_ok=True)
    cmd = [str(tool32), prg_name, job_name, argument]

    started = time.time()
    result = _run_subprocess(cmd, cwd=ediabas_bin, timeout_s=timeout_s)
    ended = time.time()

    with output_file.open("w", encoding="utf-8") as f:
        f.write("$ " + " ".join(cmd) + "\n\n")
        if result.stdout:
            f.write("[stdout]\n" + result.stdout + "\n")
        if result.stderr:
            f.write("[stderr]\n" + result.stderr + "\n")
        f.write(f"\n[exit_code]={result.returncode}\n")

    return StepResult(
        state="",
        action_name=f"{job_name}:{argument}",
        returncode=result.returncode,
        log_file=str(output_file),
        started_at=started,
        ended_at=ended,
        stdout=(result.stdout or "").strip(),
        stderr=(result.stderr or "").strip(),
    )


def run_action_with_retries(
    mode: str,
    ediabas_bin: Path,
    tool64cli: Path | None,
    tool32: Path | None,
    state: str,
    action_name: str,
    tool32_prg: str,
    tool32_job: str,
    tool32_argument: str,
    output_dir: Path,
    timeout_s: int,
    retries: int,
    audit_jsonl: Path,
) -> StepResult:
    last_result: StepResult | None = None
    for attempt in range(retries + 1):
        log_file = output_dir / f"{int(time.time())}_{state}_attempt{attempt + 1}.log"
        if mode == "tool64cli":
            assert tool64cli is not None
            step = run_tool64_action(
                tool64cli=tool64cli,
                ediabas_bin=ediabas_bin,
                action_name=action_name,
                output_file=log_file,
                timeout_s=timeout_s,
            )
            engine_used = "tool64cli"
        elif mode == "tool32":
            assert tool32 is not None
            step = run_tool32_action(
                tool32=tool32,
                ediabas_bin=ediabas_bin,
                prg_name=tool32_prg,
                job_name=tool32_job,
                argument=tool32_argument,
                output_file=log_file,
                timeout_s=timeout_s,
            )
            engine_used = "tool32"
        elif mode == "auto":
            if tool64cli is not None:
                step = run_tool64_action(
                    tool64cli=tool64cli,
                    ediabas_bin=ediabas_bin,
                    action_name=action_name,
                    output_file=log_file,
                    timeout_s=timeout_s,
                )
                engine_used = "tool64cli"
                if step.returncode != 0 and tool32 is not None:
                    fallback_log_file = output_dir / f"{int(time.time())}_{state}_attempt{attempt + 1}_fallback_tool32.log"
                    step = run_tool32_action(
                        tool32=tool32,
                        ediabas_bin=ediabas_bin,
                        prg_name=tool32_prg,
                        job_name=tool32_job,
                        argument=tool32_argument,
                        output_file=fallback_log_file,
                        timeout_s=timeout_s,
                    )
                    engine_used = "tool32"
            elif tool32 is not None:
                step = run_tool32_action(
                    tool32=tool32,
                    ediabas_bin=ediabas_bin,
                    prg_name=tool32_prg,
                    job_name=tool32_job,
                    argument=tool32_argument,
                    output_file=log_file,
                    timeout_s=timeout_s,
                )
                engine_used = "tool32"
            else:
                raise RuntimeError("Auto mode could not find Tool64Cli or tool32.")
        else:
            raise RuntimeError(f"Unsupported mode: {mode}")

        step.state = state
        payload = asdict(step)
        payload["attempt"] = attempt + 1
        payload["engine"] = engine_used
        _append_jsonl(audit_jsonl, payload)

        last_result = step
        if step.returncode == 0:
            return step

        if attempt < retries:
            time.sleep(1.0)

    assert last_result is not None
    return last_result


def run_str_cycle(
    mode: str,
    ediabas_bin: Path,
    tool64cli_path: str | None,
    tool32_path: str | None,
    action_pad: str,
    action_wohnen: str,
    action_parking: str,
    tool32_prg: str,
    tool32_job: str,
    tool32_arg_pad: str,
    tool32_arg_wohnen: str,
    tool32_arg_parking: str,
    settle_seconds: int,
    str_seconds: int,
    timeout_seconds: int,
    retries: int,
    output_dir: Path,
    skip_smoke_test: bool,
) -> int:
    tool64cli: Path | None = None
    tool32: Path | None = None

    if mode in {"tool64cli", "auto"}:
        try:
            tool64cli = _resolve_tool64cli(ediabas_bin, tool64cli_path)
        except Exception:
            if mode == "tool64cli":
                raise
    if mode in {"tool32", "auto"}:
        try:
            tool32 = _resolve_tool32(ediabas_bin, tool32_path)
        except Exception:
            if mode == "tool32":
                raise

    output_dir.mkdir(parents=True, exist_ok=True)
    audit_jsonl = output_dir / "ediabas_str_audit.jsonl"

    if not skip_smoke_test:
        if mode == "tool64cli":
            assert tool64cli is not None
            smoke_test_cli(tool64cli=tool64cli, ediabas_bin=ediabas_bin, timeout_s=timeout_seconds)
        elif mode == "tool32":
            assert tool32 is not None
            smoke_test_tool32(tool32=tool32)
        elif mode == "auto":
            if tool64cli is not None:
                smoke_test_cli(tool64cli=tool64cli, ediabas_bin=ediabas_bin, timeout_s=timeout_seconds)
            elif tool32 is not None:
                smoke_test_tool32(tool32=tool32)
            else:
                raise RuntimeError("Auto mode could not find Tool64Cli or tool32.")

    sequence = [
        ("PAD", action_pad, tool32_arg_pad, settle_seconds),
        ("WOHNEN", action_wohnen, tool32_arg_wohnen, settle_seconds),
        ("PARKING", action_parking, tool32_arg_parking, settle_seconds),
        ("SLEEP", "", "", str_seconds),
        ("WOHNEN", action_wohnen, tool32_arg_wohnen, settle_seconds),
        ("PAD", action_pad, tool32_arg_pad, settle_seconds),
    ]

    for state, action_name, tool32_argument, wait_s in sequence:
        if state == "SLEEP":
            _append_jsonl(
                audit_jsonl,
                {
                    "state": state,
                    "sleep_seconds": wait_s,
                    "timestamp": time.time(),
                },
            )
            time.sleep(wait_s)
            continue

        step = run_action_with_retries(
            mode=mode,
            ediabas_bin=ediabas_bin,
            tool64cli=tool64cli,
            tool32=tool32,
            state=state,
            action_name=action_name,
            tool32_prg=tool32_prg,
            tool32_job=tool32_job,
            tool32_argument=tool32_argument,
            output_dir=output_dir,
            timeout_s=timeout_seconds,
            retries=retries,
            audit_jsonl=audit_jsonl,
        )

        if step.returncode != 0:
            print(
                f"ERROR: Failed at state={state} action={action_name} rc={step.returncode}. "
                f"Log: {step.log_file}",
                file=sys.stderr,
            )
            return 2

        time.sleep(wait_s)

    print(f"OK: STR cycle completed. Artifacts: {output_dir}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run BMW STR cycle via EDIABAS Tool64Cli user actions")
    parser.add_argument("--ediabas-bin", default=str(DEFAULT_EDIABAS_BIN), help="EDIABAS BIN directory")
    parser.add_argument("--mode", choices=["auto", "tool64cli", "tool32"], default="auto", help="Execution engine")
    parser.add_argument("--tool64cli", default=None, help="Explicit path to Tool64Cli executable")
    parser.add_argument("--tool32", default=None, help="Explicit path to tool32 executable")
    parser.add_argument("--action-pad", default=DEFAULT_ACTION_PAD, help="Tool64 action name for PAD")
    parser.add_argument("--action-wohnen", default=DEFAULT_ACTION_WOHNEN, help="Tool64 action name for WOHNEN")
    parser.add_argument("--action-parking", default=DEFAULT_ACTION_PARKING, help="Tool64 action name for PARKING")
    parser.add_argument("--tool32-prg", default=DEFAULT_TOOL32_PRG, help="Tool32 PRG file")
    parser.add_argument("--tool32-job", default=DEFAULT_TOOL32_JOB, help="Tool32 job name")
    parser.add_argument("--tool32-arg-pad", default=DEFAULT_TOOL32_ARG_PAD, help="Tool32 argument for PAD")
    parser.add_argument("--tool32-arg-wohnen", default=DEFAULT_TOOL32_ARG_WOHNEN, help="Tool32 argument for WOHNEN")
    parser.add_argument("--tool32-arg-parking", default=DEFAULT_TOOL32_ARG_PARKING, help="Tool32 argument for PARKING")
    parser.add_argument("--settle-seconds", type=int, default=2, help="Pause after each state transition")
    parser.add_argument("--str-seconds", type=int, default=180, help="STR sleep duration")
    parser.add_argument("--timeout-seconds", type=int, default=60, help="Timeout for each Tool64 CLI call")
    parser.add_argument("--retries", type=int, default=1, help="Retry count per state transition")
    parser.add_argument(
        "--output-dir",
        default=str(Path("artifacts") / "ediabas" / f"str_cycle_{time.strftime('%Y%m%d_%H%M%S')}"),
        help="Directory for logs and JSONL audit",
    )
    parser.add_argument("--skip-smoke-test", action="store_true", help="Skip Tool64Cli --help smoke test")
    parser.add_argument("--diagnose", action="store_true", help="Generate compatibility report and exit")
    parser.add_argument("--probe-action", default=None, help="Optional Tool64 actionName to execute during --diagnose")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    ediabas_bin = Path(args.ediabas_bin)
    output_dir = Path(args.output_dir).resolve()

    if not ediabas_bin.exists() or not ediabas_bin.is_dir():
        print(f"ERROR: Invalid EDIABAS BIN directory: {ediabas_bin}", file=sys.stderr)
        return 2

    if args.settle_seconds < 0 or args.str_seconds < 0 or args.timeout_seconds <= 0 or args.retries < 0:
        print("ERROR: Invalid timing/retry values.", file=sys.stderr)
        return 2

    if args.diagnose:
        return diagnose_environment(
            mode=args.mode,
            ediabas_bin=ediabas_bin,
            tool64cli_path=args.tool64cli,
            tool32_path=args.tool32,
            probe_action=args.probe_action,
            timeout_seconds=args.timeout_seconds,
            output_dir=output_dir,
        )

    return run_str_cycle(
        mode=args.mode,
        ediabas_bin=ediabas_bin,
        tool64cli_path=args.tool64cli,
        tool32_path=args.tool32,
        action_pad=args.action_pad,
        action_wohnen=args.action_wohnen,
        action_parking=args.action_parking,
        tool32_prg=args.tool32_prg,
        tool32_job=args.tool32_job,
        tool32_arg_pad=args.tool32_arg_pad,
        tool32_arg_wohnen=args.tool32_arg_wohnen,
        tool32_arg_parking=args.tool32_arg_parking,
        settle_seconds=args.settle_seconds,
        str_seconds=args.str_seconds,
        timeout_seconds=args.timeout_seconds,
        retries=args.retries,
        output_dir=output_dir,
        skip_smoke_test=args.skip_smoke_test,
    )


if __name__ == "__main__":
    raise SystemExit(main())