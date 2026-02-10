@echo off
setlocal enabledelayedexpansion

rem Runs ALL demo flows (20) in flows\demo using the Python runner.
rem Stores per-flow logs and Maestro output under artifacts\runs\<timestamp>\...

set "JBR_BIN=C:\Android\jbr\bin"
if exist "%JBR_BIN%\java.exe" (
  for %%I in ("%JBR_BIN%\..") do set "JAVA_HOME=%%~fI"
  set "PATH=%JBR_BIN%;%PATH%"
) else (
  echo [WARN] JBR not found at %JBR_BIN%. If Maestro fails with Java errors, update JBR_BIN.
)

for /f "tokens=1-3 delims=/- " %%a in ("%date%") do set D=%%c-%%a-%%b
for /f "tokens=1-2 delims=: " %%a in ("%time%") do set T=%%a%%b
set "ART_DIR=artifacts\runs\%D%_%T%"

echo Artifacts: %ART_DIR%
python scripts\run_all_demo.py --artifacts "%ART_DIR%"
exit /b %ERRORLEVEL%
