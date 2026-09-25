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

class SetTraceApp extends StatefulWidget {
  const SetTraceApp({super.key, required this.plans, required this.workouts,
    required this.preferences});

  final PlanRepository plans;
  final WorkoutRepository workouts;
  final SharedPreferences preferences;

  @override
  State<SetTraceApp> createState() => _SetTraceAppState();
}

class _SetTraceAppState extends State<SetTraceApp> {
  late ThemeMode mode = _readMode();

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
    title: '训练本', debugShowCheckedModeBanner: false,
    theme: AppTheme.light, darkTheme: AppTheme.dark, themeMode: mode,
    home: RootTabs(plans: widget.plans, workouts: widget.workouts,
      mode: mode, onModeChanged: setMode),
  );
}

class RootTabs extends StatefulWidget {
  const RootTabs({super.key, required this.plans, required this.workouts,
    required this.mode, required this.onModeChanged});

  final PlanRepository plans;
  final WorkoutRepository workouts;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int index = 0;
  int historyRevision = 0;

  Future<void> openWorkout(WorkoutSessionData session) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WorkoutPage(workouts: widget.workouts, sessionId: session.id)));
    if (mounted) setState(() => historyRevision++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: [
      PlansPage(plans: widget.plans, workouts: widget.workouts,
        onOpenWorkout: openWorkout),
      HistoryPage(workouts: widget.workouts, revision: historyRevision),
      SettingsPage(mode: widget.mode, onModeChanged: widget.onModeChanged),
    ]),
    bottomNavigationBar: AppBottomNav(index: index,
      onChanged: (value) => setState(() {
        index = value;
        if (value == 1) historyRevision++;
      })),
  );
}
