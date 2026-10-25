import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/app/theme/theme_color_preset.dart';
import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/diagnostics/diagnostics_controller.dart';
import 'package:settrace/features/diagnostics/diagnostics_pages.dart';
import 'package:settrace/features/settings/settings_page.dart';
import 'package:settrace/l10n/generated/app_localizations.dart';

import '../support/diagnostics_fakes.dart';

void main() {
  late FakeDiagnosticsTransport transport;
  late DiagnosticsClient client;
  late DiagnosticsController controller;
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'SetTrace',
      packageName: 'com.settrace.settrace',
      version: 'test',
      buildNumber: '1',
      buildSignature: '',
    );
    transport = FakeDiagnosticsTransport();
    client = DiagnosticsClient(transport: transport);
    controller = DiagnosticsController(client);
  });
  tearDown(() {
    controller.dispose();
    client.dispose();
  });
  Future<void> show(
    WidgetTester tester,
    Widget page, {
    String language = 'zh',
    ThemeColorPreset preset = ThemeColorPreset.teal,
    Brightness brightness = Brightness.light,
    double scale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.forPreset(brightness, preset),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('latest settings keeps data rows together even without backup', (
    tester,
  ) async {
    await show(
      tester,
      SettingsPage(
        mode: ThemeMode.system,
        onModeChanged: (_) {},
        locale: const Locale('zh'),
        onLocaleChanged: (_) async {},
      ),
    );
    final tile = find.byKey(const ValueKey('settings-diagnostics'));
    await tester.scrollUntilVisible(
      tile,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.text('诊断与日志'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
  });
  testWidgets(
    'no logs and read failure are distinct; disabled detail does not enable logging',
    (tester) async {
      transport.enabled = false;
      await show(tester, DiagnosticsPage(controller: controller));
      expect(find.text('尚无操作日志'), findsOneWidget);
      expect(find.text('记录已关闭'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('临时详细诊断'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('临时详细诊断'));
      await tester.pumpAndSettle();
      expect(find.text('请先在上一页开启本机诊断记录。'), findsOneWidget);
      expect(transport.calls, isNot(contains('setEnabled')));
      transport.failMethods.add('overview');
      await controller.load(recoverExport: false);
      await tester.pumpAndSettle();
      expect(controller.overviewFailed, isTrue);
    },
  );
  testWidgets(
    'preview creates no file; only save starts; result keeps full selectable filename',
    (tester) async {
      await controller.load();
      await show(tester, DiagnosticsExportPage(controller: controller));
      expect(transport.calls, isNot(contains('startExport')));
      expect(find.text('仅包含当前应用与系统诊断信息，不含操作日志。'), findsOneWidget);
      await tester.tap(find.text('保存到下载目录'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(transport.calls.where((m) => m == 'startExport'), hasLength(1));
      expect(find.text('诊断包已保存'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('1.2 KiB'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('0.0 MiB'), findsNothing);
      expect(
        find.byKey(const ValueKey('diagnostics-filename')),
        findsOneWidget,
      );
      expect(
        find.text(
          'SetTrace-diagnostics-2026-10-24-a-long-verified-report-name.zip',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('unknown export offers inspection and no duplicate save action', (
    tester,
  ) async {
    transport.hasExport = true;
    transport.stage = DiagnosticExportStage.unknown;
    await controller.load();
    await show(tester, DiagnosticsExportPage(controller: controller));
    expect(find.text('重新核查'), findsOneWidget);
    expect(find.text('保存到下载目录'), findsNothing);
    transport.stage = DiagnosticExportStage.saved;
    await tester.tap(find.text('重新核查'));
    await tester.pumpAndSettle();
    expect(find.text('诊断包已保存'), findsOneWidget);
    expect(transport.calls, isNot(contains('startExport')));
  });
  testWidgets('clear defaults to cancel; cancel never calls native deletion', (
    tester,
  ) async {
    await show(tester, DiagnosticsPage(controller: controller));
    await tester.scrollUntilVisible(
      find.text('清空本机日志'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('清空本机日志'));
    await tester.pumpAndSettle();
    expect(find.text('清空本机日志？'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .autofocus,
      isTrue,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(transport.calls, isNot(contains('clear')));
  });
  testWidgets(
    'all primary pages adapt to themes, languages, sizes and large text',
    (tester) async {
      for (final preset in ThemeColorPreset.values) {
        for (final brightness in Brightness.values) {
          for (final language in ['zh', 'en']) {
            for (final scale in [1.0, 1.3, 1.6]) {
              for (final size in [
                const Size(360, 640),
                const Size(430, 932),
                const Size(768, 600),
                const Size(844, 390),
              ]) {
                await show(
                  tester,
                  DiagnosticsExportPage(controller: controller),
                  language: language,
                  preset: preset,
                  brightness: brightness,
                  scale: scale,
                  size: size,
                );
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '$preset $brightness $language $scale $size preview',
                );
              }
            }
          }
        }
      }
      transport.hasExport = true;
      transport.stage = DiagnosticExportStage.saved_partial;
      transport.exportMissing.add('read_failed');
      await controller.load();
      for (final page in [
        DiagnosticsPage(controller: controller),
        DiagnosticsDetailedPage(controller: controller),
        DiagnosticsExportPage(controller: controller),
        const DiagnosticsPrivacyPage(),
      ]) {
        for (final size in [const Size(360, 640), const Size(844, 390)]) {
          await show(tester, page, language: 'en', scale: 1.6, size: size);
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} $size large text',
          );
        }
      }
    },
  );
}
