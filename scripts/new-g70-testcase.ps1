param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$templateDir = Join-Path $RepoRoot "flows\g70\testcases\_template"
$targetDir = Join-Path $RepoRoot "flows\g70\testcases\$CaseId"

if (-not (Test-Path $templateDir)) {
    throw "Template folder not found: $templateDir"
}

if (Test-Path $targetDir) {
    throw "Case folder already exists: $targetDir"
}

New-Item -ItemType Directory -Path $targetDir | Out-Null
Copy-Item (Join-Path $templateDir "deviceA.yaml") (Join-Path $targetDir "deviceA.yaml")
Copy-Item (Join-Path $templateDir "deviceB.yaml") (Join-Path $targetDir "deviceB.yaml")
Copy-Item (Join-Path $templateDir "case.meta.yaml") (Join-Path $targetDir "case.meta.yaml")

# Stamp case id into metadata
(Get-Content (Join-Path $targetDir "case.meta.yaml") -Raw).Replace('TC_TEMPLATE', $CaseId) |
    Set-Content (Join-Path $targetDir "case.meta.yaml")

Write-Host "Created: $targetDir"
Write-Host "Next: edit deviceA.yaml/deviceB.yaml and run run-g70-same-time.ps1"
