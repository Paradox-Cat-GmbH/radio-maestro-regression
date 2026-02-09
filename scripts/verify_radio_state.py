#!/usr/bin/env python3
"""
verify_radio_state.py

Goal: Backend verification that "Radio is truly playing", not just that the UI shows Radio.
Checks:
  1) dumpsys audio -> audio focus "pack:" contains expected package
  2) dumpsys media_session -> expected package has an active session in PLAYING state
     (state parsing is best-effort; it varies across Android builds)

Exit codes:
  0 = PASS
  1 = FAIL
  2 = TOOLING ERROR (adb unreachable, parsing failed, etc.)
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import List, Optional


# =============================
# Leandro-required function name
# =============================
def func(dumpsys_output: str, user_id: int = -1) -> List[str]:
    """
    Extracts a list of individual session entries for a specific full_user from adb dumpsys media_session output.

    Parameters:
        dumpsys_output (str): The complete dumpsys output.
        user_id (int): The full_user ID to extract. If -1, the first available full_user block is used.

    Returns:
        list[str]: A list of session entry strings (each entry is one session).
    """
    user_pattern = r"Record for full_user=(\d+)"
    user_matches = list(re.finditer(user_pattern, dumpsys_output))
    if not user_matches:
        return []

    # Choose user_id if provided, otherwise first one
    available = [int(m.group(1)) for m in user_matches]
    if user_id == -1:
        user_id = available[0]
    if user_id not in available:
        return []

    # Slice the user block
    user_indices = {int(m.group(1)): m.start() for m in user_matches}
    start_index = user_indices[user_id]
    following = [uid for uid in sorted(user_indices.keys()) if uid > user_id]
    end_index = user_indices[following[0]] if following else len(dumpsys_output)
    user_block = dumpsys_output[start_index:end_index]

    # Locate Sessions Stack in the user block
    session_start = re.search(r"Sessions Stack\s*-\s*have\s*\d+\s*sessions:", user_block)
    if not session_start:
        return []

    session_block = user_block[session_start.start():].strip()

    # Split sessions using indentation-based heuristic:
    # New sessions typically start with 4 spaces then non-space content.
    chunks = re.split(r"\n\s{4}(?=\S)", session_block)
    if not chunks:
        return []

    # First item is the header, skip it
    return [c.strip() for c in chunks[1:] if c.strip()]


@dataclass
class MediaSession:
    user_id: int
    package: Optional[str]
    active: Optional[bool]
    state: Optional[str]
    description: List[str]


def _run_adb(cmd: List[str], retries: int = 2, retry_delay_s: float = 0.7, timeout_s: int = 20) -> str:
    """
    Run an adb command with small retries (racks can be flaky).
    """
    last_err = None
    for attempt in range(retries + 1):
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_s)
            if p.returncode == 0:
                return p.stdout or ""
            last_err = p.stderr or p.stdout
        except Exception as e:
            last_err = str(e)

        if attempt < retries:
            time.sleep(retry_delay_s)

    raise RuntimeError(f"ADB command failed: {' '.join(cmd)} | last_error={last_err}")


def get_current_user_id() -> int:
    out = _run_adb(["adb", "shell", "am", "get-current-user"]).strip()
    m = re.search(r"(\d+)", out)
    return int(m.group(1)) if m else 0


def parse_audio_focus_packages(dumpsys_audio: str) -> List[str]:
    # We care about lines like: "pack: com.example"
    # Be tolerant to extra whitespace.
    return re.findall(r"pack:\s*([^\s]+)", dumpsys_audio)


def parse_media_sessions(user_id: int, session_entries: List[str]) -> List[MediaSession]:
    def first(lst):
        return lst[0] if lst else None

    out: List[MediaSession] = []
    for entry in session_entries:
        package = first(re.findall(r"package=([\w\.]+)", entry, flags=re.M))
        active_raw = first(re.findall(r"active=(true|false)", entry, flags=re.I | re.M))
        active = (active_raw.lower() == "true") if active_raw else None

        # Various builds show state as:
        # - "... state=PLAYING(..."
        # - "{state=3(..."
        # We'll capture the token after "state=" up to "(" if present.
        state = first(re.findall(r"(?:\{state=|state=)(.+?)(?=\()", entry, flags=re.M))
        state = state.strip() if state else None

        desc = re.findall(r"description=(.+)", entry, flags=re.M)
        out.append(MediaSession(user_id=user_id, package=package, active=active, state=state, description=desc))
    return out


def is_playing_state(state: Optional[str]) -> bool:
    if not state:
        return False
    s = state.strip().upper()
    # Common textual states
    if "PLAY" in s:
        return True
    # Some platforms show numeric playback state (e.g., 3=PLAYING in Android PlaybackStateCompat)
    # We keep this mapping loose.
    if s in {"3", "STATE_PLAYING", "PLAYING"}:
        return True
    return False


def verify_radio(package: str, require_focus: bool, require_playing: bool) -> bool:
    audio = _run_adb(["adb", "shell", "dumpsys", "audio"])
    focus_packs = set(parse_audio_focus_packages(audio))

    has_focus = package in focus_packs
    if require_focus and not has_focus:
        print(f"[FAIL] Audio focus not held by expected package: {package}")
        print(f"       Found focus packages: {sorted(list(focus_packs))[:15]}{'...' if len(focus_packs)>15 else ''}")
        return False

    user_id = get_current_user_id()
    ms_dump = _run_adb(["adb", "shell", "dumpsys", "media_session"])
    entries = func(ms_dump, user_id=user_id)
    sessions = parse_media_sessions(user_id, entries)

    candidates = [s for s in sessions if s.package == package]
    if not candidates:
        print(f"[FAIL] No media session found for package: {package} (user_id={user_id})")
        return False

    # Find any active+playing session
    ok = False
    for s in candidates:
        active_ok = (s.active is True) if require_playing else (s.active is not False)
        playing_ok = is_playing_state(s.state) if require_playing else True
        if active_ok and playing_ok:
            ok = True
            break

    if not ok:
        print(f"[FAIL] Media session for {package} exists, but not active+playing.")
        for s in candidates[:3]:
            print(f"       session: active={s.active} state={s.state}")
        return False

    print(f"[PASS] Radio backend verified: focus={has_focus} | session active+playing for {package}")
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", required=True, help="Expected package holding audio focus and media session (radio service).")
    ap.add_argument("--require-focus", action="store_true", help="Fail if expected package is not in audio focus 'pack:' list.")
    ap.add_argument("--require-playing", action="store_true", help="Fail if media session isn't active+PLAYING.")
    args = ap.parse_args()

    try:
        ok = verify_radio(args.package, require_focus=args.require_focus, require_playing=args.require_playing)
        return 0 if ok else 1
    except Exception as e:
        print(f"[ERROR] {e}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
