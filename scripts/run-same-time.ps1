param(
    [string]$DeviceA,
    [string]$DeviceB,
    [string]$TestA = "Test1.yaml",
    [string]$TestB = "Test2.yaml"
)

$ErrorActionPreference = "Stop"

# Resolve repo root from script location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$TestAPath = if ([System.IO.Path]::IsPathRooted($TestA)) { $TestA } else { Join-Path $RepoRoot $TestA }
$TestBPath = if ([System.IO.Path]::IsPathRooted($TestB)) { $TestB } else { Join-Path $RepoRoot $TestB }

$TestAPath = (Resolve-Path -LiteralPath $TestAPath).Path
$TestBPath = (Resolve-Path -LiteralPath $TestBPath).Path

Write-Host "Connected devices from ADB:"
$adbList = adb devices -l
$adbList | ForEach-Object { Write-Host $_ }

# Parse online device serials dynamically from `adb devices -l`
$connected = @()
foreach ($line in $adbList) {
    if ($line -match '^(\S+)\s+device\b') {
        $connected += $matches[1]
    }
}

if ($connected.Count -lt 2) {
    throw "Need at least 2 connected devices in 'device' state. Found: $($connected.Count)"
}

# Optional parameters: auto-pick if missing
if (-not $DeviceA) { $DeviceA = $connected[0] }
if (-not $DeviceB) { $DeviceB = $connected[1] }

# Validate when provided/selected
if (-not ($connected -contains $DeviceA)) {
    throw "DeviceA not found in adb connected list: '$DeviceA'. Connected: $($connected -join ', ')"
}
if (-not ($connected -contains $DeviceB)) {
    throw "DeviceB not found in adb connected list: '$DeviceB'. Connected: $($connected -join ', ')"
}
if ($DeviceA -eq $DeviceB) {
    throw "DeviceA and DeviceB cannot be the same serial."
}

Write-Host "Using DeviceA: $DeviceA"
Write-Host "Using DeviceB: $DeviceB"

# Single Maestro process: stable simultaneous run on both devices
$deviceList = "$DeviceA,$DeviceB"

Write-Host "Running both flows simultaneously on both devices..."

$outFile = [System.IO.Path]::GetTempFileName()
$errFile = [System.IO.Path]::GetTempFileName()

try {
    $p = Start-Process -FilePath "maestro" `
        -ArgumentList @("test", "--no-ansi", "--device", $deviceList, "--shard-split", "2", $TestAPath, $TestBPath) `
        -NoNewWindow -PassThru -Wait `
        -RedirectStandardOutput $outFile `
        -RedirectStandardError $errFile

    $lines = @()
    if (Test-Path $outFile) { $lines += Get-Content $outFile }
    if (Test-Path $errFile) { $lines += Get-Content $errFile }

    foreach ($line in $lines) {
        if ($line -match '^Will split .*shards') { continue }
        if ($line -match '^\[shard\s+\d+\]\s+Waiting for flows to complete\.\.\.$') { continue }

        $clean = $line `
            -replace '^\[shard\s+\d+\]\s*', '' `
            -replace '\bshard\b', 'device run' `
            -replace '\bshards\b', 'device runs'

        Write-Host $clean
    }

    if ($p.ExitCode -ne 0) {
        throw "Maestro failed with exit code $($p.ExitCode)"
    }
}
finally {
    Remove-Item -ErrorAction SilentlyContinue $outFile, $errFile
}

Write-Host "Both screenshot flows completed successfully."
