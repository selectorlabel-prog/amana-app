$ErrorActionPreference = 'Continue'
$url = 'http://127.0.0.1:8095/assets/assets/branding/amana_icon.png'
try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
    Write-Output "BRAND ICON: $($r.StatusCode) length=$($r.RawContentLength)"
} catch {
    Write-Output "BRAND ICON ERR: $($_.Exception.Message)"
}
$url2 = 'http://127.0.0.1:8095/assets/AssetManifest.json'
try {
    $r2 = Invoke-WebRequest -Uri $url2 -UseBasicParsing -TimeoutSec 10
    Write-Output "MANIFEST: $($r2.StatusCode) length=$($r2.RawContentLength)"
} catch {
    Write-Output "MANIFEST ERR: $($_.Exception.Message)"
}
$url3 = 'http://127.0.0.1:8095/assets/AssetManifest.bin'
try {
    $r3 = Invoke-WebRequest -Uri $url3 -UseBasicParsing -TimeoutSec 10
    Write-Output "MANIFEST.BIN: $($r3.StatusCode) length=$($r3.RawContentLength)"
} catch {
    Write-Output "MANIFEST.BIN ERR: $($_.Exception.Message)"
}
