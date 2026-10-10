import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settrace/l10n/language_settings.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:settrace/l10n/error_messages.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:settrace/features/workout/workout_failure.dart';

import '../tool/check_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting());
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('primary system language, compatibility, invalid preference and persistence', () async {
    for (final tag in ['zh-CN', 'zh-TW', 'zh-HK', 'zh-Hant']) {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(
        await initializeAppLocale(prefs, systemLocales: [parseLocaleTag(tag)!]),
        const Locale('zh'),
      );
      expect(prefs.getString(languagePreferenceKey), 'zh');
    }
    for (final locales in [
      <Locale>[],
      [const Locale('en', 'GB')],
      [const Locale('fr', 'FR'), const Locale('zh')],
    ]) {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(
        await initializeAppLocale(prefs, systemLocales: locales),
        const Locale('en'),
      );
      expect(prefs.getString(languagePreferenceKey), 'en');
    }
    for (final value in ['invalid-tag-???', 'fr-FR', 42]) {
      SharedPreferences.setMockInitialValues({languagePreferenceKey: value});
      final prefs = await SharedPreferences.getInstance();
      expect(
        await initializeAppLocale(prefs, systemLocales: [const Locale('zh')]),
        const Locale('en'),
      );
    }
    SharedPreferences.setMockInitialValues({
      languagePreferenceKey: 'zh-Hant-TW',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(
      await initializeAppLocale(prefs, systemLocales: [const Locale('en')]),
      const Locale('zh'),
    );
    expect(languageOptions(), [const Locale('en'), const Locale('zh')]);
    expect(languageOptions().map(languageSelfName), ['English', '中文']);
  });
  test('formatting and complete plural messages preserve numeric meanings', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(en.setCount(0), '0 sets');
    expect(en.setCount(1), '1 set');
    expect(en.setCount(3), '3 sets');
    expect(zh.setCount(3), '3 组');
    expect(AppFormats(en).duration(0), '0 minutes');
    expect(AppFormats(en).duration(3600), '1 hour 0 minutes');
    expect(AppFormats(en).duration(7260), '2 hours 1 minute');
    expect(AppFormats(en).month(DateTime(2026, 10)), 'October 2026');
    expect(AppFormats(zh).month(DateTime(2026, 10)), '2026年10月');
    expect(AppFormats(en).weightLabel(45.5), '45.5 kg');
    expect(AppFormats(en).date(DateTime(2026, 10, 10)), 'Oct 10, 2026');
    expect(AppFormats(en).time(DateTime(2026, 10, 10, 17, 30)), '17:30');
    for (final locale in AppLocalizations.supportedLocales) {
      for (final number in [1, 2, 100, 999999999]) {
        final suffix = lookupAppLocalizations(locale).importSuffix(number);
        expect(suffix.trim(), isNotEmpty);
        expect(suffix.characters.length, lessThan(40));
      }
    }
  });
  test('decimal parser accepts a single separator and rejects ambiguity', () {
    for (final text in ['45.5', '45,5', ' 45,5 ', '.5', ',5']) {
      expect(
        parseWeight(text),
        text.trim().startsWith('.') || text.trim().startsWith(',') ? 0.5 : 45.5,
      );
    }
    for (final text in [
      '',
      '0',
      '-2',
      'NaN',
      'Infinity',
      '1,234.5',
      '1.234,5',
      '1,,2',
      '1..2',
      '1e309',
      '1 234',
    ]) {
      expect(parseWeight(text), isNull, reason: text);
    }
  });
  test(
    'structured errors retain location and hide unknown exception detail',
    () {
      final error = PlanTransferException(
        PlanTransferFailure.invalidInteger,
        location: const PlanTransferLocation(
          plan: 2,
          exercise: 3,
          field: PlanTransferField.sets,
        ),
        min: 1,
        max: 100,
      );
      final en = lookupAppLocalizations(const Locale('en'));
      final zh = lookupAppLocalizations(const Locale('zh'));
      expect(failureText(en, error), contains('Plan 2'));
      expect(failureText(en, error), contains('exercise 3'));
      expect(failureText(zh, error), contains('第 2 个计划'));
      expect(
        failureText(en, StateError('secret native stack')),
        en.operationFailed,
      );
      expect(
        failureText(en, WorkoutStateException(WorkoutFailure.planNotFound)),
        en.planNotFound,
      );
      final plans = [
        TransferPlan(name: '原名', exercises: []),
        TransferPlan(name: '原名', exercises: []),
      ];
      expect(
        resolveImportNames(plans, [
          '原名',
        ], suffixFor: en.importSuffix).map((p) => p.name),
        ['原名 (imported)', '原名 (imported 2)'],
      );
      final long = '👨‍👩‍👧‍👦' * 40;
      final result = resolveImportNames(
        [TransferPlan(name: long, exercises: const [])],
        [long],
        suffixFor: en.importSuffix,
      ).single;
      expect(result.name.characters.length, 40);
      expect(result.name, endsWith(' (imported)'));
    },
  );
  test('language pack fixtures reject missing, empty, wrong typed and missing parameters', () {
    final original = jsonDecode(
      File('lib/l10n/app_zh.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final dir = Directory.systemTemp.createTempSync('l10n_fixture_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('lib/l10n/app_en.arb').copySync('${dir.path}/app_en.arb');
    void check(void Function(Map<String, dynamic>) mutate, String expected) {
      final pack = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
      mutate(pack);
      File('${dir.path}/app_zh.arb').writeAsStringSync(jsonEncode(pack));
      expect(checkLanguagePacks(dir).join('\n'), contains(expected));
    }

    check((p) => p.remove('permissionDenied'), 'missing key permissionDenied');
    check((p) => p['permissionDenied'] = ' ', 'permissionDenied: empty');
    check(
      (p) => p['@setCount']['placeholders']['count']['type'] = 'String',
      'setCount: placeholder',
    );
    check((p) => p['setCount'] = '组', 'setCount: missing placeholder count');
    check((p) => p['@@locale'] = 'en', 'duplicate locale');
    check(
      (p) => p['languageSelfName'] = '{language}',
      'invalid languageSelfName',
    );
    expect(checkLanguagePacks(Directory('lib/l10n')), isEmpty);
  });
  test(
    'AST text sink checks both English and Chinese including interpolation',
    () {
      for (final source in [
        "Text('Retry')",
        "Text('重试')",
        "AppButton(label: 'Save')",
        "InputDecoration(hintText: 'Weight')",
        "Semantics(label: 'Complete set')",
        r"Text('Done $count sets')",
      ]) {
        expect(
          checkDartText(
            'void build() { $source; }',
            path: 'bad.dart',
          ).join('\n'),
          contains('bad.dart:1:'),
        );
      }
      expect(
        checkDartText(
          "void build() { Text('SetTrace'); Text('00:30'); Text(strings.retry); const key = 'downloads'; }",
        ),
        isEmpty,
      );
    },
  );
}
