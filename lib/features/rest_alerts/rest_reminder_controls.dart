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

class _RestReminderControlsState extends State<RestReminderControls> {
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

  Future<void> preview(String sound) async {
    try {
      await widget.alerts.platform.preview(sound, widget.alerts.localeName);
      if (mounted) setState(() => previewFailed = false);
    } catch (_) {
      if (mounted) setState(() => previewFailed = true);
    }
  }

  Future<void> choose(bool sound) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ReminderChoiceSheet(alerts: widget.alerts, sound: sound),
    );
    await widget.alerts.platform.stopPreview().catchError((Object _) {});
  }

  @override
  void dispose() {
    unawaited(widget.alerts.platform.stopPreview().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, options = widget.alerts.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.restReminderSound),
          subtitle: Text(reminderSoundName(l, options.sound)),
          onTap: saving ? null : () => choose(true),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l.restReminderPreviewSound(
                  reminderSoundName(l, options.sound),
                ),
                onPressed: saving ? null : () => preview(options.sound),
                icon: const Icon(Icons.play_circle_outline),
              ),
              const SizedBox(width: 8),
              const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
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
            onTap: saving ? null : () => choose(false),
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
  const _ReminderChoiceSheet({required this.alerts, required this.sound});
  final RestAlertService alerts;
  final bool sound;
  @override
  State<_ReminderChoiceSheet> createState() => _ReminderChoiceSheetState();
}

class _ReminderChoiceSheetState extends State<_ReminderChoiceSheet> {
  late String selected = widget.sound
      ? widget.alerts.options.sound
      : widget.alerts.options.interval.toString();
  bool saving = false, failed = false, previewFailed = false;
  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.alerts.setOptions(
        widget.sound
            ? widget.alerts.options.copyWith(sound: selected)
            : widget.alerts.options.copyWith(interval: int.parse(selected)),
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

  Future<void> preview(String sound) async {
    try {
      await widget.alerts.platform.preview(sound, widget.alerts.localeName);
      if (mounted) setState(() => previewFailed = false);
    } catch (_) {
      if (mounted) setState(() => previewFailed = true);
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
    final choices = widget.sound
        ? RestAlertOptions.sounds
        : RestAlertOptions.intervals.map((e) => e.toString()).toList();
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
                    widget.sound ? l.restReminderSound : l.restReminderInterval,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!widget.sound) ...[
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
                                widget.sound
                                    ? reminderSoundName(l, value)
                                    : l.restReminderSeconds(int.parse(value)),
                              ),
                              secondary: widget.sound
                                  ? IconButton(
                                      tooltip: l.restReminderPreviewSound(
                                        reminderSoundName(l, value),
                                      ),
                                      onPressed: saving
                                          ? null
                                          : () => preview(value),
                                      icon: const Icon(
                                        Icons.play_circle_outline,
                                      ),
                                    )
                                  : null,
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
