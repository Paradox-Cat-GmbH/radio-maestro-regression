$stamp = '20260216_121448'
$tmp = Join-Path 'artifacts' ("tmp_forensic_$stamp")
if(Test-Path $tmp){ Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Path $tmp | Out-Null
$items = @(
    @{src='artifacts\control_server_run_tail.txt'; dst='control_server_run_tail.txt'},
    @{src='artifacts\control_server.log'; dst='control_server.log'},
    @{src='artifacts\runs\20260216_113812\backend\radio_check\backend_verdict.json'; dst='backend_verdict_20260216_113812.json'},
    @{src='artifacts\runs\20260216_121448\backend\radio_check\backend_verdict.json'; dst='backend_verdict_20260216_121448.json'},
    @{src=(Join-Path $env:TEMP 'adb_logcat_run.txt'); dst='adb_logcat_run.txt'}
)
foreach($it in $items){
    $s = $it.src; $d = Join-Path $tmp $it.dst
    if(Test-Path $s){
        try{
            Get-Content -Raw -ErrorAction Stop -Path $s | Out-File -FilePath $d -Encoding UTF8 -Force
            Write-Output ("COPIED: " + $s)
        } catch {
            try{
                Copy-Item -Force -Path $s -Destination $d -ErrorAction Stop
                Write-Output ("COPIED_BY_COPY: " + $s)
            } catch {
                Write-Output ("FAILED_COPY: " + $s)
            }
        }
    } else { Write-Output ("MISSING: " + $s) }
}
$dest = Join-Path 'artifacts' ('forensic_bundle_' + $stamp + '.zip')
try{
    Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $dest -Force
    Write-Output ("ZIP_DONE: " + $dest)
} catch {
    Write-Output ("ZIP_FAILED: " + $_.Exception.Message)
}
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
