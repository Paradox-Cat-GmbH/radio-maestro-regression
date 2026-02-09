<#
Download and extract Android Platform Tools (Windows) into repo-local tools/platform-tools.
This does NOT modify system PATH. After running, use scripts\adb.bat to invoke adb from the local tools.
#>

$out = Join-Path $PSScriptRoot "..\tools\platform-tools"
$zip = Join-Path $PSScriptRoot "platform-tools-latest.zip"
$out = Join-Path $PSScriptRoot "..\tools\platform-tools"
$zip = Join-Path $PSScriptRoot "platform-tools-latest.zip"

Write-Host "Installing platform-tools to: $out"

$url = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'

if (Test-Path $out) {
    Write-Host "Platform-tools already exist at $out. Remove the folder to reinstall."
    <#
    Download and extract Android Platform Tools (Windows) into repo-local tools/platform-tools.
    This does NOT modify system PATH. After running, use scripts\adb.bat to invoke adb from the local tools.
    #>

    param()

    $out = Join-Path $PSScriptRoot "..\tools\platform-tools"
    $zip = Join-Path $PSScriptRoot "platform-tools-latest.zip"

    Write-Host "Installing platform-tools to: $out"

    $url = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'

    if (Test-Path $out) {
        Write-Host "Platform-tools already exist at $out. Remove the folder to reinstall."
        exit 0
    }

    Write-Host "Downloading platform-tools..."
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

    Write-Host "Extracting..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $PSScriptRoot ".."))

    Remove-Item $zip -Force

    Write-Host "Creating scripts\adb.bat wrapper..."
    $wrapper = Join-Path $PSScriptRoot "adb.bat"
    $toolsAdb = Join-Path $PSScriptRoot "..\tools\platform-tools\adb.exe"
    "@echo off" | Out-File -FilePath $wrapper -Encoding ASCII
    "%~dp0\..\tools\platform-tools\adb.exe %*" | Out-File -FilePath $wrapper -Encoding ASCII -Append

    Write-Host "Done. Use .\scripts\adb.bat to run adb from the repo-local platform-tools."
