$ErrorActionPreference = 'SilentlyContinue'
Get-NetTCPConnection -LocalPort 8095 -State Listen -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object {
    $p = Get-Process -Id $_ -ErrorAction SilentlyContinue
    Write-Output ("killing pid={0} name={1}" -f $_, $p.ProcessName)
    Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
  }
Start-Sleep -Seconds 2
$still = Get-NetTCPConnection -LocalPort 8095 -State Listen -ErrorAction SilentlyContinue
if ($still) { Write-Output 'STILL-LISTENING' } else { Write-Output 'PORT-FREE' }
Write-Output 'DONE-KILL'
