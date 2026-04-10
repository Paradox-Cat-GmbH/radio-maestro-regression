param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,
    [string]$DltIp = "",
    [string]$DltPort = "3490",
    [switch]$PruneEvidenceOnPass
)

$ErrorActionPreference = "Stop"

function Invoke-Adb {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args,
        [int]$TimeoutSeconds = 30
    )

    $adbExe = Join-Path $ScriptDir "adb.bat"
    if (-not (Test-Path $adbExe)) { throw "Missing adb wrapper: $adbExe" }

    $job = Start-Job -ScriptBlock {
        param($exe, $argList)
        & $exe @argList 2>&1
    } -ArgumentList $adbExe, $Args

    if (-not (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
        Stop-Job -Job $job -Force | Out-Null
        Remove-Job -Job $job -Force | Out-Null
        throw "ADB command timed out: $($Args -join ' ')"
    }

    $output = Receive-Job -Job $job
    Remove-Job -Job $job -Force | Out-Null
    return @($output) -join [Environment]::NewLine
}

function Start-AdbScreenrecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,
        [Parameter(Mandatory = $true)]
        [string]$RemoteFile
    )

    $adbExe = Join-Path $ScriptDir "adb.bat"
    return Start-Process -FilePath $adbExe -ArgumentList @("-s", $DeviceId, "shell", "screenrecord", $RemoteFile) -WindowStyle Hidden -PassThru
}

function Save-AdbScreenshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,
        [Parameter(Mandatory = $true)]
        [string]$RemoteFile,
        [Parameter(Mandatory = $true)]
        [string]$LocalFile
    )

    Invoke-Adb -Args @("-s", $DeviceId, "shell", "screencap", "-p", $RemoteFile) -TimeoutSeconds 20 | Out-Null
    Invoke-Adb -Args @("-s", $DeviceId, "pull", $RemoteFile, $LocalFile) -TimeoutSeconds 20 | Out-Null
    Invoke-Adb -Args @("-s", $DeviceId, "shell", "rm", "-f", $RemoteFile) -TimeoutSeconds 10 | Out-Null
}

function Get-LatestMaestroRun {
    param(
        [string]$Root,
        [string]$Baseline
    )

    if (-not (Test-Path $Root)) { return $null }
    $dirs = Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if (-not $dirs) { return $null }
    if ([string]::IsNullOrWhiteSpace($Baseline)) { return $dirs | Select-Object -First 1 }
    return $dirs | Where-Object { $_.FullName -ne $Baseline } | Select-Object -First 1
}

function Get-BoolEnv {
    param([string]$Name, [bool]$Default)
    $raw = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
    switch ($raw.Trim().ToLowerInvariant()) {
        '1' { return $true }
        'true' { return $true }
        'yes' { return $true }
        'on' { return $true }
        '0' { return $false }
        'false' { return $false }
        'no' { return $false }
        'off' { return $false }
        default { return $Default }
    }
}

function Get-MaestroEnvArgs {
    param([string[]]$Names)

    $args = @()
    foreach ($name in $Names) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $args += @("-e", "$name=$value")
        }
    }
    return $args
}

$keepEvidenceOnPass = Get-BoolEnv -Name 'MAESTRO_KEEP_EVIDENCE_ON_PASS' -Default $true
if ($PruneEvidenceOnPass) {
    $keepEvidenceOnPass = $false
}

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
        "C:\Project Maestro\maestro\bin\maestro.bat",
        "C:\Project Maestro\maestro\bin\maestro.exe",
        "C:\Users\DavidErikGarciaArena\maestro\bin\maestro.bat",
        "C:\Users\DavidErikGarciaArena\Desktop\maestro\bin\maestro.bat"
    )
    foreach ($p in $candidates) { if (Test-Path $p) { $maestroCmd = $p; break } }
}
if (-not $maestroCmd) { throw "Maestro executable not found. Ensure maestro is installed and on PATH." }

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$resolvedDltIp = if (-not [string]::IsNullOrWhiteSpace($DltIp)) {
    $DltIp
} elseif ($DeviceId -match '^([^:]+)') {
    $Matches[1]
} else {
    "169.254.8.177"
}
$runRoot = Join-Path $RepoRoot "artifacts\runs\idc23\$CaseId\$ts"
$dltOut = Join-Path $runRoot "dlt\idc23_capture.dlt"
$maestroOut = Join-Path $runRoot "maestro"
$screenshotsDir = Join-Path $runRoot "screenshots"
$videoDirOut = Join-Path $runRoot "video"
$remoteStartPng = "/sdcard/oc_start.png"
$remoteStopPng = "/sdcard/oc_stop.png"
$remoteVideo = "/sdcard/oc_fallback.mp4"
$screenrecordProc = $null
$maestroEnvArgs = Get-MaestroEnvArgs -Names @(
    'IDC23_STR_LOOPS',
    'IDC23_COLD_BOOT_LOOPS',
    'IDC23_TARGET_USER_ID',
    'IDC23_TARGET_USER_NAME',
    'IDC23_USER_X_ID',
    'IDC23_USER_X_NAME',
    'IDC23_USER_Y_ID',
    'IDC23_USER_Y_NAME',
    'IDC23_GUEST_USER_ID',
    'LIFECYCLE_ECU',
    'LIFECYCLE_PRE1_ECU',
    'LIFECYCLE_PRE2_ECU',
    'LIFECYCLE_COLD_POST_REBOOT_DELAY_SECONDS',
    'ALEXA_STRICT',
    'EHH_STRICT',
    'SWITCH_SETTLE_MS',
    'RETRY_METADATA_SECONDS',
    'RETRY_METADATA_INTERVAL_MS'
)

