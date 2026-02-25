@echo off
setlocal

set "MAESTRO_CONTROL_HOST=127.0.0.1"
set "MAESTRO_CONTROL_PORT=4567"
set "ADB_EXE=%~dp0..\..\tools\platform-tools\adb.exe"
node "%~dp0server.js"
