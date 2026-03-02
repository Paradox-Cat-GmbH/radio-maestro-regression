# EDIABAS JS Direct API Spike (No Tool64 Actions)

## Goal
Run STR transitions from JavaScript without relying on manually created Tool64 GUI actions.

## Implemented
- Node STR runner (direct API path): `scripts/ediabas_str_cycle_api.js`
- PowerShell API bridge to `api32.dll`: `scripts/ediabas_api32_job.ps1`
- Wrapper integration: `scripts/run_action.bat` (`ediabas-str-js-api`)
- ACTION integration: `scripts/helpers.py` + timeout handling in `scripts/run_flow_with_actions.py`

## Commands
Direct run:
```bat
node scripts\ediabas_str_cycle_api.js --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --str-seconds 180 --settle-seconds 2
```

Diagnose + probe:
```bat
node scripts\ediabas_str_cycle_api.js --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --diagnose --probe --probe-ecu TMODE --probe-job INFO
```

Wrapper:
```bat
scripts\run_action.bat ediabas-str-js-api --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --str-seconds 180
```

## Current status on this rack
- Bridge initialization works (`ApiInitExt` returns success).
- Job dispatch currently fails (`job_rc=0`) on probe attempts.
- Typical outcomes observed:
  - `TMODE/INFO` -> `SYS-0005: OBJECT FILE NOT FOUND`
  - `IPB_APP1/INFO` -> final state READY but `job_rc=0`

Artifacts:
- `artifacts/ediabas/api32_js_diagnose/`
- `artifacts/ediabas/api32_js_diagnose_ipb/`
- `artifacts/ediabas/api32_js_diagnose_ipb_v2/`
- `artifacts/ediabas/api32_js_diagnose_cfg_ecupath/`

## Likely blockers
- API job function signature/entrypoint mismatch versus local `api32.dll` variant.
- EDIABAS configuration context mismatch when running via x86 PowerShell host.
- Potential need for additional API calls/options before `ApiJob*` is accepted.

## Next recommended steps
1. Validate exact `api32.dll` function signatures from local EDIABAS `Api.h` / docs (`__apiJob` vs `__apiJobData` parameter contract).
2. Capture known-good API trace from a working client session and compare call sequence.
3. Add one minimal known-good API job from the same ECU/session context, then re-run STR sequence.
4. Keep `ediabas-str-js` (Tool64 CLI action mode) as production fallback until direct API path is green.
