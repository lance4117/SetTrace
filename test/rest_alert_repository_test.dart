import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/workout/workout_models.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_platform.dart';
import 'package:settrace/features/rest_alerts/rest_alert_service.dart';
import 'package:settrace/l10n/generated/app_localizations_en.dart';
import 'package:settrace/l10n/generated/app_localizations_zh.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeAlertsPlatform extends RestAlertPlatform {
  FakeAlertsPlatform(this.repo);
  final RestAlertRepository repo;
  final scheduled = <int, int>{};
  final sounds = <int>[];
  Set<int> validIds = {};
  bool failSchedule = false, failCancel = false;
  int permissionCalls = 0;
  @override
  Future<void> initialize(String path, String name, String description) async {}
  @override
  Future<RestAlertCapabilities> capabilities() async =>
      const RestAlertCapabilities(notifications: false, exact: false);
  @override
  Future<void> schedule(RestAlertEvent e) async {
    if (failSchedule) throw StateError('scheduleFailed');
    scheduled[e.id] = e.revision;
  }

  @override
  Future<void> deliver(RestAlertEvent e) async {
    if (await repo.consume(e.id, e.revision) != null) {
      sounds.add(e.id);
      onDelivered?.call(e.body);
    }
  }

  @override
  Future<void> cancelExcept(Set<int> ids) async {
    if (failCancel) throw StateError('cancelFailed');
    validIds = ids;
    scheduled.removeWhere((id, _) => !ids.contains(id));
  }

  @override
  Future<void> requestNotifications() async {
    permissionCalls++;
  }

  @override
  Future<void> openSettings({required bool exact}) async {}
  @override
  Future<int?> takeInitialTap() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase db;
  late WorkoutRepository workouts;
  late RestAlertRepository alerts;
  late RestAlertService service;
  late FakeAlertsPlatform platform;
  late DateTime now;
  late WorkoutSessionData session;
  setUp(() async {
    now = DateTime.utc(2026, 10, 13);
    dir = await Directory.systemTemp.createTemp('rest_alerts_test_');
    db = await AppDatabase.open(
      filePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    workouts = WorkoutRepository(db.db, clock: () => now);
    alerts = RestAlertRepository(db.db, clock: () => now);
    platform = FakeAlertsPlatform(alerts);
    service = RestAlertService(alerts, platform);
    final plans = PlanRepository(db.db);
    final id = await plans.createPlan('Plan');
    for (final name in ['A', 'B', 'C']) {
      await plans.addExercise(
        planId: id,
        name: name,
        targetSets: 4,
        restBetweenSetsSeconds: 60,
        restAfterExerciseSeconds: 60,
      );
    }
    session = await workouts.start(id);
    await service.configure(AppLocalizationsEn(), expireElapsed: true);
  });
  tearDown(() async {
    service.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<WorkoutSessionData> done() async {
    session = await workouts.completeSet(
      session.id,
      expectedExerciseId: session.currentExercise.id,
      expectedSetNumber: session.currentSetNumber,
    );
    return session;
  }

  test('default does not request permission before a real rest; refusal is remembered', () async {
    expect(service.enabled, true);
    expect(service.permissionNeeded, false);
    await done();
    await service.synchronize(offerPermission: true);
    expect(service.permissionNeeded, true);
    await service.acknowledgePermission(request: false);
    expect((await alerts.preferences())['permission_requested'], 1);
    await workouts.skipRest(session.id);
    session = (await workouts.getSession(session.id))!;
    await done();
    await service.synchronize(offerPermission: true);
    expect(service.permissionNeeded, false);
    expect(platform.permissionCalls, 0);
  });

  test(
    'normalization and concurrent observers still deliver at most once',
    () async {
      await done();
      await service.synchronize();
      final e = (await alerts.pending()).single;
      now = now.add(const Duration(seconds: 60));
      await workouts.normalizeRest(session.id);
      await Future.wait([
        platform.deliver(e),
        service.synchronize(),
        platform.deliver(e),
      ]);
      expect(platform.sounds, [e.id]);
      expect((await workouts.getSession(session.id))!.completedSets, 1);
    },
  );

  test('adjustment invalidates old revision; cancel failure cannot revive stale delivery', () async {
    await done();
    await service.synchronize();
    final old = (await alerts.pending()).single;
    session = await workouts.adjustRest(session.id, 30);
    await service.synchronize();
    now = now.add(const Duration(seconds: 60));
    await platform.deliver(old);
    expect(platform.sounds, isEmpty);
    final updated = (await alerts.pending()).single;
    platform.failCancel = true;
    await workouts.skipRest(session.id);
    await expectLater(service.synchronize(), throwsStateError);
    now = now.add(const Duration(seconds: 30));
    await platform.deliver(updated);
    expect(platform.sounds, isEmpty);
  });

  test(
    'schedule failure preserves completed set and is separately retryable',
    () async {
      platform.failSchedule = true;
      await done();
      await expectLater(service.synchronize(), throwsStateError);
      expect((await workouts.getSession(session.id))!.completedSets, 1);
      expect(service.failed, true);
      platform.failSchedule = false;
      await service.synchronize();
      expect(service.failed, false);
      expect(platform.scheduled.length, 1);
    },
  );

  test('preference save failure preserves original setting and events', () async {
    await done();
    await service.synchronize();
    final old = (await alerts.pending()).single;
    await db.db.execute(
      """CREATE TRIGGER fail_preference BEFORE UPDATE ON rest_alert_preferences
      BEGIN SELECT RAISE(ABORT, 'test'); END""",
    );
    await expectLater(
      service.setEnabled(false),
      throwsA(isA<DatabaseException>()),
    );
    expect(service.enabled, true);
    expect((await alerts.pending()).single.revision, old.revision);
  });

  test('off/on keeps deadline; restart and late callbacks never replay elapsed reminders', () async {
    await done();
    await service.synchronize();
    final e = (await alerts.pending()).single;
    final due = session.restEndAt;
    await service.setEnabled(false);
    expect(await alerts.pending(), isEmpty);
    await service.setEnabled(true);
    expect((await workouts.getSession(session.id))!.restEndAt, due);
    now = now.add(const Duration(seconds: 60));
    await service.synchronize(expireElapsed: true);
    await platform.deliver(e);
    expect(platform.sounds, isEmpty);
    await workouts.skipRest(session.id);
    session = (await workouts.getSession(session.id))!;
    await done();
    await service.synchronize();
    final next = (await alerts.pending()).single;
    now = now.add(const Duration(seconds: 91));
    await platform.deliver(next);
    expect(platform.sounds, isEmpty);
  });

  test('language and next-exercise ordering update content without shifting due date', () async {
    await done();
    await service.synchronize();
    final old = (await alerts.pending()).single;
    await service.configure(AppLocalizationsZh());
    final translated = (await alerts.pending()).single;
    expect(translated.dueAt, old.dueAt);
    expect(translated.title, '休息结束');
    expect(translated.body, contains('A'));
    expect(translated.revision, greaterThan(old.revision));
  });


  test('restoring an ongoing future rest does not prompt during upgrade startup', () async {
    await done();
    await service.configure(AppLocalizationsEn(), expireElapsed: true);
    expect(service.permissionNeeded, false);
    expect(platform.permissionCalls, 0);
    expect(platform.scheduled, isNotEmpty);
    await service.synchronize(offerPermission: true);
    expect(service.permissionNeeded, true);
  });

  test('skip remaining, undo and finish invalidate the old alert', () async {
    await done();
    await workouts.skipRest(session.id);
    session = (await workouts.getSession(session.id))!;
    await done();
    await service.synchronize();
    final old = (await alerts.pending()).single;
    session = await workouts.skipRemainingSets(
      session.id,
      expectedExerciseId: session.currentExercise.id,
      expectedToken: session.reorderToken,
    );
    await service.synchronize();
    expect(await alerts.pending(), isEmpty);
    now = now.add(const Duration(seconds: 60));
    await platform.deliver(old);
    expect(platform.sounds, isEmpty);
    await workouts.finish(session.id);
    await service.synchronize();
    expect(platform.validIds, isEmpty);
  });
  test('elapsed rest cannot be extended by a stale adjustment', () async {
    await done(); await service.synchronize();
    final event = (await alerts.pending()).single;
    now = now.add(const Duration(seconds: 60));
    await expectLater(workouts.adjustRest(session.id, 30), throwsStateError);
    await workouts.normalizeRest(session.id);
    expect((await workouts.getSession(session.id))!.resting, false);
    await platform.deliver(event); expect(platform.sounds, [event.id]);
  });

}
