import 'backup_json.dart';

typedef BackupMap = Map<String, Object?>;

/// Immutable, validated domain snapshot. Keys are local to this document;
/// database identifiers and runtime/permission state never enter this model.
class BackupData {
  BackupData._(this.json);
  factory BackupData.fromJson(Object? value) => _read(value, true);
  static void validate(Object? value) => _read(value, false);
  static BackupData _read(Object? value, bool immutable) {
    final data = object(value, const ['plans', 'workouts', 'settings']);
    final plans = array(data['plans']);
    final workouts = array(data['workouts']);
    final planKeys = <String>{};
    final exerciseOwners = <String, String>{};
    final workoutKeys = <String>{};
    final sessionExerciseKeys = <String>{};
    final batchKeys = <String>{};
    for (final item in plans) {
      final p = object(item, const [
        'key',
        'name',
        'createdAt',
        'updatedAt',
        'exercises',
      ]);
      final key = unique(p['key'], planKeys);
      string(p['name']);
      timestamp(p['createdAt']);
      timestamp(p['updatedAt']);
      for (final item in array(p['exercises'])) {
        final e = object(item, const ['key', 'name', ...exerciseFields]);
        final ek = string(e['key']);
        if (exerciseOwners.containsKey(ek)) invalidBackup();
        exerciseOwners[ek] = key;
        string(e['name']);
        validateExercise(e);
      }
    }
    for (final item in workouts) {
      final w = object(item, const [
        'key',
        'sourcePlanKey',
        'planNameSnapshot',
        'startedAt',
        'startedLocalDate',
        'endedAt',
        'durationSeconds',
        'exercises',
      ]);
      unique(w['key'], workoutKeys);
      final source = nullableString(w['sourcePlanKey']);
      if (source != null && !planKeys.contains(source)) invalidBackup();
      string(w['planNameSnapshot']);
      timestamp(w['startedAt']);
      timestamp(w['endedAt']);
      integer(w['durationSeconds'], min: 0);
      localDate(w['startedLocalDate']);
      final sequences = <int>{};
      for (final item in array(w['exercises'])) {
        final e = object(item, const [
          'key',
          'sourceExerciseKey',
          'nameSnapshot',
          ...exerciseFields,
          'sets',
          'skipBatches',
        ]);
        unique(e['key'], sessionExerciseKeys);
        final origin = nullableString(e['sourceExerciseKey']);
        if (origin != null &&
            (!exerciseOwners.containsKey(origin) ||
                exerciseOwners[origin] != source)) {
          invalidBackup();
        }
        string(e['nameSnapshot']);
        validateExercise(e);
        final batches = <String, BackupMap>{};
        for (final item in array(e['skipBatches'])) {
          final b = object(item, const ['key', 'createdAt', 'undoneAt']);
          final bk = unique(b['key'], batchKeys);
          timestamp(b['createdAt']);
          if (b['undoneAt'] != null) timestamp(b['undoneAt']);
          batches[bk] = b;
        }
        final sets = array(e['sets']);
        if (sets.length != e['targetSets']) invalidBackup();
        for (var i = 0; i < sets.length; i++) {
          final s = object(sets[i], const [
            'setNumber',
            'completedAt',
            'completedSequence',
            'skippedAt',
            'skipBatchKey',
          ]);
          if (integer(s['setNumber'], min: 1) != i + 1) invalidBackup();
          final completed = s['completedAt'];
          final skipped = s['skippedAt'];
          final batch = nullableString(s['skipBatchKey']);
          if ((completed != null && skipped != null) ||
              ((completed == null) != (s['completedSequence'] == null)) ||
              ((skipped == null) != (batch == null))) {
            invalidBackup();
          }
          if (completed != null) {
            timestamp(completed);
            if (!sequences.add(integer(s['completedSequence'], min: 1))) {
              invalidBackup();
            }
          }
          if (skipped != null) {
            timestamp(skipped);
            if (!batches.containsKey(batch) ||
                batches[batch]!['undoneAt'] != null) {
              invalidBackup();
            }
          }
        }
      }
    }
    BackupSettings.fromJson(data['settings']);
    return BackupData._(immutable ? freeze(data) as BackupMap : data);
  }

