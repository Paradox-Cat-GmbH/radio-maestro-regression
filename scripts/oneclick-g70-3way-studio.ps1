param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [string]$ControlServerUrl = "http://127.0.0.1:4567",

    [string]$CDE = "169.254.166.167:5555",
    [string]$RSE = "169.254.166.152:5555",
    [string]$HU  = "169.254.166.99:5555",

    [string]$DltIpCDE = "169.254.166.167",
    [string]$DltIpRSE = "169.254.166.152",
    [string]$DltIpHU  = "169.254.166.99",
    [string]$DltPort = "3490"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$caseDir = Join-Path $RepoRoot "flows\g70\testcases\$CaseId"
$startBat = Join-Path $ScriptDir "control_server\start_server.bat"

if (-not (Test-Path $startBat)) { throw "Missing control server launcher: $startBat" }

if (-not (Test-Path $caseDir)) {
    & (Join-Path $ScriptDir "new-g70-3way-testcase.ps1") -CaseId $CaseId
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$runRoot = Join-Path $RepoRoot "artifacts\runs\g70\$CaseId\$ts"

$cdeRoot = Join-Path $runRoot "cde"
$rseRoot = Join-Path $runRoot "rse"
$huRoot  = Join-Path $runRoot "hu"

$cdeDlt = Join-Path $cdeRoot "dlt\cde_capture.dlt"
$rseDlt = Join-Path $rseRoot "dlt\rse_capture.dlt"
$huDlt  = Join-Path $huRoot  "dlt\hu_capture.dlt"

New-Item -ItemType Directory -Force -Path (Join-Path $cdeRoot "dlt"), (Join-Path $rseRoot "dlt"), (Join-Path $huRoot "dlt") | Out-Null

# Start control server if needed
$uri = [uri]$ControlServerUrl
$port = $uri.Port
$listening = $false
try {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($conn) { $listening = $true }
} catch {}

if (-not $listening) {
    Write-Host "Starting control server on $ControlServerUrl ..."
    Start-Process -FilePath $startBat -WorkingDirectory (Split-Path $startBat -Parent) | Out-Null
    Start-Sleep -Seconds 2
}

$envBlock = @"
CONTROL_SERVER_URL=$ControlServerUrl
CASE_ID=$CaseId
RUN_TS=$ts
RUN_ROOT=$runRoot
DLT_PORT=$DltPort
CDE_DEVICE=$CDE
RSE_DEVICE=$RSE
HU_DEVICE=$HU
DLT_IP_CDE=$DltIpCDE
DLT_IP_RSE=$DltIpRSE
DLT_IP_HU=$DltIpHU
CAPTURE_ID_CDE=G70_CDE_STUDIO
CAPTURE_ID_RSE=G70_RSE_STUDIO
CAPTURE_ID_HU=G70_HU_STUDIO
DLT_OUTPUT_CDE=$cdeDlt
DLT_OUTPUT_RSE=$rseDlt
DLT_OUTPUT_HU=$huDlt
"@

$envFile = Join-Path $runRoot "studio-env-g70-3way.txt"
$envBlock | Set-Content -Encoding UTF8 $envFile

try { Set-Clipboard -Value $envBlock } catch {}

Write-Host ""
Write-Host "READY - G70 3-way Studio parity pack"
Write-Host "Case folder: $caseDir"
Write-Host "Flows:"
Write-Host "  $caseDir\cde.yaml"
Write-Host "  $caseDir\rse.yaml"
Write-Host "  $caseDir\hu.yaml"
Write-Host "Run root : $runRoot"
Write-Host "Env file : $envFile"
Write-Host "(Env block copied to clipboard when supported.)"
Write-Host ""
Write-Host "Use these 3 flows in Maestro Studio same-time run with devices:"
Write-Host "  CDE -> $CDE"
Write-Host "  RSE -> $RSE"
Write-Host "  HU  -> $HU"
Write-Host ""
Write-Host "Paste these env vars in Maestro Studio:"
Write-Host $envBlock
