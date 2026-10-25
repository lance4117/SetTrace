import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/diagnostics/diagnostic_contract.dart';
import '../../core/diagnostics/diagnostic_observation.dart';
import '../../core/diagnostics/diagnostics_client.dart';

import '../../l10n/localization.dart';
import '../../l10n/error_messages.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_task_layout.dart';
import 'plan_models.dart';
import 'plan_repository.dart';
import 'plan_transfer.dart';
import 'plan_transfer_platform.dart';

class PlanExportPage extends StatefulWidget {
  const PlanExportPage({
    super.key,
    required this.plans,
    required this.platform,
  });
  final PlanRepository plans;
  final PlanTransferPlatform platform;
  @override
  State<PlanExportPage> createState() => _PlanExportPageState();
}

class _PlanExportPageState extends State<PlanExportPage> {
  List<WorkoutPlan> items = [];
  Set<int> selected = {};
  bool loading = true, busy = false, successful = false;
  LocalizedMessage? message;
  bool? fileOperation;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final plans = await widget.plans.listPlans();
      if (mounted) {
        setState(() {
          items = plans;
          selected = plans.map((p) => p.id).toSet();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          message = (l) => l.plansLoadFailed;
        });
      }
    }
  }

  Future<void> output(bool file) async {
    if (busy || selected.isEmpty) return;
    setState(() {
      busy = true;
      fileOperation = file;
      message = null;
      successful = false;
    });
    try {
      final plans = await widget.plans.exportPlans(Set.of(selected));
      final text = PlanTransferCodec().encode(
        PlanTransferDocument(plans, exportedAt: DateTime.now().toUtc()),
      );
      final LocalizedMessage result;
      if (file) {
        final saved = await diagnosticObserve(
          DiagnosticsClient.instance,
          DiagnosticName.transferExport,
          () => widget.platform.saveFile(text),
        );
        result = (l) => l.fileSaved(saved.fileName);
      } else {
        await diagnosticObserve(
          DiagnosticsClient.instance,
          DiagnosticName.transferCopy,
          () => widget.platform.copyText(text),
        );
        result = (l) => l.copySuccess(plans.length);
      }
      if (mounted) {
        setState(() {
          message = result;
          successful = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              message = (l) => failureText(l, error, fallback: l.exportFailed),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.exportPlans),
        automaticallyImplyLeading: !busy,
      ),
      body: AppTaskLayout(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Text(
              context.l10n.exportNote,
              style: TextStyle(color: context.appColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  context.l10n.selectedPlans(selected.length),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: busy || loading
                      ? null
                      : () => setState(
                          () => selected = items.map((p) => p.id).toSet(),
                        ),
                  child: Text(context.l10n.selectAll),
                ),
                TextButton(
                  onPressed: busy || loading
                      ? null
                      : () => setState(() => selected = {}),
                  child: Text(context.l10n.deselectAll),
                ),
              ],
            ),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (items.isEmpty)
              Text(context.l10n.noExportPlans),
            for (final plan in items) ...[
              AppCard(
                padding: EdgeInsets.zero,
                child: CheckboxListTile(
                  value: selected.contains(plan.id),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            selected.add(plan.id);
                          } else {
                            selected.remove(plan.id);
                          }
                        }),
                  title: Text(plan.name),
                  subtitle: Text(
                    context.l10n.exerciseSummary(
                      plan.exercises.length,
                      plan.totalSets,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
        actions: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  message!(context.l10n),
                  style: TextStyle(
                    color: successful
                        ? context.appColors.onAccentSoft
                        : context.appColors.danger,
                  ),
                ),
              ),
              if (!successful && items.isEmpty)
                TextButton(onPressed: load, child: Text(context.l10n.retry)),
            ],
            AppButton(
              label: context.l10n.copyClipboard,
              primary: false,
              busy: busy && fileOperation == false,
              onPressed: busy || selected.isEmpty ? null : () => output(false),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: context.l10n.exportFile,
              busy: busy && fileOperation == true,
              onPressed: busy || selected.isEmpty ? null : () => output(true),
            ),
          ],
        ),
      ),
    ),
  );
}

class PlanImportPage extends StatefulWidget {
  const PlanImportPage({
    super.key,
    required this.plans,
    required this.platform,
  });
  final PlanRepository plans;
  final PlanTransferPlatform platform;
  @override
  State<PlanImportPage> createState() => _PlanImportPageState();
}

class _PlanImportPageState extends State<PlanImportPage> {
  final input = TextEditingController();
  List<TransferPlan>? preview;
  List<TextEditingController> names = [];
  bool busy = false;
  bool closing = false, validatedNames = false;
  ImportSuffix? previewSuffix;
  LocalizedMessage? message;
  @override
  void dispose() {
    input.dispose();
    for (final c in names) {
      c.dispose();
    }
    super.dispose();
  }

  void showPreview(List<TransferPlan> plans) {
    for (final c in names) {
      c.dispose();
    }
    names = plans.map((p) => TextEditingController(text: p.name)).toList();
    setState(() => preview = plans);
  }

