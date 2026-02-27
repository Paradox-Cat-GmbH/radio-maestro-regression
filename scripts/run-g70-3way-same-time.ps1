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
$script:hooklessTemp = @()
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
        $content = $appIdLine + "`r`n---`r`n" + $body
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($tmp, $content, $utf8NoBom)

        $script:hooklessTemp += $tmp
        Write-Host "Generated hookless flow: $tmp"
        return $tmp
    }

    $runFlowCDE = New-HooklessFlow $flowCDE "cde"
    $runFlowRSE = New-HooklessFlow $flowRSE "rse"
    $runFlowHU  = New-HooklessFlow $flowHU  "hu"
}

Write-Host "Running 3 flows in parallel (separate Maestro processes) across CDE/RSE/HU..."

$jobs = @(
    @{ Name = 'CDE'; Device = $CDE; Flow = $runFlowCDE },
    @{ Name = 'RSE'; Device = $RSE; Flow = $runFlowRSE },
    @{ Name = 'HU';  Device = $HU;  Flow = $runFlowHU  }
)

$procs = @()
try {
    foreach ($j in $jobs) {
        $outFile = [System.IO.Path]::GetTempFileName()
        $errFile = [System.IO.Path]::GetTempFileName()

        Write-Host "[$($j.Name)] Starting: maestro test --no-ansi --device $($j.Device) $($j.Flow)"
        $p = Start-Process -FilePath "maestro" `
            -ArgumentList @("test", "--no-ansi", "--device", $j.Device, $j.Flow) `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput $outFile `
            -RedirectStandardError $errFile

        $procs += @{ Name = $j.Name; Device = $j.Device; Flow = $j.Flow; Proc = $p; Out = $outFile; Err = $errFile }
    }

    foreach ($item in $procs) {
        $item.Proc.WaitForExit()
        Write-Host "[$($item.Name)] ExitCode: $($item.Proc.ExitCode)"

        $lines = @()
        if (Test-Path $item.Out) { $lines += Get-Content $item.Out }
        if (Test-Path $item.Err) { $lines += Get-Content $item.Err }

        foreach ($line in $lines) {
            Write-Host "[$($item.Name)] $line"
        }

        if ($item.Proc.ExitCode -ne 0) { $maestroFailed = $true }
    }

    if ($maestroFailed) {
        throw "One or more Maestro flows failed in parallel run"
    }
}
finally {
    foreach ($item in $procs) {
        Remove-Item -ErrorAction SilentlyContinue $item.Out, $item.Err
    }

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
