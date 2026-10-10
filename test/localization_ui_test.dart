import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/core/widgets/app_button.dart';
import 'package:settrace/core/widgets/app_bottom_nav.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/plans/exercise_editor_page.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:settrace/features/plans/plan_transfer_pages.dart';
import 'package:settrace/features/plans/plan_transfer_platform.dart';
import 'package:settrace/features/settings/settings_page.dart';
import 'package:settrace/features/workout/workout_page.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/l10n/language_settings.dart';
import 'package:settrace/l10n/localization.dart';

import 'fixtures/long_localizations.dart';

class FailingPreferences extends InMemorySharedPreferencesStore {
  FailingPreferences() : super.withData({'flutter.app_language': 'zh'});
  bool fail = true;
  @override
  Future<bool> setValue(String type, String key, Object value) async =>
      fail ? false : super.setValue(type, key, value);
}

class ErrorFiles implements PlanTransferPlatform {
  @override
  Future<void> copyText(String text) async =>
      throw StateError('raw native secret');
  @override
  Future<String?> readClipboard() async => null;
  @override
  Future<SavedPlanFile> saveFile(String text) async =>
      throw const PlanTransferException(PlanTransferFailure.permissionDenied);
  @override
  Future<String?> pickFile() async => null;
}

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory dir;
  late AppDatabase database;
  late PlanRepository plans;
  late WorkoutRepository workouts;
  late SharedPreferences preferences;
  late int planId;
  setUp(() async {
    SharedPreferences.setMockInitialValues({languagePreferenceKey: 'zh'});
    preferences = await SharedPreferences.getInstance();
    dir = await Directory.systemTemp.createTemp('settrace_locale_ui_');
    database = await AppDatabase.open(
      filePath: '${dir.path}/db',
      factory: databaseFactoryFfi,
    );
    plans = PlanRepository(database.db);
    workouts = WorkoutRepository(database.db);
    planId = await plans.createPlan('用户计划');
    await plans.addExercise(
      planId: planId,
      name: '用户动作',
      targetSets: 2,
      restBetweenSetsSeconds: 120,
      restAfterExerciseSeconds: 0,
      defaultWeightKg: 45.5,
    );
  });
  tearDown(() async {
    await database.close();
    await dir.delete(recursive: true);
  });
  Widget root() =>
      SetTraceApp(plans: plans, workouts: workouts, preferences: preferences);
  Future<void> switchRoot(WidgetTester tester, Locale locale) async {
    await tester.runAsync(
      () => tester
          .widget<RootTabs>(find.byType(RootTabs, skipOffstage: false))
          .onLocaleChanged(locale),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'setting order, immediate switch, persistence and failure retry',
    (tester) async {
      final store = FailingPreferences();
      SharedPreferencesStorePlatform.instance = store;
      await tester.pumpWidget(root());
      await flush(tester);
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'SetTrace',
      );
      final english = find.byKey(const ValueKey('language-en'));
      await tester.ensureVisible(english);
      final englishY = tester.getTopLeft(english).dy;
      expect(
        englishY,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('language-zh'))).dy,
        ),
      );
      await tester.tap(english);
      await tester.pumpAndSettle();
      expect(
        find.text(
          lookupAppLocalizations(const Locale('zh')).languageSaveFailed,
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        const Locale('zh'),
      );
      expect(preferences.getString(languagePreferenceKey), 'zh');
      store.fail = false;
      await tester.tap(english);
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('中文'), findsOneWidget);
      expect(preferences.getString(languagePreferenceKey), 'en');
      await tester.pumpWidget(const SizedBox());
      await preferences.reload();
      await tester.pumpWidget(root());
      await flush(tester);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        const Locale('en'),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'root switch keeps navigator, tab, editor draft, progress and rest deadline',
    (tester) async {
      final session = (await tester.runAsync(() async {
        final session = await workouts.start(planId);
        return workouts.completeSet(
          session.id,
          expectedExerciseId: session.currentExercise.id,
          expectedSetNumber: 1,
        );
      }))!;
      await tester.pumpWidget(root());
      await flush(tester);
      await tester.tap(find.text('设置').last);
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ExerciseEditorPage(plans: plans, planId: planId),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '草稿 remains');
      final field = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller;
      final editorState = tester.state(find.byType(ExerciseEditorPage));
      await switchRoot(tester, const Locale('en'));
      expect(tester.state(find.byType(ExerciseEditorPage)), same(editorState));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller,
        same(field),
      );
      expect(field!.text, '草稿 remains');
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)),
        same(navigator),
      );
      expect(find.text('Add exercise'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(
        find.text('Language'),
        findsOneWidget,
      ); // Settings tab did not reset.
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              WorkoutPage(workouts: workouts, sessionId: session.id),
        ),
      );
      await flush(tester);
      final workoutState = tester.state(find.byType(WorkoutPage));
      await switchRoot(tester, const Locale('zh'));
      expect(tester.state(find.byType(WorkoutPage)), same(workoutState));
      final after = (await tester.runAsync(
        () => workouts.getSession(session.id),
      ))!;
      expect(after.completedSets, session.completedSets);
      expect(after.restEndAt, session.restEndAt);
      await tester.tap(find.text('退出'));
      await tester.pumpAndSettle();
      await switchRoot(tester, const Locale('en'));
      expect(find.text('End this workout?'), findsOneWidget);
      expect(find.text('Save completed sets'), findsOneWidget);
      await tester.tap(find.text('Resume workout'));
      await tester.pumpAndSettle();
      showAppSnackBar(
        tester.element(find.byType(WorkoutPage)),
        (l) => l.operationFailed,
      );
      await tester.pump();
      await switchRoot(tester, const Locale('zh'));
      expect(
        find.text(lookupAppLocalizations(const Locale('zh')).operationFailed),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [360.0, 430.0]) {
    for (final dark in [false, true]) {
      testWidgets('long text $width dp dark=$dark at 1.6 scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget localized(Widget page) => MaterialApp(
          key: ValueKey(page.runtimeType),
          locale: const Locale('en'),
          theme: dark ? AppTheme.dark : AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            const LongDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: page,
        );
        await tester.pumpWidget(
          localized(
            Scaffold(
              bottomNavigationBar: AppBottomNav(index: 2, onChanged: (_) {}),
              body: SettingsPage(
                mode: ThemeMode.system,
                onModeChanged: (_) {},
                locale: const Locale('en'),
                onLocaleChanged: (_) async {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          localized(ExerciseEditorPage(plans: plans, planId: planId)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final button = find.byType(AppButton).last;
        await tester.ensureVisible(button);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
        final session = (await tester.runAsync(() => workouts.start(planId)))!;
        await tester.pumpWidget(
          localized(WorkoutPage(workouts: workouts, sessionId: session.id)),
        );
        await flush(tester);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text(LongStrings().completeSet),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(LongStrings().completeSet));
        await flush(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Exit'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Resume workout'));
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(() => workouts.getSession(session.id)))!
              .completedSets,
          1,
        );
        await tester.pumpWidget(
          localized(PlanExportPage(plans: plans, platform: ErrorFiles())),
        );
        await flush(tester);
        await tester.scrollUntilVisible(
          find.text(LongStrings().exportFile),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(LongStrings().exportFile));
        await flush(tester);
        expect(tester.takeException(), isNull);
        expect(find.text(LongStrings().permissionDenied), findsOneWidget);
        await tester.pumpWidget(
          localized(PlanImportPage(plans: plans, platform: ErrorFiles())),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('plan-import-text')),
          'broken',
        );
        await tester.scrollUntilVisible(
          find.text(LongStrings().previewPlans),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(LongStrings().previewPlans));
        await flush(tester);
        expect(tester.takeException(), isNull);
        expect(find.text(LongStrings().damagedContent), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
