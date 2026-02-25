# DLT + Maestro Integration

This setup adds a Node helper to start/stop DLT capture around a Maestro run.

## Files
- `scripts/dlt-capture.js` -> start/stop/status DLT capture (`dlt-receive`), now supports capture IDs for parallel captures
- `scripts/run-with-dlt.ps1` -> wrapper that starts capture, runs flow, always stops capture
- `scripts/run-g70-3way-with-dlt.ps1` -> starts CDE/RSE/HU captures, runs 3-way same-time case, always stops all captures
- `flows/g70/subflows/common/login.yaml` -> example onFlowStart subflow
- `flows/g70/subflows/common/cleanup.yaml` -> example onFlowComplete subflow
- `flows/g70/testcases/_template_3way/feature_with_hooks.example.yaml` -> example flow with hooks

## Usage

### 1) Run flow with DLT capture
```powershell
.\scripts\run-with-dlt.ps1 -Flow "flows\g70\testcases\TC_3WAY_001\cde.yaml" -Device "169.254.166.167:5555" -DltIp "192.168.1.50" -DltPort "3490" -DltOutput "artifacts\dlt\TC_3WAY_001_cde.dlt"
```

### 2) Manual control if needed
```powershell
node .\scripts\dlt-capture.js start 192.168.1.50 3490 artifacts\dlt\manual_capture.dlt myCapture
node .\scripts\dlt-capture.js status 0 0 0 myCapture
node .\scripts\dlt-capture.js stop 0 0 0 myCapture
```

### 3) 3-way run with auto DLT (CDE/RSE/HU)
```powershell
.\scripts\run-g70-3way-with-dlt.ps1 -CaseId "TC_3WAY_001"
```

## Notes
- Requires `dlt-receive` available in PATH.
- If not in PATH, set `DLT_RECEIVE_BIN` to full executable path before running:
  ```powershell
  $env:DLT_RECEIVE_BIN = "C:\full\path\to\dlt-receive.exe"
  ```
- `onFlowStart` / `onFlowComplete` are for test setup/teardown subflows.
- DLT process lifecycle is handled by PowerShell wrapper for reliability.
- For G70, prefer `run-g70-3way-with-dlt.ps1` to keep start/run/stop consistent.
