import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/workout/workout_models.dart';
import 'package:settrace/features/history/history_stats.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase database;
  late WorkoutRepository repo;
  late PlanRepository plans;
  var now = DateTime.utc(2026, 10, 13);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('settrace_skip_');
    database = await AppDatabase.open(
      filePath: '${dir.path}/workout.db',
      factory: databaseFactoryFfi,
    );
    plans = PlanRepository(database.db);
    repo = WorkoutRepository(database.db, clock: () => now);
  });
  tearDown(() async {
    await database.close();
    await dir.delete(recursive: true);
  });
  Future<WorkoutSessionData> seed({int rest = 0, int actions = 2}) async {
    final id = await plans.createPlan('Plan');
    for (var i = 0; i < actions; i++) {
      await plans.addExercise(
        planId: id,
        name: 'Exercise $i',
        targetSets: 4,
        restBetweenSetsSeconds: rest,
        restAfterExerciseSeconds: 60,
      );
    }
    return repo.start(id);
  }

  Future<WorkoutSessionData> done(WorkoutSessionData s) => repo.completeSet(
    s.id,
    expectedExerciseId: s.currentExercise.id,
    expectedSetNumber: s.currentSetNumber,
  );
  Future<WorkoutSessionData> skip(WorkoutSessionData s) =>
      repo.skipRemainingSets(
        s.id,
        expectedExerciseId: s.currentExercise.id,
        expectedToken: s.reorderToken,
      );
  Future<WorkoutSessionData> restore(WorkoutSessionData s) => repo.undoLastSkip(
    s.id,
    expectedBatchId: s.lastSkipBatchId!,
    expectedToken: s.reorderToken,
  );

  test(
    '2/4 persists, cancellation and restart do not lose targets or completion',
    () async {
      var s = await seed(rest: 120);
      final plan = (await database.db.query('plans')).single['id'] as int;
      s = await done(s);
      s = await repo.skipRest(s.id);
      s = await done(s);
      final token = s;
      s = await skip(s);
      expect(s.exercises.first.completedSets, 2);
      expect(s.exercises.first.skippedSets, 2);
      expect(s.exercises.first.targetSets, 4);
      expect(s.currentExercise.name, 'Exercise 1');
      expect(s.resting, false);
      expect((await plans.getPlan(plan))!.exercises.first.targetSets, 4);
      await expectLater(skip(token), throwsStateError);
      await database.close();
      database = await AppDatabase.open(
        filePath: '${dir.path}/workout.db',
        factory: databaseFactoryFfi,
      );
      repo = WorkoutRepository(database.db, clock: () => now);
      s = (await repo.getActive())!;
      expect(s.currentExercise.name, 'Exercise 1');
      s = await restore(s);
      expect(s.currentSetNumber, 3);
      expect(s.currentExercise.pendingSets, 2);
      expect(s.currentExercise.completedSets, 2);
      expect(s.currentExercise.skippedSets, 0);
      expect(s.resting, false);
    },
  );

  test('last action can finish at 2/4, stats count only actual sets', () async {
    var s = await seed(actions: 1);
    s = await done(s);
    s = await done(s);
    s = await skip(s);
    expect(s.readyToFinish, true);
    expect(s.allSetsCompleted, false);
    expect(s.completedSets / s.totalSets, .5);
    s = await repo.finish(s.id);
    expect(s.completedSets, 2);
    expect(s.exercises.single.targetSets, 4);
    final stats = HistoryStats.calculate([s], now: now, month: now);
    expect(stats.monthCompletedSets, 2);
    expect(await repo.getActive(), isNull);
    await expectLater(restore(s), throwsStateError);
  });

  test(
    'undo skip preserves later completed sets and follows saved order',
    () async {
      var s = await seed(actions: 3);
      s = await done(s);
      s = await done(s);
      final movable = s.movableExercises.map((e) => e.id).toList();
      s = await repo.reorder(
        s.id,
        movable.reversed.toList(),
        expectedToken: s.reorderToken,
      );
      s = await skip(s);
      expect(s.currentExercise.name, 'Exercise 2');
      s = await done(s);
      s = await restore(s);
      expect(s.currentExercise.name, 'Exercise 0');
      expect(s.exercises[1].completedSets, 1);
      s = await done(s);

      s = await done(s);
      s = await repo.skipRest(s.id);
      expect(s.currentExercise.name, 'Exercise 2');
      expect(s.currentSetNumber, 2);
    },
  );

  test('undo completion retains skips even at zero completed sets', () async {
    var s = await seed();
    s = await done(s);
    s = await done(s);
    s = await skip(s);
    s = await repo.undoLastSet(s.id);
    s = await repo.undoLastSet(s.id);
    expect(s.currentExercise.completedSets, 0);
    expect(s.currentExercise.skippedSets, 2);
    expect(s.currentExercise.movable, false);
    s = await done(s);
    s = await done(s);
    expect(s.currentExercise.name, 'Exercise 1');
  });

  test(
    'zero completed / foreign / stale / edit with skips are rejected',
    () async {
      var s = await seed();
      await expectLater(skip(s), throwsStateError);
      s = await done(s);
      final old = s;
      s = await done(s);
      await expectLater(skip(old), throwsStateError);
      await expectLater(
        repo.skipRemainingSets(
          s.id,
          expectedExerciseId: s.exercises.last.id,
          expectedToken: s.reorderToken,
        ),
        throwsStateError,
      );
      s = await skip(s);
      await expectLater(
        repo.updateExercise(
          s.id,
          s.exercises.first.id,
          targetSets: 2,
          restBetweenSetsSeconds: 0,
          restAfterExerciseSeconds: 0,
        ),
        throwsStateError,
      );
      expect((await repo.getSession(s.id))!.exercises.first.targetSets, 4);
    },
  );

  test('state constraint and atomic rollback preserve all records', () async {
    var s = await seed();
    s = await done(s);
    await expectLater(
      database.db.update(
        'session_sets',
        {'skipped_at': 1},
        where: 'id = ?',
        whereArgs: [s.currentExercise.sets.first.id],
      ),
      throwsA(isA<DatabaseException>()),
    );
    await database.db.execute(
      """CREATE TRIGGER fail_skip BEFORE UPDATE ON session_sets
      WHEN NEW.skipped_at IS NOT NULL BEGIN SELECT RAISE(ABORT, 'test'); END""",
    );
    await expectLater(skip(s), throwsA(isA<DatabaseException>()));
    final after = (await repo.getSession(s.id))!;
    expect(after.reorderToken, s.reorderToken);
    expect(await database.db.query('session_skip_batches'), isEmpty);
  });
}
