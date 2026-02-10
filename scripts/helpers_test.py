"""Quick, non-destructive checks for `scripts.helpers`.

This script intentionally avoids running ADB/device-affecting commands.
"""
from __future__ import annotations

from pathlib import Path
import sys

# Ensure repo root is on sys.path when executing the script directly
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts import helpers


def main() -> int:
    print("Running helpers quick-check...")
    root = helpers.repo_root()
    print(f"repo_root={root}")

    maestro = helpers.find_maestro_exe()
    print(f"maestro_exe={maestro}")

    demo_flow = root / "flows" / "demo" / "IDCEVODEV-478199__all_stations_select.yaml"
    if demo_flow.exists():
        tokens = helpers.read_action_tokens(demo_flow)
        print(f"found ACTION tokens: {tokens}")
    else:
        print("demo flow not found; skipping token read")

    # Validate we can load the helper-backed modules without calling device actions
    try:
        bmw = helpers._bmw_module()
        vr = helpers._verify_module()
        print(f"loaded modules: bmw={hasattr(bmw, 'action_swag')}, verify={hasattr(vr, 'verify_radio')}")
    except Exception as e:
        print(f"module load failed: {e}")
        return 2

    print("helpers quick-check OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
