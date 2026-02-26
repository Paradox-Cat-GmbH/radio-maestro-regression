param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [string]$CDE,
    [string]$RSE,
    [string]$HU,

    [string]$DltCDE = "169.254.166.167",
    [string]$DltRSE = "169.254.166.152",
    [string]$DltHU  = "169.254.166.99",
    [string]$DltPort = "3490"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$nodeScript = Join-Path $ScriptDir "dlt-capture.js"
$run3way = Join-Path $ScriptDir "run-g70-3way-same-time.ps1"
if (-not (Test-Path $nodeScript)) { throw "Missing script: $nodeScript" }
if (-not (Test-Path $run3way)) { throw "Missing script: $run3way" }

# Default explicit mapping by known G70 IPs (prevents adb list-order swaps)
if (-not $CDE) { $CDE = "$DltCDE`:5555" }
if (-not $RSE) { $RSE = "$DltRSE`:5555" }
if (-not $HU)  { $HU  = "$DltHU`:5555" }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$outRoot = Join-Path $RepoRoot "artifacts\dlt\$CaseId\$ts"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$cdeOut = Join-Path $outRoot "cde.dlt"
$rseOut = Join-Path $outRoot "rse.dlt"
$huOut  = Join-Path $outRoot "hu.dlt"

Write-Host "Starting DLT captures (CDE/RSE/HU)..."
& node $nodeScript start $DltCDE $DltPort $cdeOut "CDE" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Failed to start CDE DLT capture" }

& node $nodeScript start $DltRSE $DltPort $rseOut "RSE" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Failed to start RSE DLT capture" }

& node $nodeScript start $DltHU $DltPort $huOut "HU" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Failed to start HU DLT capture" }

try {
    Write-Host "Running 3-way same-time Maestro case..."
    # Ignore flow hooks here to avoid duplicate/fragile hook path during CLI 3-way.
    & $run3way -CaseId $CaseId -CDE $CDE -RSE $RSE -HU $HU -IgnoreHooks
    if ($LASTEXITCODE -ne 0) { throw "3-way runner failed with exit code $LASTEXITCODE" }
}
finally {
    Write-Host "Stopping DLT captures..."
    & node $nodeScript stop "0" "0" "0" "CDE" | Out-Host
    & node $nodeScript stop "0" "0" "0" "RSE" | Out-Host
    & node $nodeScript stop "0" "0" "0" "HU"  | Out-Host
}

Write-Host "Done. DLT outputs: $outRoot"
