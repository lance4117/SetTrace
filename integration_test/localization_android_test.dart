import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settrace/app/app.dart';
import 'package:settrace/core/database/app_database.dart';
import 'package:settrace/features/plans/plan_repository.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:settrace/features/plans/plan_transfer_pages.dart';
import 'package:settrace/features/plans/plan_transfer_platform.dart';
import 'package:settrace/features/workout/workout_repository.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:settrace/l10n/language_settings.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android language startup, switching, workouts and Downloads roundtrip',
    (tester) async {
      await initializeDateFormatting();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final system = await initializeAppLocale(prefs);
      const expected = String.fromEnvironment(
        'EXPECTED_SYSTEM',
        defaultValue: 'en',
      );
      expect(system.languageCode, expected);
      final db = await AppDatabase.open(
        filePath:
            '${Directory.systemTemp.path}/localization_qa-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final plans = PlanRepository(db.db), workouts = WorkoutRepository(db.db);
      Future<void> start(Locale locale) async {
        await tester.pumpWidget(const SizedBox());
        await prefs.setString(languagePreferenceKey, locale.toLanguageTag());
        await tester.pumpWidget(
          SetTraceApp(plans: plans, workouts: workouts, preferences: prefs),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(String text) async {
        final finder = find.text(text);
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            250,
            scrollable: find.byType(Scrollable).first,
          );
        } else {
          await tester.ensureVisible(finder.last);
        }
        await tester.pumpAndSettle();
        await tester.tap(finder.last);
        await tester.pumpAndSettle();
      }

      Future<void> shot(String name) async {
        final bytes = await binding.takeScreenshot(name);
        await File('${Directory.systemTemp.path}/$name.png')
            .writeAsBytes(bytes);
      }

      await start(system);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await shot(
        'system-${const String.fromEnvironment('SYSTEM_TAG', defaultValue: expected)}',
      );
      if (const bool.fromEnvironment('STARTUP_ONLY')) {
        await tester.pumpWidget(const SizedBox());
        await db.close();
        return;
      }
      // UI toggle, theme, persistence and restart on actual preferences storage.
      var strings = lookupAppLocalizations(system);
      await tap(strings.settings);
      final other = system.languageCode == 'en'
          ? const Locale('zh')
          : const Locale('en');
      await tester.ensureVisible(
        find.byKey(ValueKey('language-${other.languageCode}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('language-${other.languageCode}')));
      await tester.pumpAndSettle();
      expect(prefs.getString(languagePreferenceKey), other.languageCode);
      strings = lookupAppLocalizations(other);
      await tap(strings.darkTheme);
      await shot('settings-${other.languageCode}-dark');
      await tester.pumpWidget(const SizedBox());
      await prefs.reload();
      expect(readAppLocale(prefs), other);
      await tester.pumpWidget(
        SetTraceApp(plans: plans, workouts: workouts, preferences: prefs),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        other,
      );
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      final platform = AndroidPlanTransferPlatform();
      for (final locale in [const Locale('en'), const Locale('zh')]) {
        await start(locale);
        strings = lookupAppLocalizations(locale);
        // Creation and editor validate application-owned copy and decimal input.
        await tap(strings.newPlan);
        final planName = 'QA-${locale.languageCode}-中文保留';
        await tester.enterText(find.byType(TextField), planName);
        await tap(strings.save);
        await tap(planName);
        await tap(strings.addExerciseAction);
        await tester.enterText(
          find.byKey(const ValueKey('exercise-name')),
          '划船 ${locale.languageCode}',
        );
        await tester.pumpAndSettle();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pumpAndSettle();
        final weight = find.byKey(const ValueKey('exercise-weight'));
        await tester.scrollUntilVisible(
          weight,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(weight, '45,5');
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(weight).controller!.text, '45,5');
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pumpAndSettle();
        await shot('editor-${locale.languageCode}');
        await tap(strings.saveExercise);
        final plan = (await plans.listPlans()).firstWhere(
          (p) => p.name == planName,
        );
        expect(plan.exercises.single.defaultWeightKg, 45.5);
        await tap(strings.startWorkout);
        await shot('prepare-${locale.languageCode}');
        await tap(strings.startWorkout);
        await shot('workout-${locale.languageCode}');
        await tap(strings.completeSet);
        final before = (await workouts.getActive())!;
        expect(before.completedSets, 1);
        expect(before.restEndAt, isNotNull);
        await shot('rest-${locale.languageCode}');
        // Complete a full workout through the normal rest controls.
        for (var set = 2; set <= 4; set++) {
          await tap(strings.skip);
          await tap(strings.completeSet);
        }
        await shot('finish-${locale.languageCode}');
        await tap(strings.saveCompleted);
        expect(await workouts.getActive(), isNull);
        final history = await workouts.listHistory();
        expect(
          history.any((s) => s.planName == planName && s.completedSets == 4),
          isTrue,
        );
        // Return from the details route, then verify history and its saved snapshot.
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tap(strings.historyTab);
        await shot('history-${locale.languageCode}');
        await tap(planName);
        await shot('history-detail-${locale.languageCode}');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tap(strings.plansTab);
        // Actual native bridge writes to public Downloads, including collision avoidance.
        final snapshot = const PlanTransferCodec().encode(
          PlanTransferDocument(
            await plans.exportPlans({plan.id}),
            exportedAt: DateTime.now().toUtc(),
          ),
        );
        final saved = await platform.saveFile(snapshot);
        expect(saved.location, 'downloads');
        expect(saved.fileName, startsWith('SetTrace-plans-'));
        final bytes = await File('/sdcard/Download/${saved.fileName}')
            .readAsString();
        expect(bytes, snapshot);
        final decoded = const PlanTransferCodec().decode(bytes);
        expect(decoded.plans.single.exercises.single.defaultWeightKg, 45.5);
        // Also exercise export success feedback and old Chinese filename-independent content.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => PlanExportPage(plans: plans, platform: platform),
          ),
        );
        await tester.pumpAndSettle();
        await tap(strings.exportFile);
        await shot('export-${locale.languageCode}');
        expect(find.textContaining('SetTrace-plans-'), findsOneWidget);
        navigator.pop();
        await tester.pumpAndSettle();
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => PlanImportPage(plans: plans, platform: platform),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('plan-import-text')),
          bytes,
        );
        await tester.pumpAndSettle();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pumpAndSettle();
        await tap(strings.previewPlans);
        await shot('import-${locale.languageCode}');
        final importedName = planName + strings.importSuffix(1);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('import-name-0')))
              .controller!
              .text,
          importedName,
        );
        await tap(strings.confirmImport);
        expect(
          (await plans.listPlans()).any((p) => p.name == importedName),
          isTrue,
        );
        // Unknown exceptions are not exposed; all original user names stay intact.
        expect((await plans.getPlan(plan.id))!.name, planName);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );
}
