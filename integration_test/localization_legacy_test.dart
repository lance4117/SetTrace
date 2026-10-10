import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:settrace/app/theme/app_theme.dart';
import 'package:settrace/features/plans/plan_transfer.dart';
import 'package:settrace/features/plans/plan_transfer_platform.dart';
import 'package:settrace/l10n/error_messages.dart';
import 'package:settrace/l10n/localization.dart';

// Run only on a disposable API28 device. The host denies, allows and cancels
// the system-owned dialogs at the printed LEGACY_QA stages.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'legacy permission denial, retry, actual Downloads and picker cancel',
    (tester) async {
      final strings = lookupAppLocalizations(const Locale('en'));
      String message = strings.exportPlans;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(message),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      final platform = AndroidPlanTransferPlatform();
      const content =
          '{"format":"settrace.training-plans","schemaVersion":1,"plans":[{"name":"旧中文备份","exercises":[]}]}';
      debugPrint('LEGACY_QA_DENY');
      try {
        await platform.saveFile(content);
        fail('Permission refusal must not return success');
      } on PlanTransferException catch (error) {
        expect(error.code, PlanTransferFailure.permissionDenied);
        update(() => message = failureText(strings, error));
      }
      await tester.pumpAndSettle();
      await File(
        '${Directory.systemTemp.path}/legacy-permission-denied.png',
      ).writeAsBytes(await binding.takeScreenshot('legacy-permission-denied'));
      debugPrint('LEGACY_QA_ALLOW');
      final saved = await platform.saveFile(content);
      expect(saved.location, 'downloads');
      expect(saved.fileName, startsWith('SetTrace-plans-'));
      expect(
        await File('/sdcard/Download/${saved.fileName}').readAsString(),
        content,
      );
      update(() => message = strings.fileSaved(saved.fileName));
      await tester.pumpAndSettle();
      await File('${Directory.systemTemp.path}/legacy-save-success.png')
          .writeAsBytes(await binding.takeScreenshot('legacy-save-success'));
      debugPrint('LEGACY_QA_CANCEL');
      expect(await platform.pickFile(), isNull);
      update(() => message = strings.importPlans);
      await tester.pumpAndSettle();
      await File(
        '${Directory.systemTemp.path}/legacy-picker-cancelled.png',
      ).writeAsBytes(await binding.takeScreenshot('legacy-picker-cancelled'));
      debugPrint('LEGACY_QA_PICK_OLD');
      final old = await platform.pickFile();
      expect(old, isNotNull);
      expect(const PlanTransferCodec().decode(old!).plans.single.name, '旧中文备份');
      update(() => message = strings.importPreview);
      await tester.pumpAndSettle();
      await File('${Directory.systemTemp.path}/legacy-old-backup.png')
          .writeAsBytes(await binding.takeScreenshot('legacy-old-backup'));
      expect(tester.takeException(), isNull);
    },
  );
}
