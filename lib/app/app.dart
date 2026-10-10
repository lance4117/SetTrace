import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/widgets/app_bottom_nav.dart';
import '../features/history/history_page.dart';
import '../features/plans/plan_repository.dart';
import '../features/plans/plans_page.dart';
import '../features/settings/settings_page.dart';
import '../features/workout/workout_models.dart';
import '../features/workout/workout_page.dart';
import '../features/workout/workout_repository.dart';
import 'theme/app_theme.dart';
import '../l10n/language_settings.dart';
import '../l10n/localization.dart';

class SetTraceApp extends StatefulWidget {
  const SetTraceApp({
    super.key,
    required this.plans,
    required this.workouts,
    required this.preferences,
    this.initialLocale,
  });

  final PlanRepository plans;
  final WorkoutRepository workouts;
  final SharedPreferences preferences;
  final Locale? initialLocale;

  @override
  State<SetTraceApp> createState() => _SetTraceAppState();
}

class _SetTraceAppState extends State<SetTraceApp> {
  late ThemeMode mode = _readMode();
  late Locale locale =
      widget.initialLocale ?? readAppLocale(widget.preferences);

  Future<void> setLocale(Locale next) async {
    try {
      final saved = await widget.preferences.setString(
        languagePreferenceKey,
        next.toLanguageTag(),
      );
      if (!saved) throw StateError('languagePreferenceWriteFailed');
    } catch (_) {
      // The legacy preferences API updates its cache before a platform write.
      // Restore that cache after a failed write as well as keeping the UI locale.
      try {
        await widget.preferences.reload();
      } catch (_) {}
      rethrow;
    }
    if (mounted) setState(() => locale = next);
  }

  ThemeMode _readMode() => switch (widget.preferences.getString('theme_mode')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setMode(ThemeMode next) async {
    await widget.preferences.setString('theme_mode', next.name);
    if (mounted) setState(() => mode = next);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SetTrace',
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    home: RootTabs(
      plans: widget.plans,
      workouts: widget.workouts,
      mode: mode,
      onModeChanged: setMode,
      locale: locale,
      onLocaleChanged: setLocale,
    ),
  );
}

class RootTabs extends StatefulWidget {
  const RootTabs({
    super.key,
    required this.plans,
    required this.workouts,
    required this.mode,
    required this.onModeChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final PlanRepository plans;
  final WorkoutRepository workouts;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;
  final Locale locale;
  final Future<void> Function(Locale) onLocaleChanged;

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int index = 0;
  int historyRevision = 0;

  Future<void> openWorkout(WorkoutSessionData session) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            WorkoutPage(workouts: widget.workouts, sessionId: session.id),
      ),
    );
    if (mounted) setState(() => historyRevision++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: index,
      children: [
        PlansPage(
          plans: widget.plans,
          workouts: widget.workouts,
          onOpenWorkout: openWorkout,
        ),
        HistoryPage(workouts: widget.workouts, revision: historyRevision),
        SettingsPage(
          mode: widget.mode,
          onModeChanged: widget.onModeChanged,
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
        ),
      ],
    ),
    bottomNavigationBar: AppBottomNav(
      index: index,
      onChanged: (value) => setState(() {
        index = value;
        if (value == 1) historyRevision++;
      }),
    ),
  );
}
