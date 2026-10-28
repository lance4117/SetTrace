param(
    [string]$Avd = 'Pixel_7_Pro',
    [ValidateSet('auto', 'host', 'software', 'swiftshader', 'swangle', 'lavapipe')]
    [string]$Gpu = 'auto',
    [switch]$DisableVulkan
)

$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
Set-Location -LiteralPath $projectDirectory
$env:ANDROID_HOME = 'D:\ProgramData\Android_SDK'
$env:ANDROID_AVD_HOME = 'D:\ProgramData\Android_AVD'
$env:ANDROID_USER_HOME = 'D:\ProgramData\DevCache\Android'
$env:ADB_VENDOR_KEYS = Join-Path $env:ANDROID_USER_HOME 'adbkey'
$env:TEMP = 'D:\ProgramData\DevTemp\settrace-emulator-repair'
$env:TMP = $env:TEMP

# The registered GamePP Vulkan layer supports this process-local opt-out.
$env:DISABLE_GAMEPP_LAYER = '1'
$emulatorExecutable = Join-Path $env:ANDROID_HOME 'emulator\emulator.exe'
if (!(Test-Path -LiteralPath $emulatorExecutable -PathType Leaf)) {
    throw "Android Emulator is missing: $emulatorExecutable"
}
if ($Avd -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Invalid AVD name' }
$avdIndex = Join-Path $env:ANDROID_AVD_HOME "$Avd.ini"
if (!(Test-Path -LiteralPath $avdIndex -PathType Leaf)) { throw "AVD is missing: $avdIndex" }
$avdPathLine = Get-Content -LiteralPath $avdIndex | Where-Object { $_ -match '^path=' } | Select-Object -First 1
if (!$avdPathLine) { throw 'AVD index must contain an absolute path' }
$avdDirectory = [IO.Path]::GetFullPath($avdPathLine.Substring(5))
$avdRoot = [IO.Path]::GetFullPath($env:ANDROID_AVD_HOME).TrimEnd('\') + '\'
if (!$avdDirectory.StartsWith($avdRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "AVD storage is outside the configured D drive directory: $avdDirectory"
}
foreach ($directory in @($env:ANDROID_HOME, $env:ANDROID_AVD_HOME, $avdDirectory)) {
    if (!(Test-Path -LiteralPath $directory -PathType Container)) { throw "Directory is missing: $directory" }
}
$logDirectory = Join-Path $projectDirectory 'build\emulator-repair'
foreach ($directory in @($env:ANDROID_USER_HOME, $env:TEMP, $logDirectory)) {
    if ([IO.Path]::GetPathRoot($directory) -ne 'D:\') { throw "Expected a D drive directory: $directory" }
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
$runId = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$stdout = Join-Path $logDirectory "$runId-stdout.log"
$stderr = Join-Path $logDirectory "$runId-stderr.log"
# Cold boot without reading or overwriting the existing Quick Boot snapshot.
$arguments = @('-avd', $Avd, '-gpu', $Gpu, '-no-snapshot-load', '-no-snapshot-save')
if ($DisableVulkan) { $arguments += @('-feature', '-Vulkan') }
$process = Start-Process -FilePath $emulatorExecutable -ArgumentList $arguments -WorkingDirectory $projectDirectory -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
[pscustomobject]@{
    ProcessId = $process.Id
    Avd = $Avd
    Gpu = $Gpu
    GamePPLayerDisabled = $true
    VulkanDisabled = [bool]$DisableVulkan
    Stdout = $stdout
    Stderr = $stderr
}
