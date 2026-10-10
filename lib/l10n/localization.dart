import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'generated/app_localizations.dart';
export 'generated/app_localizations.dart';

extension AppLocalization on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  AppFormats get formats => AppFormats(l10n);
}

/// Presentation only. Stored dates, durations and kg values remain unchanged.
class AppFormats {
  const AppFormats(this.strings);
  final AppLocalizations strings;

  String number(num value) =>
      NumberFormat.decimalPattern(strings.localeName).format(value);
  String decimal(num value) => NumberFormat.decimalPatternDigits(
    locale: strings.localeName,
    decimalDigits: 1,
  ).format(value);
  String weight(num value) =>
      NumberFormat('0.################', strings.localeName).format(value);
  String weightLabel(num? value) =>
      value == null ? strings.weightNotSet : strings.weightKg(weight(value));
  String month(DateTime value) =>
      DateFormat.yMMMM(strings.localeName).format(value);
  String date(DateTime value) =>
      DateFormat.yMMMd(strings.localeName).format(value.toLocal());
  String time(DateTime value) =>
      DateFormat.Hm(strings.localeName).format(value.toLocal());
  String duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours == 0
        ? strings.minutesDuration(minutes)
        : strings.hoursDuration(hours, minutes);
  }
}

/// No grouping separators: a single dot or comma means a decimal separator.
double? parseWeight(String input) {
  final raw = input.trim();
  if (!RegExp(r'^(?:\d+(?:[.,]\d*)?|[.,]\d+)$').hasMatch(raw)) return null;
  final value = double.tryParse(raw.replaceAll(',', '.'));
  return value != null && value.isFinite && value > 0 ? value : null;
}

/// A callback carries data, not a cached translation. It also works for feedback
/// that remains visible while the user changes languages.
typedef LocalizedMessage = String Function(AppLocalizations strings);

void showAppSnackBar(
  BuildContext context,
  LocalizedMessage message, {
  VoidCallback? onRetry,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Builder(
        builder: (context) => Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(message(context.l10n)),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.inversePrimary,
                ),
                child: Text(context.l10n.retry),
              ),
          ],
        ),
      ),
    ),
  );
}
