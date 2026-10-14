import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/widgets/app_button.dart';
import 'package:settrace/core/widgets/step_picker.dart';
import 'package:settrace/l10n/localization.dart';

Widget localized(Widget child) => MaterialApp(
  theme: AppTheme.light,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
void main() {
  test('semantic foregrounds and required borders meet contrast', () {
    for (final c in [AppColors.light, AppColors.dark]) {
      double ratio(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      for (final pair in [
        (c.textPrimary, c.background),
        (c.textSecondary, c.surface),
        (c.onAccent, c.accent),
        (c.onAccentSoft, c.accentSoft),
        (c.onDanger, c.danger),
        (c.warning, c.warningSoft),
      ]) {
        expect(ratio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      expect(ratio(c.controlBorder, c.surface), greaterThanOrEqualTo(3));
    }
  });
  testWidgets('button grows for translated text, busy cannot submit', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var calls = 0;
    Widget button(bool busy) => localized(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AppButton(
            label: 'Save the completed sets in this workout',
            busy: busy,
            onPressed: () => calls++,
          ),
        ),
      ),
    );
    await t.pumpWidget(button(false));
    final finder = find.byType(AppButton);
    expect(t.getSize(finder).height, greaterThan(56));
    await t.tap(find.text('Save the completed sets in this workout'));
    expect(calls, 1);
    await t.pumpWidget(button(true));
    await t.pump();
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(t.takeException(), isNull);
  });
  testWidgets('picker buttons, swipe and external sync do not double fire', (
    t,
  ) async {
    var value = 1;
    var haptics = 0;
    final changes = <int>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics++;
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    late StateSetter update;
    await t.pumpWidget(
      localized(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Center(
              child: SizedBox(
                width: 360,
                child: StepPicker(
                  value: value,
                  min: 1,
                  max: 4,
                  step: 1,
                  label: (n) => '$n sets',
                  onChanged: (n) {
                    changes.add(n);
                    setState(() => value = n);
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(
      t
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
          .onPressed,
      isNull,
    );
    await t.tap(find.widgetWithIcon(IconButton, Icons.add));
    await t.pumpAndSettle();
    expect(value, 2);
    expect(changes, [2]);
    expect(haptics, 1);
    update(() => value = 4);
    await t.pumpAndSettle();
    expect(haptics, 1);
    expect(changes, [2]);
    expect(
      t
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
    await t.tap(find.widgetWithIcon(IconButton, Icons.remove));
    await t.pumpAndSettle();
    expect(value, 3);
    expect(changes, [2, 3]);
    expect(haptics, 2);
    expect(t.takeException(), isNull);
  });
}
