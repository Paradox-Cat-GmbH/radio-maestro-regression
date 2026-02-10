"""Unit-style checks for helpers utilities.

These are lightweight, non-destructive checks intended to run locally without device access.
"""
from __future__ import annotations

from pathlib import Path
import sys
import time

# Make repo importable when run directly
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts import helpers


def test_read_action_tokens():
    root = helpers.repo_root()
    demo_flow = root / "flows" / "demo" / "IDCEVODEV-478199__all_stations_select.yaml"
    if demo_flow.exists():
        tokens = helpers.read_action_tokens(demo_flow)
        print("read_action_tokens:", tokens)
    else:
        print("demo flow not present; skipping read_action_tokens test")


def long_fn():
    time.sleep(2)


def quick():
    return 123


def test_run_in_process_timeout():
    # timeout shorter than sleep should return TimeoutError
    exc = helpers._run_in_process(long_fn, args=(), timeout_s=0.5)
    print("_run_in_process timeout test exc:", type(exc))


def test_run_with_retries_success():
    exc = helpers.run_with_retries(quick, args=(), retries=1, timeout_s=1)
    print("run_with_retries success exc:", exc)


def main():
    print("helpers unit tests")
    test_read_action_tokens()
    test_run_in_process_timeout()
    test_run_with_retries_success()
    print("done")


if __name__ == "__main__":
    main()
