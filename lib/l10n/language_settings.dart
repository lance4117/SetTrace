import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'generated/app_localizations.dart';

const languagePreferenceKey = 'app_language';

Locale? parseLocaleTag(String? tag) {
  if (tag == null ||
      !RegExp(r'^[a-zA-Z]{2,3}(?:-[a-zA-Z]{4})?(?:-(?:[a-zA-Z]{2}|[0-9]{3}))?$')
          .hasMatch(tag)) {
    return null;
  }
  final parts = tag.split('-');
  String? script, country;
  for (final part in parts.skip(1)) {
    if (part.length == 4) {
      script = part[0].toUpperCase() + part.substring(1).toLowerCase();
    } else {
      country = part.toUpperCase();
    }
  }
  return Locale.fromSubtags(
    languageCode: parts.first.toLowerCase(),
    scriptCode: script,
    countryCode: country,
  );
}

Locale resolveAppLocale(Locale? preferred, {Iterable<Locale>? supported}) {
  final locales = (supported ?? AppLocalizations.supportedLocales).toList();
  final fallback = locales.firstWhere((l) => l.toLanguageTag() == 'en');
  if (preferred == null ||
      !locales.any((l) => l.languageCode == preferred.languageCode)) {
    return fallback;
  }
  return basicLocaleListResolution([preferred], locales);
}

Locale readAppLocale(
  SharedPreferences preferences, {
  List<Locale>? systemLocales,
}) {
  try {
    final saved = preferences.getString(languagePreferenceKey);
    if (saved != null) return resolveAppLocale(parseLocaleTag(saved));
    return resolveAppLocale(
      (systemLocales ?? WidgetsBinding.instance.platformDispatcher.locales)
          .firstOrNull,
    );
  } catch (_) {
    return resolveAppLocale(null);
  }
}

Future<Locale> initializeAppLocale(
  SharedPreferences preferences, {
  List<Locale>? systemLocales,
}) async {
  final locale = readAppLocale(preferences, systemLocales: systemLocales);
  try {
    if (preferences.getString(languagePreferenceKey) !=
        locale.toLanguageTag()) {
      await preferences.setString(
        languagePreferenceKey,
        locale.toLanguageTag(),
      );
    }
  } catch (_) {
    // A preferences failure must not prevent the user from opening their data.
    // Explicit language changes report write failures in SettingsPage.
  }
  return locale;
}

List<Locale> languageOptions({Iterable<Locale>? supported}) {
  int rank(Locale locale) => switch (locale.toLanguageTag()) {
    'en' => 0,
    'zh' => 1,
    _ => 2,
  };
  return (supported ?? AppLocalizations.supportedLocales).toList()
    ..sort((a, b) {
      final priority = rank(a).compareTo(rank(b));
      return priority != 0
          ? priority
          : a.toLanguageTag().compareTo(b.toLanguageTag());
    });
}

String languageSelfName(Locale locale) =>
    lookupAppLocalizations(locale).languageSelfName;
