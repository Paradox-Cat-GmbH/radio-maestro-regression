param(
  [string]$ConfigPath = "scripts/g70_orchestrator.targets.json",
  [string]$OutRoot,
  [switch]$SkipConnect,
  [switch]$EnableMaestro,
  [string]$MaestroExe,
  [switch]$ContinueOnFailure,
  [switch]$OpenReport
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function New-RunId {
  return (Get-Date -Format 'yyyyMMdd_HHmmss')
}

function Invoke-Proc {
  param(
    [string]$FilePath,
    [string[]]$Args,
    [int]$TimeoutSec = 60,
    [string]$WorkingDirectory = $null
  )

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FilePath
  if ($Args) {
    foreach ($a in $Args) { [void]$psi.ArgumentList.Add($a) }
  }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()

  if (-not $p.WaitForExit($TimeoutSec * 1000)) {
    try { $p.Kill() } catch {}
    return [pscustomobject]@{ code = 124; out = ''; err = "timeout after ${TimeoutSec}s" }
  }

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  return [pscustomobject]@{ code = $p.ExitCode; out = $stdout.Trim(); err = $stderr.Trim() }
}

function Invoke-WithRetry {
  param(
    [scriptblock]$Action,
    [int]$Attempts = 2,
    [int]$DelayMs = 800
  )

  $last = $null
  for ($i = 1; $i -le $Attempts; $i++) {
    $last = & $Action
    if ($last.code -eq 0) {
      return [pscustomobject]@{ result = $last; attempts = $i }
    }
    Start-Sleep -Milliseconds $DelayMs
  }
  return [pscustomobject]@{ result = $last; attempts = $Attempts }
}

function Get-FirstMaestroPath {
  param([string]$Candidate)

  if ($Candidate -and (Test-Path $Candidate)) {
    return (Resolve-Path $Candidate).Path
  }

  $list = @(
    "$env:USERPROFILE\Desktop\maestro\bin\maestro.exe",
    "$env:USERPROFILE\Desktop\maestro\bin\maestro.bat",
    "$env:USERPROFILE\Desktop\maestro\bin\maestro.cmd"
  )

  foreach ($c in $list) {
    if (Test-Path $c) { return (Resolve-Path $c).Path }
  }

  $cmd = Get-Command maestro -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  return $null
}

$repoRoot = Resolve-RepoRoot
Set-Location $repoRoot

$cfgFullPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath } else { Join-Path $repoRoot $ConfigPath }
if (-not (Test-Path $cfgFullPath)) {
  throw "Config not found: $cfgFullPath"
}

$config = Get-Content $cfgFullPath -Raw | ConvertFrom-Json
$runId = New-RunId

if (-not $OutRoot) {
  $OutRoot = Join-Path $repoRoot "artifacts/g70_orchestrator/$runId"
}
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null

$adbBat = Join-Path $repoRoot 'scripts/adb.bat'
if (-not (Test-Path $adbBat)) { throw "Missing adb wrapper: $adbBat" }

$maestroPath = Get-FirstMaestroPath -Candidate $MaestroExe
if ($EnableMaestro -and -not $maestroPath) {
  throw "EnableMaestro was requested but Maestro executable was not found."
}

$continue = if ($PSBoundParameters.ContainsKey('ContinueOnFailure')) { [bool]$ContinueOnFailure } else { [bool]$config.continueOnFailure }
$connectRetries = [int]$config.connectRetries
$actionRetries = [int]$config.actionRetries
$connectTimeoutSec = [int]$config.connectTimeoutSec

$results = @()
$overallPass = $true

