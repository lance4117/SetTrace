import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/localization.dart';
import '../../l10n/error_messages.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/step_picker.dart';
import 'workout_models.dart';
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
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with WidgetsBindingObserver {
  WorkoutSessionData? session;
  Timer? ticker;
  bool busy = false;
  int writeRevision = 0, loadGeneration = 0;
  bool reloadPending = false;
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
          now = DateTime.now();
        });
      }
    } catch (error) {
      if (mounted &&
          generation == loadGeneration &&
          revision == writeRevision) {
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
    try {
      final updated = await write(operation);
      if (updated.allSetsCompleted && mounted) await askExit();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(context, (l) => failureText(l, error));
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

  Future<void> askExit() async {
    if (busy || session == null || !mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Builder(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(
            session!.allSetsCompleted
                ? context.l10n.finishWorkoutTitle
                : context.l10n.endWorkoutTitle,
          ),
          content: Text(
            session!.completedSets == 0
                ? context.l10n.emptyWorkoutExit
                : context.l10n.exitCompletedNote(session!.completedSets),
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
              content: Text(context.l10n.confirmDiscardNote),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.l10n.confirmDiscard),
                ),
              ],
            ),
          ),
        );
        if (confirmed != true) return;
      }
      await widget.workouts.discard(widget.sessionId);
      if (mounted) Navigator.of(context).pop();
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
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final exercise in data.exercises)
                      ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(
                          sheetContext.l10n.exerciseProgressRest(
                            exercise.completedSets,
                            exercise.targetSets,
                            sheetContext.formats.decimal(
                              exercise.restBetweenSetsSeconds / 60,
                            ),
                          ),
                        ),
                        trailing: !exercise.completed
                            ? Icon(Icons.edit_outlined)
                            : null,
                        onTap: exercise.completed
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SessionExerciseEditorPage(
                                      workouts: widget.workouts,
                                      sessionId: widget.sessionId,
                                      exercise: exercise,
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
    final colors = context.appColors;
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
            icon: Icon(Icons.arrow_back),
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
            ? Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: ListView(
                    children: [
                      Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            context.l10n.exercisePosition(
                              data.currentExerciseOrder,
                              data.exercises.length,
                            ),
                            style: TextStyle(color: colors.textSecondary),
                          ),
                          TextButton(
                            onPressed: busy ? null : showExercises,
                            child: Text(context.l10n.allExercisesEdit),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: data.totalSets == 0
                            ? 0
                            : data.completedSets / data.totalSets,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(6),
                        color: colors.accentPressed,
                        backgroundColor: colors.surfaceAlt,
                      ),
                      SizedBox(height: 24),
                      data.resting
                          ? _rest(context, data)
                          : _training(context, data),
                      if (data.completedSets > 0)
                        AppButton(
                          label: context.l10n.undoLastSet,
                          primary: false,
                          onPressed: busy
                              ? null
                              : () => mutate(
                                  () => widget.workouts.undoLastSet(data.id),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _training(BuildContext context, WorkoutSessionData data) {
    final colors = context.appColors;
    final exercise = data.currentExercise;
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AppCard(
          borderColor: colors.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.name,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              if (exercise.defaultWeightKg != null) ...[
                SizedBox(height: 6),
                Text(
                  context.formats.weightLabel(exercise.defaultWeightKg),
                  style: TextStyle(color: colors.textSecondary),
                ),
              ],
              SizedBox(height: 28),
              Center(
                child: Text(
                  '${data.currentSetNumber.toString().padLeft(2, '0')} / '
                  '${exercise.targetSets.toString().padLeft(2, '0')}',
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.4),
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    color: colors.accentPressed,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    for (final set in exercise.sets)
                      Icon(
                        set.completed ? Icons.circle : Icons.circle_outlined,
                        size: 19,
                        color: set.completed
                            ? colors.accentPressed
                            : colors.textTertiary,
                      ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Center(
                child: Text(
                  data.allSetsCompleted
                      ? context.l10n.allSetsCompleted
                      : context.l10n.currentSet(data.currentSetNumber),
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              SizedBox(height: 24),
              AppButton(
                label: data.allSetsCompleted
                    ? context.l10n.saveWorkout
                    : context.l10n.completeSet,
                onPressed: busy
                    ? null
                    : data.allSetsCompleted
                    ? askExit
                    : () => mutate(
                        () => widget.workouts.completeSet(
                          data.id,
                          expectedExerciseId: data.currentExercise.id,
                          expectedSetNumber: data.currentSetNumber,
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (data.canReorder) ...[
          SizedBox(height: 8),
          Text(
            data.currentExercise.movable
                ? context.l10n.currentExerciseMovable
                : context.l10n.currentExerciseFixed,
            style: TextStyle(color: colors.textSecondary),
          ),
          TextButton(
            onPressed: busy ? null : () => showOrder(selectNext: true),
            child: Text(context.l10n.changeNext),
          ),
        ],
        SizedBox(height: 12),
        AppCard(
          backgroundColor: colors.accentSoft,
          borderColor: colors.accentSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.nextExercise,
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
              SizedBox(height: 4),
              Text(
                data.nextExercise == null
                    ? context.l10n.lastExercise
                    : context.l10n.exerciseSets(
                        data.nextExercise!.name,
                        data.nextExercise!.targetSets,
                      ),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rest(BuildContext context, WorkoutSessionData data) {
    final colors = context.appColors;
    final remaining = math.max(
      0,
      data.restEndAt!.difference(now).inSeconds + 1,
    );
    final display =
        '${(remaining ~/ 60).toString().padLeft(2, '0')}:'
        '${(remaining % 60).toString().padLeft(2, '0')}';
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        SizedBox(height: 16),
        Text(
          data.restKind == 'between_exercises'
              ? context.l10n.betweenExercises
              : context.l10n.betweenSets,
          style: TextStyle(color: colors.textSecondary),
        ),
        SizedBox(height: 24),
        FittedBox(
          child: Text(
            display,
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w700,
              color: colors.accentPressed,
            ),
          ),
        ),
        SizedBox(height: 14),
        Text(
          context.l10n.nextSet(
            data.currentExercise.name,
            data.currentSetNumber,
            data.currentExercise.targetSets,
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary),
        ),
        if (data.canReorder)
          TextButton(
            onPressed: busy ? null : () => showOrder(selectNext: true),
            child: Text(context.l10n.changeNext),
          ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: context.l10n.subtractRest,
                primary: false,
                onPressed: busy
                    ? null
                    : () => mutate(
                        () => widget.workouts.adjustRest(data.id, -30),
                      ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: context.l10n.skip,
                onPressed: busy
                    ? null
                    : () => mutate(() => widget.workouts.skipRest(data.id)),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: context.l10n.addRest,
                primary: false,
                onPressed: busy
                    ? null
                    : () =>
                          mutate(() => widget.workouts.adjustRest(data.id, 30)),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

class SessionExerciseEditorPage extends StatefulWidget {
  const SessionExerciseEditorPage({
    super.key,
    required this.workouts,
    required this.sessionId,
    required this.exercise,
  });
  final WorkoutRepository workouts;
  final int sessionId;
  final SessionExercise exercise;

  @override
  State<SessionExerciseEditorPage> createState() =>
      _SessionExerciseEditorPageState();
}

class _SessionExerciseEditorPageState extends State<SessionExerciseEditorPage> {
  late int sets = widget.exercise.targetSets;
  late int between = widget.exercise.restBetweenSetsSeconds;
  late int after = widget.exercise.restAfterExerciseSeconds;
  bool saving = false;

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.workouts.updateExercise(
        widget.sessionId,
        widget.exercise.id,
        targetSets: sets,
        restBetweenSetsSeconds: between,
        restAfterExerciseSeconds: after,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          (l) => failureText(l, error, fallback: l.saveFailed),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.sessionEditTitle(widget.exercise.name)),
    ),
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text(context.l10n.targetSets),
                  SizedBox(height: 12),
                  StepPicker(
                    value: sets,
                    min: math.max(1, widget.exercise.completedSets),
                    max: 100,
                    step: 1,
                    label: (value) => context.l10n.setCount(value),
                    onChanged: (value) => setState(() => sets = value),
                  ),
                  SizedBox(height: 24),
                  Text(context.l10n.betweenSets),
                  SizedBox(height: 12),
                  StepPicker(
                    value: between,
                    min: 0,
                    max: 3600,
                    step: 30,
                    label: (value) => context.l10n.minutesShort(
                      context.formats.decimal(value / 60),
                    ),
                    onChanged: (value) => setState(() => between = value),
                  ),
                  SizedBox(height: 24),
                  Text(context.l10n.afterExerciseShort),
                  SizedBox(height: 12),
                  StepPicker(
                    value: after,
                    min: 0,
                    max: 3600,
                    step: 30,
                    label: (value) => context.l10n.minutesShort(
                      context.formats.decimal(value / 60),
                    ),
                    onChanged: (value) => setState(() => after = value),
                  ),
                  SizedBox(height: 16),
                  Text(
                    context.l10n.sessionEditNote,
                    style: TextStyle(color: context.appColors.textSecondary),
                  ),
                ],
              ),
            ),
            AppButton(
              label: context.l10n.saveSessionConfig,
              onPressed: saving ? null : save,
            ),
          ],
        ),
      ),
    ),
  );
}
