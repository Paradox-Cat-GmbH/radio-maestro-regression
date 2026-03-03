# IDC23 E2E Validation Pack

Purpose: keep IDC23 regression work isolated in this repo while reusing the proven Maestro + DLT + Studio-first foundation.

## Workflow

1. Create testcase
```powershell
.\scripts\new-idc23-testcase.ps1 -CaseId "TC_IDC23_001"
```

2. Fill flow
- `flows/idc23/testcases/TC_IDC23_001/idc23.yaml`

3. Run E2E PoC (CLI)
```powershell
.\scripts\run-idc23-e2e-poc.ps1 -CaseId "TC_IDC23_001" -DeviceId "<IDC23_SERIAL>" -DltIp "169.254.107.117" -DltPort "3490"
```

4. Studio-first orchestration (preferred)
```powershell
.\scripts\oneclick-idc23-studio.ps1 -CaseId "TC_IDC23_001" -DltIp "169.254.107.117" -DltPort "3490"
```
Open `flows/idc23/testcases/TC_IDC23_001/idc23.studio.yaml` in Studio, paste env vars, Run.

5. Studio sidecar fallback
```powershell
.\scripts\run-idc23-studio-evidence.ps1 -CaseId "TC_IDC23_001" -DltIp "169.254.107.117" -DltPort "3490"
```
Run in Studio, then press ENTER in terminal to finalize bundle.
