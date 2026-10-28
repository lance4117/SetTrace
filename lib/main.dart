import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'l10n/language_settings.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'core/database/app_database.dart';
import 'features/plans/plan_repository.dart';
import 'features/workout/workout_repository.dart';
import 'features/rest_alerts/rest_alert_repository.dart';
import 'features/rest_alerts/rest_alert_service.dart';
import 'features/rest_alerts/rest_alert_platform.dart';
import 'features/backup/backup_files_platform.dart';
import 'features/backup/data_write_coordinator.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_color_preset.dart';
import 'l10n/localization.dart';
import 'core/diagnostics/diagnostic_contract.dart';
import 'core/diagnostics/diagnostic_errors.dart';
import 'core/diagnostics/diagnostics_client.dart';
import 'core/widgets/app_button.dart';
import 'core/widgets/app_task_layout.dart';
import 'features/diagnostics/diagnostics_controller.dart';
import 'features/diagnostics/diagnostics_pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final writes = DataWriteCoordinator();
  final diagnostics = DiagnosticsClient(
    transport: const AndroidDiagnosticsTransport(),
    epoch: () => writes.diagnosticEpoch,
  );
  DiagnosticsClient.instance = diagnostics;
  installDiagnosticErrorHandlers(diagnostics);
  // No diagnostic failure or disk initialization is a startup prerequisite.
  unawaited(
    diagnostics.overview().then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    ),
  );
  runApp(SetTraceBootstrap(writes: writes, diagnostics: diagnostics));
}

/// L07 does not depend on business repositories. Failed opens never trigger
/// database deletion or replacement, and retries use the existing migration.
class SetTraceBootstrap extends StatefulWidget {
  const SetTraceBootstrap({
    super.key,
    required this.writes,
    required this.diagnostics,
    this.openDatabase = AppDatabase.open,
    this.readPreferences = SharedPreferences.getInstance,
    this.initializeDates = initializeDateFormatting,
  });
  final DataWriteCoordinator writes;
  final DiagnosticsClient diagnostics;
  final Future<AppDatabase> Function() openDatabase;
  final Future<SharedPreferences> Function() readPreferences;
  final Future<void> Function() initializeDates;
  @override
  State<SetTraceBootstrap> createState() => _SetTraceBootstrapState();
}

class _SetTraceBootstrapState extends State<SetTraceBootstrap> {
  late final controller = DiagnosticsController(widget.diagnostics);
  bool busy = false, failed = false;
  int attempts = 0;
  Widget? ready;
  Locale? locale;
  ThemeMode mode = ThemeMode.system;
  ThemeColorPreset color = ThemeColorPreset.teal;
  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    if (busy || ready != null) return;
    setState(() {
      busy = true;
      failed = false;
    });
    AppDatabase? database;
    if (attempts++ > 0) {
      widget.diagnostics.event(
        DiagnosticName.startupRecovery,
        phase: DiagnosticPhase.started,
        fields: {DiagnosticField.count: attempts},
      );
    }
    final operation = widget.diagnostics.operation(
      DiagnosticName.startupDatabase,
    );
    try {
      database = await widget.openDatabase();
      operation.emit(DiagnosticPhase.completed, DiagnosticOutcome.observed);
      final preferences = await widget.readPreferences();
      locale = readAppLocale(preferences);
      mode = switch (preferences.getString('theme_mode')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      color = ThemeColorPreset.parse(preferences.get('theme_color'));
      await widget.initializeDates();
      if (!mounted) {
        await database.close();
        return;
      }
      final db = database.db;
      ready = SetTraceApp(
        initialLocale: locale,
        dataWrites: widget.writes,
        backupFiles: AndroidBackupFilesPlatform(),
        preferences: preferences,
        alerts: RestAlertService(
          RestAlertRepository(db, coordinator: widget.writes),
          AndroidRestAlertPlatform(),
        ),
        plans: PlanRepository(db, coordinator: widget.writes),
        workouts: WorkoutRepository(db, coordinator: widget.writes),
      );
      setState(() {
        busy = false;
      });
    } catch (error, stack) {
      operation.emit(
        DiagnosticPhase.failed,
        DiagnosticOutcome.unknown,
        reason: DiagnosticReason.initialization,
        level: DiagnosticSeverity.error,
        stack: stack,
      );
      try {
        await database?.close();
      } catch (_) {}
      if (mounted) {
        setState(() {
          failed = true;
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ready ??
      MaterialApp(
        title: 'SetTrace',
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.forPreset(Brightness.light, color),
        darkTheme: AppTheme.forPreset(Brightness.dark, color),
        themeMode: mode,
        home: Builder(
          builder: (context) {
            final l = context.l10n;
            return Scaffold(
              appBar: AppBar(title: const Text('SetTrace')),
              body: AppTaskLayout(
                body: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        failed ? l.diagStartupTitle : l.diagLoading,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (failed) Text(l.diagStartupHelp),
                  ],
                ),
                actions: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      label: l.diagStartupRetry,
                      busy: busy,
                      onPressed: busy ? null : _open,
                    ),
                    if (failed) ...[
                      const SizedBox(height: 12),
                      AppButton(
                        label: l.diagAvailableExport,
                        primary: false,
                        onPressed: () async {
                          await controller.load();
                          if (context.mounted) {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DiagnosticsExportPage(
                                  controller: controller,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
}
