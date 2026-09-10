$ErrorActionPreference = 'Continue'
$urls = @(
    'http://127.0.0.1:8095/canvaskit/canvaskit.js',
    'http://127.0.0.1:8095/canvaskit/canvaskit.wasm',
    'http://127.0.0.1:8096/canvaskit/canvaskit.js',
    'http://127.0.0.1:8096/canvaskit/canvaskit.wasm'
)
foreach ($u in $urls) {
    try {
        $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 10
        Write-Output "OK: $u -> $($resp.StatusCode) (Length: $($resp.RawContentLength), Type: $($resp.Headers['Content-Type']))"
    } catch {
        Write-Output "ERR: $u -> $($_.Exception.Message)"
    }
}
