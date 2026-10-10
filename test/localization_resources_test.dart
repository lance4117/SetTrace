import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:settrace/l10n/localization.dart';
import 'package:settrace/l10n/language_settings.dart';

void main() {
  test('every generated locale has usable name, delegates and import suffix', () {
    for (final locale in languageOptions()) {
      final strings = lookupAppLocalizations(locale);
      expect(
        strings.languageSelfName.trim(),
        isNotEmpty,
        reason: '$locale.languageSelfName',
      );
      expect(
        GlobalMaterialLocalizations.delegate.isSupported(locale),
        isTrue,
        reason: '$locale: official widget locale data must exist',
      );
      for (final number in [1, 2, 100, 999999999]) {
        final suffix = strings.importSuffix(number);
        expect(
          suffix.trim(),
          isNotEmpty,
          reason: '$locale.importSuffix($number)',
        );
        expect(
          suffix.characters.length,
          lessThan(40),
          reason:
              '$locale.importSuffix($number) must leave space for the original name',
        );
      }
    }
  });
}
