param(
    [Parameter(Mandatory = $true)]
    [string]$CaseId
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$templateDir = Join-Path $RepoRoot "flows\idcevo\testcases\_template"
$targetDir = Join-Path $RepoRoot "flows\idcevo\testcases\$CaseId"

if (-not (Test-Path $templateDir)) { throw "Template folder not found: $templateDir" }
if (Test-Path $targetDir) { throw "Case folder already exists: $targetDir" }

New-Item -ItemType Directory -Path $targetDir | Out-Null
Copy-Item (Join-Path $templateDir "idcevo.yaml") (Join-Path $targetDir "idcevo.yaml")
Copy-Item (Join-Path $templateDir "idcevo.studio.yaml") (Join-Path $targetDir "idcevo.studio.yaml")
Copy-Item (Join-Path $templateDir "case.meta.yaml") (Join-Path $targetDir "case.meta.yaml")

(Get-Content (Join-Path $targetDir "case.meta.yaml") -Raw).Replace('TC_TEMPLATE', $CaseId) |
    Set-Content (Join-Path $targetDir "case.meta.yaml")

Write-Host "Created IDCEvo testcase: $targetDir"
