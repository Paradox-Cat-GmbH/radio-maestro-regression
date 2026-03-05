# IDC23 PRT Validation Pack

Purpose: execute IDC23 regression with the same Studio-first architecture used in IDCEvo/G70, while reusing shared backend helpers and hooks.

## Included cases

The PRT pack now includes 22 ABPI testcases generated from `TMS_PRT_TestScenarios.pdf`:
- Case folders: `flows/idc23/testcases/ABPI-*/`
- Case index: `flows/idc23/testcases/_INDEX.txt`

Each testcase contains:
- `case.meta.yaml` (traceability + acceptance)
- `idc23.yaml` (CLI flow)
- `idc23.studio.yaml` (Studio hooks + DLT/evidence bundling)

## Run a testcase

CLI:
```powershell
.\scripts\run-idc23-e2e-poc.ps1 -CaseId "ABPI-671618" -DeviceId "<IDC23_SERIAL>" -DltIp "169.254.107.117" -DltPort "3490"
```

Studio prep:
```powershell
.\scripts\oneclick-idc23-studio.ps1 -CaseId "ABPI-671618" -DltIp "169.254.107.117" -DltPort "3490"
```

Then open `flows/idc23/testcases/ABPI-671618/idc23.studio.yaml`, paste generated env vars, and run.

## Lifecycle + profile recovery knobs

For lifecycle-heavy case `ABPI-671618`:
- `IDC23_STR_LOOPS` (default `5`)
- `IDC23_COLD_BOOT_LOOPS` (default `5`)
- `IDC23_TARGET_USER_ID` and/or `IDC23_TARGET_USER_NAME`

Profile recovery uses backend endpoint `POST /device/user-ensure` through `flows/subflows/ensure_user_profile_backend.yaml`.

## Evidence optimization (pass runs)

To reduce storage when tests pass:
- Set env `MAESTRO_KEEP_EVIDENCE_ON_PASS=false` for `run_with_artifacts.ps1`
- Or call IDC23 runner with `-PruneEvidenceOnPass`

When enabled, pass artifacts are pruned and only lightweight run summary remains.
