<#
Interactive helper to detect Maestro CLI and set MAESTRO_CMD.
Run from PowerShell in the repo root:
  .\scripts\setup_maestro.ps1
#>

function Test-MaestroPath($p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    $f = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
    if ($null -ne $f -and -not $f.PSIsContainer) { return $true }
    return $false
}

Write-Host "Detecting Maestro CLI..."

$envVal = $env:MAESTRO_CMD
if ($envVal) {
    Write-Host "MAESTRO_CMD currently set to: $envVal"
    if (Test-MaestroPath $envVal) {
        Write-Host "Found file at MAESTRO_CMD."
        exit 0
    } else {
        Write-Host "MAESTRO_CMD does not point to an existing file."
    }
}

Write-Host "Checking PATH for 'maestro'..."
try {
    $which = (Get-Command maestro -ErrorAction SilentlyContinue)
} catch { $which = $null }
if ($which) {
    Write-Host "Found maestro in PATH at: $($which.Source)"
    exit 0
}

Write-Host "No Maestro CLI found in PATH. Searching common install locations..."

$candidates = @(
    "$env:ProgramFiles\Maestro Studio\maestro.exe",
    "$env:ProgramFiles(x86)\Maestro Studio\maestro.exe",
    "$env:LOCALAPPDATA\Programs\Maestro Studio\maestro.exe",
    "$env:USERPROFILE\AppData\Local\Programs\Maestro Studio\maestro.exe"
)

$found = $null
foreach ($c in $candidates) {
    if (Test-MaestroPath $c) { $found = $c; break }
}

if ($found) {
    Write-Host "Detected Maestro CLI at: $found"
    $set = Read-Host "Set MAESTRO_CMD to this path for all sessions? (Y/n)"
    if ($set -ne 'n') {
        setx MAESTRO_CMD $found | Out-Null
        Write-Host "MAESTRO_CMD set. Restart your terminal to apply."
    }
    exit 0
}

Write-Host "No common installation found."
$prompt = Read-Host "If you have the Maestro CLI executable, paste its full path now (or press Enter to cancel)"
if (-not [string]::IsNullOrWhiteSpace($prompt)) {
    if (Test-MaestroPath $prompt) {
        setx MAESTRO_CMD $prompt | Out-Null
        Write-Host "MAESTRO_CMD set to $prompt. Restart your terminal to apply."
        exit 0
    } else {
        Write-Host "Path not found. Please verify and run this script again."
        exit 1
    }
} else {
    Write-Host "Cancelled. To run flows you need the Maestro CLI installed. Visit your Maestro admin or install the CLI." 
    exit 1
}
