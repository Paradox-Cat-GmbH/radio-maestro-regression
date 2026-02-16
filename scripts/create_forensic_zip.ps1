$adb = Join-Path $env:TEMP 'adb_logcat_run.txt'
$files = @()
if(Test-Path 'artifacts\control_server_run_tail.txt'){ $files += 'artifacts\control_server_run_tail.txt' }
if(Test-Path 'artifacts\control_server.log'){ $files += 'artifacts\control_server.log' }
if(Test-Path 'artifacts\runs\20260216_113812\backend\radio_check\backend_verdict.json'){ $files += 'artifacts\runs\20260216_113812\backend\radio_check\backend_verdict.json' }
if(Test-Path 'artifacts\runs\20260216_121448\backend\radio_check\backend_verdict.json'){ $files += 'artifacts\runs\20260216_121448\backend\radio_check\backend_verdict.json' }
if(Test-Path $adb){ $files += $adb } else { Write-Output "WARNING: adb_logcat not found at $adb" }
if($files.Count -eq 0){ Write-Error 'NO FILES TO ZIP'; exit 1 }
$dest='artifacts\forensic_bundle_20260216_121448.zip'
Compress-Archive -Path $files -DestinationPath $dest -Force
Write-Output "ZIP_DONE: $dest"
