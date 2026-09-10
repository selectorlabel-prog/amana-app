$ErrorActionPreference = 'Continue'
foreach ($u in @('http://127.0.0.1:8095/','http://127.0.0.1:7400/','http://127.0.0.1:8095/canvaskit/canvaskit.wasm','http://127.0.0.1:7400/canvaskit/canvaskit.wasm')) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 10
    Write-Output ("OK {0} status={1} type={2} len={3}" -f $u, $r.StatusCode, $r.Headers['Content-Type'], $r.RawContentLength)
  } catch {
    Write-Output ("FAIL {0} -> {1}" -f $u, $_.Exception.Message)
  }
}
