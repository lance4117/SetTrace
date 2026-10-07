import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_models.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/workout/workout_page.dart';
import 'package:settrace/features/history/history_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ControlledWorkouts extends WorkoutRepository {
  ControlledWorkouts(super.db);
  bool holdNextRead = false, readCaptured = false, failNextSave = false;
  Completer<void>? readGate, saveGate;
  int saveCalls = 0;
  @override
  Future<WorkoutSessionData?> getSession(int id) async {
    final data = await super.getSession(id);
    if (holdNextRead) {
      holdNextRead = false;
      readCaptured = true;
      await readGate!.future;
    }
    return data;
  }

  @override
  Future<WorkoutSessionData> reorder(
    int id,
    List<int> ids, {
    required String expectedToken,
  }) async {
    saveCalls++;
    if (saveGate != null) await saveGate!.future;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('模拟保存失败');
    }
    return super.reorder(id, ids, expectedToken: expectedToken);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late AppDatabase database;
  late PlanRepository plans;
  late ControlledWorkouts workouts;
  late int planId;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settrace_order_widget_');
    database = await AppDatabase.open(
      filePath: p.join(directory.path, 'db'),
      factory: databaseFactoryFfi,
    );
    plans = PlanRepository(database.db);
    workouts = ControlledWorkouts(database.db);
    planId = await plans.createPlan('训练');
    for (final name in ['A', 'B', 'C']) {
      await plans.addExercise(
        planId: planId,
        name: name,
        targetSets: 2,
        restBetweenSetsSeconds: 0,
        restAfterExerciseSeconds: 0,
      );
    }
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });
  Future<void> flush(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<WorkoutSessionData> seed(
    WidgetTester tester, {
    bool finishA = true,
    int after = 0,
  }) async {
    return (await tester.runAsync(() async {
      final plan = (await plans.getPlan(planId))!;
      if (after > 0) {
        final a = plan.exercises.first;
        await plans.updateExercise(
          id: a.id,
          name: 'A',
          targetSets: 2,
          restBetweenSetsSeconds: 0,
          restAfterExerciseSeconds: after,
        );
      }
      var data = await workouts.start(planId);
      if (finishA) {
        for (var i = 0; i < 2; i++) {
          data = await workouts.completeSet(
            data.id,
            expectedExerciseId: data.currentExercise.id,
            expectedSetNumber: data.currentSetNumber,
          );
        }
      }
      return data;
    }))!;
  }

  Future<void> mount(
    WidgetTester tester,
    WorkoutSessionData data, {
    ThemeData? theme,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: WorkoutPage(workouts: workouts, sessionId: data.id),
      ),
    );
    addTearDown(() async {
      if (workouts.readGate != null && !workouts.readGate!.isCompleted) {
        workouts.readGate!.complete();
      }
      if (workouts.saveGate != null && !workouts.saveGate!.isCompleted) {
        workouts.saveGate!.complete();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await flush(tester);
    });
    await flush(tester);
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.ensureVisible(find.text('更换下一动作'));
    await tester.tap(find.text('更换下一动作'));
    await flush(tester);
  }

  Future<void> openFull(WidgetTester tester) async {
    await tester.tap(find.text('全部动作与编辑'));
    await flush(tester);
    await tester.tap(find.text('调整剩余顺序'));
    await flush(tester);
  }

  Future<void> moveCBeforeB(
    WidgetTester tester,
    WorkoutSessionData data,
  ) async {
    final c = data.exercises[2].id, b = data.exercises[1].id;
    final start = tester.getCenter(find.byKey(ValueKey('drag-$c')));
    final end = tester.getCenter(find.byKey(ValueKey('order-row-$b')));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, -25));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(Offset(start.dx, end.dy - 45));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.moveBy(const Offset(0, -5));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await flush(tester);
  }

  testWidgets(
    'zero-rest current B changes to C without extra completion or plan edits',
    (tester) async {
      final data = await seed(tester);
      await mount(tester, data);
      await choose(tester);
      expect(find.text('替换当前待练动作，不记录额外完成组。'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('select-next-${data.exercises[2].id}')),
      );
      await flush(tester);
      final saved = (await tester.runAsync(
        () => workouts.getSession(data.id),
      ))!;
      expect(saved.currentExercise.name, 'C');
      expect(saved.completedSets, 2);
      expect(saved.exercises.map((e) => e.name), ['A', 'C', 'B']);
      expect(
        (await tester.runAsync(() => plans.getPlan(planId)))!.exercises
            .map((e) => e.name),
        ['A', 'B', 'C'],
      );
    },
  );

  testWidgets('rest-page chooser preserves deadline and next-group label', (
    tester,
  ) async {
    final data = await seed(tester, after: 150);
    await mount(tester, data);
    await choose(tester);
    await tester.tap(
      find.byKey(ValueKey('select-next-${data.exercises[2].id}')),
    );
    await flush(tester);
    final saved = (await tester.runAsync(() => workouts.getSession(data.id)))!;
    expect(saved.restEndAt, data.restEndAt);
    expect(find.text('下一组：C · 1 / 2'), findsOneWidget);
  });

  testWidgets('partial current action stays pinned and locks its drag handle', (
    tester,
  ) async {
    var data = await seed(tester, finishA: false);
    data = (await tester.runAsync(
      () => workouts.completeSet(
        data.id,
        expectedExerciseId: data.currentExercise.id,
        expectedSetNumber: 1,
      ),
    ))!;
    await mount(tester, data);
    await choose(tester);
    expect(find.text('当前动作做完后练；当前组数和休息保持。'), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey('select-next-${data.exercises[2].id}')),
    );
    await flush(tester);
    final saved = (await tester.runAsync(() => workouts.getSession(data.id)))!;
    expect(saved.currentExercise.name, 'A');
    expect(saved.currentSetNumber, 2);
    await openFull(tester);
    expect(find.byKey(ValueKey('drag-${data.exercises[0].id}')), findsNothing);
    expect(find.text('进行中 · 1 / 2 组'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await flush(tester);
  });

  testWidgets('full drag cancellation leaves persisted queue unchanged', (
    tester,
  ) async {
    final data = await seed(tester);
    await mount(tester, data);
    await openFull(tester);
    expect(
      find.byKey(ValueKey('drag-${data.exercises.first.id}')),
      findsNothing,
    );
    await moveCBeforeB(tester, data);
    expect(
      tester
          .getTopLeft(find.byKey(ValueKey('order-row-${data.exercises[2].id}')))
          .dy,
      lessThan(
        tester
            .getTopLeft(
              find.byKey(ValueKey('order-row-${data.exercises[1].id}')),
            )
            .dy,
      ),
    );
    await tester.tap(find.text('取消'));
    await flush(tester);
    expect(
      (await tester.runAsync(() => workouts.getSession(data.id)))!.reorderToken,
      data.reorderToken,
    );
  });

  testWidgets('full drag save persists only candidate order', (tester) async {
    final data = await seed(tester);
    await mount(tester, data);
    await openFull(tester);
    await moveCBeforeB(tester, data);
    await tester.tap(find.text('保存顺序'));
    await flush(tester);
    expect(
      (await tester.runAsync(() => workouts.getSession(data.id)))!.exercises
          .map((e) => e.name),
      ['A', 'C', 'B'],
    );
  });

  testWidgets(
    'stale draft fails, reload allows retry without partial sorting',
    (tester) async {
      final data = await seed(tester);
      await mount(tester, data);
      await openFull(tester);
      await tester.runAsync(
        () => workouts.completeSet(
          data.id,
          expectedExerciseId: data.currentExercise.id,
          expectedSetNumber: 1,
        ),
      );
      await tester.tap(find.text('保存顺序'));
      await flush(tester);
      expect(find.textContaining('训练状态已变化'), findsOneWidget);
      expect(
        (await tester.runAsync(() => workouts.getSession(data.id)))!
            .currentSetNumber,
        2,
      );
      await tester.tap(find.text('重新加载'));
      await flush(tester);
      expect(
        find.byKey(ValueKey('drag-${data.exercises[1].id}')),
        findsNothing,
      );
      // Only C is now movable: save is disabled rather than applying stale B/C order.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '保存顺序'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('取消'));
      await flush(tester);
    },
  );

  testWidgets('save failure retry and double taps submit once', (tester) async {
    final data = await seed(tester);
    await mount(tester, data);
    await choose(tester);
    workouts.failNextSave = true;
    await tester.tap(
      find.byKey(ValueKey('select-next-${data.exercises[2].id}')),
    );
    await flush(tester);
    expect(find.textContaining('模拟保存失败'), findsOneWidget);
    expect(
      (await tester.runAsync(() => workouts.getSession(data.id)))!.reorderToken,
      data.reorderToken,
    );
    workouts.saveGate = Completer<void>();
    final choice = find.byKey(ValueKey('select-next-${data.exercises[2].id}'));
    await tester.tap(choice);
    await tester.tap(choice);
    expect(workouts.saveCalls, 2); // one failed attempt, one pending retry
    workouts.saveGate!.complete();
    await flush(tester);
    expect(
      (await tester.runAsync(() => workouts.getSession(data.id)))!
          .currentExercise
          .name,
      'C',
    );
  });

  testWidgets('sorting invalidates an older delayed lifecycle read', (
    tester,
  ) async {
    final data = await seed(tester);
    await mount(tester, data);
    workouts.readGate = Completer<void>();
    workouts.holdNextRead = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flush(tester);
    expect(workouts.readCaptured, true);
    await choose(tester);
    await tester.tap(
      find.byKey(ValueKey('select-next-${data.exercises[2].id}')),
    );
    await flush(tester);
    workouts.readGate!.complete();
    await flush(tester);
    final stored = (await tester.runAsync(() => workouts.getSession(data.id)))!;
    expect(stored.currentExercise.name, 'C');
    await tester.ensureVisible(find.text('完成本组'));
    await tester.tap(find.text('完成本组'));
    await flush(tester);
    expect(
      (await tester.runAsync(() => workouts.getSession(data.id)))!
          .exercises[1]
          .completedSets,
      1,
    );
    expect(find.textContaining('操作失败'), findsNothing);
  });

  testWidgets('existing exercise editor remains accessible', (tester) async {
    final data = await seed(tester);
    await mount(tester, data);
    await tester.tap(find.text('全部动作与编辑'));
    await flush(tester);
    await tester.tap(find.widgetWithText(ListTile, 'B'));
    await flush(tester);
    expect(find.text('本次编辑 · B'), findsOneWidget);
  });

  testWidgets('fewer than two candidates hides selection and sorting entry', (
    tester,
  ) async {
    var data = await seed(tester);
    data = (await tester.runAsync(
      () => workouts.completeSet(
        data.id,
        expectedExerciseId: data.currentExercise.id,
        expectedSetNumber: 1,
      ),
    ))!;
    await mount(tester, data);
    expect(find.text('更换下一动作'), findsNothing);
    await tester.tap(find.text('全部动作与编辑'));
    await flush(tester);
    expect(find.text('调整剩余顺序'), findsNothing);
    expect(find.widgetWithText(ListTile, 'B'), findsOneWidget);
  });

  for (final complete in [false, true]) {
    testWidgets(
      'history preserves final order and groups for complete=$complete',
      (tester) async {
        var data = await seed(tester);
        data = (await tester.runAsync(
          () => workouts.reorder(
            data.id,
            data.movableExercises.map((e) => e.id).toList().reversed.toList(),
            expectedToken: data.reorderToken,
          ),
        ))!;
        if (complete) {
          data = (await tester.runAsync(() async {
            var next = data;
            while (!next.allSetsCompleted) {
              next = await workouts.completeSet(
                next.id,
                expectedExerciseId: next.currentExercise.id,
                expectedSetNumber: next.currentSetNumber,
              );
            }
            return next;
          }))!;
        }
        data = (await tester.runAsync(() => workouts.finish(data.id)))!;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: HistoryDetailPage(session: data, workouts: workouts),
          ),
        );
        await tester.pump();
        expect(
          tester.getTopLeft(find.text('A')).dy,
          lessThan(tester.getTopLeft(find.text('C')).dy),
        );
        await tester.ensureVisible(find.text('B'));
        expect(
          tester.getTopLeft(find.text('C')).dy,
          lessThan(tester.getTopLeft(find.text('B')).dy),
        );
        expect(
          find.text(complete ? '完成 2 / 2 组' : '完成 0 / 2 组'),
          complete ? findsNWidgets(3) : findsNWidgets(2),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final width in [360.0, 430.0]) {
    for (final dark in [false, true]) {
      testWidgets('${width}dp scaled sorting stays readable in dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = await seed(tester);
        await mount(
          tester,
          data,
          theme: dark ? AppTheme.dark : AppTheme.light,
          scale: 1.3,
        );
        await openFull(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('保存顺序'), findsOneWidget);
        await tester.tap(find.text('取消'));
        await flush(tester);
      });
    }
  }
}
