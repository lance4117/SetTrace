import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/diagnostics/diagnostic_contract.dart';
import '../../core/diagnostics/diagnostics_client.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_task_layout.dart';
import '../../l10n/localization.dart';
import 'diagnostics_controller.dart';

typedef DiagnosticStateSource = Future<Map<String, Object?>> Function();

String diagnosticError(AppLocalizations l, String? reason) => switch (reason) {
  'no_space' => l.diagNoSpace,
  'permission_denied' => l.diagPermission,
  'permission_permanent' => l.diagPermanentPermission,
  'publication_unknown' => l.diagUnknownHelp,
  'missing' || 'not_found' => l.diagFileMissing,
  'unsupported' || 'unsupported_version' => l.diagUnsupported,
  _ => l.diagStorageFailed,
};
String _dateTime(BuildContext context, DateTime time) =>
    '${context.formats.date(time)} ${context.formats.time(time)}';
String _range(BuildContext context, DiagnosticsOverview? value) =>
    value?.firstTime != null && value?.lastTime != null
    ? '${_dateTime(context, value!.firstTime!)} — ${_dateTime(context, value.lastTime!)}'
    : value?.eventCount == 0
    ? context.l10n.diagEmpty
    : context.l10n.diagRangeUnknown;
(String, String) _sizeParts(BuildContext context, int bytes) => bytes < 1024
    ? ('$bytes', 'B')
    : bytes < 1024 * 1024
    ? (context.formats.decimal(bytes / 1024), 'KiB')
    : (context.formats.decimal(bytes / (1024 * 1024)), 'MiB');
String _size(BuildContext context, int bytes) {
  final (number, unit) = _sizeParts(context, bytes);
  return '$number $unit';
}

Widget _heading(String text) => Semantics(
  header: true,
  child: Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  ),
);
Widget _paragraph(String text) =>
    Padding(padding: const EdgeInsets.only(top: 8), child: Text(text));
