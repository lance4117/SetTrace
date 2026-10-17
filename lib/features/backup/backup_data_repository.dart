import 'package:sqflite/sqflite.dart';

import 'backup_codec.dart';
import 'backup_json.dart';
import 'backup_metadata_repository.dart';
import 'backup_models.dart';

/// Logical snapshot/restore adapter. Never copies SQLite files or imports
/// runtime cursors, permissions, aggregates, IDs, or backup control metadata.
class BackupDataRepository {
  const BackupDataRepository(this.db);
  final Database db;

  Future<BackupMap?> activeSummary() async => (await db.rawQuery('''
    SELECT s.plan_name_snapshot AS name,
      (SELECT COUNT(*) FROM session_sets ss JOIN session_exercises e
        ON e.id=ss.session_exercise_id WHERE e.session_id=s.id
        AND ss.completed_at IS NOT NULL) AS completed,
      (SELECT COALESCE(SUM(e.target_sets),0) FROM session_exercises e
        WHERE e.session_id=s.id) AS total
    FROM workout_sessions s WHERE s.status='in_progress' LIMIT 1
  ''')).firstOrNull;

  Future<void> requireNoActive(DatabaseExecutor executor) async {
    if ((await executor.query(
      'workout_sessions',
      columns: ['id'],
      where: "status='in_progress'",
      limit: 1,
    )).isNotEmpty) {
      throw const BackupException(BackupFailure.activeWorkout);
    }
  }

  Future<BackupData> snapshot(
    BackupSettings settings, {
    bool overview = false,
  }) => db.transaction((txn) => read(txn, settings, overview: overview));

  Future<BackupData> read(
    DatabaseExecutor txn,
    BackupSettings settings, {
    bool overview = false,
  }) async {
    if (!overview) await requireNoActive(txn);
    final plans = await txn.query('plans', orderBy: 'sort_order ASC, id ASC');
    final exercises = _group(
      await txn.query('plan_exercises', orderBy: 'sort_order ASC'),
      'plan_id',
    );
    final workouts = await txn.query(
      'workout_sessions',
      where: "status='completed'",
      orderBy: 'backup_order ASC, id ASC',
    );
    final historyExercises = _group(
      await txn.query('session_exercises', orderBy: 'sort_order ASC'),
      'session_id',
    );
    final sets = _group(
      await txn.query('session_sets', orderBy: 'set_number ASC'),
      'session_exercise_id',
    );
    final batches = _group(
      await txn.query('session_skip_batches', orderBy: 'id ASC'),
      'session_exercise_id',
    );
    return BackupData.fromJson({
      'plans': [
        for (final p in plans)
          {
            'key': 'p${p['id']}',
            'name': p['name'],
            'createdAt': p['created_at'],
            'updatedAt': p['updated_at'],
            'exercises': [
              for (final e in exercises[p['id']] ?? <BackupMap>[])
                {'key': 'e${e['id']}', 'name': e['name'], ..._configuration(e)},
            ],
          },
      ],
      'workouts': [
        for (final w in workouts)
          {
            'key': 'w${w['id']}',
            'sourcePlanKey': _ref('p', w['source_plan_id']),
            'planNameSnapshot': w['plan_name_snapshot'],
            'startedAt': w['started_at'],
            'startedLocalDate': w['started_local_date'],
            'endedAt': w['ended_at'],
            'durationSeconds': w['duration_seconds'],
            'exercises': [
              for (final e in historyExercises[w['id']] ?? <BackupMap>[])
                {
                  'key': 'we${e['id']}',
                  'sourceExerciseKey': _ref('e', e['source_exercise_id']),
                  'nameSnapshot': e['name_snapshot'],
                  ..._configuration(e),
                  'sets': [
                    for (final s in sets[e['id']] ?? <BackupMap>[])
                      {
                        'setNumber': s['set_number'],
                        'completedAt': s['completed_at'],
                        'completedSequence': s['completed_sequence'],
                        'skippedAt': s['skipped_at'],
                        'skipBatchKey': _ref('b', s['skip_batch_id']),
                      },
                  ],
                  'skipBatches': [
                    for (final b in batches[e['id']] ?? <BackupMap>[])
                      {
                        'key': 'b${b['id']}',
                        'createdAt': b['created_at'],
                        'undoneAt': b['undone_at'],
                      },
                  ],
                },
            ],
          },
      ],
      'settings': settings.toJson(),
    });
  }

