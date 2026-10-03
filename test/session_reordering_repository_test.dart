import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_models.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/history/history_stats.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late String path;
  late AppDatabase database;
  late PlanRepository plans;
  late WorkoutRepository workouts;
  late DateTime now;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settrace_reorder_');
    path = p.join(directory.path, 'test.db');
    now = DateTime.utc(2026, 10, 3, 10);
    database = await AppDatabase.open(
      filePath: path,
      factory: databaseFactoryFfi,
    );
    plans = PlanRepository(database.db);
    workouts = WorkoutRepository(database.db, clock: () => now);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });
  Future<int> seed({
    List<int> sets = const [1, 2, 1, 1],
    int rest = 0,
    int after = 0,
    List<String> names = const ['A', 'B', 'C', 'D'],
  }) async {
    final id = await plans.createPlan('训练');
    for (var i = 0; i < sets.length; i++) {
      await plans.addExercise(
        planId: id,
        name: names[i],
        targetSets: sets[i],
        restBetweenSetsSeconds: rest,
        restAfterExerciseSeconds: after,
        defaultWeightKg: i + 10.5,
      );
    }
    return id;
  }

  Future<WorkoutSessionData> done(WorkoutSessionData data) =>
      workouts.completeSet(
        data.id,
        expectedExerciseId: data.currentExercise.id,
        expectedSetNumber: data.currentSetNumber,
      );
  Future<WorkoutSessionData> order(WorkoutSessionData data, List<int> ids) =>
      workouts.reorder(data.id, ids, expectedToken: data.reorderToken);

  test(
    'A C B D preserves adjusted rest, identities, config and restart',
    () async {
      final plan = await seed(after: 150);
      final initial = await workouts.start(plan);
      final ids = initial.exercises.map((e) => e.id).toList();
      var data = await done(initial);
      data = await workouts.adjustRest(data.id, 30);
      data = await workouts.adjustRest(data.id, -30);
      final deadline = data.restEndAt;
      final start = data.restStartedAt;
      final timestamp = data.exercises.first.sets.first.completedAt;
      data = await order(data, [ids[2], ids[1], ids[3]]);
      expect(data.exercises.map((e) => e.name), ['A', 'C', 'B', 'D']);
      expect(data.currentExercise.id, ids[2]);
      expect(data.restEndAt, deadline);
      expect(data.restStartedAt, start);
      expect(data.restKind, 'between_exercises');
      expect(data.exercises.first.sets.first.completedAt, timestamp);
      expect(data.completedSets, 1);
      expect(data.exercises[1].defaultWeightKg, 12.5);
      expect((await plans.getPlan(plan))!.exercises.map((e) => e.name), [
        'A',
        'B',
        'C',
        'D',
      ]);
      await database.close();
      now = now.add(const Duration(seconds: 30));
      database = await AppDatabase.open(
        filePath: path,
        factory: databaseFactoryFfi,
      );
      workouts = WorkoutRepository(database.db, clock: () => now);
      plans = PlanRepository(database.db);
      final resumed = (await workouts.getActive())!;
      expect(resumed.reorderToken, data.reorderToken);
      expect(resumed.restEndAt, deadline);
      expect(resumed.currentExercise.id, ids[2]);
      now = now.add(const Duration(minutes: 3));
      final expired = (await workouts.getActive())!;
      expect(expired.resting, false);
      expect(expired.currentExercise.name, 'C');
      expect(expired.completedSets, 1);
    },
  );

  test(
    'zero-rest current B can switch to C and stale B cannot complete C',
    () async {
      var data = await done(await workouts.start(await seed()));
      final oldB = data.currentExercise.id;
      final ids = data.movableExercises.map((e) => e.id).toList();
      data = await order(data, [ids[1], ids[0], ids[2]]);
      expect(data.currentExercise.name, 'C');
      expect(data.resting, false);
      await expectLater(
        workouts.completeSet(
          data.id,
          expectedExerciseId: oldB,
          expectedSetNumber: 1,
        ),
        throwsStateError,
      );
      data = await done(data);
      expect(data.currentExercise.name, 'B');
      expect(data.completedSets, 2);
      await expectLater(
        workouts.updateExercise(
          data.id,
          ids[1],
          targetSets: 2,
          restBetweenSetsSeconds: 0,
          restAfterExerciseSeconds: 0,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'partial B stays pinned while future D moves before C during group rest',
    () async {
      var data = await done(
        await workouts.start(await seed(sets: [1, 4, 1, 1], rest: 120)),
      );
      data = await done(data);
      data = await workouts.skipRest(data.id);
      data = await done(data);
      final deadline = data.restEndAt;
      final current = data.currentExercise.id;
      final candidates = data.movableExercises;
      data = await order(data, [candidates[1].id, candidates[0].id]);
      expect(data.currentExercise.id, current);
      expect(data.currentSetNumber, 3);
      expect(data.exercises.map((e) => e.name), ['A', 'B', 'D', 'C']);
      expect(data.restEndAt, deadline);
      data = await workouts.skipRest(data.id);
      data = await done(data);
      data = await workouts.skipRest(data.id);
      data = await done(data);
      expect(data.currentExercise.name, 'D');
    },
  );

  test(
    'invalid and stale drafts roll back every part of the session',
    () async {
      var data = await done(await workouts.start(await seed(after: 150)));
      final candidates = data.movableExercises.map((e) => e.id).toList();
      final before = await database.db.query(
        'session_exercises',
        orderBy: 'id',
      );
      final sessionBefore = await database.db.query('workout_sessions');
      for (final invalid in [
        [candidates[0], candidates[0], candidates[2]],
        candidates.take(2).toList(),
        [99999, candidates[1], candidates[2]],
        [data.exercises.first.id, candidates[1], candidates[2]],
      ]) {
        await expectLater(order(data, invalid), throwsArgumentError);
        expect(
          await database.db.query('session_exercises', orderBy: 'id'),
          before,
        );
        expect(await database.db.query('workout_sessions'), sessionBefore);
      }
      final stale = data;
      data = await order(data, candidates.reversed.toList());
      await expectLater(order(stale, candidates), throwsStateError);
      expect(
        (await workouts.getSession(data.id))!.reorderToken,
        data.reorderToken,
      );
      data = await workouts.skipRest(data.id);
      final pending = data;
      data = await done(data);
      await expectLater(
        order(pending, pending.movableExercises.map((e) => e.id).toList()),
        throwsStateError,
      );
      expect(
        (await workouts.getSession(data.id))!.completedSets,
        data.completedSets,
      );
      await workouts.finish(data.id);
      await expectLater(
        order(data, data.movableExercises.map((e) => e.id).toList()),
        throwsStateError,
      );
    },
  );

  test('same names use IDs and foreign session IDs are rejected', () async {
    var data = await done(
      await workouts.start(await seed(names: ['同名', '同名', '同名', '同名'])),
    );
    final ids = data.movableExercises.map((e) => e.id).toList();
    data = await order(data, [ids[1], ids[0], ids[2]]);
    expect(data.currentExercise.id, ids[1]);
    await workouts.finish(data.id);
    final another = await workouts.start(await seed());
    await expectLater(
      order(another, [
        data.exercises.first.id,
        ...another.movableExercises.skip(1).map((e) => e.id),
      ]),
      throwsArgumentError,
    );
  });

  test(
    'equal timestamp undo follows submissions across reordered actions',
    () async {
      var data = await done(await workouts.start(await seed(sets: [1, 1, 1])));
      final ids = data.movableExercises.map((e) => e.id).toList();
      data = await order(data, ids.reversed.toList());
      data = await done(data); // C has a larger original set ID.
      data = await done(data); // B is the actual most recent completion.
      expect(data.allSetsCompleted, true);
      expect(
        data.exercises.map((e) => e.sets.single.completedAt).toSet().length,
        1,
      );
      data = await workouts.undoLastSet(data.id);
      expect(data.currentExercise.name, 'B');
      expect(data.exercises[1].completed, true);
      data = await workouts.undoLastSet(data.id);
      expect(data.currentExercise.name, 'C');
      expect(data.exercises.map((e) => e.name), ['A', 'C', 'B']);
      data = await workouts.undoLastSet(data.id);
      expect(data.currentExercise.name, 'A');
      data = await order(
        data,
        data.movableExercises.map((e) => e.id).toList().reversed.toList(),
      );
      expect(data.currentExercise.name, 'B');
    },
  );

  test('continuous cross-action undo and redo preserves new queue', () async {
    var data = await workouts.start(await seed(sets: [2, 2, 2]));
    data = await done(data);
    data = await done(data);
    data = await order(
      data,
      data.movableExercises.map((e) => e.id).toList().reversed.toList(),
    );
    data = await done(data);
    data = await done(data);
    for (var i = 0; i < 3; i++) {
      data = await workouts.undoLastSet(data.id);
    }
    expect(data.currentExercise.name, 'A');
    expect(data.currentSetNumber, 2);
    data = await done(data);
    expect(data.currentExercise.name, 'C');
    data = await done(data);
    data = await done(data);
    expect(data.currentExercise.name, 'B');
    expect(data.completedSets, 4);
  });

  test('finish skips already completed later slots', () async {
    var data = await done(await workouts.start(await seed(sets: [1, 1, 1, 1])));
    final c = data.exercises[2];
    await database.db.update(
      'session_sets',
      {'completed_at': now.millisecondsSinceEpoch, 'completed_sequence': 2},
      where: 'session_exercise_id = ?',
      whereArgs: [c.id],
    );
    data = (await workouts.getSession(data.id))!;
    data = await done(data);
    expect(data.currentExercise.name, 'D');
    expect(data.nextExercise, isNull);
    data = await done(data);
    expect(data.allSetsCompleted, true);
  });

  test(
    'session edits and plan deletion retain saved order and stats',
    () async {
      final plan = await seed();
      var data = await done(await workouts.start(plan));
      final ids = data.movableExercises.map((e) => e.id).toList();
      data = await order(data, [ids[1], ids[0], ids[2]]);
      data = await workouts.updateExercise(
        data.id,
        ids[0],
        targetSets: 3,
        restBetweenSetsSeconds: 30,
        restAfterExerciseSeconds: 60,
      );
      expect(data.currentExercise.name, 'C');
      expect((await plans.getPlan(plan))!.exercises[1].targetSets, 2);
      data = await done(data);
      now = now.add(const Duration(minutes: 5));
      final partial = await workouts.finish(data.id);
      expect(partial.durationSeconds, 300);
      expect(partial.completedSets, 2);
      final next = await workouts.start(plan);
      expect(next.exercises.map((e) => e.name), ['A', 'B', 'C', 'D']);
      await workouts.discard(next.id);
      await plans.deletePlan(plan);
      final saved = (await workouts.listHistory()).single;
      expect(saved.exercises.map((e) => e.name), ['A', 'C', 'B', 'D']);
      expect(saved.completedSets, 2);
      final stats = HistoryStats.calculate(
        [saved],
        now: now,
        month: DateTime(2026, 10),
      );
      expect(stats.monthCount, 1);
      expect(stats.monthCompletedSets, 2);
      expect(stats.monthDurationSeconds, 300);
    },
  );

  test(
    'one remaining candidate or all-completed session has no reorder',
    () async {
      var data = await workouts.start(
        await seed(sets: [1, 1], names: ['A', 'B']),
      );
      data = await done(data);
      expect(data.canReorder, false);
      await expectLater(
        order(data, data.movableExercises.map((e) => e.id).toList()),
        throwsArgumentError,
      );
      data = await done(data);
      expect(data.canReorder, false);
    },
  );
}