Widget _scroll(List<Widget> children) => ListView(
  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
  children: children,
);
Widget _note(
  BuildContext context,
  String text, {
  bool warning = false,
  bool error = false,
}) => Semantics(
  liveRegion: true,
  child: AppCard(
    backgroundColor: error
        ? context.appColors.dangerSoft
        : warning
        ? context.appColors.warningSoft
        : context.appColors.accentSoft,
    child: Text(
      text,
      style: TextStyle(
        color: error
            ? context.appColors.danger
            : warning
            ? context.appColors.warning
            : context.appColors.onAccentSoft,
      ),
    ),
  ),
);

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, this.controller, this.stateSource});
  final DiagnosticsController? controller;
  final DiagnosticStateSource? stateSource;
  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage>
    with WidgetsBindingObserver {
  late final DiagnosticsController c =
      widget.controller ?? DiagnosticsController(DiagnosticsClient.instance);
  final _detailFocus = FocusNode(),
      _privacyFocus = FocusNode(),
      _clearFocus = FocusNode();
  String? clearMessage;
  Timer? _expiry;
  DateTime? _scheduledDeadline;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    unawaited(c.load());
  }

  void _changed() {
    final until = c.overview?.detailedUntil;
    if (until != _scheduledDeadline) {
      _expiry?.cancel();
      _scheduledDeadline = until;
      if (until != null && until.isAfter(DateTime.now())) {
        _expiry = Timer(
          until.difference(DateTime.now()) + const Duration(milliseconds: 50),
          () => c.load(recoverExport: false),
        );
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(c.resume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    _expiry?.cancel();
    _detailFocus.dispose();
    _privacyFocus.dispose();
    _clearFocus.dispose();
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  Future<void> _export({bool review = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiagnosticsExportPage(
          controller: c,
          reviewExisting: review,
          stateSource: widget.stateSource,
        ),
      ),
    );
    if (mounted) unawaited(c.load(recoverExport: false));
  }

  Future<void> _clear() async {
    final l = context.l10n;
    if (c.exporting ||
        c.export?.stage == DiagnosticExportStage.unknown ||
        c.exportError == 'publication_unknown') {
      setState(() => clearMessage = l.diagClearBusy);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l.diagClearTitle),
        content: Text(l.diagClearBody),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          AppButton(
            label: l.diagClearConfirm,
            variant: AppButtonVariant.danger,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _clearFocus.requestFocus();
    if (confirmed != true) return;
    await c.clear();
    if (mounted) {
      setState(
        () => clearMessage = c.controlError == null
            ? l.diagCleared
            : c.controlError == 'busy'
            ? l.diagClearBusy
            : l.diagClearFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, value = c.overview;
    final detailed = value?.detailedUntil?.isAfter(DateTime.now()) == true;
    return PopScope(
      canPop: !c.controlling,
      child: Scaffold(
        appBar: AppBar(title: Text(l.diagTitle)),
        body: AppTaskLayout(
          body: _scroll([
            Text(l.diagIntro),
            const SizedBox(height: 24),
            if (c.loading)
              Semantics(liveRegion: true, child: Text(l.diagLoading)),
            if (c.overviewFailed) ...[
              _note(context, l.diagReadFailedHelp, warning: true),
              TextButton(
                onPressed: c.loading
                    ? null
                    : () => c.load(recoverExport: false),
                child: Text(l.retry),
              ),
            ] else if (value != null) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      key: const ValueKey('diagnostics-enabled'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l.diagLogging,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(l.diagLocalOnly),
                      value: value.enabled,
                      onChanged: c.blocked || c.loading ? null : c.setEnabled,
                    ),
                    if (!value.enabled) _paragraph(l.diagOffHelp),
                    if (c.controlError != null) _paragraph(l.diagControlFailed),
                    if (c.controlling) const LinearProgressIndicator(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _heading(l.diagSavedLogs),
                        Text(
                          value.enabled ? l.diagRecording : l.diagOff,
                          style: TextStyle(
                            color: context.appColors.onAccentSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(_range(context, value)),
                    const SizedBox(height: 12),
                    Semantics(
                      label:
                          '${l.diagSize}: ${_size(context, value.bytes)} / 20 MiB',
                      child: ExcludeSemantics(
                        child: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _sizeParts(context, value.bytes).$1,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_sizeParts(context, value.bytes).$2} / 20 MiB',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ExcludeSemantics(
                      child: LinearProgressIndicator(
                        value: (value.bytes / (20 * 1024 * 1024)).clamp(0, 1),
                      ),
                    ),
                    _paragraph(l.diagRetention),
                    if (value.missing.isNotEmpty) _paragraph(l.diagGaps),
                  ],
                ),
              ),
              if (value.limited) ...[
                const SizedBox(height: 16),
                _note(context, l.diagLimitedHelp, warning: true),
              ],
            ],
            if (c.controlError != null && c.overviewFailed)
              _note(context, l.diagControlUnknown, error: true),
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                focusNode: _detailFocus,
                contentPadding: const EdgeInsets.all(16),
                title: Text(l.diagDetailed),
                subtitle: Text(
                  detailed
                      ? l.diagDetailedUntil(
                          _dateTime(context, value!.detailedUntil!),
                        )
                      : l.diagDetailedSubtitle,
                ),
                trailing: const ExcludeSemantics(
                  child: Icon(Icons.chevron_right),
                ),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DiagnosticsDetailedPage(controller: c),
                    ),
                  );
                  if (mounted) _detailFocus.requestFocus();
                },
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              focusNode: _privacyFocus,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Text(l.diagPrivacy),
              trailing: const ExcludeSemantics(
                child: Icon(Icons.chevron_right),
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DiagnosticsPrivacyPage(),
                  ),
                );
                if (mounted) _privacyFocus.requestFocus();
              },
            ),
            TextButton(
              focusNode: _clearFocus,
              style: TextButton.styleFrom(
                foregroundColor: context.appColors.danger,
                alignment: Alignment.centerLeft,
                minimumSize: const Size(48, 48),
              ),
              onPressed: c.controlling ? null : _clear,
              child: Text(l.diagClear),
            ),
            if (clearMessage != null) _paragraph(clearMessage!),
            if (c.export != null &&
                    c.export!.stage != DiagnosticExportStage.cancelled ||
                c.exportError == 'publication_unknown')
              TextButton(
                onPressed: () => _export(review: true),
                child: Text(l.diagReviewExport),
              ),
          ]),
          actions: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: l.diagExport,
                onPressed: c.controlling ? null : _export,
              ),
              const SizedBox(height: 8),
              Text(
                l.diagExportHint,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiagnosticsDetailedPage extends StatelessWidget {
  const DiagnosticsDetailedPage({super.key, required this.controller});
  final DiagnosticsController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller, l = context.l10n;
      final value = c.overview,
          on = value?.detailedUntil?.isAfter(DateTime.now()) == true;
      return PopScope(
        canPop: !c.controlling,
        child: Scaffold(
          appBar: AppBar(title: Text(l.diagDetailed)),
          body: AppTaskLayout(
            body: _scroll([
              _heading(l.diagDetailedIntro),
              const SizedBox(height: 24),
              AppCard(child: Text(l.diagDetailedRules)),
              const SizedBox(height: 16),
              _note(
                context,
                on
                    ? l.diagDetailedUntil(
                        _dateTime(context, value!.detailedUntil!),
                      )
                    : l.diagDetailedOff,
              ),
              if (value?.enabled != true)
                _paragraph(l.diagDetailedNeedsLogging),
              if (c.controlError != null)
                _paragraph(
                  c.overviewFailed ? l.diagControlUnknown : l.diagControlFailed,
                ),
              const SizedBox(height: 24),
              Text(l.diagLocalOnly),
            ]),
            actions: AppButton(
              label: on ? l.diagDisableDetailed : l.diagEnableDetailed,
              busy: c.controlling,
              onPressed:
                  value?.enabled == true && !c.overviewFailed && !c.blocked
                  ? () => c.setDetailed(!on)
                  : null,
            ),
          ),
        ),
      );
    },
  );
}

class DiagnosticsPrivacyPage extends StatelessWidget {
  const DiagnosticsPrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.diagPrivacy)),
      body: SafeArea(
        child: _scroll([
          _heading(l.diagLogging),
          _paragraph(l.diagPrivacyContent),
          const SizedBox(height: 24),
          _heading(l.diagRetention),
          _paragraph(l.diagPrivacyRetention),
          const SizedBox(height: 24),
          _heading(l.diagSharingTitle),
          _paragraph(l.diagPrivacySharing),
          const SizedBox(height: 24),
          _heading(l.diagClear),
          _paragraph(l.diagPrivacyClear),
        ]),
      ),
    );
  }
}

