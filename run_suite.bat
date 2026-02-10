@echo off
setlocal enabledelayedexpansion

rem Runs core regression flows in flows\regression (UI-only + backend validation).

set "JBR_BIN=C:\Android\jbr\bin"
if exist "%JBR_BIN%\java.exe" (
  for %%I in ("%JBR_BIN%\..") do set "JAVA_HOME=%%~fI"
  set "PATH=%JBR_BIN%;%PATH%"
)

for /f "tokens=1-3 delims=/- " %%a in ("%date%") do set D=%%c-%%a-%%b
for /f "tokens=1-2 delims=: " %%a in ("%time%") do set T=%%a%%b
set "ART_DIR=artifacts\runs\%D%_%T%"

echo Artifacts: %ART_DIR%

python scripts\run_flow_with_actions.py flows\regression\radio_selection.yaml --artifacts "%ART_DIR%" --no-action
if errorlevel 1 exit /b %ERRORLEVEL%
python scripts\run_flow_with_actions.py flows\regression\radio_search.yaml --artifacts "%ART_DIR%" --no-action
if errorlevel 1 exit /b %ERRORLEVEL%
python scripts\run_flow_with_actions.py flows\regression\radio_favorites.yaml --artifacts "%ART_DIR%" --no-action
exit /b %ERRORLEVEL%
