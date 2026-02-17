@echo off
setlocal

set "DEVICE_ID=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\maestro\run_with_artifacts.ps1 -DeviceId "%DEVICE_ID%" -Target "flows\regression"
exit /b %ERRORLEVEL%
