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
rem   run_action.bat ediabas-str --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --str-seconds 180
rem   run_action.bat ediabas-str-js --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --str-seconds 180
rem   run_action.bat ediabas-str-js-api --ediabas-bin "C:\EC-Apps\EDIABAS\BIN" --str-seconds 180
rem   run_action.bat ediabas-str-js-sidecar --str-seconds 180
rem
if "%~1"=="" (
  echo Usage: %~nx0 ^<swag^|bim^|workaround^|ehh^|ediabas-str^|ediabas-str-js^|ediabas-str-js-api^|ediabas-str-js-sidecar^> [args]
  exit /b 1
)

set CMD=%~1
shift

if /I "%CMD%"=="ediabas-str" (
  python "%~dp0ediabas_str_cycle.py" %*
  exit /b %ERRORLEVEL%
)

if /I "%CMD%"=="ediabas-str-js" (
  node "%~dp0ediabas_str_cycle.js" %*
  exit /b %ERRORLEVEL%
)

if /I "%CMD%"=="ediabas-str-js-api" (
  node "%~dp0ediabas_str_cycle_api.js" %*
  exit /b %ERRORLEVEL%
)

if /I "%CMD%"=="ediabas-str-js-sidecar" (
  node "%~dp0ediabas_str_cycle_sidecar.js" %*
  exit /b %ERRORLEVEL%
)

python "%~dp0bmw_controls.py" %CMD% %*
exit /b %ERRORLEVEL%
