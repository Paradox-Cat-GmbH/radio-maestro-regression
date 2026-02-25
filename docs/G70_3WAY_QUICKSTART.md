# G70 3-Device Same-Time Quickstart

## Endpoints from Leandro
- CDE: `169.254.166.167`
- RSE: `169.254.166.152`
- HU: `169.254.166.99`

## 1) Connect ADB over TCP
```powershell
.\scripts\connect-g70-devices.ps1
```

## 2) Create testcase scaffold
```powershell
.\scripts\new-g70-3way-testcase.ps1 -CaseId "TC_3WAY_001"
```

## 3) Edit the three flows
- `flows/g70/testcases/TC_3WAY_001/cde.yaml`
- `flows/g70/testcases/TC_3WAY_001/rse.yaml`
- `flows/g70/testcases/TC_3WAY_001/hu.yaml`

## 4) Run all 3 at same time
```powershell
.\scripts\run-g70-3way-same-time.ps1 -CaseId "TC_3WAY_001"
```

(Optional explicit mapping)
```powershell
.\scripts\run-g70-3way-same-time.ps1 -CaseId "TC_3WAY_001" -CDE "169.254.166.167:5555" -RSE "169.254.166.152:5555" -HU "169.254.166.99:5555"
```

## 5) Run with automatic DLT capture around the same-time run
```powershell
.\scripts\run-g70-3way-with-dlt.ps1 -CaseId "TC_3WAY_001"
```

(Override DLT endpoints if needed)
```powershell
.\scripts\run-g70-3way-with-dlt.ps1 -CaseId "TC_3WAY_001" -DltCDE "169.254.166.167" -DltRSE "169.254.166.152" -DltHU "169.254.166.99" -DltPort "3490"
```