New-Item -ItemType Directory -Force -Path $runRoot, (Join-Path $runRoot "dlt"), $maestroOut, $screenshotsDir, $videoDirOut | Out-Null

$maestroTestsRoot = Join-Path $env:USERPROFILE ".maestro\tests"
$baselineMaestroRun = $null
if (Test-Path $maestroTestsRoot) {
    $baselineMaestroRun = Get-ChildItem -Path $maestroTestsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

Write-Host "Starting DLT capture (${resolvedDltIp}:${DltPort})..."
& node $dltJs start $resolvedDltIp $DltPort $dltOut "IDC23"
if ($LASTEXITCODE -ne 0) { throw "Failed to start DLT capture" }

try {
    Save-AdbScreenshot -DeviceId $DeviceId -RemoteFile $remoteStartPng -LocalFile (Join-Path $screenshotsDir "START.png")
} catch {
    Write-Warning "Failed to capture START screenshot: $($_.Exception.Message)"
}

try {
    $screenrecordProc = Start-AdbScreenrecord -DeviceId $DeviceId -RemoteFile $remoteVideo
} catch {
    Write-Warning "Failed to start fallback screenrecord: $($_.Exception.Message)"
}

$maestroExit = 0
$maestroError = $null
try {
    Write-Host "Running Maestro flow on IDC23 device..."
    & $maestroCmd test --device "$DeviceId" @maestroEnvArgs --test-output-dir "$maestroOut" "$flow"
    $maestroExit = $LASTEXITCODE
    if ($maestroExit -ne 0) {
        $maestroError = "Maestro failed with exit code $maestroExit"
    }
}
finally {
    Write-Host "Stopping DLT capture..."
    & node $dltJs stop "0" "0" "0" "IDC23" | Out-Host

    if ($screenrecordProc) {
        try {
            if (-not $screenrecordProc.HasExited) {
                Stop-Process -Id $screenrecordProc.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {}
        Start-Sleep -Milliseconds 1500
        $videoPulled = $false
        for ($i = 0; $i -lt 4; $i++) {
            try {
                Invoke-Adb -Args @("-s", $DeviceId, "pull", $remoteVideo, (Join-Path $videoDirOut "video_fallback_adb.mp4")) -TimeoutSeconds 30 | Out-Null
                $videoFile = Join-Path $videoDirOut "video_fallback_adb.mp4"
                if ((Test-Path $videoFile) -and ((Get-Item $videoFile).Length -gt 200000)) {
                    $videoPulled = $true
                    break
                }
            } catch {}
            Start-Sleep -Seconds 1
        }
        try {
            Invoke-Adb -Args @("-s", $DeviceId, "shell", "rm", "-f", $remoteVideo) -TimeoutSeconds 10 | Out-Null
        } catch {}
        if (-not $videoPulled) {
            Write-Warning "Fallback ADB video was not captured."
        }
    }

    try {
        Save-AdbScreenshot -DeviceId $DeviceId -RemoteFile $remoteStopPng -LocalFile (Join-Path $screenshotsDir "STOP.png")
    } catch {
        Write-Warning "Failed to capture STOP screenshot: $($_.Exception.Message)"
    }
}

$dltExists = Test-Path $dltOut
$dltSize = if ($dltExists) { (Get-Item $dltOut).Length } else { 0 }
$pngCount = 0
Get-ChildItem -Path $maestroOut -Recurse -Filter *.png -ErrorAction SilentlyContinue | ForEach-Object {
    $dst = Join-Path $screenshotsDir $_.Name
    try { Copy-Item -Path $_.FullName -Destination $dst -Force -ErrorAction SilentlyContinue } catch {}
}
$pngCount = (Get-ChildItem -Path $screenshotsDir -Recurse -File -Include *.png,*.jpg,*.jpeg,*.webp -ErrorAction SilentlyContinue | Measure-Object).Count

$videoCount = (Get-ChildItem -Path $videoDirOut -Recurse -File -Include *.mp4,*.mkv,*.webm -ErrorAction SilentlyContinue | Measure-Object).Count
$latestRun = Get-LatestMaestroRun -Root $maestroTestsRoot -Baseline ($baselineMaestroRun.FullName)
if ($latestRun) {
    $srcVideos = Join-Path $latestRun.FullName "videos"
    if (Test-Path $srcVideos) {
        Copy-Item -Path (Join-Path $srcVideos "*") -Destination $videoDirOut -Recurse -Force -ErrorAction SilentlyContinue
        $videoCount = (Get-ChildItem -Path $videoDirOut -Recurse -File -Include *.mp4,*.mkv,*.webm -ErrorAction SilentlyContinue | Measure-Object).Count
    }
}

$flowPassed = ($maestroExit -eq 0)
$evidenceChecks = [pscustomobject]@{
    dltCaptured = ($dltExists -and $dltSize -gt 0)
    videoCaptured = ($videoCount -gt 0)
    screenshotsCaptured = ($pngCount -gt 0)
}
$evidenceComplete = ($evidenceChecks.dltCaptured -and $evidenceChecks.videoCaptured -and $evidenceChecks.screenshotsCaptured)
$verdict = if (-not $flowPassed) { "FAIL" } elseif ($evidenceComplete) { "PASS" } else { "PARTIAL" }
$analysis = @(
    ("Flow " + ($(if ($flowPassed) { "passed" } else { "failed" }))),
    ("DLT " + ($(if ($evidenceChecks.dltCaptured) { "captured" } else { "missing/empty" })) + " ($dltSize bytes)"),
    ("Video " + ($(if ($evidenceChecks.videoCaptured) { "captured" } else { "not found" })) + " ($videoCount file(s))"),
    ("Screenshots " + ($(if ($evidenceChecks.screenshotsCaptured) { "captured" } else { "not found" })) + " ($pngCount file(s))")
)

$summary = [pscustomobject]@{
    caseId = $CaseId
    deviceId = $DeviceId
    dltIp = $resolvedDltIp
    dltPort = $DltPort
    timestamp = $ts
    runRoot = $runRoot
    dltFile = $dltOut
    dltBytes = $dltSize
    maestroOutputDir = $maestroOut
    screenshotsDir = $screenshotsDir
    screenshotCount = $pngCount
    videoDir = $(if ($videoCount -gt 0) { $videoDirOut } else { "" })
    videoCount = $videoCount
    maestroExitCode = $maestroExit
    flowPassed = $flowPassed
    evidenceComplete = $evidenceComplete
    checks = $evidenceChecks
    verdict = $verdict
    analysis = $analysis
    success = $flowPassed
    keepEvidenceOnPass = $keepEvidenceOnPass
    evidencePruned = $false
}

if ($summary.flowPassed -and -not $keepEvidenceOnPass) {
    Write-Host "[INFO] Pruning pass evidence (MAESTRO_KEEP_EVIDENCE_ON_PASS=false)"
    if (Test-Path $dltOut) {
        Remove-Item -Path $dltOut -Force -ErrorAction SilentlyContinue
    }
    foreach ($dir in @($maestroOut, $videoDirOut, $screenshotsDir)) {
        if (Test-Path $dir) {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $summary.evidencePruned = $true
}

$summaryPath = Join-Path $runRoot "run-summary.json"
$summary | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $summaryPath

Write-Host "E2E PoC finished."
Write-Host "Run folder: $runRoot"
Write-Host "DLT bytes: $dltSize"
Write-Host "Screenshots found: $pngCount"
Write-Host "Video files found: $videoCount"
Write-Host "Summary: $summaryPath"

if ($maestroError) {
    throw $maestroError
}
