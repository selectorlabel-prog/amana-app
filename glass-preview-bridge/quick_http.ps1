$ErrorActionPreference = 'SilentlyContinue'
foreach ($port in 8095, 7400, 8100, 8101) {
  try {
    $r = Invoke-WebRequest -Uri ("http://127.0.0.1:{0}/" -f $port) -UseBasicParsing -TimeoutSec 3
    Write-Output ("{0} = {1}" -f $port, $r.StatusCode)
  } catch {
    Write-Output ("{0} = DOWN" -f $port)
  }
}
Write-Output 'DONE-HTTP'
