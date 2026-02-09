@echo off
setlocal enabledelayedexpansion

REM Runs the ADB-based radio backend validation.
REM Returns ERRORLEVEL 0 on PASS, 1 on FAIL.

set SCRIPT_DIR=%~dp0
set PY=%SCRIPT_DIR%verify_radio_state.py

REM Expected active media package for Radio
set RADIO_PKG=com.bmwgroup.apinext.tunermediaservice

python "%PY%" --package "%RADIO_PKG%" --require-focus --require-playing
exit /b %ERRORLEVEL%
