param(
  [ValidatePattern('^emulator-[0-9]+$')][string]$Serial = 'emulator-5554',
  [string]$Label,
  [ValidatePattern('^[a-z0-9-]+$')][string]$Snapshot = 'screen',
  [switch]$SwipeUp,
  [switch]$Back
)
$ErrorActionPreference = 'Stop'
$taskAdb = 'C:\Users\Lance\AppData\Local\Android\sdk\platform-tools\adb.exe'
$taskRoot = Join-Path $PSScriptRoot '../build/qa/rest-alerts'
[System.IO.Directory]::CreateDirectory($taskRoot) | Out-Null
function Get-QaUi {
  for ($taskAttempt = 0; $taskAttempt -lt 5; $taskAttempt++) {
    & $taskAdb -s $Serial shell uiautomator dump /sdcard/settrace-qa.xml 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
      & $taskAdb -s $Serial pull /sdcard/settrace-qa.xml (Join-Path $taskRoot 'current.xml') 2>&1 | Out-Null
      if ($LASTEXITCODE -eq 0) {
        return [xml](Get-Content -Raw -LiteralPath (Join-Path $taskRoot 'current.xml'))
      }
    }
    Start-Sleep -Milliseconds 300
  }
  throw 'UI hierarchy unavailable'
}
if ($Label) {
  $taskUi = Get-QaUi
  $taskCandidates = @($taskUi.SelectNodes('//node') | Where-Object {
    $_.GetAttribute('text') -eq $Label -or $_.GetAttribute('content-desc') -eq $Label
  })
  if ($taskCandidates.Count -eq 0) {
    $taskCandidates = @($taskUi.SelectNodes('//node') | Where-Object {
      $_.GetAttribute('clickable') -eq 'true' -and $_.GetAttribute('content-desc').Contains($Label)
    })
  }
  if ($taskCandidates.Count -ne 1) { throw "Expected one visible label: $Label; found $($taskCandidates.Count)" }
  $taskBounds = $taskCandidates[0].GetAttribute('bounds')
  if ($taskBounds -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') { throw 'Invalid bounds' }
  $taskX = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
  $taskY = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
  "Tap $Label at $taskBounds"
  & $taskAdb -s $Serial shell input tap $taskX $taskY
}
if ($SwipeUp) { & $taskAdb -s $Serial shell input swipe 540 1760 540 720 400 }
if ($Back) { & $taskAdb -s $Serial shell input keyevent 4 }
$taskUi = Get-QaUi
[System.IO.File]::WriteAllText((Join-Path $taskRoot "$Snapshot.xml"), $taskUi.OuterXml, [System.Text.UTF8Encoding]::new($false))
& $taskAdb -s $Serial shell screencap -p /sdcard/settrace-qa.png
& $taskAdb -s $Serial pull /sdcard/settrace-qa.png (Join-Path $taskRoot "$Snapshot.png") 2>&1 | Out-Null
$taskUi.SelectNodes('//*[@text!="" or @content-desc!=""]') | ForEach-Object {
  [pscustomobject]@{ Text=$_.GetAttribute('text'); Description=$_.GetAttribute('content-desc'); Bounds=$_.GetAttribute('bounds') }
}

