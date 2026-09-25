import '../workout/workout_models.dart';

class HistoryStats {
  const HistoryStats({required this.weekCount, required this.monthCount,
    required this.monthDurationSeconds, required this.monthCompletedSets,
    required this.monthSessions, this.latest});

  final int weekCount, monthCount, monthDurationSeconds, monthCompletedSets;
  final List<WorkoutSessionData> monthSessions;
  final WorkoutSessionData? latest;

  factory HistoryStats.calculate(List<WorkoutSessionData> sessions,
      {required DateTime now, required DateTime month}) {
    final localNow = now.toLocal();
    final weekStart = DateTime(localNow.year, localNow.month,
      localNow.day - localNow.weekday + 1);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final monthSessions = sessions.where((session) {
      final day = DateTime.parse(session.startedLocalDate);
      return day.year == month.year && day.month == month.month;
    }).toList();
    final weekCount = sessions.where((session) {
      final day = DateTime.parse(session.startedLocalDate);
      return !day.isBefore(weekStart) && day.isBefore(weekEnd);
    }).length;
    final currentMonthCount = sessions.where((session) {
      final day = DateTime.parse(session.startedLocalDate);
      return day.year == localNow.year && day.month == localNow.month;
    }).length;
    final sorted = [...sessions]..sort((a, b) =>
      (b.endedAt ?? b.startedAt).compareTo(a.endedAt ?? a.startedAt));
    return HistoryStats(weekCount: weekCount, monthCount: currentMonthCount,
      monthSessions: monthSessions,
      monthDurationSeconds: monthSessions.fold(0,
        (sum, session) => sum + (session.durationSeconds ?? 0)),
      monthCompletedSets: monthSessions.fold(0,
        (sum, session) => sum + session.completedSets),
      latest: sorted.isEmpty ? null : sorted.first);
  }
}
