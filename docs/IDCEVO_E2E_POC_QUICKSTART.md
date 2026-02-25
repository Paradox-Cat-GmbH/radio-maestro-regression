# IDCEvo E2E PoC Quickstart (Single Device)

## Goal
Validate complete chain on IDCEvo:
- single-device Maestro run
- flow lifecycle hooks (onFlowStart/onFlowComplete)
- DLT capture start/stop around run

## 1) Create case
```powershell
.\scripts\new-idcevo-testcase.ps1 -CaseId "TC_IDCEVO_001"
```

## 2) Edit flow
- `flows/idcevo/testcases/TC_IDCEVO_001/idcevo.yaml`

## 3) Find IDCEvo device ID
```powershell
adb devices -l
```

## 4) Run E2E PoC (DLT localhost:3490)
```powershell
.\scripts\run-idcevo-e2e-poc.ps1 -CaseId "TC_IDCEVO_001" -DeviceId "IDCEVO_SERIAL" -DltIp "localhost" -DltPort "3490"
```

## Studio-first JavaScript mode (recommended for Leandro workflow)
One command prep (creates case flow if missing, starts control server, generates env vars):
```powershell
.\scripts\oneclick-idcevo-studio.ps1 -CaseId "TC_IDCEVO_001" -DltIp "169.254.107.117" -DltPort "3490"
```
In Maestro Studio open flow:
`flows/idcevo/testcases/TC_IDCEVO_001/idcevo.studio.yaml`

Paste env vars printed by the script in Studio, then Run.
This uses JS (`runScript`) inside Studio to call local control server endpoints for:
- DLT start (onFlowStart)
- DLT stop + evidence bundle (onFlowComplete)

### Minimal no-prep Studio option
If control server is already running, you can run Studio flow directly and set only:
- `CONTROL_SERVER_URL`
- `DLT_IP`
- `DLT_PORT`
- `CASE_ID`

`RUN_TS/RUN_ROOT/DLT_OUTPUT/CAPTURE_ID` are optional (auto defaults exist), but using oneclick gives cleaner bundled evidence paths.

## Studio sidecar mode (fallback)
If env setup in Studio is inconvenient, use sidecar helper:
```powershell
.\scripts\run-idcevo-studio-evidence.ps1 -CaseId "TC_IDCEVO_001" -DltIp "169.254.107.117" -DltPort "3490"
```
Then run the test in Studio, return to terminal, press ENTER. The script will stop DLT and bundle evidence.

## Artifacts
- Run bundle root: `artifacts/runs/idcevo/<CASE_ID>/<timestamp>/`
- DLT: `artifacts/runs/idcevo/<CASE_ID>/<timestamp>/dlt/idcevo_capture.dlt`
- CLI Maestro output (if CLI runner used): `.../maestro/`
- Studio run copy (if Studio helper used): `.../studio/`
- Video copy: `.../video/`
- Summary JSON: `artifacts/runs/idcevo/<CASE_ID>/<timestamp>/run-summary.json`
