@echo off
setlocal

echo Checking environment for RadioRegression

rem Check Python
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 goto python_fail
echo [OK] Python found.
goto python_done
:python_fail
echo [ERROR] Python is not available on PATH. Install Python 3.x and add to PATH.
:python_done

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
