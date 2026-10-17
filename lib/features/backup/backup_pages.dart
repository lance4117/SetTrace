import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_task_layout.dart';
import '../../l10n/localization.dart';
import 'backup_codec.dart';
import 'backup_coordinator.dart';
import 'backup_json.dart';
import 'backup_models.dart';

String backupError(AppLocalizations l, Object error) => switch (error) {
  BackupException(code: BackupFailure.tooLarge) => l.backupTooLarge,
  BackupException(code: BackupFailure.unsupportedVersion) =>
    l.backupUnsupported,
  BackupException(code: BackupFailure.planFile) => l.backupPlanFile,
  BackupException(
    code: BackupFailure.invalidData ||
        BackupFailure.integrity ||
        BackupFailure.damaged ||
        BackupFailure.wrongFormat,
  ) =>
    l.backupInvalid,
  BackupException(code: BackupFailure.activeWorkout) => l.backupActiveHelp,
  BackupException(code: BackupFailure.protection) => l.backupProtectionFailed,
  BackupException(code: BackupFailure.rolledBack) => l.backupRolledBack,
  BackupException(code: BackupFailure.stalePreview) => l.backupStale,
  BackupException(code: BackupFailure.indeterminate) => l.backupUnknown,
  BackupException(code: BackupFailure.missingCopy) => l.backupCopyUnavailable,
  BackupException(code: BackupFailure.busy) => l.backupBusy,
  BackupException(code: BackupFailure.readFailed) => l.backupReadFailed,
  BackupException(code: BackupFailure.deleteFailed) => l.backupDeleteFailed,
  _ => l.backupStorageFailed,
};

String backupPhase(AppLocalizations l, String phase) => switch (phase) {
  'protecting' => l.backupProtecting,
  'restoring' => l.backupRestoring,
  'settings' => l.backupApplyingSettings,
  'validating' => l.backupValidating,
  'exporting' => l.backupExporting,
  _ => l.backupChecking,
};

