param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,

    [string]$CDE,
    [string]$RSE,
    [string]$HU,

    [switch]$IgnoreHooks
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
$hooklessTemp = @()
$maestroFailed = $false

if ($IgnoreHooks) {
    Write-Host "IgnoreHooks enabled: generating hookless temporary flows for CLI execution..."

    function New-HooklessFlow([string]$srcPath, [string]$suffix) {
        $raw = Get-Content -Raw $srcPath
        $parts = $raw -split "`r?`n---`r?`n", 2
        if ($parts.Count -lt 2) { return $srcPath }

        $header = $parts[0]
        $body = $parts[1]
        $appIdLine = ($header -split "`r?`n" | Where-Object { $_ -match '^\s*appId\s*:' } | Select-Object -First 1)
        if (-not $appIdLine) { $appIdLine = 'appId: com.android.settings' }

        # Keep hookless flow next to source flow so relative runFlow/js paths still resolve.
        $srcDir = Split-Path -Parent $srcPath
        $tmp = Join-Path $srcDir ("g70_hookless_{0}_{1}.yaml" -f $suffix, ([System.Guid]::NewGuid().ToString('N')))
        ($appIdLine + "`r`n---`r`n" + $body) | Set-Content -Encoding UTF8 $tmp
        $hooklessTemp += $tmp
        return $tmp
    }

    $runFlowCDE = New-HooklessFlow $flowCDE "cde"
    $runFlowRSE = New-HooklessFlow $flowRSE "rse"
    $runFlowHU  = New-HooklessFlow $flowHU  "hu"
}

Write-Host "Running 3 flows simultaneously across CDE/RSE/HU..."

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
        if ($line -match '^Will split .*shards') { continue }
        if ($line -match '^\[shard\s+\d+\]\s+Waiting for flows to complete\.\.\.$') { continue }

        $clean = $line -replace '^\[shard\s+\d+\]\s*', ''
        Write-Host $clean
    }

    if ($p.ExitCode -ne 0) {
        $maestroFailed = $true
        throw "Maestro failed with exit code $($p.ExitCode)"
    }
}
finally {
    Remove-Item -ErrorAction SilentlyContinue $outFile, $errFile
    if ($hooklessTemp.Count -gt 0) {
        if ($maestroFailed) {
            Write-Warning "Maestro failed. Keeping generated hookless flows for inspection:`n$($hooklessTemp -join "`n")"
        }
        else {
            Remove-Item -ErrorAction SilentlyContinue $hooklessTemp
        }
    }
}

Write-Host "All 3 device flows completed successfully."
