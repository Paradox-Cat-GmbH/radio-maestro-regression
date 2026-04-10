param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,
    [string]$DltIp = "",
    [string]$DltPort = "3490",
    [string]$StartAtCaseId = "",
    [string[]]$ExcludeCaseIds = @(),
    [switch]$PruneEvidenceOnPass,
    [switch]$StopOnFailure,
    [int]$DelayBetweenCasesSeconds = 5,
    [int]$PerCaseTimeoutMinutes = 30
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$suiteFlow = Join-Path $RepoRoot "flows\idc23\demo\IDC23DEMO-900001__prt_pdf_full_suite.yaml"
$singleRunner = Join-Path $ScriptDir "run-idc23-e2e-poc.ps1"

if (-not (Test-Path $suiteFlow)) { throw "Missing suite flow: $suiteFlow" }
if (-not (Test-Path $singleRunner)) { throw "Missing IDC23 runner: $singleRunner" }

$orderedCases = @(
    Get-Content $suiteFlow |
    Where-Object { $_ -match 'IDC23DEV-(\d+)' } |
    ForEach-Object { "ABPI-$($Matches[1])" }
)

if (-not $orderedCases -or $orderedCases.Count -eq 0) {
    throw "Could not extract ordered cases from $suiteFlow"
}

$normalizedExclude = @($ExcludeCaseIds | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim().ToUpperInvariant() })
$startAt = $StartAtCaseId.Trim().ToUpperInvariant()

if (-not [string]::IsNullOrWhiteSpace($startAt) -and ($orderedCases -notcontains $startAt)) {
    throw "StartAtCaseId '$StartAtCaseId' is not in the IDC23 PDF suite order."
}

$casesToRun = New-Object System.Collections.Generic.List[string]
$startFound = [string]::IsNullOrWhiteSpace($startAt)
foreach ($caseId in $orderedCases) {
    $normalizedCase = $caseId.ToUpperInvariant()
    if (-not $startFound) {
        if ($normalizedCase -eq $startAt) {
            $startFound = $true
        } else {
            continue
        }
    }
    if ($normalizedExclude -contains $normalizedCase) { continue }
    $casesToRun.Add($caseId)
}

if ($casesToRun.Count -eq 0) {
    throw "No IDC23 cases selected after filters."
}

function Get-LatestRunSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$CaseId
    )

    $caseRoot = Join-Path $RepoRoot "artifacts\runs\idc23\$CaseId"
    if (-not (Test-Path $caseRoot)) { return $null }

    $latest = Get-ChildItem -Path $caseRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $latest) { return $null }

    $summaryPath = Join-Path $latest.FullName "run-summary.json"
    if (-not (Test-Path $summaryPath)) {
        return [pscustomobject]@{
            runRoot = $latest.FullName
            summaryPath = $summaryPath
            summary = $null
        }
    }

    return [pscustomobject]@{
        runRoot = $latest.FullName
        summaryPath = $summaryPath
        summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    }
}

function Write-BatchSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [psobject]$Summary
    )

    $Summary | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding UTF8
}

$batchTs = Get-Date -Format "yyyyMMdd_HHmmss"
$batchRoot = Join-Path $RepoRoot "artifacts\runs\idc23\_batches\$batchTs"
New-Item -ItemType Directory -Force -Path $batchRoot | Out-Null

$results = New-Object System.Collections.Generic.List[object]
$summaryPath = Join-Path $batchRoot "batch-summary.json"

$summary = [pscustomobject]@{
    timestamp = $batchTs
    deviceId = $DeviceId
    dltIp = if ([string]::IsNullOrWhiteSpace($DltIp)) { $null } else { $DltIp }
    dltPort = $DltPort
    pruneEvidenceOnPass = [bool]$PruneEvidenceOnPass
    stopOnFailure = [bool]$StopOnFailure
    perCaseTimeoutMinutes = $PerCaseTimeoutMinutes
    startAtCaseId = if ([string]::IsNullOrWhiteSpace($StartAtCaseId)) { $null } else { $StartAtCaseId }
    excludeCaseIds = $ExcludeCaseIds
    orderedCases = $casesToRun
    results = $results
}

Write-BatchSummary -Path $summaryPath -Summary $summary

Write-Host ("IDC23 PDF order runner: {0} case(s)" -f $casesToRun.Count)
Write-Host ("Batch root: {0}" -f $batchRoot)

