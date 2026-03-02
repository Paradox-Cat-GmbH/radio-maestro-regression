# EDIABAS pydiabas Sidecar (JS-first)

## Why this exists
Leandro's target is JS-first orchestration (Maestro Studio friendly) without manual Tool64 action setup.

This sidecar approach keeps orchestration in JavaScript while executing direct EDIABAS API calls through `pydiabas`.

## Components
- JS STR orchestrator: `scripts/ediabas_str_cycle_sidecar.js`
- Python sidecar service: `scripts/ediabas_pydiabas_sidecar.py`
- Pinned dependency: `scripts/requirements-pydiabas-sidecar.txt`

## Modes
- CLI sidecar mode: JS runner invokes sidecar `run-job` command per state transition.
- HTTP sidecar mode: JS runner sends job requests to sidecar `/job` endpoint.
- Auto mode: tries HTTP first, then CLI.

## Setup
1. Install 32-bit Python (required for `api32.dll`).
2. Install dependency:
   ```bat
   C:\Path\To\Python32\python.exe -m pip install -r scripts\requirements-pydiabas-sidecar.txt
   ```
3. Set environment variable:
   ```bat
   set PYDIABAS_PYTHON32=C:\Path\To\Python32\python.exe
   ```

## Run STR
```bat
node scripts\ediabas_str_cycle_sidecar.js --str-seconds 180 --settle-seconds 2
```

## Diagnose
```bat
node scripts\ediabas_str_cycle_sidecar.js --diagnose --probe --probe-ecu TMODE --probe-job INFO
```

## Wrapper command
```bat
scripts\run_action.bat ediabas-str-js-sidecar --str-seconds 180 --settle-seconds 2
```

## Maestro ACTION marker
```yaml
# ACTION: ediabas-str-js-sidecar --str-seconds 180
```

## Ready-made Maestro smoke test flow
- Flow file: `flows/smoke/_smoke_ediabas_str_sidecar.yaml`
- Runs a short STR cycle (`str-seconds=5`) via ACTION marker.

Run with host-action wrapper:
```bat
python scripts\run_flow_with_actions.py flows\smoke\_smoke_ediabas_str_sidecar.yaml --no-validate
```
