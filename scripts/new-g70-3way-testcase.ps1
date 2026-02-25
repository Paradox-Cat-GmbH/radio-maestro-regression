param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$templateDir = Join-Path $RepoRoot "flows\g70\testcases\_template_3way"
$targetDir = Join-Path $RepoRoot "flows\g70\testcases\$CaseId"

if (-not (Test-Path $templateDir)) { throw "Template folder not found: $templateDir" }
if (Test-Path $targetDir) { throw "Case folder already exists: $targetDir" }

New-Item -ItemType Directory -Path $targetDir | Out-Null
Copy-Item (Join-Path $templateDir "cde.yaml") (Join-Path $targetDir "cde.yaml")
Copy-Item (Join-Path $templateDir "rse.yaml") (Join-Path $targetDir "rse.yaml")
Copy-Item (Join-Path $templateDir "hu.yaml")  (Join-Path $targetDir "hu.yaml")
Copy-Item (Join-Path $templateDir "case.meta.yaml") (Join-Path $targetDir "case.meta.yaml")

(Get-Content (Join-Path $targetDir "case.meta.yaml") -Raw).Replace('TC_TEMPLATE', $CaseId) |
    Set-Content (Join-Path $targetDir "case.meta.yaml")

Write-Host "Created 3-way testcase: $targetDir"
