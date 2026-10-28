// Wire values intentionally match the native, versioned contract.
// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'dart:math';

/// Closed vocabulary: user strings, SQL arguments and exception messages are
/// never accepted as diagnostic attributes.
enum DiagnosticName {
  appLifecycle('app.lifecycle'),
  restCallback('rest.callback'),
  restTransition('rest.transition'),
  restAudio('rest.audio'),
  startupBegin('startup.begin'),
  startupDatabase('startup.database'),
  startupReady('startup.ready'),
  startupRecovery('startup.recovery'),
  startupExit('startup.exit'),
  planCreate('plan.create'),
  planRead('plan.read'),
  planEdit('plan.edit'),
  planDelete('plan.delete'),
  planReorder('plan.reorder'),
  planExerciseCreate('plan.exercise_create'),
  planExerciseEdit('plan.exercise_edit'),
  planExerciseDelete('plan.exercise_delete'),
  workoutStart('workout.start'),
  workoutRecover('workout.recover'),
  workoutComplete('workout.complete'),
  workoutUndoComplete('workout.undo_complete'),
  workoutRestoreSkipped('workout.restore_skipped'),
  workoutSkipRemaining('workout.skip_remaining'),
  workoutEdit('workout.edit'),
  workoutReorder('workout.reorder'),
  workoutRestAdjust('workout.rest_adjust'),
  workoutRestEnd('workout.rest_end'),
  workoutSave('workout.save'),
  workoutDiscard('workout.discard'),
  restSynchronize('rest.synchronize'),
  restSchedule('rest.schedule'),
  restClaim('rest.claim'),
  restOutput('rest.output'),
  restNext('rest.next'),
  restAcknowledge('rest.acknowledge'),
  restCancel('rest.cancel'),
  historyRead('history.read'),
  historyDelete('history.delete'),
  historyRefresh('history.refresh'),
  transferParse('plan_transfer.parse'),
  transferImport('plan_transfer.import'),
  transferExport('plan_transfer.export'),
  transferCopy('plan_transfer.copy'),
  backupExport('backup.export'),
  backupProtect('backup.protect'),
  backupRestore('backup.restore'),
  backupUndo('backup.undo'),
  backupSettings('backup.settings'),
  backupRecovery('backup.recovery'),
  settingsSave('settings.save'),
  navigationNotification('navigation.notification'),
  diagnosticsPolicy('diagnostics.policy'),
  diagnosticsExport('diagnostics.export'),
  diagnosticsClear('diagnostics.clear'),
  diagnosticsLoss('diagnostics.loss'),
  errorUnhandled('diagnostics.unhandled');

  const DiagnosticName(this.wire);
  final String wire;
}

enum DiagnosticPhase {
  started,
  validation,
  transaction,
  committed,
  readback,
  refresh,
  schedule,
  claim,
  output,
  acknowledged,
  cancelled,
  preparing,
  protected,
  core_committed,
  settings_pending,
  completed,
  inspecting,
  rejected,
  failed,
}

enum DiagnosticOutcome {
  committed,
  rejected,
  cancelled,
  rolled_back_confirmed,
  partial_success,
  unknown,
  observed,
}

enum DiagnosticSeverity { debug, info, warn, error, fatal }

enum DiagnosticReason {
  crash,
  native_crash,
  anr,
  low_memory,
  user_requested,
  user_stopped,
  self_exit,
  signaled,
  excessive_resource,
  dependency_died,
  initialization_failure,
  none,
  validation,
  stale_position,
  not_found,
  active_session,
  no_completed_sets,
  position_locked,
  name_conflict,
  unsupported_version,
  invalid_format,
  size_limit,
  permission_denied,
  permission_permanent,
  channel_disabled,
  exact_alarm_unavailable,
  storage_unavailable,
  no_space,
  io,
  sqlite,
  platform,
  state,
  format,
  unhandled,
  unknown,
  cancelled,
  old_revision,
  old_round,
  already_acknowledged,
  expired,
  invalid_session,
  restore_guard,
  condition_mismatch,
  claim_lost,
  foreground,
  background,
  user_disabled,
  followup_failed,
  read_failed,
  write_failed,
  verification_failed,
  publication_unknown,
  missing,
  unsupported,
  not_available,
  truncated,
  sanitization_rejected,
  queue_overflow,
  rate_limited,
  clock_changed,
  corrupt_tail,
  corrupt_control,
  busy,
  timeout,
  incomplete,
  initialization,
}

enum DiagnosticObject {
  plan,
  exercise,
  session,
  session_exercise,
  backup,
  rest_alert,
}

