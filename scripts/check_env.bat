@echo off
setlocal

echo Checking environment for RadioRegression

rem Check Python
python --version >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Python is not available on PATH. Install Python 3.x and add to PATH.
) else (
  echo [OK] Python found.
)

rem Check ADB
where adb >nul 2>&1
if errorlevel 1 (
  echo [WARN] ADB not found on PATH. Install Android Platform Tools and add adb to PATH.
) else (
  echo [OK] adb found.
)

rem Check Maestro CLI (allow MAESTRO_CMD override)
if defined MAESTRO_CMD (
  where %MAESTRO_CMD% >nul 2>&1
  if errorlevel 1 (
    echo [WARN] MAESTRO_CMD is set to %MAESTRO_CMD% but executable was not found in PATH.
  ) else (
    echo [OK] Maestro executable (%MAESTRO_CMD%) found.
  )
) else (
  where maestro >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Maestro CLI not found as 'maestro'. If you use Maestro Studio, install the CLI or set MAESTRO_CMD to the full path to the executable.
  ) else (
    echo [OK] Maestro CLI found as 'maestro'.
  )
)

echo
echo If anything critical is missing, run scripts\setup_env.bat for guidance.

endlocal
