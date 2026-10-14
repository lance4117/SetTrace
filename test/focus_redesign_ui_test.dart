import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/widgets/step_picker.dart';
import 'package:settrace/core/widgets/app_button.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_models.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/plans/plans_page.dart';
import 'package:settrace/features/workout/workout_page.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ControlledPlans extends PlanRepository {
  ControlledPlans(super.db);
  int calls = 0;
  bool fail = false, failRead = false;
  Completer<void>? gate;
  @override
  Future<int> createPlan(String name) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('write unavailable');
    return super.createPlan(name);
  }

  @override
  Future<List<WorkoutPlan>> listPlans() async {
    if (failRead) throw StateError('read unavailable');
    return super.listPlans();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late AppDatabase database;
  late ControlledPlans plans;
  late WorkoutRepository workouts;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('settrace_focus_ui_');
    database = await AppDatabase.open(
      filePath: '${directory.path}/db',
      factory: databaseFactoryFfi,
    );
    plans = ControlledPlans(database.db);
    workouts = WorkoutRepository(database.db);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });
  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    // SQLite work happens on a real isolate; fake-time settling cannot finish it.
    for (
      var i = 0;
      i < 100 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pumpAndSettle();
  }

  Widget wrap(
    Widget child, {
    bool dark = false,
    Locale locale = const Locale('en'),
    double scale = 1,
  }) => MaterialApp(
    theme: dark ? AppTheme.dark : AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
  testWidgets(
    'naming retains invalid and failed input, submits once, allows duplicate',
    (t) async {
      await t.runAsync(() => plans.createPlan('Duplicate'));
      plans.calls = 0;
      await t.pumpWidget(
        wrap(
          PlansPage(
            plans: plans,
            workouts: workouts,
            onOpenWorkout: (_) async {},
          ),
        ),
      );
      await flush(t);
      await t.tap(find.text('＋ New'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(plans.calls, 0);
      expect(
        t.widget<TextField>(find.byType(TextField)).decoration!.errorText,
        isNotNull,
      );
      await t.enterText(find.byType(TextField), 'Duplicate');
      plans.fail = true;
      plans.gate = Completer<void>();
      await t.tap(find.text('Save'));
      await t.pump();
      expect(
        t
            .widgetList<TextButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextButton),
              ),
            )
            .last
            .onPressed,
        isNull,
      );
      plans.gate!.complete();
      await flush(t);
      expect(plans.calls, 1);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'Duplicate',
      );
      expect(
        t.widget<TextField>(find.byType(TextField)).decoration!.errorText,
        isNotNull,
      );
      plans.fail = false;
      plans.gate = null;
      await t.tap(find.text('Save'));
      await flush(t);
      expect(find.byType(AlertDialog), findsNothing);
      final items = (await t.runAsync(plans.listPlans))!;
      expect(items.where((p) => p.name == 'Duplicate').length, 2);
      expect(plans.calls, 2);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'successful naming followed by failed refresh does not create again',
    (t) async {
      await t.pumpWidget(
        wrap(
          PlansPage(
            plans: plans,
            workouts: workouts,
            onOpenWorkout: (_) async {},
          ),
        ),
      );
      await flush(t);
      await t.tap(find.text('＋ New'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Saved once');
      plans.failRead = true;
      await t.tap(find.text('Save'));
      await flush(t);
      expect(find.byType(AlertDialog), findsNothing);
      expect(plans.calls, 1);
      plans.failRead = false;
      await t.tap(find.text('Retry'));
      await flush(t);
      expect(plans.calls, 1);
      expect(find.text('Saved once'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final width in [360.0, 430.0]) {
    testWidgets('100 sets at $width keep primary reachable while scrolling', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final session = (await t.runAsync(() async {
        final id = await plans.createPlan('Plan');
        await plans.addExercise(
          planId: id,
          name: 'Long exercise name that wraps to multiple lines',
          targetSets: 100,
          restBetweenSetsSeconds: 0,
          restAfterExerciseSeconds: 0,
        );
        return await workouts.start(id);
      }))!;
      await t.pumpWidget(
        wrap(
          WorkoutPage(workouts: workouts, sessionId: session.id),
          scale: 1.6,
        ),
      );
      await flush(t);
      final action = find.byKey(const ValueKey('workout-primary'));
      final position = t.getTopLeft(action);
      final scrolling = find
          .descendant(
            of: find.byKey(const ValueKey('workout-body')),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.drag(scrolling, const Offset(0, -400));
      await t.pumpAndSettle();
      expect(t.getTopLeft(action), position);
      expect(position.dy, lessThan(800));
      expect(t.getBottomRight(action).dy, lessThanOrEqualTo(800));
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
      expect(t.takeException(), isNull);
      await t.tap(action);
      await flush(t);
      final latest = (await t.runAsync(() => workouts.getSession(session.id)))!;
      expect(latest.completedSets, 1);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'default move and destructive dialogs preserve active snapshots',
    (t) async {
      final id = (await t.runAsync(() async {
        final id = await plans.createPlan('Snapshot plan');
        for (final name in ['A', 'B']) {
          await plans.addExercise(
            planId: id,
            name: name,
            targetSets: 2,
            restBetweenSetsSeconds: 0,
            restAfterExerciseSeconds: 0,
          );
        }
        await workouts.start(id);
        return id;
      }))!;
      await t.pumpWidget(
        wrap(
          PlansPage(
            plans: plans,
            workouts: workouts,
            onOpenWorkout: (_) async {},
          ),
        ),
      );
      await flush(t);
      await t.tap(find.text('Snapshot plan'));
      await flush(t);
      await t.tap(find.byTooltip('Move B up'));
      await flush(t);
      final moved = (await t.runAsync(() => plans.getPlan(id)))!;
      expect(moved.exercises.map((e) => e.name), ['B', 'A']);
      await t.tap(find.text('B'));
      await flush(t);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await t.pumpAndSettle();
      expect((await t.runAsync(() => plans.getPlan(id)))!.exercises.length, 2);
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await flush(t);
      expect(
        (await t.runAsync(() => plans.getPlan(id)))!.exercises
            .map((e) => e.name),
        ['A'],
      );
      await t.tap(find.byType(PopupMenuButton<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete plan'));
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await flush(t);
      expect(await t.runAsync(() => plans.getPlan(id)), isNull);
      final active = (await t.runAsync(workouts.getActive))!;
      expect(active.exercises.map((e) => e.name), ['A', 'B']);
      expect(find.text('Resume workout'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'non-current session editor rejects stale draft and preserves selected identity',
    (t) async {
      final data = (await t.runAsync(() async {
        final id = await plans.createPlan('Selected identity');
        for (final name in ['A', 'B', 'C']) {
          await plans.addExercise(
            planId: id,
            name: name,
            targetSets: 4,
            restBetweenSetsSeconds: 0,
            restAfterExerciseSeconds: 0,
          );
        }
        var s = await workouts.start(id);
        for (var i = 0; i < 2; i++) {
          s = await workouts.completeSet(
            s.id,
            expectedExerciseId: s.currentExercise.id,
            expectedSetNumber: s.currentSetNumber,
          );
        }
        return s;
      }))!;
      final l = lookupAppLocalizations(const Locale('en'));
      await t.pumpWidget(wrap(const SizedBox()));
      t
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => SessionExerciseEditorPage(
                workouts: workouts,
                sessionId: data.id,
                exercise: data.exercises[1],
                expectedToken: data.reorderToken,
              ),
            ),
          );
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.add).first);
      await t.pumpAndSettle();
      expect(t.widget<StepPicker>(find.byType(StepPicker).first).value, 5);
      await t.runAsync(
        () => workouts.completeSet(
          data.id,
          expectedExerciseId: data.currentExercise.id,
          expectedSetNumber: data.currentSetNumber,
        ),
      );
      await t.tap(find.text(l.saveSessionConfig));
      await flush(t);
      expect(t.widget<StepPicker>(find.byType(StepPicker).first).value, 5);
      expect(t.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
      await t.scrollUntilVisible(
        find.text(l.reload),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text(l.reload));
      await flush(t);
      expect(t.widget<StepPicker>(find.byType(StepPicker).first).value, 4);
      await t.tap(find.byIcon(Icons.add).first);
      await t.pumpAndSettle();
      await t.tap(find.text(l.saveSessionConfig));
      await flush(t);
      final saved = (await t.runAsync(() => workouts.getSession(data.id)))!;
      expect(saved.exercises.map((e) => e.targetSets), [4, 5, 4]);
      expect(saved.completedSets, 3);
      final original = (await t.runAsync(plans.listPlans))!.single;
      expect(original.exercises.map((e) => e.targetSets), [4, 4, 4]);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('home keyboard order follows new, menu, resume, then plan', (
    t,
  ) async {
    await t.runAsync(() async {
      final id = await plans.createPlan('Keyboard plan');
      await plans.addExercise(
        planId: id,
        name: 'Press',
        targetSets: 4,
        restBetweenSetsSeconds: 0,
        restAfterExerciseSeconds: 0,
      );
      await workouts.start(id);
    });
    await t.pumpWidget(
      wrap(
        PlansPage(
          plans: plans,
          workouts: workouts,
          onOpenWorkout: (_) async {},
        ),
      ),
    );
    await flush(t);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(Focus.of(t.element(find.text('＋ New'))).hasPrimaryFocus, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(
      Focus.of(t.element(find.text('Resume workout'))).hasPrimaryFocus,
      isTrue,
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(
      Focus.of(t.element(find.text('Keyboard plan'))).hasPrimaryFocus,
      isTrue,
    );
    await t.pumpWidget(const SizedBox());
  });
}
