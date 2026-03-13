# IDC23 PRT Validation Pack

Purpose: execute IDC23 regression with the same Studio-first architecture used in IDCEvo/G70, while reusing shared backend helpers and hooks.

## IDC23-specific rules

- IDC23 is not a drop-in selector match for IDCEvo or G70. Validate selectors on IDC23 screen state before reusing them.
- Do not manually pre-create `tcp:7001 -> tcp:7001`. Clean ADB mappings and let Maestro own forwarding.
- For Studio evidence mode, IDC23 uses a single-device env block. Do not reuse G70 `CDE_DEVICE`, `RSE_DEVICE`, `HU_DEVICE`, or per-stack capture IDs here.

## Included cases

The PRT pack now includes 22 ABPI testcases generated from `TMS_PRT_TestScenarios.pdf`:
- Case folders: `flows/idc23/testcases/ABPI-*/`
- Case index: `flows/idc23/testcases/_INDEX.txt`

Each testcase contains:
- `case.meta.yaml` (traceability + acceptance)
- `idc23.yaml` (CLI flow)
- `idc23.studio.yaml` (Studio hooks + DLT/evidence bundling)

## Flow layers

IDC23 has three different entry layers. They are related, but they are not the same thing:

- `flows/idc23/demo/IDC23DEV-*.yaml`
  - Thin demo wrappers used for bulk orchestration and PDF-style naming.
  - Usually set a friendly `output.testId` such as `IDC23DEV-684348`.
  - Then call the real testcase flow, for example `../testcases/ABPI-684348/idc23.yaml`.
- `flows/idc23/testcases/ABPI-*/idc23.yaml`
  - The actual testcase logic used by CLI runs and by the demo wrappers.
  - Includes normal `start.yaml` / `stop.yaml`.
  - Does not add the Studio-specific DLT/video/bundle wrapper layer.
- `flows/idc23/testcases/ABPI-*/idc23.studio.yaml`
  - The Studio entrypoint for the same testcase.
  - Wraps the testcase with Studio hooks such as `studio_start_dlt.yaml`, `studio_stop_dlt.yaml`, and `studio_bundle_evidence.yaml`.
  - This is the file to open in Maestro Studio when you want Studio-managed evidence.

Example:
- `flows/idc23/demo/IDC23DEV-684348__shortcut_icons_after_str_mode.yaml`
  - sets `output.testId = 'IDC23DEV-684348'`
  - runs `../testcases/ABPI-684348/idc23.yaml`
- `flows/idc23/testcases/ABPI-684348/idc23.yaml`
  - contains the real case steps
- `flows/idc23/testcases/ABPI-684348/idc23.studio.yaml`
  - is the Studio wrapper for the same case

Important:
- `tags:` are metadata only. They do not decide which platform logic runs.
- Platform behavior comes from the flow family you explicitly run:
  - `flows/idc23/...` -> IDC23
  - `flows/idcevo/...` -> IDCEVO
  - `flows/g70/...` -> G70
- `run_idc23_demo_suite.bat` does not look up tags. It directly runs `flows/idc23/demo/IDC23DEMO-900001__prt_pdf_full_suite.yaml`, and that master flow then runs the flat `IDC23DEV-*` wrappers one by one.

## Run a testcase

CLI:
```powershell
.\scripts\run-idc23-e2e-poc.ps1 -CaseId "ABPI-671618" -DeviceId "169.254.8.177:5555" -DltIp "169.254.8.177" -DltPort "3490"
```

Studio prep:
```powershell
.\scripts\oneclick-idc23-studio.ps1 -CaseId "ABPI-671618" -DeviceId "169.254.8.177:5555" -DltIp "169.254.8.177" -DltPort "3490"
```

Then open `flows/idc23/testcases/ABPI-671618/idc23.studio.yaml`, paste generated env vars, and run.

Before Studio runs, reset the device bridge:

```powershell
.\scripts\adb.bat kill-server
.\scripts\adb.bat start-server
.\scripts\adb.bat connect 169.254.8.177:5555
.\scripts\adb.bat -s 169.254.8.177:5555 forward --remove-all
.\scripts\adb.bat -s 169.254.8.177:5555 reverse --remove-all
```

