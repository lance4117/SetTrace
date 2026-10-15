import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/widgets/app_bottom_nav.dart';
import '../features/about/app_info_service.dart';
import '../features/about/app_notice_dialog.dart';
import '../features/about/notice_preferences.dart';
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
import '../features/rest_alerts/rest_alert_service.dart';

class SetTraceApp extends StatefulWidget {
  const SetTraceApp({
    super.key,
    required this.plans,
    required this.workouts,
    required this.preferences,
    this.initialLocale,
    this.noticePreferences,
    this.info = const AppInfoService(),
    this.alerts,
  });

  final PlanRepository plans;
  final WorkoutRepository workouts;
  final SharedPreferences preferences;
  final Locale? initialLocale;
  final NoticePreferences? noticePreferences;
  final AppInfoService info;
  final RestAlertService? alerts;

  @override
  State<SetTraceApp> createState() => _SetTraceAppState();
}

class _SetTraceAppState extends State<SetTraceApp> with WidgetsBindingObserver {
  late ThemeMode mode = _readMode();
  late Locale locale =
      widget.initialLocale ?? readAppLocale(widget.preferences);

  final rootKey = GlobalKey<RootTabsState>();
  final navigatorKey = GlobalKey<NavigatorState>();
  Timer? alertTicker;
  bool permissionDialog = false, reportedReminderFailure = false;
  int? pendingTap;
  late final NoticePreferences noticePreferences =
      widget.noticePreferences ?? NoticePreferences(widget.preferences);
  bool startupReady = false, presentationRunning = false;

