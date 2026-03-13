param(
  [Parameter(Mandatory=$false)]
  [string]$DeviceId,
  [Parameter(Mandatory=$false)]
  [string]$Label = "screen",
  [Parameter(Mandatory=$false)]
  [string]$OutDir
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$adb = Join-Path $PSScriptRoot 'adb.bat'
if (-not (Test-Path $adb)) {
  throw "adb wrapper not found: $adb"
}

function Run-Adb {
  param([string[]]$CommandArgs)
  $allArgs = @()
  if ($DeviceId) {
    $allArgs += @('-s', $DeviceId)
  }
  $allArgs += $CommandArgs
  & $adb @allArgs
  if ($LASTEXITCODE -ne 0) {
    throw "ADB command failed (exit $LASTEXITCODE): $($allArgs -join ' ')"
  }
}

function Run-Adb-CaptureOutput {
  param([string[]]$CommandArgs)
  $allArgs = @()
  if ($DeviceId) {
    $allArgs += @('-s', $DeviceId)
  }
  $allArgs += $CommandArgs
  $out = & $adb @allArgs 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "ADB command failed (exit $LASTEXITCODE): $($allArgs -join ' ')`n$out"
  }
  return $out
}

if (-not $DeviceId) {
  $devicesRaw = Run-Adb-CaptureOutput -CommandArgs @('devices')
  $deviceLine = $devicesRaw -split "`r?`n" | Where-Object { $_ -match '^\S+\s+device$' } | Select-Object -First 1
  if (-not $deviceLine) {
    throw 'No connected ADB device found. Provide -DeviceId.'
  }
  $DeviceId = ($deviceLine -split '\s+')[0]
}

