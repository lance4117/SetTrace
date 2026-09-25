import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/step_picker.dart';
import 'workout_models.dart';
import 'workout_repository.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required this.workouts, required this.sessionId});
  final WorkoutRepository workouts;
  final int sessionId;

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with WidgetsBindingObserver {
  WorkoutSessionData? session;
  Timer? ticker;
  bool busy = false;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
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
    await widget.workouts.normalizeRest(widget.sessionId);
    final data = await widget.workouts.getSession(widget.sessionId);
    if (mounted) setState(() { session = data; now = DateTime.now(); });
  }

  Future<void> mutate(Future<WorkoutSessionData> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final updated = await operation();
      if (mounted) setState(() { session = updated; now = DateTime.now(); });
      if (updated.allSetsCompleted && mounted) await askExit();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$error')));
      }
      await reload();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> askExit() async {
    if (session == null || !mounted) return;
    final choice = await showDialog<String>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(session!.allSetsCompleted ? '完成训练？' : '结束这次训练？'),
        content: Text(session!.completedSets == 0
          ? '尚未完成任何一组。可继续训练或丢弃本次会话。'
          : '已完成 ${session!.completedSets} 组。可以保存已完成内容，稍后在记录中查看。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'continue'),
            child: const Text('继续训练')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: Text('丢弃', style: TextStyle(color: dialogContext.appColors.danger))),
          if (session!.completedSets > 0)
            TextButton(onPressed: () => Navigator.pop(dialogContext, 'save'),
              child: const Text('保存已完成')),
        ],
      ));
    if (!mounted) return;
    if (choice == 'save') {
      await widget.workouts.finish(widget.sessionId);
      if (mounted) Navigator.of(context).pop();
    } else if (choice == 'discard') {
      if (session!.completedSets > 0) {
        final confirmed = await showDialog<bool>(context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('确认丢弃？'),
            content: const Text('已完成的组记录会永久删除。'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确认丢弃')),
            ],
          ));
        if (confirmed != true) return;
      }
      await widget.workouts.discard(widget.sessionId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void showExercises() {
    final data = session!;
    showModalBottomSheet<void>(context: context, isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('本次训练动作', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Flexible(child: ListView(shrinkWrap: true, children: [
              for (final exercise in data.exercises)
                ListTile(
                  title: Text(exercise.name),
                  subtitle: Text('${exercise.completedSets} / ${exercise.targetSets} 组 · '
                    '组间 ${exercise.restBetweenSetsSeconds ~/ 30 * 0.5} 分钟'),
                  trailing: exercise.sortOrder >= data.currentExerciseOrder
                    ? const Icon(Icons.edit_outlined) : null,
                  onTap: exercise.sortOrder < data.currentExerciseOrder ? null : () async {
                    Navigator.pop(sheetContext);
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => SessionExerciseEditorPage(
                        workouts: widget.workouts, sessionId: widget.sessionId,
                        exercise: exercise)));
                    await reload();
                  },
                ),
            ])),
          ]),
      )));
  }

  @override
  Widget build(BuildContext context) {
    final data = session;
    final colors = context.appColors;
    return PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) {
      if (!didPop) askExit();
    }, child: Scaffold(
      appBar: AppBar(title: Text(data?.planName ?? '训练中'),
        leading: IconButton(onPressed: askExit,
          icon: const Icon(Icons.arrow_back), tooltip: '结束或返回'),
        actions: [TextButton(onPressed: data == null ? null : askExit,
          child: const Text('退出'))]),
      body: data == null ? const Center(child: CircularProgressIndicator()) :
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text('动作 ${data.currentExerciseOrder} / ${data.exercises.length}',
                style: TextStyle(color: colors.textSecondary))),
              TextButton(onPressed: showExercises, child: const Text('全部动作与编辑')),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: data.totalSets == 0 ? 0 :
              data.completedSets / data.totalSets, minHeight: 7,
              borderRadius: BorderRadius.circular(6),
              color: colors.accentPressed, backgroundColor: colors.surfaceAlt),
            const SizedBox(height: 24),
            Expanded(child: data.resting ? _rest(context, data) : _training(context, data)),
            if (data.completedSets > 0)
              AppButton(label: '撤销上一组', primary: false,
                onPressed: busy ? null : () => mutate(() =>
                  widget.workouts.undoLastSet(data.id))),
          ]),
        )),
    ));
  }

  Widget _training(BuildContext context, WorkoutSessionData data) {
    final colors = context.appColors;
    final exercise = data.currentExercise;
    return LayoutBuilder(builder: (context, constraints) => ListView(children: [
        SizedBox(height: math.max(0, constraints.maxHeight - 530)),
        AppCard(borderColor: colors.accent, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.name, style: const TextStyle(fontSize: 24,
              fontWeight: FontWeight.w700)),
            if (exercise.defaultWeightKg != null) ...[
              const SizedBox(height: 6),
              Text('${exercise.defaultWeightKg} kg',
                style: TextStyle(color: colors.textSecondary)),
            ],
            const SizedBox(height: 28),
            Center(child: Text(
              '${data.currentSetNumber.toString().padLeft(2, '0')} / '
              '${exercise.targetSets.toString().padLeft(2, '0')}',
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.4),
              style: TextStyle(fontSize: 52, fontWeight: FontWeight.w700,
                color: colors.accentPressed))),
            const SizedBox(height: 16),
            Center(child: Wrap(spacing: 14, runSpacing: 10, children: [
              for (final set in exercise.sets)
                Icon(set.completed ? Icons.circle : Icons.circle_outlined,
                  size: 19, color: set.completed ? colors.accentPressed : colors.textTertiary),
            ])),
            const SizedBox(height: 12),
            Center(child: Text(data.allSetsCompleted ? '全部组已完成' :
              '当前第 ${data.currentSetNumber} 组',
              style: TextStyle(color: colors.textSecondary))),
            const SizedBox(height: 24),
            AppButton(label: data.allSetsCompleted ? '保存训练' : '完成本组',
              onPressed: busy ? null : data.allSetsCompleted ? askExit : () => mutate(() =>
                widget.workouts.completeSet(data.id,
                  expectedExerciseOrder: data.currentExerciseOrder,
                  expectedSetNumber: data.currentSetNumber))),
          ])),
        const SizedBox(height: 12),
        AppCard(backgroundColor: colors.accentSoft,
          borderColor: colors.accentSoft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('下一动作', style: TextStyle(color: colors.textSecondary,
              fontSize: 12)),
            const SizedBox(height: 4),
            Text(data.nextExercise == null ? '这是最后一个动作' :
              '${data.nextExercise!.name} · ${data.nextExercise!.targetSets} 组',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          ])),
      ]));
  }

  Widget _rest(BuildContext context, WorkoutSessionData data) {
    final colors = context.appColors;
    final remaining = math.max(0, data.restEndAt!.difference(now).inSeconds + 1);
    final display = '${(remaining ~/ 60).toString().padLeft(2, '0')}:'
      '${(remaining % 60).toString().padLeft(2, '0')}';
    return Column(children: [
      const Spacer(),
      Text(data.restKind == 'between_exercises' ? '动作间休息' : '组间休息',
        style: TextStyle(color: colors.textSecondary)),
      const SizedBox(height: 24),
      FittedBox(child: Text(display, style: TextStyle(fontSize: 72,
        fontWeight: FontWeight.w700, color: colors.accentPressed))),
      const SizedBox(height: 14),
      Text('下一组：${data.currentExercise.name} · '
        '${data.currentSetNumber} / ${data.currentExercise.targetSets}',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.textSecondary)),
      const Spacer(),
      Row(children: [
        Expanded(child: AppButton(label: '−30 秒', primary: false,
          onPressed: busy ? null : () => mutate(() =>
            widget.workouts.adjustRest(data.id, -30)))),
        const SizedBox(width: 8),
        Expanded(child: AppButton(label: '跳过',
          onPressed: busy ? null : () => mutate(() =>
            widget.workouts.skipRest(data.id)))),
        const SizedBox(width: 8),
        Expanded(child: AppButton(label: '+30 秒', primary: false,
          onPressed: busy ? null : () => mutate(() =>
            widget.workouts.adjustRest(data.id, 30)))),
      ]),
      const SizedBox(height: 20),
    ]);
  }
}

