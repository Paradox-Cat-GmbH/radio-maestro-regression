param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [string]$CDE,
    [string]$RSE,
    [string]$HU,

    [switch]$IgnoreHooks,
    [switch]$AllowLargeRSEScreenshots
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$flowCDE = Join-Path $RepoRoot "flows\g70\testcases\$CaseId\cde.yaml"
$flowRSE = Join-Path $RepoRoot "flows\g70\testcases\$CaseId\rse.yaml"
$flowHU  = Join-Path $RepoRoot "flows\g70\testcases\$CaseId\hu.yaml"

if (-not (Test-Path $flowCDE)) { throw "Missing flow: $flowCDE" }
if (-not (Test-Path $flowRSE)) { throw "Missing flow: $flowRSE" }
if (-not (Test-Path $flowHU))  { throw "Missing flow: $flowHU" }

Write-Host "Connected devices from ADB:"
$adbList = adb devices -l
$adbList | ForEach-Object { Write-Host $_ }

$connected = @()
foreach ($line in $adbList) {
    if ($line -match '^(\S+)\s+device\b') { $connected += $matches[1] }
}
if ($connected.Count -lt 3) {
    throw "Need at least 3 connected devices in 'device' state. Found: $($connected.Count)"
}

# Require explicit mapping to avoid accidental CDE/RSE swaps from adb list ordering
if (-not $CDE -or -not $RSE -or -not $HU) {
    throw "Explicit device mapping required. Provide -CDE, -RSE, -HU. Example: -CDE '169.254.166.167:5555' -RSE '169.254.166.152:5555' -HU '169.254.166.99:5555'"
}

if (-not ($connected -contains $CDE)) { throw "CDE not connected: $CDE" }
if (-not ($connected -contains $RSE)) { throw "RSE not connected: $RSE" }
if (-not ($connected -contains $HU))  { throw "HU not connected: $HU" }

if (($CDE -eq $RSE) -or ($CDE -eq $HU) -or ($RSE -eq $HU)) {
    throw "CDE/RSE/HU must be unique device IDs"
}

Write-Host "Using CDE: $CDE"
Write-Host "Using RSE: $RSE"
Write-Host "Using HU : $HU"

$deviceList = "$CDE,$RSE,$HU"

$runFlowCDE = $flowCDE
$runFlowRSE = $flowRSE
$runFlowHU  = $flowHU
$script:hooklessTemp = @()
$script:RSEFallbackAppId = $null
$maestroFailed = $false

