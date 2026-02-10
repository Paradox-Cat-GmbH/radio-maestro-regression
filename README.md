# RadioRegression (Maestro) + ADB Validation

## What this repo is
- **Maestro**: drives the BMW iDrive/AAOS UI flows.
- **ADB validation**: confirms Radio is *actually* playing (audio focus + media session), not just that the UI looks correct.

## Terminology (BMW-specific)
These names come from the platform/components, not from Maestro:
- **CID**: Central Information Display (main center screen).
- **PHUD**: Passenger Head‑Up Display / secondary surface (multi‑display setup).
- **SWAG**: Steering wheel input path (MFL controls / steering‑wheel events).
- **BIM**: Center console/button input path (input events routed via a separate module). The exact naming varies internally; treat it as “non‑touch hardware input path”.
- **Superstack Media Widget**: the media widget rendered in the “superstack”/home area.

Why this matters: **SWAG/BIM/PHUD cases are not plain touch UIs** — they require host-side input injection or a different display surface.

## Where to find IDs / selectors
Use Maestro Studio:
1) Run your flow until the target screen is visible.
2) Click **Inspect Screen** (or open the hierarchy view).
3) Click the target element on the screenshot.
4) Use the generated selector (id/text) + **index** when needed.

Example: list rows often share the same `id` and differ only by **index**.

## Running tests
### Option A — Maestro Studio (UI-only)
Run flows directly from Studio. This is best for quick iteration.

### Option B — CLI runner (recommended for artifacts + logs)
Run from repo root:
```bat
.\run_demo_suite.bat
```
This will:
- run all flows in `flows\demo`
- apply required SWAG/BIM injections (when a flow declares them)
- run backend validation (`scripts/verify_radio_state.py`)
- store output under `artifacts\runs\<timestamp>\...`

## SWAG/BIM injections
Maestro does not natively execute `adb shell cmd car_service inject-custom-input`.
So the SWAG/BIM flows declare an action comment like:
```
# ACTION: swag media-next
```
The CLI runner picks it up and performs the injection.

You can also run it manually:
```bat
scripts\run_action.bat swag media-next
scripts\run_action.bat swag media-previous
scripts\run_action.bat bim next
scripts\run_action.bat bim previous
```

## CID/PHUD toggles (EHH)
Toggles are exposed as:
```bat
scripts\run_action.bat ehh cid true
scripts\run_action.bat ehh phud true
```

Before running the demo/full suite, verify your environment:

```powershell
.\scripts\check_env.bat
```

If `maestro` is not found, either install the Maestro CLI or set the `MAESTRO_CMD` environment variable to the full path of the Maestro executable. Example (PowerShell):

```powershell
setx MAESTRO_CMD "C:\\path\\to\\maestro.exe"
```

Restart your terminal after setting `MAESTRO_CMD` and re-run `.\scripts\check_env.bat`.

## Maestro output location
By default, Maestro stores artifacts under `%USERPROFILE%\.maestro\tests\...`.
This repo includes `.maestro/config.yaml` with:
```yaml
testOutputDir: artifacts/maestro
```
so artifacts can be stored inside the repo when using the CLI (or by setting `--test-output-dir`).

## Notes
- Inline YAML scripts are avoided on this Windows setup.
- ADB validations target:
  - audio focus `pack:` contains `com.bmwgroup.apinext.tunermediaservice`
  - media session for the current Android user is active and **PLAYING**

## Quick start (Windows racks)

### 1) Set Maestro CLI (required)
Your current CLI folder (given): `%USERPROFILE%\Desktop\maestro\bin`

Run:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup_maestro.ps1
```

### 2) Install repo-local ADB (recommended)
```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_platform_tools.ps1
```

### 3) Check environment
```bat
scripts\check_env.bat
```

### 4) Run suites
- All 20 PDF demo flows (includes SWAG/BIM host-side actions + backend verification):
```bat
run_demo_suite.bat
```

- Lightning Talk subset:
```bat
run_lightning_demo.bat
```

- Core regression YAMLs:
```bat
run_suite.bat
```

Artifacts are written under `artifacts\runs\<timestamp>\demo\<flow>\` (logs + Maestro output).

### Notes
- SWAG/BIM flows rely on `# ACTION:` markers and must be executed via the runner (CLI), not just Maestro Studio.
- Speech / PHUD flows are placeholders unless your rack supports those interactions.

## Helper utilities

This repository includes `scripts/helpers.py` — a lightweight, importable utility module that centralizes common test helpers:

- `repo_root()` — returns repository root `Path`.
- `find_maestro_exe(hint=None)` — locate the Maestro CLI executable by name, hint path, or PATH.
- `read_action_tokens(flow_path)` — read `# ACTION:` token from a Maestro YAML flow.
- `run_bmw_action_safe(tokens, log_path=None, timeout_s=30, retries=1)` — execute BMW ACTION tokens in a separate process with timeout and retries; writes a simple log and returns an exit code.
- `verify_radio(package, require_focus=True, require_playing=True)` — wrapper around `scripts/verify_radio_state.py` verification function.

Demo and tests
--------------

- `scripts/helpers_demo.py` — safe, non-destructive demo showing how to import and use `scripts.helpers`.
- `scripts/helpers_test.py` — lightweight runtime checks that verify imports and module loading.
- `scripts/helpers_unit_test.py` — small unit-style tests for timeout/retry behaviors (non-destructive).

Run the demo/tests locally (no device required):

```powershell
python scripts\helpers_demo.py
python scripts\helpers_test.py
python scripts\helpers_unit_test.py
```

These utilities are intentionally conservative: device-affecting actions are executed in a subprocess with timeouts and retries so they won't hang the test runner.
