import 'package:flutter/material.dart';

import '../../l10n/localization.dart';
import '../../l10n/error_messages.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_task_layout.dart';
import 'workout_models.dart';
import 'workout_failure.dart';

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
  LocalizedMessage? error;

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
          error = (l) => failureText(l, failure, fallback: l.saveFailed);
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
      if (data == null || !data.inProgress) {
        throw WorkoutStateException(WorkoutFailure.sessionEnded);
      }
      if (mounted) {
        setState(() {
          baseline = data;
          draft = [...data.exercises];
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = (l) => failureText(l, failure, fallback: l.loadFailed);
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget header(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.selectNext
              ? context.l10n.changeNext
              : context.l10n.reorderRemaining,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          widget.selectNext
              ? (baseline.currentExercise.movable
                    ? context.l10n.replaceCurrentNote
                    : context.l10n.chooseFollowingNote)
              : context.l10n.reorderSessionNote,
          style: TextStyle(color: context.appColors.textSecondary),
        ),
        if (!baseline.canReorder) ...[
          const SizedBox(height: 12),
          Text(context.l10n.noReorderCandidates),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
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
  );

  void moveCandidate(int index, int delta) {
    final slots = [
      for (var i = 0; i < draft.length; i++)
        if (draft[i].movable) i,
    ];
    final position = slots.indexOf(index);
    if (saving ||
        position < 0 ||
        position + delta < 0 ||
        position + delta >= slots.length) {
      return;
    }
    reorder(index, slots[position + delta]);
  }

  Widget orderRow(BuildContext context, int index) {
    final e = draft[index];
    final canMove = e.movable && baseline.canReorder && !saving;
    final state = e.skippedSets > 0
        ? context.l10n.remainingSetsSkipped
        : e.completed
        ? context.l10n.completed
        : e.movable
        ? context.l10n.pending
        : context.l10n.inProgress;
    return Column(
      key: ValueKey('order-item-${e.id}'),
      children: [
        ListTile(
          key: ValueKey('order-row-${e.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(e.name),
          subtitle: Text(
            context.l10n.orderProgress(state, e.completedSets, e.targetSets),
          ),
          trailing: canMove
              ? ReorderableDragStartListener(
                  index: index,
                  key: ValueKey('drag-${e.id}'),
                  child: Semantics(
                    label: context.l10n.dragExercise(e.name),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                )
              : Semantics(
                  label: state,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.lock_outline),
                  ),
                ),
        ),
        if (e.movable && baseline.canReorder)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: ValueKey('order-up-${e.id}'),
                tooltip: context.l10n.moveExerciseUp(e.name),
                onPressed: !canMove || candidateIds.indexOf(e.id) == 0
                    ? null
                    : () => moveCandidate(index, -1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                key: ValueKey('order-down-${e.id}'),
                tooltip: context.l10n.moveExerciseDown(e.name),
                onPressed:
                    !canMove ||
                        candidateIds.indexOf(e.id) == candidateIds.length - 1
                    ? null
                    : () => moveCandidate(index, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
        const Divider(height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: FractionallySizedBox(
      heightFactor: .9,
      child: AppTaskLayout(
        body: widget.selectNext
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  header(context),
                  for (final e in draft.where((e) => e.movable))
                    ListTile(
                      key: ValueKey('select-next-${e.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.name),
                      subtitle: Text(context.l10n.pendingSets(e.targetSets)),
                      trailing: const ExcludeSemantics(
                        child: Icon(Icons.chevron_right),
                      ),
                      onTap: saving || !baseline.canReorder
                          ? null
                          : () {
                              final ids = candidateIds..remove(e.id);
                              ids.insert(0, e.id);
                              save(ids);
                            },
                    ),
                ],
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.all(24),
                header: header(context),
                buildDefaultDragHandles: false,
                itemCount: draft.length,
                onReorderItem: reorder,
                itemBuilder: orderRow,
              ),
        actions: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saving) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: context.l10n.cancel,
                    primary: false,
                    onPressed: saving ? null : () => Navigator.pop(context),
                  ),
                ),
                if (!widget.selectNext) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: context.l10n.saveOrder,
                      busy: saving,
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
  );
}
