@echo off
setlocal
if "%~1"=="" (
  echo Usage: %~nx0 ^<DEVICE_ID^>
  exit /b 2
)
set "DEVICE_ID=%~1"
set "JAVA_HOME=C:\Android\jbr"
set "MAESTRO_BACKEND_URL=http://127.0.0.1:4567"
set "PATH=C:\SDK\platform-tools;C:\Users\DavidErikGarciaArena\Documents\GitHub\radio-maestro-regression\tools\platform-tools;%PATH%"
echo Running Maestro for device: %DEVICE_ID%
call "C:\Users\DavidErikGarciaArena\Desktop\maestro\bin\maestro.bat" --device "%DEVICE_ID%" test flows\demo --test-output-dir artifacts\maestro_demo
endlocal
