import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostic_observation.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/diagnostics_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late AppDatabase database;
  late PlanRepository plans;
  late WorkoutRepository workouts;
  late DiagnosticsClient client;
  late FakeDiagnosticsTransport transport;
  late DataWriteCoordinator writes;
  var now = DateTime.utc(2026, 10, 24, 10);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'settrace_diagnostic_business_',
    );
    database = await AppDatabase.open(
      filePath: p.join(directory.path, 'business.db'),
      factory: databaseFactoryFfi,
    );
    writes = DataWriteCoordinator()..reconcile(0);
    transport = FakeDiagnosticsTransport();
    client = DiagnosticsClient(
      transport: transport,
      epoch: () => writes.diagnosticEpoch,
    );
    await client.overview();
    plans = PlanRepository(
      database.db,
      coordinator: writes,
      diagnostics: client,
    );
    workouts = WorkoutRepository(
      database.db,
      coordinator: writes,
      diagnostics: client,
      clock: () => now,
    );
  });
  tearDown(() async {
    client.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });
  Future<int> seed() async {
    final id = await plans.createPlan('PRIVATE_PLAN_SENTINEL');
    await plans.addExercise(
      planId: id,
      name: 'PRIVATE_EXERCISE_SENTINEL',
      targetSets: 3,
      restBetweenSetsSeconds: 30,
      restAfterExerciseSeconds: 0,
      defaultWeightKg: 47.125,
    );
    return id;
  }

  List<Map<String, dynamic>> events(DiagnosticName name) => transport.events
      .where((event) => event['event_name'] == name.wire)
      .toList();

  test(
    'real plan/workout operations preserve commits without user content',
    () async {
      final plan = await seed();
      final session = await workouts.start(plan);
      await workouts.completeSet(
        session.id,
        expectedExerciseId: session.currentExercise.id,
        expectedSetNumber: 1,
      );
      await client.flush();
      final complete = events(DiagnosticName.workoutComplete);
      expect(
        complete.any(
          (event) =>
              event['phase'] == 'committed' && event['outcome'] == 'committed',
        ),
        isTrue,
      );
      expect((complete.last['attributes'] as Map)['completed_count'], 1);
      expect((complete.last['attributes'] as Map)['duration_ms'], isA<int>());
      expect(complete.map((event) => event['operation_id']).toSet().length, 1);
      final serialized = transport.events.toString();
      expect(serialized, isNot(contains('PRIVATE_PLAN_SENTINEL')));
      expect(serialized, isNot(contains('PRIVATE_EXERCISE_SENTINEL')));
      expect(serialized, isNot(contains('47.125')));
      expect(await database.db.getVersion(), 6);
    },
  );
  test(
    'commit is retained when onChanged throws after successful transaction',
    () async {
      final session = await workouts.start(await seed());
      workouts.onChanged = () => throw StateError('PRIVATE callback failure');
      await expectLater(
        workouts.completeSet(
          session.id,
          expectedExerciseId: session.currentExercise.id,
          expectedSetNumber: 1,
        ),
        throwsStateError,
      );
      expect((await workouts.getSession(session.id))!.completedSets, 1);
      await client.flush();
      final complete = events(DiagnosticName.workoutComplete);
      expect(complete.any((event) => event['outcome'] == 'committed'), isTrue);
      expect(complete.last['outcome'], 'partial_success');
      expect(complete.last['phase'], 'refresh');
      expect(complete.last['reason_code'], 'followup_failed');
      expect(
        transport.events.toString(),
        isNot(contains('PRIVATE callback failure')),
      );
    },
  );
  test(
    'validation rejection and confirmed rollback do not claim a commit',
    () async {
      await expectLater(plans.createPlan('  '), throwsArgumentError);
      await expectLater(
        diagnosticObserve(
          client,
          DiagnosticName.planCreate,
          () => diagnosticTransaction(database.db, (transaction) async {
            await transaction.insert('plans', {
              'name': 'PRIVATE_TRANSACTION',
              'created_at': 1,
              'updated_at': 1,
            });
            throw Exception('PRIVATE SQL parameters');
          }),
        ),
        throwsException,
      );
      await client.flush();
      expect(await plans.listPlans(), isEmpty);
      final records = events(DiagnosticName.planCreate);
      expect(records.any((event) => event['outcome'] == 'committed'), isFalse);
      expect(
        records.any(
          (event) =>
              event['outcome'] == 'rejected' && event['severity'] == 'info',
        ),
        isTrue,
      );
      expect(records.last['outcome'], 'rolled_back_confirmed');
      expect(records.toString(), isNot(contains('PRIVATE')));
    },
  );
  test(
    'normal recovery reads stay quiet; committed correction is observable',
    () async {
      final session = await workouts.start(await seed());
      await client.flush();
      transport.events.clear();
      for (var i = 0; i < 5; i++) {
        await workouts.getActive();
      }
      await client.flush();
      expect(events(DiagnosticName.workoutRecover), isEmpty);
      await database.db.update(
        'workout_sessions',
        {'current_set_number': 99},
        where: 'id = ?',
        whereArgs: [session.id],
      );
      await workouts.getActive();
      await client.flush();
      final corrected = events(DiagnosticName.workoutRecover)
          .where((event) => event['phase'] == 'committed')
          .toList();
      expect(corrected, isNotEmpty);
      expect(corrected.last['reason_code'], 'stale_position');
      expect((corrected.last['attributes'] as Map)['before_count'], 99);
      expect((corrected.last['attributes'] as Map)['after_count'], 1);
    },
  );
  test(
    'history deletion and failed later refresh can share the causal parent',
    () async {
      final session = await workouts.start(await seed());
      await workouts.completeSet(
        session.id,
        expectedExerciseId: session.currentExercise.id,
        expectedSetNumber: 1,
      );
      await workouts.finish(session.id);
      await workouts.deleteHistory(session.id);
      final deletion = workouts.lastHistoryDeleteOperationId;
      expect(deletion, isNotNull);
      await expectLater(
        diagnosticObserve(
          client,
          DiagnosticName.historyRefresh,
          () async => throw StateError('PRIVATE refresh failed'),
          readOnly: true,
          parentOperation: deletion,
        ),
        throwsStateError,
      );
      await client.flush();
      expect(await workouts.getSession(session.id), isNull);
      expect(
        events(DiagnosticName.historyDelete)
            .any((event) => event['outcome'] == 'committed'),
        isTrue,
      );
      expect(
        events(DiagnosticName.historyRefresh).last['parent_operation_id'],
        deletion,
      );
      expect(events(DiagnosticName.historyRefresh).last['outcome'], 'unknown');
    },
  );
  test('logger transport failure cannot roll back a business write', () async {
    transport.failMethods.add('recordBatch');
    final plan = await seed();
    final session = await workouts.start(plan);
    await workouts.completeSet(
      session.id,
      expectedExerciseId: session.currentExercise.id,
      expectedSetNumber: 1,
    );
    await client.flush();
    expect((await workouts.getSession(session.id))!.completedSets, 1);
    expect(client.dropped, greaterThan(0));
  });
  test(
    'diagnostic epoch is unknown until reconciliation and changes on commit',
    () async {
      final coordinator = DataWriteCoordinator();
      expect(coordinator.diagnosticEpoch, isNull);
      coordinator.reconcile(3);
      expect(coordinator.diagnosticEpoch, 3);
      await coordinator.exclusive(() async {
        coordinator.committed(4);
      });
      expect(coordinator.diagnosticEpoch, 4);
    },
  );
}
