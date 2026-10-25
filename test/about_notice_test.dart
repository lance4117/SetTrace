import 'package:flutter/services.dart';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/about/app_info_service.dart';
import 'package:settrace/features/about/about_section.dart';
import 'package:settrace/features/about/app_notice_dialog.dart';
import 'package:settrace/features/about/notice_preferences.dart';
import 'package:settrace/features/about/licenses_page.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/features/workout/workout_page.dart';
import 'package:settrace/features/rest_alerts/rest_alert_repository.dart';
import 'package:settrace/features/rest_alerts/rest_alert_service.dart';
import 'package:settrace/l10n/localization.dart';

import 'fixtures/long_localizations.dart';
import 'rest_alert_repository_test.dart' show FakeAlertsPlatform;

class FailureStore extends InMemorySharedPreferencesStore {
  FailureStore() : super.withData({});
  bool fail = true, throws = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (throws) throw StateError('private details');
    return fail ? false : super.setValue(type, key, value);
  }
}

class FakeInfo extends AppInfoService {
  bool failRead = false, failOpen = false;
  int reads = 0, opens = 0;
  @override
  Future<InstalledVersion> readVersion() async {
    reads++;
    if (failRead) throw StateError('private details');
    return (version: '9.8.7-qa', buildNumber: '1234');
  }

  @override
  Future<bool> openPage({required bool issues}) async {
    opens++;
    return !failOpen;
  }
}

