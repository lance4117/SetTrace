import 'package:flutter/material.dart';

import '../../l10n/localization.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../workout/workout_models.dart';
import '../workout/workout_repository.dart';
import 'history_stats.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.workouts,
    required this.revision,
  });
  final WorkoutRepository workouts;
  final int revision;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<WorkoutSessionData> sessions = [];
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool loading = true;
  int refreshGeneration = 0;
  final removedSessionIds = <int>{};
  LocalizedMessage? refreshError;
  LocalizedMessage? removalNotice;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) refresh();
  }

  Future<void> refresh() async {
    final generation = ++refreshGeneration;
    try {
      final data = await widget.workouts.listHistory();
      if (!mounted || generation != refreshGeneration) return;
      setState(() {
        sessions = data
            .where((s) => !removedSessionIds.contains(s.id))
            .toList();
        loading = false;
        refreshError = null;
        removalNotice = null;
      });
    } catch (_) {
      if (!mounted || generation != refreshGeneration) return;
      setState(() {
        loading = false;
        final notice = removalNotice;
        refreshError = notice == null
            ? (l) => l.historyLoadFailed
            : (l) => l.historyRefreshFailed(notice(l));
      });
    }
  }

  Future<void> openDetail(WorkoutSessionData session) async {
    final deleted = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) =>
            HistoryDetailPage(session: session, workouts: widget.workouts),
      ),
    );
    // null is an ordinary return; false means the target was already absent.
    if (!mounted || deleted == null) return;
    setState(() {
      refreshGeneration++;
      removedSessionIds.add(session.id);
      sessions = sessions.where((s) => s.id != session.id).toList();
      loading = false;
      refreshError = null;
      removalNotice = deleted
          ? (l) => l.historyDeleted
          : (l) => l.historyMissing;
    });
    showAppSnackBar(context, removalNotice!);
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final stats = HistoryStats.calculate(
      sessions,
      now: DateTime.now(),
      month: month,
    );
    final grouped = <String, List<WorkoutSessionData>>{};
    for (final session in stats.monthSessions) {
      grouped.putIfAbsent(session.startedLocalDate, () => []).add(session);
    }
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(24),
        children: [
          Text(
            context.l10n.historyTitle,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _stat(
                  context,
                  context.formats.number(stats.weekCount),
                  context.l10n.thisWeek,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _stat(
                  context,
                  context.formats.number(stats.monthCount),
                  context.l10n.thisMonth,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _stat(
                  context,
                  context.formats.duration(stats.monthDurationSeconds),
                  context.l10n.monthDuration,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _stat(
                  context,
                  context.formats.number(stats.monthCompletedSets),
                  context.l10n.monthSets,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            stats.latest == null
                ? context.l10n.noRecentWorkout
                : context.l10n.recentWorkout(
                    stats.latest!.planName,
                    context.formats.duration(
                      stats.latest!.durationSeconds ?? 0,
                    ),
                  ),
            style: TextStyle(color: colors.textSecondary),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                icon: Icon(Icons.chevron_left),
                tooltip: context.l10n.previousMonth,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    context.formats.month(month),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                icon: Icon(Icons.chevron_right),
                tooltip: context.l10n.nextMonth,
              ),
            ],
          ),
          SizedBox(height: 12),
          if (refreshError != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(refreshError!(context.l10n)),
                  TextButton(
                    onPressed: refresh,
                    style: TextButton.styleFrom(minimumSize: Size(48, 48)),
                    child: Text(context.l10n.retryRefresh),
                  ),
                ],
              ),
            ),
          if (loading)
            Center(child: CircularProgressIndicator())
          else if (grouped.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 56),
              child: Center(
                child: Text(
                  context.l10n.noHistoryMonth,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            )
          else
            for (final entry in grouped.entries) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  context.formats.date(DateTime.parse(entry.key)),
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              for (final session in entry.value) ...[
                AppCard(
                  key: ValueKey('history-session-${session.id}'),
                  onTap: () => openDetail(session),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.planName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              context.l10n.historySummary(
                                context.formats.duration(
                                  session.durationSeconds ?? 0,
                                ),
                                session.exercises.length,
                                session.completedSets,
                              ),
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                SizedBox(height: 10),
              ],
            ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) => AppCard(
    padding: EdgeInsets.all(12),
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class HistoryDetailPage extends StatefulWidget {
  const HistoryDetailPage({
    super.key,
    required this.session,
    required this.workouts,
  });
  final WorkoutSessionData session;
  final WorkoutRepository workouts;

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  bool confirming = false;
  bool deleting = false;
  LocalizedMessage? deleteError;
  WorkoutSessionData get session => widget.session;

  Future<void> delete() async {
    if (confirming || deleting) return;
    setState(() {
      confirming = true;
      deleteError = null;
    });
    bool closed = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final context = dialogContext;
        void close(bool value) {
          if (closed) return;
          closed = true;
          Navigator.pop(dialogContext, value);
        }

        return AlertDialog(
          title: Text(context.l10n.deleteHistoryTitle),
          scrollable: true,
          content: Text(
            context.l10n.deleteHistoryNote(
              session.planName,
              context.formats.date(DateTime.parse(session.startedLocalDate)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => close(false),
              style: TextButton.styleFrom(minimumSize: Size(48, 48)),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => close(true),
              style: TextButton.styleFrom(
                minimumSize: Size(48, 48),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(context.l10n.delete),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => confirming = false);
      return;
    }
    setState(() {
      deleting = true;
      confirming = false;
    });
    try {
      await widget.workouts.deleteHistory(session.id);
    } on HistoryDeleteException catch (error) {
      if (!mounted) return;
      if (error.reason == HistoryDeleteFailure.notFound) {
        await returnToHistory(false);
        return;
      }
      setState(() {
        deleting = false;
        deleteError = (l) => l.activeHistoryDelete;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        deleting = false;
        deleteError = (l) => l.historyDeleteFailed;
      });
      return;
    }
    if (mounted) await returnToHistory(true);
  }

  Future<void> returnToHistory(bool deleted) async {
    // Rebuild PopScope before popping a route protected during the write.
    setState(() {
      deleting = false;
      confirming = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(deleted);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    String time(DateTime date) => context.formats.time(date);

    return PopScope<bool>(
      canPop: !deleting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.workoutDetails),
          actions: [
            if (deleting)
              Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            PopupMenuButton<String>(
              tooltip: context.l10n.historyMenu,
              style: IconButton.styleFrom(
                minimumSize: Size(48, 48),
                visualDensity: VisualDensity.standard,
              ),
              enabled: !confirming && !deleting,
              onSelected: (_) => delete(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  height: 48,
                  child: Text(context.l10n.deleteHistory),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(24),
            children: [
              if (deleteError != null) ...[
                Text(deleteError!(context.l10n)),
                TextButton(
                  onPressed: delete,
                  style: TextButton.styleFrom(minimumSize: Size(48, 48)),
                  child: Text(context.l10n.retryDelete),
                ),
                SizedBox(height: 16),
              ],
              Text(
                session.planName,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                context.l10n.historyTimeRange(
                  context.formats.date(
                    DateTime.parse(session.startedLocalDate),
                  ),
                  time(session.startedAt),
                  time(session.endedAt!),
                  context.formats.duration(session.durationSeconds ?? 0),
                ),
                style: TextStyle(color: colors.textSecondary),
              ),
              SizedBox(height: 24),
              for (final exercise in session.exercises) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        context.l10n.completedSets(
                          exercise.completedSets,
                          exercise.targetSets,
                        ),
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      for (final set in exercise.sets)
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            context.l10n.setResult(
                              set.number,
                              set.completedAt == null
                                  ? context.l10n.notCompleted
                                  : time(set.completedAt!),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