class BackupStartupPage extends StatelessWidget {
  const BackupStartupPage({
    super.key,
    required this.failed,
    required this.onRetry,
  });
  final bool failed;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!failed && !MediaQuery.disableAnimationsOf(context))
                  const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    failed
                        ? context.l10n.backupUnknown
                        : context.l10n.backupChecking,
                  ),
                ),
                if (failed) ...[
                  const SizedBox(height: 24),
                  AppButton(label: context.l10n.retry, onPressed: onRetry),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class BackupPage extends StatefulWidget {
  const BackupPage({
    super.key,
    required this.service,
    required this.onWorkout,
    required this.onHistory,
    required this.onPlanImport,
  });
  final BackupCoordinator service;
  final Future<void> Function() onWorkout, onHistory, onPlanImport;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  BackupCoordinator get service => widget.service;
  String screen = 'home';
  bool busy = false, loading = true;
  int requestVersion = 0;
  bool get canCancelRead =>
      busy && ['selecting', 'validating'].contains(service.phase);
  Object? error;
  BackupData? current;
  BackupMap? activeWorkout;
  String? currentDigest;
  BackupMap? state, selectedCopy, saved;
  List<BackupMap> copies = [], operations = [];
  BackupDocument? exportDocument, copyDocument;
  BackupPreview? preview;
  BackupOperationResult? result;
  bool get restricted =>
      service.writes.blocked && service.phase == 'indeterminate';
  @override
  void initState() {
    super.initState();
    service.addListener(changed);
    unawaited(load());
  }

  @override
  void dispose() {
    service.removeListener(changed);
    unawaited(service.clearCandidate().catchError((Object _) {}));
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    final version = ++requestVersion;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (e is BackupException && e.code == BackupFailure.activeWorkout) {
        try {
          activeWorkout = await service.data.activeSummary();
        } catch (_) {
          activeWorkout = null;
        }
      }
      if (mounted && version == requestVersion) setState(() => error = e);
    } finally {
      if (mounted && version == requestVersion) {
        setState(() {
          busy = false;
          loading = false;
        });
      }
    }
  }

  Future<void> load() => run(() async {
    final BackupData snapshot;
    try {
      snapshot = await service.overview();
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(BackupFailure.readFailed);
    }
    final fingerprint = await BackupFingerprints.compute(snapshot);
    final control = await service.metadata.state();
    final logs = await service.metadata.operations();
    if (!mounted) return;
    setState(() {
      current = snapshot;
      currentDigest = fingerprint.contentDigest;
      state = control;
      operations = logs;
      loading = false;
    });
  });
  Future<void> goHome() async {
    await service.clearCandidate();
    if (!mounted) return;
    setState(() {
      screen = 'home';
      preview = null;
      error = null;
      loading = true;
    });
    await load();
  }

  Future<void> back() async {
    if (canCancelRead) {
      requestVersion++;
      await service.clearCandidate();
      if (mounted) {
        setState(() {
          busy = false;
          preview = null;
          error = null;
          screen = 'choose';
        });
      }
      return;
    }
    if (busy || restricted) return;
    if (screen == 'home') {
      Navigator.of(context).pop();
      return;
    }
    if (screen == 'copy') {
      await showCopies();
      return;
    }
    await goHome();
  }

  Future<void> choose() => run(() async {
    preview = null;
    final chosen = await service.selectFile();
    if (mounted) {
      setState(() {
        preview = chosen;
        screen = chosen == null ? 'choose' : 'preview';
      });
    }
  });
  Future<void> showCopies() => run(() async {
    await service.copies.reconcile();
    service.copyCheckError = null;
    final rows = await service.metadata.copies();
    operations = await service.metadata.operations();
    if (mounted) {
      setState(() {
        copies = rows;
        screen = 'copies';
      });
    }
  });
  Future<void> openCopy(BackupMap row) => run(() async {
    selectedCopy = row;
    copyDocument = null;
    setState(() => screen = 'copy');
    copyDocument = await service.copies.read(row['id'] as String);
  });
  Future<bool> confirm({
    required String Function(AppLocalizations) title,
    required String Function(AppLocalizations) body,
    required String Function(AppLocalizations) action,
  }) async {
    var answered = false;
    void answer(BuildContext dialog, bool value) {
      if (answered) return;
      answered = true;
      Navigator.pop(dialog, value);
    }

    try {
      return await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              scrollable: true,
              title: Text(title(dialogContext.l10n)),
              content: Text(body(dialogContext.l10n)),
              actions: [
                TextButton(
                  autofocus: true,
                  onPressed: () => answer(dialogContext, false),
                  child: Text(dialogContext.l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: dialogContext.appColors.danger,
                    foregroundColor: dialogContext.appColors.onDanger,
                    minimumSize: const Size(48, 56),
                  ),
                  onPressed: () => answer(dialogContext, true),
                  child: Text(action(dialogContext.l10n)),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      answered = true;
    }
  }

  Future<void> restore() async {
    final target = preview!;
    final undo = target.undoOf != null;
    final accepted = await confirm(
      title: (l) => undo ? l.backupUndo : l.backupRestore,
      body: (l) {
        final settings = undo
            ? (target.restoreSettings
                  ? l.backupUndoSettings
                  : l.backupUndoKeepSettings)
            : (target.restoreSettings
                  ? l.backupSettingsHelp
                  : l.backupKeepSettings);
        return '${target.fileName}\n\n${l.backupTime(stamp(target.document.snapshotAt))}\n\n'
            '${l.backupCounts(target.document.data.plans.length, target.document.data.workouts.length)}\n\n'
            '${undo ? l.backupUndoNotice : l.backupReplaceNotice}\n\n$settings';
      },
      action: (l) => undo ? l.backupUndoConfirm : l.backupReplace,
    );
    if (!accepted || !mounted) return;
    await run(() async {
      try {
        result = await service.restore(target);
      } on BackupException catch (failure) {
        if ([
          BackupFailure.protection,
          BackupFailure.rolledBack,
        ].contains(failure.code)) {
          markOutcomeVisible(target.id, failed: true);
        }
        rethrow;
      }
      if (mounted) {
        setState(() => screen = 'result');
        markOutcomeVisible(target.id);
      }
    });
  }

  void markOutcomeVisible(String id, {bool failed = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || (failed ? error == null : screen != 'result')) return;
      try {
        await service.metadata.updateOperation(id, {'result_seen': 1});
      } catch (_) {
        // An unrecorded presentation remains discoverable on the next launch.
      }
    });
  }

  String stamp(DateTime value) =>
      '${context.formats.date(value)} ${context.formats.time(value)}';
  String interruptedSummary(AppLocalizations l, BackupMap operation) {
    final summary =
        jsonDecode(operation['target_summary'] as String) as BackupMap;
    return '${l.backupCounts(summary['planCount'] as int, summary['workoutCount'] as int)}\n'
        '${l.backupTime(stamp(DateTime.parse(summary['snapshotAt'] as String)))}';
  }

  String lastExportText(AppLocalizations l) {
    final time = state?['last_export_at'] as int?;
    return time == null
        ? l.backupNever
        : l.backupLastExport(stamp(DateTime.fromMillisecondsSinceEpoch(time)));
  }

  Widget activeSummary(AppLocalizations l) {
    final workout = activeWorkout!;
    final progress = l.orderProgress(
      l.workoutInProgress,
      workout['completed'] as int,
      workout['total'] as int,
    );
    final name = workout['name'] as String;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(name), const SizedBox(height: 8), Text(progress)],
      ),
    );
  }

  String copyPurpose(AppLocalizations l, BackupMap row) {
    final operation = operations
        .where((op) => op['id'] == row['operation_id'])
        .firstOrNull;
    return switch (operation?['kind']) {
      'undo' => l.backupCopyBeforeUndo,
      'restore' => l.backupCopyBeforeRestore,
      _ => l.backupCopyRecovered,
    };
  }

  String copyTime(BackupMap row) =>
      stamp(DateTime.parse(row['snapshot_at'] as String));
  String copyCounts(AppLocalizations l, BackupMap row) =>
      l.backupCounts(row['plan_count'] as int, row['workout_count'] as int);
  String copySize(AppLocalizations l, BackupMap row) =>
      l.backupSize(context.formats.decimal((row['byte_count'] as int) / 1024));
  String settingLabel(AppLocalizations l, String field) => switch (field) {
    'themeMode' => l.appearance,
    'themeColor' => l.themeColor,
    'languageTag' => l.language,
    _ => l.restAlerts,
  };
  Widget title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    ),
  );
  Widget note(String text, {bool warning = false}) => AppCard(
    backgroundColor: warning
        ? context.appColors.warningSoft
        : context.appColors.accentSoft,
    child: Text(
      text,
      style: TextStyle(
        color: warning
            ? context.appColors.warning
            : context.appColors.onAccentSoft,
      ),
    ),
  );
  Widget counts(BackupData data, String label) {
    final dates =
        data.workouts.map((w) => w['startedLocalDate'] as String).toList()
          ..sort();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.appColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            context.l10n.backupCounts(data.plans.length, data.workouts.length),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            dates.isEmpty
                ? context.l10n.backupNoDates
                : context.l10n.backupRange(
                    context.formats.date(DateTime.parse(dates.first)),
                    context.formats.date(DateTime.parse(dates.last)),
                  ),
            style: TextStyle(
              fontSize: 14,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget action(
    String label,
    VoidCallback? callback, {
    bool primary = false,
    bool danger = false,
  }) {
    final button = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppButton(
        label: label,
        onPressed: busy ? null : callback,
        variant: danger
            ? AppButtonVariant.danger
            : primary
            ? AppButtonVariant.primary
            : AppButtonVariant.outline,
      ),
    );

    return primary ? _PrimaryAction(child: button) : button;
  }

  List<Widget> body() {
    final l = context.l10n;
    if (busy &&
        [
          'protecting',
          'restoring',
          'settings',
          'exporting',
          'validating',
          'checking',
        ].contains(service.phase)) {
      return [
        Semantics(
          liveRegion: true,
          child: title(backupPhase(l, service.phase)),
        ),
        if (!MediaQuery.disableAnimationsOf(context))
          const LinearProgressIndicator(),
        const SizedBox(height: 24),
        Text(l.backupPleaseWait),
      ];
    }
    if (screen == 'home') {
      return [
        for (final op in operations.where(
          (op) =>
              op['restore_settings'] == 1 &&
              ['settings_pending', 'core_committed'].contains(op['phase']),
        )) ...[
          const SizedBox(height: 24),
          note(l.backupSettingsPending, warning: true),
          action(
            l.backupRetrySettings,
            () => run(() async {
              await service.retrySettings(op['id'] as String);
              operations = await service.metadata.operations();
            }),
          ),
          action(
            l.backupSkipSettings,
            () => run(() async {
              await service.skipSettings(op['id'] as String);
              operations = await service.metadata.operations();
            }),
          ),
        ],
        for (final op in operations.where(
          (op) =>
              op['kind'] == 'export' &&
              !['completed', 'aborted'].contains(op['phase']),
        )) ...[
          const SizedBox(height: 24),
          note(l.backupPendingExport, warning: true),
          action(
            l.backupRepairLedger,
            () => run(() async {
              await service.reconcileExport(op['id'] as String);
              operations = await service.metadata.operations();
            }),
          ),
        ],
        for (final op in operations.where(
          (op) =>
              op['kind'] != 'export' &&
              op['result_seen'] == 0 &&
              [
                'completed',
                'aborted',
                'settings_skipped',
              ].contains(op['phase']),
        )) ...[
          const SizedBox(height: 24),
          note(
            op['phase'] == 'aborted'
                ? l.backupInterruptedBefore
                : l.backupInterruptedAfter,
          ),
          if (op['target_summary'] != null && op['phase'] == 'completed')
            Text(interruptedSummary(l, op)),
          action(
            l.backupDone,
            () => run(() async {
              await service.metadata.updateOperation(op['id'] as String, {
                'result_seen': 1,
              });
              operations = await service.metadata.operations();
            }),
          ),
        ],
        if (loading) Text(l.backupChecking),
        if (current != null && error == null) ...[
          counts(current!, l.backupCurrent),
          const SizedBox(height: 24),
          Text(lastExportText(l)),
          if (state?['last_export_digest'] != null) ...[
            const SizedBox(height: 8),
            Text(
              state!['last_export_digest'] == currentDigest
                  ? l.backupUnchanged
                  : l.backupChanged,
            ),
          ],
        ],
        action(
          l.backupCreate,
          current == null || error != null
              ? null
              : () => run(() async {
                  exportDocument = await service.createExportSnapshot();
                  setState(() => screen = 'export');
                }),
          primary: true,
        ),
        action(
          l.backupRestore,
          () => setState(() {
            screen = 'choose';
            error = null;
          }),
        ),
        action(l.backupCopies, showCopies),
        if (service.copyCheckError != null)
          note(l.backupCopyUnavailable, warning: true),
        if (state?['undo_operation_id'] != null)
          action(
            l.backupUndo,
            () => run(() async {
              preview = await service.previewUndo();
              setState(() => screen = 'preview');
            }),
          ),
        const SizedBox(height: 24),
        Text(
          l.backupCopiesBoundary,
          style: TextStyle(
            fontSize: 14,
            color: context.appColors.textSecondary,
          ),
        ),
      ];
    }
    if (screen == 'export') {
      return [
        title(l.backupCreate),
        counts(exportDocument!.data, l.backupCurrent),
        const SizedBox(height: 24),
        Text(l.backupScope),
        const SizedBox(height: 16),
        note(l.backupExportNotice),
        action(
          l.backupSaveFile,
          () => run(() async {
            saved = await service.export(exportDocument!, currentData: true);
            setState(() => screen = 'exportResult');
          }),
          primary: true,
        ),
      ];
    }
    if (screen == 'choose') {
      return [
        title(l.backupRestore),
        Text(l.backupSelectHelp),
        const SizedBox(height: 24),
        note(l.backupReplaceNotice, warning: true),
        action(l.backupChooseFile, choose, primary: true),
      ];
    }
    if (screen == 'preview') {
      final p = preview!;
      return [
        title(p.undoOf == null ? l.backupRestore : l.backupUndo),
        Text(l.backupTime(stamp(p.document.snapshotAt))),
        const SizedBox(height: 16),
        counts(p.current, l.backupCurrent),
        const SizedBox(height: 16),
        counts(p.document.data, l.backupTarget),
        const SizedBox(height: 24),
        note(
          p.undoOf == null ? l.backupReplaceNotice : l.backupUndoNotice,
          warning: true,
        ),
        const SizedBox(height: 16),
        if (p.undoOf == null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.backupSettings),
            subtitle: Text(l.backupSettingsHelp),
            value: p.restoreSettings,
            onChanged: (v) =>
                setState(() => preview = p.withSettings(v ?? true)),
          )
        else
          Text(
            p.restoreSettings ? l.backupUndoSettings : l.backupUndoKeepSettings,
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l.backupDetails),
          children: [
            SelectableText(p.fileName),
            Text(l.backupSourceVersion(p.document.sourceAppVersion)),
            Text(l.backupSize(context.formats.decimal(p.bytes / 1024))),
          ],
        ),
        action(l.backupContinue, error == null ? restore : null, primary: true),
        action(l.backupChooseFile, choose),
      ];
    }
    if (screen == 'exportResult') {
      return [
        title(l.backupSaved),
        SelectableText(saved!['fileName'] as String),
        const SizedBox(height: 16),
        Text(l.backupSavedLocation),
        if (saved!['ledgerPending'] == true) ...[
          const SizedBox(height: 24),
          note(l.backupLedgerPending, warning: true),
          action(
            l.backupRepairLedger,
            () => run(() async {
              final receipt = await service.reconcileExport(
                saved!['operationId'] as String,
              );
              if (receipt['state'] != 'published') {
                throw const BackupException(BackupFailure.storage);
              }
              setState(() => saved!['ledgerPending'] = false);
            }),
          ),
        ],
        action(l.backupDone, goHome, primary: true),
      ];
    }
    if (screen == 'result') {
      final r = result!;
      return [
        title(preview?.undoOf == null ? l.backupRestored : l.backupUndone),
        counts(r.document.data, l.backupTarget),
        const SizedBox(height: 24),
        note(l.backupCopiesBoundary),
        if (r.settingsPending.isNotEmpty) ...[
          const SizedBox(height: 24),
          note(l.backupSettingsPending, warning: true),
          for (final field in r.settingsPending) Text(settingLabel(l, field)),

          action(
            l.backupRetrySettings,
            () => run(() async {
              final pending = await service.retrySettings(r.operationId);
              setState(
                () => result = BackupOperationResult(
                  r.operationId,
                  r.document,
                  settingsPending: pending,
                  refreshFailed: r.refreshFailed,
                ),
              );
            }),
            primary: true,
          ),
          action(
            l.backupSkipSettings,
            () => run(() async {
              await service.skipSettings(r.operationId);
              setState(
                () => result = BackupOperationResult(
                  r.operationId,
                  r.document,
                  refreshFailed: r.refreshFailed,
                ),
              );
            }),
          ),
        ],
        if (r.refreshFailed) ...[
          const SizedBox(height: 24),
          note(l.backupRefreshFailed, warning: true),
          action(
            l.retry,
            () => run(() async {
              await service.onCommitted?.call();
              setState(
                () => result = BackupOperationResult(
                  r.operationId,
                  r.document,
                  settingsPending: r.settingsPending,
                ),
              );
            }),
          ),
        ],
        action(
          l.backupViewHistory,
          widget.onHistory,
          primary: r.settingsPending.isEmpty,
        ),
        if (preview?.undoOf == null)
          action(
            l.backupUndo,
            () => run(() async {
              preview = await service.previewUndo();
              setState(() => screen = 'preview');
            }),
          ),
        action(l.backupCopies, showCopies),
        action(l.backupDone, goHome),
      ];
    }
    if (screen == 'copies') {
      return [
        title(l.backupCopies),
        note(l.backupCopiesBoundary),
        const SizedBox(height: 24),
        if (copies.isEmpty) Text(l.backupNoCopies),
        for (final row in copies)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () => openCopy(row),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(copyTime(row)),
                        Text(copyPurpose(l, row)),
                        Text(copyCounts(l, row)),
                        Text(copySize(l, row)),
                        if (row['state'] != 'ready')
                          Text(l.backupCopyUnavailable),
                      ],
                    ),
                  ),
                  const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                ],
              ),
            ),
          ),
      ];
    }
    if (screen == 'copy') {
      return [
        title(l.backupCopies),
        SelectableText(selectedCopy!['relative_path'] as String),
        const SizedBox(height: 8),
        Text(copyPurpose(l, selectedCopy!)),
        Text(l.backupTime(copyTime(selectedCopy!))),
        const SizedBox(height: 16),
        if (copyDocument != null) counts(copyDocument!.data, l.backupTarget),
        const SizedBox(height: 24),
        note(l.backupCopiesBoundary),
        action(
          l.backupCopyExport,
          copyDocument == null
              ? null
              : () => run(() async {
                  saved = await service.export(
                    await service.copies.read(selectedCopy!['id'] as String),
                    currentData: false,
                  );
                  setState(() => screen = 'exportResult');
                }),
        ),
        action(
          l.backupCopyRestore,
          copyDocument == null
              ? null
              : () => run(() async {
                  preview = await service.previewCopy(
                    selectedCopy!['id'] as String,
                  );
                  setState(() => screen = 'preview');
                }),
          primary: true,
        ),
        action(l.backupCopyDelete, () async {
          if (!await confirm(
            title: (l) => l.backupCopyDelete,
            body: (l) =>
                '${selectedCopy!['relative_path']}\n\n${l.backupDeleteNotice}',
            action: (l) => l.backupCopyDelete,
          )) {
            return;
          }
          await run(() async {
            copyDocument = null;
            try {
              await service.copies.delete(selectedCopy!['id'] as String);
            } catch (_) {
              throw const BackupException(BackupFailure.deleteFailed);
            }
            copies = await service.metadata.copies();
            setState(() => screen = 'copies');
          });
        }, danger: true),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final content = <Widget>[
      if (busy &&
          !loading &&
          ['idle', 'completed', 'preview'].contains(service.phase))
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(liveRegion: true, child: Text(l.backupChecking)),
        ),
      if (error != null) ...[
        Semantics(
          liveRegion: true,
          child: note(backupError(l, error!), warning: true),
        ),
        if (error is BackupException &&
            (error as BackupException).code == BackupFailure.activeWorkout) ...[
          if (activeWorkout != null) activeSummary(l),
          action(
            l.backupOpenWorkout,
            () => run(widget.onWorkout),
            primary: true,
          ),
        ] else if (restricted)
          action(
            l.retry,
            () => run(() async {
              await service.reconcileStartup();
              current = await service.overview();
              currentDigest = (await BackupFingerprints.compute(current!))
                  .contentDigest;
              state = await service.metadata.state();
              operations = await service.metadata.operations();
              screen = 'home';
              preview = null;
            }),
            primary: true,
          )
        else if (error is BackupException &&
            (error as BackupException).code == BackupFailure.planFile)
          action(l.backupGoPlanImport, () => run(widget.onPlanImport))
        else if (screen == 'home')
          action(l.retry, load),
        if (screen == 'preview')
          action(
            l.backupReviewAgain,
            () => run(() async {
              final old = preview!;
              preview = old.copyId == null
                  ? await service.selectFile(
                      restoreSettings: old.restoreSettings,
                    )
                  : await service.previewCopy(
                      old.copyId!,
                      restoreSettings: old.restoreSettings,
                      undoOf: old.undoOf,
                    );
              if (preview == null) setState(() => screen = 'choose');
            }),
          ),
        const SizedBox(height: 24),
      ],
      if (!restricted) ...body(),
    ];
    final primary = content.whereType<_PrimaryAction>().toList();
    content.removeWhere((item) => item is _PrimaryAction);
    final scroll = ListView(
      key: ValueKey(screen),
      padding: const EdgeInsets.all(24),
      children: content,
    );
    return PopScope(
      canPop: !busy && !restricted && screen == 'home',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(back());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.backupTitle),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: canCancelRead
                ? back
                : busy || restricted
                ? null
                : back,
          ),
        ),
        body: primary.isEmpty
            ? SafeArea(child: scroll)
            : AppTaskLayout(
                body: scroll,
                actions: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: error == null ? primary : [primary.first],
                ),
              ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
