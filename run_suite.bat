@echo off
setlocal enabledelayedexpansion

rem === Java (JBR) - preferred ===
set "JBR_BIN=C:\Android\jbr\bin"
if exist "%JBR_BIN%\java.exe" (
  for %%I in ("%JBR_BIN%\..") do set "JAVA_HOME=%%~fI"
  set "PATH=%JBR_BIN%;%PATH%"
)

rem === Determine device ===
set "DEVICE_ID=%~1"
if "%DEVICE_ID%"=="" (
  if not "%ANDROID_SERIAL%"=="" (
    set "DEVICE_ID=%ANDROID_SERIAL%"
  ) else (
    for /f "skip=1 tokens=1,2" %%A in ('scripts\adb.bat devices') do (
      if "%%B"=="device" (
        set "DEVICE_ID=%%A"
        goto :gotDevice
      )
    )
    :gotDevice
  )
)

if "%DEVICE_ID%"=="" (
  echo [ERROR] No device found. Provide one:
  echo   %~nx0 ^<DEVICE_ID^>
  echo Or set ANDROID_SERIAL.
  exit /b 2
)

set "ANDROID_SERIAL=%DEVICE_ID%"

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
set "ART_DIR=artifacts\runs\%TS%"
if not exist "%ART_DIR%" mkdir "%ART_DIR%"
for %%P in ("%CD%\%ART_DIR%") do set "MAESTRO_RUN_DIR=%%~fP"

rem === Control server + backend vars ===
set "MAESTRO_CONTROL_HOST=127.0.0.1"
set "MAESTRO_CONTROL_PORT=4567"
set "MAESTRO_BACKEND_URL=http://127.0.0.1:4567"
set "MAESTRO_RADIO_PACKAGE=com.bmwgroup.apinext.tunermediaservice"
if "%MAESTRO_RAND_MAX_INDEX%"=="" set "MAESTRO_RAND_MAX_INDEX=3"

call scripts\control_server\ensure_server.bat
if errorlevel 1 exit /b %ERRORLEVEL%

rem === Detect optional Maestro flags ===
set "USE_DEVICE_FLAG=0"
"%MAESTRO_EXE%" --help 2>&1 | findstr /C:"--device" >nul && set "USE_DEVICE_FLAG=1"


echo [INFO] Device: %DEVICE_ID%
echo [INFO] Maestro: %MAESTRO_EXE%
echo [INFO] Artifacts: %ART_DIR%

set "OUT_DIR=%ART_DIR%\maestro_regression"
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

if "%USE_DEVICE_FLAG%"=="1" (
  "%MAESTRO_EXE%" --device "%DEVICE_ID%" test flows\regression --test-output-dir "%OUT_DIR%"
) else (
  "%MAESTRO_EXE%" test flows\regression --test-output-dir "%OUT_DIR%"
)

exit /b %ERRORLEVEL%
