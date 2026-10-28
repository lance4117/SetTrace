param([Parameter(Mandatory=$true)][string]$CompatibilityKey)
$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
Set-Location -LiteralPath $projectDirectory
& "$PSScriptRoot/diagnostics_dev.ps1" -CheckOnly
$adbExecutable = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
if ((& $adbExecutable -s emulator-5554 shell getprop ro.kernel.qemu).Trim() -ne '1') { throw 'QA only permits the selected emulator' }
if (!(Test-Path -LiteralPath $CompatibilityKey -PathType Leaf)) { throw 'Existing compatibility key missing' }
$outputDirectory = Join-Path $projectDirectory 'build/rest-system-sound'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$signer = Join-Path $env:ANDROID_HOME 'build-tools/36.1.0/apksigner.bat'
foreach ($item in @(@('build/app/outputs/apk/debug/app-debug.apk','app-debug-compatible.apk'),@('build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk','tests-compatible.apk'))) {
    $output = Join-Path $outputDirectory $item[1]
    & $signer sign --ks $CompatibilityKey --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out $output $item[0]
    if ($LASTEXITCODE -ne 0) { throw 'Compatibility signing failed' }
    & $adbExecutable -s emulator-5554 install -r -t $output
    if ($LASTEXITCODE -ne 0) { throw 'Install failed; existing data retained' }
}
$testLog = Join-Path $projectDirectory 'docs/qa/rest-system-sound/android-platform.log'
& $adbExecutable -s emulator-5554 shell am instrument -w -r -e class 'com.settrace.settrace.RestAlertsStoreTest,com.settrace.settrace.DiagnosticsPlatformTest' com.settrace.settrace.test/androidx.test.runner.AndroidJUnitRunner *> $testLog
if ((Get-Content -LiteralPath $testLog -Raw) -notmatch '(?m)^OK \(') { throw 'Platform tests failed; inspect log including assumption skips' }
Get-Content -LiteralPath $testLog -Tail 8
