@echo off
setlocal enabledelayedexpansion

set "HOST=%MAESTRO_CONTROL_HOST%"
if "%HOST%"=="" set "HOST=127.0.0.1"
set "PORT=%MAESTRO_CONTROL_PORT%"
if "%PORT%"=="" set "PORT=4567"

rem Check if server is already healthy
for /f %%S in ('powershell -NoProfile -Command "try { (Invoke-WebRequest -UseBasicParsing http://%HOST%:%PORT%/health -TimeoutSec 1).StatusCode } catch { 0 }"') do set "STATUS=%%S"

if "%STATUS%"=="200" (
  echo [OK] Control server already running (%HOST%:%PORT%).
  exit /b 0
)

echo [INFO] Starting control server (%HOST%:%PORT%)...
set "LOG=%~dp0\..\..\artifacts\control_server.log"
if not exist "%~dp0\..\..\artifacts" mkdir "%~dp0\..\..\artifacts"

start "radio-control-server" /min cmd /c node "%~dp0server.js" 1>> "%LOG%" 2>&1

rem Wait a moment then re-check
timeout /t 1 >nul
for /f %%S in ('powershell -NoProfile -Command "try { (Invoke-WebRequest -UseBasicParsing http://%HOST%:%PORT%/health -TimeoutSec 2).StatusCode } catch { 0 }"') do set "STATUS2=%%S"

if "%STATUS2%"=="200" (
  echo [OK] Control server started.
  exit /b 0
)

echo [ERROR] Control server did not start. Check artifacts\control_server.log
exit /b 2
