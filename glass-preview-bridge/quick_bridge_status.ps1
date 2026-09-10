$ErrorActionPreference = 'SilentlyContinue'
foreach ($port in 8100, 8101) {
  try {
    $r = Invoke-WebRequest -Uri ("http://127.0.0.1:{0}/status.json" -f $port) -UseBasicParsing -TimeoutSec 5
    Write-Output ("{0}: {1}" -f $port, $r.Content)
  } catch {
    Write-Output ("{0}: FAIL" -f $port)
  }
}
Write-Output 'DONE-BRIDGE'
