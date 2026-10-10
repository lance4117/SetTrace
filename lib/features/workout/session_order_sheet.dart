import 'package:flutter/material.dart';

import '../../l10n/localization.dart';
import '../../l10n/error_messages.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
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
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectNext
                      ? context.l10n.changeNext
                      : context.l10n.reorderRemaining,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  widget.selectNext
                      ? baseline.currentExercise.movable
                            ? context.l10n.replaceCurrentNote
                            : context.l10n.chooseFollowingNote
                      : context.l10n.reorderSessionNote,
                  style: TextStyle(color: colors.textSecondary),
                ),
                SizedBox(height: 12),
                Expanded(
                  child: widget.selectNext
                      ? ListView(
                          children: [
                            for (final exercise in candidates)
                              ListTile(
                                key: ValueKey('select-next-${exercise.id}'),
                                title: Text(exercise.name),
                                subtitle: Text(
                                  context.l10n.pendingSets(exercise.targetSets),
                                ),
                                trailing: Icon(Icons.chevron_right),
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
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(context.l10n.noReorderCandidates),
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
                                ? context.l10n.completed
                                : exercise.movable
                                ? context.l10n.pending
                                : context.l10n.inProgress;
                            return ListTile(
                              key: ValueKey('order-row-${exercise.id}'),
                              title: Text(exercise.name),
                              subtitle: Text(
                                context.l10n.orderProgress(
                                  state,
                                  exercise.completedSets,
                                  exercise.targetSets,
                                ),
                              ),
                              trailing:
                                  exercise.movable &&
                                      baseline.canReorder &&
                                      !saving
                                  ? ReorderableDragStartListener(
                                      index: index,
                                      key: ValueKey('drag-${exercise.id}'),
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
                                    )
                                  : SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Icon(Icons.lock_outline),
                                    ),
                            );
                          },
                        ),
                ),
                if (error != null) ...[
                  Text(
                    error!(context.l10n),
                    style: TextStyle(color: colors.danger),
                  ),
                  TextButton(
                    onPressed: saving ? null : reload,
                    child: Text(context.l10n.reload),
                  ),
                ],
                if (saving) LinearProgressIndicator(),
                SizedBox(height: 12),
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
                      SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          label: context.l10n.saveOrder,
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
