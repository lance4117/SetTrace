import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/backup/backup_metadata_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/database_v4.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('backup_metadata_'),
  );
  tearDown(() async => directory.delete(recursive: true));

  Future<void> seed(Database db) async {
    await db.insert('plans', {
      'id': 50,
      'name': '旧计划',
      'created_at': 100,
      'updated_at': 200,
    });
    await db.insert('plan_exercises', {
      'id': 60,
      'plan_id': 50,
      'name': '深蹲',
      'sort_order': 1,
      'target_sets': 3,
      'rest_between_sets_seconds': 30,
      'rest_after_exercise_seconds': 60,
      'default_weight_kg': 12.5,
    });
    for (final id in [70, 71]) {
      await db.insert('workout_sessions', {
        'id': id,
        'source_plan_id': 50,
        'plan_name_snapshot': '旧快照',
        'started_at': 1000,
        'started_local_date': '2026-10-15',
        'ended_at': id == 70 ? 900 : null,
        'duration_seconds': id == 70 ? 0 : null,
        'status': id == 70 ? 'completed' : 'in_progress',
        'current_exercise_order': 1,
        'current_set_number': 3,
        'current_session_exercise_id': id + 10,
        'rest_kind': id == 71 ? 'between_sets' : null,
        'rest_started_at': id == 71 ? 2000 : null,
        'rest_end_at': id == 71 ? 32000 : null,
      });
      await db.insert('session_exercises', {
        'id': id + 10,
        'session_id': id,
        'source_exercise_id': 60,
        'name_snapshot': '原动作',
        'sort_order': 1,
        'target_sets': 3,
        'rest_between_sets_seconds': 30,
        'rest_after_exercise_seconds': 60,
        'default_weight_kg': 10.0,
      });
      await db.insert('session_skip_batches', {
        'id': id + 20,
        'session_id': id,
        'session_exercise_id': id + 10,
        'created_at': 1500,
      });
      for (var i = 1; i <= 3; i++) {
        await db.insert('session_sets', {
          'session_exercise_id': id + 10,
          'set_number': i,
          'completed_at': i == 1 ? 1200 : null,
          'completed_sequence': i == 1 ? 1 : null,
          'skipped_at': i == 2 ? 1500 : null,
          'skip_batch_id': i == 2 ? id + 20 : null,
        });
      }
    }
    await db.insert('rest_alerts', {
      'id': 100,
      'session_id': 71,
      'exercise_id': 81,
      'set_number': 3,
      'due_at': 32000,
      'state': 'pending',
      'title': 'Rest',
      'body': 'Ready',
    });
    await db.update('workout_sessions', {
      'current_rest_alert_id': 100,
    }, where: 'id=71');
    await db.update('rest_alert_preferences', {
      'enabled': 0,
      'permission_requested': 1,
    });
  }

  const tables = [
    'plans',
    'plan_exercises',
    'workout_sessions',
    'session_exercises',
    'session_sets',
    'session_skip_batches',
    'rest_alerts',
    'rest_alert_preferences',
  ];
  for (final version in [3, 4]) {
    test('v$version to v6 retains every existing business field', () async {
      final path = '${directory.path}/v$version.db';
      final old = await LegacyAppDatabaseV4.open(
        filePath: path,
        version: version,
        factory: databaseFactoryFfi,
      );
      await seed(old.db);
      if (version == 4) {
        await old.db.update('rest_alert_preferences', {
          'sound_id': 'voice',
          'interval_seconds': 30,
          'vibration_enabled': 0,
        });
      }
      final before = {
        for (final table in tables)
          table: await old.db.query(table, orderBy: 'id'),
      };
      await old.close();
      final current = await AppDatabase.open(
        filePath: path,
        factory: databaseFactoryFfi,
      );
      try {
        expect(await current.db.getVersion(), 6);
        for (final table in tables) {
          final after = await current.db.query(table, orderBy: 'id');
          expect(after.length, before[table]!.length);
          for (var i = 0; i < after.length; i++) {
            for (final field in before[table]![i].entries) {
              expect(
                after[i][field.key],
                field.value,
                reason: '$table/$i/${field.key}',
              );
            }
          }
        }
        expect(await current.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(await BackupMetadataRepository(current.db).epoch(), 0);
      } finally {
        await current.close();
      }
    });
    test(
      'v$version failed metadata migration rolls back all schema and data changes',
      () async {
        final path = '${directory.path}/fail$version.db';
        final old = await LegacyAppDatabaseV4.open(
          filePath: path,
          version: version,
          factory: databaseFactoryFfi,
        );
        await seed(old.db);
        await old.db.execute('CREATE TABLE backup_copies (id TEXT)');
        final schema = await old.db.rawQuery(
          'SELECT * FROM sqlite_master ORDER BY name',
        );
        final before = {
          for (final table in tables)
            table: await old.db.query(table, orderBy: 'id'),
        };
        await old.close();
        await expectLater(
          AppDatabase.open(filePath: path, factory: databaseFactoryFfi),
          throwsA(isA<DatabaseException>()),
        );
        final reopened = await databaseFactoryFfi.openDatabase(path);
        try {
          expect(await reopened.getVersion(), version);
          expect(
            await reopened.rawQuery(
              'SELECT * FROM sqlite_master ORDER BY name',
            ),
            schema,
          );
          for (final table in tables) {
            expect(await reopened.query(table, orderBy: 'id'), before[table]);
          }
        } finally {
          await reopened.close();
        }
      },
    );
  }
  test('core marker, epoch and business changes share rollback; copies survive deletion', () async {
    final app = await AppDatabase.open(
      filePath: '${directory.path}/metadata.db',
      factory: databaseFactoryFfi,
    );
    addTearDown(app.close);
    final db = app.db;
    await seed(db);
    final repo = BackupMetadataRepository(db);
    await repo.begin(
      id: 'restore1',
      kind: 'restore',
      sourceDigest: 'before',
      targetDigest: 'after',
      sourceEpoch: 0,
      restoreSettings: true,
    );
    await repo.registerCopy({
      'id': 'copy1',
      'operation_id': 'restore1',
      'snapshot_at': '2026-10-16T00:00:00Z',
      'relative_path': 'copy1.settrace.json',
      'digest': 'abc',
      'schema_version': 1,
      'plan_count': 1,
      'workout_count': 1,
      'byte_count': 12,
      'state': 'ready',
      'created_at': 1,
    });
    await repo.protect('restore1', 'copy1');
    await expectLater(
      db.transaction((txn) async {
        await txn.delete('plans');
        await repo.commitCore(txn, 'restore1', 0);
        throw StateError('after marker');
      }),
      throwsStateError,
    );
    expect((await db.query('plans')).single['name'], '旧计划');
    expect(await repo.epoch(), 0);
    expect((await repo.operation('restore1'))!['phase'], 'protected');
    await db.transaction((txn) async {
      await txn.delete('plans');
      await repo.commitCore(txn, 'restore1', 0);
    });
    expect(await repo.epoch(), 1);
    expect((await repo.operation('restore1'))!['phase'], 'core_committed');
    expect((await repo.copies()).single['id'], 'copy1');
    expect(
      await db.rawQuery('PRAGMA foreign_key_list(backup_copies)'),
      isEmpty,
    );
    await expectLater(
      db.transaction((txn) => repo.commitCore(txn, 'restore1', 0)),
      throwsException,
    );
    await repo.begin(
      id: 'export1',
      kind: 'export',
      sourceDigest: 'current',
      targetDigest: 'current',
      sourceEpoch: 1,
      restoreSettings: false,
    );
    await repo.recordExport(
      'export1',
      result: {'name': 'saved.json'},
      exportedAt: 123,
      currentData: true,
    );
    expect((await repo.state())['last_export_digest'], 'current');
    await repo.begin(
      id: 'export-copy',
      kind: 'export',
      sourceDigest: 'older',
      targetDigest: 'older',
      sourceEpoch: 1,
      restoreSettings: false,
    );
    await repo.recordExport(
      'export-copy',
      result: {'name': 'copy.json'},
      exportedAt: 124,
      currentData: false,
    );
    expect((await repo.state())['last_export_digest'], 'current');
    await expectLater(
      repo.updateOperation('missing', {'phase': 'completed'}),
      throwsException,
    );
    await expectLater(
      repo.registerCopy({'relative_path': '../escape.json'}),
      throwsException,
    );
  });
}
