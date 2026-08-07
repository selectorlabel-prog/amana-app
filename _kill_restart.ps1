$ErrorActionPreference = 'SilentlyContinue'
foreach ($port in 8080, 7390) {
  Get-NetTCPConnection -LocalPort $port | ForEach-Object {
    Write-Host "Kill port $port PID $($_.OwningProcess)"
    Stop-Process -Id $_.OwningProcess -Force
  }
}
Get-CimInstance Win32_Process | Where-Object {
  $_.Name -match 'dart|flutter' -and $_.CommandLine -match 'web-port=(8080|7390)|web-server'
} | ForEach-Object {
  Write-Host "Kill flutter/dart PID $($_.ProcessId)"
  Stop-Process -Id $_.ProcessId -Force
}
Start-Sleep -Seconds 2
foreach ($port in 8080, 7390) {
  $left = @(Get-NetTCPConnection -LocalPort $port)
  if ($left.Count -eq 0) { Write-Host "Port $port FREE" } else { Write-Host "Port $port STILL BUSY" }
}
