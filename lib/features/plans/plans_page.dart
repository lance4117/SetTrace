import 'package:flutter/material.dart';

import '../../l10n/localization.dart';
import '../../l10n/error_messages.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../workout/workout_models.dart';
import '../workout/workout_repository.dart';
import 'exercise_editor_page.dart';
import 'plan_models.dart';
import 'plan_repository.dart';
import 'plan_transfer_pages.dart';
import 'plan_transfer_platform.dart';

typedef OpenWorkout = Future<void> Function(WorkoutSessionData session);

Future<String?> askPlanName(BuildContext context, {String? initial}) async {
  return showDialog<String>(
    context: context,
    builder: (_) => _PlanNameDialog(initial: initial),
  );
}

class _PlanNameDialog extends StatefulWidget {
  const _PlanNameDialog({this.initial});
  final String? initial;

  @override
  State<_PlanNameDialog> createState() => _PlanNameDialogState();
}

class _PlanNameDialogState extends State<_PlanNameDialog> {
  late final controller = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.initial == null
          ? context.l10n.newPlanTitle
          : context.l10n.renamePlanTitle,
    ),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: 40,
      decoration: InputDecoration(hintText: context.l10n.planNameHint),
      onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: Text(context.l10n.save),
      ),
    ],
  );
}

class PlansPage extends StatefulWidget {
  const PlansPage({
    super.key,
    required this.plans,
    required this.workouts,
    required this.onOpenWorkout,
    this.transferPlatform,
  });

  final PlanRepository plans;
  final WorkoutRepository workouts;
  final OpenWorkout onOpenWorkout;
  final PlanTransferPlatform? transferPlatform;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  List<WorkoutPlan> items = [];
  WorkoutSessionData? active;
  bool loading = true;
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

  Future<void> refresh() async {
    final plans = await widget.plans.listPlans();
    final workout = await widget.workouts.getActive();
    if (mounted) {
      setState(() {
        items = plans;
        active = workout;
        loading = false;
      });
    }
  }

  Future<void> create() async {
    final name = await askPlanName(context);
    if (name == null) return;
    if (name.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, (l) => l.planNameRequired);
      }
      return;
    }
    await widget.plans.createPlan(name);
    await refresh();
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.plansTitle,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: create,
                  child: Text(context.l10n.newPlan),
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
            ),
            SizedBox(height: 16),
            Text(
              context.l10n.whatToTrain,
              style: TextStyle(color: colors.textSecondary),
            ),
            SizedBox(height: 16),
            Expanded(
              child: loading
                  ? Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
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
                                      : plan.exercises
                                            .map((e) => e.name)
                                            .join(' · '),
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
                    ),
            ),
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

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final loaded = await widget.plans.getPlan(widget.planId);
    if (mounted) setState(() => plan = loaded);
  }

  Future<void> editName() async {
    final result = await askPlanName(context, initial: plan!.name);
    if (result == null) return;
    if (result.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, (l) => l.planNameRequired);
      }
      return;
    }
    await widget.plans.renamePlan(widget.planId, result);
    await refresh();
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Builder(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(context.l10n.deletePlanTitle),
          content: Text(context.l10n.deletePlanNote),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.delete),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await widget.plans.deletePlan(widget.planId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> openEditor([PlanExercise? exercise]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
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
    final current = List<PlanExercise>.of(plan!.exercises);
    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    await widget.plans.reorder(
      widget.planId,
      current.map((e) => e.id).toList(),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final current = plan;
    return Scaffold(
      appBar: AppBar(
        title: Text(current?.name ?? context.l10n.planDetails),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') editName();
              if (value == 'delete') delete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(context.l10n.rename)),
              PopupMenuItem(
                value: 'delete',
                child: Text(context.l10n.deletePlan),
              ),
            ],
          ),
        ],
      ),
      body: current == null
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.reorderPlanHint,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 14),
                    Expanded(
                      child: current.exercises.isEmpty
                          ? Center(
                              child: Text(
                                context.l10n.noExercisesAdd,
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            )
                          : ReorderableListView.builder(
                              itemCount: current.exercises.length,
                              onReorderItem: reorder,
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, index) {
                                final exercise = current.exercises[index];
                                return Padding(
                                  key: ValueKey(exercise.id),
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: AppCard(
                                    onTap: () => openEditor(exercise),
                                    child: Row(
                                      children: [
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Semantics(
                                            label: context.l10n.dragExercise(
                                              exercise.name,
                                            ),
                                            child: SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: Icon(Icons.drag_handle),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                exercise.name,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                context.l10n.exerciseRest(
                                                  exercise.targetSets,
                                                  context.formats.decimal(
                                                    exercise.restBetweenSetsSeconds /
                                                        60,
                                                  ),
                                                ),
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    AppButton(
                      label: context.l10n.addExerciseAction,
                      primary: false,
                      onPressed: () => openEditor(),
                    ),
                    SizedBox(height: 12),
                    AppButton(
                      label: context.l10n.startWorkout,
                      onPressed: current.exercises.isEmpty
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
                              await refresh();
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
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.prepareWorkout)),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        context.l10n.exerciseSummary(
                          widget.plan.exercises.length,
                          widget.plan.totalSets,
                        ),
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 22),
              Text(
                context.l10n.exerciseOrder,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.plan.exercises.length,
                  separatorBuilder: (_, _) => SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final exercise = widget.plan.exercises[index];
                    return AppCard(
                      child: Text(
                        context.l10n.exercisePreview(
                          index + 1,
                          exercise.name,
                          exercise.targetSets,
                        ),
                      ),
                    );
                  },
                ),
              ),
              AppButton(
                label: context.l10n.startWorkout,
                onPressed: starting ? null : start,
                height: 58,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
