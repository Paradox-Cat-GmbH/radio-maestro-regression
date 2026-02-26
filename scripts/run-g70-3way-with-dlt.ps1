param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [string]$CDE,
    [string]$RSE,
    [string]$HU,

    [string]$DltCDE = "169.254.166.167",
    [string]$DltRSE = "169.254.166.152",
    [string]$DltHU  = "169.254.166.99",
    [string]$DltPort = "3490",
    [string]$ControlServerUrl = "http://127.0.0.1:4567"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$run3way = Join-Path $ScriptDir "run-g70-3way-same-time.ps1"
if (-not (Test-Path $run3way)) { throw "Missing script: $run3way" }

# Default device mapping if not explicitly provided
if (-not $CDE) { $CDE = "$DltCDE`:5555" }
if (-not $RSE) { $RSE = "$DltRSE`:5555" }
if (-not $HU)  { $HU  = "$DltHU`:5555" }

# DLT is managed by flow hooks (onFlowStart/onFlowComplete).
# This wrapper only injects the required environment for 3-way same-time execution.
$env:CONTROL_SERVER_URL = $ControlServerUrl
$env:CASE_ID = $CaseId
$env:DLT_PORT = $DltPort

$env:CDE_DEVICE = $CDE
$env:RSE_DEVICE = $RSE
$env:HU_DEVICE = $HU

$env:DLT_IP_CDE = $DltCDE
$env:DLT_IP_RSE = $DltRSE
$env:DLT_IP_HU  = $DltHU

$env:CAPTURE_ID_CDE = "G70_CDE_STUDIO"
$env:CAPTURE_ID_RSE = "G70_RSE_STUDIO"
$env:CAPTURE_ID_HU  = "G70_HU_STUDIO"

Write-Host "Running 3-way same-time with flow-managed DLT hooks..."
Write-Host "CDE: $CDE"
Write-Host "RSE: $RSE"
Write-Host "HU : $HU"

& $run3way -CaseId $CaseId -CDE $CDE -RSE $RSE -HU $HU
if ($LASTEXITCODE -ne 0) { throw "3-way runner failed with exit code $LASTEXITCODE" }

Write-Host "Done. 3-way same-time + DLT hook lifecycle completed."