class DiagnosticsExportPage extends StatefulWidget {
  const DiagnosticsExportPage({
    super.key,
    required this.controller,
    this.stateSource,
    this.reviewExisting = false,
  });
  final DiagnosticsController controller;
  final DiagnosticStateSource? stateSource;
  final bool reviewExisting;
  @override
  State<DiagnosticsExportPage> createState() => _DiagnosticsExportPageState();
}

class _DiagnosticsExportPageState extends State<DiagnosticsExportPage>
    with WidgetsBindingObserver {
  DiagnosticsController get c => widget.controller;
  bool starting = false;
  late bool showResult =
      widget.reviewExisting ||
      c.exporting ||
      c.export?.stage == DiagnosticExportStage.unknown;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(c.resume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _start() async {
    if (starting || c.blocked) return;
    setState(() {
      starting = true;
      showResult = true;
    });
    Map<String, Object?> state;
    try {
      state =
          await widget.stateSource?.call().timeout(
            const Duration(seconds: 1),
          ) ??
          {
            'available': false,
            'reason': 'initialization',
            'captured_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
          };
    } catch (_) {
      state = {
        'available': false,
        'reason': 'read_failed',
        'captured_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
      };
    }
    if (mounted) await c.startExport(state: state);
    if (mounted) setState(() => starting = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final l = context.l10n, result = showResult ? c.export : null;
      final error = showResult ? c.exportError : null;
      final unknown =
          result?.stage == DiagnosticExportStage.unknown ||
          c.exportError == 'publication_unknown';
      final progress = !unknown && (starting || c.exporting);
      final failed =
          !unknown &&
          (result?.stage == DiagnosticExportStage.failed ||
              error != null && error != 'cancelled');
      final saved = !unknown && result?.saved == true;
      final partial = result?.stage == DiagnosticExportStage.saved_partial;
      final title = unknown
          ? l.diagUnknown
          : saved
          ? partial
                ? l.diagPartial
                : l.diagSaved
          : failed
          ? l.diagFailed
          : progress
          ? l.diagProgress
          : l.diagExportHeading;
      final reason = error ?? result?.reason;
      return PopScope(
        canPop: !progress,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(c.cancel());
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(l.diagExport),
            leading: BackButton(
              onPressed: progress
                  ? () => c.cancel()
                  : () => Navigator.pop(context),
            ),
          ),
          body: AppTaskLayout(
            body: _scroll([
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (unknown)
                _note(context, l.diagUnknownHelp, warning: true)
              else if (saved) ...[
                Text(l.diagSavedHelp),
                const SizedBox(height: 24),
                if (partial) ...[
                  _note(
                    context,
                    result!.missing.any(
                          (item) => {
                            'read_failed',
                            'corrupt_tail',
                            'queue_overflow',
                            'clock_changed',
                            'missing',
                            'incomplete',
                          }.contains(item),
                        )
                        ? l.diagMissingLogs
                        : l.diagMissingEnvironment,
                    warning: true,
                  ),
                  const SizedBox(height: 16),
                ],
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading(l.diagFile),
                      const SizedBox(height: 16),
                      Text(l.diagFileName),
                      const SizedBox(height: 8),
                      SelectableText(
                        result!.fileName ?? '',
                        key: const ValueKey('diagnostics-filename'),
                      ),
                      const SizedBox(height: 16),
                      Text(l.diagLocation),
                      _paragraph(l.diagDownloads),
                      const SizedBox(height: 16),
                      Text(l.diagSize),
                      _paragraph(_size(context, result.bytes ?? 0)),
                    ],
                  ),
                ),
              ] else if (failed) ...[
                _note(context, diagnosticError(l, reason), error: true),
                if (reason == 'permission_permanent')
                  TextButton(
                    onPressed: () async {
                      try {
                        await c.client.transport?.call('openAppSettings');
                      } catch (_) {}
                    },
                    child: Text(l.diagSettings),
                  ),
              ] else if (progress) ...[
                Text(l.diagProgressHelp),
                const SizedBox(height: 24),
                if (c.cancelling)
                  _note(context, l.diagCancelling)
                else if (result?.stage == DiagnosticExportStage.publishing)
                  _note(context, l.diagPublishing),
                const SizedBox(height: 16),
                for (var index = 0; index < 3; index++)
                  _step(context, index, result?.stage),
              ] else ...[
                Text(l.diagExportIntro),
                const SizedBox(height: 24),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading(l.diagThisExport),
                      const SizedBox(height: 16),
                      Text(l.diagRange),
                      _paragraph(
                        c.overviewFailed
                            ? l.diagRangeUnknown
                            : _range(context, c.overview),
                      ),
                      const SizedBox(height: 16),
                      Text(l.diagLocation),
                      _paragraph(l.diagDownloads),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _heading(l.diagIncludes),
                _paragraph(l.diagEnvironment),
                _paragraph(
                  c.overview?.eventCount == 0 && !c.overviewFailed
                      ? l.diagEnvironmentOnly
                      : l.diagOperations,
                ),
                const SizedBox(height: 24),
                _note(
                  context,
                  '${l.diagSharingTitle}\n\n${l.diagPrivacySharing}',
                ),
              ],
            ]),
            actions: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unknown) ...[
                  AppButton(
                    label: l.diagInspect,
                    busy: c.inspecting,
                    onPressed: c.inspect,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.close),
                  ),
                ] else if (saved)
                  AppButton(
                    label: l.diagDone,
                    onPressed: () => Navigator.pop(context),
                  )
                else if (progress)
                  AppButton(
                    label: c.cancelling
                        ? l.diagCancelling
                        : result?.cancellable == false
                        ? l.diagPublishing
                        : l.diagCancelExport,
                    primary: false,
                    onPressed: c.cancelling || result?.cancellable == false
                        ? null
                        : c.cancel,
                  )
                else
                  AppButton(
                    label: failed ? l.retry : l.diagSave,
                    onPressed: c.blocked ? null : _start,
                  ),
                if (!progress && !saved && !unknown) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.diagZipHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _step(BuildContext context, int index, DiagnosticExportStage? stage) {
    final l = context.l10n;
    final current = switch (stage) {
      DiagnosticExportStage.packaging => 1,
      DiagnosticExportStage.writing_unpublished ||
      DiagnosticExportStage.verifying ||
      DiagnosticExportStage.publishing => 2,
      _ => 0,
    };
    final status = index < current
        ? l.diagStepDone
        : index == current
        ? l.diagStepActive
        : l.diagStepWaiting;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Semantics(
        liveRegion: index == current,
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              '${index + 1}. ${[l.diagCollect, l.diagPackage, l.diagVerify][index]}',
            ),
            Text(status),
          ],
        ),
      ),
    );
  }
}
