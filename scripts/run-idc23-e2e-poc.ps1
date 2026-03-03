param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,
    [string]$DltIp = "localhost",
    [string]$DltPort = "3490"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$flow = Join-Path $RepoRoot "flows\idc23\testcases\$CaseId\idc23.yaml"
if (-not (Test-Path $flow)) { throw "Missing flow: $flow" }

$dltJs = Join-Path $ScriptDir "dlt-capture.js"
if (-not (Test-Path $dltJs))  { throw "Missing DLT helper: $dltJs" }

$maestroCmd = $null
$cmd = Get-Command maestro -ErrorAction SilentlyContinue
if ($cmd) { $maestroCmd = $cmd.Source }
if (-not $maestroCmd) {
    $cmd = Get-Command maestro.bat -ErrorAction SilentlyContinue
    if ($cmd) { $maestroCmd = $cmd.Source }
}
if (-not $maestroCmd) {
    $candidates = @(
        "C:\Users\DavidErikGarciaArena\maestro\bin\maestro.bat",
        "C:\Users\DavidErikGarciaArena\Desktop\maestro\bin\maestro.bat"
    )
    foreach ($p in $candidates) { if (Test-Path $p) { $maestroCmd = $p; break } }
}
if (-not $maestroCmd) { throw "Maestro executable not found. Ensure maestro is installed and on PATH." }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$runRoot = Join-Path $RepoRoot "artifacts\runs\idc23\$CaseId\$ts"
$dltOut = Join-Path $runRoot "dlt\idc23_capture.dlt"
$maestroOut = Join-Path $runRoot "maestro"

New-Item -ItemType Directory -Force -Path $runRoot, (Join-Path $runRoot "dlt"), $maestroOut | Out-Null

Write-Host "Starting DLT capture (${DltIp}:${DltPort})..."
& node $dltJs start $DltIp $DltPort $dltOut "IDC23"
if ($LASTEXITCODE -ne 0) { throw "Failed to start DLT capture" }

$maestroExit = 0
try {
    Write-Host "Running Maestro flow on IDC23 device..."
    & $maestroCmd test --device "$DeviceId" --test-output-dir "$maestroOut" "$flow"
    $maestroExit = $LASTEXITCODE
    if ($maestroExit -ne 0) { throw "Maestro failed with exit code $maestroExit" }
}
finally {
    Write-Host "Stopping DLT capture..."
    & node $dltJs stop "0" "0" "0" "IDC23" | Out-Host
}

$dltExists = Test-Path $dltOut
$dltSize = if ($dltExists) { (Get-Item $dltOut).Length } else { 0 }
$pngCount = (Get-ChildItem -Path $maestroOut -Recurse -Filter *.png -ErrorAction SilentlyContinue | Measure-Object).Count

$videoCount = 0
$videoDirOut = Join-Path $runRoot "video"
$maestroTestsRoot = Join-Path $env:USERPROFILE ".maestro\tests"
if (Test-Path $maestroTestsRoot) {
    $latestRun = Get-ChildItem -Path $maestroTestsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestRun) {
        $srcVideos = Join-Path $latestRun.FullName "videos"
        if (Test-Path $srcVideos) {
            New-Item -ItemType Directory -Force -Path $videoDirOut | Out-Null
            Copy-Item -Path (Join-Path $srcVideos "*") -Destination $videoDirOut -Recurse -Force -ErrorAction SilentlyContinue
            $videoCount = (Get-ChildItem -Path $videoDirOut -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
        }
    }
}

$summary = [pscustomobject]@{
    caseId = $CaseId
    deviceId = $DeviceId
    dltIp = $DltIp
    dltPort = $DltPort
    timestamp = $ts
    runRoot = $runRoot
    dltFile = $dltOut
    dltBytes = $dltSize
    maestroOutputDir = $maestroOut
    screenshotCount = $pngCount
    videoDir = $(if ($videoCount -gt 0) { $videoDirOut } else { "" })
    videoCount = $videoCount
    maestroExitCode = $maestroExit
    success = ($maestroExit -eq 0 -and $dltExists -and $dltSize -gt 0)
}

$summaryPath = Join-Path $runRoot "run-summary.json"
$summary | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $summaryPath

Write-Host "E2E PoC finished."
Write-Host "Run folder: $runRoot"
Write-Host "DLT bytes: $dltSize"
Write-Host "Screenshots found: $pngCount"
Write-Host "Video files found: $videoCount"
Write-Host "Summary: $summaryPath"
