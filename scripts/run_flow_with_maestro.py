"""Wrapper to run the flow runner with a session-local MAESTRO_CMD set.

This avoids shell quoting issues when setting environment variables from the outer shell.
Set the `MAESTRO_CMD_PATH` variable below to your Maestro installation folder or executable.
"""
from __future__ import annotations

import os
import sys

# Ensure repo root is importable when running the wrapper directly
sys.path.insert(0, str(os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))))

# Adjust this path if different on your machine.
MAESTRO_CMD_PATH = r"C:\Users\DavidErikGarciaArena\Desktop\maestro\bin\maestro.bat"

def main() -> int:
    os.environ["MAESTRO_CMD"] = MAESTRO_CMD_PATH
    # quick diagnostic: show what the helpers resolves
    try:
        from scripts import helpers
        print('MAESTRO_CMD set to:', os.environ.get('MAESTRO_CMD'))
        print('helpers.find_maestro_exe(MAESTRO_CMD) ->', helpers.find_maestro_exe(os.environ.get('MAESTRO_CMD')))
    except Exception as e:
        print('helpers import/diagnostic failed:', e)
    from scripts import run_flow_with_actions
    return run_flow_with_actions.main()


if __name__ == "__main__":
    raise SystemExit(main())
