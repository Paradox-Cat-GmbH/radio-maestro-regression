@echo off
setlocal

echo Checking environment for RadioRegression

rem Check Python (prefer 'python', fallback to 'py -3')
python --version >nul 2>&1
if %ERRORLEVEL% equ 0 (
  echo [OK] python found on PATH.
) else (
  py -3 --version >nul 2>&1
  if %ERRORLEVEL% equ 0 (
    echo [OK] Python launcher 'py' found (use py -3).
  ) else (
    echo [ERROR] Python is not available on PATH and 'py' launcher not found. Install Python 3.x and add to PATH.
  )
)

rem Check ADB (system or repo-local tools)
where adb >nul 2>&1
if %ERRORLEVEL% equ 0 (
  echo [OK] adb found on PATH.
) else (
  if exist "%~dp0\..\tools\platform-tools\adb.exe" (
    echo [OK] adb found in repo tools (tools\platform-tools\adb.exe).
  ) else (
    echo [WARN] ADB not found on PATH or in repo tools. Run scripts\install_platform_tools.ps1 to install local platform-tools.
  )
)

rem Check Node.js
node --version >nul 2>&1
if %ERRORLEVEL% equ 0 (
  echo [OK] Node.js found.
) else (
  echo [WARN] Node.js not found. Install Node.js LTS for the control server.
)

rem Check Maestro CLI (allow MAESTRO_CMD override)
if defined MAESTRO_CMD (
  if exist "%MAESTRO_CMD%" (
    echo [OK] Maestro executable found at %MAESTRO_CMD%.
  ) else (
    echo [WARN] MAESTRO_CMD is set to %MAESTRO_CMD% but the file was not found. Ensure the path is correct or point to the Maestro CLI executable.
  )
) else (
  where maestro >nul 2>&1
  if %ERRORLEVEL% equ 0 (
    echo [OK] Maestro CLI found as 'maestro'.
  ) else (
    echo [WARN] Maestro CLI not found as 'maestro'. If you have Maestro Studio, locate the CLI and set MAESTRO_CMD to the CLI executable.
  )
)

echo
echo If anything critical is missing, run scripts\setup_env.bat for guidance or scripts\install_platform_tools.ps1 to install platform-tools locally.

endlocal
