// Opt-in reference rendering of production widgets on isolated test fixtures.
// These images are widget-test evidence, never release-emulator screenshots.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/core/diagnostics/diagnostic_contract.dart';
import 'package:settrace/core/diagnostics/diagnostics_client.dart';
import 'package:settrace/features/diagnostics/diagnostics_controller.dart';
import 'package:settrace/features/diagnostics/diagnostics_pages.dart';
import 'package:settrace/l10n/localization.dart';

import 'support/diagnostics_fakes.dart';
import 'support/focus_scenes.dart';

const output = String.fromEnvironment('UI_REFERENCE_OUTPUT');
final rootKey = GlobalKey();
final captures = <Map<String, Object?>>[];

Future<void> saveFrame(
  WidgetTester t,
  String id,
  String language,
  bool dark, {
  String state = 'normal',
  String group = 'core',
  String recordFile = 'widget-captures.json',
  Size size = const Size(360, 800),
  double scale = 1,
  String preset = 'teal',
  String? fixture,
}) async {
  expect(t.takeException(), isNull, reason: '$id $language dark=$dark');
  // The test engine uses block glyphs for TextStyles without a family, unlike
  // Android's system fallback. Supply only font fallback on the rendered spans;
  // preserve all strings, sizes, weights, colors, widgets and production code.
  InlineSpan readable(InlineSpan span) {
    if (span is! TextSpan) return span;
    final style = span.style;
    return TextSpan(
      text: span.text,
      style:
          (style?.fontFamily == null &&
              (style?.fontFamilyFallback?.isEmpty ?? true))
          ? (style ?? const TextStyle()).copyWith(
              fontFamily: 'Roboto',
              fontFamilyFallback: const ['Noto Sans SC'],
            )
          : style,
      children: span.children?.map(readable).toList(),
      recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  final originals = <RenderParagraph, InlineSpan>{};
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      originals[node] = node.text;
      node.text = readable(node.text);
    }
    node.visitChildren(visit);
  }

  visit(rootKey.currentContext!.findRenderObject()!);
  await t.pump(const Duration(milliseconds: 100));
  expect(t.takeException(), isNull, reason: '$id readable font layout');
  final boundary =
      rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final name =
      '$id-$state-$language-${dark ? 'dark' : 'light'}-${size.width.round()}-widget';
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final target = File('$output/screenshots/$group/$name.png');
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes!.buffer.asUint8List());
    captures.add({
      'capture_id': name,
      'screen_id': id,
      'state_id': state,
      'group': group,
      'path': 'screenshots/$group/$name.png',
      'language': language,
      'theme': dark ? 'dark' : 'light',
      'theme_color': preset,
      'logical_width': size.width,
      'logical_height': size.height,
      'pixel_width': (size.width * 2).round(),
      'pixel_height': (size.height * 2).round(),
      'font_scale': scale,
      'orientation': size.width > size.height ? 'landscape' : 'portrait',
      'capture_kind': 'widget-test',
      'captured_at': DateTime.now().toUtc().toIso8601String(),
      'fixture': fixture ?? 'isolated real SQLite + controlled platform adapters; test-only missing font-family fallback set to installed Roboto/Microsoft YaHei before rasterization; text, size and weight unchanged',
    });
    await File('$output/verification/$recordFile')
        .writeAsString(jsonEncode(captures));
  });
  for (final entry in originals.entries) {
    if (entry.key.attached) entry.key.text = entry.value;
  }
  await t.pump();
}

Widget wrap(Widget page, String language, bool dark) => RepaintBoundary(
  key: rootKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.dark : AppTheme.light,
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: page,
  ),
);

