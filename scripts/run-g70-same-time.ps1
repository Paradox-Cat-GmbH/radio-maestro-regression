param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId,
    [string]$DeviceA,
    [string]$DeviceB
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$flowA = Join-Path $RepoRoot "flows\g70\testcases\$CaseId\deviceA.yaml"
$flowB = Join-Path $RepoRoot "flows\g70\testcases\$CaseId\deviceB.yaml"

if (-not (Test-Path $flowA)) { throw "Missing flow: $flowA" }
if (-not (Test-Path $flowB)) { throw "Missing flow: $flowB" }

$runner = Join-Path $ScriptDir "run-same-time.ps1"
if (-not (Test-Path $runner)) { throw "Missing runner: $runner" }

& $runner -DeviceA $DeviceA -DeviceB $DeviceB -TestA $flowA -TestB $flowB
