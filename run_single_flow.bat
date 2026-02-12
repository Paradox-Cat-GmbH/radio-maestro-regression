@echo off
setlocal enabledelayedexpansion

rem Usage:
rem   run_single_flow.bat <DEVICE_ID> <FLOW_PATH>
rem Example:
rem   run_single_flow.bat 169.254.107.117:5555 flows\demo\IDCEVODEV-478199__all_stations_select.yaml

set "DEVICE_ID=%~1"
set "FLOW=%~2"

if "%DEVICE_ID%"=="" (
  echo [ERROR] Missing DEVICE_ID.
  echo Usage: %~nx0 ^<DEVICE_ID^> ^<FLOW_PATH^>
  exit /b 2
)
if "%FLOW%"=="" (
  echo [ERROR] Missing FLOW_PATH.
  echo Usage: %~nx0 ^<DEVICE_ID^> ^<FLOW_PATH^>
  exit /b 2
)

set "ANDROID_SERIAL=%DEVICE_ID%"

rem === Java (JBR) - preferred ===
set "JBR_BIN=C:\Android\jbr\bin"
if exist "%JBR_BIN%\java.exe" (
  for %%I in ("%JBR_BIN%\..") do set "JAVA_HOME=%%~fI"
  set "PATH=%JBR_BIN%;!PATH!"
)

rem === Maestro CLI discovery ===
set "MAESTRO_EXE=%MAESTRO_CMD%"
if "%MAESTRO_EXE%"=="" (
  if exist "%USERPROFILE%\Desktop\maestro\bin\maestro.exe" set "MAESTRO_EXE=%USERPROFILE%\Desktop\maestro\bin\maestro.exe"
  if "%MAESTRO_EXE%"=="" if exist "%USERPROFILE%\Desktop\maestro\bin\maestro.cmd" set "MAESTRO_EXE=%USERPROFILE%\Desktop\maestro\bin\maestro.cmd"
  if "%MAESTRO_EXE%"=="" if exist "%USERPROFILE%\Desktop\maestro\bin\maestro.bat" set "MAESTRO_EXE=%USERPROFILE%\Desktop\maestro\bin\maestro.bat"
)
if "%MAESTRO_EXE%"=="" (
  for /f "delims=" %%M in ('where maestro 2^>nul') do (
    set "MAESTRO_EXE=%%M"
    goto :gotMaestro
  )
)
:gotMaestro

if "%MAESTRO_EXE%"=="" (
  echo [ERROR] Maestro CLI not found. Set MAESTRO_CMD or install Maestro.
  exit /b 2
)

rem === Timestamped artifacts dir ===
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
set "ART_DIR=artifacts\debug_single_flow\%TS%"
if not exist "%ART_DIR%" mkdir "%ART_DIR%"
for %%P in ("%CD%\%ART_DIR%") do set "MAESTRO_RUN_DIR=%%~fP"

rem === Control server + backend vars ===
set "MAESTRO_CONTROL_HOST=127.0.0.1"
set "MAESTRO_CONTROL_PORT=4567"
set "MAESTRO_BACKEND_URL=http://127.0.0.1:4567"
set "MAESTRO_RADIO_PACKAGE=com.bmwgroup.apinext.tunermediaservice"

call scripts\control_server\ensure_server.bat
if errorlevel 1 exit /b %ERRORLEVEL%

rem === Ensure UTF-8 for Java and console ===
chcp 65001 >nul
if "%JAVA_TOOL_OPTIONS%"=="" set "JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8"

rem === ADB preflight (best-effort) ===
echo %DEVICE_ID% | findstr /C:":" >nul && call scripts\adb.bat connect %DEVICE_ID% >nul 2>&1
call scripts\adb.bat -s %DEVICE_ID% root >nul 2>&1
timeout /t 1 >nul
call scripts\adb.bat -s %DEVICE_ID% forward tcp:7001 tcp:7001 >nul 2>&1

echo [INFO] Device: %DEVICE_ID%
echo [INFO] Maestro: %MAESTRO_EXE%
echo [INFO] Flow: %FLOW%
echo [INFO] Artifacts: %ART_DIR%

set "OUT_DIR=%ART_DIR%\maestro_single"
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

rem === Detect optional Maestro flags ===
set "USE_DEVICE_FLAG=0"
"%MAESTRO_EXE%" --help 2>&1 | findstr /C:"--device" >nul && set "USE_DEVICE_FLAG=1"

if "%USE_DEVICE_FLAG%"=="1" (
  "%MAESTRO_EXE%" --device "%DEVICE_ID%" test "%FLOW%" --test-output-dir "%OUT_DIR%"
) else (
  "%MAESTRO_EXE%" test "%FLOW%" --test-output-dir "%OUT_DIR%"
)

exit /b %ERRORLEVEL%
