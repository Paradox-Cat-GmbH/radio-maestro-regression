@echo off
setlocal

set "DEVICE_ID=%~1"

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\maestro\run_with_artifacts.ps1 -DeviceId "%DEVICE_ID%" -FlowList "flows\demo\IDCEVODEV-478199__all_stations_select.yaml" "flows\demo\IDCEVODEV-478229__search_select_station.yaml" "flows\demo\IDCEVODEV-478202__miniplayer_skip_next.yaml" "flows\demo\IDCEVODEV-478210__swag_skip_next.yaml" "flows\demo\IDCEVODEV-478205__bim_skip_next.yaml"

exit /b %ERRORLEVEL%
