@echo off
setlocal enabledelayedexpansion

rem Detect first connected device that's in 'device' state
set "DEVICE_ID="
for /f "skip=1 tokens=1,2" %%A in ('scripts\adb.bat devices') do (
  if "%%B"=="device" (
    set "DEVICE_ID=%%A"
    goto :gotDevice
  )
)
:gotDevice
if "%DEVICE_ID%"=="" (
  echo [ERROR] No device detected. Connect a device and try again.
  exit /b 2
)

rem Sanitize device id (strip question marks or other problematic chars)
set "DEVICE_ID_SANI=%DEVICE_ID:?=%"
echo [INFO] Using device: %DEVICE_ID_SANI%

call "%~dp0\..\run_demo_suite.bat" %DEVICE_ID_SANI%
