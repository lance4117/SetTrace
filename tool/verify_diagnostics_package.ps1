param([string]$Package, [string]$Result)
$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Split-Path $PSScriptRoot -Parent)).Path
Set-Location -LiteralPath $projectDirectory
if (!$Result -and !$Package) { $Result = 'docs/qa/local-diagnostics/android-ui/local-diagnostics-evidence/export-result.json' }
$expected = if ($Result) { Get-Content -LiteralPath $Result -Raw | ConvertFrom-Json } else { $null }
if (!$Package) { $Package = Join-Path 'docs/qa/local-diagnostics/android-ui' $expected.file_name }
$packagePath = (Resolve-Path -LiteralPath $Package).Path
if (!(Get-Item -LiteralPath $packagePath).Length -or (Get-Item -LiteralPath $packagePath).Length -gt 24MB) { throw 'Invalid ZIP size' }
if ($expected -and (Get-Item -LiteralPath $packagePath).Length -ne $expected.bytes) { throw 'Published result size mismatch' }
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
    if ($manifest.format -ne 'settrace.diagnostics' -or $manifest.format_version -notin @(1,2) -or $manifest.encrypted -ne $false) { throw 'Unknown diagnostic format' }
    if (@($manifest.entries).Count -ne $contents.Count - 1) { throw 'Unlisted content' }
    foreach ($item in $manifest.entries) {
        if ($item.path -eq 'manifest.json' -or !$contents.ContainsKey($item.path)) { throw 'Invalid manifest resource' }
        $bytes = [Text.Encoding]::UTF8.GetBytes($contents[$item.path])
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
        if ($bytes.Length -ne $item.bytes -or $hash -ne $item.sha256) { throw "Content hash/size mismatch: $($item.path)" }
    }
    $environment = $contents['environment.json'] | ConvertFrom-Json
    if (@($environment.PSObject.Properties.Name | Where-Object { $_ -notin @('application','android_api','android_version','device_model','captured_utc','notifications_allowed','exact_allowed','exit_information','exit_trace') }).Count) { throw 'Unlisted environment field' }
    if (@($environment.application.PSObject.Properties.Name | Where-Object { $_ -notin @('package','version','build','supported_database_schema','obfuscated') }).Count -or $environment.application.package -ne 'com.settrace.settrace') { throw 'Invalid application metadata' }
    if ($null -ne $environment.application.version -and $environment.application.version -notmatch '^[a-zA-Z0-9._+()-]{1,64}$') { throw 'Invalid version metadata' }
    if ($null -ne $environment.application.build -and $environment.application.build -notmatch '^[0-9]{1,20}$') { throw 'Invalid build metadata' }
    $allowedEventKeys = @('schema_version','event_name','module','origin','phase','outcome','severity','reason_code','operation_id','parent_operation_id','correlation_id','process_instance','sequence','monotonic_us','clock_domain','time_utc','observed_time_utc','timezone_offset_minutes','dataset_epoch','generation','attributes','objects','incident_id','aggregation_count','aggregation_first_mono','aggregation_last_mono')
    $eventsV1 = @('startup.begin','startup.database','startup.ready','startup.recovery','startup.exit',
        'plan.create','plan.read','plan.edit','plan.delete','plan.reorder','plan.exercise_create','plan.exercise_edit','plan.exercise_delete',
        'workout.start','workout.recover','workout.complete','workout.undo_complete','workout.restore_skipped','workout.skip_remaining','workout.edit','workout.reorder','workout.rest_adjust','workout.rest_end','workout.save','workout.discard',
        'rest.synchronize','rest.schedule','rest.claim','rest.output','rest.next','rest.acknowledge','rest.cancel',
        'history.read','history.delete','history.refresh','plan_transfer.parse','plan_transfer.import','plan_transfer.export','plan_transfer.copy',
        'backup.export','backup.protect','backup.restore','backup.undo','backup.settings','backup.recovery','settings.save','navigation.notification',
        'diagnostics.policy','diagnostics.export','diagnostics.clear','diagnostics.loss','diagnostics.unhandled')
    $eventsV2 = @('app.lifecycle','rest.callback','rest.transition','rest.audio','rest.service')
    $phases = @('started','validation','transaction','committed','readback','refresh','schedule','claim','output','acknowledged','cancelled','preparing','protected','core_committed','settings_pending','completed','inspecting','rejected','failed')
    $outcomes = @('committed','rejected','cancelled','rolled_back_confirmed','partial_success','unknown','observed')
    $reasons = @('crash','native_crash','anr','low_memory','user_requested','user_stopped','self_exit','signaled','excessive_resource','dependency_died','initialization_failure','none','validation','stale_position','not_found','active_session','no_completed_sets','position_locked','name_conflict','unsupported_version','invalid_format','size_limit','permission_denied','permission_permanent','channel_disabled','exact_alarm_unavailable','storage_unavailable','no_space','io','sqlite','platform','state','format','unhandled','unknown','cancelled','old_revision','old_round','already_acknowledged','expired','invalid_session','restore_guard','condition_mismatch','claim_lost','foreground','background','user_disabled','followup_failed','read_failed','write_failed','verification_failed','publication_unknown','missing','unsupported','not_available','truncated','sanitization_rejected','queue_overflow','rate_limited','clock_changed','corrupt_tail','corrupt_control','busy','timeout','incomplete','initialization','lease_timeout','permission_lost','task_removed')
    $numbersV1 = @('count','before_count','after_count','target_count','completed_count','skipped_count','revision','round','due_utc','actual_utc','source_epoch','target_epoch','duration_ms','bytes')
    $numbersV2 = @('lease_expires_elapsed','next_round','truncated_count','ringer_mode','notification_volume','interruption_filter','channel_importance')
    $flagsV1 = @('enabled','repeat','sound','vibrate','notifications_allowed','channel_allowed','exact_allowed','foreground')
    $flagsV2 = @('notification_requested','sound_requested','vibration_requested','identity_unknown','channel_has_sound','readings_available','subject_build_unknown')
    $enums = @{
        mode = @('exact','inexact','foreground','background','disabled','unsupported','unknown','system','light','dark','teal','blue','violet','graphite','en','zh')
        trigger = @('service_timer','startup','resume','foreground_poll','alarm','delivered_callback','training_change','acknowledge','settings_change','platform_cleanup','preview','unknown')
        source = @('foreground_poll','warm_resume','service_timer','alarm','cold_recovery','settings_refresh')
        service_state = @('starting','running','stopping','stopped','blocked','failed','unknown')
        recovery_decision = @('future_kept','warm_claim_eligible','cold_history_expired','window_expired','repeat_rebased','invalidated','guarded','unknown')
        cancel_reason = @('acknowledge','manual_rest_end','deadline_replaced','undo_complete','restore_skipped','skip_remaining','training_advance','workout_saved','workout_discarded','user_disabled','restore_guard','lease_timeout','permission_lost','task_removed','platform_cleanup','unknown')
        audio_state = @('requested','started','completed','stopped','failed','suppressed','unknown')
        sound_condition = @('allowed','silent','zero_volume','dnd','channel_silent','channel_quiet','unknown','create_failed','playback_failed','busy','bounded_stop')
        before_state = @('pending','consumed','expired','cancelled','resumed','inactive','hidden','paused','detached','unknown')
        after_state = @('pending','consumed','expired','cancelled','resumed','inactive','hidden','paused','detached','unknown')
    }
    function Test-SafeNumber($Value) { return ($Value -is [long] -or $Value -is [int]) -and $Value -ge 0 -and $Value -le 9007199254740991 }
    if ([Text.Encoding]::UTF8.GetByteCount($contents['summary.txt']) -gt 32KB) { throw 'Oversized summary' }
    if ($manifest.format_version -eq 2) {
        if (@($manifest.process_builds.PSObject.Properties).Count -gt 32) { throw 'Oversized process map' }
        foreach ($mapping in $manifest.process_builds.PSObject.Properties) {
            if ($mapping.Name -notmatch '^[a-f0-9]{32}$') { throw 'Invalid process identity' }
            if ($null -ne $mapping.Value) {
                if (@($mapping.Value.PSObject.Properties.Name | Where-Object { $_ -notin @('version','build') }).Count -or
                    $mapping.Value.version -notmatch '^[a-zA-Z0-9._+()-]{1,64}$' -or $mapping.Value.build -notmatch '^[0-9]{1,20}$') { throw 'Invalid build mapping' }
            }
        }
    }
    [long]$eventCount = 0; $eventNames = @{}
    foreach ($path in $contents.Keys) {
        $text = $contents[$path]
        if ($text -match 'PRIVATE_|47\.125|content://|/storage/emulated/|(?i)SELECT\s+.+\s+FROM\s+') { throw "Privacy sentinel or raw source leakage: $path" }
        if ($path -notmatch '^events/') { continue }
        foreach ($line in ($text -split "`n" | Where-Object { $_ })) {
            if ([Text.Encoding]::UTF8.GetByteCount($line) -gt 8KB) { throw 'Oversized event' }
            $event = $line | ConvertFrom-Json
            if ($event.schema_version -notin @(1,2) -or ($manifest.format_version -eq 1 -and $event.schema_version -ne 1)) { throw 'Unknown event schema' }
            foreach ($key in $event.PSObject.Properties.Name) { if ($key -notin $allowedEventKeys) { throw "Unlisted event field: $key" } }
            if ($event.event_name -notin $eventsV1 -and !($event.schema_version -eq 2 -and $event.event_name -in $eventsV2)) { throw 'Unknown event name' }
            if ($event.phase -notin $phases -or $event.outcome -notin $outcomes -or $event.reason_code -notin $reasons -or $event.severity -notin @('debug','info','warn','error','fatal')) { throw 'Unknown event vocabulary' }
            if ($event.module -ne ($event.event_name -split '\.')[0] -or $event.origin -notin @('dart','android')) { throw 'Invalid module or origin' }
            foreach ($key in @('operation_id','correlation_id','process_instance','generation')) { if ($event.$key -notmatch '^[a-f0-9]{32}$') { throw 'Invalid event token' } }
            if ($null -ne $event.parent_operation_id -and $event.parent_operation_id -notmatch '^[a-f0-9]{32}$') { throw 'Invalid parent token' }
            foreach ($key in @('sequence','time_utc','observed_time_utc')) { if (!(Test-SafeNumber $event.$key)) { throw 'Invalid event number' } }
            if ($event.time_utc -gt $manifest.cutoff_utc -and 'clock_changed' -notin $manifest.known_missing) { throw 'Event beyond snapshot cutoff' }
            if ($event.timezone_offset_minutes -lt -1080 -or $event.timezone_offset_minutes -gt 1080) { throw 'Invalid timezone' }
            if ($event.clock_domain -eq 'unknown') { if ($null -ne $event.monotonic_us) { throw 'Invented historical monotonic time' } }
            elseif ($event.clock_domain -ne "$($event.origin):$($event.process_instance)" -or !(Test-SafeNumber $event.monotonic_us)) { throw 'Invalid clock domain' }
            if (@($event.attributes.PSObject.Properties).Count -gt 24) { throw 'Oversized attributes' }
            foreach ($field in $event.attributes.PSObject.Properties) {
                $key = $field.Name; $value = $field.Value
                if ($key -in $numbersV1 -or ($event.schema_version -eq 2 -and $key -in $numbersV2)) { if (!(Test-SafeNumber $value)) { throw 'Invalid numeric attribute' } }
                elseif ($key -in $flagsV1 -or ($event.schema_version -eq 2 -and $key -in $flagsV2)) { if ($value -isnot [bool]) { throw 'Invalid flag attribute' } }
                elseif ($key -eq 'mode' -or ($event.schema_version -eq 2 -and $enums.ContainsKey($key))) { if ($value -notin $enums[$key]) { throw 'Invalid enum attribute' } }
                else { throw "Unlisted attribute: $key" }
            }
            foreach ($identity in $event.objects.PSObject.Properties) {
                if ($identity.Name -notin @('plan','exercise','session','session_exercise','backup','rest_alert') -or $identity.Value -notmatch '^[a-f0-9]{64}$') { throw 'Raw or invalid business ID' }
            }
            $eventCount++; $eventNames[$event.event_name] = $true
        }
    }
    foreach ($path in @($contents.Keys | Where-Object { $_ -match '^incidents/' })) {
        foreach ($line in ($contents[$path] -split "`n" | Where-Object { $_ })) {
            if ([Text.Encoding]::UTF8.GetByteCount($line) -gt 48KB) { throw 'Oversized incident' }
            $incident = $line | ConvertFrom-Json
            if ($incident.schema_version -notin @(1,2) -or ($manifest.format_version -eq 1 -and $incident.schema_version -ne 1)) { throw 'Unknown incident schema' }
            if (@($incident.PSObject.Properties.Name | Where-Object { $_ -notin @('schema_version','incident_id','time_utc','reason_code','frames') }).Count) { throw 'Unlisted incident field' }
            if ($incident.incident_id -notmatch '^[a-f0-9]{64}$' -or $incident.reason_code -notin $reasons -or @($incident.frames).Count -gt 96) { throw 'Invalid incident' }
            if (($incident.frames -join '').Length -gt 32KB) { throw 'Oversized frames' }
            foreach ($frame in $incident.frames) {
                if ($frame -notmatch '^(package:(settrace|flutter)/[a-zA-Z0-9_/]+\.dart:[0-9]+(:[0-9]+)?|dart:[a-z_][a-zA-Z0-9_/]*(\.dart)?:[0-9]+(:[0-9]+)?|(com\.settrace\.settrace|java|javax|android|kotlin)\.[a-zA-Z0-9_.$]+#[a-zA-Z0-9_<>$]+:[0-9]+)$') { throw 'Unsafe incident frame' }
            }
        }
    }
    if ($eventCount -ne $manifest.event_count) { throw 'Event count mismatch' }
    if ($expected -and (@($expected.missing) -join ',') -ne (@($manifest.known_missing) -join ',')) { throw 'Missing evidence differs from UI result' }
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
