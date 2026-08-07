# Prefer start-all.ps1 (Flutter sources + dual bridge). This script starts dual-bridge only.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root
$Evidence = Join-Path $Root "evidence"
New-Item -ItemType Directory -Force -Path $Evidence | Out-Null

foreach ($p in 8100, 8101) {
  Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
}
Start-Sleep -Seconds 1
Start-Process -FilePath "node" -ArgumentList @("dual-bridge.js") -WorkingDirectory $Root `
  -RedirectStandardOutput (Join-Path $Evidence "dual-bridge.log") `
  -RedirectStandardError (Join-Path $Evidence "dual-bridge.err") -WindowStyle Hidden

Write-Host "OPEN ONLY in Glass side panel:"
Write-Host "  http://127.0.0.1:8100/"
Write-Host "  http://127.0.0.1:8101/"
