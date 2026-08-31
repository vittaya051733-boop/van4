# Build van4 Android release APK (admin app).
# van4 currently uses debug signing unless key.properties is added later.
param(
    [switch]$SkipClean,
    [switch]$AllowDebugSigning = $true
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keyProps = Join-Path $root 'android\key.properties'
$usingDebugSigning = -not (Test-Path $keyProps)
if ($usingDebugSigning -and -not $AllowDebugSigning) {
    Write-Error @"
Missing android/key.properties — configure upload keystore before store release.
For internal QA only, rerun with -AllowDebugSigning (uses debug keystore).
"@
}
if ($usingDebugSigning) {
    Write-Warning 'Building with debug signing — OK for admin sideload, NOT for Play Store upload.'
}

if (-not $SkipClean) {
    flutter pub get
}

$version = (Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*(.+)$').Matches.Groups[1].Value.Trim()
$releasesDir = Join-Path $root 'releases'
if (-not (Test-Path $releasesDir)) {
    New-Item -ItemType Directory -Path $releasesDir | Out-Null
}

# Sideload admin builds keep debug App Check so callables work without Play Integrity SHA.
flutter build apk --release --no-pub `
  --dart-define=APP_CHECK_DEBUG=true `
  -PfirebaseCrashlyticsMappingFileUploadEnabled=false
if ($LASTEXITCODE -ne 0) {
    throw 'flutter build apk --release failed'
}
$apkSrc = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apkSrc)) {
    throw "Missing release APK at $apkSrc"
}
$apkDst = Join-Path $releasesDir "van4-$version-release.apk"
Copy-Item $apkSrc $apkDst -Force
Write-Host "APK: $apkDst"
