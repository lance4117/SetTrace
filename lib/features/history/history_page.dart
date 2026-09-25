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
  const HistoryPage({super.key, required this.workouts, required this.revision});
  final WorkoutRepository workouts;
  final int revision;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<WorkoutSessionData> sessions = [];
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool loading = true;

  @override
  void initState() { super.initState(); refresh(); }

  @override
  void didUpdateWidget(covariant HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) refresh();
  }

  Future<void> refresh() async {
    final data = await widget.workouts.listHistory();
    if (mounted) setState(() { sessions = data; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final stats = HistoryStats.calculate(sessions, now: DateTime.now(), month: month);
    final grouped = <String, List<WorkoutSessionData>>{};
    for (final session in stats.monthSessions) {
      grouped.putIfAbsent(session.startedLocalDate, () => []).add(session);
    }
    return SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('训练记录', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _stat(context, '${stats.weekCount}', '本周训练')),
        const SizedBox(width: 8),
        Expanded(child: _stat(context, '${stats.monthCount}', '本月训练')),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _stat(context,
          durationLabel(stats.monthDurationSeconds), '所选月份时长')),
        const SizedBox(width: 8),
        Expanded(child: _stat(context, '${stats.monthCompletedSets}', '所选月份完成组')),
      ]),
      const SizedBox(height: 16),
      Text(stats.latest == null ? '最近训练：暂无' :
        '最近训练：${stats.latest!.planName} · ${durationLabel(stats.latest!.durationSeconds ?? 0)}',
        style: TextStyle(color: colors.textSecondary)),
      const SizedBox(height: 20),
      Row(children: [
        IconButton(onPressed: () => setState(() =>
          month = DateTime(month.year, month.month - 1)),
          icon: const Icon(Icons.chevron_left), tooltip: '上个月'),
        Expanded(child: Center(child: Text('${month.year} 年 ${month.month} 月',
          style: const TextStyle(fontWeight: FontWeight.w700)))),
        IconButton(onPressed: () => setState(() =>
          month = DateTime(month.year, month.month + 1)),
          icon: const Icon(Icons.chevron_right), tooltip: '下个月'),
      ]),
      const SizedBox(height: 12),
      if (loading) const Center(child: CircularProgressIndicator())
      else if (grouped.isEmpty)
        Padding(padding: const EdgeInsets.only(top: 56), child: Center(
          child: Text('这个月还没有训练记录',
            style: TextStyle(color: colors.textSecondary))))
      else for (final entry in grouped.entries) ...[
        Padding(padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(entry.key, style: TextStyle(color: colors.textSecondary))),
        for (final session in entry.value) ...[
          AppCard(onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => HistoryDetailPage(session: session))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.planName, style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('${durationLabel(session.durationSeconds ?? 0)} · '
                    '${session.exercises.length} 个动作 · ${session.completedSets} 组',
                    style: TextStyle(color: colors.textSecondary)),
                ])),
              const Icon(Icons.chevron_right),
            ])),
          const SizedBox(height: 10),
        ],
      ],
    ]));
  }

  Widget _stat(BuildContext context, String value, String label) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Column(children: [
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: context.appColors.textSecondary,
        fontSize: 11)),
    ]));
}

class HistoryDetailPage extends StatelessWidget {
  const HistoryDetailPage({super.key, required this.session});
  final WorkoutSessionData session;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    String time(DateTime date) {
      final local = date.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    }
    return Scaffold(appBar: AppBar(title: const Text('训练详情')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
        Text(session.planName, style: const TextStyle(fontSize: 26,
          fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${session.startedLocalDate} · ${time(session.startedAt)}–'
          '${time(session.endedAt!)} · ${durationLabel(session.durationSeconds ?? 0)}',
          style: TextStyle(color: colors.textSecondary)),
        const SizedBox(height: 24),
        for (final exercise in session.exercises) ...[
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exercise.name, style: const TextStyle(fontSize: 18,
                fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('完成 ${exercise.completedSets} / ${exercise.targetSets} 组',
                style: TextStyle(color: colors.textSecondary)),
              for (final set in exercise.sets)
                Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text('第 ${set.number} 组 · ${set.completedAt == null ? '未完成' : time(set.completedAt!)}')),
            ])),
          const SizedBox(height: 12),
        ],
      ])));
  }
}
