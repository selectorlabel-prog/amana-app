# Start Flutter web sources (8095/7400) + single dual Glass bridge (8100/8101)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Evidence = Join-Path $Root "evidence"
New-Item -ItemType Directory -Force -Path $Evidence | Out-Null

$MarketWeb = "C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_app\build\web"
$AdminWeb = "C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_admin\build\web"

function Stop-PortListeners([int[]]$Ports) {
  foreach ($p in $Ports) {
    $conns = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
    foreach ($c in $conns) {
      try { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue } catch {}
    }
  }
  Start-Sleep -Seconds 1
}

function Start-NodeLogged($ArgsArr, $LogBase) {
  $out = Join-Path $Evidence "$LogBase.log"
  $err = Join-Path $Evidence "$LogBase.err"
  Start-Process -FilePath "node" -ArgumentList $ArgsArr -WorkingDirectory $Root `
    -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden
}

Write-Host "Stopping old listeners on 8095/7400/8100/8101..."
Stop-PortListeners @(8095, 7400, 8100, 8101)

Write-Host "Starting Flutter static: market :8095"
Start-NodeLogged @("serve-flutter-build.js", $MarketWeb, "8095") "flutter-market"
Write-Host "Starting Flutter static: admin :7400"
Start-NodeLogged @("serve-flutter-build.js", $AdminWeb, "7400") "flutter-admin"
Start-Sleep -Seconds 2

Write-Host "Starting dual Glass bridge :8100 + :8101"
Start-NodeLogged @("dual-bridge.js") "dual-bridge"

Write-Host ""
Write-Host "OPEN ONLY THESE in Cursor Glass side panel:"
Write-Host "  http://127.0.0.1:8100/   (market)"
Write-Host "  http://127.0.0.1:8101/   (admin)"
Write-Host "Do NOT open 8095/7400 in Glass (CanvasKit white screen)."
