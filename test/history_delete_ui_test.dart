import 'package:intl/intl.dart';
import 'package:settrace/l10n/generated/app_localizations.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/widgets/app_card.dart';
import 'package:settrace/features/history/history_page.dart';
import 'package:settrace/features/workout/workout_models.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ControlledHistory extends WorkoutRepository {
  ControlledHistory(super.db);
  List<WorkoutSessionData> records = [];
  int deleteCalls = 0, loadCalls = 0;
  bool failNextDelete = false, failNextLoad = false;
  Completer<void>? deleteGate, nextLoadGate;

  @override
  Future<List<WorkoutSessionData>> listHistory() async {
    loadCalls++;
    final snapshot = [...records];
    final gate = nextLoadGate;
    nextLoadGate = null;
    final fail = failNextLoad;
    failNextLoad = false;
    if (gate != null) await gate.future;
    if (fail) throw StateError('test load failure');
    return snapshot;
  }

  @override
  Future<void> deleteHistory(int sessionId) async {
    deleteCalls++;
    if (deleteGate != null) await deleteGate!.future;
    if (failNextDelete) {
      failNextDelete = false;
      throw StateError('test delete failure');
    }
    if (!records.any((s) => s.id == sessionId)) {
      throw const HistoryDeleteException(HistoryDeleteFailure.notFound);
    }
    records = records.where((s) => s.id != sessionId).toList();
  }
}

