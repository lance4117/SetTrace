import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/workout/workout_models.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase app;
  late DateTime now;
  late RestAlertRepository alerts;
  late WorkoutRepository workouts;
  late WorkoutSessionData session;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('repeat_');
    app = await AppDatabase.open(
      filePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    now = DateTime.utc(2026, 10, 16);
    workouts = WorkoutRepository(app.db, clock: () => now);
    alerts = RestAlertRepository(app.db, clock: () => now);
    final plans = PlanRepository(app.db);
    final id = await plans.createPlan('Plan');
    await plans.addExercise(
      planId: id,
      name: 'A',
      targetSets: 4,
      restBetweenSetsSeconds: 60,
      restAfterExerciseSeconds: 60,
    );
    session = await workouts.start(id);
    session = await workouts.completeSet(
      session.id,
      expectedExerciseId: session.currentExercise.id,
      expectedSetNumber: session.currentSetNumber,
    );
    final e = (await alerts.pending()).single;
    await alerts.setContent(e, 'Rest is over', 'A set 2 of 4');
  });
  tearDown(() async {
    await app.close();
    await dir.delete(recursive: true);
  });
  Future<RestAlertEvent> first() async {
    now = now.add(const Duration(seconds: 60));
    final e = (await alerts.pending()).single;
    return (await alerts.consume(e.id, e.revision))!;
  }

  test(
    'each round is claimed once, repeats beyond first 30 second window',
    () async {
      var e = await first();
      for (var n = 1; n <= 5; n++) {
        expect(
          await alerts.consume(e.id, e.revision, sequence: e.sequence),
          isNull,
        );
        now = now.add(const Duration(seconds: 10));
        final attempts = await Future.wait([
          alerts.consume(e.id, e.revision, sequence: e.sequence),
          alerts.consume(e.id, e.revision, sequence: e.sequence),
        ]);
        expect(attempts.whereType<RestAlertEvent>(), hasLength(1));
        e = attempts.whereType<RestAlertEvent>().single;
        expect(e.sequence, n + 1);
      }
      expect((await workouts.getSession(session.id))!.completedSets, 1);
    },
  );
  test(
    'acknowledgment cancels future rounds without completing a set',
    () async {
      final e = await first();
      expect(
        await alerts.acknowledge(e.id, e.sessionId, revision: e.revision),
        true,
      );
      now = now.add(const Duration(seconds: 10));
      expect(
        await alerts.consume(e.id, e.revision, sequence: e.sequence),
        isNull,
      );
      expect(await alerts.awaiting(), isEmpty);
      expect((await workouts.getSession(session.id))!.completedSets, 1);
    },
  );
  test(
    'confirmation failure retains pending confirmation for explicit retry',
    () async {
      final e = await first();
      await app.db.execute(
        "CREATE TRIGGER fail_ack BEFORE UPDATE OF acknowledged_at ON rest_alerts BEGIN SELECT RAISE(ABORT,'fail'); END",
      );
      await expectLater(
        alerts.acknowledge(e.id, e.sessionId),
        throwsA(isA<DatabaseException>()),
      );
      expect(await alerts.awaiting(), hasLength(1));
      await app.db.execute('DROP TRIGGER fail_ack');
      expect(await alerts.acknowledge(e.id, e.sessionId), true);
    },
  );
  test(
    'interval changes and off/on never replay or alter rest deadline',
    () async {
      final e = await first();
      final due = e.dueAt;
      await alerts.setOptions(const RestAlertOptions(repeat: false));
      var current = (await alerts.awaiting()).single;
      expect(current.deliveryAt, isNull);
      await alerts.setOptions(const RestAlertOptions(interval: 30));
      current = (await alerts.awaiting()).single;
      expect(current.deliveryAt, alerts.nowMs + 30000);
      expect(current.dueAt, due);
      expect(
        await alerts.consume(e.id, e.revision, sequence: e.sequence),
        isNull,
      );
      expect(
        await alerts.consume(
          current.id,
          current.revision,
          sequence: current.sequence,
        ),
        isNull,
      );
    },
  );
  test(
    'late repeat produces one round, restart retains only a future next round',
    () async {
      var e = await first();
      now = now.add(const Duration(minutes: 2));
      e = (await alerts.consume(e.id, e.revision, sequence: e.sequence))!;
      expect(e.deliveryAt, alerts.nowMs + 10000);
      now = now.add(const Duration(seconds: 20));
      await alerts.restore(expireElapsed: true);
      final restored = (await alerts.awaiting()).single;
      expect(restored.deliveryAt, alerts.nowMs + 10000);
      // Recovery changes timing, not the identity carried by its notification.
      expect(restored.revision, e.revision);
      expect(
        await alerts.consume(e.id, e.revision, sequence: e.sequence),
        isNull,
      );
      expect(
        await alerts.acknowledge(e.id, e.sessionId, revision: e.revision),
        true,
      );
    },
  );
  test(
    'first late callback expires, and training advancement invalidates repeats',
    () async {
      now = now.add(const Duration(seconds: 91));
      final late = (await alerts.pending()).single;
      expect(await alerts.consume(late.id, late.revision), isNull);
      expect(await alerts.awaiting(), isEmpty);
    },
  );
  test('old confirmation cannot affect a new rest', () async {
    final e = await first();
    await workouts.normalizeRest(session.id);
    session = (await workouts.getSession(session.id))!;
    await workouts.completeSet(
      session.id,
      expectedExerciseId: session.currentExercise.id,
      expectedSetNumber: session.currentSetNumber,
    );
    expect(await alerts.acknowledge(e.id, e.sessionId), false);
    expect(await alerts.pending(), hasLength(1));
  });
  test(
    'v3 upgrade retains training rows and terminates legacy consumed reminders',
    () async {
      await app.db.update('rest_alert_preferences', {'enabled': 0});
      await app.db.update('rest_alerts', {
        'state': 'consumed',
        'consumed_at': alerts.nowMs,
      });
      final original = (await app.db.query('rest_alerts')).single;
      for (final state in ['cancelled', 'expired']) {
        await app.db.insert(
          'rest_alerts',
          {...original}
            ..remove('id')
            ..['state'] = state,
        );
      }
      final business = <String, List<Map<String, Object?>>>{};
      for (final table in [
        'plans',
        'plan_exercises',
        'workout_sessions',
        'session_exercises',
        'session_sets',
      ]) {
        business[table] = await app.db.query(table, orderBy: 'id');
      }
      for (final column in [
        'sound_id',
        'vibration_enabled',
        'repeat_enabled',
        'interval_seconds',
      ]) {
        await app.db.execute(
          'ALTER TABLE rest_alert_preferences DROP COLUMN $column',
        );
      }
      for (final column in [
        'acknowledged_at',
        'delivery_sequence',
        'next_delivery_at',
      ]) {
        await app.db.execute('ALTER TABLE rest_alerts DROP COLUMN $column');
      }
      for (final table in [
        'backup_operations',
        'backup_copies',
        'backup_state',
      ]) {
        await app.db.execute('DROP TABLE $table');
      }
      for (final trigger in [
        'plans_append_order',
        'workouts_append_order_insert',
        'workouts_append_order_complete',
      ]) {
        await app.db.execute('DROP TRIGGER $trigger');
      }
      await app.db.execute('ALTER TABLE plans DROP COLUMN sort_order');
      await app.db.execute(
        'ALTER TABLE workout_sessions DROP COLUMN backup_order',
      );
      await app.db.setVersion(3);
      await app.close();
      app = await AppDatabase.open(
        filePath: '${dir.path}/db',
        factory: databaseFactoryFfi,
      );
      expect(await app.db.getVersion(), 6);
      expect(
        (await app.db.query('rest_alert_preferences')).single['enabled'],
        0,
      );
      for (final entry in business.entries) {
        expect(await app.db.query(entry.key, orderBy: 'id'), entry.value);
      }
      final rows = await app.db.query('rest_alerts', orderBy: 'id');
      expect(rows.first['acknowledged_at'], alerts.nowMs);
      expect(rows.map((e) => e['state']), ['consumed', 'cancelled', 'expired']);
      expect(rows.every((e) => e['next_delivery_at'] == null), true);
    },
  );
}
