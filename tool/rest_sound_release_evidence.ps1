param([Parameter(Mandatory=$true)][string]$CompatibilityKey)
$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
Set-Location -LiteralPath $projectDirectory
& "$PSScriptRoot/diagnostics_dev.ps1" -CheckOnly
$original = Join-Path $projectDirectory 'build/app/outputs/flutter-apk/app-release.apk'
$retained = Join-Path $projectDirectory 'build/rest-system-sound'
New-Item -ItemType Directory -Force -Path $retained | Out-Null
$apk = Join-Path $retained 'SetTrace-0.3.1+12.apk'
$signer = Join-Path $env:ANDROID_HOME 'build-tools/36.1.0/apksigner.bat'
& $signer sign --ks $CompatibilityKey --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out $apk $original
if ($LASTEXITCODE -ne 0) { throw 'Existing-signature compatibility signing failed' }
$aapt = Join-Path $env:ANDROID_HOME 'build-tools/36.1.0/aapt2.exe'
$badging = & $aapt dump badging $apk
if ($LASTEXITCODE -ne 0 -or ($badging -join "`n") -notmatch "versionCode='12' versionName='0.3.1'") { throw 'Wrong APK identity' }
$permissions = & $aapt dump permissions $apk
if ($LASTEXITCODE -ne 0) { throw 'Permission inspection failed' }
$manifest = & $aapt dump xmltree $apk --file AndroidManifest.xml
if ($LASTEXITCODE -ne 0) { throw 'Manifest inspection failed' }
if (($permissions -join "`n") -match 'android.permission.(INTERNET|FOREGROUND_SERVICE|WAKE_LOCK|MANAGE_EXTERNAL_STORAGE|READ_MEDIA_|QUERY_ALL_PACKAGES)') { throw 'Unexpected permission' }
if (($manifest -join "`n") -match 'E: service') { throw 'Unexpected service' }
$bridge = Get-Content -LiteralPath android/app/src/main/kotlin/com/settrace/settrace/RestAlertsBridge.kt -Raw
if ($bridge -match 'android.resource://|rest_three_tone|rest_double_beep|rest_voice_') { throw 'Production output still depends on raw sound resources' }
$symbols = Join-Path $retained 'release-symbols'
New-Item -ItemType Directory -Force -Path $symbols | Out-Null
foreach ($name in @('mapping.txt','configuration.txt','seeds.txt')) {
    Copy-Item -LiteralPath (Join-Path $projectDirectory "build/app/outputs/mapping/release/$name") -Destination (Join-Path $symbols $name) -Force
}
$mapping = Join-Path $symbols 'mapping.txt'
if (!(Select-String -LiteralPath $mapping -Pattern '^com\.settrace\.settrace\.DiagnosticEngine -> com\.settrace\.settrace\.DiagnosticEngine:$' -Quiet)) { throw 'Diagnostic namespace not retained' }
$qa = Join-Path $projectDirectory 'docs/qa/rest-system-sound'
$badging | Set-Content -LiteralPath (Join-Path $qa 'release-badging.txt')
$permissions | Set-Content -LiteralPath (Join-Path $qa 'release-permissions.txt')
$manifest | Set-Content -LiteralPath (Join-Path $qa 'release-manifest.txt')
[ordered]@{
    created_utc = [DateTime]::UtcNow.ToString('o'); version = '0.3.1+12'; apk = $apk
    bytes = (Get-Item -LiteralPath $apk).Length; sha256 = (Get-FileHash -LiteralPath $apk).Hash.ToLowerInvariant()
    original_apk_sha256 = (Get-FileHash -LiteralPath $original).Hash.ToLowerInvariant()
    source_commit = (& git rev-parse HEAD); source_dirty = $true
    mapping = $mapping; mapping_sha256 = (Get-FileHash -LiteralPath $mapping).Hash.ToLowerInvariant()
    production_signing = $false; signature = 'Existing development signing identity; no data reset required for matching installations'
    dart_obfuscated = $false; permissions = $permissions
    raw_sound_dependency = $false; new_service = $false; device_hearing_verified = $false
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $qa 'release-verification.json')
