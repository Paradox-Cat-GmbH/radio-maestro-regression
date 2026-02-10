<#
Interactive helper to detect Maestro CLI and set MAESTRO_CMD.

Run from PowerShell in the repo root:
  powershell -ExecutionPolicy Bypass -File scripts\setup_maestro.ps1

MAESTRO_CMD can be:
- Full path to maestro.exe / maestro.cmd / maestro.bat / maestro
- A directory containing the CLI (script will search recursively)

Your known install paths:
- CLI:  %USERPROFILE%\Desktop\maestro\bin
- Studio: %LOCALAPPDATA%\Programs\Maestro Studio
#>

$ErrorActionPreference = "Stop"

function Find-MaestroInDir([string]$dir) {
    if (-not (Test-Path $dir)) { return $null }
    $names = @("maestro.exe", "maestro.cmd", "maestro.bat", "maestro")
    foreach ($n in $names) {
        $p = Get-ChildItem -Path $dir -Recurse -Filter $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) { return $p.FullName }
    }
    return $null
}

function Resolve-Maestro([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }

    if (Test-Path $p) {
        $item = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            if (-not $item.PSIsContainer) { return $item.FullName }
            $found = Find-MaestroInDir $item.FullName
            if ($found) { return $found }
        }
    }

    $cmd = Get-Command $p -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    return $null
}

Write-Host "Detecting Maestro CLI..."

if ($env:MAESTRO_CMD) {
    Write-Host "MAESTRO_CMD currently set to: $env:MAESTRO_CMD"
    $r = Resolve-Maestro $env:MAESTRO_CMD
    if ($r) {
        Write-Host "OK: $r"
        exit 0
    }
    Write-Host "MAESTRO_CMD does not resolve to a valid CLI."
}

$candidates = @(
    (Join-Path $env:USERPROFILE "Desktop\maestro\bin"),
    (Join-Path $env:LOCALAPPDATA "Programs\Maestro Studio"),
    (Join-Path $env:USERPROFILE "AppData\Local\Programs\Maestro Studio"),
    "$env:ProgramFiles\Maestro Studio",
    "$env:ProgramFiles(x86)\Maestro Studio"
)

$found = $null
foreach ($c in $candidates) {
    $found = Resolve-Maestro $c
    if ($found) { break }
}

if ($found) {
    Write-Host "Detected Maestro CLI at: $found"
    $ans = Read-Host "Set MAESTRO_CMD (User) to this path? (Y/n)"
    if ($ans -ne "n") {
        setx MAESTRO_CMD "$found" | Out-Null
        Write-Host "MAESTRO_CMD set. Restart your terminal to apply."
    }
    exit 0
}

Write-Host "Not found automatically."
$manual = Read-Host "Paste full path to Maestro CLI executable or its install folder (Enter to cancel)"
if ([string]::IsNullOrWhiteSpace($manual)) { exit 1 }

$resolved = Resolve-Maestro $manual
if (-not $resolved) {
    Write-Host "Could not resolve Maestro CLI from: $manual"
    exit 2
}

setx MAESTRO_CMD "$resolved" | Out-Null
Write-Host "MAESTRO_CMD set to: $resolved"
Write-Host "Restart your terminal to apply."
exit 0
