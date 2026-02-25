# G70 Template Quickstart

## 1) Create case folder
```powershell
.\scripts\new-g70-testcase.ps1 -CaseId "TC_001_poc"
```

## 2) Edit flows
- `flows/g70/testcases/TC_001_poc/deviceA.yaml`
- `flows/g70/testcases/TC_001_poc/deviceB.yaml`

Use `runFlow` for reusable blocks:
```yaml
- runFlow: ../../subflows/common/wait_for_sync_window.yaml
```

## 3) Run same-time on both devices
```powershell
.\scripts\run-g70-same-time.ps1 -CaseId "TC_001_poc"
```

(Optional explicit devices)
```powershell
.\scripts\run-g70-same-time.ps1 -CaseId "TC_001_poc" -DeviceA "SERIAL_A" -DeviceB "SERIAL_B"
```
