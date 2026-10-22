import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/localization.dart';

/// Display only: the page supplies the selected month's existing statistics.
class HistorySummaryCard extends StatelessWidget {
  const HistorySummaryCard({
    super.key,
    required this.month,
    required this.durationSeconds,
    required this.completedSets,
  });

  final DateTime month;
  final int durationSeconds;
  final int completedSets;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final strings = context.l10n;
    final formats = context.formats;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              strings.historyMonthSummary(formats.month(month)),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            container: true,
            label: strings.summaryDurationSemantics(
              formats.duration(durationSeconds),
            ),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.summaryDuration,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
                const SizedBox(height: 4),
                Wrap(
                  key: const ValueKey('history-duration'),
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    for (final (index, part)
                        in formats.durationParts(durationSeconds).indexed)
                      Text.rich(
                        key: ValueKey('history-duration-part-$index'),
                        TextSpan(
                          children: [
                            TextSpan(
                              text: part.value,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            TextSpan(
                              text: ' ${part.unit}',
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        softWrap: false,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final labelStyle = TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
              );
              const valueStyle = TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              );
              final quantity = strings.summarySets(completedSets);
              double width(String text, TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: text,
                    style: DefaultTextStyle.of(context).style.merge(style),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final result = painter.width;
                painter.dispose();
                return result;
              }

              final label = Text(
                strings.summaryCompletedSets,
                style: labelStyle,
              );
              final value = Text(quantity, style: valueStyle);
              if (width(strings.summaryCompletedSets, labelStyle) +
                      width(quantity, valueStyle) +
                      16 >
                  constraints.maxWidth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label,
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: value,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [label, value],
              );
            },
          ),
        ],
      ),
    );
  }
}
