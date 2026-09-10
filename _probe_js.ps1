$ErrorActionPreference = 'Continue'
foreach ($pair in @(@('MARKET','http://127.0.0.1:8095/'), @('ADMIN','http://127.0.0.1:8096/'))) {
  $name = $pair[0]; $base = $pair[1]
  Write-Output "=== $name ==="
  $r = Invoke-WebRequest -UseBasicParsing -Uri "$base" -TimeoutSec 15
  $boot = Invoke-WebRequest -UseBasicParsing -Uri "$baseflutter_bootstrap.js" -TimeoutSec 15
  $js = $boot.Content
  # find any .js asset names referenced in the bootstrap script
  $refs = [regex]::Matches($js, '(["''][^"'']*\.js[^"'']*["''])') | ForEach-Object { $_.Groups[1].Value.Trim('"'"'') } | Where-Object { $_ -notmatch '^https?:' } | Select-Object -Unique
  Write-Output "bootstrap references: $refs"
  foreach ($ref in $refs) {
    $clean = $ref.Trim('"'"'')
    $u = if ($clean.StartsWith('/')) { $base + $clean.TrimStart('/') } else { $base + $clean }
    try {
      $a = Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 60
      Write-Output "JS $clean -> $($a.StatusCode) len=$($a.Content.Length) type=$($a.Headers['Content-Type'])"
    } catch {
      Write-Output "JS $clean -> FAILED: $($_.Exception.Message)"
    }
  }
}
