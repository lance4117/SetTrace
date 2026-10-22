param([Parameter(ValueFromRemainingArguments = $true)][string[]]$FlutterArgs)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:ANDROID_HOME = 'D:\ProgramData\Android_SDK'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_AVD_HOME = 'D:\ProgramData\Android_AVD'
$env:ANDROID_USER_HOME = 'D:\ProgramData\DevCache\Android'
$env:ADB_VENDOR_KEYS = Join-Path $env:ANDROID_USER_HOME 'adbkey'
$env:GRADLE_USER_HOME = 'D:\ProgramData\DevCache\Gradle'
$env:PUB_CACHE = 'D:\ProgramData\DevCache\Pub'
$env:TEMP = 'D:\ProgramData\DevTemp\history-summary'
$env:TMP = $env:TEMP
foreach ($directory in @($env:ANDROID_HOME, $env:ANDROID_AVD_HOME, $env:GRADLE_USER_HOME, $env:PUB_CACHE, $env:TEMP)) {
    if (!(Test-Path -LiteralPath $directory -PathType Container)) { throw "Missing D: directory: $directory" }
}
& 'D:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\DevTools\flutter\bin\cache\flutter_tools.snapshot' @FlutterArgs
exit $LASTEXITCODE
