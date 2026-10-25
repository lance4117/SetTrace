import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../l10n/localization.dart';
import 'notice_preferences.dart';

Future<void> showAppNotice(
  BuildContext context, {
  NoticePreferences? preferences,
}) => showDialog<void>(
  context: context,
  builder: (_) => AppNoticeDialog(preferences: preferences),
);

class AppNoticeDialog extends StatefulWidget {
  const AppNoticeDialog({super.key, this.preferences});
  final NoticePreferences? preferences;
  @override
  State<AppNoticeDialog> createState() => _AppNoticeDialogState();
}

class _AppNoticeDialogState extends State<AppNoticeDialog> {
  bool saving = false, failed = false;
  Future<void> acknowledge() async {
    if (saving) return;
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.preferences!.acknowledge();
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
  Widget build(BuildContext context) {
    final l = context.l10n;
    final firstRun = widget.preferences != null;
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        key: const ValueKey('app-notice-dialog'),
        scrollable: true,
        title: Text(firstRun ? l.welcomeTitle : l.privacyAndData),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.noticeIntroduction),
            for (final section in [
              (l.noticePrivacyTitle, l.noticePrivacyBody),
              (l.noticeLocalTitle, l.noticeLocalBody),
              (l.noticeBackupTitle, l.noticeBackupBody),
              (l.noticeDiagnosticsTitle, l.noticeDiagnosticsBody),
            ]) ...[
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  section.$1,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Text(section.$2),
            ],
            if (failed) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.noticeSaveFailed,
                  style: TextStyle(color: context.appColors.danger),
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: AppButton(
              key: const ValueKey('notice-confirm'),
              busy: saving,
              label: firstRun ? (failed ? l.retry : l.noticeStart) : l.close,
              onPressed: saving
                  ? null
                  : firstRun
                  ? acknowledge
                  : () => Navigator.of(context).pop(),
            ),
          ),
          if (failed)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.noticeContinue),
            ),
        ],
      ),
    );
  }
}
