@echo off
setlocal EnableExtensions

set "HOST=%MAESTRO_CONTROL_HOST%"
if not defined HOST set "HOST=127.0.0.1"
set "PORT=%MAESTRO_CONTROL_PORT%"
if not defined PORT set "PORT=4567"

for %%I in ("%~dp0..\..") do set "REPO_ROOT=%%~fI"
set "ART_DIR=%REPO_ROOT%\artifacts"
if not exist "%ART_DIR%" mkdir "%ART_DIR%"

set "LOG=%ART_DIR%\control_server.log"
set "SERVER_JS=%~dp0server.js"

set "NODE_EXE=%MAESTRO_NODE_EXE%"
if defined NODE_EXE if not exist "%NODE_EXE%" set "NODE_EXE="

if not defined NODE_EXE if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
if not defined NODE_EXE if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles(x86)%\nodejs\node.exe"
if not defined NODE_EXE (
  for /f "delims=" %%N in ('where node 2^>nul') do (
    set "NODE_EXE=%%N"
    goto :nodeFound
  )
)

:nodeFound
if not defined NODE_EXE (
  echo [ERROR] node.exe not found.
  echo Install Node.js or set MAESTRO_NODE_EXE to full path.
  exit /b 2
)

call :health STATUS 2
if "%STATUS%"=="200" (
  echo [OK] Control server already running - %HOST%:%PORT%
  exit /b 0
)

echo [INFO] Starting control server (%HOST%:%PORT%)...
start "" /b cmd /c "\"%NODE_EXE%\" \"%SERVER_JS%\" >> \"%LOG%\" 2>&1"

for /l %%I in (1,1,15) do (
  call :health STATUS 2
  if "%STATUS%"=="200" (
    echo [OK] Control server started.
    exit /b 0
  )
  timeout /t 1 /nobreak >nul
)

echo [ERROR] Control server did not start. Check "%LOG%".
exit /b 2

:health
set "%~1=0"
for /f "usebackq delims=" %%S in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "try { (Invoke-WebRequest -UseBasicParsing -Uri 'http://%HOST%:%PORT%/health' -TimeoutSec %~2).StatusCode } catch { 0 }"`) do set "%~1=%%S"
exit /b 0
