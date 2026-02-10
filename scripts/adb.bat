@echo off
setlocal

set "ADB_LOCAL=%~dp0\..\tools\platform-tools\adb.exe"
if exist "%ADB_LOCAL%" (
  "%ADB_LOCAL%" %*
  exit /b %ERRORLEVEL%
)

rem Fallback to system adb if local platform-tools not installed
where adb >nul 2>&1
if %ERRORLEVEL%==0 (
  adb %*
  exit /b %ERRORLEVEL%
)

echo [ERROR] adb not found. Install platform-tools locally:
echo   powershell -ExecutionPolicy Bypass -File scripts\install_platform_tools.ps1
exit /b 2
