"""Small demo showing safe usage of `scripts.helpers`.

This script performs only non-destructive checks (no ADB actions).
"""
from __future__ import annotations

from pathlib import Path
import sys

# Ensure repo root is on sys.path when executing the script directly
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from scripts import helpers


def main() -> int:
    root = helpers.repo_root()
    print(f"repo_root={root}")

    maestro = helpers.find_maestro_exe()
    print(f"maestro_exe={maestro}")

    # Show how to read ACTION tokens from a demo flow if present
    demo_flow = root / "flows" / "demo" / "IDCEVODEV-478199__all_stations_select.yaml"
    if demo_flow.exists():
        tokens = helpers.read_action_tokens(demo_flow)
        print(f"found ACTION tokens in demo flow: {tokens}")
    else:
        print("demo flow not present; skipping token read")

    # Show that we can load the bmw module without executing actions
    try:
        mod = helpers._bmw_module()
        print(f"loaded bmw_controls module: {hasattr(mod, 'action_swag')} available")
    except Exception as e:
        print(f"could not load bmw_controls module: {e}")

    # Do not call any ADB/device-affecting functions here.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
