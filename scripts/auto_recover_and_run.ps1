param(
  [string]$Device = '169.254.107.117:5555'
)

Write-Output "Auto recovery start for device: $Device"

function RunCmd($c){
  Write-Output "> $c"
  cmd /c $c
}

if(-not (Test-Path "artifacts")) { New-Item -ItemType Directory artifacts | Out-Null }

# Capture initial artifacts
RunCmd "scripts\\adb.bat -s $Device shell screencap -p /sdcard/screen_before.png"
RunCmd "scripts\\adb.bat -s $Device pull /sdcard/screen_before.png artifacts\\device_screen_before.png"
RunCmd "scripts\\adb.bat -s $Device shell dumpsys audio > artifacts\\dumpsys_audio.txt"
RunCmd "scripts\\adb.bat -s $Device shell dumpsys media_session > artifacts\\dumpsys_media_session.txt"
RunCmd "scripts\\adb.bat -s $Device shell dumpsys activity activities > artifacts\\dumpsys_activity.txt"
RunCmd "scripts\\adb.bat -s $Device shell dumpsys window windows > artifacts\\dumpsys_window_before.txt"
RunCmd "scripts\\adb.bat -s $Device logcat -d > artifacts\\logcat_before.txt"

# Check window dumps for expected package
$win = Get-Content artifacts\\dumpsys_window_before.txt -Raw -ErrorAction SilentlyContinue
if($win -match 'com.bmwgroup.apinext.tunermediaservice'){
  Write-Output "Package appears in window dumps; attempting demo run without restart."
  $needReboot = $false
} else {
  Write-Output "Package not focused or UI not visible; attempting app restart."
  $needReboot = $true
}

if($needReboot){
  RunCmd "scripts\\adb.bat -s $Device shell am force-stop com.bmwgroup.apinext.tunermediaservice"
  Start-Sleep -s 3
  RunCmd "scripts\\adb.bat -s $Device shell monkey -p com.bmwgroup.apinext.tunermediaservice -c android.intent.category.LAUNCHER 1"
  Start-Sleep -s 8
  RunCmd "scripts\\adb.bat -s $Device shell dumpsys window windows > artifacts\\dumpsys_window_after_restart.txt"
  $win2 = Get-Content artifacts\\dumpsys_window_after_restart.txt -Raw -ErrorAction SilentlyContinue
  if($win2 -match 'com.bmwgroup.apinext.tunermediaservice'){
    Write-Output "App restart appears to have restored UI."
    $didReboot = $false
  } else {
    Write-Output "App restart didn't restore UI; rebooting device."
    RunCmd "scripts\\adb.bat -s $Device reboot"
    Write-Output "Waiting for device to come back..."
    RunCmd "scripts\\adb.bat wait-for-device"
    Start-Sleep -s 5
    RunCmd "scripts\\adb.bat connect $Device"
    RunCmd "scripts\\adb.bat devices -l > artifacts\\devices_after_reboot.txt"
    $didReboot = $true
  }
}

# Collect post-recovery artifacts
RunCmd "scripts\\adb.bat -s $Device shell screencap -p /sdcard/screen_after.png"
RunCmd "scripts\\adb.bat -s $Device pull /sdcard/screen_after.png artifacts\\device_screen_after.png"
RunCmd "scripts\\adb.bat -s $Device shell dumpsys media_session > artifacts\\dumpsys_media_session_after.txt"
RunCmd "scripts\\adb.bat -s $Device logcat -d > artifacts\\logcat_after.txt"

# Start demo run
Write-Output "Starting demo suite against $Device"
RunCmd "run_demo_suite.bat $Device"

Write-Output "Auto recovery + run complete. Check artifacts/ for logs and screenshots."
