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

## EDIABAS Tool64 STR automation
This repo supports a host-side STR cycle via `Tool64Cli.exe` user actions:
- Sequence: `PAD -> WOHNEN -> PARKING -> sleep(180s) -> WOHNEN -> PAD`
- Default EDIABAS path: `C:\EC-Apps\EDIABAS\BIN`
- Default action names expected in Tool64 GUI:
  - `SET_PAD`
  - `SET_WOHNEN`
  - `SET_PARKING`

Run directly:
```bat
python scripts\ediabas_str_cycle.py --ediabas-bin "C:\EC-Apps\EDIABAS\BIN"
```

Run directly (Node.js, same CLI flags):
```bat
node scripts\ediabas_str_cycle.js --ediabas-bin "C:\EC-Apps\EDIABAS\BIN"
```

JS-first sidecar mode (direct EDIABAS API via pydiabas, no Tool64 actions):
```bat
node scripts\ediabas_str_cycle_sidecar.js --str-seconds 180 --settle-seconds 2
```

Sidecar dependency setup (recommended):
1. Install 32-bit Python (required by EDIABAS `api32.dll`).
2. Install sidecar dependency:
  ```bat
  C:\Path\To\Python32\python.exe -m pip install -r scripts\requirements-pydiabas-sidecar.txt
  ```
3. Point runner to 32-bit Python:
  ```bat
  set PYDIABAS_PYTHON32=C:\Path\To\Python32\python.exe
  ```

Sidecar diagnose/probe:
```bat
node scripts\ediabas_str_cycle_sidecar.js --diagnose --probe --probe-ecu TMODE --probe-job INFO
```

Start sidecar HTTP service explicitly (optional):
```bat
%PYDIABAS_PYTHON32% scripts\ediabas_pydiabas_sidecar.py serve --host 127.0.0.1 --port 8777
```

Auto mode behavior:
- `--mode auto` (default): tries `Tool64Cli` first, then falls back to `tool32` if available.
- `--mode tool64cli`: force Tool64 user-action execution.
- `--mode tool32`: force direct Tool32 job execution.

Force Tool32 mode (legacy direct jobs):
```bat
python scripts\ediabas_str_cycle.py --mode tool32 --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --tool32-prg IPB_APP1.prg --tool32-job STEUERN_ROUTINE --tool32-arg-pad "ARG;ZUSTAND_FAHRZEUG;STR;0x07" --tool32-arg-wohnen "ARG;ZUSTAND_FAHRZEUG;STR;0x05" --tool32-arg-parking "ARG;ZUSTAND_FAHRZEUG;STR;0x01"
```

Or via wrapper:
```bat
scripts\run_action.bat ediabas-str --ediabas-bin "C:\EC-Apps\EDIABAS\BIN"
```

Or via wrapper (Node.js):
```bat
scripts\run_action.bat ediabas-str-js --ediabas-bin "C:\EC-Apps\EDIABAS\BIN"
```

Or via wrapper (Node.js sidecar):
```bat
scripts\run_action.bat ediabas-str-js-sidecar --str-seconds 180 --settle-seconds 2
```

Direct API mode (experimental, no Tool64 user actions required):
```bat
node scripts\ediabas_str_cycle_api.js --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --str-seconds 180 --settle-seconds 2
```

Wrapper form:
```bat
scripts\run_action.bat ediabas-str-js-api --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --str-seconds 180 --settle-seconds 2
```

Direct API diagnose/probe:
```bat
node scripts\ediabas_str_cycle_api.js --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --diagnose --probe --probe-ecu TMODE --probe-job INFO
```

Notes for direct API mode:
- Uses `scripts/ediabas_api32_job.ps1` bridge with calls to `api32.dll` (EDIABAS API).
- Targets 32-bit API loading via x86 PowerShell path when available.
- Keep Tool64 action mode as fallback if API bridge cannot be initialized on a rack.

Customize timing:
```bat
python scripts\ediabas_str_cycle.py --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --str-seconds 180 --settle-seconds 2 --retries 1
```

Artifacts are written under:
- `artifacts/ediabas/str_cycle_<timestamp>/`
- Includes per-step Tool64 logs and `ediabas_str_audit.jsonl`

If Tool64 CLI fails:
- Re-run with `--mode tool32` on racks where `tool32.exe` is available.
- Check `ediabas_str_audit.jsonl` to see which engine was used per step (`tool64cli` or `tool32`) and exact return codes.

Tool64 troubleshooting (without Tool32):
```bat
python scripts\ediabas_str_cycle.py --mode tool64cli --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --diagnose --probe-action SET_PAD
```

This writes:
- `diagnose_report.txt` with binary detection, `--help` result, and probe-action result.
- `diagnose_probe_action.log` with probe action command output.

Use this to confirm if failures are due to missing action names, runtime path/dependency issues, or rack-specific Tool64 CLI behavior.

Flow action marker support:
- Add this in a Maestro YAML comment to run STR as host action:
  - `# ACTION: ediabas-str --ediabas-bin C:\EC-Apps\EDIABAS\BIN --str-seconds 180`
  - `# ACTION: ediabas-str-js --ediabas-bin C:\EC-Apps\EDIABAS\BIN --str-seconds 180`
  - `# ACTION: ediabas-str-js-api --ediabas-bin C:\EC-Apps\EDIABAS\BIN --str-seconds 180`
  - `# ACTION: ediabas-str-js-sidecar --str-seconds 180`

Node/Python parity:
- `scripts/ediabas_str_cycle.js` intentionally supports the same flags as `scripts/ediabas_str_cycle.py` for zero-friction migration.

Dependency governance:
- `pydiabas` is consumed as an external dependency for the sidecar and acknowledged in `THIRD_PARTY_NOTICES.md`.
- Raw downloaded package folders are ignored via `.gitignore` to avoid accidental vendoring.

## G70 multi-target orchestrator
End-to-end PoC runner:
- `scripts/g70_orchestrator.ps1`
- config: `scripts/g70_orchestrator.targets.json`
- docs: `docs/G70_MULTI_DEVICE_POC.md`

Run:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\g70_orchestrator.ps1
```

It generates per-run JSON/HTML/ZIP artifacts under:
- `artifacts/g70_orchestrator/<runId>/`

## Maestro Studio notes
Default workspace config keeps artifacts in repo:
- `config.yaml`
- `.maestro/config.yaml`

Both point to:
- `artifacts/maestro_studio`
