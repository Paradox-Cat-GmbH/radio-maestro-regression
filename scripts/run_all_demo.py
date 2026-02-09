import argparse
import sys
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser(description="Run all demo flows with optional hardware injection + backend validation.")
    ap.add_argument("--artifacts", default=None, help="Artifacts directory (defaults to artifacts/runs/<timestamp>)")
    ap.add_argument("--no-validate", action="store_true", help="Skip backend validation")
    args = ap.parse_args()

    root = Path(__file__).resolve().parent.parent
    demo_dir = root / "flows" / "demo"
    flows = sorted([p for p in demo_dir.glob("IDCEVODEV-*.yaml")])
    if not flows:
        print(f"No flows found in {demo_dir}", file=sys.stderr)
        return 2

    # Delegate to run_flow_with_actions for each flow.
    runner = root / "scripts" / "run_flow_with_actions.py"
    artifacts = args.artifacts

    rc_final = 0
    for flow in flows:
        cmd = [sys.executable, str(runner), str(flow.relative_to(root))]
        if artifacts:
            cmd += ["--artifacts", artifacts]
        if args.no_validate:
            cmd += ["--no-validate"]
        print(f"\n=== RUN: {flow.name} ===")
        rc = __import__("subprocess").call(cmd, cwd=str(root))
        if rc != 0:
            rc_final = rc
            print(f"FAILED: {flow.name} (exit={rc})")
            # Continue running remaining tests to get full picture.
        else:
            print(f"OK: {flow.name}")

    return rc_final


if __name__ == "__main__":
    raise SystemExit(main())