  Future<void> prepare(String text) async {
    final parsed = await diagnosticObserve(
      DiagnosticsClient.instance,
      DiagnosticName.transferParse,
      () async => PlanTransferCodec().decode(text),
      readOnly: true,
      recordSuccess: false,
    );
    if (!mounted) return;
    previewSuffix = context.l10n.importSuffix;
    final resolved = await widget.plans.previewImport(
      parsed.plans,
      suffixFor: previewSuffix!,
    );
    if (mounted) showPreview(resolved);
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              message = (l) => failureText(l, error, fallback: l.importFailed),
        );
      }
    } finally {
      if (mounted && !closing) setState(() => busy = false);
    }
  }

  Future<void> paste() => perform(() async {
    final text = await widget.platform.readClipboard();
    if (text == null || text.trim().isEmpty) {
      throw PlanTransferException(PlanTransferFailure.clipboardEmpty);
    }
    PlanTransferCodec.checkSize(text);
    if (mounted) setState(() => input.text = text);
  });
  Future<void> pick() => perform(() async {
    final text = await widget.platform.pickFile();
    if (text == null) {
      DiagnosticsClient.instance.event(
        DiagnosticName.transferParse,
        phase: DiagnosticPhase.cancelled,
        outcome: DiagnosticOutcome.cancelled,
        reason: DiagnosticReason.cancelled,
      );
    }
    if (text != null && mounted) await prepare(text);
  });
  Future<void> confirm() => perform(() async {
    setState(() => validatedNames = true);
    final edited = [
      for (var i = 0; i < preview!.length; i++)
        preview![i].withName(names[i].text),
    ];
    PlanTransferCodec().validatePlans(edited);
    final resolved = await widget.plans.previewImport(
      edited,
      suffixFor: previewSuffix!,
    );
    if (!mounted) return;
    if (Iterable<int>.generate(edited.length)
        .any((i) => edited[i].name != resolved[i].name)) {
      showPreview(resolved);
      setState(() => message = (l) => l.nameConflict);
      return;
    }
    try {
      final ids = await widget.plans.importPlans(
        edited,
        suffixFor: previewSuffix!,
      );
      if (mounted) {
        closing = true;
        Navigator.pop(context, ids.length);
      }
    } on ImportNameConflict catch (conflict) {
      if (mounted) {
        showPreview(conflict.plans);
        setState(() => message = (l) => l.nameTaken);
      }
    }
  });
  void reset() {
    for (final c in names) {
      c.dispose();
    }
    names = [];
    setState(() {
      preview = null;
      validatedNames = false;
      message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = preview;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            current == null
                ? context.l10n.importPlans
                : context.l10n.importPreview,
          ),
          automaticallyImplyLeading: !busy,
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
          ],
        ),
        body: AppTaskLayout(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              if (current == null) ...[
                Text(
                  context.l10n.importHint,
                  style: TextStyle(color: context.appColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('plan-import-text'),
                  controller: input,
                  minLines: 6,
                  maxLines: 10,
                  enabled: !busy,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.l10n.importPlans,
                    hintText: context.l10n.importTextHint,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: busy ? null : paste,
                    child: Text(context.l10n.paste),
                  ),
                ),
              ] else ...[
                Text(
                  context.l10n.importPreviewNote(current.length),
                  style: TextStyle(color: context.appColors.textSecondary),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < current.length; i++) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: ValueKey('import-name-$i'),
                          controller: names[i],
                          maxLength: 40,
                          enabled: !busy,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: context.l10n.planName,
                            errorText: validatedNames
                                ? (names[i].text.trim().isEmpty
                                      ? context.l10n.planNameRequired
                                      : names[i].text.trim().characters.length >
                                            40
                                      ? context.l10n.planNameTooLong
                                      : null)
                                : null,
                          ),
                        ),
                        Text(
                          context.l10n.exerciseSummary(
                            current[i].exercises.length,
                            current[i].totalSets,
                          ),
                        ),
                        if (current[i].exercises.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(context.l10n.emptyPlanNote),
                        ] else
                          ExpansionTile(
                            key: PageStorageKey('preview-config-$i'),
                            maintainState: true,
                            tilePadding: EdgeInsets.zero,
                            title: Text(context.l10n.viewExerciseConfig),
                            children: [
                              for (
                                var j = 0;
                                j < current[i].exercises.length;
                                j++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      context.l10n.transferExerciseDetails(
                                        j + 1,
                                        current[i].exercises[j].name,
                                        current[i].exercises[j].targetSets,
                                        current[i]
                                            .exercises[j]
                                            .restBetweenSetsSeconds,
                                        current[i]
                                            .exercises[j]
                                            .restAfterExerciseSeconds,
                                        context.formats.weightLabel(
                                          current[i]
                                              .exercises[j]
                                              .defaultWeightKg,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          ),
          actions: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message!(context.l10n),
                    style: TextStyle(color: context.appColors.danger),
                  ),
                ),
              ],
              AppButton(
                label: current == null
                    ? context.l10n.chooseFile
                    : context.l10n.chooseAgain,
                primary: false,
                onPressed: busy
                    ? null
                    : current == null
                    ? pick
                    : reset,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: current == null
                    ? context.l10n.previewPlans
                    : context.l10n.confirmImport,
                busy: busy,
                onPressed:
                    busy || (current == null && input.text.trim().isEmpty)
                    ? null
                    : current == null
                    ? () => perform(() => prepare(input.text))
                    : confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
