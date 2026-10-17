import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_data_repository.dart';
import 'package:settrace/features/backup/backup_metadata_repository.dart';
import 'package:settrace/features/backup/backup_models.dart';
import 'package:settrace/features/backup/backup_recovery_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late AppDatabase app;
  late BackupMetadataRepository metadata;
  late BackupDataRepository repository;
  late BackupRecoveryStore copies;
  late BackupDocument target;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup_restore_');
    app = await AppDatabase.open(
      filePath: '${directory.path}/test.db',
      factory: databaseFactoryFfi,
    );
    metadata = BackupMetadataRepository(app.db);
    repository = BackupDataRepository(app.db);
    copies = BackupRecoveryStore(
      Directory('${directory.path}/backup-recovery'),
      metadata,
    );
    target = BackupCodec().decode(
      File('test/fixtures/backup/v1-history.settrace.json').readAsBytesSync(),
    );
  });
  tearDown(() async {
    await app.close();
    await directory.delete(recursive: true);
  });
  Future<BackupData> prepare(String id) async {
    final before = await repository.snapshot(target.data.settings);
    await metadata.begin(
      id: id,
      kind: 'restore',
      sourceDigest: BackupFingerprints(before).contentDigest,
      targetDigest: BackupFingerprints(target.data).contentDigest,
      sourceEpoch: await metadata.epoch(),
      restoreSettings: true,
    );
    await copies.protect(
      id,
      BackupDocument(
        backupId: id,
        snapshotAt: DateTime.utc(2026),
        exportedAt: DateTime.utc(2026),
        sourceAppVersion: 'test',
        data: before,
      ),
    );
    await metadata.protect(id, id);
    return before;
  }

  test('empty and existing targets restore exact semantics with fresh IDs and immutable copies', () async {
    for (var i = 0; i < 2; i++) {
      final before = await prepare('restore$i');
      final oldIds = (await app.db.query('plans'))
          .map((r) => r['id'] as int)
          .toSet();
      final next = await repository.replace(
        operationId: 'restore$i',
        expectedEpoch: i,
        expectedCoreDigest: BackupFingerprints(before).coreDigest,
        target: target.data,
        currentSettings: target.data.settings,
      );
      expect(next, i + 1);
      final restored = await repository.snapshot(target.data.settings);
      expect(
        BackupFingerprints(restored).contentDigest,
        BackupFingerprints(target.data).contentDigest,
      );
      expect(
        (await app.db.query('plans'))
            .map((r) => r['id'] as int)
            .toSet()
            .intersection(oldIds),
        isEmpty,
      );
      expect((await app.db.query('rest_alerts')), isEmpty);
      expect(
        (await app.db.query('workout_sessions'))
            .single['current_rest_alert_id'],
        null,
      );
      expect((await copies.read('restore$i')).data.toJson(), before.toJson());
      expect((await metadata.copies()).length, i + 1);
    }
  });
  test(
    'every entity insertion failure rolls back data, marker and epoch',
    () async {
      await app.db.insert('plans', {
        'id': 100,
        'name': '保留',
        'created_at': 1,
        'updated_at': 1,
      });
      for (final table in [
        'plans',
        'plan_exercises',
        'workout_sessions',
        'session_exercises',
        'session_skip_batches',
        'session_sets',
      ]) {
        final before = await prepare(table);
        await expectLater(
          repository.replace(
            operationId: table,
            expectedEpoch: 0,
            expectedCoreDigest: BackupFingerprints(before).coreDigest,
            target: target.data,
            currentSettings: target.data.settings,
            afterInsert: (name, _) async {
              if (name == table) throw StateError('injected');
            },
          ),
          throwsStateError,
        );
        expect(
          (await repository.snapshot(target.data.settings)).toJson(),
          before.toJson(),
        );
        expect(await metadata.epoch(), 0);
        expect((await metadata.operation(table))!['phase'], 'protected');
        expect((await copies.read(table)).data.toJson(), before.toJson());
      }
    },
  );
  test('preview same-count rename, active workouts and duplicate commit are refused', () async {
    await app.db.insert('plans', {
      'name': 'A',
      'created_at': 1,
      'updated_at': 1,
    });
    final before = await prepare('stale');
    await app.db.update('plans', {'name': 'B'});
    await expectLater(
      repository.replace(
        operationId: 'stale',
        expectedEpoch: 0,
        expectedCoreDigest: BackupFingerprints(before).coreDigest,
        target: target.data,
        currentSettings: target.data.settings,
      ),
      throwsException,
    );
    await app.db.insert('workout_sessions', {
      'plan_name_snapshot': 'active',
      'started_at': 1,
      'started_local_date': '2026-10-16',
      'status': 'in_progress',
      'current_exercise_order': 1,
      'current_set_number': 1,
    });
    await expectLater(
      repository.snapshot(target.data.settings),
      throwsException,
    );
  });
  test('interrupted protection retains complete orphans; missing/deleting reconcile honestly', () async {
    final failing = BackupRecoveryStore(
      copies.directory,
      metadata,
      checkpoint: (phase) async {
        if (phase == 'after_rename') throw StateError('process interruption');
      },
    );
    await expectLater(failing.protect('orphan', target), throwsStateError);
    expect(await metadata.copies(), isEmpty);
    await copies.reconcile();
    expect((await copies.read('orphan')).digest, target.digest);
    final failDelete = BackupRecoveryStore(
      copies.directory,
      metadata,
      checkpoint: (phase) async {
        if (phase == 'after_delete') throw StateError('index not updated');
      },
    );
    await expectLater(failDelete.delete('orphan'), throwsStateError);
    expect((await metadata.copy('orphan'))!['state'], 'deleting');
    await copies.reconcile();
    expect(await metadata.copy('orphan'), null);
    await copies.protect('missing', target);
    await File('${copies.directory.path}/missing.settrace.json').delete();
    await copies.reconcile();
    expect((await metadata.copy('missing'))!['state'], 'missing');
  });
  test('source links, same-time completion ordering, skip batches and all fields round trip', () async {
    final raw = jsonDecode(jsonEncode(target.data.toJson())) as BackupMap;
    final w = (raw['workouts'] as List).first as BackupMap;
    w['sourcePlanKey'] = 'p1';
    final e = (w['exercises'] as List).first as BackupMap;
    e['sourceExerciseKey'] = 'e1';
    final last = (e['sets'] as List).last as BackupMap;
    last['completedAt'] = 3000;
    last['completedSequence'] = 7;
    final data = BackupData.fromJson(raw);
    final before = await prepare('links');
    await repository.replace(
      operationId: 'links',
      expectedEpoch: 0,
      expectedCoreDigest: BackupFingerprints(before).coreDigest,
      target: data,
      currentSettings: data.settings,
    );
    expect(
      BackupFingerprints(await repository.snapshot(data.settings)).coreDigest,
      BackupFingerprints(data).coreDigest,
    );
  });
  test('corrupt copies stay unavailable until exact bytes are recovered; no copy expires automatically', () async {
    await copies.protect('checked', target);
    final file = File('${copies.directory.path}/checked.settrace.json');
    final bytes = await file.readAsBytes();
    await file.writeAsString('broken');
    await copies.reconcile();
    expect((await metadata.copy('checked'))!['state'], 'missing');
    await expectLater(copies.read('checked'), throwsException);
    await file.writeAsBytes(bytes, flush: true);
    await copies.reconcile();
    expect((await metadata.copy('checked'))!['state'], 'ready');
    expect((await copies.read('checked')).snapshotAt, target.snapshotAt);
    expect(await file.exists(), true);
    final failing = BackupRecoveryStore(
      copies.directory,
      metadata,
      checkpoint: (phase) async {
        if (phase == 'before_delete') throw StateError('file deletion denied');
      },
    );
    await expectLater(failing.delete('checked'), throwsStateError);
    expect(await file.exists(), true);
    expect((await metadata.copy('checked'))!['state'], 'deleting');
    await copies.reconcile();
    expect(await file.exists(), false);
    expect(await metadata.copy('checked'), isNull);
  });
}
