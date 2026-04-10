# IDC23 Selector Workflow

Use Maestro CLI hierarchy export as the primary selector-discovery path for IDC23.

## Why

- IDC23 is not a drop-in selector match for IDCEvo or G70.
- Maestro CLI exposes full visible hierarchy data in a machine-readable form.
- This is more reliable for bulk mapping than copying Studio short labels or relying on ad-hoc ADB/UIAutomator-only dumps.

## Preferred commands

```powershell
maestro --device 169.254.8.177:5555 hierarchy
maestro --device 169.254.8.177:5555 hierarchy --compact
maestro --device 169.254.8.177:5555 query id=statusbar_title
maestro --device 169.254.8.177:5555 query text="All stations"
```

`hierarchy --compact` is the bulk-mapping command. It emits CSV rows with:
- `element_num`
- `depth`
- `attributes`
- `parent_num`

## Repo helper

```powershell
.\scripts\idc23_capture_hierarchy.ps1 -DeviceId "169.254.8.177:5555" -Label "screen_name"
```

This capture bundle includes:
- Maestro hierarchy text export
- Maestro hierarchy compact CSV export
- screenshot
- XML dump
- dumpsys summary

## Mapping rules

- Prefer full Android resource IDs from hierarchy export, for example `com.bmwgroup.apinext.mediaapp:id/item_arrow`.
- Treat Studio short IDs as hints, not final selectors.
- Use text, coordinates, or index only when there is no stable resource ID.
- Validate selectors against the actual IDC23 screen state from the testcase, not by inheritance from G70 or IDCEvo.

## Connection baseline

Before Studio runs or hierarchy capture:

```powershell
adb kill-server
adb start-server
adb connect 169.254.8.177:5555
adb -s 169.254.8.177:5555 forward --remove-all
adb -s 169.254.8.177:5555 reverse --remove-all
```

Important:
- do not manually pre-create `tcp:7001 -> tcp:7001`
- let Maestro allocate forwarding itself
- stale forwards/reverses are a confirmed activation failure source

## Current baseline artifacts

- Latest compact export: `artifacts/maestro_hierarchy_compact_latest.csv`
- Local per-screen notes: `artifacts/idc23_ui_map/manual_selector_inventory_20260309.md`

## Known IDC23 selector example

For DAB All Stations:
- legacy selector: `ListImageComponent ImageRightIcon`
- IDC23 selector: `com.bmwgroup.apinext.mediaapp:id/item_arrow`
