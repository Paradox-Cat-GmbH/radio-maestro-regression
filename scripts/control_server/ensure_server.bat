@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "HOST=%MAESTRO_CONTROL_HOST%"
if not defined HOST set "HOST=127.0.0.1"
set "PORT=%MAESTRO_CONTROL_PORT%"
if not defined PORT set "PORT=4567"

for %%I in ("%~dp0..\..") do set "REPO_ROOT=%%~fI"
set "ART_DIR=%REPO_ROOT%\artifacts"
if not exist "%ART_DIR%" mkdir "%ART_DIR%"

set "LOG=%ART_DIR%\control_server.log"
set "SERVER_JS=%~dp0server.js"

rem === Resolve node.exe (Node is not always on PATH on Windows racks) ===
set "NODE_EXE=%MAESTRO_NODE_EXE%"
if defined NODE_EXE if not exist "%NODE_EXE%" set "NODE_EXE="

if not defined NODE_EXE (
  if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
)
if not defined NODE_EXE (
  if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles(x86)%\nodejs\node.exe"
)
if not defined NODE_EXE (
  for /f "delims=" %%N in ('where node 2^>nul') do (
    set "NODE_EXE=%%N"
    goto :nodeFound
  )
)
:nodeFound

if not defined NODE_EXE (
  echo [ERROR] node.exe not found.
  echo Install Node.js or set MAESTRO_NODE_EXE to the full path of node.exe
  exit /b 2
)

rem === Fast health check ===
call :health STATUS 1
if "%STATUS%"=="200" (
  echo [OK] Control server already running (%HOST%:%PORT%).
  exit /b 0
)

echo [INFO] Starting control server (%HOST%:%PORT%)...

call :startServer

rem === Wait up to 15s for health ===
for /l %%I in (1,1,15) do (
  call :health STATUS 2
  if "%STATUS%"=="200" goto :started
  timeout /t 1 /nobreak >nul
)

echo [ERROR] Control server did not start. Check "%LOG%".
exit /b 2

:started
echo [OK] Control server started.
exit /b 0

:health
set "%~1=0"
for /f "usebackq delims=" %%S in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-StrictMode -Version Latest; $h=$args[0]; $p=$args[1]; $t=[int]$args[2]; try { (Invoke-WebRequest -UseBasicParsing -Uri ('http://{0}:{1}/health' -f $h,$p) -TimeoutSec $t).StatusCode } catch { 0 }" "%HOST%" "%PORT%" "%~2"`) do set "%~1=%%S"
exit /b 0

:startServer
rem Start Node via a PowerShell background job to avoid cmd.exe quoting issues.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-StrictMode -Version Latest; $repo=$args[0]; $node=$args[1]; $js=$args[2]; $log=$args[3]; $jobName=('maestro_control_server_{0}' -f $args[4]); if (Get-Job -Name $jobName -ErrorAction SilentlyContinue) { return }; Start-Job -Name $jobName -ScriptBlock { param($repo,$node,$js,$log) Set-Location $repo; & $node $js 2>&1 | Out-File -FilePath $log -Append -Encoding utf8 } -ArgumentList $repo,$node,$js,$log | Out-Null" "%REPO_ROOT%" "%NODE_EXE%" "%SERVER_JS%" "%LOG%" "%PORT%"
exit /b 0
