import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_coordinator.dart';
import 'package:settrace/features/backup/backup_json.dart';
import 'package:settrace/features/backup/backup_models.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/backup/backup_files_platform.dart';
import 'package:settrace/features/backup/backup_recovery_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/backup_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase app;
  late BackupCoordinator service;
  late FakeBackupPreferences preferences;
  late FakeBackupFiles files;
  late DataWriteCoordinator writes;
  late BackupDocument target;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup_flow_');
    app = await AppDatabase.open(
      filePath: '${dir.path}/data.db',
      factory: databaseFactoryFfi,
    );
    target = BackupCodec().decode(
      File('test/fixtures/backup/v1-history.settrace.json').readAsBytesSync(),
    );
    preferences = FakeBackupPreferences(
      BackupSettings.fromJson({
        ...target.data.settings.toJson(),
        'languageTag': 'en',
        'themeColor': 'violet',
      }),
    );
    files = FakeBackupFiles(Directory('${dir.path}/files'));
    writes = DataWriteCoordinator();
    service = BackupCoordinator(
      db: app.db,
      writes: writes,
      preferences: preferences,
      files: files,
      appVersion: () => 'test+1',
    );
    await service.reconcileStartup();
    await service.copies.protect('target', target);
  });
  tearDown(() async {
    service.dispose();
    await app.close();
    await dir.delete(recursive: true);
  });

  test(
    'restore, add, undo protects additions and can explicitly recover them',
    () async {
      final result = await service.restore(
        await service.previewCopy('target', restoreSettings: false),
      );
      expect(result.settingsPending, isEmpty);
      expect(preferences.value.languageTag, 'en');
      final plans = PlanRepository(app.db, coordinator: writes);
      await plans.createPlan('恢复后新增');
      final undo = await service.previewUndo();
      expect(undo.restoreSettings, false);
      expect(undo.current.plans.length, 3);
      await service.restore(undo);
      expect((await service.snapshot()).plans, isEmpty);
      expect((await service.metadata.state())['undo_operation_id'], null);
      expect((await service.copies.read(undo.id)).data.plans.length, 3);
      await service.restore(await service.previewCopy(undo.id));
      expect((await service.snapshot()).plans.length, 3);
      await expectLater(service.restore(undo), throwsA(isA<BackupException>()));
    },
  );
  test('settings failures persist, restart permits later records, retry never replaces core', () async {
    preferences.failures.add('languageTag');
    final result = await service.restore(await service.previewCopy('target'));
    expect(result.settingsPending, ['languageTag']);
    expect(
      (await service.metadata.operation(result.operationId))!['phase'],
      'settings_pending',
    );
    await PlanRepository(app.db, coordinator: writes).createPlan('later');
    final before = BackupFingerprints(await service.snapshot()).coreDigest;
    await service.reconcileStartup();
    expect((await service.snapshot()).plans.length, 3);
    preferences.failures.clear();
    final applied = preferences.applied.length;
    expect(await service.retrySettings(result.operationId), isEmpty);
    expect(preferences.applied.sublist(applied), ['languageTag']);
    expect(preferences.value.languageTag, 'zh');
    expect(BackupFingerprints(await service.snapshot()).coreDigest, before);
    expect(await service.metadata.epoch(), 1);
  });
  test(
    'later manual intent supersedes pending restore and survives retry',
    () async {
      preferences.failures.add('languageTag');
      final result = await service.restore(await service.previewCopy('target'));
      await writes.write(() async {
        await service.supersedeSettings('languageTag');
        preferences.failures.clear();
        await preferences.apply('languageTag', 'en');
      });
      await expectLater(
        service.retrySettings(result.operationId),
        throwsA(
          isA<BackupException>().having(
            (e) => e.code,
            'code',
            BackupFailure.stalePreview,
          ),
        ),
      );
      expect(
        (await service.metadata.operation(result.operationId))!['phase'],
        'settings_skipped',
      );
      expect(preferences.value.languageTag, 'en');
    },
  );
  test(
    'stale preview rejects same-count modification; state remains intact',
    () async {
      final plans = PlanRepository(app.db, coordinator: writes);
      final id = await plans.createPlan('before');
      final preview = await service.previewCopy('target');
      await plans.renamePlan(id, 'changed');
      await expectLater(
        service.restore(preview),
        throwsA(
          isA<BackupException>().having(
            (e) => e.code,
            'code',
            BackupFailure.stalePreview,
          ),
        ),
      );
      expect((await plans.getPlan(id))!.name, 'changed');
      expect(await service.metadata.epoch(), 0);
    },
  );
  test(
    'startup aborts uncommitted protection; unknown result restricts writes',
    () async {
      final snapshot = await service.snapshot();
      await service.metadata.begin(
        id: 'interrupted',
        kind: 'restore',
        sourceDigest: BackupFingerprints(snapshot).contentDigest,
        targetDigest: 'target',
        sourceEpoch: 0,
        restoreSettings: false,
      );
      await service.reconcileStartup();
      expect(
        (await service.metadata.operation('interrupted'))!['phase'],
        'aborted',
      );
      await service.metadata.begin(
        id: 'unknown',
        kind: 'restore',
        sourceDigest: 'not-current',
        targetDigest: 'target',
        sourceEpoch: 0,
        restoreSettings: false,
      );
      await expectLater(service.reconcileStartup(), throwsException);
      expect(writes.blocked, true);
      await expectLater(
        PlanRepository(app.db, coordinator: writes).createPlan('blocked'),
        throwsException,
      );
    },
  );
  test(
    'current export tracks fixed snapshot; copy export leaves ledger untouched',
    () async {
      final document = await service.createExportSnapshot();
      await PlanRepository(app.db, coordinator: writes).createPlan('later');
      final saved = await service.export(document, currentData: true);
      expect(saved['state'], 'published');
      expect(File(saved['target'] as String).existsSync(), true);
      final ledger = await service.metadata.state();
      expect(
        ledger['last_export_digest'],
        BackupFingerprints(document.data).contentDigest,
      );
      expect(
        ledger['last_export_digest'],
        isNot(BackupFingerprints(await service.snapshot()).contentDigest),
      );
      await service.export(
        await service.copies.read('target'),
        currentData: false,
      );
      expect(
        (await service.metadata.state())['last_export_operation_id'],
        ledger['last_export_operation_id'],
      );
    },
  );
  test('real repositories reject all mutations during exclusive admission, then resume', () async {
    final plans = PlanRepository(app.db, coordinator: writes);
    final workouts = WorkoutRepository(app.db, coordinator: writes);
    final alerts = RestAlertRepository(app.db, coordinator: writes);
    final release = Completer<void>();
    final entered = Completer<void>();
    final exclusive = writes.exclusive(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    for (final action in <Future<void> Function()>[
      () async {
        await plans.createPlan('blocked');
      },
      () async {
        await workouts.start(999);
      },
      () => alerts.setEnabled(false),
      () => alerts.markPermissionRequested(),
    ]) {
      await expectLater(action(), throwsA(isA<BackupException>()));
    }
    release.complete();
    await exclusive;
    await plans.createPlan('allowed');
    expect((await plans.listPlans()).length, 1);
  });
  for (final completed in [0, 1, 3]) {
    test(
      'active workout with $completed completed sets blocks create/preview/undo but not overview',
      () async {
        await service.restore(
          await service.previewCopy('target', restoreSettings: false),
        );
        final session = await app.db.insert('workout_sessions', {
          'plan_name_snapshot': 'still active',
          'started_at': 1,
          'started_local_date': '2026-10-17',
          'status': 'in_progress',
          'current_exercise_order': 1,
          'current_set_number': 1,
        });
        final exercise = await app.db.insert('session_exercises', {
          'session_id': session,
          'name_snapshot': 'exercise',
          'sort_order': 1,
          'target_sets': 3,
          'rest_between_sets_seconds': 0,
          'rest_after_exercise_seconds': 0,
        });
        for (var n = 1; n <= 3; n++) {
          await app.db.insert('session_sets', {
            'session_exercise_id': exercise,
            'set_number': n,
            'completed_at': n <= completed ? 1 : null,
            'completed_sequence': n <= completed ? n : null,
          });
        }
        expect((await service.overview()).workouts.length, 1);
        final summary = (await service.data.activeSummary())!;
        expect(summary['completed'], completed);
        expect(summary['total'], 3);
        for (final action in <Future<Object?> Function()>[
          service.createExportSnapshot,
          () => service.previewCopy('target'),
          service.previewUndo,
        ]) {
          await expectLater(
            action(),
            throwsA(
              isA<BackupException>().having(
                (e) => e.code,
                'code',
                BackupFailure.activeWorkout,
              ),
            ),
          );
        }
        expect(
          (await app.db.query(
            'workout_sessions',
            where: 'id=?',
            whereArgs: [session],
          )).single['status'],
          'in_progress',
        );
      },
    );
  }
  test('a new active workout after preview invalidates confirmation without creating an operation', () async {
    final preview = await service.previewCopy('target');
    await app.db.insert('workout_sessions', {
      'plan_name_snapshot': 'later',
      'started_at': 1,
      'started_local_date': '2026-10-17',
      'status': 'in_progress',
      'current_exercise_order': 1,
      'current_set_number': 1,
    });
    await expectLater(
      service.restore(preview),
      throwsA(
        isA<BackupException>().having(
          (e) => e.code,
          'code',
          BackupFailure.activeWorkout,
        ),
      ),
    );
    expect(await service.metadata.operation(preview.id), isNull);
  });
  test('picker cancellation deletes previous candidate and invalidates its preview', () async {
    final token = await files.allocate();
    await BackupCodec.writeFile(files.pathFor(token), target);
    files.selected = BackupFileCandidate(
      token: token,
      fileName: 'source',
      bytes: 1,
    );
    final preview = (await service.selectFile())!;
    files.selected = null;
    expect(await service.selectFile(), isNull);
    expect(await File(files.pathFor(token)).exists(), false);
    await expectLater(
      service.restore(preview),
      throwsA(isA<BackupException>()),
    );
  });
  test('published export with failed bookkeeping repairs only the marker, without publishing twice', () async {
    await app.db.execute(
      "CREATE TRIGGER fail_export_ledger BEFORE UPDATE ON backup_state WHEN NEW.last_export_at IS NOT NULL BEGIN SELECT RAISE(ABORT,'injected'); END",
    );
    final document = await service.createExportSnapshot();
    final saved = await service.export(document, currentData: true);
    expect(saved['ledgerPending'], true);
    expect(files.exports.length, 1);
    final id = saved['operationId'] as String;
    expect(await File(saved['target'] as String).exists(), true);
    await app.db.execute('DROP TRIGGER fail_export_ledger');
    await service.reconcileExport(id);
    expect(files.exports.length, 1);
    expect((await service.metadata.state())['last_export_operation_id'], id);
  });
  for (final phase in [
    'before_write',
    'after_flush',
    'after_rename',
    'after_verify',
    'after_register',
  ]) {
    test(
      'protection interruption at $phase never replaces the current data',
      () async {
        service.dispose();
        service = BackupCoordinator(
          db: app.db,
          writes: writes,
          preferences: preferences,
          files: files,
          appVersion: () => 'test',
          protectionCheckpoint: (point) async {
            if (point == phase) throw StateError('injected');
          },
        );
        await PlanRepository(
          app.db,
          coordinator: writes,
        ).createPlan('original');
        final preview = await service.previewCopy(
          'target',
          restoreSettings: false,
        );
        await expectLater(
          service.restore(preview),
          throwsA(
            isA<BackupException>().having(
              (e) => e.code,
              'code',
              BackupFailure.protection,
            ),
          ),
        );
        expect((await service.snapshot()).plans.single['name'], 'original');
        expect(await service.metadata.epoch(), 0);
        await service.copies.reconcile();
        final complete = [
          'after_rename',
          'after_verify',
          'after_register',
        ].contains(phase);
        expect(
          await service.metadata.copy(preview.id),
          complete ? isNotNull : isNull,
        );
      },
    );
  }
  for (final field in ['themeMode', 'themeColor', 'languageTag', 'reminder']) {
    test(
      'each failed setting is isolated and retry never repeats the core transaction: $field',
      () async {
        final raw = jsonDecode(jsonEncode(target.data.toJson())) as BackupMap;
        final settings = raw['settings'] as BackupMap;
        settings['themeMode'] = 'dark';
        settings['themeColor'] = 'blue';
        settings['languageTag'] = 'zh';
        (settings['reminder'] as BackupMap)['enabled'] =
            !(preferences.value.reminder['enabled'] as bool);
        final doc = BackupDocument(
          backupId: 'settings',
          snapshotAt: target.snapshotAt,
          exportedAt: target.exportedAt,
          sourceAppVersion: 'test',
          data: BackupData.fromJson(raw),
        );
        await service.copies.protect('settings', doc);
        preferences.failures.add(field);
        final result = await service.restore(
          await service.previewCopy('settings'),
        );
        expect(result.settingsPending, [field]);
        final epoch = await service.metadata.epoch();
        await PlanRepository(
          app.db,
          coordinator: writes,
        ).createPlan('after partial settings');
        await service.reconcileStartup();
        preferences.failures.clear();
        final old = preferences.applied.length;
        expect(await service.retrySettings(result.operationId), isEmpty);
        expect(preferences.applied.sublist(old), [field]);
        expect(await service.metadata.epoch(), epoch);
        expect(
          (await service.snapshot()).plans.last['name'],
          'after partial settings',
        );
      },
    );
  }
  test('skip pending settings ends old intent and permits a later complete restore', () async {
    preferences.failures.add('languageTag');
    final result = await service.restore(await service.previewCopy('target'));
    await service.skipSettings(result.operationId);
    preferences.failures.clear();
    await expectLater(
      service.retrySettings(result.operationId),
      throwsA(isA<BackupException>()),
    );
    expect(preferences.value.languageTag, 'en');
    await service.restore(await service.previewCopy('target'));
    expect(preferences.value.languageTag, 'zh');
  });
  test('copy deleting interruption is reconciled without touching current data or retargeting undo', () async {
    await service.restore(
      await service.previewCopy('target', restoreSettings: false),
    );
    final undoId =
        (await service.metadata.state())['undo_operation_id'] as String;
    final op = (await service.metadata.operation(undoId))!;
    final copyId = op['before_copy_id'] as String;
    final store = BackupRecoveryStore(
      files.recoveryDirectory,
      service.metadata,
      checkpoint: (phase) async {
        if (phase == 'after_delete') throw StateError('index failure');
      },
    );
    await expectLater(store.delete(copyId), throwsStateError);
    expect((await service.metadata.copy(copyId))!['state'], 'deleting');
    await service.reconcileStartup();
    expect(await service.metadata.copy(copyId), isNull);
    expect((await service.metadata.state())['undo_operation_id'], isNull);
    expect((await service.snapshot()).workouts.length, 1);
    expect(await service.metadata.copy('target'), isNotNull);
  });
  test('unverifiable core result restricts admission and retains a readable protection copy', () async {
    service.dispose();
    service = BackupCoordinator(
      db: app.db,
      writes: writes,
      preferences: preferences,
      files: files,
      appVersion: () => 'test',
      protectionCheckpoint: (phase) async {
        if (phase == 'after_register') await app.db.execute('DROP TABLE plans');
      },
    );
    final preview = await service.previewCopy('target', restoreSettings: false);
    await expectLater(
      service.restore(preview),
      throwsA(
        isA<BackupException>().having(
          (e) => e.code,
          'code',
          BackupFailure.indeterminate,
        ),
      ),
    );
    expect(writes.blocked, true);
    expect(service.phase, 'indeterminate');
    expect((await service.copies.read(preview.id)).data.plans, isEmpty);
  });
  test('core replacement failure is verified as rolled back and can never report success', () async {
    await PlanRepository(app.db, coordinator: writes).createPlan('original');
    final before = await service.snapshot();
    await app.db.execute(
      "CREATE TRIGGER fail_restore_insert BEFORE INSERT ON session_exercises BEGIN SELECT RAISE(ABORT,'injected'); END",
    );
    final preview = await service.previewCopy('target', restoreSettings: false);
    await expectLater(
      service.restore(preview),
      throwsA(
        isA<BackupException>().having(
          (e) => e.code,
          'code',
          BackupFailure.rolledBack,
        ),
      ),
    );
    expect(
      BackupFingerprints(await service.snapshot()).contentDigest,
      BackupFingerprints(before).contentDigest,
    );
    expect((await service.metadata.operation(preview.id))!['phase'], 'aborted');
    expect(await service.metadata.epoch(), 0);
    expect(writes.blocked, false);
  });
  test('preference success before journal failure is reread on startup without applying settings or core twice', () async {
    preferences.value = BackupSettings.fromJson({
      ...preferences.value.toJson(),
      'themeMode': target.data.settings.themeMode == 'dark' ? 'light' : 'dark',
    });
    await app.db.execute(
      "CREATE TRIGGER fail_settings_log BEFORE UPDATE ON backup_operations WHEN NEW.settings_results != OLD.settings_results BEGIN SELECT RAISE(ABORT,'injected'); END",
    );
    final result = await service.restore(await service.previewCopy('target'));
    expect(result.settingsPending, isNotEmpty);
    final applied = preferences.applied.length;
    final epoch = await service.metadata.epoch();
    await app.db.execute('DROP TRIGGER fail_settings_log');
    await service.reconcileStartup();
    expect(preferences.applied.length, applied);
    expect(await service.metadata.epoch(), epoch);
    final operation = (await service.metadata.operation(result.operationId))!;
    expect(operation['target_summary'], isNotNull);
    // Only already-persisted fields are completed by startup; unfinished fields
    // stay pending for the explicit settings-only retry.
    expect(await service.retrySettings(result.operationId), isEmpty);
    expect(await service.metadata.epoch(), epoch);
  });
  test('refresh failure preserves successful result and later refresh does not replace core', () async {
    service.dispose();
    var fail = true;
    service = BackupCoordinator(
      db: app.db,
      writes: writes,
      preferences: preferences,
      files: files,
      appVersion: () => 'test',
      onCommitted: () async {
        if (fail) throw StateError('refresh');
      },
    );
    final result = await service.restore(
      await service.previewCopy('target', restoreSettings: false),
    );
    expect(result.refreshFailed, true);
    expect((await service.snapshot()).workouts.length, 1);
    await PlanRepository(
      app.db,
      coordinator: writes,
    ).createPlan('after refresh error');
    fail = false;
    await service.onCommitted!();
    expect(await service.metadata.epoch(), 1);
    expect(
      (await service.snapshot()).plans.last['name'],
      'after refresh error',
    );
  });
  test('undo keeps the original settings scope, and an undo protection failure preserves later data', () async {
    service.dispose();
    var fail = false;
    service = BackupCoordinator(
      db: app.db,
      writes: writes,
      preferences: preferences,
      files: files,
      appVersion: () => 'test',
      protectionCheckpoint: (phase) async {
        if (fail && phase == 'after_verify') throw StateError('space');
      },
    );
    await service.restore(
      await service.previewCopy('target', restoreSettings: false),
    );
    preferences.value = BackupSettings.fromJson({
      ...preferences.value.toJson(),
      'languageTag': 'zh',
    });
    await PlanRepository(app.db, coordinator: writes).createPlan('later');
    final undo = await service.previewUndo();
    expect(undo.restoreSettings, false);
    fail = true;
    await expectLater(
      service.restore(undo),
      throwsA(
        isA<BackupException>().having(
          (e) => e.code,
          'code',
          BackupFailure.protection,
        ),
      ),
    );
    expect((await service.snapshot()).plans.last['name'], 'later');
    expect(preferences.value.languageTag, 'zh');
    expect((await service.metadata.state())['undo_operation_id'], undo.undoOf);
    fail = false;
    await service.restore(await service.previewUndo());
    expect(preferences.value.languageTag, 'zh');
  });
  for (final phase in ['preparing', 'protected', 'completed', 'aborted']) {
    test(
      'startup reconciles $phase without replaying a core transaction',
      () async {
        await PlanRepository(
          app.db,
          coordinator: writes,
        ).createPlan('unchanged');
        final before = await service.snapshot();
        await service.metadata.begin(
          id: 'interrupted-$phase',
          kind: 'restore',
          sourceDigest: BackupFingerprints(before).contentDigest,
          targetDigest: 'target',
          sourceEpoch: 0,
          restoreSettings: false,
        );
        if (phase == 'protected') {
          await service.copies.protect(
            'interrupted-$phase',
            await service.createExportSnapshot(),
          );
          await service.metadata.protect(
            'interrupted-$phase',
            'interrupted-$phase',
          );
        } else if (phase != 'preparing') {
          await service.metadata.updateOperation('interrupted-$phase', {
            'phase': phase,
          });
        }
        await service.reconcileStartup();
        expect(
          (await service.metadata.operation('interrupted-$phase'))!['phase'],
          ['preparing', 'protected'].contains(phase) ? 'aborted' : phase,
        );
        expect(await service.metadata.epoch(), 0);
        expect((await service.snapshot()).plans.single['name'], 'unchanged');
      },
    );
  }
  test('core committed with bookkeeping interruption is completed on startup without overwriting later records', () async {
    await app.db.execute(
      "CREATE TRIGGER fail_completion_log BEFORE UPDATE ON backup_operations WHEN NEW.phase='completed' BEGIN SELECT RAISE(ABORT,'injected'); END",
    );
    final result = await service.restore(
      await service.previewCopy('target', restoreSettings: false),
    );
    expect(
      (await service.metadata.operation(result.operationId))!['phase'],
      'core_committed',
    );
    await PlanRepository(app.db, coordinator: writes).createPlan('later');
    await app.db.execute('DROP TRIGGER fail_completion_log');
    await service.reconcileStartup();
    expect(
      (await service.metadata.operation(result.operationId))!['phase'],
      'completed',
    );
    expect((await service.snapshot()).plans.last['name'], 'later');
    expect(await service.metadata.epoch(), 1);
  });
  test('lost publish acknowledgement is reconciled before retry and never creates a duplicate file', () async {
    final document = await service.createExportSnapshot();
    files.failAfterPublish = true;
    await expectLater(
      service.export(document, currentData: true),
      throwsStateError,
    );
    expect(files.exports.length, 1);
    final original = files.exports.values.single['target'];
    files.failAfterPublish = false;
    final retry = await service.export(document, currentData: true);
    expect(retry['target'], original);
    expect(files.exports.length, 1);
    expect(retry['ledgerPending'], false);
  });
  test('repairing an older successful export cannot replace the latest export marker even with clock changes', () async {
    final older = await service.createExportSnapshot();
    await service.export(older, currentData: true);
    final first =
        (await service.metadata.state())['last_export_operation_id'] as String;
    await PlanRepository(app.db, coordinator: writes).createPlan('later');
    await service.export(
      await service.createExportSnapshot(),
      currentData: true,
    );
    final latest = await service.metadata.state();
    await service.metadata.recordExport(
      first,
      result: await files.inspect(first),
      exportedAt: 999999999999999,
      currentData: true,
    );
    expect(
      (await service.metadata.state())['last_export_operation_id'],
      latest['last_export_operation_id'],
    );
    expect(
      (await service.metadata.state())['last_export_digest'],
      latest['last_export_digest'],
    );
  });
  test('canceled read discards a late picker result without validating or reviving the candidate', () async {
    final completion = Completer<BackupFileCandidate?>();
    files.pendingPick = completion.future;
    final reading = service.selectFile();
    await Future<void>.delayed(Duration.zero);
    await service.clearCandidate();
    final token = await files.allocate();
    await File(files.pathFor(token)).writeAsString('not a backup');
    completion.complete(
      BackupFileCandidate(token: token, fileName: 'late', bytes: 1),
    );
    await expectLater(
      reading,
      throwsA(
        isA<BackupException>().having(
          (e) => e.code,
          'code',
          BackupFailure.stalePreview,
        ),
      ),
    );
    expect(await File(files.pathFor(token)).exists(), false);
    expect(service.phase, 'idle');
  });
  test('undo inherits selected settings and treats its partial setting failure independently of core success', () async {
    await service.restore(
      await service.previewCopy('target', restoreSettings: true),
    );
    await PlanRepository(
      app.db,
      coordinator: writes,
    ).createPlan('after selected restore');
    preferences.failures.add('languageTag');
    final preview = await service.previewUndo();
    expect(preview.restoreSettings, true);
    final result = await service.restore(preview);
    expect(result.settingsPending, ['languageTag']);
    expect((await service.snapshot()).plans, isEmpty);
    expect(
      (await service.copies.read(preview.id)).data.plans.last['name'],
      'after selected restore',
    );
    preferences.failures.clear();
    expect(await service.retrySettings(result.operationId), isEmpty);
    expect(preferences.value.languageTag, 'en');
    expect(await service.metadata.epoch(), 2);
  });
}
