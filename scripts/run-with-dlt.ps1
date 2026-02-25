param(
    [Parameter(Mandatory = $true)]
    [string]$Flow,

    [string]$Device,
    [string]$DltIp = "127.0.0.1",
    [string]$DltPort = "3490",
    [string]$DltOutput = "capture.dlt"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$flowPath = if ([System.IO.Path]::IsPathRooted($Flow)) { $Flow } else { Join-Path $RepoRoot $Flow }
$flowPath = (Resolve-Path -LiteralPath $flowPath).Path

$dltJs = Join-Path $ScriptDir "dlt-capture.js"
if (-not (Test-Path $dltJs)) { throw "Missing script: $dltJs" }

$nodeCmd = "node"

Write-Host "Starting DLT capture..."
& $nodeCmd $dltJs start $DltIp $DltPort $DltOutput
if ($LASTEXITCODE -ne 0) { throw "Failed to start DLT capture" }

try {
    Write-Host "Running Maestro flow..."
    if ($Device) {
        & maestro test --device "$Device" "$flowPath"
    } else {
        & maestro test "$flowPath"
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Maestro failed with exit code $LASTEXITCODE"
    }
}
finally {
    Write-Host "Stopping DLT capture..."
    & $nodeCmd $dltJs stop "0" "0" "0" "default" | Out-Host
}

Write-Host "Flow + DLT capture completed."
