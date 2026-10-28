param(
    [switch]$CheckOnly,
    [ValidateSet('flutter', 'dart', 'gradle', 'adb')][string]$Tool = 'flutter',
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$ToolArgs
)
$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
Set-Location -LiteralPath $projectDirectory
$env:ANDROID_HOME = 'D:\ProgramData\Android_SDK'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_AVD_HOME = 'D:\ProgramData\Android_AVD'
$env:ANDROID_USER_HOME = 'D:\ProgramData\DevCache\Android'
$env:ADB_VENDOR_KEYS = Join-Path $env:ANDROID_USER_HOME 'adbkey'
$env:GRADLE_USER_HOME = 'D:\ProgramData\DevCache\Gradle'
$env:PUB_CACHE = 'D:\ProgramData\DevCache\Pub'
$env:TEMP = 'D:\ProgramData\DevTemp\fix-rest-sound-and-diagnostics'
$env:TMP = $env:TEMP
$env:APPDATA = 'D:\ProgramData\DevCache\FlutterConfig'
$env:LOCALAPPDATA = 'D:\ProgramData\DevCache\LocalAppData'
$env:JAVA_HOME = 'D:\Program Files\Android Studio\jbr'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
foreach ($requiredDirectory in @($env:ANDROID_HOME, $env:ANDROID_AVD_HOME, $env:ANDROID_USER_HOME, $env:GRADLE_USER_HOME, $env:PUB_CACHE)) {
    if (!(Test-Path -LiteralPath $requiredDirectory -PathType Container)) { throw "Missing D: directory: $requiredDirectory" }
}
if (!(Test-Path -LiteralPath $env:TEMP)) { New-Item -ItemType Directory -Path $env:TEMP | Out-Null }
foreach ($toolConfigurationDirectory in @($env:APPDATA, $env:LOCALAPPDATA)) {
    if (!(Test-Path -LiteralPath $toolConfigurationDirectory)) { New-Item -ItemType Directory -Path $toolConfigurationDirectory | Out-Null }
}
if (!(Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin/java.exe'))) { throw 'Missing D: JDK' }
$effectivePaths = [ordered]@{ project = $projectDirectory; sdk = $env:ANDROID_HOME; avd = $env:ANDROID_AVD_HOME; androidUser = $env:ANDROID_USER_HOME; gradle = $env:GRADLE_USER_HOME; pub = $env:PUB_CACHE; temp = $env:TEMP; flutter = 'D:\DevTools\flutter' }
$effectivePaths['toolConfig'] = $env:APPDATA
$effectivePaths['toolLocalCache'] = $env:LOCALAPPDATA
$effectivePaths['jdk'] = $env:JAVA_HOME
foreach ($effectivePath in $effectivePaths.Values) {
    if (!([IO.Path]::GetFullPath($effectivePath).StartsWith('D:\', [StringComparison]::OrdinalIgnoreCase))) { throw "Non D: path: $effectivePath" }
}
$localProperties = Get-Content -LiteralPath 'android/local.properties' -Raw
if ($localProperties -notmatch '(?m)^sdk\.dir=D:\\\\ProgramData\\\\Android_SDK\s*$') { throw 'android/local.properties SDK conflicts with the required D: SDK' }
foreach ($avdIni in Get-ChildItem -LiteralPath $env:ANDROID_AVD_HOME -Filter '*.ini' -File) {
    $pathMatch = [regex]::Match((Get-Content -LiteralPath $avdIni.FullName -Raw), '(?m)^path=(.+)\r?$')
    if (!$pathMatch.Success) { throw "Missing AVD path: $($avdIni.Name)" }
    $avdDiskDirectory = [IO.Path]::GetFullPath($pathMatch.Groups[1].Value.Trim())
    if (!$avdDiskDirectory.StartsWith($env:ANDROID_AVD_HOME + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "AVD outside required directory: $avdDiskDirectory" }
    $effectivePaths["avd:$($avdIni.BaseName)"] = $avdDiskDirectory
}
foreach ($writableDirectory in @($env:ANDROID_USER_HOME, $env:GRADLE_USER_HOME, $env:PUB_CACHE, $env:TEMP)) {
    $probeFile = Join-Path $writableDirectory ('diagnostics-probe-' + [guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($probeFile, '')
    Remove-Item -LiteralPath $probeFile
}
$effectivePaths | ConvertTo-Json
if ($CheckOnly) { exit 0 }
switch ($Tool) {
    'flutter' { & 'D:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\DevTools\flutter\bin\cache\flutter_tools.snapshot' @ToolArgs }
    'dart' { & 'D:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe' @ToolArgs }
    'adb' { & (Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe') @ToolArgs }
    'gradle' { Push-Location (Join-Path $projectDirectory 'android'); try { & '.\gradlew.bat' @ToolArgs } finally { Pop-Location } }
}
exit $LASTEXITCODE