WorkoutSessionData sample(int id, DateTime day, int duration, int sets) {
  final ended = DateTime(day.year, day.month, day.day, 12, id);
  final date =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  return WorkoutSessionData(
    id: id,
    planName: '训练 $id',
    startedAt: ended.subtract(Duration(seconds: duration)),
    endedAt: ended,
    startedLocalDate: date,
    durationSeconds: duration,
    status: 'completed',
    currentExerciseOrder: 1,
    currentSetNumber: 1,
    exercises: [
      SessionExercise(
        id: id,
        name: '动作 $id',
        sortOrder: 1,
        targetSets: sets + 1,
        restBetweenSetsSeconds: 0,
        restAfterExerciseSeconds: 0,
        sets: [
          for (var n = 1; n <= sets + 1; n++)
            SessionSet(id: n, number: n, completedAt: n <= sets ? ended : null),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late ControlledHistory workouts;
  final now = DateTime.now();
  final oldMonth = DateTime(now.year, now.month - 1, 15);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    workouts = ControlledHistory(db);
    workouts.records = [
      sample(2, now, 1800, 6),
      sample(1, now, 600, 2),
      sample(3, oldMonth, 1200, 4),
    ];
  });
  tearDown(() async => db.close());

  Widget app({int revision = 0, bool dark = false, double scale = 1}) =>
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: HistoryPage(workouts: workouts, revision: revision),
        ),
      );

  Future<void> mount(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(app(dark: dark, scale: scale));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {int id = 2}) async {
    final card = find.byKey(ValueKey('history-session-$id'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  Future<void> confirmDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('训练记录操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除记录'));
    await tester.pumpAndSettle();
    expect(find.text('删除这条训练记录？'), findsOneWidget);
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await confirmDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
  }

  void stat(String label, String value) {
    final card = find.ancestor(
      of: find.text(label),
      matching: find.byType(AppCard),
    );
    expect(
      find.descendant(of: card, matching: find.text(value)),
      findsOneWidget,
    );
  }

  for (final cancel in ['button', 'barrier', 'back']) {
    testWidgets('confirmation $cancel never deletes or changes statistics', (
      tester,
    ) async {
      await mount(tester);
      await open(tester);
      await confirmDialog(tester);
      expect(find.textContaining('训练 2\n'), findsOneWidget);
      expect(find.textContaining('删除后无法恢复'), findsOneWidget);
      if (cancel == 'button') {
        await tester.tap(find.widgetWithText(TextButton, '取消'));
      } else if (cancel == 'barrier') {
        await tester.tapAt(const Offset(4, 100));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.text('训练详情'), findsOneWidget);
      expect(workouts.deleteCalls, 0);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(workouts.loadCalls, 1);
      stat('本月训练', '2');
      stat('所选月份时长', '40 分钟');
    });
  }

  testWidgets(
    'success removes one same-day record and updates every statistic',
    (tester) async {
      await mount(tester);
      await open(tester);
      await confirmDelete(tester);
      expect(find.text('训练详情'), findsNothing);
      expect(find.byKey(const ValueKey('history-session-2')), findsNothing);
      expect(find.byKey(const ValueKey('history-session-1')), findsOneWidget);
      expect(find.text('记录已删除'), findsOneWidget);
      stat('本周训练', '1');
      stat('本月训练', '1');
      stat('所选月份时长', '10 分钟');
      stat('所选月份完成组', '2');
      expect(find.text('最近训练：训练 1 · 10 分钟'), findsOneWidget);
      expect(workouts.deleteCalls, 1);
    },
  );

  testWidgets(
    'deleting selected historical month retains month and empty state',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('上个月'));
      await tester.pumpAndSettle();
      await open(tester, id: 3);
      await confirmDelete(tester);
      expect(
        find.text(DateFormat.yMMMM('zh').format(oldMonth)),
        findsOneWidget,
      );
      expect(find.text('这个月还没有训练记录'), findsOneWidget);
      stat('本月训练', '2');
      stat('所选月份时长', '0 分钟');
      stat('所选月份完成组', '0');
      expect(find.text('最近训练：训练 2 · 30 分钟'), findsOneWidget);
    },
  );

  testWidgets('last deletion clears recent training and all counters', (
    tester,
  ) async {
    workouts.records = [workouts.records.first];
    await mount(tester);
    await open(tester);
    await confirmDelete(tester);
    expect(find.text('这个月还没有训练记录'), findsOneWidget);
    expect(find.text('最近训练：暂无'), findsOneWidget);
    for (final label in ['本周训练', '本月训练', '所选月份完成组']) {
      stat(label, '0');
    }
    stat('所选月份时长', '0 分钟');
  });

  testWidgets('delete failure preserves details and permits confirmed retry', (
    tester,
  ) async {
    workouts.failNextDelete = true;
    await mount(tester);
    await open(tester);
    await confirmDelete(tester);
    expect(find.text('删除失败，请重试。'), findsOneWidget);
    expect(find.text('动作 2'), findsOneWidget);
    expect(workouts.records.length, 3);
    await tester.tap(find.text('重试删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(find.text('训练详情'), findsNothing);
    expect(workouts.deleteCalls, 2);
  });

  testWidgets(
    'duplicate confirmation and back during write do not repeat or exit',
    (tester) async {
      final gate = Completer<void>();
      workouts.deleteGate = gate;
      await mount(tester);
      await open(tester);
      await confirmDialog(tester);
      final action = tester
          .widget<TextButton>(find.widgetWithText(TextButton, '删除'))
          .onPressed!;
      action();
      action();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(workouts.deleteCalls, 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('训练详情'), findsOneWidget);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        false,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('训练详情'), findsNothing);
      expect(workouts.deleteCalls, 1);
    },
  );

  testWidgets(
    'missing target refreshes without claiming a successful deletion',
    (tester) async {
      await mount(tester);
      await open(tester);
      workouts.records.removeWhere((s) => s.id == 2);
      await confirmDelete(tester);
      expect(find.text('记录已不存在'), findsOneWidget);
      expect(find.text('记录已删除'), findsNothing);
      expect(find.byKey(const ValueKey('history-session-2')), findsNothing);
    },
  );

  testWidgets(
    'load failure after committed delete stays removed and only retries loading',
    (tester) async {
      await mount(tester);
      await open(tester);
      workouts.failNextLoad = true;
      await confirmDelete(tester);
      expect(find.text('记录已删除，刷新失败，请重试'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-session-2')), findsNothing);
      stat('所选月份时长', '10 分钟');
      await tester.ensureVisible(find.text('重试刷新'));
      await tester.tap(find.text('重试刷新'));
      await tester.pumpAndSettle();
      expect(find.text('记录已删除，刷新失败，请重试'), findsNothing);
      expect(workouts.deleteCalls, 1);
    },
  );

  testWidgets('stale pre-delete load cannot resurrect a deleted record', (
    tester,
  ) async {
    await mount(tester);
    final gate = Completer<void>();
    workouts.nextLoadGate = gate;
    await tester.pumpWidget(app(revision: 1));
    await tester.pump();
    expect(workouts.loadCalls, 2);
    await open(tester);
    await confirmDelete(tester);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-session-2')), findsNothing);
    stat('本月训练', '1');
  });

  testWidgets('initial load failure offers refresh retry', (tester) async {
    workouts.failNextLoad = true;
    await mount(tester);
    expect(find.text('记录加载失败，请重试'), findsOneWidget);
    await tester.tap(find.text('重试刷新'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-session-2')), findsOneWidget);
  });

  for (final width in [360.0, 430.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'confirmation remains usable width=$width dark=$dark scale=1.3',
        (tester) async {
          tester.view.resetPhysicalSize();
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 800);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await mount(tester, dark: dark, scale: 1.3);
          await open(tester);
          expect(
            tester.getSize(find.byTooltip('训练记录操作')).width,
            greaterThanOrEqualTo(48),
          );
          await confirmDialog(tester);
          final button = find.widgetWithText(TextButton, '删除');
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
          await tester.tap(find.widgetWithText(TextButton, '取消'));
          await tester.pumpAndSettle();
          expect(workouts.deleteCalls, 0);
        },
      );
    }
  }
}
