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

    [switch]$AllowLargeRSEScreenshots
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
$outRoot = Join-Path $RepoRoot "artifacts\runs\g70\$CaseId\$ts"
$dltDir = Join-Path $outRoot "dlt"
$maestroDir = Join-Path $outRoot "maestro"
$videoDir = Join-Path $outRoot "video"

New-Item -ItemType Directory -Force -Path $outRoot, $dltDir, $maestroDir | Out-Null

$cdeOut = Join-Path $dltDir "cde.dlt"
$rseOut = Join-Path $dltDir "rse.dlt"
$huOut  = Join-Path $dltDir "hu.dlt"

$maestroTestsRoot = Join-Path $env:USERPROFILE ".maestro\tests"
$baseline = $null
if (Test-Path $maestroTestsRoot) {
    $baseline = Get-ChildItem -Path $maestroTestsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

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
    & $run3way -CaseId $CaseId -CDE $CDE -RSE $RSE -HU $HU -IgnoreHooks -AllowLargeRSEScreenshots:$AllowLargeRSEScreenshots
    if ($LASTEXITCODE -ne 0) { throw "3-way runner failed with exit code $LASTEXITCODE" }
}
finally {
    Write-Host "Stopping DLT captures..."
    & node $nodeScript stop "0" "0" "0" "CDE" | Out-Host
    & node $nodeScript stop "0" "0" "0" "RSE" | Out-Host
    & node $nodeScript stop "0" "0" "0" "HU"  | Out-Host

    $latestRun = $null
    if (Test-Path $maestroTestsRoot) {
        $latestRun = Get-ChildItem -Path $maestroTestsRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    if ($latestRun -and (-not $baseline -or $latestRun.FullName -ne $baseline.FullName)) {
        Copy-Item -Path (Join-Path $latestRun.FullName "*") -Destination $maestroDir -Recurse -Force -ErrorAction SilentlyContinue

        $srcVideos = Join-Path $latestRun.FullName "videos"
        if (Test-Path $srcVideos) {
            New-Item -ItemType Directory -Force -Path $videoDir | Out-Null
            Copy-Item -Path (Join-Path $srcVideos "*") -Destination $videoDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$cdeBytes = if (Test-Path $cdeOut) { (Get-Item $cdeOut).Length } else { 0 }
$rseBytes = if (Test-Path $rseOut) { (Get-Item $rseOut).Length } else { 0 }
$huBytes  = if (Test-Path $huOut)  { (Get-Item $huOut).Length } else { 0 }
$videoCount = (Get-ChildItem -Path $videoDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
$shotCount = (Get-ChildItem -Path $maestroDir -Recurse -File -Include *.png -ErrorAction SilentlyContinue | Measure-Object).Count

$summary = [pscustomobject]@{
    caseId = $CaseId
    timestamp = $ts
    runRoot = $outRoot
    dlt = [pscustomobject]@{
        cde = [pscustomobject]@{ path = $cdeOut; bytes = $cdeBytes }
        rse = [pscustomobject]@{ path = $rseOut; bytes = $rseBytes }
        hu  = [pscustomobject]@{ path = $huOut;  bytes = $huBytes }
    }
    maestroArtifactsDir = $maestroDir
    screenshotCount = $shotCount
    videoDir = $(if ($videoCount -gt 0) { $videoDir } else { "" })
    videoCount = $videoCount
}

$summaryPath = Join-Path $outRoot "run-summary.json"
$summary | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $summaryPath

if (($cdeBytes + $rseBytes + $huBytes) -eq 0) {
    Write-Warning "DLT files are empty. Verify dlt-receive availability/path and DLT routing on devices."
}

Write-Host "Done. Run folder: $outRoot"
Write-Host "DLT bytes -> CDE:$cdeBytes RSE:$rseBytes HU:$huBytes"
Write-Host "Screenshots copied: $shotCount"
Write-Host "Videos copied: $videoCount"
Write-Host "Summary: $summaryPath"
