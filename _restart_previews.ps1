$ErrorActionPreference='SilentlyContinue'
$log='C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\preview_fix.txt'
$base='C:\Users\Administrator.user-HP\AndroidStudioProjects'
function Kill-Port($port){
  $lines = netstat -ano | Select-String ":$port\s"
  foreach($line in $lines){
    $parts = ($line.ToString() -split '\s+') | Where-Object { $_ -ne '' }
    $pid = $parts[-1]
    if($pid -match '^\d+$' -and [int]$pid -gt 0){ taskkill /F /PID $pid 2>$null }
  }
}
Kill-Port 8080
Kill-Port 7390
Start-Sleep 2
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if(-not $flutter){ $flutter = 'flutter' }
"flutter=$flutter" | Set-Content $log
Start-Process -FilePath $flutter -ArgumentList @('run','-d','web-server','--web-port=8080','--web-hostname=localhost','--no-web-resources-cdn') -WorkingDirectory "$base\amana_app" -WindowStyle Hidden
Start-Process -FilePath $flutter -ArgumentList @('run','-d','web-server','--web-port=7390','--web-hostname=localhost','--no-web-resources-cdn') -WorkingDirectory "$base\amana_admin" -WindowStyle Hidden
'LAUNCHED' | Add-Content $log
$deadline=(Get-Date).AddSeconds(90)
$r8080='FAILED'; $r7390='FAILED'
while((Get-Date) -lt $deadline){
  try { if((Invoke-WebRequest -Uri 'http://127.0.0.1:8080' -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200){ $r8080='DONE' } } catch {}
  try { if((Invoke-WebRequest -Uri 'http://127.0.0.1:7390' -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200){ $r7390='DONE' } } catch {}
  "poll app=$r8080 admin=$r7390 $(Get-Date -Format HH:mm:ss)" | Add-Content $log
  if($r8080 -eq 'DONE' -and $r7390 -eq 'DONE'){ break }
  Start-Sleep 3
}
"RESULT_APP=$r8080 http://localhost:8080" | Add-Content $log
"RESULT_ADMIN=$r7390 http://localhost:7390" | Add-Content $log