  Future<int> replace({
    required String operationId,
    required int expectedEpoch,
    required String expectedCoreDigest,
    required BackupData target,
    required BackupSettings currentSettings,
    Future<void> Function(String table, int index)? afterInsert,
  }) => db.transaction((txn) async {
    final metadata = BackupMetadataRepository(db);
    if (await metadata.epoch(txn) != expectedEpoch) {
      throw const BackupException(BackupFailure.stalePreview);
    }
    final before = await read(txn, currentSettings);
    if ((await BackupFingerprints.compute(before)).coreDigest !=
        expectedCoreDigest) {
      throw const BackupException(BackupFailure.stalePreview);
    }
    for (final table in [
      'rest_alerts',
      'session_sets',
      'session_skip_batches',
      'session_exercises',
      'workout_sessions',
      'plan_exercises',
      'plans',
    ]) {
      await txn.delete(table);
    }
    // sqlite_sequence is deliberately untouched; all newly allocated IDs exceed
    // old high watermarks, so stale navigation/notification IDs cannot alias.
    final planIds = <Object?, int>{}, exerciseIds = <Object?, int>{};
    var index = 0;
    Future<int> insert(String table, BackupMap values) async {
      final id = await txn.insert(table, values);
      await afterInsert?.call(table, index++);
      return id;
    }

    var planOrder = 0;
    for (final p in target.plans) {
      final id = await insert('plans', {
        'sort_order': ++planOrder,
        'name': p['name'],
        'created_at': p['createdAt'],
        'updated_at': p['updatedAt'],
      });
      planIds[p['key']] = id;
      final exercises = (p['exercises'] as List).cast<BackupMap>();
      for (var i = 0; i < exercises.length; i++) {
        final e = exercises[i];
        exerciseIds[e['key']] = await insert('plan_exercises', {
          'plan_id': id,
          'name': e['name'],
          'sort_order': i + 1,
          ..._databaseConfiguration(e),
        });
      }
    }
    var workoutOrder = 0;
    for (final w in target.workouts) {
      final id = await insert('workout_sessions', {
        'backup_order': ++workoutOrder,
        'source_plan_id': planIds[w['sourcePlanKey']],
        'plan_name_snapshot': w['planNameSnapshot'],
        'started_at': w['startedAt'],
        'started_local_date': w['startedLocalDate'],
        'ended_at': w['endedAt'],
        'duration_seconds': w['durationSeconds'],
        'status': 'completed',
        'current_exercise_order': 1,
        'current_set_number': 1,
      });
      final exercises = (w['exercises'] as List).cast<BackupMap>();
      int? lastExercise;
      for (var i = 0; i < exercises.length; i++) {
        final e = exercises[i];
        final eid = await insert('session_exercises', {
          'session_id': id,
          'source_exercise_id': exerciseIds[e['sourceExerciseKey']],
          'name_snapshot': e['nameSnapshot'],
          'sort_order': i + 1,
          ..._databaseConfiguration(e),
        });
        lastExercise = eid;
        final batchIds = <Object?, int>{};
        for (final b in (e['skipBatches'] as List).cast<BackupMap>()) {
          batchIds[b['key']] = await insert('session_skip_batches', {
            'session_id': id,
            'session_exercise_id': eid,
            'created_at': b['createdAt'],
            'undone_at': b['undoneAt'],
          });
        }
        for (final s in (e['sets'] as List).cast<BackupMap>()) {
          await insert('session_sets', {
            'session_exercise_id': eid,
            'set_number': s['setNumber'],
            'completed_at': s['completedAt'],
            'completed_sequence': s['completedSequence'],
            'skipped_at': s['skippedAt'],
            'skip_batch_id': batchIds[s['skipBatchKey']],
          });
        }
      }
      if (lastExercise != null) {
        await txn.update(
          'workout_sessions',
          {
            'current_session_exercise_id': lastExercise,
            'current_exercise_order': exercises.length,
            'current_set_number': exercises.last['targetSets'],
          },
          where: 'id=?',
          whereArgs: [id],
        );
      }
    }
    if ((await txn.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      invalidBackup();
    }
    final result = await read(txn, currentSettings);
    if ((await BackupFingerprints.compute(result)).coreDigest !=
        (await BackupFingerprints.compute(target)).coreDigest) {
      invalidBackup();
    }
    return metadata.commitCore(txn, operationId, expectedEpoch);
  });

  static String? _ref(String prefix, Object? value) =>
      value == null ? null : '$prefix$value';
  static Map<Object?, List<BackupMap>> _group(
    List<BackupMap> rows,
    String field,
  ) {
    final result = <Object?, List<BackupMap>>{};
    for (final row in rows) {
      (result[row[field]] ??= []).add(row);
    }
    return result;
  }

  static BackupMap _configuration(BackupMap e) => {
    'targetSets': e['target_sets'],
    'restBetweenSetsSeconds': e['rest_between_sets_seconds'],
    'restAfterExerciseSeconds': e['rest_after_exercise_seconds'],
    'defaultWeightKg': e['default_weight_kg'],
  };
  static BackupMap _databaseConfiguration(BackupMap e) => {
    'target_sets': e['targetSets'],
    'rest_between_sets_seconds': e['restBetweenSetsSeconds'],
    'rest_after_exercise_seconds': e['restAfterExerciseSeconds'],
    'default_weight_kg': e['defaultWeightKg'],
  };
}
