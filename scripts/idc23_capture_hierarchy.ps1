param(
  [Parameter(Mandatory=$false)]
  [string]$DeviceId = "169.254.8.177:5555",
  [Parameter(Mandatory=$true)]
  [string]$Label
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$safeLabel = ($Label -replace '[^A-Za-z0-9_.-]','_')
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = Join-Path $repoRoot ("artifacts\idc23_ui_map\{0}_{1}" -f $stamp, $safeLabel)
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$adb = Join-Path $PSScriptRoot 'adb.bat'
if (-not (Test-Path $adb)) {
  throw "Missing adb wrapper: $adb"
}

# Resolve Maestro CLI
$maestroCandidates = @(
  $env:MAESTRO_CMD,
  'C:\Project Maestro\maestro\bin\maestro.bat',
  'C:\Project Maestro\maestro\bin\maestro.exe',
  "$env:USERPROFILE\Desktop\maestro\bin\maestro.bat",
  "$env:USERPROFILE\Desktop\maestro\bin\maestro.exe"
) | Where-Object { $_ -and $_.Trim() -ne '' }

$maestro = $null
foreach($c in $maestroCandidates){
  if(Test-Path $c){ $maestro = $c; break }
}
if(-not $maestro){
  $cmd = Get-Command maestro -ErrorAction SilentlyContinue
  if($cmd){ $maestro = $cmd.Source }
}
if(-not $maestro){
  throw 'Maestro CLI not found. Set MAESTRO_CMD or install Maestro CLI.'
}

# Ensure device connection + root
& $adb connect $DeviceId | Out-Null
& $adb -s $DeviceId root | Out-Null
Start-Sleep -Seconds 2
& $adb connect $DeviceId | Out-Null
& $adb -s $DeviceId wait-for-device | Out-Null
& $adb -s $DeviceId shell 'echo ready' | Out-Null

# 1) Full UI dump (screenshot + xml + dumpsys)
$dumpScript = Join-Path $PSScriptRoot 'idc23_dump_screen.ps1'
if (-not (Test-Path $dumpScript)) {
  throw "Missing script: $dumpScript"
}

powershell -NoProfile -ExecutionPolicy Bypass -File $dumpScript -DeviceId $DeviceId -Label $safeLabel -OutDir $outDir

# 2) Maestro hierarchy exports (compact CSV + JSON)
$compactCsv = Join-Path $outDir ("{0}.maestro.hierarchy.compact.csv" -f $safeLabel)
$jsonOut = Join-Path $outDir ("{0}.maestro.hierarchy.json" -f $safeLabel)
$hierErr = Join-Path $outDir ("{0}.maestro.hierarchy.error.txt" -f $safeLabel)

function Invoke-MaestroHierarchy {
  param(
    [switch]$Compact,
    [string]$OutputFile,
    [int]$Retries = 2
  )

  for($i=1; $i -le $Retries; $i++) {
    $args = @('--device', $DeviceId, 'hierarchy')
    if($Compact) { $args += '--compact' }

    $out = (& $maestro @args 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE

    if($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($out)) {
      if($Compact) {
        if($out -match 'element_num,depth,attributes,parent_num') {
          $out | Set-Content -Path $OutputFile -Encoding UTF8
          return $true
        }
      } else {
        if($out -match '"attributes"|attributes=') {
          $out | Set-Content -Path $OutputFile -Encoding UTF8
          return $true
        }
      }
    }

    Start-Sleep -Seconds (2 * $i)
    & $adb connect $DeviceId | Out-Null
    & $adb -s $DeviceId wait-for-device | Out-Null
  }

  return $false
}

$compactOk = Invoke-MaestroHierarchy -Compact -OutputFile $compactCsv
$jsonOk = Invoke-MaestroHierarchy -OutputFile $jsonOut

if(-not $compactOk -or -not $jsonOk) {
  @(
    "Maestro hierarchy export had failures.",
    "compactOk=$compactOk",
    "jsonOk=$jsonOk",
    "time=$(Get-Date -Format o)"
  ) | Set-Content -Path $hierErr -Encoding UTF8
}

# 3) Quick summary
$summary = Join-Path $outDir ("{0}.capture.summary.txt" -f $safeLabel)
$lines = @(
  "IDC23 capture bundle",
  "Label: $safeLabel",
  "Device: $DeviceId",
  "Time:  $(Get-Date -Format o)",
  "",
  "Dir: $outDir",
  "Compact hierarchy: $compactCsv",
  "JSON hierarchy:    $jsonOut",
  "Hierarchy error:   $hierErr"
)
$lines | Set-Content -Path $summary -Encoding UTF8

Write-Host "[OK] Capture bundle ready: $outDir"
Write-Host "[OK] Compact hierarchy: $compactCsv"
Write-Host "[OK] JSON hierarchy: $jsonOut"
Write-Host "[OK] Summary: $summary"