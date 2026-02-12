@echo off
echo DEBUG START
echo Checking python presence...
python --version >nul 2>&1
echo AFTER_PYTHON
if %ERRORLEVEL% equ 0 (
  echo PY_OK
) else (
  echo PY_NOT_OK
)
echo DEBUG END
