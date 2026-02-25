param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,
    [string]$DltIp = "169.254.107.117",
    [string]$DltPort = "3490",
    [string]$ControlServerUrl = "http://127.0.0.1:4567",
    [string]$CaptureId = "IDCEVO_STUDIO"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$startBat = Join-Path $ScriptDir "control_server\start_server.bat"
if (-not (Test-Path $startBat)) { throw "Missing control server launcher: $startBat" }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$runRoot = Join-Path $RepoRoot "artifacts\runs\idcevo\$CaseId\$ts"
$dltOutput = Join-Path $runRoot "dlt\idcevo_capture.dlt"
New-Item -ItemType Directory -Force -Path (Join-Path $runRoot "dlt") | Out-Null

# Start control server if not listening
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

Write-Host ""
Write-Host "Use this flow in Maestro Studio:"
Write-Host "  flows/idcevo/testcases/_template/idcevo.studio.yaml"
Write-Host ""
Write-Host "Set these env vars in Studio before Run:"
Write-Host "  CONTROL_SERVER_URL=$ControlServerUrl"
Write-Host "  DLT_IP=$DltIp"
Write-Host "  DLT_PORT=$DltPort"
Write-Host "  CASE_ID=$CaseId"
Write-Host "  RUN_TS=$ts"
Write-Host "  RUN_ROOT=$runRoot"
Write-Host "  DLT_OUTPUT=$dltOutput"
Write-Host "  CAPTURE_ID=$CaptureId"
Write-Host ""
Write-Host "Expected evidence bundle root: $runRoot"
