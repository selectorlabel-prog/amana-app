$ports = @(8095, 8096)
foreach ($p in $ports) {
    $url = "http://127.0.0.1:$p/"
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10
        Write-Output "PORT $p -> HTTP $($r.StatusCode) bytes=$($r.Content.Length) title=$([regex]::Match($r.Content, '<title>(.*?)</title>'))"
    } catch {
        Write-Output "PORT $p -> ERROR $($_.Exception.Message)"
    }
}