  bool get foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void schedulePresentation() {
    if (!mounted || presentationRunning || !foreground) return;
    presentationRunning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted || !foreground || rootKey.currentContext == null) return;
        if (!startupReady) {
          if (!noticePreferences.hasSeenCurrent) {
            await showAppNotice(
              rootKey.currentContext!,
              preferences: noticePreferences,
            );
          }
          startupReady = true;
        }
        if (!mounted || !foreground || permissionDialog) return;
        final tap = pendingTap;
        pendingTap = null;
        if (tap != null) await rootKey.currentState?.openFromNotification(tap);
      } finally {
        presentationRunning = false;
        if (mounted && foreground && startupReady) {
          if (pendingTap != null && !permissionDialog) schedulePresentation();
          alertsChanged();
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    schedulePresentation();
    final alerts = widget.alerts;
    if (alerts != null) {
      alerts.onTap = openNotification;
      alerts.onDelivered = (body) {
        final context = navigatorKey.currentContext;
        if (context != null && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(body)));
        }
      };
      alerts.addListener(alertsChanged);
      widget.workouts.onChanged = () => syncAlerts(offerPermission: true);
      setupAlerts(expireElapsed: true);
      alertTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          syncAlerts();
        }
      });
    }
  }

  void syncAlerts({bool offerPermission = false}) {
    widget.alerts
        ?.synchronize(offerPermission: offerPermission)
        .catchError((Object _) {});
  }

  Future<void> setupAlerts({bool expireElapsed = false}) async {
    final alerts = widget.alerts;
    if (alerts == null) return;
    try {
      final strings = await AppLocalizations.delegate.load(locale);
      await alerts.configure(strings, expireElapsed: expireElapsed);
      final tap = await alerts.takeInitialTap();
      if (tap != null && mounted) openNotification(tap);
    } catch (_) {
      alertsChanged();
    }
  }

  void openNotification(int id) {
    if (!mounted) return;
    pendingTap = id;
    schedulePresentation();
  }

  void alertsChanged() {
    if (!mounted || widget.alerts == null) return;
    final alerts = widget.alerts!;
    if (alerts.failed && !reportedReminderFailure) {
      reportedReminderFailure = true;
      final context = navigatorKey.currentContext;
      if (context != null) {
        showAppSnackBar(
          context,
          (l) => l.restAlertsFailed,
          onRetry: syncAlerts,
        );
      }
    } else if (!alerts.failed) {
      reportedReminderFailure = false;
    }
    if (alerts.permissionNeeded &&
        !permissionDialog &&
        startupReady &&
        !presentationRunning &&
        foreground) {
      explainNotificationPermission();
    }
  }

  Future<void> explainNotificationPermission() async {
    final context = navigatorKey.currentContext;
    if (context == null ||
        permissionDialog ||
        !mounted ||
        !startupReady ||
        presentationRunning ||
        !foreground) {
      return;
    }
    permissionDialog = true;
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.restAlertsEnabled),
          content: Text(context.l10n.restAlertsExplain),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.allowRestNotifications),
            ),
          ],
        ),
      );
      await widget.alerts!.acknowledgePermission(request: accepted == true);
    } catch (_) {
      syncAlerts();
    } finally {
      permissionDialog = false;
      if (pendingTap != null) schedulePresentation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      schedulePresentation();
      widget.alerts?.synchronize(expireElapsed: true).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    alertTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.workouts.onChanged = null;
    widget.alerts?.removeListener(alertsChanged);
    widget.alerts?.dispose();
    super.dispose();
  }

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
    if (mounted) {
      setState(() => locale = next);
      await setupAlerts();
    }
  }

  ThemeMode _readMode() => switch (widget.preferences.getString('theme_mode')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setMode(ThemeMode next) async {
    try {
      final saved = await widget.preferences.setString('theme_mode', next.name);
      if (!saved) throw StateError('themePreferenceWriteFailed');
    } catch (_) {
      try {
        await widget.preferences.reload();
      } catch (_) {}
      rethrow;
    }
    if (mounted) setState(() => mode = next);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SetTrace',
    themeAnimationDuration:
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200),
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    home: RootTabs(
      key: rootKey,
      info: widget.info,
      alerts: widget.alerts,
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
    this.alerts,
    this.info = const AppInfoService(),
    required this.plans,
    required this.workouts,
    required this.mode,
    required this.onModeChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final RestAlertService? alerts;
  final AppInfoService info;
  final PlanRepository plans;
  final WorkoutRepository workouts;
  final ThemeMode mode;
  final FutureOr<void> Function(ThemeMode) onModeChanged;
  final Locale locale;
  final Future<void> Function(Locale) onLocaleChanged;

  @override
  State<RootTabs> createState() => RootTabsState();
}

class RootTabsState extends State<RootTabs> {
  int index = 0;
  int historyRevision = 0;
  int workoutRevision = 0;
  int? openSessionId;
  GlobalKey<WorkoutPageState>? workoutKey;
  bool handlingNotification = false;

  Future<void> openFromNotification(int id) async {
    if (handlingNotification || !mounted) return;
    handlingNotification = true;
    try {
      final session = await widget.workouts.getSession(id);
      if (!mounted) return;
      if (session == null || !session.inProgress) {
        showAppSnackBar(context, (l) => l.notificationWorkoutUnavailable);
        return;
      }
      await widget.workouts.normalizeRest(id);
      if (mounted) {
        if (openSessionId == id) {
          await workoutKey?.currentState?.reload();
        } else {
          unawaited(openWorkout((await widget.workouts.getSession(id))!));
        }
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, (l) => l.loadFailed);
    } finally {
      handlingNotification = false;
    }
  }

  Future<void> openWorkout(WorkoutSessionData session) async {
    if (openSessionId == session.id) {
      await workoutKey?.currentState?.reload();
      return;
    }
    if (openSessionId != null) Navigator.of(context).popUntil((r) => r.isFirst);
    openSessionId = session.id;
    final pageKey = GlobalKey<WorkoutPageState>();
    workoutKey = pageKey;
    final route = Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutPage(
          key: pageKey,
          workouts: widget.workouts,
          sessionId: session.id,
        ),
      ),
    );
    widget.alerts?.synchronize(offerPermission: true).catchError((Object _) {});
    await route;
    if (openSessionId == session.id) openSessionId = null;
    if (mounted) {
      setState(() {
        historyRevision++;
        workoutRevision++;
      });
    }
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
          workoutRevision: workoutRevision,
        ),
        HistoryPage(workouts: widget.workouts, revision: historyRevision),
        SettingsPage(
          info: widget.info,
          alerts: widget.alerts,
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
