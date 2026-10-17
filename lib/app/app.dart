import 'dart:async';

import '../features/backup/backup_coordinator.dart';
import '../features/backup/backup_files_platform.dart';
import '../features/backup/backup_pages.dart';
import '../features/backup/data_write_coordinator.dart';
import '../features/backup/live_backup_preferences.dart';
import '../features/plans/plan_transfer_pages.dart';
import '../features/plans/plan_transfer_platform.dart';

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
import 'presentation_observer.dart';
import '../features/rest_alerts/rest_reminder_dialog.dart';
import '../features/rest_alerts/rest_alert_platform.dart';
import 'theme/theme_color_controller.dart';
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
    this.themeColorStore,
    this.noticePreferences,
    this.info = const AppInfoService(),
    this.alerts,
    this.dataWrites,
    this.backupFiles,
  });

  final PlanRepository plans;
  final WorkoutRepository workouts;
  final SharedPreferences preferences;
  final Locale? initialLocale;
  final ThemeColorStore? themeColorStore;
  final NoticePreferences? noticePreferences;
  final AppInfoService info;
  final RestAlertService? alerts;
  final DataWriteCoordinator? dataWrites;
  final BackupFilesPlatform? backupFiles;

  @override
  State<SetTraceApp> createState() => _SetTraceAppState();
}

class _SetTraceAppState extends State<SetTraceApp> with WidgetsBindingObserver {
  late ThemeMode mode = _readMode();
  late final themeColors = ThemeColorController(
    widget.themeColorStore ?? PreferencesThemeColorStore(widget.preferences),
    coordinator: widget.dataWrites,
  );
  BackupCoordinator? backups;
  bool backupReady = false, backupCheckFailed = false;
  bool startupBackupOutcome = false;

  Future<void> initializeBackup() async {
    if (mounted) setState(() => backupCheckFailed = false);
    try {
      await backups!.reconcileStartup();
      final operations = await backups!.metadata.operations();
      startupBackupOutcome = operations.any(
        (op) =>
            op['kind'] != 'export' &&
            op['result_seen'] == 0 &&
            [
              'completed',
              'aborted',
              'settings_skipped',
              'settings_pending',
              'core_committed',
            ].contains(op['phase']),
      );
      await initializeAppLocale(widget.preferences);
      if (!mounted) return;
      setState(() => backupReady = true);
      startAlerts();
      schedulePresentation();
    } catch (_) {
      widget.dataWrites?.restrict();
      if (mounted) setState(() => backupCheckFailed = true);
    }
  }

  Future<void> backupCommitted() async {
    pendingTap = null;
    pendingTapDetails = null;
    shownRestIds.clear();
    rootKey.currentState?.refreshDataset();
    await widget.alerts?.synchronize(expireElapsed: true);
  }

  void colorChanged() {
    if (mounted) setState(() {});
  }

  late Locale locale =
      widget.initialLocale ?? readAppLocale(widget.preferences);

  final rootKey = GlobalKey<RootTabsState>();
  final navigatorKey = GlobalKey<NavigatorState>();
  Timer? alertTicker;
  bool permissionDialog = false, reportedReminderFailure = false;
  int? pendingTap;
  RestAlertTap? pendingTapDetails;
  final shownRestIds = <int>{};
  final restDialogKey = GlobalKey<RestReminderDialogState>();
  late final presentationObserver = PresentationObserver(() {
    if (mounted) schedulePresentation();
  });
  late final NoticePreferences noticePreferences =
      widget.noticePreferences ?? NoticePreferences(widget.preferences);
  bool startupReady = false, presentationRunning = false;

