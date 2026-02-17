@echo off
setlocal

set "DEVICE_ID=%~1"
set "FLOW=%~2"

if "%FLOW%"=="" (
  echo [ERROR] Missing FLOW_PATH.
  echo Usage: %~nx0 ^<DEVICE_ID^> ^<FLOW_PATH^>
  echo Example: %~nx0 169.254.107.117:5555 flows\demo\IDCEVODEV-478199__all_stations_select.yaml
  exit /b 2
)

powershell -NoProfile -ExecutionPolicy Bypass -File scripts\maestro\run_with_artifacts.ps1 -DeviceId "%DEVICE_ID%" -Target "%FLOW%"
exit /b %ERRORLEVEL%
