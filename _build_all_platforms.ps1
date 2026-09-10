$ErrorActionPreference = 'Continue'
$log = 'C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\_build_all_platforms.log'
function Log([string]$m) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
  Add-Content -Path $log -Value $line
  Write-Host $line
}
Set-Content -Path $log -Value "=== Amana platform build start $(Get-Date) ==="

$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:ANDROID_HOME = 'C:\Users\Administrator.user-HP\AppData\Local\Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$flutter = 'C:\flutter\flutter_windows_3.44.2-stable\flutter\bin\flutter.bat'
$market = 'C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_app'
$admin = 'C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_admin'
$logo = Join-Path $market 'assets\branding\amana_icon.png'

# 1) Android Studio
$studio = 'C:\Program Files\Android\Android Studio\bin\studio64.exe'
$sp = Get-Process -Name 'studio64' -ErrorAction SilentlyContinue
if ($sp) { Log "STUDIO already running pid=$($sp.Id)" }
else {
  Start-Process -FilePath $studio
  Start-Sleep -Seconds 3
  $sp = Get-Process -Name 'studio64' -ErrorAction SilentlyContinue
  if ($sp) { Log "STUDIO launched pid=$($sp.Id)" } else { Log "STUDIO launch unconfirmed" }
}

# 2) Copy gateway logo to admin
$adminBrand = Join-Path $admin 'assets\branding'
New-Item -ItemType Directory -Force -Path $adminBrand | Out-Null
Copy-Item -Force $logo (Join-Path $adminBrand 'amana_icon.png')
Log "Copied gateway logo to admin. Size=$((Get-Item $logo).Length)"

# 3) Prepare iOS folders (no IPA)
if (-not (Test-Path (Join-Path $market 'ios'))) {
  Log "Creating market ios/ via flutter create --platforms=ios"
  Set-Location $market
  & $flutter create --platforms=ios .
  Log "market ios create exit=$LASTEXITCODE exists=$(Test-Path (Join-Path $market 'ios'))"
} else { Log "market ios/ already exists" }

if (-not (Test-Path (Join-Path $admin 'ios'))) {
  Log "Creating admin ios/ via flutter create --platforms=ios"
  Set-Location $admin
  & $flutter create --platforms=ios .
  Log "admin ios create exit=$LASTEXITCODE exists=$(Test-Path (Join-Path $admin 'ios'))"
} else { Log "admin ios/ already exists" }

# 4) Generate launcher icons (market then admin — sequential)
Log "pub get + launcher icons MARKET"
Set-Location $market
& $flutter pub get
Log "market pub get exit=$LASTEXITCODE"
& $flutter pub run flutter_launcher_icons
Log "market icons exit=$LASTEXITCODE"

Log "pub get + launcher icons ADMIN"
Set-Location $admin
& $flutter pub get
Log "admin pub get exit=$LASTEXITCODE"
& $flutter pub run flutter_launcher_icons
Log "admin icons exit=$LASTEXITCODE"

# 5) Market APK
Log "BUILD MARKET APK"
Set-Location $market
& $flutter build apk --release
$marketApkExit = $LASTEXITCODE
Log "market apk exit=$marketApkExit"

# 6) Admin APK (after market finishes — one Gradle project at a time)
Log "BUILD ADMIN APK"
Set-Location $admin
& $flutter build apk --release
$adminApkExit = $LASTEXITCODE
Log "admin apk exit=$adminApkExit"

# 7) Admin Windows
Log "BUILD ADMIN WINDOWS"
Set-Location $admin
& $flutter build windows --release
$adminWinExit = $LASTEXITCODE
Log "admin windows exit=$adminWinExit"

# 8) Admin Web
Log "BUILD ADMIN WEB"
Set-Location $admin
& $flutter build web --release --no-web-resources-cdn
$adminWebExit = $LASTEXITCODE
Log "admin web exit=$adminWebExit"

# 9) Sizes
function ReportFile($label, $path) {
  if (Test-Path $path) {
    $i = Get-Item $path
    Log ("{0}: {1}  bytes={2}  mb={3:N2}  mtime={4}" -f $label, $i.FullName, $i.Length, ($i.Length/1MB), $i.LastWriteTime)
  } else {
    Log "$label MISSING: $path"
  }
}
ReportFile 'MARKET_APK' (Join-Path $market 'build\app\outputs\flutter-apk\app-release.apk')
ReportFile 'ADMIN_APK' (Join-Path $admin 'build\app\outputs\flutter-apk\app-release.apk')
$winCandidates = @(
  (Join-Path $admin 'build\windows\x64\runner\Release\amana_admin.exe'),
  (Join-Path $admin 'build\windows\runner\Release\amana_admin.exe')
)
foreach ($w in $winCandidates) { if (Test-Path $w) { ReportFile 'ADMIN_WIN_EXE' $w } }
$webIndex = Join-Path $admin 'build\web\index.html'
if (Test-Path $webIndex) { Log "ADMIN_WEB_INDEX: $webIndex" } else { Log "ADMIN_WEB_INDEX MISSING" }

Log "DONE marketApk=$marketApkExit adminApk=$adminApkExit adminWin=$adminWinExit adminWeb=$adminWebExit"
Log "=== Amana platform build end $(Get-Date) ==="
