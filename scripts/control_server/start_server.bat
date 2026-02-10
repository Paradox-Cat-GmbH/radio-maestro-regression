@echo off
setlocal

set "MAESTRO_CONTROL_HOST=127.0.0.1"
set "MAESTRO_CONTROL_PORT=4567"
node "%~dp0server.js"
