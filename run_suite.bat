@echo off
setlocal enabledelayedexpansion

REM ===============================================
REM RadioRegression - demo runner (Windows)
REM Runs 5 demo flows sequentially and validates Radio backend after each.
REM ===============================================

REM 1) Ensure JAVA_HOME (Android Studio embedded JBR)
REM Adjust this path if Android Studio is installed elsewhere.
set "JAVA_HOME=C:\Android\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"

REM 2) Workspace root
set "ROOT=%~dp0"
cd /d "%ROOT%"

REM 3) Demo flows (order matters for presentation)
set FLOWS[1]=flows\demo\IDCEVODEV-478199__all_stations_select.yaml
set FLOWS[2]=flows\demo\IDCEVODEV-478229__search_select_station.yaml
set FLOWS[3]=flows\demo\IDCEVODEV-478202__miniplayer_skip_next.yaml
set FLOWS[4]=flows\demo\IDCEVODEV-478204__miniplayer_skip_prev.yaml
set FLOWS[5]=flows\demo\IDCEVODEV-486497__fullscreen_skip_next.yaml

set COUNT=5

echo === Running RadioRegression demo suite ===
for /L %%i in (1,1,%COUNT%) do (
  call :run_one "!FLOWS[%%i]!"
  if errorlevel 1 exit /b 1
)

echo === ALL DEMO TESTS PASSED ===
exit /b 0

:run_one
set "FLOW=%~1"
echo.
echo ------------------------------------------------------------
echo [RUN] %FLOW%
echo ------------------------------------------------------------
maestro test "%FLOW%"
if errorlevel 1 (
  echo [FAIL] Maestro flow failed: %FLOW%
  exit /b 1
)

REM Backend validation (ADB)
call scripts\run_check.bat
if errorlevel 1 (
  echo [FAIL] Backend validation failed after: %FLOW%
  exit /b 1
)

echo [OK] %FLOW%
exit /b 0
@echo off
setlocal enabledelayedexpansion

REM ===============================================
REM RadioRegression - demo runner (Windows)
REM Runs 5 demo flows sequentially and validates Radio backend after each.
REM ===============================================

REM 1) Ensure JAVA_HOME (Android Studio embedded JBR)
REM Adjust this path if Android Studio is installed elsewhere.
set "JAVA_HOME=C:\Android\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"

REM 2) Workspace root
set "ROOT=%~dp0"
cd /d "%ROOT%"

REM 3) Demo flows (order matters for presentation)
set FLOWS[1]=flows\demo\IDCEVODEV-478199__all_stations_select.yaml
set FLOWS[2]=flows\demo\IDCEVODEV-478229__search_select_station.yaml
set FLOWS[3]=flows\demo\IDCEVODEV-478202__miniplayer_skip_next.yaml
set FLOWS[4]=flows\demo\IDCEVODEV-478204__miniplayer_skip_prev.yaml
set FLOWS[5]=flows\demo\IDCEVODEV-486497__fullscreen_skip_next.yaml

set COUNT=5

echo === Running RadioRegression demo suite ===
for /L %%i in (1,1,%COUNT%) do (
  call :run_one "!FLOWS[%%i]!"
  if errorlevel 1 exit /b 1
)

echo === ALL DEMO TESTS PASSED ===
exit /b 0

:run_one
set "FLOW=%~1"
echo.
echo ------------------------------------------------------------
echo [RUN] %FLOW%
echo ------------------------------------------------------------
maestro test "%FLOW%"
if errorlevel 1 (
  echo [FAIL] Maestro flow failed: %FLOW%
  exit /b 1
)

REM Backend validation (ADB)
call scripts\run_check.bat
if errorlevel 1 (
  echo [FAIL] Backend validation failed after: %FLOW%
  exit /b 1
)

echo [OK] %FLOW%
exit /b 0
