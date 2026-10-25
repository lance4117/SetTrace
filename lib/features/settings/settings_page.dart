import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/theme_color_controller.dart';
import 'theme_color_section.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/language_settings.dart';
import '../../l10n/localization.dart';
import '../rest_alerts/rest_alert_service.dart';
import '../rest_alerts/rest_reminder_controls.dart';
import '../about/about_section.dart';
import '../about/app_info_service.dart';
import '../diagnostics/diagnostics_pages.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.alerts,
    this.themeColors,
    this.onBackup,
    this.onDiagnostics,
    this.info = const AppInfoService(),
    required this.mode,
    required this.onModeChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final RestAlertService? alerts;
  final ThemeColorController? themeColors;
  final VoidCallback? onBackup;
  final FutureOr<void> Function()? onDiagnostics;
  final AppInfoService info;
  final ThemeMode mode;
  final FutureOr<void> Function(ThemeMode) onModeChanged;
  final Locale locale;
  final Future<void> Function(Locale) onLocaleChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final diagnosticsFocus = FocusNode();
  Future<void> openDiagnostics() async {
    if (widget.onDiagnostics != null) {
      await widget.onDiagnostics!.call();
    } else {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsPage()));
    }
    if (mounted) diagnosticsFocus.requestFocus();
  }

  @override
  void dispose() {
    diagnosticsFocus.dispose();
    super.dispose();
  }

  bool savingLanguage = false;
  bool savingTheme = false, themeError = false;
  bool languageError = false;
  bool savingReminder = false, reminderSaveError = false;

  Future<void> changeTheme(ThemeMode? next) async {
    if (next == null || savingTheme || next == widget.mode) return;
    setState(() {
      savingTheme = true;
      themeError = false;
    });
    try {
      await widget.onModeChanged(next);
    } catch (_) {
      if (mounted) setState(() => themeError = true);
    } finally {
      if (mounted) setState(() => savingTheme = false);
    }
  }

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

  Future<void> changeReminders(bool value) async {
    if (savingReminder) return;
    setState(() {
      savingReminder = true;
      reminderSaveError = false;
    });
    try {
      await widget.alerts!.setEnabled(value);
    } catch (_) {
      if (mounted) {
        setState(() => reminderSaveError = widget.alerts!.enabled != value);
      }
    } finally {
      if (mounted) setState(() => savingReminder = false);
    }
  }

  Future<void> openReminderSettings(bool exact) async {
    try {
      await widget.alerts!.platform.openSettings(exact: exact);
    } catch (_) {
      if (mounted) showAppSnackBar(context, (l) => l.restAlertsFailed);
    }
  }

  Widget reminderSettings(RestAlertService alerts) => AnimatedBuilder(
    animation: alerts,
    builder: (context, _) {
      final l = context.l10n;
      final cap = alerts.capability;
      final message = !alerts.enabled
          ? l.restAlertsOff
          : alerts.failed
          ? l.restAlertsFailed
          : cap?.notifications != true
          ? l.restAlertsNoNotifications
          : cap?.exact != true
          ? l.restAlertsMayBeLate
          : l.restAlertsAvailable;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            l.restAlerts,
            style: TextStyle(color: context.appColors.textSecondary),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.restAlertsEnabled),
                  subtitle: Text(
                    message,
                    style: TextStyle(
                      color: !alerts.enabled
                          ? context.appColors.textSecondary
                          : alerts.failed
                          ? context.appColors.danger
                          : cap?.notifications != true || cap?.exact != true
                          ? context.appColors.warning
                          : context.appColors.onAccentSoft,
                    ),
                  ),
                  value: alerts.enabled,
                  onChanged: savingReminder ? null : changeReminders,
                ),
                if (alerts.enabled) RestReminderControls(alerts: alerts),
                if (savingReminder) const LinearProgressIndicator(),
                if (reminderSaveError)
                  Text(
                    l.restAlertsSaveFailed,
                    style: TextStyle(color: context.appColors.danger),
                  ),
                if (alerts.failed || reminderSaveError)
                  TextButton(
                    onPressed: savingReminder
                        ? null
                        : () {
                            if (reminderSaveError) {
                              changeReminders(!alerts.enabled);
                            } else {
                              alerts.synchronize().catchError((Object _) {});
                            }
                          },
                    child: Text(l.retry),
                  ),
                if (alerts.enabled && cap?.notifications != true)
                  TextButton(
                    onPressed: () => openReminderSettings(false),
                    child: Text(l.notificationSettings),
                  ),
                if (alerts.enabled && cap?.exact != true)
                  TextButton(
                    onPressed: () => openReminderSettings(true),
                    child: Text(l.accurateRestSettings),
                  ),
              ],
            ),
          ),
          if (alerts.enabled) ...[
            const SizedBox(height: 12),
            Text(
              l.restReminderStopHelp,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.restReminderSystemHelp,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 14,
              ),
            ),
            Text(
              l.restReminderDelayHelp,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      );
    },
  );

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
              onChanged: changeTheme,
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
                      enabled: !savingTheme,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ),
          if (savingTheme) const LinearProgressIndicator(),
          if (themeError)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                strings.themeSaveFailed,
                style: TextStyle(color: colors.danger),
              ),
            ),
          ThemeColorSection(controller: widget.themeColors),
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
          if (widget.alerts != null) reminderSettings(widget.alerts!),
          ...[
            const SizedBox(height: 24),
            Text(
              strings.backupDataSection,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: Text(strings.backupTitle),
                    subtitle: Text(strings.backupSubtitle),
                    trailing: const ExcludeSemantics(
                      child: Icon(Icons.chevron_right),
                    ),
                    onTap: widget.onBackup,
                  ),
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: colors.border,
                  ),
                  ListTile(
                    key: const ValueKey('settings-diagnostics'),
                    focusNode: diagnosticsFocus,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    title: Text(strings.diagTitle),
                    subtitle: Text(strings.diagSubtitle),
                    trailing: const ExcludeSemantics(
                      child: Icon(Icons.chevron_right),
                    ),
                    onTap: openDiagnostics,
                  ),
                ],
              ),
            ),
          ],
          AboutSection(info: widget.info),
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
