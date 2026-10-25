$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
Set-Location -LiteralPath $projectDirectory
& "$PSScriptRoot/diagnostics_dev.ps1" -CheckOnly
# Do not use --no-pub when switching from integration-test debug builds:
# Flutter must regenerate release registration without dev-only plugins.
& "$PSScriptRoot/diagnostics_dev.ps1" -Tool flutter -ToolArgs @('build','apk','--release','--target-platform','android-x64','--target','lib/main.dart') *> docs/qa/local-diagnostics/release-build.log
if ($LASTEXITCODE -ne 0) { throw 'Current release build failed' }
$apk = Join-Path $projectDirectory 'build/app/outputs/flutter-apk/app-release.apk'
$aapt = Join-Path $env:ANDROID_HOME 'build-tools/36.1.0/aapt2.exe'
$permissions = & $aapt dump permissions $apk
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect release permissions' }
$manifest = & $aapt dump xmltree $apk --file AndroidManifest.xml
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect release manifest' }
$permissions | Set-Content -LiteralPath 'docs/qa/local-diagnostics/release-permissions.txt'
$manifest | Set-Content -LiteralPath 'docs/qa/local-diagnostics/release-manifest.txt'
if (($permissions -join "`n") -match 'android.permission.(INTERNET|MANAGE_EXTERNAL_STORAGE|READ_EXTERNAL_STORAGE|READ_MEDIA_)') { throw 'Unexpected network or broad storage permission' }
if (($manifest -join "`n") -match 'allowBackup.*false|allowBackup.*0x0\b') { throw 'Business system backup must remain enabled' }
$mappingDirectory = Join-Path $projectDirectory 'build/app/outputs/mapping/release'
$mapping = Join-Path $mappingDirectory 'mapping.txt'
if (!(Test-Path -LiteralPath $mapping)) { throw 'R8 mapping missing' }
if (!(Select-String -LiteralPath $mapping -Pattern '^com\.settrace\.settrace\.DiagnosticEngine -> com\.settrace\.settrace\.DiagnosticEngine:$' -Quiet)) { throw 'Application frame namespace is not preserved' }
$retained = Join-Path $projectDirectory 'build/local-diagnostics/release-symbols'
New-Item -ItemType Directory -Force -Path $retained | Out-Null
foreach ($name in @('mapping.txt','configuration.txt','seeds.txt')) { Copy-Item -LiteralPath (Join-Path $mappingDirectory $name) -Destination (Join-Path $retained $name) -Force }
& "$PSScriptRoot/diagnostics_dev.ps1" -Tool gradle -ToolArgs @(':app:dependencies','--configuration','releaseRuntimeClasspath','--offline') *> docs/qa/local-diagnostics/release-dependencies.log
if ($LASTEXITCODE -ne 0) { throw 'Dependency report failed' }
[ordered]@{
    date = [DateTime]::UtcNow.ToString('o'); version = '0.2.4+10'; abi = 'x86_64'; target = 'lib/main.dart'
    apk = $apk; bytes = (Get-Item -LiteralPath $apk).Length
    apk_sha256 = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    r8_mapping = (Join-Path $retained 'mapping.txt')
    r8_mapping_sha256 = (Get-FileHash -LiteralPath $mapping -Algorithm SHA256).Hash.ToLowerInvariant()
    r8_enabled = $true; application_class_names_preserved = $true; dart_obfuscated = $false
    production_signing = $false; signature = 'existing project debug configuration; verification artifact only'
    permissions = @($permissions); backup = 'Android default enabled; diagnostics exclusively in noBackupFilesDir (platform tested separately)'
    telemetry_review = 'No new runtime SDK dependencies; inspect release-dependencies.log; no INTERNET permission'
    performance = 'Low-end physical device p95, release StrictMode and crash symbolication not measured'
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath docs/qa/local-diagnostics/release-verification.json
Get-Content -LiteralPath docs/qa/local-diagnostics/release-verification.json
