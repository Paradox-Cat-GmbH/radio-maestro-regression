# G70 Multi-Device PoC (CDE / RSE / HU)

This repo now includes a full end-to-end orchestrator for multi-target G70 runs.

## Files
- Config: `scripts/g70_orchestrator.targets.json`
- Runner: `scripts/g70_orchestrator.ps1`

## What it does
For each enabled target:
1. `adb connect <ip>` (with retries)
2. Check device state (`adb -s <serial> get-state`)
3. Start Calendar on display (`am start ... --display <id>`)
4. Dump UI XML (`uiautomator dump /sdcard/window_dump_<TARGET>.xml`)
5. Pull XML locally
6. (Optional) Run Maestro flow for that specific target serial

## Artifacts generated per run
Path:
- `artifacts/g70_orchestrator/<runId>/`

Outputs:
- `report.json` (machine-readable)
- `report.html` (human-readable)
- `<TARGET>/window_dump_<TARGET>.xml`
- `<TARGET>/...` step outputs
- ZIP bundle: `artifacts/g70_orchestrator/<runId>.zip`

## Run (adb actions only)
```powershell
powershell -ExecutionPolicy Bypass -File scripts\g70_orchestrator.ps1
```

## Run with Maestro per target
```powershell
powershell -ExecutionPolicy Bypass -File scripts\g70_orchestrator.ps1 -EnableMaestro
```

Optional Maestro path:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\g70_orchestrator.ps1 -EnableMaestro -MaestroExe "C:\path\to\maestro.bat"
```

## Useful options
- `-SkipConnect` (if already connected)
- `-ContinueOnFailure:$false` (stop on first failing target)
- `-OpenReport` (auto-open HTML report after run)
- `-ConfigPath <path>` (use a custom config)

## Target mapping (current)
- CDE: `169.254.166.167`
- RSE: `169.254.166.152`
- HU: `169.254.166.99`

Adjust `displayId` per target in `scripts/g70_orchestrator.targets.json` once confirmed.