$safeLabel = ($Label -replace '[^A-Za-z0-9_.-]','_')
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if (-not $OutDir) {
  $OutDir = Join-Path $repoRoot ("artifacts\idc23_ui_map\$stamp`_$safeLabel")
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$remotePng = '/sdcard/idc23_screen_dump.png'
$remoteXml = '/sdcard/idc23_window_dump.xml'
$remoteXmlFallback = '/sdcard/window_dump.xml'
$localPng = Join-Path $OutDir ("$safeLabel.png")
$localXml = Join-Path $OutDir ("$safeLabel.xml")
$localTopDump = Join-Path $OutDir ("$safeLabel.dumpsys_activity_top.txt")
$localWindowDump = Join-Path $OutDir ("$safeLabel.dumpsys_window.txt")
$localMediaDump = Join-Path $OutDir ("$safeLabel.dumpsys_media_session.txt")
$summaryJson = Join-Path $OutDir ("$safeLabel.summary.json")
$summaryTxt = Join-Path $OutDir ("$safeLabel.summary.txt")
$idsCsv = Join-Path $OutDir ("$safeLabel.ids.csv")

# Capture screenshot and UI hierarchy
Run-Adb -CommandArgs @('shell','screencap','-p',$remotePng)
Run-Adb -CommandArgs @('pull',$remotePng,$localPng)

$uiDumpAvailable = $true
try {
  Run-Adb -CommandArgs @('shell','uiautomator','dump',$remoteXml)
  if ((Run-Adb-CaptureOutput -CommandArgs @('shell','ls','-l',$remoteXml) | Out-String) -match [regex]::Escape($remoteXml)) {
    Run-Adb -CommandArgs @('pull',$remoteXml,$localXml)
  } elseif ((Run-Adb-CaptureOutput -CommandArgs @('shell','ls','-l',$remoteXmlFallback) | Out-String) -match [regex]::Escape($remoteXmlFallback)) {
    Run-Adb -CommandArgs @('pull',$remoteXmlFallback,$localXml)
  }
} catch {
  $uiDumpAvailable = $false
}

if (-not (Test-Path $localXml)) {
  $uiDumpAvailable = $false
  $rawUi = ''
  try {
    $rawUi = Run-Adb-CaptureOutput -CommandArgs @('exec-out','uiautomator','dump','/dev/tty')
  } catch {
    $rawUi = ''
  }
  if ($rawUi -match '<\?xml') {
    $xmlStart = $rawUi.IndexOf('<?xml')
    if ($xmlStart -ge 0) {
      $xmlRaw = $rawUi.Substring($xmlStart)
      $xmlRaw | Set-Content -Path $localXml -Encoding UTF8
      $uiDumpAvailable = $true
    }
  }
}

# Always capture textual dumps for mapping support
$topDump = Run-Adb-CaptureOutput -CommandArgs @('shell','dumpsys','activity','top')
$winDump = Run-Adb-CaptureOutput -CommandArgs @('shell','dumpsys','window')
$mediaDump = Run-Adb-CaptureOutput -CommandArgs @('shell','dumpsys','media_session')
$topDump | Set-Content -Path $localTopDump -Encoding UTF8
$winDump | Set-Content -Path $localWindowDump -Encoding UTF8
$mediaDump | Set-Content -Path $localMediaDump -Encoding UTF8

# Best effort cleanup on device
try { Run-Adb -CommandArgs @('shell','rm','-f',$remotePng,$remoteXml,$remoteXmlFallback) } catch { }

[xml]$xml = $null
$nodes = @()
if ($uiDumpAvailable -and (Test-Path $localXml)) {
  try {
    [xml]$xml = Get-Content -Path $localXml -Raw
    $nodes = @($xml.SelectNodes('//node'))
  } catch {
    $uiDumpAvailable = $false
    $nodes = @()
  }
}

$flattened = foreach ($n in $nodes) {
  [pscustomobject]@{
    resourceId = [string]$n.'resource-id'
    text       = [string]$n.text
    desc       = [string]$n.'content-desc'
    class      = [string]$n.class
    clickable  = [string]$n.clickable
    enabled    = [string]$n.enabled
    bounds     = [string]$n.bounds
  }
}

$interesting = $flattened | Where-Object {
  -not [string]::IsNullOrWhiteSpace($_.resourceId) -or
  -not [string]::IsNullOrWhiteSpace($_.text) -or
  -not [string]::IsNullOrWhiteSpace($_.desc)
}

$uniqueIds = $interesting |
  Where-Object { -not [string]::IsNullOrWhiteSpace($_.resourceId) } |
  Group-Object resourceId |
  Sort-Object Name |
  ForEach-Object {
    [pscustomobject]@{
      resourceId = $_.Name
      count      = $_.Count
      sampleText = ($_.Group | Where-Object { $_.text } | Select-Object -First 1 -ExpandProperty text)
      sampleDesc = ($_.Group | Where-Object { $_.desc } | Select-Object -First 1 -ExpandProperty desc)
    }
  }

$topTexts = $interesting |
  Where-Object { -not [string]::IsNullOrWhiteSpace($_.text) } |
  Group-Object text |
  Sort-Object Count -Descending |
  Select-Object -First 40 |
  ForEach-Object {
    [pscustomobject]@{ text = $_.Name; count = $_.Count }
  }

$summary = [pscustomobject]@{
  deviceId = $DeviceId
  label = $Label
  stamp = (Get-Date).ToString('o')
  outDir = $OutDir
  screenshot = $localPng
  uiDumpXml = $(if (Test-Path $localXml) { $localXml } else { $null })
  uiDumpAvailable = $uiDumpAvailable
  dumpsysActivityTop = $localTopDump
  dumpsysWindow = $localWindowDump
  dumpsysMediaSession = $localMediaDump
  totalNodes = $nodes.Count
  interestingNodes = $interesting.Count
  uniqueResourceIds = $uniqueIds.Count
  topResourceIds = $uniqueIds | Select-Object -First 120
  topTexts = $topTexts
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryJson -Encoding UTF8
$uniqueIds | Export-Csv -Path $idsCsv -NoTypeInformation -Encoding UTF8

$lines = @()
$lines += "IDC23 UI Dump"
$lines += "Device: $DeviceId"
$lines += "Label: $Label"
$lines += "Time:  $(Get-Date -Format o)"
$lines += ""
$lines += "Screenshot: $localPng"
$lines += "UI XML:      $(if (Test-Path $localXml) { $localXml } else { 'NOT_AVAILABLE (uiautomator dump blocked/empty)' })"
$lines += "Activity top: $localTopDump"
$lines += "Window dump:  $localWindowDump"
$lines += "Media dump:   $localMediaDump"
$lines += "Summary:     $summaryJson"
$lines += "IDs CSV:     $idsCsv"
$lines += ""
$lines += "Total nodes: $($nodes.Count)"
$lines += "Interesting nodes: $($interesting.Count)"
$lines += "Unique resource IDs: $($uniqueIds.Count)"
$lines += ""
$lines += "Top resource IDs (first 40):"
$lines += ($uniqueIds | Select-Object -First 40 | ForEach-Object { "- $($_.resourceId) [count=$($_.count)] text='$($_.sampleText)' desc='$($_.sampleDesc)'" })
$lines += ""
$lines += "Top text labels (first 30):"
$lines += ($topTexts | Select-Object -First 30 | ForEach-Object { "- '$($_.text)' [count=$($_.count)]" })
$lines | Set-Content -Path $summaryTxt -Encoding UTF8

Write-Host "[OK] Dump complete: $OutDir"
Write-Host "[OK] Screenshot: $localPng"
Write-Host "[OK] XML: $localXml"
Write-Host "[OK] Summary: $summaryTxt"