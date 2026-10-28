import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostic_observation.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/diagnostics_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('expiry observations are bounded, post-commit and absent on rollback or unchanged polling', () async {
    final directory = await Directory.systemTemp.createTemp('transitions-v2-');
    final db = await AppDatabase.open(
      filePath: '${directory.path}/db',
      factory: databaseFactoryFfi,
    );
    final transport = FakeDiagnosticsTransport();
    final client = DiagnosticsClient(transport: transport, epoch: () => 0);
    final previous = DiagnosticsClient.instance;
    DiagnosticsClient.instance = client;
    try {
      await client.overview();
      final plans = PlanRepository(db.db);
      final plan = await plans.createPlan('PRIVATE_NAME');
      await plans.addExercise(
        planId: plan,
        name: 'PRIVATE_EXERCISE',
        targetSets: 3,
        restBetweenSetsSeconds: 30,
        restAfterExerciseSeconds: 0,
      );
      final workouts = WorkoutRepository(
        db.db,
        clock: () => DateTime.utc(2026),
      );
      final session = await workouts.start(plan);
      await workouts.completeSet(
        session.id,
        expectedExerciseId: session.currentExercise.id,
        expectedSetNumber: 1,
      );
      final row = Map<String, Object?>.from(
        (await db.db.query('rest_alerts')).single,
      )..remove('id');
      for (var i = 0; i < 49; i++) {
        await db.db.insert('rest_alerts', row);
      }
      final repository = RestAlertRepository(
        db.db,
        clock: () => DateTime.utc(2027),
      );
      await client.flush();
      transport.events.clear();
      Future<void> restore() => diagnosticObserve(
        client,
        DiagnosticName.restSynchronize,
        () => repository.restore(expireElapsed: true),
        readOnly: true,
        recordSuccess: false,
        nestReadScope: true,
      );
      await db.db.execute(
        "CREATE TRIGGER fail_expiry BEFORE UPDATE OF state ON rest_alerts BEGIN SELECT RAISE(ABORT,'PRIVATE_FAILURE'); END",
      );
      await expectLater(restore(), throwsA(isA<DatabaseException>()));
      await client.flush();
      expect(
        transport.events.where((e) => e['event_name'] == 'rest.transition'),
        isEmpty,
      );
      await db.db.execute('DROP TRIGGER fail_expiry');
      transport.events.clear();
      await restore();
      await client.flush();
      final transitions = transport.events
          .where((e) => e['event_name'] == 'rest.transition')
          .toList();
      expect(transitions, hasLength(17));
      expect(transitions.last['attributes']['count'], 50);
      expect(transitions.last['attributes']['truncated_count'], 34);
      expect(transitions.every((e) => e['phase'] == 'committed'), isTrue);
      expect(transport.events.toString(), isNot(contains('PRIVATE_')));
      transport.events.clear();
      await restore();
      await client.flush();
      expect(transport.events, isEmpty);
      expect((await workouts.getSession(session.id))!.completedSets, 1);
    } finally {
      DiagnosticsClient.instance = previous;
      client.dispose();
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
