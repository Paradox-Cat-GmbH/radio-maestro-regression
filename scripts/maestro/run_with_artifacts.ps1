param(
  [string]$DeviceId,
  [string]$Target,
  [string[]]$FlowList,
  [switch]$NoVideo,
  [string]$RunId,
  [string]$MaestroExe
)

$ErrorActionPreference = 'Stop'

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

function Get-IntEnv {
  param([string]$Name, [int]$Default)
  $raw = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
  $parsed = 0
  if ([int]::TryParse($raw.Trim(), [ref]$parsed)) { return $parsed }
  return $Default
}

function Split-Commands {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
  return ($Value -split '\|\||\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Resolve-MaestroExe {
  param([string]$Candidate)

  if ($Candidate -and (Test-Path $Candidate)) {
    return (Resolve-Path $Candidate).Path
  }

  if ($env:MAESTRO_CMD -and (Test-Path $env:MAESTRO_CMD)) {
    return (Resolve-Path $env:MAESTRO_CMD).Path
  }

  $desktopCandidates = @(
    "$env:USERPROFILE\\Desktop\\maestro\\bin\\maestro.exe",
    "$env:USERPROFILE\\Desktop\\maestro\\bin\\maestro.cmd",
    "$env:USERPROFILE\\Desktop\\maestro\\bin\\maestro.bat"
  )
  foreach ($path in $desktopCandidates) {
    if (Test-Path $path) {
      return (Resolve-Path $path).Path
    }
  }

  $where = Get-Command maestro -ErrorAction SilentlyContinue
  if ($where) {
    return $where.Source
  }

  throw 'Maestro CLI not found. Install Maestro or set MAESTRO_CMD.'
}

function Resolve-DeviceId {
  param([string]$Candidate, [string]$RepoRoot)

  if ($Candidate) {
    return $Candidate
  }

  if ($env:ANDROID_SERIAL) {
    return $env:ANDROID_SERIAL
  }

  $adb = Join-Path $RepoRoot 'scripts\adb.bat'
  if (-not (Test-Path $adb)) {
    throw 'Missing scripts\adb.bat and no DEVICE_ID provided.'
  }

  $lines = & $adb devices | ForEach-Object { $_.Trim() }
  foreach ($line in $lines) {
    if ($line -match '^(\S+)\s+device$') {
      return $Matches[1]
    }
  }

  throw 'No connected device found. Pass -DeviceId or set ANDROID_SERIAL.'
}

function Resolve-Flows {
  param([string]$RepoRoot, [string]$Target, [string[]]$FlowList)

  if ($FlowList -and $FlowList.Count -gt 0) {
    $resolved = @()
    foreach ($flow in $FlowList) {
      $path = if ([System.IO.Path]::IsPathRooted($flow)) { $flow } else { Join-Path $RepoRoot $flow }
      if (-not (Test-Path $path -PathType Leaf)) {
        throw "Flow not found: $flow"
      }
      $resolved += (Resolve-Path $path).Path
    }
    return $resolved
  }

  if (-not $Target) {
    throw 'Provide -Target (flow file or folder) or -FlowList.'
  }

  $resolvedTarget = if ([System.IO.Path]::IsPathRooted($Target)) { $Target } else { Join-Path $RepoRoot $Target }
  if (-not (Test-Path $resolvedTarget)) {
    throw "Target not found: $Target"
  }

  if (Test-Path $resolvedTarget -PathType Leaf) {
    return @((Resolve-Path $resolvedTarget).Path)
  }

  $flows = Get-ChildItem $resolvedTarget -Filter '*.yaml' -File | Sort-Object Name | ForEach-Object { $_.FullName }
  if (-not $flows -or $flows.Count -eq 0) {
    throw "No YAML flows found under: $resolvedTarget"
  }
  return $flows
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

$maestro = Resolve-MaestroExe -Candidate $MaestroExe
$device = Resolve-DeviceId -Candidate $DeviceId -RepoRoot $repoRoot
$flows = Resolve-Flows -RepoRoot $repoRoot -Target $Target -FlowList $FlowList

$runStamp = if ($RunId) { $RunId } else { Get-Date -Format 'yyyyMMdd_HHmmss' }
$runRoot = Join-Path (Join-Path $repoRoot 'artifacts\\runs') $runStamp
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$env:ANDROID_SERIAL = $device
if (-not $env:MAESTRO_CONTROL_HOST) { $env:MAESTRO_CONTROL_HOST = '127.0.0.1' }
if (-not $env:MAESTRO_CONTROL_PORT) { $env:MAESTRO_CONTROL_PORT = '4567' }
if (-not $env:MAESTRO_BACKEND_URL) { $env:MAESTRO_BACKEND_URL = 'http://127.0.0.1:4567' }
if (-not $env:MAESTRO_RADIO_PACKAGE) { $env:MAESTRO_RADIO_PACKAGE = 'com.bmwgroup.apinext.tunermediaservice' }
if (-not $env:MAESTRO_RAND_MAX_INDEX) { $env:MAESTRO_RAND_MAX_INDEX = '5' }

$ensureServer = Join-Path $repoRoot 'scripts\control_server\ensure_server.bat'
cmd /c "`"$ensureServer`""
if ($LASTEXITCODE -ne 0) {
  throw "Failed to start control server (exit $LASTEXITCODE)."
}

$globalPrepEnabled = Get-BoolEnv -Name 'MAESTRO_GLOBAL_PRECONDITIONS_ENABLED' -Default $false
$keepEvidenceOnPass = Get-BoolEnv -Name 'MAESTRO_KEEP_EVIDENCE_ON_PASS' -Default $true
if ($globalPrepEnabled) {
  $prepBase = $env:MAESTRO_BACKEND_URL
  if ([string]::IsNullOrWhiteSpace($prepBase)) { $prepBase = 'http://127.0.0.1:4567' }
  $prepUrl = $prepBase.TrimEnd('/') + '/ediabas/str-prep'

  $beforeDefault = 'setprop persist.vendor.com.bmwgroup.disable_cid_ehh true||setprop persist.vendor.com.bmwgroup.disable_phud_ehh true'
  $afterDefault = 'getprop persist.vendor.com.bmwgroup.disable_cid_ehh||getprop persist.vendor.com.bmwgroup.disable_phud_ehh'

  $beforeRaw = [Environment]::GetEnvironmentVariable('MAESTRO_PREP_BEFORE_SHELL')
  $afterRaw = [Environment]::GetEnvironmentVariable('MAESTRO_PREP_AFTER_SHELL')

  $prepPayload = @{
    testId = 'global_preconditions'
    enabled = $true
    reboot = (Get-BoolEnv -Name 'MAESTRO_PREP_REBOOT' -Default $true)
    timeoutSeconds = (Get-IntEnv -Name 'MAESTRO_PREP_TIMEOUT_SECONDS' -Default 30)
    postRebootDelaySeconds = (Get-IntEnv -Name 'MAESTRO_PREP_POST_REBOOT_DELAY_SECONDS' -Default 35)
    beforeShell = (Split-Commands -Value ($(if ([string]::IsNullOrWhiteSpace($beforeRaw)) { $beforeDefault } else { $beforeRaw })))
    afterShell = (Split-Commands -Value ($(if ([string]::IsNullOrWhiteSpace($afterRaw)) { $afterDefault } else { $afterRaw })))
    deviceId = $device
  }

  Write-Host "[INFO] Running global preconditions..."
  $prepResp = Invoke-RestMethod -Method Post -Uri $prepUrl -ContentType 'application/json' -Body ($prepPayload | ConvertTo-Json -Depth 8 -Compress)
  if (-not $prepResp.ok) {
    throw "Global preconditions failed. Response: $($prepResp | ConvertTo-Json -Depth 8 -Compress)"
  }
  Write-Host "[OK] Global preconditions completed."
}

$help = (& $maestro --help 2>&1 | Out-String)
$supportsDeviceFlag = $help -match '--device'

$failedFlows = @()

Write-Host "[INFO] Device: $device"
Write-Host "[INFO] Maestro: $maestro"
Write-Host "[INFO] Run root: $runRoot"
Write-Host "[INFO] Flow count: $($flows.Count)"
Write-Host "[INFO] Keep evidence on pass: $keepEvidenceOnPass"

foreach ($flow in $flows) {
  $flowName = [System.IO.Path]::GetFileNameWithoutExtension($flow)
  $flowRoot = Join-Path $runRoot $flowName
  $debugDir = Join-Path $flowRoot 'debug'
  $outputDir = Join-Path $flowRoot 'output'
  $videoDir = Join-Path $flowRoot 'videos'
  $recordDebugDir = Join-Path $flowRoot 'record_debug'

  New-Item -ItemType Directory -Force -Path $debugDir, $outputDir, $videoDir, $recordDebugDir | Out-Null

  Write-Host ""
  Write-Host "[RUN] $flow"
  Write-Host "[RUN] debug: $debugDir"
  Write-Host "[RUN] output: $outputDir"

  $testArgs = @('test', $flow, '--format', 'NOOP', '--debug-output', $debugDir, '--test-output-dir', $outputDir)
  if ($supportsDeviceFlag) {
    $cmdArgs = @('--device', $device) + $testArgs
  } else {
    $cmdArgs = $testArgs
  }

  & $maestro @cmdArgs
  $testExit = $LASTEXITCODE
  if ($testExit -ne 0) {
    Write-Host "[FAIL] Test failed: $flow (exit $testExit)"
    $failedFlows += $flow
    continue
  }

  $flowPassed = $true

  if (-not $NoVideo) {
    $videoPath = Join-Path $videoDir ("{0}.mp4" -f $flowName)
    Write-Host "[RUN] record: $videoPath"

    $recordArgs = @('record', '--local', $flow, $videoPath, '--debug-output', $recordDebugDir)
    if ($supportsDeviceFlag) {
      $recordCmdArgs = @('--device', $device) + $recordArgs
    } else {
      $recordCmdArgs = $recordArgs
    }

    & $maestro @recordCmdArgs
    $recordExit = $LASTEXITCODE
    if ($recordExit -ne 0) {
      Write-Host "[WARN] Video recording failed for $flow (exit $recordExit)"
    }
  }

  if ($flowPassed -and -not $keepEvidenceOnPass) {
    Write-Host "[INFO] Pruning pass artifacts for $flowName (MAESTRO_KEEP_EVIDENCE_ON_PASS=false)"
    foreach ($dir in @($debugDir, $outputDir, $videoDir, $recordDebugDir)) {
      if (Test-Path $dir) {
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
    $pruneMarker = Join-Path $flowRoot 'pass_pruned.txt'
    "Pass artifacts pruned at $(Get-Date -Format o)" | Set-Content -Encoding UTF8 $pruneMarker
  }
}

Write-Host ""
Write-Host "[INFO] Artifacts saved in: $runRoot"

if ($failedFlows.Count -gt 0) {
  Write-Host "[ERROR] Failed flows:"
  foreach ($flow in $failedFlows) {
    Write-Host "  - $flow"
  }
  exit 1
}

Write-Host "[OK] All requested flows finished successfully."
exit 0
