param(
    [string]$CDE = "169.254.166.167",
    [string]$RSE = "169.254.166.152",
    [string]$HU  = "169.254.166.99",
    [int]$Port = 5555
)

$ErrorActionPreference = "Stop"

$targets = @(
    @{ Name = "CDE"; Ip = $CDE },
    @{ Name = "RSE"; Ip = $RSE },
    @{ Name = "HU";  Ip = $HU }
)

Write-Host "Connecting G70 devices over ADB TCP..."
foreach ($t in $targets) {
    $endpoint = "$($t.Ip):$Port"
    Write-Host "[$($t.Name)] adb connect $endpoint"
    adb connect $endpoint | Out-Host
}

Write-Host "\nConnected devices:"
adb devices -l