enum DiagnosticField {
  trigger,
  next_round,
  notification_requested,
  sound_requested,
  vibration_requested,
  identity_unknown,
  truncated_count,
  audio_state,
  sound_condition,
  before_state,
  after_state,
  ringer_mode,
  notification_volume,
  interruption_filter,
  channel_has_sound,
  channel_importance,
  readings_available,
  subject_build_unknown,
  count,
  before_count,
  after_count,
  target_count,
  completed_count,
  skipped_count,
  revision,
  round,
  due_utc,
  actual_utc,
  source_epoch,
  target_epoch,
  duration_ms,
  bytes,
  enabled,
  repeat,
  sound,
  vibrate,
  notifications_allowed,
  channel_allowed,
  exact_allowed,
  foreground,
  mode,
}

enum DiagnosticValue {
  startup,
  resume,
  foreground_poll,
  alarm,
  delivered_callback,
  training_change,
  acknowledge,
  settings_change,
  platform_cleanup,
  preview,
  requested,
  started,
  completed,
  stopped,
  failed,
  suppressed,
  allowed,
  silent,
  zero_volume,
  dnd,
  channel_silent,
  channel_quiet,
  create_failed,
  playback_failed,
  busy,
  bounded_stop,
  pending,
  consumed,
  expired,
  cancelled,
  resumed,
  inactive,
  hidden,
  paused,
  detached,
  exact,
  inexact,
  foreground,
  background,
  disabled,
  unsupported,
  unknown,
  system,
  light,
  dark,
  teal,
  blue,
  violet,
  graphite,
  en,
  zh,
}

String diagnosticId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

Map<String, Object> diagnosticFields(Map<DiagnosticField, Object> fields) {
  final result = <String, Object>{};
  for (final entry in fields.entries) {
    final value = entry.value;
    if (diagnosticEnumFields.containsKey(entry.key)) {
      if (value is DiagnosticValue &&
          diagnosticEnumFields[entry.key]!.contains(value.name)) {
        result[entry.key.name] = value.name;
      }
    } else if (const {
      DiagnosticField.enabled,
      DiagnosticField.repeat,
      DiagnosticField.sound,
      DiagnosticField.vibrate,
      DiagnosticField.notifications_allowed,
      DiagnosticField.channel_allowed,
      DiagnosticField.exact_allowed,
      DiagnosticField.foreground,
      DiagnosticField.notification_requested,
      DiagnosticField.sound_requested,
      DiagnosticField.vibration_requested,
      DiagnosticField.identity_unknown,
      DiagnosticField.channel_has_sound,
      DiagnosticField.readings_available,
      DiagnosticField.subject_build_unknown,
    }.contains(entry.key)) {
      if (value is bool) result[entry.key.name] = value;
    } else if (value is int && value >= 0 && value <= 0x1fffffffffffff) {
      result[entry.key.name] = value;
    }
  }
  return result;
}

const diagnosticEnumFields = <DiagnosticField, Set<String>>{
  DiagnosticField.mode: {
    'exact',
    'inexact',
    'foreground',
    'background',
    'disabled',
    'unsupported',
    'unknown',
    'system',
    'light',
    'dark',
    'teal',
    'blue',
    'violet',
    'graphite',
    'en',
    'zh',
  },
  DiagnosticField.trigger: {
    'startup',
    'resume',
    'foreground_poll',
    'alarm',
    'delivered_callback',
    'training_change',
    'acknowledge',
    'settings_change',
    'platform_cleanup',
    'preview',
    'unknown',
  },
  DiagnosticField.audio_state: {
    'requested',
    'started',
    'completed',
    'stopped',
    'failed',
    'suppressed',
    'unknown',
  },
  DiagnosticField.sound_condition: {
    'allowed',
    'silent',
    'zero_volume',
    'dnd',
    'channel_silent',
    'channel_quiet',
    'unknown',
    'create_failed',
    'playback_failed',
    'busy',
    'bounded_stop',
  },
  DiagnosticField.before_state: {
    'pending',
    'consumed',
    'expired',
    'cancelled',
    'resumed',
    'inactive',
    'hidden',
    'paused',
    'detached',
    'unknown',
  },
  DiagnosticField.after_state: {
    'pending',
    'consumed',
    'expired',
    'cancelled',
    'resumed',
    'inactive',
    'hidden',
    'paused',
    'detached',
    'unknown',
  },
};

/// Frame locations only. No exception text or arbitrary absolute source paths.
List<String> diagnosticFrames(StackTrace? stack) {
  if (stack == null) return const [];
  final frames = <String>[];
  var bytes = 0;
  final location = RegExp(
    r'(?:^|[\s(])(package:(?:settrace|flutter)/[a-zA-Z0-9_/]+\.dart:\d+(?::\d+)?|dart:[a-z_][a-zA-Z0-9_/]*(?:\.dart)?:\d+(?::\d+)?)',
  );
  for (final line in stack.toString().split('\n').take(256)) {
    final match = location.firstMatch(line);
    if (match == null) continue;
    final frame = match.group(1)!;
    final size = utf8.encode(frame).length;
    if (bytes + size > 32 * 1024 || frames.length >= 96) break;
    frames.add(frame);
    bytes += size;
  }
  return frames;
}

