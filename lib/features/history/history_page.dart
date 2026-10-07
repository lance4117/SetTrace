import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../workout/workout_models.dart';
import '../workout/workout_repository.dart';
import 'history_stats.dart';

String durationLabel(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return hours == 0 ? '$minutes 分钟' : '$hours 小时 $minutes 分钟';
}

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
  String? refreshError;
  String? removalNotice;

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
        refreshError = removalNotice == null
            ? '记录加载失败，请重试'
            : '$removalNotice，刷新失败，请重试';
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
      removalNotice = deleted ? '记录已删除' : '记录已不存在';
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(removalNotice!)));
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
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            '训练记录',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _stat(context, '${stats.weekCount}', '本周训练')),
              const SizedBox(width: 8),
              Expanded(child: _stat(context, '${stats.monthCount}', '本月训练')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _stat(
                  context,
                  durationLabel(stats.monthDurationSeconds),
                  '所选月份时长',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat(context, '${stats.monthCompletedSets}', '所选月份完成组'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            stats.latest == null
                ? '最近训练：暂无'
                : '最近训练：${stats.latest!.planName} · ${durationLabel(stats.latest!.durationSeconds ?? 0)}',
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
                tooltip: '上个月',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${month.year} 年 ${month.month} 月',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
                tooltip: '下个月',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (refreshError != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(refreshError!),
                  TextButton(
                    onPressed: refresh,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('重试刷新'),
                  ),
                ],
              ),
            ),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (grouped.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 56),
              child: Center(
                child: Text(
                  '这个月还没有训练记录',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            )
          else
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  entry.key,
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
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${durationLabel(session.durationSeconds ?? 0)} · '
                              '${session.exercises.length} 个动作 · ${session.completedSets} 组',
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
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
  String? deleteError;
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
        void close(bool value) {
          if (closed) return;
          closed = true;
          Navigator.pop(dialogContext, value);
        }

        return AlertDialog(
          title: const Text('删除这条训练记录？'),
          scrollable: true,
          content: Text(
            '${session.planName}\n${session.startedLocalDate}\n\n'
            '删除后无法恢复，相关训练统计将同步更新。',
          ),
          actions: [
            TextButton(
              onPressed: () => close(false),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => close(true),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除'),
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
        deleteError = '只能删除已保存的训练，正在进行的训练不会被删除。';
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        deleting = false;
        deleteError = '删除失败，请重试。';
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
    String time(DateTime date) {
      final local = date.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }

    return PopScope<bool>(
      canPop: !deleting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('训练详情'),
          actions: [
            if (deleting)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            PopupMenuButton<String>(
              tooltip: '训练记录操作',
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                visualDensity: VisualDensity.standard,
              ),
              enabled: !confirming && !deleting,
              onSelected: (_) => delete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', height: 48, child: Text('删除记录')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (deleteError != null) ...[
                Text(deleteError!),
                TextButton(
                  onPressed: delete,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('重试删除'),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                session.planName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${session.startedLocalDate} · ${time(session.startedAt)}–'
                '${time(session.endedAt!)} · ${durationLabel(session.durationSeconds ?? 0)}',
                style: TextStyle(color: colors.textSecondary),
              ),
              const SizedBox(height: 24),
              for (final exercise in session.exercises) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '完成 ${exercise.completedSets} / ${exercise.targetSets} 组',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      for (final set in exercise.sets)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '第 ${set.number} 组 · ${set.completedAt == null ? '未完成' : time(set.completedAt!)}',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
