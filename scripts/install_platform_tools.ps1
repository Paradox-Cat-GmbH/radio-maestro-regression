<#
Installs Android Platform Tools (Windows) into repo-local tools/platform-tools.

Usage (PowerShell):
  powershell -ExecutionPolicy Bypass -File scripts\install_platform_tools.ps1

Afterwards:
  scripts\adb.bat version
#>

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$toolsDir = Join-Path $repoRoot "tools"
$outDir   = Join-Path $toolsDir "platform-tools"
$tmpZip   = Join-Path $PSScriptRoot "platform-tools-latest-windows.zip"
$url      = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

Write-Host "Repo root: $repoRoot"
Write-Host "Install dir: $outDir"

if (Test-Path $outDir) {
    Write-Host "platform-tools already present at $outDir"
    exit 0
}

New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null

Write-Host "Downloading platform-tools..."
Invoke-WebRequest -Uri $url -OutFile $tmpZip -UseBasicParsing

Write-Host "Extracting..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($tmpZip, $toolsDir)

Remove-Item $tmpZip -Force

$adbExe = Join-Path $outDir "adb.exe"
if (-not (Test-Path $adbExe)) {
    throw "adb.exe not found after extraction. Expected: $adbExe"
}

Write-Host "OK. ADB installed at: $adbExe"
Write-Host "Try: scripts\adb.bat devices -l"
