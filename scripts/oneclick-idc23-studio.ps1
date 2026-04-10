param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,
    [string]$DeviceId = "169.254.8.177:5555",
    [string]$DltIp = "",
    [string]$DltPort = "3490",
    [string]$ControlServerUrl = "http://127.0.0.1:4567",
    [string]$CaptureId = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$caseDir = Join-Path $RepoRoot "flows\idc23\testcases\$CaseId"
$templateStudio = Join-Path $RepoRoot "flows\idc23\testcases\_template\idc23.studio.yaml"
$startBat = Join-Path $ScriptDir "control_server\start_server.bat"

if (-not (Test-Path $startBat)) { throw "Missing control server launcher: $startBat" }
if (-not (Test-Path $templateStudio)) { throw "Missing Studio template: $templateStudio" }

if (-not (Test-Path $caseDir)) {
    & (Join-Path $ScriptDir "new-idc23-testcase.ps1") -CaseId $CaseId
}

$caseStudioFlow = Join-Path $caseDir "idc23.studio.yaml"
if (-not (Test-Path $caseStudioFlow)) {
    Copy-Item $templateStudio $caseStudioFlow -Force
}

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$resolvedDltIp = if (-not [string]::IsNullOrWhiteSpace($DltIp)) {
    $DltIp
} elseif ($DeviceId -match '^([^:]+)') {
    $Matches[1]
} else {
    "169.254.8.177"
}

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
DEVICE_ID=$DeviceId
DLT_IP=$resolvedDltIp
DLT_PORT=$DltPort
CASE_ID=$CaseId
"@

$runHint = Join-Path $RepoRoot "artifacts\runs\idc23\$CaseId\$ts"
New-Item -ItemType Directory -Force -Path $runHint | Out-Null
$envFile = Join-Path $runHint "studio-env.txt"
$envBlock | Set-Content -Encoding UTF8 $envFile

try { Set-Clipboard -Value $envBlock } catch {}

Write-Host ""
Write-Host "READY"
Write-Host "Studio flow: $caseStudioFlow"
Write-Host "Run hint : $runHint"
Write-Host "Env file : $envFile"
Write-Host "Runtime values generated automatically in Studio: RUN_TS, RUN_ROOT, DLT_OUTPUT, CAPTURE_ID"
Write-Host "(Env block copied to clipboard when supported.)"
Write-Host ""
Write-Host "Paste these env vars in Maestro Studio:"
Write-Host $envBlock