for ($i = 0; $i -lt $casesToRun.Count; $i++) {
    $caseId = $casesToRun[$i]
    Write-Host ""
    Write-Host ("[{0}/{1}] Running {2}" -f ($i + 1), $casesToRun.Count, $caseId) -ForegroundColor Cyan

    $invokeArgs = @{
        CaseId   = $caseId
        DeviceId = $DeviceId
        DltPort  = $DltPort
    }
    if (-not [string]::IsNullOrWhiteSpace($DltIp)) {
        $invokeArgs.DltIp = $DltIp
    }
    if ($PruneEvidenceOnPass) {
        $invokeArgs.PruneEvidenceOnPass = $true
    }

    $runStatus = "UNKNOWN"
    $runnerError = $null
    $runnerTimedOut = $false
    $tempOutput = Join-Path $batchRoot ("{0}.stdout.log" -f $caseId)
    $tempError = Join-Path $batchRoot ("{0}.stderr.log" -f $caseId)
    try {
        $argList = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $singleRunner
        )
        foreach ($kv in $invokeArgs.GetEnumerator()) {
            if ($kv.Value -is [bool]) {
                if ($kv.Value) {
                    $argList += "-$($kv.Key)"
                }
                continue
            }
            $argList += "-$($kv.Key)"
            if ($kv.Value -isnot [switch] -and $kv.Value -isnot [System.Management.Automation.SwitchParameter]) {
                $argList += [string]$kv.Value
            }
        }

        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -RedirectStandardOutput $tempOutput -RedirectStandardError $tempError -PassThru -WindowStyle Hidden
        try {
            Wait-Process -Id $proc.Id -Timeout ($PerCaseTimeoutMinutes * 60) -ErrorAction Stop | Out-Null
            $proc.Refresh()
        } catch {
            $runnerTimedOut = $true
        }

        if ($runnerTimedOut) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            $runStatus = "RUNNER_TIMEOUT"
            $runnerError = "Timed out after $PerCaseTimeoutMinutes minute(s)"
        } elseif ($proc.ExitCode -eq 0) {
            $runStatus = "COMPLETED"
        } else {
            $runStatus = "RUNNER_ERROR"
            $runnerError = "Runner exit code $($proc.ExitCode)"
        }
    } catch {
        $runStatus = "RUNNER_ERROR"
        $runnerError = $_.Exception.Message
    }
    if ($runnerError) {
        Write-Warning ("{0}: {1}" -f $caseId, $runnerError)
    }

    $latest = Get-LatestRunSummary -RepoRoot $RepoRoot -CaseId $caseId
    $verdict = if ($latest -and $latest.summary) { $latest.summary.verdict } else { $null }
    $flowPassed = if ($latest -and $latest.summary) { $latest.summary.flowPassed } else { $null }
    $evidenceComplete = if ($latest -and $latest.summary) { $latest.summary.evidenceComplete } else { $null }

    $results.Add([pscustomobject]@{
        caseId = $caseId
        runStatus = $runStatus
        verdict = $verdict
        flowPassed = $flowPassed
        evidenceComplete = $evidenceComplete
        runRoot = if ($latest) { $latest.runRoot } else { $null }
        summaryPath = if ($latest) { $latest.summaryPath } else { $null }
        runnerLog = if (Test-Path $tempOutput) { $tempOutput } else { $null }
        runnerErrorLog = if (Test-Path $tempError) { $tempError } else { $null }
        error = $runnerError
    })

    Write-BatchSummary -Path $summaryPath -Summary $summary

    if ($StopOnFailure -and ($runStatus -ne "COMPLETED" -or $verdict -eq "FAIL")) {
        Write-Warning ("Stopping batch on {0}" -f $caseId)
        break
    }

    if ($DelayBetweenCasesSeconds -gt 0 -and $i -lt ($casesToRun.Count - 1)) {
        Start-Sleep -Seconds $DelayBetweenCasesSeconds
    }
}

Write-BatchSummary -Path $summaryPath -Summary $summary

Write-Host ""
Write-Host ("Batch summary: {0}" -f $summaryPath) -ForegroundColor Green

$hasFailures = @($results | Where-Object { $_.runStatus -ne "COMPLETED" -or $_.verdict -eq "FAIL" }).Count -gt 0
if ($hasFailures) {
    exit 1
}