Future<void> loadReferenceFonts() async {
  if (output.isEmpty) return;
  if (!output.replaceAll('\\', '/').startsWith('D:/')) {
    throw StateError('UI reference output must be on D:');
  }
  final fonts = {
    'Roboto': 'D:/DevTools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
    'Noto Sans SC': 'C:/Windows/Fonts/msyh.ttc',
    'MaterialIcons': 'D:/DevTools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  };
  for (final entry in fonts.entries) {
    final bytes = File(entry.value).readAsBytesSync();
    final loader = FontLoader(entry.key)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  await Directory('$output/verification').create(recursive: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(loadReferenceFonts);
  for (final language in ['zh', 'en']) {
    for (final dark in [false, true]) {
      for (final id in focusSceneIds) {
        testWidgets('reference $id $language dark=$dark', (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(360, 800);
          SharedPreferences.setMockInitialValues({});
          final scene = await t.runAsync(
            () => FocusScene.create(
              id,
              Locale(language),
              factory: databaseFactoryFfi,
            ),
          );
          try {
            scene!.dark = dark;
            await t.pumpWidget(
              id == 'D11'
                  ? RepaintBoundary(key: rootKey, child: scene.page)
                  : wrap(scene.page, language, dark),
            );
            await settleFocus(t);
            await prepareFocusScene(t, scene);
            await saveFrame(t, id, language, dark);
          } finally {
            await t.pumpWidget(const SizedBox());
            await t.runAsync(() => scene!.close());
          }
        }, skip: output.isEmpty);
      }
      for (final id in [
        'L01',
        'L01a',
        'L01b',
        'L01c',
        'L01d',
        'L01e',
        'L02',
        'L02a',
        'L03',
        'L03a',
        'L04',
        'L05',
        'L06',
        'L08',
        'LE01',
      ]) {
        testWidgets('reference $id $language dark=$dark', (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(360, 800);
          final transport = FakeDiagnosticsTransport()
            ..bytes = 153600
            ..eventCount = 27
            ..firstTime = DateTime.now().subtract(const Duration(days: 2))
            ..lastTime = DateTime.now();
          if (id == 'L01a') transport.enabled = false;
          if (id == 'L01b' || id == 'L02a') {
            transport.bytes = 0;
            transport.eventCount = 0;
            transport.firstTime = null;
            transport.lastTime = null;
          }
          if (id == 'L01c') transport.failMethods.add('overview');
          if (id == 'L01d') transport.limited = true;
          if (id == 'L01e') {
            transport.detailedUntil = DateTime.now().add(
              const Duration(minutes: 20),
            );
          }
          if (['L03', 'L03a', 'L04', 'L06', 'LE01'].contains(id)) {
            transport.hasExport = true;
            transport.autoComplete = false;
            transport.stage = switch (id) {
              'L03' || 'L03a' => DiagnosticExportStage.packaging,
              'L04' => DiagnosticExportStage.saved,
              'L06' => DiagnosticExportStage.saved_partial,
              _ => DiagnosticExportStage.failed,
            };
            if (id == 'L06') transport.exportMissing.add('queue_overflow');
          }
          final client = DiagnosticsClient(transport: transport);
          final controller = DiagnosticsController(client);
          try {
            await controller.load();
            if (id == 'L03a') controller.cancelling = true;
            final Widget page = switch (id) {
              'L02' ||
              'L02a' ||
              'L03' ||
              'L03a' ||
              'L04' ||
              'L06' ||
              'LE01' => DiagnosticsExportPage(controller: controller),
              'L05' => DiagnosticsDetailedPage(controller: controller),
              'L08' => const DiagnosticsPrivacyPage(),
              _ => DiagnosticsPage(controller: controller),
            };
            await t.pumpWidget(wrap(page, language, dark));
            await t.pump(const Duration(milliseconds: 250));
            if (id != 'L03' && id != 'L03a') await t.pumpAndSettle();
            await saveFrame(
              t,
              id,
              language,
              dark,
              group: 'diagnostics',
              recordFile: id == 'L03a'
                  ? 'diagnostic-cancel-captures.json'
                  : 'widget-captures.json',
              fixture: id == 'L03a'
                  ? 'Production diagnostics widget with controlled export stage and cancelling flag; test font fallback. Rendering only; actual cancellation race not exercised.'
                  : null,
            );
          } finally {
            await t.pumpWidget(const SizedBox());
            controller.dispose();
            client.dispose();
          }
        }, skip: output.isEmpty);
      }
    }
  }
}
