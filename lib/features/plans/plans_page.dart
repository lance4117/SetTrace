import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/localization.dart';
import '../../l10n/error_messages.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/app_task_layout.dart';
import '../workout/workout_models.dart';
import '../workout/workout_repository.dart';
import 'exercise_editor_page.dart';
import 'plan_models.dart';
import 'plan_repository.dart';
import 'plan_transfer_pages.dart';
import 'plan_transfer_platform.dart';

typedef OpenWorkout = Future<void> Function(WorkoutSessionData session);

Future<bool?> askPlanName(
  BuildContext context, {
  String? initial,
  required Future<void> Function(String) onSave,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _PlanNameDialog(initial: initial, onSave: onSave),
);

class _PlanNameDialog extends StatefulWidget {
  const _PlanNameDialog({this.initial, required this.onSave});
  final String? initial;
  final Future<void> Function(String) onSave;
  @override
  State<_PlanNameDialog> createState() => _PlanNameDialogState();
}

class _PlanNameDialogState extends State<_PlanNameDialog> {
  late final controller = TextEditingController(text: widget.initial ?? '');
  final focus = FocusNode();
  bool saving = false;
  LocalizedMessage? error;
  Future<void> save() async {
    if (saving) return;
    final name = controller.text.trim();
    if (name.isEmpty || name.characters.length > 40) {
      setState(
        () =>
            error = (l) =>
                name.isEmpty ? l.planNameRequired : l.planNameTooLong,
      );
      focus.requestFocus();
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    bool succeeded = false;
    try {
      await widget.onSave(name);
      succeeded = true;
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = (l) => failureText(l, failure, fallback: l.saveFailed),
        );
        focus.requestFocus();
      }
    } finally {
      if (mounted && !succeeded) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        widget.initial == null
            ? context.l10n.newPlanTitle
            : context.l10n.renamePlanTitle,
      ),
      content: TextField(
        controller: controller,
        focusNode: focus,
        autofocus: true,
        enabled: !saving,
        maxLength: 40,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        decoration: InputDecoration(
          labelText: context.l10n.planName,
          hintText: context.l10n.planNameHint,
          errorText: error?.call(context.l10n),
        ),
        onSubmitted: (_) => save(),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: saving ? null : save,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.save),
        ),
      ],
    ),
  );
}

class PlansPage extends StatefulWidget {
  const PlansPage({
    super.key,
    required this.plans,
    required this.workouts,
    required this.onOpenWorkout,
    this.transferPlatform,
    this.workoutRevision = 0,
  });