Widget shell(
  Widget child, {
  String lang = 'en',
  bool dark = false,
  double scale = 1,
  bool long = false,
}) => MaterialApp(
  theme: dark ? AppTheme.dark : AppTheme.light,
  locale: Locale(lang),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: [
    if (long) const LongDelegate(),
    ...AppLocalizations.localizationsDelegates,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);
Future<void> flush(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// SQLite replies use real asynchronous work while the widget clock is fake.
/// Pump until this specific operation settles instead of relying on 90 ms of
/// host scheduling, which is insufficient under the full matrix's load.
Future<void> settleOperation(WidgetTester t, Future<void> operation) async {
  var done = false;
  operation.then<void>(
    (_) {
      done = true;
    },
    onError: (Object _, StackTrace _) {
      done = true;
    },
  );
  final elapsed = Stopwatch()..start();
  while (!done && elapsed.elapsed < const Duration(seconds: 5)) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 20));
  }
  expect(done, isTrue, reason: 'The actual reminder operation must settle');
  await operation;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'notice treats absent, invalid, older and saved versions correctly',
    () async {
      for (final value in [null, 'invalid', 0, 1, 2]) {
        SharedPreferences.setMockInitialValues({noticePreferenceKey: ?value});
        final prefs = NoticePreferences(await SharedPreferences.getInstance());
        expect(
          prefs.hasSeenCurrent,
          value is int && value >= currentNoticeVersion,
        );
        await prefs.acknowledge();
        expect(prefs.hasSeenCurrent, isTrue);
      }
    },
  );
  test('failed writes do not leave phantom seen state and can retry', () async {
    final store = FailureStore();
    SharedPreferencesStorePlatform.instance = store;
    final prefs = NoticePreferences(await SharedPreferences.getInstance());
    await expectLater(prefs.acknowledge(), throwsStateError);
    expect(prefs.hasSeenCurrent, isFalse);
    store.throws = true;
    await expectLater(prefs.acknowledge(), throwsStateError);
    expect(prefs.hasSeenCurrent, isFalse);
    store.throws = false;
    store.fail = false;
    await prefs.acknowledge();
    expect(prefs.hasSeenCurrent, isTrue);
  });
  test(
    'service reads installed metadata and opens only explicit fixed URLs',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'SetTrace',
        packageName: 'test',
        version: '9.8.7',
        buildNumber: '7001',
        buildSignature: '',
      );
      final urls = <Uri>[];
      final service = AppInfoService(
        launch: (uri) async {
          urls.add(uri);
          return true;
        },
      );
      expect(await service.readVersion(), (
        version: '9.8.7',
        buildNumber: '7001',
      ));
      expect(urls, isEmpty);
      await service.openPage(issues: false);
      await service.openPage(issues: true);
      expect(urls.map((u) => u.toString()), [
        'https://github.com/lance4117/SetTrace',
        'https://github.com/lance4117/SetTrace/issues',
      ]);
      expect(urls.every((u) => u.query.isEmpty), isTrue);
    },
  );
  testWidgets(
    'dialog save failure supports retry and continue without marking read',
    (t) async {
      final store = FailureStore();
      SharedPreferencesStorePlatform.instance = store;
      final prefs = NoticePreferences(await SharedPreferences.getInstance());
      await t.pumpWidget(
        shell(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppNotice(context, preferences: prefs),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('notice-confirm')));
      await t.pumpAndSettle();
      expect(find.text('Continue for now'), findsOneWidget);
      expect(prefs.hasSeenCurrent, isFalse);
      await t.tap(find.text('Continue for now'));
      await t.pumpAndSettle();
      expect(find.byType(AppNoticeDialog), findsNothing);
      expect(prefs.hasSeenCurrent, isFalse);
      store.fail = false;
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('notice-confirm')));
      await t.pumpAndSettle();
      expect(prefs.hasSeenCurrent, isTrue);
      expect(find.byType(AppNoticeDialog), findsNothing);
    },
  );
  testWidgets('back and manual review do not mark notice read', (t) async {
    final prefs = NoticePreferences(await SharedPreferences.getInstance());
    await t.pumpWidget(
      shell(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppNotice(context, preferences: prefs),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(prefs.hasSeenCurrent, isFalse);
    await t.pumpWidget(
      shell(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppNotice(context),
            child: const Text('Review'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Review'));
    await t.pumpAndSettle();
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    expect(prefs.hasSeenCurrent, isFalse);
  });
  testWidgets(
    'about reads once, retries metadata and external failures, reviews notice',
    (t) async {
      final info = FakeInfo()..failRead = true;
      await t.pumpWidget(shell(ListView(children: [AboutSection(info: info)])));
      await t.pumpAndSettle();
      expect(find.text('Version information is unavailable'), findsOneWidget);
      expect(info.opens, 0);
      info.failRead = false;
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('Version 9.8.7-qa (1234)'), findsOneWidget);
      info.failOpen = true;
      await t.ensureVisible(find.text('Project page'));
      await t.tap(find.text('Project page'));
      await t.pumpAndSettle();
      expect(
        find.text('Could not open your browser. Please try again.'),
        findsOneWidget,
      );
      info.failOpen = false;
      await t.ensureVisible(find.text('Retry'));
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(info.opens, 2);
      expect(info.reads, 2);
      await t.ensureVisible(find.text('Privacy and data'));
      await t.tap(find.text('Privacy and data'));
      await t.pumpAndSettle();
      expect(find.byType(AppNoticeDialog), findsOneWidget);
      await t.tap(find.text('Close'));
      await t.pumpAndSettle();
      expect(find.byType(AboutSection), findsOneWidget);
    },
  );
  testWidgets('licenses show bundled text, empty and failure retry states', (
    t,
  ) async {
    await t.pumpWidget(shell(AppLicensesPage(loadLicenses: () async => [])));
    await t.pumpAndSettle();
    expect(
      find.text('No third-party license information is available'),
      findsOneWidget,
    );
    var fail = true;
    await t.pumpWidget(
      shell(
        AppLicensesPage(
          key: const ValueKey('retry'),
          loadLicenses: () async {
            if (fail) throw StateError('secret');
            return [
              const LicenseEntryWithLineBreaks([
                'sample',
              ], 'Actual bundled license'),
            ];
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text('Could not load licenses. Please try again.'),
      findsOneWidget,
    );
    fail = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    await t.tap(find.text('View all open-source licenses'));
    await t.pumpAndSettle();
    await t.tap(find.text('sample'));
    await t.pumpAndSettle();
    expect(find.text('Actual bundled license'), findsOneWidget);
  });
  for (final size in [
    const Size(360, 800),
    const Size(430, 800),
    const Size(740, 390),
    const Size(768, 1024),
  ]) {
    for (final lang in ['en', 'zh']) {
      for (final dark in [false, true]) {
        for (final scale in [1.0, 1.3, 1.6]) {
          testWidgets('about and notice matrix $size $lang $dark $scale', (
            t,
          ) async {
            t.view.physicalSize = size;
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            final l = lookupAppLocalizations(Locale(lang));
            await t.pumpWidget(
              shell(
                ListView(children: [AboutSection(info: FakeInfo())]),
                lang: lang,
                dark: dark,
                scale: scale,
              ),
            );
            await t.pumpAndSettle();
            await t.ensureVisible(find.text(l.privacyAndData));
            await t.pumpAndSettle();
            await t.tap(find.text(l.privacyAndData));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            final dialog = find.byType(AppNoticeDialog);
            await t.drag(
              find
                  .descendant(
                    of: dialog,
                    matching: find.byType(SingleChildScrollView),
                  )
                  .first,
              const Offset(0, -1200),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            await t.tap(find.text(l.close));
            await t.pumpAndSettle();
            expect(find.byType(AppNoticeDialog), findsNothing);
          });
        }
      }
    }
  }
  testWidgets('long notice, keyboard and accessible content remain usable', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      shell(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppNotice(context),
            child: const Text('Open'),
          ),
        ),
        scale: 1.6,
        long: true,
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.textContaining('No account is required.'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    expect(find.byType(AppNoticeDialog), findsNothing);
    expect(t.takeException(), isNull);
    semantics.dispose();
  });
  group('root startup coordination', () {
    late Directory dir;
    late AppDatabase db;
    late PlanRepository plans;
    late WorkoutRepository workouts;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('settrace_about_');
      db = await AppDatabase.open(
        filePath: '${dir.path}/db',
        factory: databaseFactoryFfi,
      );
      plans = PlanRepository(db.db);
      workouts = WorkoutRepository(db.db);
    });
    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    testWidgets('fresh or upgraded user acknowledges once, reopen keeps data', (
      t,
    ) async {
      final id = (await t.runAsync(() => plans.createPlan('Existing plan')))!;
      final prefs = await SharedPreferences.getInstance();
      Future<void> start() async {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          SetTraceApp(
            plans: plans,
            workouts: workouts,
            preferences: prefs,
            info: FakeInfo(),
          ),
        );
        await flush(t);
      }

      await start();
      expect(find.byType(AppNoticeDialog), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('notice-confirm')));
      await flush(t);
      expect(find.byType(AppNoticeDialog), findsNothing);
      await start();
      expect(find.byType(AppNoticeDialog), findsNothing);
      expect((await t.runAsync(() => plans.listPlans()))!.single.id, id);
      await t.pumpWidget(const SizedBox());
    });
    testWidgets(
      'notification waits for notice and opens latest valid workout',
      (t) async {
        final id = (await t.runAsync(
          () => plans.createPlan('Notification plan'),
        ))!;
        await t.runAsync(
          () => plans.addExercise(
            planId: id,
            name: 'Exercise',
            targetSets: 2,
            restBetweenSetsSeconds: 120,
            restAfterExerciseSeconds: 0,
          ),
        );
        final session = (await t.runAsync(() => workouts.start(id)))!;
        final repo = RestAlertRepository(db.db);
        final platform = FakeAlertsPlatform(repo);
        final alerts = RestAlertService(repo, platform);
        await t.pumpWidget(
          SetTraceApp(
            plans: plans,
            workouts: workouts,
            preferences: await SharedPreferences.getInstance(),
            alerts: alerts,
            info: FakeInfo(),
          ),
        );
        await flush(t);
        alerts.onTap?.call(session.id);
        alerts.onTap?.call(session.id);
        await flush(t);
        expect(find.byType(AppNoticeDialog), findsOneWidget);
        expect(find.byType(WorkoutPage), findsNothing);
        await t.tap(find.byKey(const ValueKey('notice-confirm')));
        await flush(t);
        expect(find.byType(WorkoutPage), findsOneWidget);
        expect(platform.permissionCalls, 0);
        await t.pumpWidget(const SizedBox());
        final drained = alerts.synchronize();
        // Let the existing fake-async queue advance before awaiting its tail.
        await flush(t);
        await settleOperation(t, drained);
        await t.pumpAndSettle();
      },
    );
    testWidgets('expired notification is checked after dismissal, not opened', (
      t,
    ) async {
      final id = (await t.runAsync(
        () => plans.createPlan('Stale notification'),
      ))!;
      await t.runAsync(
        () => plans.addExercise(
          planId: id,
          name: 'Exercise',
          targetSets: 2,
          restBetweenSetsSeconds: 0,
          restAfterExerciseSeconds: 0,
        ),
      );
      final session = (await t.runAsync(() => workouts.start(id)))!;
      final repo = RestAlertRepository(db.db);
      final alerts = RestAlertService(repo, FakeAlertsPlatform(repo));
      await t.pumpWidget(
        SetTraceApp(
          plans: plans,
          workouts: workouts,
          preferences: await SharedPreferences.getInstance(),
          initialLocale: const Locale('en'),
          alerts: alerts,
          info: FakeInfo(),
        ),
      );
      await flush(t);
      alerts.onTap?.call(session.id);
      await flush(t);
      await t.runAsync(() => workouts.discard(session.id));
      await t.tap(find.byKey(const ValueKey('notice-confirm')));
      await flush(t);
      expect(find.byType(WorkoutPage), findsNothing);
      expect(
        find.text(
          lookupAppLocalizations(const Locale('en'))
              .notificationWorkoutUnavailable,
        ),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      final drained = alerts.synchronize();
      await flush(t);
      await settleOperation(t, drained);
      await t.pumpAndSettle();
    });
    testWidgets('notice preserves rest and defers permission explanation', (
      t,
    ) async {
      final id = (await t.runAsync(() => plans.createPlan('Rest plan')))!;
      await t.runAsync(
        () => plans.addExercise(
          planId: id,
          name: 'Exercise',
          targetSets: 2,
          restBetweenSetsSeconds: 120,
          restAfterExerciseSeconds: 0,
        ),
      );
      var session = (await t.runAsync(() => workouts.start(id)))!;
      session = (await t.runAsync(
        () => workouts.completeSet(
          session.id,
          expectedExerciseId: session.currentExercise.id,
          expectedSetNumber: 1,
        ),
      ))!;
      final before = session.restEndAt;
      final repo = RestAlertRepository(db.db);
      final platform = FakeAlertsPlatform(repo);
      final alerts = RestAlertService(repo, platform);
      await t.pumpWidget(
        SetTraceApp(
          plans: plans,
          workouts: workouts,
          preferences: await SharedPreferences.getInstance(),
          initialLocale: const Locale('en'),
          alerts: alerts,
          info: FakeInfo(),
        ),
      );
      await flush(t);
      final synchronization = alerts.synchronize(offerPermission: true);
      await flush(t);
      await settleOperation(t, synchronization);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(AppNoticeDialog), findsOneWidget);
      expect(platform.permissionCalls, 0);
      expect(
        (await t.runAsync(() => workouts.getSession(session.id)))!.restEndAt,
        before,
      );
      await t.tap(find.byKey(const ValueKey('notice-confirm')));
      await flush(t);
      expect(find.byType(AppNoticeDialog), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        (await t.runAsync(() => workouts.getSession(session.id)))!.restEndAt,
        before,
      );
      await t.tap(find.text(lookupAppLocalizations(const Locale('en')).cancel));
      await flush(t);
      await t.pumpWidget(const SizedBox());
      final drained = alerts.synchronize();
      await flush(t);
      await settleOperation(t, drained);
      await t.pumpAndSettle();
    });
  });
}
