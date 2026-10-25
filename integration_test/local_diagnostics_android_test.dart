import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/about/notice_preferences.dart';
import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/features/diagnostics/diagnostics_pages.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_service.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/main.dart';

import '../test/rest_alert_repository_test.dart' show FakeAlertsPlatform;
import '../test/support/backup_fakes.dart' show FakeBackupFiles;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real diagnostics UI export during active rest and independent startup failure',
    (tester) async {
      if (!const bool.fromEnvironment('DIAGNOSTICS_QA_ISOLATED')) {
        throw StateError('Only run on the selected isolated emulator.');
      }
      final evidence = Directory(
        '${Directory.systemTemp.path}/local-diagnostics-evidence',
      );
      await evidence.create(recursive: true);
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        noticePreferenceKey,
        'theme_mode',
        'theme_color',
        'app_language',
      ];
      final prior = {for (final key in keys) key: prefs.get(key)};
      final db = await AppDatabase.open(
        filePath:
            '${Directory.systemTemp.path}/diagnostics-qa-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final writes = DataWriteCoordinator()..reconcile(0);
      final client = DiagnosticsClient(
        transport: const AndroidDiagnosticsTransport(),
        epoch: () => writes.diagnosticEpoch,
      );
      final before = await client.overview();
      final previousClient = DiagnosticsClient.instance;
      DiagnosticsClient.instance = client;
      try {
        await client.setEnabled(true);
        await prefs.setInt(noticePreferenceKey, currentNoticeVersion);
        await prefs.setString('theme_mode', 'light');
        final plans = PlanRepository(db.db, coordinator: writes);
        final workouts = WorkoutRepository(db.db, coordinator: writes);
        final plan = await plans.createPlan(
          'PRIVATE_PLAN_SENTINEL_DIAGNOSTICS',
        );
        await plans.addExercise(
          planId: plan,
          name: 'PRIVATE_EXERCISE_SENTINEL_DIAGNOSTICS',
          targetSets: 3,
          restBetweenSetsSeconds: 600,
          restAfterExerciseSeconds: 0,
          defaultWeightKg: 47.125,
        );
        final session = await workouts.start(plan);
        final resting = await workouts.completeSet(
          session.id,
          expectedExerciseId: session.currentExercise.id,
          expectedSetNumber: 1,
        );
        final repository = RestAlertRepository(db.db, coordinator: writes);
        final alerts = RestAlertService(
          repository,
          FakeAlertsPlatform(repository),
        );
        await tester.pumpWidget(
          SetTraceApp(
            plans: plans,
            workouts: workouts,
            preferences: prefs,
            initialLocale: const Locale('zh'),
            dataWrites: writes,
            alerts: alerts,
            backupFiles: FakeBackupFiles(
              Directory('${Directory.systemTemp.path}/diagnostic-qa-backups'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        Future<void> capture(String name) async {
          await tester.pumpAndSettle();
          await File('${evidence.path}/$name.png')
              .writeAsBytes(await binding.takeScreenshot(name));
        }

        await tester.tap(find.text('设置').last);
        await tester.pumpAndSettle();
        await capture('L00-settings-top');
        await tester.scrollUntilVisible(
          find.text('休息提醒').first,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await capture('L00-settings-reminders');
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-diagnostics')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await capture('L00-settings-data-about');
        await tester.tap(find.byKey(const ValueKey('settings-diagnostics')));
        await tester.pumpAndSettle();
        await capture('L01-home');
        await tester.scrollUntilVisible(
          find.text('临时详细诊断').first,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('临时详细诊断').first);
        await tester.pumpAndSettle();
        await capture('L05-detailed-off');
        await tester.tap(find.text('开启30分钟'));
        await tester.pumpAndSettle();
        await capture('L05-detailed-on');
        await tester.tap(find.text('立即关闭'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('记录与隐私说明').first,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('记录与隐私说明').first);
        await tester.pumpAndSettle();
        await capture('L08-privacy');
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('清空本机日志').first,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('清空本机日志').first);
        await tester.pumpAndSettle();
        await capture('LD01-confirm');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('导出诊断包').last);
        await tester.pumpAndSettle();
        await capture('L02-preview');
        final exportPage = tester.widget<DiagnosticsExportPage>(
          find.byType(DiagnosticsExportPage),
        );
        expect(exportPage.controller.exporting, isFalse);
        await tester.tap(find.text('保存到下载目录'));
        await tester.pump();
        if (find.text('正在导出诊断包').evaluate().isNotEmpty) {
          await File('${evidence.path}/L03-progress.png')
              .writeAsBytes(await binding.takeScreenshot('L03-progress'));
        }
        final deadline = Stopwatch()..start();
        while (exportPage.controller.export?.terminal != true &&
            deadline.elapsed < const Duration(seconds: 35)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(exportPage.controller.export?.saved, isTrue);
        await capture('L04-L06-result');
        final result = exportPage.controller.export!;
        final after = (await workouts.getSession(session.id))!;
        expect(after.completedSets, 1);
        expect(after.restEndAt, resting.restEndAt);
        await File('${evidence.path}/export-result.json').writeAsString(
          jsonEncode({
            'file_name': result.fileName,
            'bytes': result.bytes,
            'stage': result.stage.name,
            'active_rest_unchanged': after.restEndAt == resting.restEndAt,
            'completed_count': after.completedSets,
            'missing': result.missing,
          }),
        );
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        final tabs = tester.widget<RootTabs>(
          find.byType(RootTabs, skipOffstage: false),
        );
        await tabs.onLocaleChanged(const Locale('en'));
        await tabs.onModeChanged(ThemeMode.dark);
        await tester.pumpAndSettle();
        await capture('L01-dark-en');
        await tester.tap(find.text('Export diagnostics').last);
        await tester.pumpAndSettle();
        expect(
          find.text('Save to Downloads'),
          findsOneWidget,
        ); // Prior success must not trap the next export.
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          SetTraceBootstrap(
            writes: DataWriteCoordinator(),
            diagnostics: client,
            openDatabase: () async =>
                throw StateError('PRIVATE startup failure'),
          ),
        );
        await tester.pumpAndSettle();
        await capture('L07-startup-failure');
        await tester.tap(find.text('Export available diagnostics'));
        await tester.pumpAndSettle();
        await capture('L02-startup-origin');
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
        expect(find.text('Unable to open local data'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        debugPrint('DIAGNOSTICS_ANDROID_OK ${evidence.path}');
      } finally {
        await client.setDetailed(false);
        await client.setEnabled(before.enabled);
        DiagnosticsClient.instance = previousClient;
        client.dispose();
        await db.close();
        for (final entry in prior.entries) {
          final value = entry.value;
          if (value == null) {
            await prefs.remove(entry.key);
          } else if (value is int) {
            await prefs.setInt(entry.key, value);
          } else if (value is String) {
            await prefs.setString(entry.key, value);
          }
        }
      }
    },
  );
}
