@echo off
setlocal

set "DEVICE_ID=%~1"
set "MAESTRO_GLOBAL_PRECONDITIONS_ENABLED=true"
set "MAESTRO_PREP_REBOOT=true"
set "MAESTRO_PREP_POST_REBOOT_DELAY_SECONDS=35"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\maestro\run_with_artifacts.ps1 -DeviceId "%DEVICE_ID%" -Target "flows\regression"
exit /b %ERRORLEVEL%
