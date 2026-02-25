# G70 Same-Time Test Pack

This folder is the "drag & drop" structure for 2-device synchronized Maestro runs.

## Layout

- `testcases/<CASE_ID>/deviceA.yaml` → steps for phone/device A
- `testcases/<CASE_ID>/deviceB.yaml` → steps for G70 rack/device B
- `testcases/<CASE_ID>/case.meta.yaml` → human-readable case notes/checklist
- `subflows/common/` → reusable shared blocks
- `subflows/deviceA/` → reusable blocks only for phone side
- `subflows/deviceB/` → reusable blocks only for G70 side

## Fast start

1. Create a new case from template:
   ```powershell
   .\scripts\new-g70-testcase.ps1 -CaseId "TC_001_poc"
   ```
2. Edit both files:
   - `flows/g70/testcases/TC_001_poc/deviceA.yaml`
   - `flows/g70/testcases/TC_001_poc/deviceB.yaml`
3. Run both at same time:
   ```powershell
   .\scripts\run-g70-same-time.ps1 -CaseId "TC_001_poc"
   ```

## Notes

- Maestro internally calls this "shard" when running two devices in one process.
- In this repo, we treat it as "same-time simultaneous run".
- Keep side-specific logic in each device file, and reuse common steps via `runFlow`.
