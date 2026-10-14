import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../l10n/localization.dart';

class StepPicker extends StatefulWidget {
  const StepPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.label,
    required this.onChanged,
    this.semanticLabel,
    this.enabled = true,
  });
  final int value, min, max, step;
  final String Function(int) label;
  final ValueChanged<int> onChanged;
  final String? semanticLabel;
  final bool enabled;
  @override
  State<StepPicker> createState() => _StepPickerState();
}

class _StepPickerState extends State<StepPicker> {
  late final PageController controller;
  late int currentIndex;
  int get count => (widget.max - widget.min) ~/ widget.step + 1;
  @override
  void initState() {
    super.initState();
    currentIndex = ((widget.value - widget.min) ~/ widget.step).clamp(
      0,
      count - 1,
    );
    controller = PageController(
      initialPage: currentIndex,
      viewportFraction: 0.5,
    );
  }

  @override
  void didUpdateWidget(covariant StepPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value &&
        oldWidget.min == widget.min &&
        oldWidget.step == widget.step &&
        oldWidget.max == widget.max) {
      return;
    }
    final next = ((widget.value - widget.min) ~/ widget.step).clamp(
      0,
      count - 1,
    );
    if (next == currentIndex) return;
    currentIndex = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.hasClients) controller.jumpToPage(currentIndex);
    });
  }

  void select(int index, {bool jump = false}) {
    if (!widget.enabled ||
        index < 0 ||
        index >= count ||
        index == currentIndex) {
      return;
    }
    setState(() => currentIndex = index);
    if (jump && controller.hasClients) controller.jumpToPage(index);
    HapticFeedback.selectionClick();
    widget.onChanged(widget.min + index * widget.step);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final value = widget.min + currentIndex * widget.step;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.controlBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.decreaseValue(widget.label(value)),
            onPressed: !widget.enabled || currentIndex == 0
                ? null
                : () => select(currentIndex - 1, jump: true),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Semantics(
              label: widget.semanticLabel,
              enabled: widget.enabled,
              value: widget.label(value),
              increasedValue: currentIndex == count - 1
                  ? null
                  : widget.label(value + widget.step),
              decreasedValue: currentIndex == 0
                  ? null
                  : widget.label(value - widget.step),
              onIncrease: !widget.enabled || currentIndex == count - 1
                  ? null
                  : () => select(currentIndex + 1, jump: true),
              onDecrease: !widget.enabled || currentIndex == 0
                  ? null
                  : () => select(currentIndex - 1, jump: true),
              child: ExcludeSemantics(
                child: SizedBox(
                  height: (48 * MediaQuery.textScalerOf(context).scale(1))
                      .clamp(64, 160),
                  child: PageView.builder(
                    controller: controller,
                    physics: widget.enabled
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    itemCount: count,
                    onPageChanged: select,
                    itemBuilder: (context, index) {
                      final selected = index == currentIndex;
                      return AnimatedContainer(
                        duration: duration,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? c.accentSoft : c.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.label(widget.min + index * widget.step),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? c.onAccentSoft : c.textSecondary,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: selected ? 16 : 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.increaseValue(widget.label(value)),
            onPressed: !widget.enabled || currentIndex == count - 1
                ? null
                : () => select(currentIndex + 1, jump: true),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