class SessionExerciseEditorPage extends StatefulWidget {
  const SessionExerciseEditorPage({super.key, required this.workouts,
    required this.sessionId, required this.exercise});
  final WorkoutRepository workouts;
  final int sessionId;
  final SessionExercise exercise;

  @override
  State<SessionExerciseEditorPage> createState() => _SessionExerciseEditorPageState();
}

class _SessionExerciseEditorPageState extends State<SessionExerciseEditorPage> {
  late int sets = widget.exercise.targetSets;
  late int between = widget.exercise.restBetweenSetsSeconds;
  late int after = widget.exercise.restAfterExerciseSeconds;
  bool saving = false;

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.workouts.updateExercise(widget.sessionId, widget.exercise.id,
        targetSets: sets, restBetweenSetsSeconds: between,
        restAfterExerciseSeconds: after);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('本次编辑 · ${widget.exercise.name}')),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: ListView(children: [
          const Text('目标组数'),
          const SizedBox(height: 12),
          StepPicker(value: sets, min: math.max(1, widget.exercise.completedSets),
            max: 100, step: 1, label: (value) => '$value 组',
            onChanged: (value) => setState(() => sets = value)),
          const SizedBox(height: 24),
          const Text('组间休息'),
          const SizedBox(height: 12),
          StepPicker(value: between, min: 0, max: 3600, step: 30,
            label: (value) => '${(value / 60).toStringAsFixed(1)} min',
            onChanged: (value) => setState(() => between = value)),
          const SizedBox(height: 24),
          const Text('动作后休息'),
          const SizedBox(height: 12),
          StepPicker(value: after, min: 0, max: 3600, step: 30,
            label: (value) => '${(value / 60).toStringAsFixed(1)} min',
            onChanged: (value) => setState(() => after = value)),
          const SizedBox(height: 16),
          Text('只修改本次训练；已开始的休息时间不变。',
            style: TextStyle(color: context.appColors.textSecondary)),
        ])),
        AppButton(label: '保存本次配置', onPressed: saving ? null : save),
      ]),
    )),
  );
}
