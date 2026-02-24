# Control Server Dashboard Quick Guide

## Start
Use runner scripts (recommended) so control server auto-starts:
- `scripts/maestro/run_with_artifacts.ps1`

Or start manually:
- `scripts/control_server/ensure_server.bat`

## URLs
- Root: `http://127.0.0.1:4567/`
- Dashboard: `http://127.0.0.1:4567/dashboard`
- Last verdict: `http://127.0.0.1:4567/radio/last`
- Probe now: `http://127.0.0.1:4567/radio/probe`
- In-memory audit: `http://127.0.0.1:4567/audit?limit=50`
- Persisted audit tail: `http://127.0.0.1:4567/audit/file?limit=200`
- Download JSONL: `http://127.0.0.1:4567/audit/file/raw?limit=2000`

## What updates when
- Dashboard refreshes every 1s.
- Probe runs every 5s from dashboard (`/radio/probe`).
- New checks append audit events and refresh latest verdict.

## Data sources
- `dumpsys audio` -> audio focus/package
- `dumpsys media_session` -> playing state/title/artist/queue
- `uiautomator dump` XML -> station and band (UI truth)
- `adb devices -l` -> serial + device details

## Troubleshooting
1. `/` returns `not_found`
   - Old process still running; restart server.
2. `ui.station` is null
   - Check `<outDir>/ui_dump.xml` and `ui_dump_debug.txt`.
3. Backend check skipped/fails
   - Ensure local server is up on `127.0.0.1:4567`.
   - For intentional UI-only runs, set `MAESTRO_RADIO_ALLOW_SKIP=true`.
