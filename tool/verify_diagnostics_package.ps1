param([string]$Package, [string]$Result)
$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
Set-Location -LiteralPath $projectDirectory
if (!$Result) { $Result = 'docs/qa/local-diagnostics/android-ui/local-diagnostics-evidence/export-result.json' }
$expected = Get-Content -LiteralPath $Result -Raw | ConvertFrom-Json
if (!$Package) { $Package = Join-Path 'docs/qa/local-diagnostics/android-ui' $expected.file_name }
$packagePath = (Resolve-Path -LiteralPath $Package).Path
if (!(Get-Item -LiteralPath $packagePath).Length -or (Get-Item -LiteralPath $packagePath).Length -gt 24MB) { throw 'Invalid ZIP size' }
if ((Get-Item -LiteralPath $packagePath).Length -ne $expected.bytes) { throw 'Published result size mismatch' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($packagePath)
try {
    $contents = @{}; [long]$expandedBytes = 0
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notmatch '^(manifest\.json|summary\.txt|environment\.json|state\.json|(events|incidents)/[0-9]{3}\.jsonl)$') { throw 'Unexpected entry or unsafe path' }
        if ($contents.ContainsKey($entry.FullName)) { throw 'Duplicate entry' }
        $expandedBytes += $entry.Length
        if ($expandedBytes -gt 24MB) { throw 'Expanded package exceeds content budget' }
        $reader = [IO.StreamReader]::new($entry.Open(), [Text.UTF8Encoding]::new($false, $true))
        try { $contents[$entry.FullName] = $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    foreach ($required in @('manifest.json','summary.txt','environment.json')) { if (!$contents.ContainsKey($required)) { throw "Missing $required" } }
    $manifest = $contents['manifest.json'] | ConvertFrom-Json
    if ($manifest.format -ne 'settrace.diagnostics' -or $manifest.format_version -ne 1 -or $manifest.encrypted -ne $false) { throw 'Unknown diagnostic format' }
    if (@($manifest.entries).Count -ne $contents.Count - 1) { throw 'Unlisted content' }
    foreach ($item in $manifest.entries) {
        if ($item.path -eq 'manifest.json' -or !$contents.ContainsKey($item.path)) { throw 'Invalid manifest resource' }
        $bytes = [Text.Encoding]::UTF8.GetBytes($contents[$item.path])
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
        if ($bytes.Length -ne $item.bytes -or $hash -ne $item.sha256) { throw "Content hash/size mismatch: $($item.path)" }
    }
    $allowedEventKeys = @('schema_version','event_name','module','origin','phase','outcome','severity','reason_code','operation_id','parent_operation_id','correlation_id','process_instance','sequence','monotonic_us','clock_domain','time_utc','observed_time_utc','timezone_offset_minutes','dataset_epoch','generation','attributes','objects','incident_id','repeat_count','last_observed_utc')
    [long]$eventCount = 0; $eventNames = @{}
    foreach ($path in $contents.Keys) {
        $text = $contents[$path]
        if ($text -match 'PRIVATE_|47\.125|content://|/storage/emulated/|(?i)SELECT\s+.+\s+FROM\s+') { throw "Privacy sentinel or raw source leakage: $path" }
        if ($path -notmatch '^events/') { continue }
        foreach ($line in ($text -split "`n" | Where-Object { $_ })) {
            if ([Text.Encoding]::UTF8.GetByteCount($line) -gt 8KB) { throw 'Oversized event' }
            $event = $line | ConvertFrom-Json
            if ($event.schema_version -ne 1) { throw 'Unknown event schema' }
            foreach ($key in $event.PSObject.Properties.Name) { if ($key -notin $allowedEventKeys) { throw "Unlisted event field: $key" } }
            foreach ($identity in $event.objects.PSObject.Properties) { if ($identity.Value -notmatch '^[a-f0-9]{64}$') { throw 'Raw business ID' } }
            $eventCount++; $eventNames[$event.event_name] = $true
        }
    }
    if ($eventCount -ne $manifest.event_count) { throw 'Event count mismatch' }
    if ((@($expected.missing) -join ',') -ne (@($manifest.known_missing) -join ',')) { throw 'Missing evidence differs from UI result' }
    [ordered]@{
        verified = $true; package = $packagePath; bytes = (Get-Item -LiteralPath $packagePath).Length
        sha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        expanded_bytes = $expandedBytes; entries = @($contents.Keys | Sort-Object)
        event_count = $eventCount; event_names = @($eventNames.Keys | Sort-Object)
        known_missing = @($manifest.known_missing); loss_counts = $manifest.loss_counts
        state = if ($contents.ContainsKey('state.json')) { $contents['state.json'] | ConvertFrom-Json } else { $null }
        active_rest_unchanged = $expected.active_rest_unchanged; completed_count = $expected.completed_count
        checks = @('resource sizes and SHA-256','bounded safe archive paths','event field whitelist and HMAC identities','test privacy sentinels','no key/control/journal/database entries','result/manifest missing reasons agree')
        privacy_scope = 'Test sentinels and schema checks; not a proof about arbitrary future producers'
    } | ConvertTo-Json -Depth 12
} finally { $zip.Dispose() }
