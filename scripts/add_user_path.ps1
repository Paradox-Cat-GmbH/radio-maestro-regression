<#
Adds specified directories to the User PATH if they exist and are not already present.
Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\add_user_path.ps1
#>

$toAdd = @(
  'C:\Android\jbr\bin',
  'C:\Program Files\nodejs',
  'C:\Users\DavidErikGarciaArena\Desktop\maestro',
  'C:\Users\DavidErikGarciaArena\AppData\Local\Programs\Maestro Studio'
)

Write-Host "Reading current User PATH..."
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
$initial = $userPath
$added = @()

foreach ($p in $toAdd) {
  if (-not [string]::IsNullOrWhiteSpace($p)) {
    if (Test-Path $p) {
      if ($userPath -and $userPath.IndexOf($p, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        Write-Host "Already present: $p"
      } else {
        if ($userPath) { $userPath = $userPath + ';' + $p } else { $userPath = $p }
        Write-Host "Added: $p"
        $added += $p
      }
    } else {
      Write-Host "Not found (skipping): $p"
    }
  }
}

if ($added.Count -gt 0) {
  Write-Host "Updating User PATH..."
  [Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
  # Refresh current process PATH to include new user entries + machine PATH
  $machine = [Environment]::GetEnvironmentVariable('Path','Machine')
  if ($machine) { $env:Path = $userPath + ';' + $machine } else { $env:Path = $userPath }
  Write-Host "User PATH updated. Restart terminals to pick changes globally."
} else {
  Write-Host "No additions were necessary."
}

Write-Host "--- Verification (current process) ---"
try { Write-Host "node:"; node --version } catch { Write-Host "node: not found or failed" }
try { Write-Host "java:"; & java -version } catch { Write-Host "java: not found or failed" }
try { Write-Host "maestro (where):"; where maestro } catch { Write-Host "maestro: not found or failed" }

Write-Host "--- New user PATH (preview) ---"
Write-Host $userPath
