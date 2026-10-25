$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
Set-Location -LiteralPath $projectDirectory
& "$PSScriptRoot/diagnostics_dev.ps1" -CheckOnly
$evidenceDirectory = Join-Path $projectDirectory 'docs/qa/local-diagnostics/android-ui'
New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
$archive = Join-Path $evidenceDirectory 'screenshots.tar'
$process = [Diagnostics.Process]::new()
$process.StartInfo.FileName = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
$process.StartInfo.UseShellExecute = $false
$process.StartInfo.CreateNoWindow = $true
$process.StartInfo.RedirectStandardOutput = $true
$process.StartInfo.Arguments = '-s emulator-5554 exec-out run-as com.settrace.settrace tar -cf - -C code_cache local-diagnostics-evidence'
if (!$process.Start()) { throw 'Unable to read emulator evidence' }
$fileStream = [IO.File]::Create($archive)
try { $process.StandardOutput.BaseStream.CopyTo($fileStream) } finally { $fileStream.Dispose() }
$process.WaitForExit()
if ($process.ExitCode -ne 0) { throw 'Evidence transfer failed' }
$entries = & tar.exe -tf $archive
if ($LASTEXITCODE -ne 0 -or $entries.Count -eq 0) { throw 'Invalid evidence archive' }
foreach ($entry in $entries) {
    if (!$entry.StartsWith('local-diagnostics-evidence/') -or $entry.Contains('..') -or $entry.Contains(':')) { throw 'Unsafe evidence path' }
}
& tar.exe -xf $archive -C $evidenceDirectory
if ($LASTEXITCODE -ne 0) { throw 'Evidence extraction failed' }
Remove-Item -LiteralPath $archive
$resultPath = Join-Path $evidenceDirectory 'local-diagnostics-evidence/export-result.json'
$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
if ($result.file_name -notmatch '^SetTrace-diagnostics-[A-Za-z0-9-]+\.zip$') { throw 'Unexpected generated file name' }
& (Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe') -s emulator-5554 pull "/sdcard/Download/$($result.file_name)" (Join-Path $evidenceDirectory $result.file_name)
if ($LASTEXITCODE -ne 0) { throw 'Unable to copy the verified public test ZIP' }
Get-ChildItem -LiteralPath $evidenceDirectory -Recurse -File | Select-Object Name,Length
