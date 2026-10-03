import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import 'workout_models.dart';

class SessionOrderSheet extends StatefulWidget {
  const SessionOrderSheet({
    super.key,
    required this.session,
    required this.onSave,
    required this.onReload,
    this.selectNext = false,
  });
  final WorkoutSessionData session;
  final Future<WorkoutSessionData> Function(WorkoutSessionData, List<int>)
  onSave;
  final Future<WorkoutSessionData?> Function() onReload;
  final bool selectNext;
  @override
  State<SessionOrderSheet> createState() => _SessionOrderSheetState();
}

class _SessionOrderSheetState extends State<SessionOrderSheet> {
  late WorkoutSessionData baseline = widget.session;
  late List<SessionExercise> draft = [...baseline.exercises];
  bool saving = false;
  String? error;

  List<int> get candidateIds =>
      draft.where((e) => e.movable).map((e) => e.id).toList();

  void reorder(int oldIndex, int newIndex) {
    if (saving || !draft[oldIndex].movable) return;

    final slots = [
      for (var i = 0; i < draft.length; i++)
        if (draft[i].movable) i,
    ];
    final candidates = slots.map((i) => draft[i]).toList();
    final from = slots.indexOf(oldIndex);
    final to = (slots.where((i) => i <= newIndex).length - 1).clamp(
      0,
      slots.length - 1,
    );
    final moved = candidates.removeAt(from);
    candidates.insert(to, moved);
    setState(() {
      for (var i = 0; i < slots.length; i++) {
        draft[slots[i]] = candidates[i];
      }
    });
  }

  Future<void> save(List<int> ids) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    var succeeded = false;
    try {
      await widget.onSave(baseline, ids);
      succeeded = true;
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = '保存失败：$failure';
        });
      }
    } finally {
      if (mounted && !succeeded) setState(() => saving = false);
    }
  }

  Future<void> reload() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final data = await widget.onReload();
      if (data == null || !data.inProgress) throw StateError('本次训练已结束');
      if (mounted) {
        setState(() {
          baseline = data;
          draft = [...data.exercises];
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = '重新加载失败：$failure';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final candidates = draft.where((e) => e.movable).toList();
    return PopScope(
      canPop: !saving,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectNext ? '更换下一动作' : '调整剩余顺序',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.selectNext
                      ? baseline.currentExercise.movable
                            ? '替换当前待练动作，不记录额外完成组。'
                            : '当前动作做完后练；当前组数和休息保持。'
                      : '拖动待练动作；已记录组的动作固定。只影响本次训练。',
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: widget.selectNext
                      ? ListView(
                          children: [
                            for (final exercise in candidates)
                              ListTile(
                                key: ValueKey('select-next-${exercise.id}'),
                                title: Text(exercise.name),
                                subtitle: Text('${exercise.targetSets} 组 · 待练'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: saving || !baseline.canReorder
                                    ? null
                                    : () {
                                        final ids = candidateIds
                                          ..remove(exercise.id);
                                        ids.insert(0, exercise.id);
                                        save(ids);
                                      },
                              ),
                            if (!baseline.canReorder)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('没有其他可换序的待练动作'),
                              ),
                          ],
                        )
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: draft.length,
                          onReorderItem: reorder,
                          itemBuilder: (context, index) {
                            final exercise = draft[index];
                            final state = exercise.completed
                                ? '已完成'
                                : exercise.movable
                                ? '待练'
                                : '进行中';
                            return ListTile(
                              key: ValueKey('order-row-${exercise.id}'),
                              title: Text(exercise.name),
                              subtitle: Text(
                                '$state · ${exercise.completedSets} / ${exercise.targetSets} 组',
                              ),
                              trailing:
                                  exercise.movable &&
                                      baseline.canReorder &&
                                      !saving
                                  ? ReorderableDragStartListener(
                                      index: index,
                                      key: ValueKey('drag-${exercise.id}'),
                                      child: Semantics(
                                        label: '拖动${exercise.name}',
                                        child: const SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: Icon(Icons.drag_handle),
                                        ),
                                      ),
                                    )
                                  : const SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Icon(Icons.lock_outline),
                                    ),
                            );
                          },
                        ),
                ),
                if (error != null) ...[
                  Text(error!, style: TextStyle(color: colors.danger)),
                  TextButton(
                    onPressed: saving ? null : reload,
                    child: const Text('重新加载'),
                  ),
                ],
                if (saving) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '取消',
                        primary: false,
                        onPressed: saving ? null : () => Navigator.pop(context),
                      ),
                    ),
                    if (!widget.selectNext) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          label: '保存顺序',
                          onPressed: saving || !baseline.canReorder
                              ? null
                              : () => save(candidateIds),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
