# Maestro Same-Time Screenshot Test (2 Devices)

## Files
- `Test.yaml` -> generic screenshot flow
- `Test1.yaml` -> screenshot for Device A
- `Test2.yaml` -> screenshot for Device B
- `scripts/run-same-time.ps1` -> PowerShell same-time run (recommended)
- `scripts/run-parallel-tests.sh` -> Bash background run

## Run (PowerShell, auto-detect first 2 devices)
```powershell
.\scripts\run-same-time.ps1
```

## Run (PowerShell, optional explicit devices)
```powershell
.\scripts\run-same-time.ps1 -DeviceA "ID_DO_DEVICE_A" -DeviceB "ID_DO_DEVICE_B"
```

## How to get IDs
```powershell
adb devices -l
```

## Notes
- This PoC only takes screenshots (no app launch step).
- Works with Android devices connected to the same PC.
- `appId` is still required by Maestro config; current flows use `com.android.settings`.
