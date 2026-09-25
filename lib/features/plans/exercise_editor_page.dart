import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/step_picker.dart';
import 'plan_models.dart';
import 'plan_repository.dart';

class ExerciseEditorPage extends StatefulWidget {
  const ExerciseEditorPage({super.key, required this.plans,
    required this.planId, this.exercise});

  final PlanRepository plans;
  final int planId;
  final PlanExercise? exercise;

  @override
  State<ExerciseEditorPage> createState() => _ExerciseEditorPageState();
}

class _ExerciseEditorPageState extends State<ExerciseEditorPage> {
  late final TextEditingController name = TextEditingController(
    text: widget.exercise?.name ?? '');
  late final TextEditingController weight = TextEditingController(
    text: widget.exercise?.defaultWeightKg?.toString() ?? '');
  late int sets = widget.exercise?.targetSets ?? 4;
  late int between = widget.exercise?.restBetweenSetsSeconds ?? 120;
  late int after = widget.exercise?.restAfterExerciseSeconds ?? 150;
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    weight.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final trimmed = name.text.trim();
    final rawWeight = weight.text.trim().replaceAll(',', '.');
    final parsedWeight = rawWeight.isEmpty ? null : double.tryParse(rawWeight);
    if (trimmed.isEmpty || (rawWeight.isNotEmpty &&
        (parsedWeight == null || parsedWeight <= 0))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('请填写动作名称和有效的重量')));
      return;
    }
    setState(() => saving = true);
    try {
      if (widget.exercise == null) {
        await widget.plans.addExercise(planId: widget.planId, name: trimmed,
          targetSets: sets, restBetweenSetsSeconds: between,
          restAfterExerciseSeconds: after, defaultWeightKg: parsedWeight);
      } else {
        await widget.plans.updateExercise(id: widget.exercise!.id, name: trimmed,
          targetSets: sets, restBetweenSetsSeconds: between,
          restAfterExerciseSeconds: after, defaultWeightKg: parsedWeight);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除动作？'),
        content: const Text('只会从计划中删除，已有训练记录不会改变。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除')),
        ],
      ));
    if (confirmed != true) return;
    await widget.plans.deleteExercise(widget.exercise!.id, widget.planId);
    if (mounted) Navigator.pop(context, true);
  }

  Widget fieldLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(label, style: TextStyle(color: context.appColors.textSecondary)),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise == null ? '添加动作' : '编辑动作'),
        actions: widget.exercise == null ? null : [
          TextButton(onPressed: delete,
            child: Text('删除', style: TextStyle(color: colors.danger))),
        ],
      ),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(children: [
          Expanded(child: ListView(children: [
            fieldLabel(context, '动作名称'),
            TextField(controller: name, maxLength: 60,
              decoration: const InputDecoration(hintText: '例如：坐姿划船', counterText: '')),
            const SizedBox(height: 20),
            fieldLabel(context, '组数'),
            StepPicker(value: sets, min: 1, max: 100, step: 1,
              label: (value) => '$value 组',
              onChanged: (value) => setState(() => sets = value)),
            const SizedBox(height: 20),
            fieldLabel(context, '组间休息'),
            StepPicker(value: between, min: 0, max: 3600, step: 30,
              label: (value) => '${(value / 60).toStringAsFixed(1)} min',
              onChanged: (value) => setState(() => between = value)),
            const SizedBox(height: 20),
            fieldLabel(context, '动作完成后休息'),
            StepPicker(value: after, min: 0, max: 3600, step: 30,
              label: (value) => '${(value / 60).toStringAsFixed(1)} min',
              onChanged: (value) => setState(() => after = value)),
            const SizedBox(height: 20),
            fieldLabel(context, '重量（可选，kg）'),
            TextField(controller: weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '例如：45')),
            const SizedBox(height: 16),
            Text('左右滑动切换档位 · 每跨一档轻震反馈',
              style: TextStyle(color: colors.textTertiary, fontSize: 12)),
          ])),
          AppButton(label: '保存动作', onPressed: saving ? null : save),
        ]),
      )),
    );
  }
}
