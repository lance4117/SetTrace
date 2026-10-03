import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/plans/plans_page.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:settrace/features/plans/plan_transfer_pages.dart';
import 'package:settrace/features/plans/plan_transfer_platform.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakePlatform implements PlanTransferPlatform {
  String? copied, saved, clipboard, picked;
  int reads = 0, copies = 0, saves = 0;
  bool failCopy = false, failSave = false;
  Completer<void>? hold;
  @override
  Future<void> copyText(String text) async {
    copies++;
    if (failCopy) throw const PlanTransferException('复制失败，请重试');
    copied = text;
  }

  @override
  Future<String?> readClipboard() async {
    reads++;
    return clipboard;
  }

  @override
  Future<String?> pickFile() async => picked;
  @override
  Future<SavedPlanFile> saveFile(String text) async {
    saves++;
    if (hold != null) await hold!.future;
    if (failSave) throw const PlanTransferException('下载目录写入失败');
    saved = text;
    return const SavedPlanFile('actual-2.settrace.json', '下载');
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase db;
  late PlanRepository repo;
  late FakePlatform platform;
  setUp(() async {
    db = await AppDatabase.open(
      filePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    repo = PlanRepository(db.db);
    platform = FakePlatform();
  });
  tearDown(() async {
    await db.close();
  });
  String sample([String name = '练背']) => const PlanTransferCodec().encode(
    PlanTransferDocument([
      TransferPlan(
        name: name,
        exercises: [
          const TransferExercise(
            name: '下拉',
            targetSets: 4,
            restBetweenSetsSeconds: 120,
            restAfterExerciseSeconds: 150,
            defaultWeightKg: 45,
          ),
        ],
      ),
    ]),
  );
  Future<void> home(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PlansPage(
            plans: repo,
            workouts: WorkoutRepository(db.db),
            onOpenWorkout: (_) async {},
            transferPlatform: platform,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> page(
    WidgetTester tester,
    Widget widget, {
    double width = 400,
    bool dark = false,
  }) async {
    tester.view.physicalSize = Size(width, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: Size(width, 820),
            textScaler: const TextScaler.linear(1.3),
          ),
          child: child!,
        ),
        home: widget,
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'home menu works with empty plans and never reads clipboard automatically',
    (tester) async {
      await home(tester);
      expect(platform.reads, 0);
      await tester.tap(find.byTooltip('计划导入导出'));
      await settle(tester);
      await tester.tap(find.text('导出计划'));
      await settle(tester);
      expect(find.text('没有可导出的计划'), findsOneWidget);
      expect(platform.saves, 0);
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byTooltip('计划导入导出'));
      await settle(tester);
      await tester.tap(find.text('导入计划'));
      await settle(tester);
      expect(platform.reads, 0);
      await tester.tap(find.text('粘贴'));
      await settle(tester);
      expect(platform.reads, 1);
      expect(find.textContaining('剪贴板没有'), findsOneWidget);
      expect(await tester.runAsync(repo.listPlans), isEmpty);
    },
  );
  testWidgets(
    'selection, both channels, errors and busy duplicate prevention',
    (tester) async {
      await tester.runAsync(() => repo.createPlan('练背'));
      await tester.runAsync(() => repo.createPlan('练腿'));
      await page(tester, PlanExportPage(plans: repo, platform: platform));
      expect(find.text('已选 2 个计划'), findsOneWidget);
      await tester.tap(find.text('取消全选'));
      await settle(tester);
      expect(
        find.widgetWithText(FilledButton, '导出到文件').evaluate().single.widget
            is FilledButton,
        isTrue,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '导出到文件'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('练背'));
      await settle(tester);
      expect(find.text('已选 1 个计划'), findsOneWidget);
      await tester.tap(find.text('复制到剪贴板'));
      await settle(tester);
      expect(jsonDecode(platform.copied!)['plans'].length, 1);
      await tester.tap(find.text('导出到文件'));
      await settle(tester);
      expect(
        jsonDecode(platform.saved!)['plans'],
        jsonDecode(platform.copied!)['plans'],
      );
      expect(find.textContaining('actual-2.settrace.json'), findsOneWidget);
      platform.failSave = true;
      await tester.tap(find.text('导出到文件'));
      await settle(tester);
      expect(find.text('下载目录写入失败'), findsOneWidget);
      platform.failCopy = true;
      await tester.tap(find.text('复制到剪贴板'));
      await settle(tester);
      expect(find.textContaining('复制失败'), findsOneWidget);
      platform.failSave = false;
      platform.hold = Completer<void>();
      await tester.tap(find.text('导出到文件'));
      await tester.pump();
      final before = platform.saves;
      await tester.tap(find.text('导出到文件'));
      await tester.pump();
      expect(platform.saves, before);
      platform.hold!.complete();
      await settle(tester);
    },
  );
  testWidgets(
    'cancelled file, malformed input and preview cancellation create nothing',
    (tester) async {
      await home(tester);
      await tester.tap(find.byTooltip('计划导入导出'));
      await settle(tester);
      await tester.tap(find.text('导入计划'));
      await settle(tester);
      await tester.tap(find.text('从文件选择'));
      await settle(tester);
      expect(find.text('导入预览'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('plan-import-text')),
        'broken',
      );
      await tester.tap(find.text('预览计划'));
      await settle(tester);
      expect(find.textContaining('计划内容损坏'), findsOneWidget);
      platform.picked = sample();
      await tester.tap(find.text('从文件选择'));
      await settle(tester);
      expect(find.text('导入预览'), findsOneWidget);
      await tester.tap(find.text('查看动作配置'));
      await settle(tester);
      expect(find.textContaining('动作后休息 150 秒'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(await tester.runAsync(repo.listPlans), isEmpty);
    },
  );
  testWidgets(
    'rename, transaction retry, conflict review and homepage refresh',
    (tester) async {
      await tester.runAsync(() => repo.createPlan('练背'));
      platform.clipboard = sample();
      await home(tester);
      await tester.tap(find.byTooltip('计划导入导出'));
      await settle(tester);
      await tester.tap(find.text('导入计划'));
      await settle(tester);
      await tester.tap(find.text('粘贴'));
      await settle(tester);
      await tester.tap(find.text('预览计划'));
      await settle(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('import-name-0')))
            .controller!
            .text,
        '练背（导入）',
      );
      await tester.enterText(
        find.byKey(const ValueKey('import-name-0')),
        '分享计划',
      );
      await tester.runAsync(() => repo.createPlan('分享计划'));
      await tester.tap(find.text('确认导入'));
      await settle(tester);
      expect(find.textContaining('名称存在冲突'), findsOneWidget);
      expect((await tester.runAsync(repo.listPlans))!.length, 2);
      await tester.runAsync(
        () => db.db.execute(
          "CREATE TRIGGER fail_ui BEFORE INSERT ON plan_exercises BEGIN SELECT RAISE(ABORT, 'injected'); END",
        ),
      );
      await tester.tap(find.text('确认导入'));
      await settle(tester);
      expect(find.text('导入失败，请重试'), findsOneWidget);
      expect(find.text('导入预览'), findsOneWidget);
      expect((await tester.runAsync(repo.listPlans))!.length, 2);
      await tester.runAsync(() => db.db.execute('DROP TRIGGER fail_ui'));
      await tester.tap(find.text('确认导入'));
      await tester.pump();
      await tester.tap(find.text('确认导入'), warnIfMissed: false);
      await settle(tester);
      expect((await tester.runAsync(repo.listPlans))!.map((p) => p.name), [
        '练背',
        '分享计划',
        '分享计划（导入）',
      ]);
      expect(find.text('成功导入 1 个计划'), findsOneWidget);
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'readable export and preview at $width, dark=$dark, 1.3 font scale',
        (tester) async {
          await tester.runAsync(() => repo.createPlan('长名称训练计划'));
          await page(
            tester,
            PlanExportPage(plans: repo, platform: platform),
            width: width,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          final button = find.widgetWithText(FilledButton, '导出到文件');
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          await tester.pumpWidget(const SizedBox());
          platform.picked = sample('🏋️‍♂️训练计划');
          await page(
            tester,
            PlanImportPage(plans: repo, platform: platform),
            width: width,
            dark: dark,
          );
          await tester.tap(find.text('从文件选择'));
          await settle(tester);
          await tester.tap(find.text('查看动作配置'));
          await settle(tester);
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.widgetWithText(FilledButton, '确认导入')).height,
            greaterThanOrEqualTo(48),
          );
        },
      );
    }
  }
}
