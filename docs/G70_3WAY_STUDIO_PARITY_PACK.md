# G70 Maestro Studio Parity Pack (IDCEvo-style)

## Goal
Bring G70 (CDE/RSE/HU) to the same Studio lifecycle model already validated on IDCEvo:
- `onFlowStart` -> start DLT via control server
- `onFlowComplete` -> stop DLT + bundle evidence
- deterministic run-root artifacts

## Included in this pack
- G70 common Studio subflows:
  - `flows/g70/subflows/common/studio_start_dlt.yaml`
  - `flows/g70/subflows/common/studio_stop_dlt.yaml`
  - `flows/g70/subflows/common/studio_bundle_evidence.yaml`
- 3-way template hook wiring:
  - `flows/g70/testcases/_template_3way/cde.yaml`
  - `flows/g70/testcases/_template_3way/rse.yaml`
  - `flows/g70/testcases/_template_3way/hu.yaml`
- One-click Studio prep:
  - `scripts/oneclick-g70-3way-studio.ps1`

## 1) Prepare case + env (one command)
```powershell
.\scripts\oneclick-g70-3way-studio.ps1 -CaseId "TC_3WAY_001"
```

This will:
- create the case from `_template_3way` if missing
- start control server if needed
- create run root under `artifacts/runs/g70/<CASE>/<timestamp>/`
- generate and print Studio env vars

## 2) Open these flows in Maestro Studio
- `flows/g70/testcases/TC_3WAY_001/cde.yaml`
- `flows/g70/testcases/TC_3WAY_001/rse.yaml`
- `flows/g70/testcases/TC_3WAY_001/hu.yaml`

Use same-time 3-device execution in Studio with mapping:
- CDE -> `CDE_DEVICE`
- RSE -> `RSE_DEVICE`
- HU  -> `HU_DEVICE`

## 3) Paste env vars from script output
Required env vars (recommended to keep in Studio env):
- common: `CONTROL_SERVER_URL`, `CASE_ID`, `DLT_PORT`
- per screen:
  - `DLT_IP_CDE`, `CAPTURE_ID_CDE`, `CDE_DEVICE`
  - `DLT_IP_RSE`, `CAPTURE_ID_RSE`, `RSE_DEVICE`
  - `DLT_IP_HU`, `CAPTURE_ID_HU`, `HU_DEVICE`

Optional override vars (advanced/manual control only):
- `RUN_TS`, `RUN_ROOT`
- `DLT_OUTPUT_CDE`, `DLT_OUTPUT_RSE`, `DLT_OUTPUT_HU`

If optional vars are omitted, the control server auto-generates run timestamp, run root, and per-screen DLT output paths.

## Artifact layout (parity target)
- `artifacts/runs/g70/<CASE>/<timestamp>/cde/...`
- `artifacts/runs/g70/<CASE>/<timestamp>/rse/...`
- `artifacts/runs/g70/<CASE>/<timestamp>/hu/...`

Each screen gets its own DLT output via the control server endpoint contract.

## Notes
- Without live rack access you can still prepare and review full wiring.
- Final runtime validation depends on real ADB + ECU/DLT reachability.
