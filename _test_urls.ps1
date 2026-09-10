$ErrorActionPreference = 'Continue'
$urls = @('http://127.0.0.1:8095/flutter_bootstrap.js', 'http://127.0.0.1:8095/main.dart.js', 'http://127.0.0.1:8095/flutter.js', 'http://127.0.0.1:8096/flutter_bootstrap.js', 'http://127.0.0.1:8096/main.dart.js', 'http://127.0.0.1:8096/flutter.js')
foreach ($u in $urls) {
    try {
        $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 10
        Write-Output "OK: $u -> $($resp.StatusCode) (Length: $($resp.RawContentLength), Type: $($resp.Headers['Content-Type']))"
    } catch {
        Write-Output "ERR: $u -> $($_.Exception.Message)"
    }
}
