param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,
    [string]$DltIp = "169.254.107.117",
    [string]$DltPort = "3490"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$dltJs = Join-Path $ScriptDir "dlt-capture.js"
if (-not (Test-Path $dltJs)) { throw "Missing DLT helper: $dltJs" }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$runRoot = Join-Path $RepoRoot "artifacts\runs\idc23\$CaseId\$ts"
$dltOut = Join-Path $runRoot "dlt\idc23_capture.dlt"
$studioOut = Join-Path $runRoot "studio"
$videoOut = Join-Path $runRoot "video"

New-Item -ItemType Directory -Force -Path $runRoot, (Join-Path $runRoot "dlt"), $studioOut | Out-Null

$maestroTestsRoot = Join-Path $env:USERPROFILE ".maestro\tests"
$baseline = $null
if (Test-Path $maestroTestsRoot) {
    $baseline = Get-ChildItem -Path $maestroTestsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

Write-Host "Starting DLT capture (${DltIp}:${DltPort})..."
& node $dltJs start $DltIp $DltPort $dltOut "IDC23_STUDIO"
if ($LASTEXITCODE -ne 0) { throw "Failed to start DLT capture" }

Write-Host ""
Write-Host "Now run your flow in Maestro Studio."
Write-Host "When the Studio run is fully finished, come back here and press ENTER."
Read-Host | Out-Null

try {
    $latestRun = $null
    if (Test-Path $maestroTestsRoot) {
        $latestRun = Get-ChildItem -Path $maestroTestsRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    if ($latestRun -and (-not $baseline -or $latestRun.FullName -ne $baseline.FullName)) {
        Copy-Item -Path (Join-Path $latestRun.FullName "*") -Destination $studioOut -Recurse -Force -ErrorAction SilentlyContinue

        $srcVideos = Join-Path $latestRun.FullName "videos"
        if (Test-Path $srcVideos) {
            New-Item -ItemType Directory -Force -Path $videoOut | Out-Null
            Copy-Item -Path (Join-Path $srcVideos "*") -Destination $videoOut -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
finally {
    Write-Host "Stopping DLT capture..."
    & node $dltJs stop "0" "0" "0" "IDC23_STUDIO" | Out-Host
}

$dltBytes = if (Test-Path $dltOut) { (Get-Item $dltOut).Length } else { 0 }
$videoCount = (Get-ChildItem -Path $videoOut -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count

$summary = [pscustomobject]@{
    caseId = $CaseId
    timestamp = $ts
    runRoot = $runRoot
    dltFile = $dltOut
    dltBytes = $dltBytes
    studioArtifactsDir = $studioOut
    videoDir = $(if ($videoCount -gt 0) { $videoOut } else { "" })
    videoCount = $videoCount
}

$summaryPath = Join-Path $runRoot "run-summary.json"
$summary | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $summaryPath

Write-Host "Studio evidence bundle completed."
Write-Host "Run folder: $runRoot"
Write-Host "DLT bytes: $dltBytes"
Write-Host "Video files: $videoCount"
Write-Host "Summary: $summaryPath"
