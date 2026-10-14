import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../l10n/localization.dart';

class AppLoadError extends StatelessWidget {
  const AppLoadError({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel,
  });
  final String message;
  final String? retryLabel;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              color: context.appColors.danger,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(retryLabel ?? context.l10n.retry),
          ),
        ],
      ),
    ),
  );
}
