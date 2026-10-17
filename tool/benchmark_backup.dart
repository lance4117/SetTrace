import 'dart:convert';
import 'dart:io';

import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_json.dart';
import 'package:settrace/features/backup/backup_models.dart';

// Run each case in a separate process so maxRss is attributable to that case.
Future<void> main(List<String> arguments) async {
  final mode = arguments.firstOrNull ?? 'decade';
  final raw = jsonDecode(
    File('test/fixtures/backup/v1-empty.settrace.json').readAsStringSync(),
  ) as BackupMap;
  final document = buildBenchmarkDocument(mode, raw);
  final watch = Stopwatch()..start();
  try {
    final bytes = BackupCodec().encode(document);
    final encodeMs = watch.elapsedMilliseconds;
    watch.reset();
    final decoded = BackupCodec().decode(bytes);
    if (decoded.data.workouts.length != document.data.workouts.length) {
      throw StateError('data loss');
    }
    stdout.writeln(
      jsonEncode({
        'case': mode,
        'bytes': bytes.length,
        'encodeMs': encodeMs,
        'decodeMs': watch.elapsedMilliseconds,
        'peakRssBytes': ProcessInfo.maxRss,
        'workouts': decoded.data.workouts.length,
      }),
    );
  } on BackupException catch (e) {
    if (mode != 'over' || e.code != BackupFailure.tooLarge) rethrow;
    stdout.writeln(
      jsonEncode({
        'case': mode,
        'result': e.code.name,
        'elapsedMs': watch.elapsedMilliseconds,
        'peakRssBytes': ProcessInfo.maxRss,
      }),
    );
  }
}

/// Shared synthetic fixture builder for desktop and Android capacity checks.
BackupDocument buildBenchmarkDocument(String mode, BackupMap raw) {
  raw.remove('integrity');
  final data = raw['data'] as BackupMap;
  if (mode == 'decade') {
    data['workouts'] = List.generate(
      3653,
      (day) => {
        'key': 'w$day',
        'sourcePlanKey': null,
        'planNameSnapshot': '十年训练 Training',
        'startedAt': day * 86400000,
        'startedLocalDate': DateTime.utc(
          2016,
          1,
          1,
        ).add(Duration(days: day)).toIso8601String().substring(0, 10),
        'endedAt': day * 86400000 + 3600000,
        'durationSeconds': 3600,
        'exercises': List.generate(
          8,
          (e) => {
            'key': 'w$day/e$e',
            'sourceExerciseKey': null,
            'nameSnapshot': '动作 Exercise $e',
            'targetSets': 5,
            'restBetweenSetsSeconds': 60,
            'restAfterExerciseSeconds': 90,
            'defaultWeightKg': 25.5,
            'skipBatches': <Object?>[],
            'sets': List.generate(
              5,
              (s) => {
                'setNumber': s + 1,
                'completedAt': day * 86400000 + 1000,
                'completedSequence': e * 5 + s + 1,
                'skippedAt': null,
                'skipBatchKey': null,
              },
            ),
          },
        ),
      },
    );
  } else {
    (raw['metadata'] as BackupMap)['extensions'] = {'padding': ''};
    final empty = BackupCodec().encode(
      BackupDocument(
        backupId: raw['backupId'] as String,
        snapshotAt: DateTime.parse(raw['snapshotAt'] as String),
        exportedAt: DateTime.parse(raw['exportedAt'] as String),
        sourceAppVersion: raw['sourceAppVersion'] as String,
        data: BackupData.fromJson(data),
        extensions: {'padding': ''},
      ),
    );
    ((raw['metadata'] as BackupMap)['extensions'] as BackupMap)['padding'] =
        'x' *
        (backupMaxBytes -
            empty.length +
            (mode == 'over'
                ? 1
                : mode == 'under'
                ? -1
                : 0));
  }
  final document = BackupDocument(
    backupId: raw['backupId'] as String,
    snapshotAt: DateTime.parse(raw['snapshotAt'] as String),
    exportedAt: DateTime.parse(raw['exportedAt'] as String),
    sourceAppVersion: raw['sourceAppVersion'] as String,
    data: BackupData.fromJson(data),
    extensions: (raw['metadata'] as BackupMap)['extensions'] as BackupMap,
  );
  return document;
}
