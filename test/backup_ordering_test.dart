import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_coordinator.dart';
import 'package:settrace/features/backup/backup_models.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/database_v5.dart';
import 'support/backup_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup_order_');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  Future<void> seed(Database db) async {
    for (final (id, time) in [(30, 200), (10, 100), (20, 100)]) {
      await db.insert('plans', {
        'id': id,
        'name': 'p$id',
        'created_at': time,
        'updated_at': time,
      });
      await db.insert('workout_sessions', {
        'id': id,
        'plan_name_snapshot': 'w$id',
        'started_at': time,
        'started_local_date': '2026-10-17',
        'status': 'completed',
        'ended_at': time - 1,
        'duration_seconds': 0,
        'current_exercise_order': 1,
        'current_set_number': 1,
      });
    }
    await db.insert('workout_sessions', {
      'id': 40,
      'plan_name_snapshot': 'active',
      'started_at': 50,
      'started_local_date': '2026-10-17',
      'status': 'in_progress',
      'current_exercise_order': 1,
      'current_set_number': 1,
    });
    await db.update('backup_state', {'epoch': 9, 'last_export_at': 123});
  }

  test('v5 migration preserves all rows and initializes stable original order, append triggers are atomic', () async {
    final path = '${dir.path}/db';
    final old = await LegacyAppDatabaseV5.open(
      filePath: path,
      factory: databaseFactoryFfi,
    );
    await seed(old.db);
    final before = {
      for (final table in ['plans', 'workout_sessions', 'backup_state'])
        table: await old.db.query(table, orderBy: 'id'),
    };
    await old.close();
    final app = await AppDatabase.open(
      filePath: path,
      factory: databaseFactoryFfi,
    );
    try {
      expect(await app.db.getVersion(), 6);
      for (final entry in before.entries) {
        final after = await app.db.query(entry.key, orderBy: 'id');
        for (var i = 0; i < after.length; i++) {
          for (final field in entry.value[i].entries) {
            expect(after[i][field.key], field.value);
          }
        }
      }
      expect((await PlanRepository(app.db).listPlans()).map((p) => p.id), [
        10,
        20,
        30,
      ]);
      expect(
        (await app.db.query(
          'workout_sessions',
          where: "status='completed'",
          orderBy: 'backup_order',
        )).map((r) => r['id']),
        [10, 20, 30],
      );
      expect(
        (await app.db.query(
          'workout_sessions',
          where: 'id=40',
        )).single['backup_order'],
        isNull,
      );
      final plans = PlanRepository(app.db);
      await plans.createPlan('new');
      await plans.importPlans([
        TransferPlan(name: 'imported', exercises: []),
      ], suffixFor: (n) => 'copy$n');
      expect((await plans.listPlans()).map((p) => p.name), [
        'p10',
        'p20',
        'p30',
        'new',
        'imported',
      ]);
      await app.db.update('workout_sessions', {
        'status': 'completed',
        'ended_at': 40,
        'duration_seconds': 0,
      }, where: 'id=40');
      expect(
        (await app.db.query(
          'workout_sessions',
          where: 'id=40',
        )).single['backup_order'],
        4,
      );
      await expectLater(
        app.db.transaction((txn) async {
          await txn.insert('plans', {
            'name': 'abort',
            'created_at': 1,
            'updated_at': 1,
          });
          throw StateError('abort');
        }),
        throwsStateError,
      );
      expect((await plans.listPlans()).last.name, 'imported');
    } finally {
      await app.close();
    }
  });
  test('v5 failed ordering migration rolls back DDL and preserves backup metadata and business data', () async {
    final path = '${dir.path}/db';
    final old = await LegacyAppDatabaseV5.open(
      filePath: path,
      factory: databaseFactoryFfi,
    );
    await seed(old.db);
    await old.db.execute(
      'ALTER TABLE workout_sessions ADD COLUMN backup_order INTEGER',
    );
    final schema = await old.db.rawQuery(
      'SELECT * FROM sqlite_master ORDER BY name',
    );
    final rows = await old.db.query('workout_sessions', orderBy: 'id');
    await old.close();
    await expectLater(
      AppDatabase.open(filePath: path, factory: databaseFactoryFfi),
      throwsA(isA<DatabaseException>()),
    );
    final raw = await databaseFactoryFfi.openDatabase(path);
    try {
      expect(await raw.getVersion(), 5);
      expect(
        await raw.rawQuery('SELECT * FROM sqlite_master ORDER BY name'),
        schema,
      );
      expect(await raw.query('workout_sessions', orderBy: 'id'), rows);
      expect((await raw.query('backup_state')).single['epoch'], 9);
    } finally {
      await raw.close();
    }
  });
  test('reverse-time arrays and ties survive restore, export, append, undo and recovery without changing time', () async {
    final app = await AppDatabase.open(
      filePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    final original = BackupCodec().decode(
      File('test/fixtures/backup/v1-history.settrace.json').readAsBytesSync(),
    );
    final raw = jsonDecode(jsonEncode(original.data.toJson())) as BackupMap;
    final plans = (raw['plans'] as List).reversed.toList();
    plans[0]['createdAt'] = 200;
    plans[1]['createdAt'] = 100;
    raw['plans'] = plans;
    final workouts = (raw['workouts'] as List);
    final duplicate = jsonDecode(jsonEncode(workouts.first)) as BackupMap;
    Object? rename(Object? node) {
      if (node is List) return node.map(rename).toList();
      if (node is Map) {
        return <String, Object?>{
          for (final entry in node.entries)
            entry.key as String:
                ['key', 'skipBatchKey'].contains(entry.key) &&
                    entry.value is String
                ? 'second-${entry.value}'
                : rename(entry.value),
        };
      }
      return node;
    }

    final second = Map<String, Object?>.from(rename(duplicate) as Map);
    workouts.first['startedAt'] = 2000;
    second['startedAt'] = 1000;
    workouts.add(second);
    final third = Map<String, Object?>.from(rename(second) as Map);
    workouts.add(third);
    final data = BackupData.fromJson(raw);
    final files = FakeBackupFiles(Directory('${dir.path}/files'));
    final service = BackupCoordinator(
      db: app.db,
      writes: DataWriteCoordinator(),
      preferences: FakeBackupPreferences(data.settings),
      files: files,
      appVersion: () => 'test',
    );
    try {
      await service.reconcileStartup();
      await service.copies.protect(
        'target',
        BackupDocument(
          backupId: 'target',
          snapshotAt: DateTime.utc(2026),
          exportedAt: DateTime.utc(2026),
          sourceAppVersion: 'test',
          data: data,
        ),
      );
      await service.restore(
        await service.previewCopy('target', restoreSettings: false),
      );
      final restored = await service.snapshot();
      expect(
        BackupFingerprints(restored).contentDigest,
        BackupFingerprints(data).contentDigest,
      );
      expect(restored.plans.map((p) => p['createdAt']), [200, 100]);
      expect(restored.workouts.map((w) => w['startedAt']), [2000, 1000, 1000]);
      final export = await service.export(
        await service.createExportSnapshot(),
        currentData: true,
      );
      final decoded = BackupCodec().decode(
        await File(export['target'] as String).readAsBytes(),
      );
      expect(
        BackupFingerprints(decoded.data).contentDigest,
        BackupFingerprints(data).contentDigest,
      );
      await PlanRepository(app.db).createPlan('after restore');
      final undo = await service.previewUndo();
      await service.restore(undo);
      expect((await service.snapshot()).plans, isEmpty);
      await service.restore(await service.previewCopy(undo.id));
      final recovered = await service.snapshot();
      expect(recovered.plans.map((p) => p['createdAt']).take(2), [200, 100]);
      expect(recovered.plans.last['name'], 'after restore');
      expect(recovered.workouts.map((w) => w['startedAt']), [2000, 1000, 1000]);
    } finally {
      service.dispose();
      await app.close();
    }
  });
}
