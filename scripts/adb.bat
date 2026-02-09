@echo off
REM Wrapper to invoke repo-local adb if present, otherwise forward to system adb
setlocal
set "REPO_ADB=%~dp0..\tools\platform-tools\adb.exe"
if exist "%REPO_ADB%" (
  "%REPO_ADB%" %*
) else (
  adb %*
)
endlocal