foreach ($target in $config.targets) {
  if (-not $target.enabled) { continue }

  $name = [string]$target.name
  $ip = [string]$target.ip
  $displayId = [string]$target.displayId
  $serial = "$ip`:5555"

  $targetOut = Join-Path $OutRoot $name
  New-Item -ItemType Directory -Force -Path $targetOut | Out-Null

  Write-Host ""
  Write-Host "[G70][$name] Target: $serial (display=$displayId)"

  $steps = @()
  $targetPass = $true

  if (-not $SkipConnect) {
    $connectCall = Invoke-WithRetry -Attempts $connectRetries -Action {
      Invoke-Proc -FilePath $adbBat -Args @('connect', $ip) -TimeoutSec $connectTimeoutSec
    }
    $steps += [pscustomobject]@{
      step = 'connect'; attempts = $connectCall.attempts; code = $connectCall.result.code
      out = $connectCall.result.out; err = $connectCall.result.err
    }
    if ($connectCall.result.code -ne 0) {
      $targetPass = $false
    }
  }

  $stateCall = Invoke-Proc -FilePath $adbBat -Args @('-s', $serial, 'get-state') -TimeoutSec 10
  $steps += [pscustomobject]@{ step='get-state'; attempts=1; code=$stateCall.code; out=$stateCall.out; err=$stateCall.err }

  if ($stateCall.code -ne 0 -or $stateCall.out -notmatch 'device') {
    $targetPass = $false
  }

  if ($targetPass) {
    $calendarPackage = [string]$config.actions.calendarPackage
    $remoteDump = ([string]$config.actions.remoteDumpTemplate).Replace('{name}', $name)
    $localDumpName = ([string]$config.actions.localDumpTemplate).Replace('{name}', $name)
    $localDump = Join-Path $targetOut $localDumpName

    $startCall = Invoke-WithRetry -Attempts $actionRetries -Action {
      Invoke-Proc -FilePath $adbBat -Args @('-s', $serial, 'shell', 'am', 'start', $calendarPackage, '--display', $displayId) -TimeoutSec 25
    }
    $steps += [pscustomobject]@{ step='calendar_start'; attempts=$startCall.attempts; code=$startCall.result.code; out=$startCall.result.out; err=$startCall.result.err }
    if ($startCall.result.code -ne 0) { $targetPass = $false }

    $dumpCall = Invoke-WithRetry -Attempts $actionRetries -Action {
      Invoke-Proc -FilePath $adbBat -Args @('-s', $serial, 'shell', 'uiautomator', 'dump', $remoteDump) -TimeoutSec 25
    }
    $steps += [pscustomobject]@{ step='uia_dump'; attempts=$dumpCall.attempts; code=$dumpCall.result.code; out=$dumpCall.result.out; err=$dumpCall.result.err }
    if ($dumpCall.result.code -ne 0) { $targetPass = $false }

    $pullCall = Invoke-WithRetry -Attempts $actionRetries -Action {
      Invoke-Proc -FilePath $adbBat -Args @('-s', $serial, 'pull', $remoteDump, $localDump) -TimeoutSec 25
    }
    $steps += [pscustomobject]@{ step='pull_dump'; attempts=$pullCall.attempts; code=$pullCall.result.code; out=$pullCall.result.out; err=$pullCall.result.err; localFile=$localDump }
    if ($pullCall.result.code -ne 0 -or -not (Test-Path $localDump)) { $targetPass = $false }

    $runMaestro = [bool]$config.actions.runMaestro -or $EnableMaestro
    if ($runMaestro) {
      $flowPath = [string]$config.actions.maestroFlow
      $fullFlowPath = if ([System.IO.Path]::IsPathRooted($flowPath)) { $flowPath } else { Join-Path $repoRoot $flowPath }

      if (-not (Test-Path $fullFlowPath)) {
        $steps += [pscustomobject]@{ step='maestro'; attempts=1; code=2; out=''; err="flow_not_found: $fullFlowPath" }
        $targetPass = $false
      } else {
        $debugOut = Join-Path $targetOut 'maestro_debug'
        $testOut = Join-Path $targetOut 'maestro_output'
        New-Item -ItemType Directory -Force -Path $debugOut, $testOut | Out-Null

        $maestroCall = Invoke-Proc -FilePath $maestroPath -Args @('--device', $serial, 'test', $fullFlowPath, '--format', 'NOOP', '--debug-output', $debugOut, '--test-output-dir', $testOut) -TimeoutSec 240
        $steps += [pscustomobject]@{ step='maestro'; attempts=1; code=$maestroCall.code; out=$maestroCall.out; err=$maestroCall.err; flow=$fullFlowPath }
        if ($maestroCall.code -ne 0) { $targetPass = $false }
      }
    }
  }

  $targetResult = [pscustomobject]@{
    name = $name
    ip = $ip
    serial = $serial
    displayId = $displayId
    pass = $targetPass
    steps = $steps
  }
  $results += $targetResult

  if (-not $targetPass) {
    $overallPass = $false
    if (-not $continue) { break }
  }
}

