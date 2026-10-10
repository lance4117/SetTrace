import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/language_settings.dart';
import '../../l10n/localization.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  final Locale locale;
  final Future<void> Function(Locale) onLocaleChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool savingLanguage = false;
  bool languageError = false;

  Future<void> changeLanguage(Locale? selected) async {
    if (selected == null || savingLanguage || selected == widget.locale) return;
    setState(() {
      savingLanguage = true;
      languageError = false;
    });
    try {
      await widget.onLocaleChanged(selected);
    } catch (_) {
      if (mounted) setState(() => languageError = true);
    } finally {
      if (mounted) setState(() => savingLanguage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final strings = context.l10n;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            strings.settings,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Text(
            strings.appearance,
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: RadioGroup<ThemeMode>(
              groupValue: widget.mode,
              onChanged: (selected) {
                if (selected != null) widget.onModeChanged(selected);
              },
              child: Column(
                children: [
                  for (final (value, label) in [
                    (ThemeMode.system, strings.systemTheme),
                    (ThemeMode.light, strings.lightTheme),
                    (ThemeMode.dark, strings.darkTheme),
                  ])
                    RadioListTile<ThemeMode>(
                      title: Text(label),
                      value: value,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(strings.language, style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 12),
          AppCard(
            child: RadioGroup<Locale>(
              groupValue: widget.locale,
              onChanged: changeLanguage,
              child: Column(
                children: [
                  for (final locale in languageOptions())
                    RadioListTile<Locale>(
                      key: ValueKey('language-${locale.toLanguageTag()}'),
                      title: Text(languageSelfName(locale)),
                      value: locale,
                      enabled: !savingLanguage,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          if (savingLanguage) const LinearProgressIndicator(),
          if (languageError)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                strings.languageSaveFailed,
                style: TextStyle(color: colors.danger),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            strings.localDataNote,
            style: TextStyle(color: colors.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