## Maestro Studio env keys for IDC23

`oneclick-idc23-studio.ps1` now emits only the fixed keys that must be supplied in Studio:
- `CONTROL_SERVER_URL`
- `DEVICE_ID`
- `DLT_IP`
- `DLT_PORT`
- `CASE_ID`

Notes:
- This is the correct IDC23 Studio set. G70 multi-device keys are not required here.
- `DEVICE_ID` should be the IDC23 HU serial, for example `169.254.8.177:5555`, so control-server fallback evidence stays pinned to the right device.
- `DLT_IP` should be the rack hostname used by DLT Viewer, for example `169.254.8.177`, with `DLT_PORT=3490`.
- `RUN_TS`, `RUN_ROOT`, `DLT_OUTPUT`, and `CAPTURE_ID` are generated automatically when the Studio run starts.
- `DLT_RECEIVE_BIN` is not a Studio env key. It is a control-server-side dependency.

## Selector mapping workflow

Use Maestro CLI hierarchy export as the primary selector source for IDC23:

```powershell
maestro --device 169.254.8.177:5555 hierarchy --compact
maestro --device 169.254.8.177:5555 query id=statusbar_title
maestro --device 169.254.8.177:5555 query text="All stations"
```

Repo helper:

```powershell
.\scripts\idc23_capture_hierarchy.ps1 -DeviceId "169.254.8.177:5555" -Label "screen_name"
```

Reference artifacts:
- `artifacts/maestro_hierarchy_compact_latest.csv`
- `docs/IDC23_SELECTOR_WORKFLOW.md`
- `artifacts/idc23_ui_map/manual_selector_inventory_20260309.md` (local note bundle)

## DLT evidence prerequisite

DLT capture is driven by the control server. Current launcher/scripts now resolve `dlt-receive` in this order:
- `DLT_RECEIVE_BIN` if explicitly set
- `C:\Tools\dlt\dlt-receive.exe`
- `C:\Tools\dlt\dlt-receive-v2.exe`
- `dlt-receive` from `PATH`

If evidence is missing, restart the control server and verify the resolved binary exists.

## Run all PDF cases (IDCEvo-style demo orchestration)

Master demo flow:
- `flows/idc23/demo/IDC23DEMO-900001__prt_pdf_full_suite.yaml`

Per-case demo files (flat, same style as `flows/demo/`):
- `flows/idc23/demo/IDC23DEV-*.yaml`
- Demo index: `flows/idc23/demo/_INDEX.txt`

CLI:
```powershell
run_idc23_demo_suite.bat <IDC23_SERIAL>
```

This executes one master flow, which then runs all 22 IDC23 demo files sequentially.

## Lifecycle + profile recovery knobs

For lifecycle-heavy case `ABPI-671618`:
- `IDC23_STR_LOOPS` (default `5`)
- `IDC23_COLD_BOOT_LOOPS` (default `5`)
- `IDC23_TARGET_USER_ID` and/or `IDC23_TARGET_USER_NAME`

For explicit multi-user cases `ABPI-684348` and `ABPI-671650`:
- `IDC23_USER_X_ID` and/or `IDC23_USER_X_NAME`
- `IDC23_USER_Y_ID` and/or `IDC23_USER_Y_NAME`

Profile recovery uses backend endpoint `POST /device/user-ensure` through `flows/subflows/ensure_user_profile_backend.yaml`.

IDC23 start flow now also suppresses CID/PHUD EHH by default through the control server:
- `persist.vendor.com.bmwgroup.disable_cid_ehh=true`
- `persist.vendor.com.bmwgroup.disable_phud_ehh=true`

IDC23 start flow also force-stops and disables the Alexa packages for the active test users by default:
- `com.amazon.alexa.auto.app`
- `com.bmwgroup.assistant.alexa`

## Evidence optimization (pass runs)

To reduce storage when tests pass:
- Set env `MAESTRO_KEEP_EVIDENCE_ON_PASS=false` for `run_with_artifacts.ps1`
- Or call IDC23 runner with `-PruneEvidenceOnPass`

When enabled, pass artifacts are pruned and only lightweight run summary remains.
