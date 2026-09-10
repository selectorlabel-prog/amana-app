$ErrorActionPreference = 'Continue'
Write-Output '=== LISTENERS ==='
netstat -ano | findstr ':8095 :8096 :7400 :8080 :8785 :8786'
Write-Output '=== HTTP CHECKS ==='
$urls = @(
  'http://127.0.0.1:8095/',
  'http://127.0.0.1:8096/',
  'http://127.0.0.1:7400/',
  'http://127.0.0.1:8080/'
)
foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 8
    $title = ''
    if ($r.Content -match '<title>([^<]+)</title>') { $title = $Matches[1] }
    $hasBoot = $r.Content.Contains('amana-boot')
    $hasFlutter = $r.Content.Contains('flutter_bootstrap.js')
    Write-Output ("OK {0} status={1} len={2} title={3} boot={4} flutter={5}" -f $u, $r.StatusCode, $r.RawContentLength, $title, $hasBoot, $hasFlutter)
  } catch {
    Write-Output ("FAIL {0} -> {1}" -f $u, $_.Exception.Message)
  }
}
Write-Output '=== BUILD INDEX EXISTS ==='
$paths = @(
  'C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_app\build\web\index.html',
  'C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_admin\build\web\index.html'
)
foreach ($p in $paths) {
  if (Test-Path $p) {
    $i = Get-Item $p
    Write-Output ("EXISTS {0} size={1} mtime={2}" -f $p, $i.Length, $i.LastWriteTime)
  } else {
    Write-Output ("MISSING {0}" -f $p)
  }
}
