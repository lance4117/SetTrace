import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../l10n/localization.dart';
import 'rest_alert_options.dart';
import 'rest_alert_service.dart';

String reminderSoundName(AppLocalizations l, String sound) => switch (sound) {
  'double_beep' => l.restReminderSoundDouble,
  'voice' => l.restReminderSoundVoice,
  _ => l.restReminderSoundThree,
};

class RestReminderControls extends StatefulWidget {
  const RestReminderControls({super.key, required this.alerts});
  final RestAlertService alerts;
  @override
  State<RestReminderControls> createState() => _RestReminderControlsState();
}

class _RestReminderControlsState extends State<RestReminderControls>
    with WidgetsBindingObserver {
  String? condition;
  bool customSound = false,
      reading = true,
      readFailed = false,
      previewing = false,
      settingsFailed = false;
  final settingsFocus = FocusNode();
  int _read = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(readSound());
  }

  Future<void> readSound() async {
    final request = ++_read;
    if (mounted) {
      setState(() {
        reading = true;
        readFailed = false;
      });
    }
    try {
      final status = await widget.alerts.platform.soundStatus();
      if (mounted && request == _read) {
        setState(() {
          condition = status['condition'] as String? ?? 'unknown';
          customSound = status['custom'] == true;
        });
      }
    } catch (_) {
      if (mounted && request == _read) setState(() => readFailed = true);
    } finally {
      if (mounted && request == _read) setState(() => reading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(readSound());
    } else {
      unawaited(widget.alerts.platform.stopPreview().catchError((Object _) {}));
    }
  }

  Future<void> systemSettings() async {
    setState(() => settingsFailed = false);
    try {
      await widget.alerts.platform.openSettings(exact: false);
      if (mounted) settingsFocus.requestFocus();
    } catch (_) {
      if (mounted) setState(() => settingsFailed = true);
    }
  }

  bool saving = false, failed = false, previewFailed = false;
  RestAlertOptions? failedValue;
  Future<void> save(RestAlertOptions value) async {
    if (saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.alerts.setOptions(value);
      failedValue = null;
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          failedValue = value;
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> preview() async {
    if (previewing) {
      await widget.alerts.platform.stopPreview().catchError((Object _) {});
      return;
    }
    setState(() {
      previewing = true;
      previewFailed = false;
    });
    try {
      await widget.alerts.platform.previewSystem();
    } catch (_) {
      if (mounted) setState(() => previewFailed = true);
    } finally {
      if (mounted) setState(() => previewing = false);
    }
  }

  Future<void> choose() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReminderChoiceSheet(alerts: widget.alerts),
    );
    await widget.alerts.platform.stopPreview().catchError((Object _) {});
  }

  @override
  void dispose() {
    unawaited(widget.alerts.platform.stopPreview().catchError((Object _) {}));
    WidgetsBinding.instance.removeObserver(this);
    settingsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, options = widget.alerts.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.restReminderSound,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  reading
                      ? l.restSoundReading
                      : readFailed
                      ? l.restSoundReadFailed
                      : condition == 'allowed'
                      ? (customSound ? l.restSoundCustom : l.restSystemSound)
                      : condition == 'unknown'
                      ? l.restSoundUnknown
                      : l.restSoundRestricted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed:
                        saving ||
                            reading ||
                            readFailed ||
                            !widget.alerts.enabled
                        ? null
                        : preview,
                    icon: Icon(
                      previewing
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                    ),
                    label: Text(
                      previewing ? l.restSoundStopPreview : l.restSoundPreview,
                    ),
                  ),
                  TextButton.icon(
                    focusNode: settingsFocus,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: saving ? null : systemSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(l.restSoundSettings),
                  ),
                  if (readFailed)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: readSound,
                      child: Text(l.retry),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (settingsFailed)
          Semantics(
            liveRegion: true,
            child: Text(
              l.restSoundSettingsFailed,
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        if (previewFailed)
          Semantics(
            liveRegion: true,
            child: Text(
              l.restReminderPreviewFailed,
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.restReminderVibration),
          value: options.vibration,
          onChanged: saving
              ? null
              : (v) => save(options.copyWith(vibration: v)),
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.restReminderRepeat),
          subtitle: Text(l.restReminderRepeatHelp),
          value: options.repeat,
          onChanged: saving ? null : (v) => save(options.copyWith(repeat: v)),
        ),
        if (options.repeat) ...[
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.restReminderInterval),
            subtitle: Text(l.restReminderEvery(options.interval)),
            trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            onTap: saving ? null : choose,
          ),
        ],
        if (saving) const LinearProgressIndicator(),
        if (failed) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              l.restAlertsSaveFailed,
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
          TextButton(
            onPressed: saving ? null : () => save(failedValue!),
            child: Text(l.retry),
          ),
        ],
      ],
    );
  }
}

class _ReminderChoiceSheet extends StatefulWidget {
  const _ReminderChoiceSheet({required this.alerts});
  final RestAlertService alerts;
  @override
  State<_ReminderChoiceSheet> createState() => _ReminderChoiceSheetState();
}

class _ReminderChoiceSheetState extends State<_ReminderChoiceSheet> {
  late String selected = widget.alerts.options.interval.toString();
  bool saving = false, failed = false, previewFailed = false;
  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.alerts.setOptions(
        widget.alerts.options.copyWith(interval: int.parse(selected)),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(widget.alerts.platform.stopPreview().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final choices = RestAlertOptions.intervals
        .map((e) => e.toString())
        .toList();
    return PopScope(
      canPop: !saving,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.restReminderInterval,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...[
                  const SizedBox(height: 8),
                  Text(l.restReminderIntervalHelp),
                ],
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: RadioGroup<String>(
                      groupValue: selected,
                      onChanged: (v) {
                        if (!saving && v != null) setState(() => selected = v);
                      },
                      child: Column(
                        children: [
                          for (final value in choices)
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              value: value,
                              enabled: !saving,
                              title: Text(
                                l.restReminderSeconds(int.parse(value)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (failed || previewFailed) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      failed
                          ? l.restAlertsSaveFailed
                          : l.restReminderPreviewFailed,
                      style: TextStyle(color: context.appColors.danger),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(label: l.save, busy: saving, onPressed: save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
