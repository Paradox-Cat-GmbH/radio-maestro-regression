# Radio Maestro Regression

Maestro-first AAOS radio regression flows for BMW iDrive racks.

## What this project does
- Navigates to Radio reliably (Home -> Media DET -> Source check -> Radio).
- Applies deterministic Radio preconditions from Settings.
- Opens All stations and selects station robustly (label/frequency primary, index fallback).
- Verifies backend playback truth via local control server (`http://127.0.0.1:4567`).
- Exposes a live local dashboard + persisted audit for run observability.

## Core behavior (Leandro workflow)
From Radio:
1. Open Settings.
2. Ensure `Switch automatically to full screen mode` is OFF.
3. Open `Radio settings`.
4. Ensure sorting is `Alphabetically`.
5. Ensure `Radio info` is OFF.
6. Close Radio settings.
7. Close Settings.

## Station selection hardening
Primary + fallback strategy:
- **Primary:** if `MAESTRO_STATION_TARGET` is provided, flow scrolls until target text is visible and taps it.
- **Fallback:** deterministic index-based tap after page scroll calculation.

Files:
- Script: `scripts/maestro/pick_random_station.js`
- Flow: `flows/subflows/tap_random_all_stations_entry.yaml`

### Random/index controls
- `MAESTRO_RAND_MAX_INDEX` controls random **absolute** max index.
  - Default: `5`
  - Supported max: `24` (5 pages x 5 visible rows)
- `FIXED_INDEX` (optional) forces a deterministic absolute index for repro/debug.

## Backend verification contract
Flow: `flows/subflows/verify_radio_backend.yaml`

Strict assertions (when backend check runs):
- `ok == true`
- `media.playing == true`
- `audio.audioFocus == true`
- `media.package == com.bmwgroup.apinext.tunermediaservice`

Skip behavior:
- Control server unavailable -> check marked skipped.
- By default skipped check **fails** the flow (strict mode).
- Set `MAESTRO_RADIO_ALLOW_SKIP=true` only for explicit UI-only runs.

## Local control server + dashboard
Server:
- `scripts/control_server/server.js`
- auto-start helper: `scripts/control_server/ensure_server.bat`

Main endpoints:
- `GET /` (service info)
- `GET /dashboard` (live HTML dashboard)
- `GET /health`
- `GET /radio/last`
- `GET /radio/probe`
- `GET /audit?limit=20` (in-memory)
- `GET /audit/file?limit=50` (persisted tail)
- `GET /audit/file/raw?limit=500` (download JSONL)
- `POST /radio/check`
- `POST /inject/swag`
- `POST /inject/bim`
- `POST /ehh/set`

### Dashboard data
The dashboard combines:
- backend media/audio verdict (`dumpsys`)
- UI station/band parsing from `uiautomator` XML
- device identity from `adb devices -l`

Persisted audit file:
- `artifacts/control_server_audit.jsonl`

Per-check artifacts include:
- `backend_verdict.json`
- `dumpsys_audio.txt`
- `dumpsys_media_session.txt`
- `current_user.txt`
- `ui_dump.xml` (when available)
- `ui_dump_debug.txt`

## Runners
All runners call:
- `scripts/maestro/run_with_artifacts.ps1`

Artifacts path:
- `artifacts/runs/<timestamp>/<flow_name>/debug`
- `artifacts/runs/<timestamp>/<flow_name>/output`
- `artifacts/runs/<timestamp>/<flow_name>/videos/<flow_name>.mp4`
- `artifacts/runs/<timestamp>/<flow_name>/record_debug`

### Single flow
```bat
run_single_flow.bat <DEVICE_ID> <FLOW_PATH>
```

### Demo suite
```bat
run_demo_suite.bat <DEVICE_ID>
```

### Regression suite
```bat
run_suite.bat <DEVICE_ID>
```

### Lightning set
```bat
run_lightning_demo.bat <DEVICE_ID>
```

## Maestro Studio notes
Default workspace config keeps artifacts in repo:
- `config.yaml`
- `.maestro/config.yaml`

Both point to:
- `artifacts/maestro_studio`
