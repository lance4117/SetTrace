param(
    [switch]$CheckOnly,
    [ValidateSet('flutter', 'dart', 'adb')][string]$Tool = 'flutter',
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
$env:TEMP = 'D:\ProgramData\DevTemp\settrace-ui-reference'
$env:TMP = $env:TEMP
$env:APPDATA = 'D:\ProgramData\DevCache\FlutterConfig'
$env:LOCALAPPDATA = 'D:\ProgramData\DevCache\LocalAppData'
$env:JAVA_HOME = 'D:\Program Files\Android Studio\jbr'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:PYTHONDONTWRITEBYTECODE = '1'
$paths = [ordered]@{project=$projectDirectory;sdk=$env:ANDROID_HOME;avd=$env:ANDROID_AVD_HOME;androidUser=$env:ANDROID_USER_HOME;gradle=$env:GRADLE_USER_HOME;pub=$env:PUB_CACHE;temp=$env:TEMP;flutter='D:\DevTools\flutter';jdk=$env:JAVA_HOME;toolConfig=$env:APPDATA;localCache=$env:LOCALAPPDATA}
foreach ($directory in $paths.Values) {
    if (![IO.Path]::GetFullPath($directory).StartsWith('D:\', [StringComparison]::OrdinalIgnoreCase)) { throw "Expected D: path: $directory" }
    if (!(Test-Path -LiteralPath $directory -PathType Container)) {
        if ($directory -eq $env:TEMP) { New-Item -ItemType Directory -Path $directory | Out-Null }
        else { throw "Missing required directory: $directory" }
    }
}
foreach ($index in Get-ChildItem -LiteralPath $env:ANDROID_AVD_HOME -Filter '*.ini' -File) {
    $match = [regex]::Match((Get-Content -LiteralPath $index.FullName -Raw), '(?m)^path=(.+)\r?$')
    if (!$match.Success -or ![IO.Path]::GetFullPath($match.Groups[1].Value.Trim()).StartsWith($env:ANDROID_AVD_HOME + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "AVD storage conflict: $($index.Name)" }
}
if ((Get-Content -LiteralPath 'android/local.properties' -Raw) -notmatch '(?m)^sdk\.dir=D:\\\\ProgramData\\\\Android_SDK\s*$') { throw 'Android SDK configuration conflict' }
foreach ($directory in @($env:TEMP,$env:ANDROID_USER_HOME,$env:GRADLE_USER_HOME,$env:PUB_CACHE)) {
    $probe = Join-Path $directory ('ui-reference-probe-' + [guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($probe, '')
    Remove-Item -LiteralPath $probe
}
$paths | ConvertTo-Json
if ($CheckOnly) { exit 0 }
switch ($Tool) {
    'flutter' { & 'D:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\DevTools\flutter\bin\cache\flutter_tools.snapshot' '--no-version-check' @ToolArgs }
    'dart' { & 'D:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe' @ToolArgs }
    'adb' { & (Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe') @ToolArgs }
}
exit $LASTEXITCODE
