param(
  [Parameter(Mandatory = $true)] [string]$EdiabasBin,
  [Parameter(Mandatory = $true)] [string]$Ecu,
  [Parameter(Mandatory = $true)] [string]$Job,
  [Parameter(Mandatory = $false)] [string]$JobParam = "",
  [Parameter(Mandatory = $false)] [string]$ResultFilter = "",
  [Parameter(Mandatory = $false)] [int]$TimeoutSeconds = 60,
  [Parameter(Mandatory = $false)] [string]$Ifh = "",
  [Parameter(Mandatory = $false)] [string]$DeviceUnit = "",
  [Parameter(Mandatory = $false)] [string]$DeviceApplication = "",
  [Parameter(Mandatory = $false)] [string]$Configuration = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $EdiabasBin)) {
  throw "Invalid EDIABAS bin path: $EdiabasBin"
}

$apiDll = Join-Path $EdiabasBin "api32.dll"
if (-not (Test-Path -LiteralPath $apiDll)) {
  throw "api32.dll not found: $apiDll"
}

$env:PATH = "$EdiabasBin;$env:PATH"
Set-Location -LiteralPath $EdiabasBin

$cs = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class EdiabasApi32
{
    [DllImport("api32.dll", EntryPoint="__apiInitExt", CallingConvention=CallingConvention.StdCall, CharSet=CharSet.Ansi)]
    public static extern int ApiInitExt(
        out UInt32 handle,
        string ifh,
        string deviceUnit,
        string deviceApplication,
        string configuration
    );

    [DllImport("api32.dll", EntryPoint="__apiJob", CallingConvention=CallingConvention.StdCall, CharSet=CharSet.Ansi)]
    public static extern int ApiJob(
      UInt32 handle,
      string ecu,
      string jobName,
      string jobParam,
      string results
    );

    [DllImport("api32.dll", EntryPoint="__apiJobData", CallingConvention=CallingConvention.StdCall, CharSet=CharSet.Ansi)]
    public static extern int ApiJobData(
        UInt32 handle,
        string ecu,
        string jobName,
        [MarshalAs(UnmanagedType.LPArray)] byte[] jobParam,
        int jobParamLen,
        string results
    );

    [DllImport("api32.dll", EntryPoint="__apiState", CallingConvention=CallingConvention.StdCall)]
    public static extern int ApiState(UInt32 handle);

    [DllImport("api32.dll", EntryPoint="__apiErrorText", CallingConvention=CallingConvention.StdCall, CharSet=CharSet.Ansi)]
    public static extern int ApiErrorText(UInt32 handle, StringBuilder text, int maxLen);

    [DllImport("api32.dll", EntryPoint="__apiEnd", CallingConvention=CallingConvention.StdCall)]
    public static extern int ApiEnd(UInt32 handle);
}
"@

Add-Type -TypeDefinition $cs -Language CSharp

$handle = [uint32]0
$initRc = [EdiabasApi32]::ApiInitExt([ref]$handle, $Ifh, $DeviceUnit, $DeviceApplication, $Configuration)
if ($initRc -eq 0) {
  throw "ApiInitExt failed"
}

$stateBusy = 0
$stateReady = 1
$stateError = 3
$finalState = -1
$errorText = ""
$jobRc = 0

try {
  $paramBytes = [System.Text.Encoding]::ASCII.GetBytes($JobParam)
  $jobRc = [EdiabasApi32]::ApiJob($handle, $Ecu, $Job, $JobParam, $ResultFilter)
  if ($jobRc -eq 0) {
    $jobRc = [EdiabasApi32]::ApiJobData($handle, $Ecu, $Job, $paramBytes, $paramBytes.Length, $ResultFilter)
  }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while ($true) {
    $finalState = [EdiabasApi32]::ApiState($handle)
    if ($finalState -ne $stateBusy) {
      break
    }
    if ($sw.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
      throw "ApiState timed out after $TimeoutSeconds seconds"
    }
    Start-Sleep -Milliseconds 100
  }

  if ($finalState -eq $stateError) {
    $sb = New-Object System.Text.StringBuilder 1024
    [void][EdiabasApi32]::ApiErrorText($handle, $sb, 1024)
    $errorText = $sb.ToString()
  }

  $ok = ($jobRc -ne 0 -and $finalState -eq $stateReady)
  $result = [ordered]@{
    ok = $ok
    init_rc = $initRc
    job_rc = $jobRc
    final_state = $finalState
    error_text = $errorText
    ecu = $Ecu
    job = $Job
    job_param = $JobParam
  }

  $json = $result | ConvertTo-Json -Compress
  Write-Output $json

  if (-not $ok) {
    exit 2
  }
}
finally {
  [void][EdiabasApi32]::ApiEnd($handle)
}

exit 0