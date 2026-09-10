$ErrorActionPreference = 'SilentlyContinue'
Write-Output '--- PORTS ---'
Get-NetTCPConnection -LocalPort 7400,8095,8100,8101 -State Listen -ErrorAction SilentlyContinue |
  Sort-Object LocalPort -Unique | ForEach-Object {
    $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    Write-Output ("port={0} pid={1} name={2} started={3}" -f $_.LocalPort, $_.OwningProcess, $p.ProcessName, $p.StartTime)
  }
Write-Output '--- APP FILES ---'
Get-ChildItem 'C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_app\lib' -Recurse -Filter *.dart |
  Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object {
    Write-Output ("{0}  {1}" -f $_.LastWriteTime, $_.FullName)
  }
Write-Output '--- ADMIN FILES ---'
Get-ChildItem 'C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_admin\lib' -Recurse -Filter *.dart |
  Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object {
    Write-Output ("{0}  {1}" -f $_.LastWriteTime, $_.FullName)
  }
Write-Output 'DONE-STATUS'
