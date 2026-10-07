import 'package:flutter_test/flutter_test.dart';
import 'package:settrace/features/history/history_stats.dart';
import 'package:settrace/features/workout/workout_models.dart';

WorkoutSessionData record(
  int id,
  String day,
  DateTime ended,
  int duration,
  int completed,
) => WorkoutSessionData(
  id: id,
  planName: '计划 $id',
  startedAt: ended.subtract(Duration(seconds: duration)),
  startedLocalDate: day,
  status: 'completed',
  currentExerciseOrder: 1,
  currentSetNumber: 1,
  endedAt: ended,
  durationSeconds: duration,
  exercises: [
    SessionExercise(
      id: id,
      name: '动作',
      sortOrder: 1,
      targetSets: completed,
      restBetweenSetsSeconds: 0,
      restAfterExerciseSeconds: 0,
      sets: [
        for (var i = 1; i <= completed; i++)
          SessionSet(id: i, number: i, completedAt: ended),
      ],
    ),
  ],
);

void main() {
  test('week, month and latest count saved sessions rather than days', () {
    final sessions = [
      record(1, '2026-09-21', DateTime.utc(2026, 9, 21, 10), 1800, 3),
      record(2, '2026-09-21', DateTime.utc(2026, 9, 21, 12), 2400, 4),
      record(3, '2026-09-01', DateTime.utc(2026, 9, 1, 10), 3600, 5),
      record(4, '2026-08-31', DateTime.utc(2026, 8, 31, 10), 600, 1),
    ];
    final stats = HistoryStats.calculate(
      sessions,
      now: DateTime(2026, 9, 25),
      month: DateTime(2026, 9),
    );
    expect(stats.weekCount, 2);
    expect(stats.monthCount, 3);
    expect(stats.monthSessions.length, 3);
    expect(stats.monthDurationSeconds, 7800);
    expect(stats.monthCompletedSets, 12);
    expect(stats.latest?.id, 2);
    final august = HistoryStats.calculate(
      sessions,
      now: DateTime(2026, 9, 25),
      month: DateTime(2026, 8),
    );
    expect(august.monthSessions.single.id, 4);
    expect(august.monthDurationSeconds, 600);
  });
  test(
    'deleting a same-day record recalculates counts duration sets and latest',
    () {
      final remaining = [
        record(1, '2026-09-21', DateTime.utc(2026, 9, 21, 10), 1800, 3),
        record(3, '2026-09-01', DateTime.utc(2026, 9, 1, 10), 3600, 5),
        record(4, '2026-08-31', DateTime.utc(2026, 8, 31, 10), 600, 1),
      ];
      final stats = HistoryStats.calculate(
        remaining,
        now: DateTime(2026, 9, 25),
        month: DateTime(2026, 9),
      );
      expect(stats.weekCount, 1);
      expect(stats.monthCount, 2);
      expect(stats.monthDurationSeconds, 5400);
      expect(stats.monthCompletedSets, 8);
      expect(stats.latest!.id, 1);
      final oldMonth = HistoryStats.calculate(
        remaining,
        now: DateTime(2026, 9, 25),
        month: DateTime(2026, 8),
      );
      expect(oldMonth.weekCount, 1);
      expect(oldMonth.monthCount, 2);
      expect(oldMonth.monthDurationSeconds, 600);
      expect(oldMonth.monthCompletedSets, 1);
      final noAugust = HistoryStats.calculate(
        remaining.where((s) => s.id != 4).toList(),
        now: DateTime(2026, 9, 25),
        month: DateTime(2026, 8),
      );
      expect(noAugust.monthSessions, isEmpty);
      expect(noAugust.monthDurationSeconds, 0);
      expect(noAugust.monthCompletedSets, 0);
      expect(noAugust.weekCount, 1);
      expect(noAugust.monthCount, 2);
      expect(noAugust.latest!.id, 1);
    },
  );

  test('last deletion zeros statistics and clears latest', () {
    final stats = HistoryStats.calculate(
      [],
      now: DateTime(2026, 9, 25),
      month: DateTime(2026, 9),
    );
    expect(stats.weekCount, 0);
    expect(stats.monthCount, 0);
    expect(stats.monthDurationSeconds, 0);
    expect(stats.monthCompletedSets, 0);
    expect(stats.latest, isNull);
    expect(stats.monthSessions, isEmpty);
  });

  test(
    'week and selected month retain their boundary semantics after deletion',
    () {
      final remaining = [
        record(1, '2026-08-31', DateTime.utc(2026, 8, 31, 10), 600, 1),
        record(2, '2026-09-01', DateTime.utc(2026, 9, 1, 10), 1200, 2),
      ];
      final stats = HistoryStats.calculate(
        remaining,
        now: DateTime(2026, 9, 2),
        month: DateTime(2026, 8),
      );
      expect(stats.weekCount, 2);
      expect(stats.monthCount, 1);
      expect(stats.monthDurationSeconds, 600);
      expect(stats.monthCompletedSets, 1);
      final after = HistoryStats.calculate(
        [remaining.last],
        now: DateTime(2026, 9, 2),
        month: DateTime(2026, 8),
      );
      expect(after.weekCount, 1);
      expect(after.monthCount, 1);
      expect(after.monthDurationSeconds, 0);
      expect(after.latest!.id, 2);
    },
  );
}
