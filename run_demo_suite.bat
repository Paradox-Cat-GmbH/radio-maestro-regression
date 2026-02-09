@echo off
setlocal enabledelayedexpansion

rem Runs all flows in flows\demo via Maestro CLI and stores artifacts under artifacts\runs\...
rem This is the recommended path to get deterministic logs + artifacts.

rem ---- Java / JBR setup (Android Studio embedded runtime) ----
set "JBR_BIN=C:\Android\jbr\bin"
if exist "%JBR_BIN%\java.exe" (
  rem Prefer JAVA_HOME as the JBR root (one level up from bin)
  for %%I in ("%JBR_BIN%\..") do set "JAVA_HOME=%%~fI"
  set "PATH=%JBR_BIN%;%PATH%"
) else (
  echo [WARN] JBR not found at %JBR_BIN%. If Maestro fails with Java errors, update JBR_BIN in this file.
)

rem ---- Artifacts output ----
for /f "tokens=1-3 delims=/- " %%a in ("%date%") do set D=%%c-%%a-%%b
for /f "tokens=1-2 delims=: " %%a in ("%time%") do set T=%%a%%b
set "ART_DIR=artifacts\runs\%D%_%T%"

echo Artifacts: %ART_DIR%

python scripts\run_all_demo.py --artifacts "%ART_DIR%"
set "RC=%ERRORLEVEL%"

echo Exit code: %RC%
exit /b %RC%
