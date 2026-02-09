@echo off
setlocal enabledelayedexpansion

rem Wrapper to run BMW input helpers from Windows.
rem Usage examples:
rem   run_action.bat swag media-next
rem   run_action.bat swag media-previous
rem   run_action.bat bim next
rem   run_action.bat bim previous
rem   run_action.bat workaround next
rem   run_action.bat ehh cid true
rem
if "%~1"=="" (
  echo Usage: %~nx0 ^<swag^|bim^|workaround^|ehh^> [args]
  exit /b 1
)

set CMD=%~1
shift

python "%~dp0bmw_controls.py" %CMD% %*
exit /b %ERRORLEVEL%
