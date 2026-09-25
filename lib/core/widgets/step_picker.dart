import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';

class StepPicker extends StatefulWidget {
  const StepPicker({super.key, required this.value, required this.min,
    required this.max, required this.step, required this.label,
    required this.onChanged});

  final int value, min, max, step;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  State<StepPicker> createState() => _StepPickerState();
}

class _StepPickerState extends State<StepPicker> {
  late PageController controller;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = (widget.value - widget.min) ~/ widget.step;
    controller = PageController(initialPage: currentIndex, viewportFraction: 0.36);
  }

  @override
  void didUpdateWidget(covariant StepPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = (widget.value - widget.min) ~/ widget.step;
    if (next != currentIndex) {
      currentIndex = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) controller.jumpToPage(next);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final count = (widget.max - widget.min) ~/ widget.step + 1;
    return Container(
      height: 52,
      decoration: BoxDecoration(color: colors.surfaceAlt,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12)),
      child: PageView.builder(
        controller: controller,
        itemCount: count,
        onPageChanged: (index) {
          if (index == currentIndex) return;
          setState(() => currentIndex = index);
          HapticFeedback.selectionClick();
          widget.onChanged(widget.min + index * widget.step);
        },
        itemBuilder: (context, index) {
          final selected = index == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.accent : colors.surfaceAlt,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(widget.label(widget.min + index * widget.step),
              maxLines: 1,
              style: TextStyle(
                color: selected ? colors.onAccent : colors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize: selected ? 16 : 13,
              )),
          );
        },
      ),
    );
  }
}
