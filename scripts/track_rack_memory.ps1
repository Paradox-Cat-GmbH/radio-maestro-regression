param(
  [Parameter(Mandatory=$false)][string]$DeviceId = '169.254.166.167:5555',
  [Parameter(Mandatory=$false)][string]$Package = 'com.bmwgroup.idnext.wirelessservices',
  [Parameter(Mandatory=$false)][string[]]$Packages = @(),
  [Parameter(Mandatory=$false)][bool]$IncludeBluetoothService = $true,
  [Parameter(Mandatory=$false)][int]$IntervalSeconds = 5,
  [Parameter(Mandatory=$false)][int]$DurationMinutes = 15,
  [Parameter(Mandatory=$false)][string]$AdbPath = 'C:\Android\SDK\platform-tools\adb.exe',
  [Parameter(Mandatory=$false)][string]$OutputDir = ''
)

$ErrorActionPreference = 'Continue'

if (-not (Test-Path $AdbPath)) {
  throw "ADB not found at $AdbPath"
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
  $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
  $OutputDir = "C:\Users\DavidErikGarciaArena\Documents\GitHub\radio-maestro-regression\artifacts\memory_tracking\$ts"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$csvPath = Join-Path $OutputDir 'memory_samples.csv'
"timestamp,device,package,pid,mem_total_kb,mem_available_kb,total_pss_kb,private_dirty_kb,total_rss_kb,native_heap_size_kb,native_heap_alloc_kb" | Out-File -FilePath $csvPath -Encoding utf8

$effectivePackages = @()
if ($Packages -and $Packages.Count -gt 0) {
  $effectivePackages = $Packages
} else {
  $effectivePackages = @($Package)
}
if ($IncludeBluetoothService -and -not ($effectivePackages -contains 'com.android.bluetooth')) {
  $effectivePackages += 'com.android.bluetooth'
}
$effectivePackages = $effectivePackages | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique

if ($effectivePackages.Count -eq 0) {
  throw 'No package list resolved. Provide -Package or -Packages.'
}

$state = & $AdbPath -s $DeviceId get-state 2>$null
if (-not $state -or $state.Trim() -ne 'device') {
  throw "Device $DeviceId is not connected. Try: `"$AdbPath`" connect $DeviceId"
}

$endTime = (Get-Date).AddMinutes($DurationMinutes)

Write-Host "Tracking memory for packages on ${DeviceId}:"
$effectivePackages | ForEach-Object { Write-Host "  - $_" }
Write-Host "Output: $OutputDir"

while ((Get-Date) -lt $endTime) {
  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $safeStamp = (Get-Date -Format 'yyyyMMdd_HHmmss')

  $meminfoRaw = & $AdbPath -s $DeviceId shell cat /proc/meminfo
  $rawDir = Join-Path $OutputDir 'raw'
  New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
  $meminfoRaw | Out-File -FilePath (Join-Path $rawDir "meminfo_$safeStamp.txt") -Encoding utf8

  $memTotal = ''
  $memAvailable = ''

  if ($meminfoRaw) {
    $memTotal = (($meminfoRaw | Select-String '^MemTotal:\s+(\d+)').Matches.Groups[1].Value)
    $memAvailable = (($meminfoRaw | Select-String '^MemAvailable:\s+(\d+)').Matches.Groups[1].Value)
  }

  foreach ($pkg in $effectivePackages) {
    $dumpsysRaw = & $AdbPath -s $DeviceId shell dumpsys meminfo $pkg

    $processId = ''
    $pssTotal = ''
    $privateDirty = ''
    $totalRss = ''
    $heapSize = ''
    $heapAlloc = ''

    if ($dumpsysRaw) {
      $safePkg = ($pkg -replace '[^a-zA-Z0-9_\-]', '_')
      $dumpsysRaw | Out-File -FilePath (Join-Path $rawDir "dumpsys_meminfo_${safePkg}_$safeStamp.txt") -Encoding utf8

      $pidLine = $dumpsysRaw | Select-String '^\*\*\s+MEMINFO in pid\s+(\d+)\s+\[' | Select-Object -First 1
      if ($pidLine) {
        $processId = $pidLine.Matches.Groups[1].Value
      }

      # Match only numeric TOTAL process row (ignore header line "Total Dirty ...")
      $pssLine = $dumpsysRaw | Select-String -CaseSensitive '^\s*TOTAL\s+\d+' | Select-Object -First 1
      if ($pssLine) {
        $tokens = ($pssLine.ToString().Trim() -split '\s+')
        if ($tokens.Length -ge 6) {
          $pssTotal = $tokens[1]
          $privateDirty = $tokens[2]
          $totalRss = $tokens[5]
        }
      }

      # Native heap table row contains heap Size/Alloc columns at the end
      $nativeRow = $dumpsysRaw | Select-String '^\s*Native Heap\s+\d+' | Select-Object -First 1
      if ($nativeRow) {
        $nt = ($nativeRow.ToString().Trim() -split '\s+')
        if ($nt.Length -ge 8) {
          $heapSize = $nt[6]
          $heapAlloc = $nt[7]
        }
      }
    }

    "$stamp,$DeviceId,$pkg,$processId,$memTotal,$memAvailable,$pssTotal,$privateDirty,$totalRss,$heapSize,$heapAlloc" | Out-File -FilePath $csvPath -Append -Encoding utf8
  }

  Write-Host "[$stamp] sample captured for $($effectivePackages.Count) package(s)"
  Start-Sleep -Seconds $IntervalSeconds
}

Write-Host "Done. CSV: $csvPath"
