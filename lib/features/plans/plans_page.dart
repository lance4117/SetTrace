import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../workout/workout_models.dart';
import '../workout/workout_repository.dart';
import 'exercise_editor_page.dart';
import 'plan_models.dart';
import 'plan_repository.dart';

typedef OpenWorkout = Future<void> Function(WorkoutSessionData session);

Future<String?> askPlanName(BuildContext context, {String? initial}) async {
  return showDialog<String>(context: context,
    builder: (_) => _PlanNameDialog(initial: initial));
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
    title: Text(widget.initial == null ? '新建训练计划' : '编辑计划名称'),
    content: TextField(controller: controller, autofocus: true, maxLength: 40,
      decoration: const InputDecoration(hintText: '例如：练背'),
      onSubmitted: (_) => Navigator.pop(context, controller.text.trim())),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: const Text('保存')),
    ],
  );
}

class PlansPage extends StatefulWidget {
  const PlansPage({super.key, required this.plans, required this.workouts,
    required this.onOpenWorkout});

  final PlanRepository plans;
  final WorkoutRepository workouts;
  final OpenWorkout onOpenWorkout;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  List<WorkoutPlan> items = [];
  WorkoutSessionData? active;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final plans = await widget.plans.listPlans();
    final workout = await widget.workouts.getActive();
    if (mounted) setState(() { items = plans; active = workout; loading = false; });
  }

  Future<void> create() async {
    final name = await askPlanName(context);
    if (name == null) return;
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('计划名称不能为空')));
      }
      return;
    }
    await widget.plans.createPlan(name);
    await refresh();
  }

  Future<void> openPlan(WorkoutPlan plan) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlanDetailPage(planId: plan.id, plans: widget.plans,
        workouts: widget.workouts, onOpenWorkout: widget.onOpenWorkout)));
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('训练计划', style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700))),
          TextButton(onPressed: create, child: const Text('＋ 新建')),
        ]),
        const SizedBox(height: 16),
        Text('今天练什么？', style: TextStyle(color: colors.textSecondary)),
        const SizedBox(height: 16),
        Expanded(child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(children: [
              if (active != null) ...[
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('尚未完成 · ${active!.planName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('${active!.currentExercise.name} · 第 ${active!.currentSetNumber} 组',
                      style: TextStyle(color: colors.textSecondary)),
                    const SizedBox(height: 12),
                    AppButton(label: '继续训练', onPressed: () async {
                      await widget.onOpenWorkout(active!);
                      await refresh();
                    }),
                  ])),
                const SizedBox(height: 16),
              ],
              if (items.isEmpty)
                Padding(padding: const EdgeInsets.only(top: 100),
                  child: Center(child: Text('还没有训练计划，先新建一个吧',
                    style: TextStyle(color: colors.textSecondary)))),
              for (final plan in items) ...[
                AppCard(onTap: () => openPlan(plan), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plan.name, style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(plan.exercises.isEmpty ? '还没有动作' :
                      plan.exercises.map((e) => e.name).join(' · '),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary)),
                    const SizedBox(height: 12),
                    Text('${plan.exercises.length} 个动作 · ${plan.totalSets} 组',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  ])),
                const SizedBox(height: 14),
              ],
            ])),
      ]),
    ));
  }
}

class PlanDetailPage extends StatefulWidget {
  const PlanDetailPage({super.key, required this.planId, required this.plans,
    required this.workouts, required this.onOpenWorkout});

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
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    final loaded = await widget.plans.getPlan(widget.planId);
    if (mounted) setState(() => plan = loaded);
  }

  Future<void> editName() async {
    final result = await askPlanName(context, initial: plan!.name);
    if (result == null) return;
    if (result.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('计划名称不能为空')));
      }
      return;
    }
    await widget.plans.renamePlan(widget.planId, result);
    await refresh();
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这个计划？'),
        content: const Text('已有训练记录和进行中的训练不会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除')),
        ],
      ));
    if (confirmed != true) return;
    await widget.plans.deletePlan(widget.planId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> openEditor([PlanExercise? exercise]) async {
    await Navigator.of(context).push(MaterialPageRoute<bool>(
      builder: (_) => ExerciseEditorPage(plans: widget.plans,
        planId: widget.planId, exercise: exercise)));
    await refresh();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = List<PlanExercise>.of(plan!.exercises);
    final moved = current.removeAt(oldIndex);
    current.insert(newIndex, moved);
    await widget.plans.reorder(widget.planId, current.map((e) => e.id).toList());
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final current = plan;
    return Scaffold(
      appBar: AppBar(title: Text(current?.name ?? '计划详情'), actions: [
        PopupMenuButton<String>(onSelected: (value) {
          if (value == 'rename') editName();
          if (value == 'delete') delete();
        }, itemBuilder: (_) => const [
          PopupMenuItem(value: 'rename', child: Text('修改名称')),
          PopupMenuItem(value: 'delete', child: Text('删除计划')),
        ]),
      ]),
      body: current == null ? const Center(child: CircularProgressIndicator()) :
        SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('长按左侧把手调整动作顺序',
              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            Expanded(child: current.exercises.isEmpty
              ? Center(child: Text('还没有动作，点击下方添加',
                  style: TextStyle(color: colors.textSecondary)))
              : ReorderableListView.builder(
                  itemCount: current.exercises.length,
                  onReorderItem: reorder,
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final exercise = current.exercises[index];
                    return Padding(key: ValueKey(exercise.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(onTap: () => openEditor(exercise), child: Row(children: [
                        ReorderableDragStartListener(index: index,
                          child: const SizedBox(width: 40, height: 48,
                            child: Icon(Icons.drag_handle))),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(exercise.name, style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('${exercise.targetSets} 组 · 组间 '
                              '${(exercise.restBetweenSetsSeconds / 60).toStringAsFixed(1)} min',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                          ])),
                        const Icon(Icons.chevron_right),
                      ])),
                    );
                  },
                )),
            AppButton(label: '＋ 添加动作', primary: false,
              onPressed: () => openEditor()),
            const SizedBox(height: 12),
            AppButton(label: '开始训练', onPressed: current.exercises.isEmpty
              ? null : () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PrepPage(plan: current, workouts: widget.workouts,
                    onOpenWorkout: widget.onOpenWorkout)));
                await refresh();
              }),
          ]),
        )),
    );
  }
}

class PrepPage extends StatefulWidget {
  const PrepPage({super.key, required this.plan, required this.workouts,
    required this.onOpenWorkout});

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
    } on StateError catch (error) {
      final active = await widget.workouts.getActive();
      if (!mounted) return;
      if (active != null) {
        final resume = await showDialog<bool>(context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('已有未完成训练'),
            content: Text('请先继续或结束「${active.planName}」。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('留在此处')),
              TextButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('继续原训练')),
            ],
          ));
        if (resume == true) await widget.onOpenWorkout(active);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: const Text('准备训练')),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: double.infinity, child: AppCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.plan.name, style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('${widget.plan.exercises.length} 个动作 · ${widget.plan.totalSets} 组',
                style: TextStyle(color: colors.textSecondary)),
            ]))),
          const SizedBox(height: 22),
          const Text('动作顺序', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(child: ListView.separated(
            itemCount: widget.plan.exercises.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final exercise = widget.plan.exercises[index];
              return AppCard(child: Text(
                '${index + 1}  ${exercise.name}    ${exercise.targetSets} 组'));
            },
          )),
          AppButton(label: '开始训练', onPressed: starting ? null : start,
            height: 58),
        ]),
      )),
    );
  }
}
