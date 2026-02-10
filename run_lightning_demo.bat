@echo off
setlocal enabledelayedexpansion

rem Lightning Talk subset (safe + visual). Adjust order as desired.

set "JBR_BIN=C:\Android\jbr\bin"
if exist "%JBR_BIN%\java.exe" (
  for %%I in ("%JBR_BIN%\..") do set "JAVA_HOME=%%~fI"
  set "PATH=%JBR_BIN%;%PATH%"
)

for /f "tokens=1-3 delims=/- " %%a in ("%date%") do set D=%%c-%%a-%%b
for /f "tokens=1-2 delims=: " %%a in ("%time%") do set T=%%a%%b
set "ART_DIR=artifacts\runs\%D%_%T%"

echo Artifacts: %ART_DIR%

python scripts\run_flow_with_actions.py flows\demo\IDCEVODEV-478199__all_stations_select.yaml --artifacts "%ART_DIR%"
if errorlevel 1 exit /b %ERRORLEVEL%
python scripts\run_flow_with_actions.py flows\demo\IDCEVODEV-478229__search_select_station.yaml --artifacts "%ART_DIR%"
if errorlevel 1 exit /b %ERRORLEVEL%
python scripts\run_flow_with_actions.py flows\demo\IDCEVODEV-478202__miniplayer_skip_next.yaml --artifacts "%ART_DIR%"
if errorlevel 1 exit /b %ERRORLEVEL%
python scripts\run_flow_with_actions.py flows\demo\IDCEVODEV-478210__swag_skip_next.yaml --artifacts "%ART_DIR%"
if errorlevel 1 exit /b %ERRORLEVEL%
python scripts\run_flow_with_actions.py flows\demo\IDCEVODEV-478205__bim_skip_next.yaml --artifacts "%ART_DIR%"
exit /b %ERRORLEVEL%
