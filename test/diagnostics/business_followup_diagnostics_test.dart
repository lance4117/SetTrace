import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_coordinator.dart';
import 'package:settrace/features/backup/backup_models.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/features/diagnostics/diagnostic_state.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_service.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/l10n/generated/app_localizations_en.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../rest_alert_repository_test.dart' show FakeAlertsPlatform;
import '../support/backup_fakes.dart';
import '../support/diagnostics_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase database;
  late DiagnosticsClient client;
  late FakeDiagnosticsTransport transport;
  late DataWriteCoordinator writes;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('diagnostic-followup-');
    database = await AppDatabase.open(
      filePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    transport = FakeDiagnosticsTransport();
    writes = DataWriteCoordinator()..reconcile(0);
    client = DiagnosticsClient(
      transport: transport,
      epoch: () => writes.diagnosticEpoch,
    );
    await client.overview();
  });
  tearDown(() async {
    client.dispose();
    await database.close();
    await dir.delete(recursive: true);
  });
  test('startup reconciliation without work has an observed terminal, not a commit', () async {
    final target = BackupCodec().decode(
      File('test/fixtures/backup/v1-history.settrace.json').readAsBytesSync(),
    );
    final backup = BackupCoordinator(
      db: database.db,
      writes: writes,
      preferences: FakeBackupPreferences(target.data.settings),
      files: FakeBackupFiles(Directory('${dir.path}/recovery-files')),
      appVersion: () => 'test',
      diagnostics: client,
    );
    try {
      await backup.reconcileStartup();
      await client.flush();
      final recovery = transport.events
          .where((e) => e['event_name'] == 'backup.recovery')
          .toList();
      expect(recovery.first['phase'], 'started');
      expect(recovery.last['phase'], 'completed');
      expect(recovery.last['outcome'], 'observed');
      expect(recovery.where((e) => e['outcome'] == 'committed'), isEmpty);
    } finally {
      backup.dispose();
    }
  });
  test(
    'business restore and export keep diagnostics disabled and identity local',
    () async {
      await client.setEnabled(false);
      final generation = client.current!.generation;
      final target = BackupCodec().decode(
        File('test/fixtures/backup/v1-history.settrace.json').readAsBytesSync(),
      );
      final prefs = FakeBackupPreferences(target.data.settings);
      final backup = BackupCoordinator(
        db: database.db,
        writes: writes,
        preferences: prefs,
        files: FakeBackupFiles(Directory('${dir.path}/files')),
        appVersion: () => 'test',
        diagnostics: client,
      );
      try {
        await backup.reconcileStartup();
        await backup.copies.protect('target', target);
        await backup.restore(await backup.previewCopy('target'));
        final snapshot = await backup.snapshot();
        final encoded = snapshot.toJson().toString();
        expect(encoded, isNot(contains('diagnostic')));
        expect(encoded, isNot(contains(generation)));
        expect(client.current!.enabled, isFalse);
        expect(client.current!.generation, generation);
        expect(transport.enabled, isFalse);
        expect(
          transport.calls.where((method) => method == 'setEnabled'),
          hasLength(1),
        );
        await client.flush();
        expect(transport.events, isEmpty);
      } finally {
        backup.dispose();
      }
    },
  );
  test('backup core commit, partial settings and retry remain separate across epoch change', () async {
    final target = BackupCodec().decode(
      File('test/fixtures/backup/v1-history.settrace.json').readAsBytesSync(),
    );
    final prefs = FakeBackupPreferences(
      BackupSettings.fromJson({
        ...target.data.settings.toJson(),
        'languageTag': 'en',
      }),
    )..failures.add('languageTag');
    final backup = BackupCoordinator(
      db: database.db,
      writes: writes,
      preferences: prefs,
      files: FakeBackupFiles(Directory('${dir.path}/files')),
      appVersion: () => 'test',
      diagnostics: client,
    );
    try {
      await backup.reconcileStartup();
      await backup.copies.protect('target', target);
      final result = await backup.restore(await backup.previewCopy('target'));
      expect(result.settingsPending, contains('languageTag'));
      expect(writes.diagnosticEpoch, 1);
      await client.flush();
      final events = transport.events
          .where((e) => e['event_name'] == 'backup.restore')
          .toList();
      expect(
        events.any(
          (e) => e['phase'] == 'core_committed' && e['outcome'] == 'committed',
        ),
        isTrue,
      );
      expect(events.last['outcome'], 'partial_success');
      expect(events.every((e) => e['dataset_epoch'] == 0), isTrue);
      expect(
        events.any((e) => e['outcome'] == 'rolled_back_confirmed'),
        isFalse,
      );
      prefs.failures.clear();
      await backup.retrySettings(result.operationId);
      await client.flush();
      expect(transport.events.last['dataset_epoch'], 1);
      expect(await backup.metadata.epoch(), 1);
      expect(
        (await backup.metadata.operation(result.operationId))!['phase'],
        'completed',
      );
    } finally {
      backup.dispose();
    }
  });
  test('workout commit and async scheduling failure retain the parent causal chain', () async {
    final plans = PlanRepository(
      database.db,
      coordinator: writes,
      diagnostics: client,
    );
    final workouts = WorkoutRepository(
      database.db,
      coordinator: writes,
      diagnostics: client,
    );
    final repo = RestAlertRepository(database.db, coordinator: writes);
    final platform = FakeAlertsPlatform(repo);
    final alerts = RestAlertService(repo, platform, diagnostics: client);
    try {
      final plan = await plans.createPlan('PRIVATE_PLAN');
      await plans.addExercise(
        planId: plan,
        name: 'PRIVATE_EXERCISE',
        targetSets: 3,
        restBetweenSetsSeconds: 60,
        restAfterExerciseSeconds: 0,
      );
      final session = await workouts.start(plan);
      await alerts.configure(AppLocalizationsEn());
      platform.failSchedule = true;
      final synchronized = Completer<void>();
      workouts.onChanged = () {
        unawaited(
          alerts.synchronize().then<void>(
            (_) => synchronized.complete(),
            onError: (Object _, StackTrace _) => synchronized.complete(),
          ),
        );
      };
      await workouts.completeSet(
        session.id,
        expectedExerciseId: session.currentExercise.id,
        expectedSetNumber: 1,
      );
      await synchronized.future;
      expect((await workouts.getSession(session.id))!.completedSets, 1);
      await client.flush();
      final complete = transport.events.lastWhere(
        (e) => e['event_name'] == 'workout.complete',
      );
      final sync = transport.events.lastWhere(
        (e) =>
            e['event_name'] == 'rest.synchronize' && e['outcome'] == 'unknown',
      );
      final schedule = transport.events.lastWhere(
        (e) => e['event_name'] == 'rest.schedule',
      );
      expect(complete['outcome'], 'committed');
      expect(sync['parent_operation_id'], complete['operation_id']);
      expect(schedule['parent_operation_id'], complete['operation_id']);
      expect(schedule['outcome'], 'unknown');
      expect(transport.events.toString(), isNot(contains('PRIVATE_')));
      final before = await database.db.query('session_sets');
      final state = await diagnosticState(database.db);
      expect(state['active'], isTrue);
      expect(state['completed_count'], 1);
      expect(state.toString(), isNot(contains('PRIVATE_')));
      expect(await database.db.query('session_sets'), before);
    } finally {
      alerts.dispose();
    }
  });
}