$report = [pscustomobject]@{
  runId = $runId
  runName = [string]$config.runName
  generatedAt = (Get-Date).ToString('o')
  repoRoot = $repoRoot
  configPath = $cfgFullPath
  overallPass = $overallPass
  continueOnFailure = $continue
  targets = $results
}

$reportJsonPath = Join-Path $OutRoot 'report.json'
$report | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $reportJsonPath

function New-HtmlReport {
  param($Report)

  $rows = foreach ($t in $Report.targets) {
    $status = if ($t.pass) { 'PASS' } else { 'FAIL' }
    $cls = if ($t.pass) { 'ok' } else { 'bad' }
    "<tr><td>$($t.name)</td><td>$($t.serial)</td><td>$($t.displayId)</td><td class='$cls'>$status</td><td>$([System.Web.HttpUtility]::HtmlEncode(($t.steps | ConvertTo-Json -Depth 5)))</td></tr>"
  }

  @"
<!doctype html>
<html>
<head>
  <meta charset='utf-8'>
  <title>G70 Orchestrator Report</title>
  <style>
    body { font-family: Segoe UI, Arial; margin: 16px; }
    table { border-collapse: collapse; width: 100%; }
    td, th { border: 1px solid #d0d0d0; padding: 8px; vertical-align: top; }
    th { background: #f2f2f2; }
    .ok { color: #0a8f3d; font-weight: 700; }
    .bad { color: #c62020; font-weight: 700; }
    pre { white-space: pre-wrap; }
  </style>
</head>
<body>
  <h1>G70 Multi-Target PoC Report</h1>
  <p><b>runId:</b> $($Report.runId)</p>
  <p><b>generatedAt:</b> $($Report.generatedAt)</p>
  <p><b>overall:</b> <span class='$(if($Report.overallPass){'ok'}else{'bad'})'>$(if($Report.overallPass){'PASS'}else{'FAIL'})</span></p>
  <table>
    <thead>
      <tr><th>Target</th><th>Serial</th><th>Display</th><th>Status</th><th>Steps (JSON)</th></tr>
    </thead>
    <tbody>
      $($rows -join "`n")
    </tbody>
  </table>
</body>
</html>
"@
}

Add-Type -AssemblyName System.Web
$reportHtmlPath = Join-Path $OutRoot 'report.html'
New-HtmlReport -Report $report | Set-Content -Encoding UTF8 $reportHtmlPath

$zipPath = Join-Path (Split-Path $OutRoot -Parent) "$runId.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path (Join-Path $OutRoot '*') -DestinationPath $zipPath

Write-Host ""
Write-Host "[G70] Run complete"
Write-Host "[G70] Output directory: $OutRoot"
Write-Host "[G70] JSON report: $reportJsonPath"
Write-Host "[G70] HTML report: $reportHtmlPath"
Write-Host "[G70] ZIP bundle:  $zipPath"

if ($OpenReport) {
  Start-Process $reportHtmlPath | Out-Null
}

if ($overallPass) { exit 0 } else { exit 1 }
