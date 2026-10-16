import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../l10n/localization.dart';
import 'rest_alert_repository.dart';
import 'rest_alert_service.dart';

class RestReminderDialog extends StatefulWidget {
  const RestReminderDialog({
    super.key,
    required this.alerts,
    required this.event,
  });
  final RestAlertService alerts;
  final RestAlertEvent event;
  @override
  State<RestReminderDialog> createState() => RestReminderDialogState();
}

class RestReminderDialogState extends State<RestReminderDialog> {
  bool saving = false, failed = false, closing = false;
  void dismiss() {
    if (!saving && !closing && mounted) {
      closing = true;
      Navigator.of(context).pop();
    }
  }

  Future<void> confirm(RestAlertEvent event) async {
    if (saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.alerts.acknowledge(event);
      if (mounted && !closing) {
        closing = true;
        Navigator.of(context).pop();
      }
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.alerts,
    builder: (context, _) {
      final l = context.l10n;
      final current = widget.alerts.awaiting.where(
        (e) => e.id == widget.event.id,
      );
      if (current.isEmpty && !saving && !closing) {
        WidgetsBinding.instance.addPostFrameCallback((_) => dismiss());
      }
      final event = current.isEmpty ? widget.event : current.first;
      final name = event.row['name_snapshot'] as String? ?? '';
      final number = event.row['set_number'] as int? ?? 1;
      final total = event.row['target_sets'] as int? ?? number;
      return PopScope(
        canPop: !saving,
        child: AlertDialog(
          backgroundColor: context.appColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          scrollable: true,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appColors.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: context.appColors.onAccentSoft,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  namesRoute: true,
                  header: true,
                  child: Text(
                    l.restEnded,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      color: context.appColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l.restReminderReady,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.appColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: context.appColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.restReminderSet(number, total),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.appColors.textSecondary,
                  ),
                ),
                if (widget.alerts.options.repeat) ...[
                  const SizedBox(height: 16),
                  Text(
                    l.restReminderRepeats(widget.alerts.options.interval),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
                if (failed) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l.restReminderConfirmFailed,
                      style: TextStyle(color: context.appColors.danger),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: l.restReminderConfirm,
                  busy: saving,
                  onPressed: () => confirm(event),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
