$ErrorActionPreference = 'Continue'
function Test-Page($name, $url) {
  Write-Output "=== $name ($url) ==="
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 15
    Write-Output "INDEX status=$($r.StatusCode) len=$($r.Content.Length)"
  } catch {
    Write-Output "INDEX FAILED: $($_.Exception.Message)"
    return
  }
  $html = $r.Content
  $refs = [regex]::Matches($html, '(?:src|href)="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notmatch '^https?:' }
  foreach ($ref in $refs) {
    $assetUrl = $url.TrimEnd('/') + '/' + $ref.TrimStart('/')
    try {
      $a = Invoke-WebRequest -UseBasicParsing -Uri $assetUrl -TimeoutSec 30 -Method Head
      if ($a.StatusCode -eq 405) { $a = Invoke-WebRequest -UseBasicParsing -Uri $assetUrl -TimeoutSec 30 }
      Write-Output "ASSET $ref -> $($a.StatusCode) len=$($a.Headers['Content-Length'])"
    } catch {
      Write-Output "ASSET $ref -> FAILED: $($_.Exception.Message)"
    }
  }
  # print first 40 lines of index for diagnostics
  Write-Output "--- index head ---"
  ($html -split "`n" | Select-Object -First 30) | ForEach-Object { Write-Output $_ }
}
Test-Page "MARKET" "http://127.0.0.1:8095/"
Test-Page "ADMIN"  "http://127.0.0.1:8096/"
