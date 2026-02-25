# IDCEvo E2E Validation Pack

Purpose: prove end-to-end setup (Maestro + DLT capture + flow hooks) on current IDCEvo rack before real G70 scenarios.

Hook naming now uses `start.yaml` / `stop.yaml` (instead of login/cleanup placeholders).

## Workflow

1. Create testcase
```powershell
.\scripts\new-idcevo-testcase.ps1 -CaseId "TC_IDCEVO_001"
```

2. Fill file
- `flows/idcevo/testcases/TC_IDCEVO_001/idcevo.yaml`

3. Run E2E PoC (CLI)
```powershell
.\scripts\run-idcevo-e2e-poc.ps1 -CaseId "TC_IDCEVO_001" -DeviceId "<IDCEVO_SERIAL>" -DltIp "169.254.107.117" -DltPort "3490"
```

4. Studio-first JS orchestration (preferred)
```powershell
.\scripts\oneclick-idcevo-studio.ps1 -CaseId "TC_IDCEVO_001" -DltIp "169.254.107.117" -DltPort "3490"
```
Open `flows/idcevo/testcases/TC_IDCEVO_001/idcevo.studio.yaml` in Studio, paste env vars, Run.

5. Studio sidecar fallback
```powershell
.\scripts\run-idcevo-studio-evidence.ps1 -CaseId "TC_IDCEVO_001" -DltIp "169.254.107.117" -DltPort "3490"
```
Run test in Studio, then press ENTER in terminal to finalize bundle.
