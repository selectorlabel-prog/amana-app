$ErrorActionPreference = 'SilentlyContinue'
foreach ($port in 8095, 7400) {
  Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object {
      $p = Get-Process -Id $_ -ErrorAction SilentlyContinue
      Write-Output ("port {0}: killing pid={1} name={2}" -f $port, $_, $p.ProcessName)
      Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Seconds 2
foreach ($port in 8095, 7400) {
  $still = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  Write-Output ("port {0}: {1}" -f $port, $(if ($still) { 'STILL-LISTENING' } else { 'FREE' }))
}
Write-Output 'DONE-KILL'
