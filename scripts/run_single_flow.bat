@echo off
setlocal enabledelayedexpansion
set "JAVA_HOME=C:\Android\jbr"
set "PATH=C:\Android\jbr\bin;!PATH!"
"C:\Users\DavidErikGarciaArena\Desktop\maestro\bin\maestro.bat" --device "%~1" test "%~2" --test-output-dir "%~3"
exit /b %ERRORLEVEL%
