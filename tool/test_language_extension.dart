import 'dart:convert';
import 'dart:io';

import 'check_localizations.dart';

/// Isolated generation smoke test. The synthetic French pack tests discovery,
/// ICU and locale data; it is deliberately not a production translation.
Future<void> main(List<String> args) async {
  final dir = await Directory.systemTemp.createTemp('settrace_third_language_');
  try {
    if (args.contains('--build')) {
      void copyTree(Directory source, String relative) {
        for (final entry in source.listSync()) {
          final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
          if ({'build', '.gradle', '.cxx', 'generated'}.contains(name)) {
            continue;
          }
          final target = '$relative/$name';
          if (entry is Directory) {
            copyTree(entry, target);
          } else if (entry is File) {
            final file = File('${dir.path}/$target');
            file.parent.createSync(recursive: true);
            entry.copySync(file.path);
          }
        }
      }

      for (final name in ['lib', 'android']) {
        copyTree(Directory(name), name);
      }
    }
    for (final name in [
      'pubspec.yaml',
      'pubspec.lock',
      'l10n.yaml',
      'lib/l10n/app_en.arb',
      'lib/l10n/app_zh.arb',
      'lib/l10n/language_settings.dart',
      'lib/l10n/localization.dart',
    ]) {
      final target = File('${dir.path}/$name');
      target.parent.createSync(recursive: true);
      File(name).copySync(target.path);
    }
    final pack = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    pack['@@locale'] = 'fr';
    pack['languageSelfName'] = 'Français';
    pack['settings'] = 'Paramètres';
    pack['setCount'] =
        '{count, plural, =0{0 série} one{{count} série} other{{count} séries}}';
    pack['importSuffix'] =
        '{number, plural, =1{ (importé)} other{ (importé {number})}}';
    final resource = File('${dir.path}/lib/l10n/app_fr.arb')
      ..writeAsStringSync(jsonEncode(pack));
    final errors = checkLanguagePacks(resource.parent);
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
    Future<ProcessResult> flutter(List<String> args) => Process.run(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      args,
      workingDirectory: dir.path,
      runInShell: Platform.isWindows,
    );
    Future<void> run(List<String> args) async {
      final result = await flutter(args);
      if (result.exitCode != 0) {
        throw StateError(
          '${args.join(' ')}\n${result.stdout}\n${result.stderr}',
        );
      }
    }

    await run(['pub', 'get', '--offline']);
    await run(['gen-l10n']);
    final test = File('${dir.path}/test/extension_test.dart');
    test.parent.createSync();
    test.writeAsStringSync(r'''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:settrace/l10n/language_settings.dart';
void main() {
  test('language pack alone extends options, primary match, plurals and formats', () async {
    await initializeDateFormatting();
    expect(languageOptions().map((l) => l.languageCode), ['en', 'zh', 'fr']);
    expect(languageOptions().map(languageSelfName), ['English', '中文', 'Français']);
    expect(resolveAppLocale(const Locale('fr', 'FR')), const Locale('fr'));
    final strings = lookupAppLocalizations(const Locale('fr'));
    expect(strings.settings, 'Paramètres');
    expect(strings.setCount(1), '1 série');
    expect(strings.setCount(2), '2 séries');
    expect(AppFormats(strings).weight(45.5), '45,5');
    expect(AppFormats(strings).month(DateTime(2026, 10)), 'octobre 2026');
  });
}
''');
    await run(['test', '--reporter', 'expanded']);
    if (args.contains('--build')) await run(['build', 'apk', '--debug']);
    pack['setCount'] = '{count, plural, one{broken}';
    resource.writeAsStringSync(jsonEncode(pack));
    final malformed = await flutter(['gen-l10n']);
    if (malformed.exitCode == 0 ||
        !('${malformed.stdout}${malformed.stderr}').contains('setCount')) {
      throw StateError(
        'Invalid ICU fixture was not rejected with a message key',
      );
    }
    stdout.writeln(
      'Isolated third-language options, resolution, ICU, formatting and invalid-ICU fixture passed. Production still contains only en and zh.',
    );
  } finally {
    final expectedRoot = Directory.systemTemp.absolute.path;
    if (!dir.absolute.path.startsWith(expectedRoot) ||
        !dir.uri.pathSegments.any(
          (s) => s.startsWith('settrace_third_language_'),
        )) {
      throw StateError('Unexpected temporary project path');
    }
    await dir.delete(recursive: true);
  }
}