  final PlanRepository plans;
  final WorkoutRepository workouts;
  final OpenWorkout onOpenWorkout;
  final PlanTransferPlatform? transferPlatform;
  final int workoutRevision;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  List<WorkoutPlan> items = [];
  WorkoutSessionData? active;
  bool loading = true;
  LocalizedMessage? loadError;
  int generation = 0;
  late final transferPlatform =
      widget.transferPlatform ?? AndroidPlanTransferPlatform();
  Future<void> transfer(String mode) async {
    if (mode == 'export') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              PlanExportPage(plans: widget.plans, platform: transferPlatform),
        ),
      );
    } else {
      final count = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          settings: const RouteSettings(name: 'editing'),
          builder: (_) =>
              PlanImportPage(plans: widget.plans, platform: transferPlatform),
        ),
      );
      if (mounted && count != null) {
        showAppSnackBar(context, (l) => l.importSuccess(count));
      }
    }
    await refresh();
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(covariant PlansPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workoutRevision != widget.workoutRevision) refresh();
  }

  Future<void> refresh() async {
    final token = ++generation;
    try {
      final plans = await widget.plans.listPlans();
      final workout = await widget.workouts.getActive();
      if (mounted && token == generation) {
        setState(() {
          items = plans;
          active = workout;
          loading = false;
          loadError = null;
        });
      }
    } catch (error) {
      if (mounted && token == generation) {
        setState(() {
          loading = false;
          loadError = (l) => failureText(l, error, fallback: l.loadFailed);
        });
      }
    }
  }

  Future<void> create() async {
    final saved = await askPlanName(
      context,
      onSave: (name) async {
        await widget.plans.createPlan(name);
      },
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> openPlan(WorkoutPlan plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanDetailPage(
          planId: plan.id,
          plans: widget.plans,
          workouts: widget.workouts,
          onOpenWorkout: widget.onOpenWorkout,
        ),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = Text(
      context.l10n.plansTitle,
      style: Theme.of(context).textTheme.headlineLarge,
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: TextButton(
            onPressed: create,
            child: Text(context.l10n.newPlan),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: context.l10n.transferMenu,
          onSelected: transfer,
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'import',
              child: Text(context.l10n.importPlans),
            ),
            PopupMenuItem(
              value: 'export',
              child: Text(context.l10n.exportPlans),
            ),
          ],
        ),
      ],
    );
    return SafeArea(
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
                    constraints.maxWidth < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      Align(alignment: Alignment.centerRight, child: controls),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    controls,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.whatToTrain,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (loadError != null)
              AppLoadError(message: loadError!(context.l10n), onRetry: refresh)
            else ...[
              if (active != null) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.unfinishedPlan(active!.planName),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        context.l10n.exerciseCurrentSet(
                          active!.currentExercise.name,
                          active!.currentSetNumber,
                        ),
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      SizedBox(height: 12),
                      AppButton(
                        label: context.l10n.resumeWorkout,
                        onPressed: () async {
                          await widget.onOpenWorkout(active!);
                          await refresh();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
              if (items.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(
                    child: Text(
                      context.l10n.noPlansYet,
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ),
              for (final plan in items) ...[
                AppCard(
                  onTap: () => openPlan(plan),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        plan.exercises.isEmpty
                            ? context.l10n.noExercises
                            : plan.exercises.map((e) => e.name).join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      SizedBox(height: 12),
                      Text(
                        context.l10n.exerciseSummary(
                          plan.exercises.length,
                          plan.totalSets,
                        ),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class PlanDetailPage extends StatefulWidget {
  const PlanDetailPage({
    super.key,
    required this.planId,
    required this.plans,
    required this.workouts,
    required this.onOpenWorkout,
  });

  final int planId;
  final PlanRepository plans;
  final WorkoutRepository workouts;
  final OpenWorkout onOpenWorkout;

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  WorkoutPlan? plan;
  LocalizedMessage? loadError;
  bool deleting = false, reordering = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final token = ++generation;
    try {
      final loaded = await widget.plans.getPlan(widget.planId);
      if (mounted && token == generation) {
        setState(() {
          plan = loaded;
          loadError = loaded == null ? (l) => l.loadFailed : null;
        });
      }
    } catch (error) {
      if (mounted && token == generation) {
        setState(
          () =>
              loadError = (l) => failureText(l, error, fallback: l.loadFailed),
        );
      }
    }
  }

  Future<void> editName() async {
    if (plan == null) return;
    final saved = await askPlanName(
      context,
      initial: plan!.name,
      onSave: (name) => widget.plans.renamePlan(widget.planId, name),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> delete() async {
    if (deleting || plan == null) return;
    setState(() => deleting = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(dialogContext.l10n.deletePlanTitle),
          content: Text(
            [
              plan!.name,
              dialogContext.l10n.deletePlanNote,
              dialogContext.l10n.irreversible,
            ].join('\n\n'),
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.l10n.cancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: dialogContext.appColors.danger,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.l10n.delete),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.plans.deletePlan(widget.planId);
      if (mounted) {
        setState(() => deleting = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) setState(() => loadError = (l) => failureText(l, error));
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  Future<void> openEditor([PlanExercise? exercise]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: 'editing'),
        builder: (_) => ExerciseEditorPage(
          plans: widget.plans,
          planId: widget.planId,
          exercise: exercise,
        ),
      ),
    );
    await refresh();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (reordering || plan == null) return;
    final current = List<PlanExercise>.of(plan!.exercises);
    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    setState(() => reordering = true);
    try {
      await widget.plans.reorder(
        widget.planId,
        current.map((e) => e.id).toList(),
      );
      await refresh();
    } catch (error) {
      if (mounted) setState(() => loadError = (l) => failureText(l, error));
    } finally {
      if (mounted) setState(() => reordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = plan;
    final c = context.appColors;
    return PopScope(
      canPop: !deleting && !reordering,
      child: Scaffold(
        appBar: AppBar(
          leading: deleting || reordering
              ? IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                )
              : const BackButton(),
          title: Text(context.l10n.planDetails),
          actions: [
            PopupMenuButton<String>(
              enabled: current != null && !deleting && !reordering,
              onSelected: (value) {
                if (value == 'rename') editName();
                if (value == 'delete') delete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Text(context.l10n.rename),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.l10n.deletePlan),
                ),
              ],
            ),
          ],
        ),
        body: current == null
            ? loadError != null
                  ? AppLoadError(
                      message: loadError!(context.l10n),
                      onRetry: refresh,
                    )
                  : const Center(child: CircularProgressIndicator())
            : AppTaskLayout(
                body: ReorderableListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: current.exercises.length,
                  buildDefaultDragHandles: false,
                  onReorderItem: reorder,
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.name,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.exerciseSummary(
                          current.exercises.length,
                          current.totalSets,
                        ),
                        style: TextStyle(color: c.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        current.exercises.isEmpty
                            ? context.l10n.noExercisesAdd
                            : context.l10n.reorderPlanHint,
                        style: TextStyle(color: c.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      if (loadError != null) ...[
                        Text(
                          loadError!(context.l10n),
                          style: TextStyle(color: c.danger),
                        ),
                        TextButton(
                          onPressed: refresh,
                          child: Text(context.l10n.retry),
                        ),
                      ],
                    ],
                  ),
                  itemBuilder: (context, index) {
                    final e = current.exercises[index];
                    return Column(
                      key: ValueKey(e.id),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              enabled: !reordering,
                              child: Semantics(
                                label: context.l10n.dragExercise(e.name),
                                child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  e.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  context.l10n.exerciseConfiguration(
                                    e.targetSets,
                                    e.restBetweenSetsSeconds,
                                    e.restAfterExerciseSeconds,
                                  ),
                                ),
                                onTap: reordering || deleting
                                    ? null
                                    : () => openEditor(e),
                                trailing: const ExcludeSemantics(
                                  child: Icon(Icons.chevron_right),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          children: [
                            IconButton(
                              tooltip: context.l10n.moveExerciseUp(e.name),
                              onPressed: reordering || index == 0
                                  ? null
                                  : () => reorder(index, index - 1),
                              icon: const Icon(Icons.arrow_upward),
                            ),
                            IconButton(
                              tooltip: context.l10n.moveExerciseDown(e.name),
                              onPressed:
                                  reordering ||
                                      index == current.exercises.length - 1
                                  ? null
                                  : () => reorder(index, index + 1),
                              icon: const Icon(Icons.arrow_downward),
                            ),
                          ],
                        ),
                        const Divider(),
                      ],
                    );
                  },
                ),
                actions: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(
                      label: context.l10n.addExerciseAction,
                      primary: false,
                      onPressed: deleting || reordering
                          ? null
                          : () => openEditor(),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: context.l10n.startWorkout,
                      onPressed:
                          current.exercises.isEmpty || deleting || reordering
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PrepPage(
                                    plan: current,
                                    workouts: widget.workouts,
                                    onOpenWorkout: widget.onOpenWorkout,
                                  ),
                                ),
                              );
                              if (mounted) await refresh();
                            },
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class PrepPage extends StatefulWidget {
  const PrepPage({
    super.key,
    required this.plan,
    required this.workouts,
    required this.onOpenWorkout,
  });

  final WorkoutPlan plan;
  final WorkoutRepository workouts;
  final OpenWorkout onOpenWorkout;

  @override
  State<PrepPage> createState() => _PrepPageState();
}

class _PrepPageState extends State<PrepPage> {
  bool starting = false;

  Future<void> start() async {
    if (starting) return;
    setState(() => starting = true);
    try {
      final session = await widget.workouts.start(widget.plan.id);
      await widget.onOpenWorkout(session);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      final active = await widget.workouts.getActive();
      if (!mounted) return;
      if (active != null) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Builder(
            builder: (context) => AlertDialog(
              scrollable: true,
              title: Text(context.l10n.activeWorkoutTitle),
              content: Text(context.l10n.resumePlanNote(active.planName)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.l10n.stayHere),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.l10n.resumeOriginal),
                ),
              ],
            ),
          ),
        );
        if (resume == true) await widget.onOpenWorkout(active);
      } else {
        showAppSnackBar(context, (l) => failureText(l, error));
      }
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return PopScope(
      canPop: !starting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.prepareWorkout),
          automaticallyImplyLeading: !starting,
        ),
        body: AppTaskLayout(
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.plan.name,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.exerciseSummary(
                  widget.plan.exercises.length,
                  widget.plan.totalSets,
                ),
                style: TextStyle(color: c.textSecondary),
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.exerciseOrder,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < widget.plan.exercises.length; i++) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: c.onAccentSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  title: Text(widget.plan.exercises[i].name),
                  subtitle: Text(
                    context.l10n.exerciseConfiguration(
                      widget.plan.exercises[i].targetSets,
                      widget.plan.exercises[i].restBetweenSetsSeconds,
                      widget.plan.exercises[i].restAfterExerciseSeconds,
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
            ],
          ),
          actions: AppButton(
            label: context.l10n.startWorkout,
            busy: starting,
            onPressed: starting || widget.plan.exercises.isEmpty ? null : start,
          ),
        ),
      ),
    );
  }
}
