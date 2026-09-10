# One-command Glass file-based previews (PNG + meta-refresh HTML).
# Prefer static Flutter web builds (paint reliably). Keep ports if already healthy.
# Writes: glass-preview-bridge/live/{market,admin}.{html,png}
$ErrorActionPreference = "Continue"
$Root = "C:\Users\Administrator.user-HP\AndroidStudioProjects\amana"
$Bridge = Join-Path $Root "glass-preview-bridge"
$Live = Join-Path $Bridge "live"
$Evidence = Join-Path $Bridge "evidence"
$MarketWeb = "C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_app\build\web"
$AdminWeb = "C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_admin\build\web"

New-Item -ItemType Directory -Force -Path $Live, $Evidence | Out-Null

function Test-PortListen([int]$Port) {
  return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Stop-PortListeners([int[]]$Ports) {
  foreach ($p in $Ports) {
    Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue |
      ForEach-Object {
        try { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue } catch {}
      }
  }
  Start-Sleep -Seconds 1
}

function Start-NodeLogged([string[]]$ArgsArr, [string]$LogBase) {
  $out = Join-Path $Evidence "$LogBase.log"
  $err = Join-Path $Evidence "$LogBase.err"
  Start-Process -FilePath "node" -ArgumentList $ArgsArr -WorkingDirectory $Bridge `
    -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden
}

Write-Host "=== Glass file previews ==="

# Flutter sources: restart only if down OR force via -ForceFlutter
$force = $args -contains "-ForceFlutter"
if ($force -or -not (Test-PortListen 8095) -or -not (Test-PortListen 7400)) {
  Write-Host "Starting/refreshing static Flutter builds on 8095/7400..."
  Stop-PortListeners @(8095, 7400)
  if (-not (Test-Path (Join-Path $MarketWeb "index.html"))) { Write-Host "ERROR missing $MarketWeb"; exit 1 }
  if (-not (Test-Path (Join-Path $AdminWeb "index.html"))) { Write-Host "ERROR missing $AdminWeb"; exit 1 }
  Start-NodeLogged @("serve-flutter-build.js", $MarketWeb, "8095") "flutter-market"
  Start-NodeLogged @("serve-flutter-build.js", $AdminWeb, "7400") "flutter-admin"
  Start-Sleep -Seconds 2
} else {
  Write-Host "Flutter :8095/:7400 already UP — leave alone (pass -ForceFlutter to rebuild sources)"
}

Write-Host "Restarting file-live bridge (8100/8101)..."
Stop-PortListeners @(8100, 8101)
Start-NodeLogged @("file-live-bridge.js") "file-live"
Start-Sleep -Seconds 4

Write-Host ""
Write-Host "PLAN A — open these FILE paths in Glass (preferred):"
Write-Host "  file:///C:/Users/Administrator.user-HP/AndroidStudioProjects/amana/glass-preview-bridge/live/market.html"
Write-Host "  file:///C:/Users/Administrator.user-HP/AndroidStudioProjects/amana/glass-preview-bridge/live/admin.html"
Write-Host "  (or PNG: .../live/market.png  .../live/admin.png)"
Write-Host ""
Write-Host "PLAN B — if file URI blocked:"
Write-Host "  http://127.0.0.1:8100/"
Write-Host "  http://127.0.0.1:8101/"
Write-Host ""
Write-Host "Arabic: لفتح المعاينة افتح ملفات live/market.html و live/admin.html أو http://127.0.0.1:8100 و :8101"
