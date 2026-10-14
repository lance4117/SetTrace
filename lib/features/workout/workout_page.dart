import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/localization.dart';
import '../../l10n/error_messages.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_task_layout.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/step_picker.dart';
import 'workout_models.dart';
import 'workout_failure.dart';
import 'workout_repository.dart';
import 'session_order_sheet.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({
    super.key,
    required this.workouts,
    required this.sessionId,
  });
  final WorkoutRepository workouts;
  final int sessionId;

  @override
  State<WorkoutPage> createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPage> with WidgetsBindingObserver {
  WorkoutSessionData? session;
  LocalizedMessage? loadError;
  LocalizedMessage? actionError;
  Timer? ticker;
  bool busy = false;
  int writeRevision = 0, loadGeneration = 0;
  bool reloadPending = false;
  bool exitDialogOpen = false, finishOffered = false, actionDialogOpen = false;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload();
    ticker = Timer.periodic(Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => now = DateTime.now());
      final end = session?.restEndAt;
      if (end != null && !end.isAfter(now) && !busy) reload();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  @override
  void dispose() {
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> reload() async {
    if (busy) {
      reloadPending = true;
      return;
    }
    final generation = ++loadGeneration;
    final revision = writeRevision;
    try {
      await widget.workouts.normalizeRest(widget.sessionId);
      final data = await widget.workouts.getSession(widget.sessionId);
      if (mounted &&
          !busy &&
          generation == loadGeneration &&
          revision == writeRevision) {
        setState(() {
          session = data;
          loadError = null;
          now = DateTime.now();
        });
        if (data != null && data.readyToFinish && !finishOffered) {
          finishOffered = true;
          await askExit();
        }
      }
    } catch (error) {
      if (mounted &&
          generation == loadGeneration &&
          revision == writeRevision) {
        setState(
          () =>
              loadError = (l) => failureText(l, error, fallback: l.loadFailed),
        );
        showAppSnackBar(
          context,
          (l) => failureText(l, error, fallback: l.loadFailed),
          onRetry: reload,
        );
      }
    }
  }

  Future<WorkoutSessionData> write(
    Future<WorkoutSessionData> Function() operation,
  ) async {
    if (busy) throw StateError('saveInProgress');
    ++writeRevision;
    ++loadGeneration;
    setState(() => busy = true);
    try {
      final updated = await operation();
      if (mounted) {
        setState(() {
          session = updated;
          now = DateTime.now();
        });
      }
      return updated;
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (reloadPending) {
          reloadPending = false;
          await reload();
        }
      }
    }
  }

  Future<void> mutate(Future<WorkoutSessionData> Function() operation) async {
    if (busy) return;
    setState(() => actionError = null);
    try {
      final updated = await write(operation);
      if (!updated.readyToFinish) finishOffered = false;
      if (updated.readyToFinish && mounted) {
        finishOffered = true;
        await askExit();
      }
    } catch (error) {
      if (mounted) {
        setState(() => actionError = (l) => failureText(l, error));
        await reload();
      }
    }
  }

  Future<void> showOrder({bool selectNext = false}) async {
    final data = session;
    if (busy || data == null || !data.canReorder) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => SessionOrderSheet(
        session: data,
        selectNext: selectNext,
        onSave: (baseline, ids) => write(
          () => widget.workouts.reorder(
            baseline.id,
            ids,
            expectedToken: baseline.reorderToken,
          ),
        ),
        onReload: () => widget.workouts.getSession(widget.sessionId),
      ),
    );
    if (mounted) await reload();
  }

  Future<void> askSkipRemaining() async {
    final baseline = session;
    if (actionDialogOpen ||
        busy ||
        baseline == null ||
        !baseline.canSkipRemaining) {
      return;
    }
    actionDialogOpen = true;
    bool submitted = false;
    try {
      final e = baseline.currentExercise;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(dialogContext.l10n.skipRemainingTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogContext.l10n.skipRemainingNote(
                  e.name,
                  e.completedSets,
                  e.pendingSets,
                ),
              ),
              SizedBox(height: 12),
              Text(
                baseline.nextExercise == null
                    ? dialogContext.l10n.skipFinishNote
                    : dialogContext.l10n.skipNextNote(
                        baseline.nextExercise!.name,
                      ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (submitted) return;
                submitted = true;
                Navigator.pop(dialogContext, false);
              },
              child: Text(dialogContext.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                if (submitted) return;
                submitted = true;
                Navigator.pop(dialogContext, true);
              },
              child: Text(dialogContext.l10n.confirmSkipRemaining),
            ),
          ],
        ),
      );
      if (accepted == true && mounted) {
        await mutate(
          () => widget.workouts.skipRemainingSets(
            baseline.id,
            expectedExerciseId: e.id,
            expectedToken: baseline.reorderToken,
          ),
        );
      }
    } finally {
      actionDialogOpen = false;
    }
  }

  Future<void> askUndoSkip() async {
    final baseline = session;
    final e = baseline?.lastSkippedExercise;
    if (actionDialogOpen || busy || baseline == null || e == null) return;
    actionDialogOpen = true;
    bool submitted = false;
    try {
      final count = e.sets
          .where((s) => s.skipped && s.skipBatchId == baseline.lastSkipBatchId)
          .length;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(dialogContext.l10n.undoSkipTitle),
          content: Text(dialogContext.l10n.undoSkipNote(count, e.name)),
          actions: [
            TextButton(
              onPressed: () {
                if (submitted) return;
                submitted = true;
                Navigator.pop(dialogContext, false);
              },
              child: Text(dialogContext.l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                if (submitted) return;
                submitted = true;
                Navigator.pop(dialogContext, true);
              },
              child: Text(dialogContext.l10n.restoreSkippedSets),
            ),
          ],
        ),
      );
      if (accepted == true && mounted) {
        await mutate(
          () => widget.workouts.undoLastSkip(
            baseline.id,
            expectedBatchId: baseline.lastSkipBatchId!,
            expectedToken: baseline.reorderToken,
          ),
        );
      }
    } finally {
      actionDialogOpen = false;
    }
  }

  Future<void> askExit() async {
    if (busy || session == null || !mounted || exitDialogOpen) return;
    exitDialogOpen = true;
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => Builder(
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(
              session!.readyToFinish
                  ? context.l10n.finishWorkoutTitle
                  : context.l10n.endWorkoutTitle,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session!.planName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  session!.completedSets == 0
                      ? context.l10n.emptyWorkoutExit
                      : context.l10n.exitCompletedNote(session!.completedSets),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'continue'),
                child: Text(context.l10n.resumeWorkout),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'discard'),
                child: Text(
                  context.l10n.discard,
                  style: TextStyle(color: dialogContext.appColors.danger),
                ),
              ),
              if (session!.completedSets > 0)
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, 'save'),
                  child: Text(context.l10n.saveCompleted),
                ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (choice == 'save') {
        setState(() => busy = true);
        ++writeRevision;
        ++loadGeneration;
        await widget.workouts.finish(widget.sessionId);
        if (mounted) Navigator.of(context).pop();
      } else if (choice == 'discard') {
        if (session!.completedSets > 0) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => Builder(
              builder: (context) => AlertDialog(
                scrollable: true,
                title: Text(context.l10n.confirmDiscardTitle),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session!.planName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(context.l10n.confirmDiscardNote),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(context.l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: TextButton.styleFrom(
                      foregroundColor: context.appColors.danger,
                    ),
                    child: Text(context.l10n.confirmDiscard),
                  ),
                ],
              ),
            ),
          );
          if (confirmed != true) return;
        }
        setState(() => busy = true);
        ++writeRevision;
        ++loadGeneration;
        await widget.workouts.discard(widget.sessionId);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              actionError = (l) =>
                  failureText(l, error, fallback: l.saveFailed),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
      exitDialogOpen = false;
    }
  }

  void showExercises() {
    final data = session!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.l10n.sessionExercises,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12),
              if (data.canReorder)
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showOrder();
                  },
                  child: Text(sheetContext.l10n.reorderRemaining),
                ),
              if (data.lastSkippedExercise != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    askUndoSkip();
                  },
                  child: Text(sheetContext.l10n.undoLastSkip),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final exercise in data.exercises)
                      ListTile(
                        title: Text(exercise.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sheetContext.l10n.exerciseProgressRest(
                                exercise.completedSets,
                                exercise.targetSets,
                                sheetContext.formats.decimal(
                                  exercise.restBetweenSetsSeconds / 60,
                                ),
                              ),
                            ),
                            if (exercise.skippedSets > 0)
                              Text(sheetContext.l10n.remainingSetsSkipped),
                          ],
                        ),
                        trailing: !exercise.resolved
                            ? Icon(Icons.edit_outlined)
                            : null,
                        onTap: exercise.completed
                            ? null
                            : () async {
                                if (exercise.skippedSets > 0) {
                                  showAppSnackBar(
                                    context,
                                    (l) => l.restoreBeforeEditing,
                                  );
                                  return;
                                }
                                Navigator.pop(sheetContext);
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SessionExerciseEditorPage(
                                      workouts: widget.workouts,
                                      sessionId: widget.sessionId,
                                      exercise: exercise,
                                      expectedToken: data.reorderToken,
                                    ),
                                  ),
                                );
                                await reload();
                              },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = session;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) askExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(data?.planName ?? context.l10n.workoutInProgress),
          leading: IconButton(
            onPressed: busy ? null : askExit,
            icon: const Icon(Icons.arrow_back),
            tooltip: context.l10n.endOrReturn,
          ),
          actions: [
            TextButton(
              onPressed: data == null || busy ? null : askExit,
              child: Text(context.l10n.exitWorkout),
            ),
          ],
        ),
        body: data == null
            ? loadError != null
                  ? AppLoadError(
                      message: loadError!(context.l10n),
                      onRetry: reload,
                    )
                  : const Center(child: CircularProgressIndicator())
            : AppTaskLayout(
                body: ListView(
                  key: const ValueKey('workout-body'),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          context.l10n.exercisePosition(
                            data.currentExerciseOrder,
                            data.exercises.length,
                          ),
                          style: TextStyle(
                            color: context.appColors.onAccentSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: busy ? null : showExercises,
                          child: Text(context.l10n.allExercisesEdit),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.currentExercise.name,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    if (data.currentExercise.defaultWeightKg != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.referenceWeight(
                          context.formats.weightLabel(
                            data.currentExercise.defaultWeightKg,
                          ),
                        ),
                        style: TextStyle(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (data.lastSkippedExercise case final skipped?) ...[
                      AppCard(
                        backgroundColor: context.appColors.warningSoft,
                        borderColor: context.appColors.warningSoft,
                        child: Text(
                          context.l10n.skippedExerciseSummary(
                            skipped.name,
                            skipped.completedSets,
                            skipped.skippedSets,
                          ),
                          style: TextStyle(color: context.appColors.warning),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    data.resting
                        ? _rest(context, data)
                        : _training(context, data),
                    if (data.canSkipRemaining) ...[
                      const SizedBox(height: 12),
                      AppButton(
                        label: context.l10n.skipRemainingSets(
                          data.currentExercise.pendingSets,
                        ),
                        variant: AppButtonVariant.outline,
                        onPressed: busy ? null : askSkipRemaining,
                      ),
                    ],
                    if (data.lastSkippedExercise != null) ...[
                      const SizedBox(height: 12),
                      AppButton(
                        label: context.l10n.undoLastSkip,
                        variant: AppButtonVariant.outline,
                        onPressed: busy ? null : askUndoSkip,
                      ),
                    ],
                    if (data.canReorder || data.nextExercise != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.nextExercise,
                        style: TextStyle(
                          color: context.appColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (data.nextExercise != null)
                        Text(
                          data.nextExercise!.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      if (data.canReorder) ...[
                        Text(
                          data.currentExercise.movable
                              ? context.l10n.currentExerciseMovable
                              : context.l10n.currentExerciseFixed,
                          style: TextStyle(
                            color: context.appColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => showOrder(selectNext: true),
                          child: Text(context.l10n.changeNext),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.completedSets(
                        data.completedSets,
                        data.totalSets,
                      ),
                      style: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: data.totalSets == 0
                          ? 0
                          : data.completedSets / data.totalSets,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    if (loadError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        loadError!(context.l10n),
                        style: TextStyle(color: context.appColors.danger),
                      ),
                      TextButton(
                        onPressed: busy ? null : reload,
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ],
                ),
                actions: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionError != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          actionError!(context.l10n),
                          style: TextStyle(color: context.appColors.danger),
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () {
                                setState(() => actionError = null);
                                reload();
                              },
                        child: Text(context.l10n.reload),
                      ),
                    ],
                    AppButton(
                      key: const ValueKey('workout-primary'),
                      busy: busy,
                      label: data.resting
                          ? context.l10n.endRest
                          : data.readyToFinish
                          ? context.l10n.saveWorkout
                          : context.l10n.completeSet,
                      onPressed: busy
                          ? null
                          : data.resting
                          ? () =>
                                mutate(() => widget.workouts.skipRest(data.id))
                          : data.readyToFinish
                          ? data.completedSets > 0
                                ? askExit
                                : null
                          : () => mutate(
                              () => widget.workouts.completeSet(
                                data.id,
                                expectedExerciseId: data.currentExercise.id,
                                expectedSetNumber: data.currentSetNumber,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      children: [
                        if (data.completedSets > 0)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => mutate(
                                    () => widget.workouts.undoLastSet(data.id),
                                  ),
                            child: Text(context.l10n.undoLastSet),
                          ),
                        TextButton(
                          onPressed: busy ? null : askExit,
                          child: Text(context.l10n.endWorkoutAction),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _training(BuildContext context, WorkoutSessionData data) {
    final c = context.appColors;
    final e = data.currentExercise;
    final ready = data.readyToFinish;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ready
                ? context.l10n.workoutReadyToFinish
                : context.l10n.currentPendingSet,
            style: TextStyle(
              color: c.onAccentSoft,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: ready
                ? context.l10n.completedSets(data.completedSets, data.totalSets)
                : context.l10n.currentSet(data.currentSetNumber),
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                ready
                    ? '${data.completedSets} / ${data.totalSets}'
                    : data.currentSetNumber.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 80,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.completedSets(
              ready ? data.completedSets : e.completedSets,
              ready ? data.totalSets : e.targetSets,
            ),
            style: TextStyle(color: c.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (e.targetSets <= 8 && !ready)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final set in e.sets)
                  Semantics(
                    label: context.l10n.setState(
                      set.number,
                      set.completed
                          ? context.l10n.completed
                          : set.skipped
                          ? context.l10n.setSkipped
                          : set.number == data.currentSetNumber
                          ? context.l10n.currentPendingSet
                          : context.l10n.pending,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: set.completed
                            ? c.accentSoft
                            : set.skipped
                            ? c.warningSoft
                            : c.background,
                        border: Border.all(
                          color: set.number == data.currentSetNumber
                              ? c.accent
                              : c.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          '${set.completed
                              ? '✓ '
                              : set.skipped
                              ? '− '
                              : ''}${set.number}',
                          style: TextStyle(
                            color: set.skipped ? c.warning : c.onAccentSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          else
            Text(
              context.l10n.setStatusSummary(
                ready ? data.completedSets : e.completedSets,
                ready
                    ? data.exercises.fold<int>(0, (n, x) => n + x.skippedSets)
                    : e.skippedSets,
                ready ? 0 : e.pendingSets,
              ),
              style: TextStyle(color: c.textSecondary),
            ),
          if (ready) ...[
            const SizedBox(height: 12),
            Text(
              data.allSetsCompleted
                  ? context.l10n.allSetsCompleted
                  : context.l10n.skipsNotCompleted,
              style: TextStyle(color: c.onAccentSoft),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rest(BuildContext context, WorkoutSessionData data) {
    final c = context.appColors;
    final remaining = math.max(
      0,
      data.restEndAt!.difference(now).inSeconds + 1,
    );
    final display =
        '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.restKind == 'between_exercises'
                ? context.l10n.betweenExercises
                : context.l10n.betweenSets,
            style: TextStyle(
              color: c.onAccentSoft,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: false,
            label: context.l10n.restTimeRemaining(display),
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                display,
                style: TextStyle(
                  fontSize: 70,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.nextSet(
              data.currentExercise.name,
              data.currentSetNumber,
              data.currentExercise.targetSets,
            ),
            style: TextStyle(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: context.l10n.subtractRest,
                  variant: AppButtonVariant.outline,
                  onPressed: busy
                      ? null
                      : () => mutate(
                          () => widget.workouts.adjustRest(data.id, -30),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: context.l10n.addRest,
                  variant: AppButtonVariant.outline,
                  onPressed: busy
                      ? null
                      : () => mutate(
                          () => widget.workouts.adjustRest(data.id, 30),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SessionExerciseEditorPage extends StatefulWidget {
  const SessionExerciseEditorPage({
    super.key,
    required this.workouts,
    required this.sessionId,
    required this.exercise,
    this.expectedToken,
  });
  final WorkoutRepository workouts;
  final int sessionId;
  final SessionExercise exercise;
  final String? expectedToken;

  @override
  State<SessionExerciseEditorPage> createState() =>
      _SessionExerciseEditorPageState();
}

class _SessionExerciseEditorPageState extends State<SessionExerciseEditorPage> {
  late SessionExercise source = widget.exercise;
  late int sets = source.targetSets,
      between = source.restBetweenSetsSeconds,
      after = source.restAfterExerciseSeconds;
  late String? baselineToken = widget.expectedToken;
  bool saving = false, stale = false;
  LocalizedMessage? error;
  Future<void> reload() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final latest = await widget.workouts.getSession(widget.sessionId);
      final selected = latest?.exercises
          .where((e) => e.id == source.id)
          .firstOrNull;
      if (latest == null || !latest.inProgress || selected == null) {
        throw WorkoutStateException(WorkoutFailure.sessionEnded);
      }
      if (mounted) {
        setState(() {
          source = selected;
          sets = source.targetSets;
          between = source.restBetweenSetsSeconds;
          after = source.restAfterExerciseSeconds;
          baselineToken = latest.reorderToken;
          stale = false;
          error = null;
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = (l) => failureText(l, failure, fallback: l.loadFailed),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> save() async {
    if (saving || stale) return;
    setState(() {
      saving = true;
      error = null;
    });
    var succeeded = false;
    try {
      final latest = await widget.workouts.getSession(widget.sessionId);
      if (latest == null ||
          !latest.inProgress ||
          (baselineToken != null && baselineToken != latest.reorderToken)) {
        stale = true;
        throw WorkoutStateException(WorkoutFailure.workoutChanged);
      }
      await widget.workouts.updateExercise(
        widget.sessionId,
        source.id,
        targetSets: sets,
        restBetweenSetsSeconds: between,
        restAfterExerciseSeconds: after,
      );
      succeeded = true;
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = (l) => failureText(l, failure, fallback: l.saveFailed),
        );
      }
    } finally {
      if (mounted && !succeeded) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sessionEditTitle(source.name)),
        automaticallyImplyLeading: !saving,
      ),
      body: AppTaskLayout(
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(source.name, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              context.l10n.sessionEditNote,
              style: TextStyle(color: context.appColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Text(context.l10n.targetSets),
            const SizedBox(height: 12),
            IgnorePointer(
              ignoring: saving || stale,
              child: StepPicker(
                enabled:
                    !saving &&
                    !stale &&
                    !source.completed &&
                    source.skippedSets == 0,
                semanticLabel: context.l10n.targetSets,
                value: sets,
                min: math.max(1, source.completedSets),
                max: 100,
                step: 1,
                label: (value) => context.l10n.setCount(value),
                onChanged: (value) => setState(() => sets = value),
              ),
            ),
            const SizedBox(height: 24),
            Text(context.l10n.betweenSets),
            const SizedBox(height: 12),
            IgnorePointer(
              ignoring: saving || stale,
              child: StepPicker(
                enabled:
                    !saving &&
                    !stale &&
                    !source.completed &&
                    source.skippedSets == 0,
                semanticLabel: context.l10n.betweenSets,
                value: between,
                min: 0,
                max: 3600,
                step: 30,
                label: (value) => context.l10n.minutesShort(
                  context.formats.decimal(value / 60),
                ),
                onChanged: (value) => setState(() => between = value),
              ),
            ),
            const SizedBox(height: 24),
            Text(context.l10n.afterExerciseShort),
            const SizedBox(height: 12),
            IgnorePointer(
              ignoring: saving || stale,
              child: StepPicker(
                enabled:
                    !saving &&
                    !stale &&
                    !source.completed &&
                    source.skippedSets == 0,
                semanticLabel: context.l10n.afterExerciseShort,
                value: after,
                min: 0,
                max: 3600,
                step: 30,
                label: (value) => context.l10n.minutesShort(
                  context.formats.decimal(value / 60),
                ),
                onChanged: (value) => setState(() => after = value),
              ),
            ),
            if (source.skippedSets > 0) ...[
              const SizedBox(height: 16),
              Text(
                context.l10n.restoreBeforeEditing,
                style: TextStyle(color: context.appColors.warning),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(
                error!(context.l10n),
                style: TextStyle(color: context.appColors.danger),
              ),
              TextButton(
                onPressed: saving ? null : reload,
                child: Text(context.l10n.reload),
              ),
            ],
          ],
        ),
        actions: AppButton(
          label: context.l10n.saveSessionConfig,
          busy: saving,
          onPressed:
              saving || stale || source.completed || source.skippedSets > 0
              ? null
              : save,
        ),
      ),
    ),
  );
}
