# Radio Maestro Regression

Maestro-first AAOS radio regression flows for BMW iDrive racks.

## What this project does
- Navigates to Radio reliably (Home -> Media DET -> Source check -> Radio).
- Applies Radio preconditions from Settings.
- Opens All stations and selects a random station safely.
- Verifies backend playback truth from `http://127.0.0.1:4567/radio/check`.

## Core behavior (Leandro workflow)
1. Tap Home.
2. Tap Media DET.
3. If already on Radio (`All stations` visible), continue.
4. Else if on Source screen, select `Radio`.
5. Else tap Media DET again and retry.

Then from Radio:
1. Open Settings.
2. Ensure `Switch automatically to full screen mode` is OFF.
3. Open `Radio settings`.
4. Ensure sorting is `Alphabetically`.
5. Ensure `Radio info` is OFF.
6. Close Radio settings.
7. Close Settings.

## Random station selection
Random tapping is branch-safe (no invalid `tapOn: ${output.selectorObject}` pattern).

- Script: `scripts/maestro/pick_random_station.js`
- Flow: `flows/subflows/tap_random_all_stations_entry.yaml`

`MAESTRO_RAND_MAX_INDEX` controls max random absolute index.
- Default: `5`.
- Supported max: `29` (5 pages x 6 visible rows).
- Flow pre-scrolls pages when needed, then taps visible row index `0..5`.

## Backend verification contract
The backend check is strict when server is reachable:
- `ok == true`
- `media.playing == true`
- `audio.audioFocus == true`
- `media.package == com.bmwgroup.apinext.tunermediaservice`

If control server is unavailable, backend check is marked as skipped with reason.

## Runners (simple)
All runners call one script:
- `scripts/maestro/run_with_artifacts.ps1`

It runs test + local video recording for each flow and stores artifacts in:
- `artifacts/runs/<timestamp>/<flow_name>/debug`
- `artifacts/runs/<timestamp>/<flow_name>/output`
- `artifacts/runs/<timestamp>/<flow_name>/videos/<flow_name>.mp4`
- `artifacts/runs/<timestamp>/<flow_name>/record_debug`

### Single flow
```bat
run_single_flow.bat <DEVICE_ID> <FLOW_PATH>
```
Example:
```bat
run_single_flow.bat 169.254.107.117:5555 flows\demo\IDCEVODEV-478199__all_stations_select.yaml
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

## Control server
Auto-started by runners via:
- `scripts/control_server/ensure_server.bat`

Health endpoint:
- `http://127.0.0.1:4567/health`

## Maestro Studio notes
Default workspace config is set to keep artifacts in repo:
- `config.yaml`
- `.maestro/config.yaml`

Both point to:
- `artifacts/maestro_studio`

## Extra backend fields for station/song context
`backend_verdict.json` now also includes media queue metadata when available:
- `media.queueTitle`
- `media.queueSize`
- `media.metadataDescription`
- `media.metadataTitle`
- `media.metadataArtist`
