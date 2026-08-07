$ErrorActionPreference = 'SilentlyContinue'
$ports = @(8080, 7390)
foreach ($port in $ports) {
  $pids = @()
  try {
    $pids = @(Get-NetTCPConnection -LocalPort $port | Select-Object -ExpandProperty OwningProcess -Unique)
  } catch {}
  if (-not $pids -or $pids.Count -eq 0) {
    $lines = netstat -ano | Select-String ":$port\s"
    foreach ($line in $lines) {
      $parts = ($line.ToString() -split '\s+') | Where-Object { $_ -ne '' }
      if ($parts.Count -ge 5) {
        $pidText = $parts[-1]
        if ($pidText -match '^\d+$') { $pids += [int]$pidText }
      }
    }
    $pids = $pids | Sort-Object -Unique
  }
  if (-not $pids -or $pids.Count -eq 0) {
    Write-Output "Port $port : free"
    continue
  }
  foreach ($procId in $pids) {
    if ($procId -le 0) { continue }
    Write-Output "Port $port : killing PID $procId"
    Stop-Process -Id $procId -Force
  }
}
Start-Sleep -Seconds 1
foreach ($port in $ports) {
  $still = @(Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue)
  if ($still.Count -gt 0) {
    Write-Output "Port $port : STILL IN USE"
  } else {
    Write-Output "Port $port : confirmed free"
  }
}