  final BackupMap json;
  List<BackupMap> get plans => (json['plans'] as List).cast<BackupMap>();
  List<BackupMap> get workouts => (json['workouts'] as List).cast<BackupMap>();
  BackupSettings get settings => BackupSettings.fromJson(json['settings']);
  BackupMap toJson() => json;
}

class BackupSettings {
  BackupSettings._(this.json);
  factory BackupSettings.fromJson(Object? value) {
    final s = object(value, const [
      'themeMode',
      'themeColor',
      'languageTag',
      'reminder',
    ]);
    choice(s['themeMode'], const ['system', 'light', 'dark']);
    choice(s['themeColor'], const ['teal', 'blue', 'violet', 'graphite']);
    choice(s['languageTag'], const ['en', 'zh']);
    final r = object(s['reminder'], const [
      'enabled',
      'sound',
      'vibration',
      'repeat',
      'interval',
    ]);
    for (final k in ['enabled', 'vibration', 'repeat']) {
      if (r[k] is! bool) invalidBackup();
    }
    choice(r['sound'], const ['three_tone', 'double_beep', 'voice']);
    if (![10, 15, 30, 60].contains(integer(r['interval']))) invalidBackup();
    return BackupSettings._(freeze(s) as BackupMap);
  }
  final BackupMap json;
  String get themeMode => json['themeMode'] as String;
  String get themeColor => json['themeColor'] as String;
  String get languageTag => json['languageTag'] as String;
  BackupMap get reminder => json['reminder'] as BackupMap;
  BackupMap toJson() => json;
}

const exerciseFields = [
  'targetSets',
  'restBetweenSetsSeconds',
  'restAfterExerciseSeconds',
  'defaultWeightKg',
];

void validateExercise(BackupMap e) {
  integer(e['targetSets'], min: 1);
  integer(e['restBetweenSetsSeconds'], min: 0);
  integer(e['restAfterExerciseSeconds'], min: 0);
  final weight = e['defaultWeightKg'];
  if (weight != null &&
      (weight is! num ||
          !weight.isFinite ||
          weight < 0 ||
          weight.abs() > backupMaxInteger)) {
    invalidBackup();
  }
}

BackupMap object(Object? value, List<String> fields) {
  if (value is! BackupMap ||
      value.length != fields.length ||
      !fields.every(value.containsKey)) {
    invalidBackup();
  }
  return value;
}

List<Object?> array(Object? value) {
  if (value is! List<Object?>) invalidBackup();
  return value;
}

String string(Object? value) {
  if (value is! String || value.isEmpty) invalidBackup();
  validateUnicode(value);
  return value;
}

String? nullableString(Object? value) => value == null ? null : string(value);

String unique(Object? value, Set<String> keys) {
  final key = string(value);
  if (!keys.add(key)) invalidBackup();
  return key;
}

int integer(Object? value, {int min = -backupMaxInteger}) {
  if (value is! num ||
      !value.isFinite ||
      value != value.truncateToDouble() ||
      value < min ||
      value.abs() > backupMaxInteger) {
    invalidBackup();
  }
  return value.toInt();
}

void timestamp(Object? value) {
  final time = integer(value);
  if (time.abs() > 8640000000000000) invalidBackup();
}

void localDate(Object? value) {
  final date = string(value);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) invalidBackup();
  final parsed = DateTime.tryParse('${date}T00:00:00Z');
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != date) {
    invalidBackup();
  }
}

void choice(Object? value, List<String> allowed) {
  if (!allowed.contains(value)) invalidBackup();
}

Object? freeze(Object? value) {
  if (value is BackupMap) {
    return Map<String, Object?>.unmodifiable(
      value.map((k, v) => MapEntry(k, freeze(v))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(freeze));
  return value;
}
