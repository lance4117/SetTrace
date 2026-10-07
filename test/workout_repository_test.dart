import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String filePath;
  late AppDatabase database;
  late PlanRepository plans;
  late WorkoutRepository workouts;
  var now = DateTime.utc(2026, 9, 25, 10);

  setUp(() async {
    now = DateTime.utc(2026, 9, 25, 10);
    directory = await Directory.systemTemp.createTemp('settrace_workout_');
    filePath = p.join(directory.path, 'settrace.db');
    database = await AppDatabase.open(
      filePath: filePath,
      factory: databaseFactoryFfi,
    );
    plans = PlanRepository(database.db);
    workouts = WorkoutRepository(database.db, clock: () => now);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<int> seedPlan() async {
    final id = await plans.createPlan('练背');
    await plans.addExercise(
      planId: id,
      name: '高位下拉',
      targetSets: 2,
      restBetweenSetsSeconds: 120,
      restAfterExerciseSeconds: 150,
      defaultWeightKg: 45,
    );
    await plans.addExercise(
      planId: id,
      name: '坐姿划船',
      targetSets: 1,
      restBetweenSetsSeconds: 90,
      restAfterExerciseSeconds: 0,
    );
    return id;
  }

  test('start snapshots plan and permits only one active workout', () async {
    final planId = await seedPlan();
    final session = await workouts.start(planId);
    expect(session.exercises.map((e) => e.name), ['高位下拉', '坐姿划船']);
    expect(session.exercises.first.defaultWeightKg, 45);
    await expectLater(workouts.start(planId), throwsStateError);
    await plans.renamePlan(planId, '新名称');
    await plans.deletePlan(planId);
    final saved = (await workouts.getSession(session.id))!;
    expect(saved.planName, '练背');
    expect(saved.exercises.first.name, '高位下拉');
    expect(saved.exercises.first.restAfterExerciseSeconds, 150);
  });

  test('set transition, rest adjustment, undo and session-only edit', () async {
    final planId = await seedPlan();
    final session = await workouts.start(planId);
    final first = await workouts.completeSet(
      session.id,
      expectedExerciseId: session.exercises[0].id,
      expectedSetNumber: 1,
    );
    expect(first.completedSets, 1);
    expect(first.restKind, 'between_sets');
    expect(first.restEndAt!.difference(now), const Duration(seconds: 120));
    await expectLater(
      workouts.completeSet(
        session.id,
        expectedExerciseId: session.exercises[0].id,
        expectedSetNumber: 1,
      ),
      throwsStateError,
    );
    final longer = await workouts.adjustRest(session.id, 30);
    expect(longer.restEndAt!.difference(now), const Duration(seconds: 150));
    final undone = await workouts.undoLastSet(session.id);
    expect(undone.completedSets, 0);
    expect(undone.resting, false);
    expect(undone.currentSetNumber, 1);
    final edited = await workouts.updateExercise(
      session.id,
      session.exercises.first.id,
      targetSets: 3,
      restBetweenSetsSeconds: 90,
      restAfterExerciseSeconds: 150,
    );
    expect(edited.exercises.first.targetSets, 3);
    expect((await plans.getPlan(planId))!.exercises.first.targetSets, 2);
    await expectLater(
      workouts.updateExercise(
        session.id,
        session.exercises.first.id,
        targetSets: 0,
        restBetweenSetsSeconds: 90,
        restAfterExerciseSeconds: 150,
      ),
      throwsArgumentError,
    );
  });

  test('expired rest recovers and partial workout enters history', () async {
    final planId = await seedPlan();
    final session = await workouts.start(planId);
    await workouts.completeSet(
      session.id,
      expectedExerciseId: session.exercises[0].id,
      expectedSetNumber: 1,
    );
    await database.close();
    now = now.add(const Duration(minutes: 3));
    database = await AppDatabase.open(
      filePath: filePath,
      factory: databaseFactoryFfi,
    );
    await database.db.update(
      'workout_sessions',
      {'current_exercise_order': 2, 'current_set_number': 1},
      where: 'id = ?',
      whereArgs: [session.id],
    );
    workouts = WorkoutRepository(database.db, clock: () => now);
    final resumed = (await workouts.getActive())!;
    expect(resumed.resting, false);
    expect(resumed.currentExerciseOrder, 1);
    expect(resumed.currentSetNumber, 2);
    expect(resumed.completedSets, 1);
    final finished = await workouts.finish(session.id);
    expect(finished.durationSeconds, 180);
    expect((await workouts.listHistory()).single.id, session.id);
    expect(await workouts.getActive(), isNull);
  });

  test('discarding a zero-set workout leaves no history', () async {
    final planId = await seedPlan();
    final session = await workouts.start(planId);
    await expectLater(workouts.finish(session.id), throwsStateError);
    await workouts.discard(session.id);
    expect(await workouts.listHistory(), isEmpty);
  });

  test('finish needs explicit call and preserves partial snapshot', () async {
    final planId = await seedPlan();
    final session = await workouts.start(planId);
    await workouts.completeSet(
      session.id,
      expectedExerciseId: session.exercises[0].id,
      expectedSetNumber: 1,
    );
    expect((await workouts.getSession(session.id))!.inProgress, true);
    expect(await workouts.listHistory(), isEmpty);
    now = now.add(const Duration(minutes: 5));
    final saved = await workouts.finish(session.id);
    expect(saved.endedAt, now);
    expect(saved.durationSeconds, 300);
    expect(saved.completedSets, 1);
    expect((await workouts.listHistory()).single.id, session.id);
    await plans.renamePlan(planId, '改名后');
    expect((await workouts.getSession(session.id))!.planName, '练背');
  });

  test(
    'both rest types lead to final-set confirmation without duplicate sets',
    () async {
      final session = await workouts.start(await seedPlan());
      await workouts.completeSet(
        session.id,
        expectedExerciseId: session.exercises[0].id,
        expectedSetNumber: 1,
      );
      await workouts.skipRest(session.id);
      final afterExercise = await workouts.completeSet(
        session.id,
        expectedExerciseId: session.exercises[0].id,
        expectedSetNumber: 2,
      );
      expect(afterExercise.restKind, 'between_exercises');
      expect(
        afterExercise.restEndAt!.difference(now),
        const Duration(seconds: 150),
      );
      final next = await workouts.skipRest(session.id);
      expect(next.currentExerciseOrder, 2);
      expect(next.currentSetNumber, 1);
      final last = await workouts.completeSet(
        session.id,
        expectedExerciseId: session.exercises[1].id,
        expectedSetNumber: 1,
      );
      expect(last.allSetsCompleted, true);
      expect(last.resting, false);
      expect(last.inProgress, true);
      await expectLater(
        workouts.completeSet(
          session.id,
          expectedExerciseId: session.exercises[1].id,
          expectedSetNumber: 1,
        ),
        throwsStateError,
      );
      expect((await workouts.getSession(session.id))!.completedSets, 3);
    },
  );

  test(
    'rest can be reduced to zero and completed sets constrain edits',
    () async {
      final session = await workouts.start(await seedPlan());
      await workouts.completeSet(
        session.id,
        expectedExerciseId: session.exercises[0].id,
        expectedSetNumber: 1,
      );
      final ready = await workouts.adjustRest(session.id, -120);
      expect(ready.resting, false);
      await workouts.updateExercise(
        session.id,
        session.exercises.first.id,
        targetSets: 3,
        restBetweenSetsSeconds: 120,
        restAfterExerciseSeconds: 150,
      );
      await workouts.completeSet(
        session.id,
        expectedExerciseId: session.exercises[0].id,
        expectedSetNumber: 2,
      );
      await expectLater(
        workouts.updateExercise(
          session.id,
          session.exercises.first.id,
          targetSets: 1,
          restBetweenSetsSeconds: 120,
          restAfterExerciseSeconds: 150,
        ),
        throwsArgumentError,
      );
      await workouts.discard(session.id);
      expect(await workouts.listHistory(), isEmpty);
    },
  );

  test(
    'reducing target to completed sets repairs final cursor and rest',
    () async {
      final planId = await plans.createPlan('短训练');
      await plans.addExercise(
        planId: planId,
        name: '动作',
        targetSets: 4,
        restBetweenSetsSeconds: 120,
        restAfterExerciseSeconds: 0,
      );
      final session = await workouts.start(planId);
      final resting = await workouts.completeSet(
        session.id,
        expectedExerciseId: session.exercises[0].id,
        expectedSetNumber: 1,
      );
      expect(resting.resting, true);
      final edited = await workouts.updateExercise(
        session.id,
        session.exercises.single.id,
        targetSets: 1,
        restBetweenSetsSeconds: 120,
        restAfterExerciseSeconds: 0,
      );
      expect(edited.allSetsCompleted, true);
      expect(edited.resting, false);
      expect(edited.currentSetNumber, 1);
    },
  );
  Future<int> savedWorkout(int planId, {bool complete = false}) async {
    final session = await workouts.start(planId);
    for (final exercise in session.exercises) {
      for (var number = 1; number <= exercise.targetSets; number++) {
        if ((await workouts.getSession(session.id))!.resting) {
          await workouts.skipRest(session.id);
        }
        await workouts.completeSet(
          session.id,
          expectedExerciseId: exercise.id,
          expectedSetNumber: number,
        );
        if (!complete) break;
      }
      if (!complete) break;
    }
    now = now.add(const Duration(minutes: 30));
    await workouts.finish(session.id);
    return session.id;
  }

  for (final complete in [false, true]) {
    test(
      'delete history cascades and preserves other data complete=$complete',
      () async {
        final plan = await seedPlan();
        final target = await savedWorkout(plan, complete: complete);
        final other = await savedWorkout(plan);
        final active = await workouts.start(plan);
        final tables = [
          'plans',
          'plan_exercises',
          'workout_sessions',
          'session_exercises',
          'session_sets',
        ];
        final before = <String, List<Map<String, Object?>>>{};
        for (final table in tables) {
          before[table] = await database.db.query(table, orderBy: 'id');
        }
        final exerciseIds = before['session_exercises']!
            .where((row) => row['session_id'] == target)
            .map((r) => r['id'])
            .toSet();
        await expectLater(workouts.discard(target), throwsStateError);
        await workouts.deleteHistory(target);
        for (final table in tables) {
          final expected = before[table]!
              .where(
                (row) => switch (table) {
                  'workout_sessions' => row['id'] != target,
                  'session_exercises' => row['session_id'] != target,
                  'session_sets' => !exerciseIds.contains(
                    row['session_exercise_id'],
                  ),
                  _ => true,
                },
              )
              .toList();
          expect(
            await database.db.query(table, orderBy: 'id'),
            expected,
            reason: table,
          );
        }
        expect((await workouts.listHistory()).single.id, other);
        expect((await workouts.getActive())!.id, active.id);
        expect(await database.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        await database.close();
        database = await AppDatabase.open(
          filePath: filePath,
          factory: databaseFactoryFfi,
        );
        workouts = WorkoutRepository(database.db, clock: () => now);
        expect(await workouts.getSession(target), isNull);
        expect((await workouts.listHistory()).single.id, other);
        expect((await workouts.getActive())!.id, active.id);
        expect(await database.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      },
    );
  }

  test(
    'delete history rejects active and missing targets without writes',
    () async {
      final active = await workouts.start(await seedPlan());
      final before = await database.db.query('workout_sessions');
      await expectLater(
        workouts.deleteHistory(active.id),
        throwsA(
          isA<HistoryDeleteException>().having(
            (e) => e.reason,
            'reason',
            HistoryDeleteFailure.notSaved,
          ),
        ),
      );
      await expectLater(
        workouts.deleteHistory(999999),
        throwsA(
          isA<HistoryDeleteException>().having(
            (e) => e.reason,
            'reason',
            HistoryDeleteFailure.notFound,
          ),
        ),
      );
      expect(await database.db.query('workout_sessions'), before);
      expect((await workouts.getActive())!.id, active.id);
    },
  );

  test('cascade failure rolls back all data and can be retried', () async {
    final target = await savedWorkout(await seedPlan());
    final before = <String, List<Map<String, Object?>>>{};
    for (final table in [
      'workout_sessions',
      'session_exercises',
      'session_sets',
    ]) {
      before[table] = await database.db.query(table, orderBy: 'id');
    }
    await database.db.execute(
      "CREATE TEMP TRIGGER fail_history_delete "
      "BEFORE DELETE ON session_sets BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      workouts.deleteHistory(target),
      throwsA(isA<DatabaseException>()),
    );
    for (final entry in before.entries) {
      expect(await database.db.query(entry.key, orderBy: 'id'), entry.value);
    }
    expect(await database.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await database.db.execute('DROP TRIGGER fail_history_delete');
    await workouts.deleteHistory(target);
    expect(await workouts.listHistory(), isEmpty);
    expect(await database.db.query('session_exercises'), isEmpty);
    expect(await database.db.query('session_sets'), isEmpty);
  });
}
