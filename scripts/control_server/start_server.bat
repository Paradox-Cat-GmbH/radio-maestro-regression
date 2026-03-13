@echo off
setlocal

set "MAESTRO_CONTROL_HOST=127.0.0.1"
set "MAESTRO_CONTROL_PORT=4567"
set "ADB_EXE=C:\Android\SDK\platform-tools\adb.exe"
if not exist "%ADB_EXE%" set "ADB_EXE=%~dp0..\..\tools\platform-tools\adb.exe"
if not defined DLT_RECEIVE_BIN if exist "C:\Tools\dlt\dlt-receive.exe" set "DLT_RECEIVE_BIN=C:\Tools\dlt\dlt-receive.exe"
if not defined DLT_RECEIVE_BIN if exist "C:\Tools\dlt\dlt-receive-v2.exe" set "DLT_RECEIVE_BIN=C:\Tools\dlt\dlt-receive-v2.exe"
node "%~dp0server.js"
