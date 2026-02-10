import argparse
import subprocess
import os
from pathlib import Path
import sys
from dataclasses import dataclass

# Based on Leandro's mapping (SWAG / BMW input injection)
BMW_KEY_CODE_MAPPING = {
    "up": 1024,          # MFL_ROTARY_UP_DIRECT
    "down": 1028,        # MFL_ROTARY_DOWN_DIRECT
    "left": 1016,        # MFL_SKIP_LEFT_DIRECT
    "right": 1020,       # MFL_SKIP_RIGHT_DIRECT
    "center": 1034,      # MFL_PUSH
    "media-next": 1040,  # BZM_SKIP_RIGHT
    "media-previous": 1038,  # BZM_SKIP_LEFT
    "menu": 1066,        # SWAG_MENU
    "media": 1014,       # MFL_MEDIA
    "phone": 1054,       # MFL_PHONE
    "ptt": 1012,         # MFL_PUSH_TO_TALK
}


@dataclass
class CmdResult:
    cmd: list[str]
    returncode: int
    stdout: str
    stderr: str


def _adb_prefix() -> list[str]:
    """Prefer repo-local scripts/adb.bat on Windows."""
    if os.name == "nt":
        repo = Path(__file__).resolve().parent.parent
        adb_bat = repo / "scripts" / "adb.bat"
        if adb_bat.exists():
            return ["cmd", "/c", str(adb_bat)]
    return ["adb"]


def _run(cmd: list[str], timeout_s: int = 20) -> CmdResult:
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_s)
    return CmdResult(cmd=cmd, returncode=p.returncode, stdout=p.stdout, stderr=p.stderr)


def adb(*args: str, timeout_s: int = 20) -> CmdResult:
    return _run(_adb_prefix() + list(args), timeout_s=timeout_s)
def inject_custom_input(keycode: int) -> None:
    """
    Leandro's SWAG simulation pattern:
      adb shell cmd car_service inject-custom-input -r 0 <KEYCODE>
      adb shell cmd car_service inject-custom-input -r 0 <KEYCODE+1>

    Interpreting this as press + release.
    """
    for code in (keycode, keycode + 1):
        r = adb("shell", "cmd", "car_service", "inject-custom-input", "-r", "0", str(code))
        if r.returncode != 0:
            raise RuntimeError(f"ADB inject failed: {' '.join(r.cmd)}\n{r.stderr.strip()}")


def keyevent(key: str) -> None:
    r = adb("shell", "input", "keyevent", key)
    if r.returncode != 0:
        raise RuntimeError(f"ADB keyevent failed: {' '.join(r.cmd)}\n{r.stderr.strip()}")


def setprop(prop: str, value: str) -> None:
    r = adb("shell", "setprop", prop, value)
    if r.returncode != 0:
        raise RuntimeError(f"ADB setprop failed: {' '.join(r.cmd)}\n{r.stderr.strip()}")


def action_swag(name: str) -> None:
    if name not in BMW_KEY_CODE_MAPPING:
        raise ValueError(f"Unknown SWAG action '{name}'. Valid: {', '.join(sorted(BMW_KEY_CODE_MAPPING))}")
    inject_custom_input(BMW_KEY_CODE_MAPPING[name])


def action_workaround_media_next_prev(direction: str) -> None:
    """
    Leandro workaround for Previous/Next:
      - Send 1014 (MFL_MEDIA)
      - Then KEYCODE_MEDIA_NEXT / KEYCODE_MEDIA_PREVIOUS

    This is useful if inject-custom-input doesn't trigger the skip on the current build.
    """
    inject_custom_input(BMW_KEY_CODE_MAPPING["media"])
    if direction == "next":
        keyevent("KEYCODE_MEDIA_NEXT")
    elif direction == "previous":
        keyevent("KEYCODE_MEDIA_PREVIOUS")
    else:
        raise ValueError("direction must be 'next' or 'previous'")


def action_bim_skip(direction: str) -> None:
    """
    BIM: Leandro note mentions KEYCODE_MUTE.

    We implement a conservative sequence:
      1) KEYCODE_MUTE (some builds require it to route the input to BIM context)
      2) Try inject-custom-input (BZM skip)
      3) Fallback to workaround keyevents

    If your build needs a different order, adjust here.
    """
    # Step 1: ensure BIM context responds
    try:
        keyevent("KEYCODE_MUTE")
    except Exception:
        # don't fail hard; continue
        pass

    try:
        if direction == "next":
            inject_custom_input(BMW_KEY_CODE_MAPPING["media-next"])
        elif direction == "previous":
            inject_custom_input(BMW_KEY_CODE_MAPPING["media-previous"])
        else:
            raise ValueError("direction must be 'next' or 'previous'")
        return
    except Exception:
        # fallback
        action_workaround_media_next_prev(direction)


def main() -> int:
    ap = argparse.ArgumentParser(description="BMW iDrive rack helpers: SWAG/BIM input injection + EHH toggles")

    sub = ap.add_subparsers(dest="cmd", required=True)

    p_swag = sub.add_parser("swag", help="Inject SWAG custom input")
    p_swag.add_argument("action", choices=sorted(BMW_KEY_CODE_MAPPING.keys()))

    p_wk = sub.add_parser("workaround", help="Workaround for media next/previous")
    p_wk.add_argument("direction", choices=["next", "previous"])

    p_bim = sub.add_parser("bim", help="BIM skip via KEYCODE_MUTE + inject + fallback")
    p_bim.add_argument("direction", choices=["next", "previous"])

    p_ehh = sub.add_parser("ehh", help="Toggle EHH suppression properties")
    p_ehh.add_argument("target", choices=["cid", "phud"])
    p_ehh.add_argument("enabled", choices=["true", "false"], help="Set to true to disable that EHH")

    args = ap.parse_args()

    try:
        if args.cmd == "swag":
            action_swag(args.action)
        elif args.cmd == "workaround":
            action_workaround_media_next_prev(args.direction)
        elif args.cmd == "bim":
            action_bim_skip(args.direction)
        elif args.cmd == "ehh":
            prop = (
                "persist.vendor.com.bmwgroup.disable_cid_ehh"
                if args.target == "cid"
                else "persist.vendor.com.bmwgroup.disable_phud_ehh"
            )
            setprop(prop, args.enabled)
        else:
            raise RuntimeError("Unhandled command")

        print("OK")
        return 0

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
