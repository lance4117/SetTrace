import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/backup/backup_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/backup/backup_codec.dart';
import 'package:settrace/features/backup/backup_coordinator.dart';
import 'package:settrace/features/backup/backup_files_platform.dart';
import 'package:settrace/features/backup/backup_pages.dart';
import 'package:settrace/features/backup/backup_models.dart';
import 'package:settrace/features/settings/settings_page.dart';
import 'package:settrace/features/rest_alerts/rest_alert_service.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';

import 'rest_alert_repository_test.dart' show FakeAlertsPlatform;
import 'about_notice_test.dart' show FakeInfo;

import 'package:settrace/features/backup/data_write_coordinator.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/backup_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase db;
  late BackupCoordinator service;
  late BackupDocument fixture;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('backup_ui_');
    db = await AppDatabase.open(
      filePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    fixture = BackupCodec().decode(
      File('test/fixtures/backup/v1-history.settrace.json').readAsBytesSync(),
    );
    service = BackupCoordinator(
      db: db.db,
      writes: DataWriteCoordinator(),
      preferences: FakeBackupPreferences(fixture.data.settings),
      files: FakeBackupFiles(Directory('${dir.path}/files')),
      appVersion: () => 'test',
    );
    await service.reconcileStartup();
  });
  tearDown(() async {
    service.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 200; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await t.pump(const Duration(milliseconds: 100));
      final page = find.byType(BackupPage);
      if (i > 2 &&
          (page.evaluate().isEmpty || !(t.state(page) as dynamic).busy)) {
        break;
      }
    }
    await t.pumpAndSettle();
  }

  for (final size in [
    const Size(360, 800),
    const Size(430, 800),
    const Size(740, 390),
    const Size(768, 1024),
  ]) {
    for (final language in ['zh', 'en']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 1.3, 1.6, 2.0]) {
          testWidgets(
            'backup home and export $size $language $brightness $scale',
            (t) async {
              t.view.physicalSize = size;
              t.view.devicePixelRatio = 1;
              addTearDown(t.view.resetPhysicalSize);
              addTearDown(t.view.resetDevicePixelRatio);
              final l = lookupAppLocalizations(Locale(language));
              await t.pumpWidget(
                MaterialApp(
                  theme: AppTheme.forPreset(
                    brightness,
                    ThemeColorPreset.values[[
                      1.0,
                      1.3,
                      1.6,
                      2.0,
                    ].indexOf(scale)],
                  ),
                  locale: Locale(language),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: BackupPage(
                    service: service,
                    onWorkout: () async {},
                    onHistory: () async {},
                    onPlanImport: () async {},
                  ),
                ),
              );
              await settle(t);
              expect(t.takeException(), isNull);
              final create = find.text(l.backupCreate);
              expect(create, findsOneWidget);
              await t.tap(create);
              await settle(t);
              expect(find.text(l.backupSaveFile), findsOneWidget);
              expect(t.takeException(), isNull);
              await t.tap(find.text(l.backupSaveFile));
              await settle(t);
              expect(
                find.text(l.backupSaved),
                findsOneWidget,
                reason:
                    '${(t.state(find.byType(BackupPage)) as dynamic).error} phase=${service.phase}',
              );
              expect(t.takeException(), isNull);
              await t.tap(find.text(l.backupDone));
              await settle(t);
              await t.scrollUntilVisible(
                find.text(l.backupRestore),
                150,
                scrollable: find
                    .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              await t.pumpAndSettle();
              await Scrollable.ensureVisible(
                t.element(find.text(l.backupRestore)),
                alignment: 0.5,
              );
              await t.pumpAndSettle();
              await t.tap(find.text(l.backupRestore));
              await settle(t);
              await t.tap(find.text(l.backupChooseFile));
              await settle(t);
              expect(find.text(l.backupSelectHelp), findsOneWidget);
              final files = service.files as FakeBackupFiles;
              await t.runAsync(() async {
                await File('test/fixtures/backup/v1-history.settrace.json')
                    .copy(files.pathFor('selected'));
              });
              files.selected = const BackupFileCandidate(
                token: 'selected',
                fileName: 'long-user-backup-file-name-with-training-history.settrace.json',
                bytes: 4096,
              );
              await t.tap(find.text(l.backupChooseFile));
              await settle(t);
              expect(find.text(l.backupContinue), findsOneWidget);
              await t.tap(find.text(l.backupContinue));
              await settle(t);
              expect(find.byType(AlertDialog), findsOneWidget);
              expect(t.takeException(), isNull);
              if (size.width == 360 &&
                  language == 'en' &&
                  brightness == Brightness.light &&
                  scale == 2.0) {
                await t.sendKeyEvent(LogicalKeyboardKey.enter);
              } else {
                await t.tap(find.text(l.cancel));
              }
              await settle(t);
              expect(find.text(l.backupContinue), findsOneWidget);
              await t.tap(find.text(l.backupContinue));
              await settle(t);
              await t.tap(find.text(l.backupReplace));
              await settle(t);
              expect(find.text(l.backupRestored), findsOneWidget);
              expect(t.takeException(), isNull);
              await t.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }
  }
  Future<void> mountPage(WidgetTester t, {Widget? home}) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.forPreset(Brightness.light, ThemeColorPreset.teal),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home:
            home ??
            BackupPage(
              service: service,
              onWorkout: () async {},
              onHistory: () async {},
              onPlanImport: () async {},
            ),
      ),
    );
    await settle(t);
  }

  Future<void> reach(WidgetTester t, String label) async {
    final finder = find.text(label);
    if (finder.evaluate().isEmpty) {
      final scroll = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      t.state<ScrollableState>(scroll).position.jumpTo(0);
      await t.pump();
      await t.scrollUntilVisible(finder, 150, scrollable: scroll);
    }
    await Scrollable.ensureVisible(t.element(finder.first), alignment: 0.5);
    await t.pumpAndSettle();
  }

  Future<void> click(WidgetTester t, String label) async {
    if (find.text(label).hitTestable().evaluate().isEmpty) {
      await reach(t, label);
    }
    await t.tap(find.text(label).hitTestable().last);
    await settle(t);
  }

  Future<void> openSourceCopy(WidgetTester t) async {
    final l = lookupAppLocalizations(const Locale('en'));
    await mountPage(t);
    await click(t, l.backupCopies);
    await click(t, l.backupCounts(2, 1));
    await click(t, l.backupCopyRestore);
  }

  for (final status in ['normal', 'off', 'failed', 'no-service']) {
    testWidgets(
      'settings backup entry is reachable and preserves scroll on return: $status',
      (t) async {
        final l = lookupAppLocalizations(const Locale('en'));
        final repo = RestAlertRepository(db.db);
        final alerts = status == 'no-service'
            ? null
            : RestAlertService(repo, FakeAlertsPlatform(repo));
        if (alerts != null) {
          alerts.enabled = status != 'off';
          alerts.failed = status == 'failed';
        }
        await mountPage(
          t,
          home: Scaffold(
            body: Builder(
              builder: (context) => SettingsPage(
                alerts: alerts,
                info: FakeInfo(),
                mode: ThemeMode.system,
                onModeChanged: (_) async {},
                locale: const Locale('en'),
                onLocaleChanged: (_) async {},
                onBackup: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Opened backup')),
                  ),
                ),
              ),
            ),
          ),
        );
        await reach(t, l.backupTitle);
        await t.tap(find.text(l.backupTitle));
        await settle(t);
        expect(find.text('Opened backup'), findsOneWidget);
        await t.binding.handlePopRoute();
        await settle(t);
        expect(find.text(l.backupTitle).hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        alerts?.dispose();
      },
    );
  }
  testWidgets(
    'pending settings persist on home and retry applies no core replacement',
    (t) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final doc = BackupCodec().decode(
        File('test/fixtures/backup/v1-history.settrace.json').readAsBytesSync(),
      );
      final prefs = service.preferences as FakeBackupPreferences;
      prefs.value = BackupSettings.fromJson({
        ...prefs.value.toJson(),
        'languageTag': 'en',
      });
      prefs.failures.add('languageTag');
      await t.runAsync(() async {
        await service.copies.protect('restore-source', doc);
        await service.restore(await service.previewCopy('restore-source'));
      });
      final epoch = await t.runAsync(service.metadata.epoch);
      await mountPage(t);
      await reach(t, l.backupRetrySettings);
      expect(find.text(l.backupSettingsPending), findsOneWidget);
      prefs.failures.clear();
      await t.tap(find.text(l.backupRetrySettings));
      await settle(t);
      expect(await t.runAsync(service.metadata.epoch), epoch);
      expect(find.text(l.backupSettingsPending), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'deleting a fixed copy requires confirmation and cancel changes nothing',
    (t) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final doc = BackupCodec().decode(
        File('test/fixtures/backup/v1-history.settrace.json').readAsBytesSync(),
      );
      await t.runAsync(() => service.copies.protect('copy-to-delete', doc));
      await mountPage(t);
      await reach(t, l.backupCopies);
      await t.tap(find.text(l.backupCopies));
      await settle(t);
      await t.tap(find.text(l.backupCounts(2, 1)));
      await settle(t);
      await reach(t, l.backupCopyDelete);
      await t.tap(find.text(l.backupCopyDelete));
      await settle(t);
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(find.text(l.cancel));
      await settle(t);
      expect(
        await t.runAsync(() => service.metadata.copy('copy-to-delete')),
        isNotNull,
      );
      await reach(t, l.backupCopyDelete);
      await t.tap(find.text(l.backupCopyDelete));
      await settle(t);
      await t.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.text(l.backupCopyDelete),
            )
            .last,
      );
      await settle(t);
      expect(
        await t.runAsync(() => service.metadata.copy('copy-to-delete')),
        isNull,
      );
      expect(find.text(l.backupNoCopies), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final language in ['en', 'zh']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 1.3, 1.6]) {
          testWidgets(
            'all backup view states $width $language $brightness $scale',
            (t) async {
              t.view.physicalSize = Size(width, 800);
              t.view.devicePixelRatio = 1;
              addTearDown(t.view.resetPhysicalSize);
              addTearDown(t.view.resetDevicePixelRatio);
              final key = GlobalKey();
              final preset =
                  ThemeColorPreset.values[([1.0, 1.3, 1.6].indexOf(scale) +
                          brightness.index +
                          (language == 'zh' ? 1 : 0)) %
                      4];
              Widget app() => MaterialApp(
                theme: AppTheme.forPreset(brightness, preset),
                themeAnimationDuration: Duration.zero,
                locale: Locale(language),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: BackupPage(
                  key: key,
                  service: service,
                  onWorkout: () async {},
                  onHistory: () async {},
                  onPlanImport: () async {},
                ),
              );
              await t.pumpWidget(app());
              await settle(t);
              final dynamic state = key.currentState;
              final row = <String, Object?>{
                'id': 'layout',
                'relative_path': 'long-backup-name-with-many-years-of-training-history.settrace.json',
                'snapshot_at': fixture.snapshotAt.toIso8601String(),
                'plan_count': 2,
                'workout_count': 1,
                'byte_count': 1024,
                'state': 'ready',
              };
              state.current = fixture.data;
              state.currentDigest = 'current';
              state.loading = false;
              state.state = <String, Object?>{
                'last_export_at': 1,
                'last_export_digest': 'old',
              };
              state.exportDocument = fixture;
              state.copyDocument = fixture;
              state.selectedCopy = row;
              state.copies = <BackupMap>[row];
              state.saved = <String, Object?>{
                'fileName': row['relative_path'],
                'ledgerPending': true,
                'operationId': 'layout',
              };
              state.preview = BackupPreview(
                id: 'layout',
                document: fixture,
                current: fixture.data,
                epoch: 0,
                restoreSettings: true,
                fileName: row['relative_path'] as String,
                bytes: 1024,
              );
              state.result = BackupOperationResult(
                'layout',
                fixture,
                settingsPending: ['themeColor', 'languageTag'],
                refreshFailed: true,
              );
              for (final screen in [
                'home',
                'export',
                'choose',
                'preview',
                'exportResult',
                'result',
                'copies',
                'copy',
              ]) {
                state.screen = screen;
                state.error = null;
                state.busy = false;
                await t.pumpWidget(app());
                await t.pump();
                expect(
                  t.takeException(),
                  isNull,
                  reason: '$screen $width $language $scale',
                );
              }
              state.screen = 'choose';
              for (final code in BackupFailure.values) {
                state.error = BackupException(code);
                if (code == BackupFailure.indeterminate) {
                  service.writes.restrict();
                  service.phase = 'indeterminate';
                }
                await t.pumpWidget(app());
                await t.pump();
                expect(
                  t.takeException(),
                  isNull,
                  reason: '$code $width $language $scale',
                );
                service.writes.reconcile(0);
                service.phase = 'idle';
              }
              state.error = null;
              state.busy = true;
              for (final phase in [
                'checking',
                'validating',
                'protecting',
                'restoring',
                'settings',
                'exporting',
              ]) {
                service.phase = phase;
                await t.pumpWidget(app());
                await t.pump();
                expect(
                  t.takeException(),
                  isNull,
                  reason: '$phase $width $language $scale',
                );
              }
              await t.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }
  }
  testWidgets(
    'root invalidates cached plans and rejects notification arriving during replacement',
    (t) async {
      SharedPreferences.setMockInitialValues({'app_notice_seen_version': 2});
      final prefs = await SharedPreferences.getInstance();
      final plans = PlanRepository(db.db, coordinator: service.writes);
      final workouts = WorkoutRepository(db.db, coordinator: service.writes);
      await t.runAsync(() async {
        await plans.createPlan('original before root restore');
        await db.db.insert('workout_sessions', {
          'id': 42,
          'plan_name_snapshot': 'old session',
          'started_at': 1,
          'started_local_date': '2026-10-17',
          'ended_at': 2,
          'duration_seconds': 0,
          'status': 'completed',
          'current_exercise_order': 1,
          'current_set_number': 1,
        });
      });
      await t.pumpWidget(
        SetTraceApp(
          plans: plans,
          workouts: workouts,
          preferences: prefs,
          initialLocale: const Locale('en'),
          dataWrites: service.writes,
          backupFiles: service.files,
          info: FakeInfo(),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      final dynamic appState = t.state(find.byType(SetTraceApp));
      final appService = appState.backups as BackupCoordinator;
      void lateTap() {
        if (appService.phase == 'protecting') appState.openNotification(42);
      }

      appService.addListener(lateTap);
      await t.runAsync(() async {
        await appService.copies.protect('root-target', fixture);
        await appService.restore(
          await appService.previewCopy('root-target', restoreSettings: false),
        );
      });
      appService.removeListener(lateTap);
      for (var i = 0; i < 6; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(appState.pendingTap, isNull);
      expect(find.text('original before root restore'), findsNothing);
      final root = t.state<RootTabsState>(find.byType(RootTabs));
      expect(await t.runAsync(() => root.openFromNotification(42)), false);
      expect(
        (await t.runAsync(() => workouts.listHistory()))!
            .every((session) => session.id > 42),
        true,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'backup extra overview read failure never becomes an empty success and retries safely',
    (t) async {
      final l = lookupAppLocalizations(const Locale('en'));
      await t.runAsync(
        () => db.db.execute('ALTER TABLE plans RENAME TO hidden_plans'),
      );
      await mountPage(t);
      expect(find.text(l.backupReadFailed), findsOneWidget);
      expect(find.text(l.backupNoDates), findsNothing);
      await t.tap(find.text(l.backupCreate));
      await settle(t);
      expect(find.text(l.backupSaveFile), findsNothing);
      await t.runAsync(
        () => db.db.execute('ALTER TABLE hidden_plans RENAME TO plans'),
      );
      await click(t, l.retry);
      expect(find.text(l.backupNoDates), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'backup extra export failure retry uses fixed snapshot and ledger repair never republishes',
    (t) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final files = service.files as FakeBackupFiles;
      await mountPage(t);
      await click(t, l.backupCreate);
      await t.runAsync(
        () => PlanRepository(db.db).createPlan('after snapshot'),
      );
      files.failPublish = true;
      await click(t, l.backupSaveFile);
      expect(find.text(l.backupStorageFailed), findsOneWidget);
      files.failPublish = false;
      await t.runAsync(
        () => db.db.execute(
          "CREATE TRIGGER fail_ui_ledger BEFORE UPDATE ON backup_state WHEN NEW.last_export_at IS NOT NULL BEGIN SELECT RAISE(ABORT,'injected'); END",
        ),
      );
      await click(t, l.backupSaveFile);
      expect(find.text(l.backupSaved), findsOneWidget);
      expect(find.text(l.backupLedgerPending), findsOneWidget);
      final published = files.exports.values
          .where((e) => e['state'] == 'published')
          .length;
      expect(published, 1);
      await t.runAsync(() => db.db.execute('DROP TRIGGER fail_ui_ledger'));
      await click(t, l.backupRepairLedger);
      expect(find.text(l.backupLedgerPending), findsNothing);
      expect(
        files.exports.values.where((e) => e['state'] == 'published').length,
        1,
      );
      await click(t, l.backupDone);
      expect(find.text(l.backupChanged), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'backup extra plan file is explicit navigation and stale preview requires renewed confirmation',
    (t) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final files = service.files as FakeBackupFiles;
      var imports = 0;
      final id = await t.runAsync(
        () => PlanRepository(db.db).createPlan('before'),
      );
      final planToken = await files.allocate();
      await t.runAsync(
        () =>
            File(files.pathFor(planToken))
                .writeAsString('{"format":"settrace.training-plans"}'),
      );
      files.selected = BackupFileCandidate(
        token: planToken,
        fileName: 'plans.json',
        bytes: 1,
      );
      await mountPage(
        t,
        home: BackupPage(
          service: service,
          onWorkout: () async {},
          onHistory: () async {},
          onPlanImport: () async {
            imports++;
          },
        ),
      );
      await click(t, l.backupRestore);
      await click(t, l.backupChooseFile);
      expect(find.text(l.backupPlanFile), findsOneWidget);
      expect(imports, 0);
      await click(t, l.backupGoPlanImport);
      expect(imports, 1);
      Future<void> candidate() async {
        final token = await files.allocate();
        await BackupCodec.writeFile(files.pathFor(token), fixture);
        files.selected = BackupFileCandidate(
          token: token,
          fileName: 'long-backup-training-history-with-complete-user-data.settrace.json',
          bytes: 1580,
        );
      }

      await t.runAsync(candidate);
      await click(t, l.backupChooseFile);
      await click(t, l.backupSettings);
      await click(t, l.backupContinue);
      await click(t, l.cancel);
      expect(
        (t.state(find.byType(BackupPage)) as dynamic).preview.restoreSettings,
        false,
      );
      await t.runAsync(() => PlanRepository(db.db).renamePlan(id!, 'changed'));
      await click(t, l.backupContinue);
      await click(t, l.backupReplace);
      expect(find.text(l.backupStale), findsOneWidget);
      await t.runAsync(candidate);
      await click(t, l.backupReviewAgain);
      expect(
        (t.state(find.byType(BackupPage)) as dynamic).preview.restoreSettings,
        false,
      );
      await click(t, l.backupContinue);
      await click(t, l.backupReplace);
      expect(find.text(l.backupRestored), findsOneWidget);
      final ops = await t.runAsync(service.metadata.operations);
      expect(ops!.last['restore_settings'], 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'backup extra protected phase rejects Android return and refresh retry preserves later records',
    (t) async {
      final l = lookupAppLocalizations(const Locale('en'));
      final files = service.files;
      final writes = service.writes;
      final prefs = service.preferences;
      service.dispose();
      var armed = false, failRefresh = true;
      final entered = Completer<void>(), release = Completer<void>();
      service = BackupCoordinator(
        db: db.db,
        writes: writes,
        preferences: prefs,
        files: files,
        appVersion: () => 'test',
        protectionCheckpoint: (phase) async {
          if (armed && phase == 'before_write') {
            entered.complete();
            await release.future;
          }
        },
        onCommitted: () async {
          if (failRefresh) throw StateError('refresh');
        },
      );
      await t.runAsync(
        () => service.copies.protect('progress-source', fixture),
      );
      armed = true;
      await openSourceCopy(t);
      await click(t, l.backupContinue);
      await t.tap(find.text(l.backupReplace));
      await t.pump();
      for (var n = 0; n < 100 && !entered.isCompleted; n++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      expect(entered.isCompleted, true);
      expect(find.text(l.backupProtecting), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(BackupPage), findsOneWidget);
      expect(await t.runAsync(service.metadata.epoch), 0);
      release.complete();
      await settle(t);
      await reach(t, l.backupRefreshFailed);
      expect(find.text(l.backupRefreshFailed), findsOneWidget);
      await t.runAsync(() => PlanRepository(db.db).createPlan('after commit'));
      failRefresh = false;
      await click(t, l.retry);
      expect(find.text(l.backupRefreshFailed), findsNothing);
      expect(await t.runAsync(service.metadata.epoch), 1);
      expect(
        (await t.runAsync(service.overview))!.plans.last['name'],
        'after commit',
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'backup extra undo and copy export or restore keep the selected target and settings scope',
    (t) async {
      final l = lookupAppLocalizations(const Locale('en'));
      await t.runAsync(() async {
        await service.copies.protect('undo-source', fixture);
        await service.restore(
          await service.previewCopy('undo-source', restoreSettings: false),
        );
        await PlanRepository(db.db).createPlan('after restore');
      });
      await mountPage(t);
      await click(t, l.backupUndo);
      expect(find.byType(CheckboxListTile), findsNothing);
      await click(t, l.backupContinue);
      await click(t, l.cancel);
      expect(await t.runAsync(service.metadata.epoch), 1);
      await click(t, l.backupContinue);
      await click(t, l.backupUndoConfirm);
      expect(find.text(l.backupUndone), findsOneWidget);
      await click(t, l.backupDone);
      await click(t, l.backupCopies);
      await click(t, l.backupCounts(3, 1));
      await click(t, l.backupCopyExport);
      expect(find.text(l.backupSaved), findsOneWidget);
      expect(
        (await t.runAsync(service.metadata.state))!['last_export_at'],
        isNull,
      );
      await click(t, l.backupDone);
      await click(t, l.backupCopies);
      await click(t, l.backupCounts(3, 1));
      await click(t, l.backupCopyRestore);
      await click(t, l.backupContinue);
      await click(t, l.backupReplace);
      expect(find.text(l.backupRestored), findsOneWidget);
      expect(
        (await t.runAsync(service.overview))!.plans.last['name'],
        'after restore',
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'startup presents an unseen committed result before normal navigation without replay',
    (t) async {
      SharedPreferences.setMockInitialValues({'app_notice_seen_version': 2});
      final prefs = await SharedPreferences.getInstance();
      await t.runAsync(() async {
        await service.copies.protect('startup-target', fixture);
        await service.restore(
          await service.previewCopy('startup-target', restoreSettings: false),
        );
      });
      final epoch = await t.runAsync(service.metadata.epoch);
      await t.pumpWidget(
        SetTraceApp(
          plans: PlanRepository(db.db, coordinator: service.writes),
          workouts: WorkoutRepository(db.db, coordinator: service.writes),
          preferences: prefs,
          initialLocale: const Locale('en'),
          dataWrites: service.writes,
          backupFiles: service.files,
          info: FakeInfo(),
        ),
      );
      for (var i = 0; i < 16; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      await settle(t);
      expect(find.byType(BackupPage), findsOneWidget);
      final l = lookupAppLocalizations(const Locale('en'));
      await reach(t, l.backupInterruptedAfter);
      expect(find.text(l.backupInterruptedAfter), findsOneWidget);
      expect(await t.runAsync(service.metadata.epoch), epoch);
      await t.pumpWidget(const SizedBox());
    },
  );
}