class DiagnosticEvent {
  DiagnosticEvent({
    required this.name,
    required this.phase,
    required this.outcome,
    required this.operationId,
    required this.processId,
    required this.sequence,
    required this.monotonicUs,
    required this.time,
    this.level = DiagnosticSeverity.info,
    this.reason = DiagnosticReason.none,
    this.epoch,
    this.generation,
    this.parentOperationId,
    this.backupOperation,
    this.fields = const {},
    this.objects = const {},
    this.frames = const [],
  });

  final DiagnosticName name;
  final DiagnosticPhase phase;
  final DiagnosticOutcome outcome;
  final DiagnosticSeverity level;
  final DiagnosticReason reason;
  final String operationId, processId;
  final String? parentOperationId, generation;
  final String? backupOperation;
  final int sequence, monotonicUs;
  final int? epoch;
  final DateTime time;
  final Map<DiagnosticField, Object> fields;
  final Map<DiagnosticObject, Object> objects;
  final List<String> frames;

  Map<String, Object?> toWire() => {
    'schema_version': 2,
    'event_name': name.wire,
    'phase': phase.name,
    'outcome': outcome.name,
    'severity': level.name,
    'reason_code': reason.name,
    'operation_id': operationId,
    'parent_operation_id': parentOperationId,
    if (name.wire.startsWith('backup.') &&
        backupOperation != null &&
        RegExp(r'^[a-f0-9]{32}$').hasMatch(backupOperation!))
      'durable_backup_operation': backupOperation,
    'process_instance': processId,
    'sequence': sequence,
    'monotonic_us': monotonicUs,
    'clock_domain': 'dart',
    'time_utc': time.toUtc().millisecondsSinceEpoch,
    'timezone_offset_minutes': time.timeZoneOffset.inMinutes,
    'dataset_epoch': epoch,
    'generation': generation,
    'attributes': {
      ...diagnosticFields(fields),
      if (objects.isNotEmpty && epoch == null) 'identity_unknown': true,
    },
    'objects': {
      for (final item in objects.entries)
        if (item.value is int && (item.value as int) >= 0 ||
            item.key == DiagnosticObject.backup &&
                item.value is String &&
                RegExp(r'^[a-f0-9]{32}$').hasMatch(item.value as String))
          item.key.name: item.value,
    },
    'frames': frames,
  };
}

class DiagnosticsOverview {
  DiagnosticsOverview.fromWire(Map<String, Object?> value)
    : enabled = value['enabled'] as bool,
      generation = value['generation'] as String,
      bytes = value['bytes'] as int,
      eventCount = value['event_count'] as int,
      firstTime = _time(value['first_time']),
      lastTime = _time(value['last_time']),
      detailedUntil = _time(value['detailed_until']),
      missing = List<String>.from(value['missing'] as List),
      limited = value['limited'] as bool;

  final bool enabled, limited;
  final String generation;
  final int bytes, eventCount;
  final DateTime? firstTime, lastTime, detailedUntil;
  final List<String> missing;
  static DateTime? _time(Object? value) =>
      value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
}

enum DiagnosticExportStage {
  collecting,
  packaging,
  writing_unpublished,
  verifying,
  publishing,
  cancelling,
  cancelled,
  saved,
  saved_partial,
  failed,
  unknown,
}

class DiagnosticExportStatus {
  DiagnosticExportStatus.fromWire(Map<String, Object?> value)
    : id = value['export_id'] as String,
      stage = DiagnosticExportStage.values.byName(value['stage'] as String),
      cancellable = value['cancellable'] as bool,
      fileName = value['file_name'] as String?,
      bytes = value['bytes'] as int?,
      reason = value['reason'] as String?,
      missing = List<String>.from((value['missing'] as List?) ?? const []) {
    if (saved &&
        (fileName == null ||
            fileName!.isEmpty ||
            bytes == null ||
            bytes! <= 0)) {
      throw const DiagnosticsFailure('publication_unknown');
    }
  }
  final String id;
  final DiagnosticExportStage stage;
  final bool cancellable;
  final String? fileName, reason;
  final int? bytes;
  final List<String> missing;
  bool get terminal => const {
    DiagnosticExportStage.cancelled,
    DiagnosticExportStage.saved,
    DiagnosticExportStage.saved_partial,
    DiagnosticExportStage.failed,
    DiagnosticExportStage.unknown,
  }.contains(stage);
  bool get saved =>
      stage == DiagnosticExportStage.saved ||
      stage == DiagnosticExportStage.saved_partial;
}

class DiagnosticsFailure implements Exception {
  const DiagnosticsFailure(this.code);
  final String code;
  @override
  String toString() => 'DiagnosticsFailure($code)';
}
