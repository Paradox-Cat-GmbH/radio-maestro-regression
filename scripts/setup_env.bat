@echo off
echo Setup hints for RadioRegression environment (Windows)
echo.
echo 1) Python 3.x
echo    - Install from https://www.python.org/downloads/ and select 'Add to PATH'.
echo.
echo 2) Android adb (Platform Tools)
echo    - Download: https://developer.android.com/studio/releases/platform-tools
echo    - Unzip and add the folder containing 'adb.exe' to your PATH system/user environment variable.
echo.
echo 3) Maestro CLI
echo    - If you have Maestro Studio, install the CLI plugin or locate the CLI executable.
echo    - If the CLI is not on PATH, set an environment variable `MAESTRO_CMD` pointing to the executable:
echo        setx MAESTRO_CMD "C:\\path\\to\\maestro.exe"
echo    - Restart your terminal after `setx`.
echo.
echo 4) Verify environment using scripts\check_env.bat
echo    .\scripts\check_env.bat