  bool get foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void schedulePresentation() {
    if (backups != null &&
        (!backupReady || widget.dataWrites?.blocked == true)) {
      return;
    }
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
        if (presentationObserver.blocked) return;
        if (startupBackupOutcome) {
          startupBackupOutcome = false;
          await rootKey.currentState?.openBackup();
          if (!mounted || !foreground || presentationObserver.blocked) return;
        }
        final tap = pendingTap;
        final details = pendingTapDetails;
        pendingTap = null;
        pendingTapDetails = null;
        if (tap != null) {
          final opened =
              await rootKey.currentState?.openFromNotification(tap) ?? false;
          if (opened && details != null && widget.alerts != null) {
            try {
              await widget.alerts!.acknowledgeTap(details);
            } catch (_) {
              if (mounted && navigatorKey.currentContext != null) {
                showAppSnackBar(
                  navigatorKey.currentContext!,
                  (l) => l.restReminderConfirmFailed,
                  onRetry: () => openNotificationDetails(details),
                );
              }
            }
          }
        }
        if (!mounted ||
            !foreground ||
            presentationObserver.blocked ||
            permissionDialog ||
            widget.alerts?.permissionNeeded == true) {
          return;
        }
        final alerts = widget.alerts;
        if (alerts != null) {
          final pending = alerts.awaiting.where(
            (e) => !shownRestIds.contains(e.id),
          );
          if (pending.isNotEmpty) {
            final event = pending.first;
            shownRestIds.add(event.id);
            await showDialog<void>(
              context: navigatorKey.currentContext!,
              barrierDismissible: false,
              barrierColor: Colors.black.withValues(alpha: .5),
              routeSettings: const RouteSettings(name: 'rest-reminder'),
              builder: (_) => RestReminderDialog(
                key: restDialogKey,
                alerts: alerts,
                event: event,
              ),
            );
          }
        }
      } finally {
        presentationRunning = false;
        if (mounted && foreground && startupReady) {
          if (pendingTap != null &&
              !permissionDialog &&
              !presentationObserver.blocked) {
            schedulePresentation();
          }
          alertsChanged();
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void initState() {
    super.initState();
    themeColors.addListener(colorChanged);
    WidgetsBinding.instance.addObserver(this);
    if (widget.backupFiles != null && widget.dataWrites != null) {
      widget.dataWrites!.restrict();
      backups = BackupCoordinator(
        db: widget.plans.db,
        writes: widget.dataWrites!,
        files: widget.backupFiles!,
        appVersion: () async {
          final version = await widget.info.readVersion();
          return '${version.version}+${version.buildNumber}';
        },
        preferences: LiveBackupPreferences(
          db: widget.plans.db,
          colors: themeColors,
          mode: () => mode.name,
          language: () => locale.toLanguageTag(),
          saveMode: (value) =>
              setMode(ThemeMode.values.byName(value), fromBackup: true),
          saveLanguage: (value) => setLocale(Locale(value), fromBackup: true),
        ),
        onCommitted: backupCommitted,
      );
      themeColors.beforeWrite = () => backups!.supersedeSettings('themeColor');
      widget.alerts?.repository.beforePreferencesWrite = () =>
          backups!.supersedeSettings('reminder');
      unawaited(initializeBackup());
    } else {
      backupReady = true;
      startAlerts();
      schedulePresentation();
    }
  }

  void startAlerts() {
    final alerts = widget.alerts;
    if (alerts != null) {
      alerts.onTap = openNotification;
      alerts.onTapDetails = openNotificationDetails;
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
    if (!backupReady || widget.dataWrites?.blocked == true) return;
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
      final tap = await alerts.takeInitialTapDetails();
      if (tap != null && mounted) openNotificationDetails(tap);
    } catch (_) {
      alertsChanged();
    }
  }

  void openNotification(int id) {
    if (!mounted) return;
    pendingTap = id;
    pendingTapDetails = null;
    restDialogKey.currentState?.dismiss();
    schedulePresentation();
  }

  void openNotificationDetails(RestAlertTap tap) {
    if (!mounted) return;
    pendingTap = tap.sessionId;
    pendingTapDetails = tap;
    restDialogKey.currentState?.dismiss();
    schedulePresentation();
  }

  void alertsChanged() {
    if (!mounted || widget.alerts == null) return;
    final alerts = widget.alerts!;
    if (startupReady &&
        !presentationRunning &&
        !permissionDialog &&
        !presentationObserver.blocked &&
        foreground &&
        alerts.awaiting.any((e) => !shownRestIds.contains(e.id))) {
      schedulePresentation();
    }
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
        !presentationObserver.blocked &&
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
        presentationObserver.blocked ||
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
      schedulePresentation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        backupReady &&
        widget.dataWrites?.blocked != true) {
      schedulePresentation();
      widget.alerts?.synchronize(expireElapsed: true).catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    backups?.dispose();
    themeColors.removeListener(colorChanged);
    themeColors.dispose();
    alertTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.workouts.onChanged = null;
    widget.alerts?.removeListener(alertsChanged);
    widget.alerts?.dispose();
    super.dispose();
  }

  Future<void> setLocale(
    Locale next, {
    bool fromBackup = false,
  }) => _settingsWrite(() async {
    if (!fromBackup) await backups?.supersedeSettings('languageTag');
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
      if (!fromBackup) await setupAlerts();
    }
  });

  Future<void> _settingsWrite(Future<void> Function() action) =>
      widget.dataWrites?.write(action) ?? action();

  ThemeMode _readMode() => switch (widget.preferences.getString('theme_mode')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setMode(ThemeMode next, {bool fromBackup = false}) =>
      _settingsWrite(() async {
        if (!fromBackup) await backups?.supersedeSettings('themeMode');
        try {
          final saved = await widget.preferences.setString(
            'theme_mode',
            next.name,
          );
          if (!saved) throw StateError('themePreferenceWriteFailed');
        } catch (_) {
          try {
            await widget.preferences.reload();
          } catch (_) {}
          rethrow;
        }
        if (mounted) setState(() => mode = next);
      });

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
    navigatorObservers: [presentationObserver],
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: AppTheme.forPreset(Brightness.light, themeColors.selected),
    darkTheme: AppTheme.forPreset(Brightness.dark, themeColors.selected),
    themeMode: mode,
    home: !backupReady
        ? BackupStartupPage(
            failed: backupCheckFailed,
            onRetry: initializeBackup,
          )
        : RootTabs(
            key: rootKey,
            info: widget.info,
            backups: backups,
            themeColors: themeColors,
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
    this.backups,
    this.themeColors,
    this.info = const AppInfoService(),
    required this.plans,
    required this.workouts,
    required this.mode,
    required this.onModeChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final RestAlertService? alerts;
  final BackupCoordinator? backups;
  final ThemeColorController? themeColors;
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
  void refreshDataset() {
    if (mounted) {
      setState(() {
        historyRevision++;
        workoutRevision++;
        datasetRevision++;
      });
    }
  }

  int datasetRevision = 0;

  Future<void> openBackup() async {
    final service = widget.backups;
    if (service == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'backup'),
        builder: (_) => BackupPage(
          service: service,
          onWorkout: () async {
            final active = await widget.workouts.getActive();
            if (active != null && mounted) await openWorkout(active);
          },
          onHistory: () async {
            Navigator.of(context).popUntil((r) => r.isFirst);
            if (mounted) {
              setState(() {
                index = 1;
                historyRevision++;
              });
            }
          },
          onPlanImport: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlanImportPage(
                  plans: widget.plans,
                  platform: AndroidPlanTransferPlatform(),
                ),
              ),
            );
            refreshDataset();
          },
        ),
      ),
    );
    refreshDataset();
  }

  int index = 0;
  int historyRevision = 0;
  int workoutRevision = 0;
  int? openSessionId;
  GlobalKey<WorkoutPageState>? workoutKey;
  bool handlingNotification = false;

  Future<bool> openFromNotification(int id) async {
    if (handlingNotification || !mounted) return false;
    handlingNotification = true;
    try {
      final session = await widget.workouts.getSession(id);
      if (!mounted) return false;
      if (session == null || !session.inProgress) {
        showAppSnackBar(context, (l) => l.notificationWorkoutUnavailable);
        return false;
      }
      await widget.workouts.normalizeRest(id);
      if (mounted) {
        if (openSessionId == id) {
          await workoutKey?.currentState?.reload();
        } else {
          unawaited(openWorkout((await widget.workouts.getSession(id))!));
        }
      }
      await WidgetsBinding.instance.endOfFrame;
      final page = workoutKey?.currentState;
      if (!mounted || openSessionId != id || page == null) return false;
      await page.reload();
      return mounted && openSessionId == id && page.loadedSuccessfully;
    } catch (_) {
      if (mounted) showAppSnackBar(context, (l) => l.loadFailed);
      return false;
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
          alerts: widget.alerts,
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
          key: ValueKey('plans-$datasetRevision'),
          plans: widget.plans,
          workouts: widget.workouts,
          onOpenWorkout: openWorkout,
          workoutRevision: workoutRevision,
        ),
        HistoryPage(
          key: ValueKey('history-$datasetRevision'),
          workouts: widget.workouts,
          revision: historyRevision,
        ),
        SettingsPage(
          onBackup: widget.backups == null ? null : openBackup,
          themeColors: widget.themeColors,
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
