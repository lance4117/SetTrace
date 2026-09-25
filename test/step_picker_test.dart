import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/widgets/step_picker.dart';

void main() {
  testWidgets('picker snaps to valid 30-second values with one haptic per change',
      (tester) async {
    final changes = <int>[];
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      });
    addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: Scaffold(body: Center(child: SizedBox(width: 360,
        child: StepPicker(value: 60, min: 0, max: 120, step: 30,
          label: (value) => '$value 秒', onChanged: changes.add))))));
    await tester.drag(find.byType(PageView), const Offset(-170, 0));
    await tester.pumpAndSettle();
    expect(changes, [90]);
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    expect(find.text('90 秒'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-170, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-170, 0));
    await tester.pumpAndSettle();
    expect(changes, [90, 120]);
    expect(haptics.length, 2);
  });
}
