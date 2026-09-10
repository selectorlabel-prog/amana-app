$ErrorActionPreference = 'Continue'
try {
  $r = Invoke-WebRequest -Uri 'http://127.0.0.1:7400/' -UseBasicParsing -TimeoutSec 8
  Write-Output ("ADMIN INDEX {0} {1}" -f $r.StatusCode, $r.RawContentLength)
} catch {
  Write-Output ("ADMIN INDEX FAIL {0}" -f $_.Exception.Message)
}
try {
  $r2 = Invoke-WebRequest -Uri 'http://127.0.0.1:8095/' -UseBasicParsing -TimeoutSec 8
  Write-Output ("MARKET INDEX {0} {1}" -f $r2.StatusCode, $r2.RawContentLength)
} catch {
  Write-Output ("MARKET INDEX FAIL {0}" -f $_.Exception.Message)
}
