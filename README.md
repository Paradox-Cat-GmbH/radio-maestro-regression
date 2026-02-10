# RadioRegression (Maestro) + ADB Truth (JS-first)

## What this repo is
A practical Maestro-based UI regression suite for BMW iDrive / AAOS **Radio**, with **ADB truth validation** to avoid “UI lies”.

**Default execution path (supported):**
- Maestro YAML flows drive UI
- Maestro **JavaScript** triggers host-side ADB operations via a tiny **Node control server**
- ADB truth checks and dumps are written next to Maestro artifacts per run

**Legacy (kept for reference / future):**
- Python runners and validators remain under `scripts/` but are not used by the default runners anymore.

---

## Terminology (BMW-specific)
- **CID**: Central Information Display (main center screen)
- **PHUD**: secondary surface / passenger HUD (multi-display)
- **SWAG**: steering wheel input path (MFL controls)
- **BIM**: center console/button input path (non-touch hardware input)
- **Superstack / mini player / fullscreen player**: UI surfaces you can typically tap (Maestro)

---

## Requirements (rack host)
- **Maestro CLI** (author with Studio, run via CLI)
- **Node.js (LTS)** (for the host control server)
- **ADB** (repo-local is preferred via `scripts\install_platform_tools.ps1`)
- **Java**: use Android Studio embedded **JBR** at `C:\Android\jbr\bin` (runners prefer it)

---

## How it works (professional, reliable path)

### 1) Control server (host-side)
`scripts\control_server\server.js` exposes HTTP endpoints that run ADB commands:
- `/radio/check` → dumpsys audio + media_session + current user, parses, returns verdict
- `/inject/swag` → Leandro workaround (car_service inject 1014/1015 + keyevent next/prev)
- `/inject/bim` → KEYCODE_MUTE + same workaround (best-effort, can be adjusted)
- `/ehh/set` → CID/PHUD EHH toggles via setprop

The runners start it automatically via:
`scripts\control_server\ensure_server.bat`

Logs: `artifacts\control_server.log`

### 2) Maestro flows
All `flows\demo\*.yaml`:
- set `output.testId`
- perform UI actions
- (HW tests) call SWAG/BIM injection subflows
- call `flows\subflows\verify_radio_backend.yaml` to enforce ADB truth + dump evidence

Random station coverage:
- `flows\subflows\tune_any_station.yaml` selects a **random station row** (bounded by `MAESTRO_RAND_MAX_INDEX`, default `3`)

---

## Running

### A) Install repo-local platform-tools (recommended)
```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_platform_tools.ps1
scripts\adb.bat devices -l
```

### B) Run all 20 demo tests
Pass a device id (recommended) or rely on `ANDROID_SERIAL`.

```bat
run_demo_suite.bat <DEVICE_ID>
```

Example:
```bat
run_demo_suite.bat 169.254.20.77:5555
```

Outputs:
- Maestro output: `artifacts\runs\<timestamp>\maestro_demo\...`
- ADB truth dumps: `artifacts\runs\<timestamp>\backend\<testId>\...`
  - `dumpsys_audio.txt`
  - `dumpsys_media_session.txt`
  - `current_user.txt`
  - `backend_verdict.json`
  - `action_*.json` (for HW injections)

### C) Lightning subset (presentation order)
```bat
run_lightning_demo.bat <DEVICE_ID>
```

### D) Regression group flows
```bat
run_suite.bat <DEVICE_ID>
```

---

## Config knobs (env vars)
- `ANDROID_SERIAL` — device selection (preferred)
- `MAESTRO_CMD` — optional explicit Maestro CLI path
- `MAESTRO_RAND_MAX_INDEX` — max random station row index (default `3`)
- `MAESTRO_CONTROL_PORT` — control server port (default `4567`)

---

## Known limits (what still needs rack confirmation)
- **PHUD station list SWAG selection** is tagged `manual` until SWAG nav/center keycodes are confirmed for that surface.
- Media metadata availability varies by build; if session does not expose “station title”, “station changed” checks may be limited to “radio still playing”.

---

## Legacy (kept)
The previous Python-based workflow remains in `scripts\`:
- `run_flow_with_actions.py`, `verify_radio_state.py`, etc.
Not used by default runners, but kept as reference / fallback.
