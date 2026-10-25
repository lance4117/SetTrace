param(
    [ValidateSet('platform','ui')][string]$Mode = 'platform',
    [string]$CompatibilityKey
)
$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
Set-Location -LiteralPath $projectDirectory
& "$PSScriptRoot/diagnostics_dev.ps1" -CheckOnly
& "$PSScriptRoot/diagnostics_dev.ps1" -Tool flutter -ToolArgs @('pub','get','--offline') *> 'docs/qa/local-diagnostics/plugin-refresh.log'
if ($LASTEXITCODE -ne 0) { throw 'Offline plugin refresh failed' }
$adbExecutable = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
$serial = 'emulator-5554'
if ((& $adbExecutable -s $serial shell getprop ro.kernel.qemu).Trim() -ne '1') { throw 'Only the selected emulator is allowed' }
$gradleArguments = @(':app:testDebugUnitTest', ':app:assembleDebug', ':app:assembleDebugAndroidTest', '--offline', '-Ptarget-platform=android-x64', '-Pandroid.injected.build.abi=x86_64')
if ($Mode -eq 'ui') {
    $gradleArguments += '-Ptarget=' + (Join-Path $projectDirectory 'integration_test/local_diagnostics_android_test.dart')
    $gradleArguments += '-Pdart-defines=' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('DIAGNOSTICS_QA_ISOLATED=true'))
} else { $gradleArguments += '-Ptarget=' + (Join-Path $projectDirectory 'lib/main.dart') }
& "$PSScriptRoot/diagnostics_dev.ps1" -Tool gradle -ToolArgs $gradleArguments *> "docs/qa/local-diagnostics/android-$Mode-build.log"
if ($LASTEXITCODE -ne 0) { throw "Android $Mode build failed; see D: project evidence log" }
# AGP 9 packages to intermediates; outputs/apk may be an old AGP artifact.
$applicationApk = Join-Path $projectDirectory 'build/app/intermediates/apk/debug/app-debug.apk'
$testsApk = Join-Path $projectDirectory 'build/app/intermediates/apk/androidTest/debug/app-debug-androidTest.apk'
foreach ($apk in @($applicationApk,$testsApk)) { if (!(Test-Path -LiteralPath $apk)) { throw "Current APK missing: $apk" } }
if ($CompatibilityKey) {
    if (!(Test-Path -LiteralPath $CompatibilityKey)) { throw 'Existing compatibility debug key is unavailable' }
    $compatibleDirectory = Join-Path $projectDirectory 'build/local-diagnostics'
    New-Item -ItemType Directory -Force -Path $compatibleDirectory | Out-Null
    $signer = Join-Path $env:ANDROID_HOME 'build-tools/36.1.0/apksigner.bat'
    $compatibleApp = Join-Path $compatibleDirectory "app-$Mode-compatible.apk"
    $compatibleTests = Join-Path $compatibleDirectory "tests-$Mode-compatible.apk"
    & $signer sign --ks $CompatibilityKey --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out $compatibleApp $applicationApk
    if ($LASTEXITCODE -ne 0) { throw 'Debug compatibility signing failed' }
    & $signer sign --ks $CompatibilityKey --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out $compatibleTests $testsApk
    if ($LASTEXITCODE -ne 0) { throw 'Debug compatibility signing failed' }
    $applicationApk = $compatibleApp; $testsApk = $compatibleTests
}
& $adbExecutable -s $serial install -r -t $applicationApk
if ($LASTEXITCODE -ne 0) { throw 'Install failed; existing application data was retained' }
& $adbExecutable -s $serial install -r -t $testsApk
if ($LASTEXITCODE -ne 0) { throw 'Test runner install failed; existing application data was retained' }
if ($Mode -eq 'ui') {
    $arguments = @('-s',$serial,'shell','am','instrument','-w','-r','-e','class','com.settrace.settrace.DiagnosticsIntegrationTest','-e','diagnosticsQa','true','com.settrace.settrace.test/androidx.test.runner.AndroidJUnitRunner')
} else {
    $arguments = @('-s',$serial,'shell','am','instrument','-w','-r','-e','class','com.settrace.settrace.DiagnosticsPlatformTest,com.settrace.settrace.RestAlertsStoreTest','com.settrace.settrace.test/androidx.test.runner.AndroidJUnitRunner')
}
$testLog = Join-Path $projectDirectory "docs/qa/local-diagnostics/android-$Mode-tests.log"
& $adbExecutable @arguments *> $testLog
Get-Content -LiteralPath $testLog -Tail 24
if ((Get-Content -LiteralPath $testLog -Raw) -notmatch '(?m)^OK \(') { throw 'Instrumentation did not report passing tests' }