if ($IgnoreHooks) {
    Write-Host "IgnoreHooks enabled: generating hookless temporary flows for CLI execution..."

    function Test-LaunchableApp([string]$device, [string]$appId) {
        # Use cmd wrapper so adb stderr doesn't become PowerShell NativeCommandError
        # under strict ErrorActionPreference settings.
        $escaped = 'adb -s "{0}" shell monkey -p "{1}" -c android.intent.category.LAUNCHER 1 2>&1' -f $device, $appId
        $out = cmd /c $escaped
        $code = $LASTEXITCODE

        $text = ($out | Out-String)
        if ($code -eq 0 -and $text -match 'Events injected:\s*1') { return $true }
        if ($text -match 'No activities found to run') { return $false }
        if ($text -match 'monkey aborted') { return $false }
        return $false
    }

    function New-HooklessFlow([string]$srcPath, [string]$suffix) {
        $raw = Get-Content -Raw $srcPath
        $parts = $raw -split "`r?`n---`r?`n", 2
        if ($parts.Count -lt 2) { return $srcPath }

        $header = $parts[0]
        $body = $parts[1]
        $appIdLine = ($header -split "`r?`n" | Where-Object { $_ -match '^\s*appId\s*:' } | Select-Object -First 1)
        if (-not $appIdLine) { $appIdLine = 'appId: com.android.settings' }

        # RSE theatre screen can exceed Maestro gRPC screenshot payload limit (4MB).
        # Default in hookless CLI mode: strip RSE screenshots unless explicitly allowed.
        if ($suffix -eq 'rse' -and -not $AllowLargeRSEScreenshots) {
            $bodyLines = $body -split "`r?`n"
            $filtered = $bodyLines | Where-Object { $_ -notmatch '^\s*-\s*takeScreenshot\s*:' }

            # Keep config valid and use a launchable app on RSE.
            if (-not $script:RSEFallbackAppId) {
                throw "RSE fallback appId not resolved."
            }
            $appIdLine = "appId: $($script:RSEFallbackAppId)"

            $hasCommand = ($filtered | Where-Object { $_ -match '^\s*-\s*\S+' } | Measure-Object).Count -gt 0
            if (-not $hasCommand) {
                $filtered = @('- pressKey: HOME')
            }

            $body = ($filtered -join "`r`n")
            Write-Warning "RSE hookless flow: takeScreenshot removed (default) and appId set to $($script:RSEFallbackAppId). Use -AllowLargeRSEScreenshots to keep original behavior."
        }

        # Keep hookless flow next to source flow so relative runFlow/js paths still resolve.
        $srcDir = Split-Path -Parent $srcPath
        $tmp = Join-Path $srcDir ("g70_hookless_{0}_{1}.yaml" -f $suffix, ([System.Guid]::NewGuid().ToString('N')))
        # Maestro requires a config section before '---'.
        # When appId is intentionally bypassed (RSE fallback), use empty config map.
        $content = if ([string]::IsNullOrWhiteSpace($appIdLine)) { "{}`r`n---`r`n" + $body } else { $appIdLine + "`r`n---`r`n" + $body }
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($tmp, $content, $utf8NoBom)

        $script:hooklessTemp += $tmp
        Write-Host "Generated hookless flow: $tmp"
        return $tmp
    }

    if (-not $AllowLargeRSEScreenshots) {
        $candidates = @(
            'com.android.settings',
            'com.android.car.settings',
            'com.android.launcher3',
            'com.google.android.apps.nexuslauncher',
            'com.android.chrome'
        )

        foreach ($pkg in $candidates) {
            if (Test-LaunchableApp -device $RSE -appId $pkg) {
                $script:RSEFallbackAppId = $pkg
                break
            }
        }

        if (-not $script:RSEFallbackAppId) {
            throw "Could not find a launchable fallback app on RSE ($RSE). Re-authorize/unlock RSE and retry, or run with -AllowLargeRSEScreenshots if you want original behavior."
        }

        Write-Host "RSE fallback app resolved: $script:RSEFallbackAppId"
    }

    $runFlowCDE = New-HooklessFlow $flowCDE "cde"
    $runFlowRSE = New-HooklessFlow $flowRSE "rse"
    $runFlowHU  = New-HooklessFlow $flowHU  "hu"
}

Write-Host "Running 3 flows in one Maestro process (single shard suite) across CDE/RSE/HU..."

$outFile = [System.IO.Path]::GetTempFileName()
$errFile = [System.IO.Path]::GetTempFileName()

try {
    $p = Start-Process -FilePath "maestro" `
        -ArgumentList @("test", "--no-ansi", "--device", $deviceList, "--shard-split", "3", $runFlowCDE, $runFlowRSE, $runFlowHU) `
        -NoNewWindow -PassThru -Wait `
        -RedirectStandardOutput $outFile `
        -RedirectStandardError $errFile

    $lines = @()
    if (Test-Path $outFile) { $lines += Get-Content $outFile }
    if (Test-Path $errFile) { $lines += Get-Content $errFile }

    foreach ($line in $lines) {
        Write-Host $line
    }

    if ($p.ExitCode -ne 0) {
        $maestroFailed = $true
        throw "Maestro failed with exit code $($p.ExitCode)"
    }
}
finally {
    Remove-Item -ErrorAction SilentlyContinue $outFile, $errFile

    if ($script:hooklessTemp.Count -gt 0) {
        if ($maestroFailed) {
            Write-Warning "Maestro failed. Keeping generated hookless flows for inspection:`n$($script:hooklessTemp -join "`n")"
        }
        else {
            Remove-Item -ErrorAction SilentlyContinue $script:hooklessTemp
        }
    }
}

Write-Host "All 3 device flows completed successfully."
