import '../backup/data_write_coordinator.dart';

import 'package:sqflite/sqflite.dart';

import 'rest_alert_options.dart';

class RestAlertEvent {
  const RestAlertEvent(this.row);
  final Map<String, Object?> row;
  int get id => row['id'] as int;
  int get revision => row['revision'] as int;
  int get sessionId => row['session_id'] as int;
  int get dueAt => row['due_at'] as int;
  String get title => row['title'] as String;
  String get body => row['body'] as String;
  int get sequence => row['delivery_sequence'] as int? ?? 0;
  bool get awaitingConfirmation =>
      row['state'] == 'consumed' && row['acknowledged_at'] == null;
  int? get deliveryAt =>
      row['state'] == 'pending' ? dueAt : row['next_delivery_at'] as int?;
  String get scheduleKey => '$revision:$sequence:$deliveryAt';
}

/// Shared durable contract with the Android receiver. Training writes use its
/// existing transaction; AlarmManager work runs only after that commit.
class RestAlertRepository {
  RestAlertRepository(this.db, {DateTime Function()? clock, this.coordinator})
    : clock = clock ?? DateTime.now;
  final Database db;
  final DataWriteCoordinator? coordinator;
  Future<void> Function()? beforePreferencesWrite;
  Future<T> _write<T>(Future<T> Function() action) =>
      coordinator?.write(action) ?? action();
  final DateTime Function() clock;
  int get nowMs => clock().toUtc().millisecondsSinceEpoch;

  static Future<void> cancel(DatabaseExecutor txn, int sessionId) async {
    await txn.rawUpdate(
      """UPDATE rest_alerts
      SET state = 'cancelled', revision = revision + 1
      WHERE session_id = ? AND state IN ('pending', 'consumed')""",
      [sessionId],
    );
    await txn.update(
      'workout_sessions',
      {'current_rest_alert_id': null},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  static Future<void> refresh(
    DatabaseExecutor txn,
    int sessionId, {
    bool revive = false,
  }) async {
    final sessions = await txn.query(
      'workout_sessions',
      where: "id = ? AND status = 'in_progress'",
      whereArgs: [sessionId],
    );
    if (sessions.isEmpty) return;
    final s = sessions.single;
    final end = s['rest_end_at'] as int?;
    if (end == null) return;
    final ids = s['current_rest_alert_id'];
    final events = ids == null
        ? <Map<String, Object?>>[]
        : await txn.query('rest_alerts', where: 'id = ?', whereArgs: [ids]);
    if (events.isEmpty) {
      final id = await txn.insert('rest_alerts', {
        'session_id': sessionId,
        'exercise_id': s['current_session_exercise_id'],
        'set_number': s['current_set_number'],
        'due_at': end,
        'state': 'pending',
      });
      await txn.update(
        'workout_sessions',
        {'current_rest_alert_id': id},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } else {
      final e = events.single;
      final changed =
          e['due_at'] != end ||
          e['exercise_id'] != s['current_session_exercise_id'] ||
          e['set_number'] != s['current_set_number'];
      if (e['state'] == 'consumed' || e['state'] == 'expired') return;
      if (changed || (revive && e['state'] == 'cancelled')) {
        await txn.update(
          'rest_alerts',
          {
            'exercise_id': s['current_session_exercise_id'],
            'set_number': s['current_set_number'],
            'due_at': end,
            'revision': (e['revision'] as int) + 1,
            'state': 'pending',
          },
          where: 'id = ?',
          whereArgs: [e['id']],
        );
      }
    }
  }

  Future<Map<String, Object?>> preferences() async =>
      (await db.query('rest_alert_preferences', where: 'id = 1')).single;

  Future<void> setOptions(RestAlertOptions options) => _write(() async {
    await beforePreferencesWrite?.call();
    if (!RestAlertOptions.sounds.contains(options.sound) ||
        !RestAlertOptions.intervals.contains(options.interval)) {
      throw ArgumentError('invalidReminderOptions');
    }
    await db.transaction((txn) async {
      final old = RestAlertOptions.fromMap(
        (await txn.query('rest_alert_preferences')).single,
      );
      await txn.update(
        'rest_alert_preferences',
        options.toMap(),
        where: 'id = 1',
      );
      final reset =
          old.repeat != options.repeat || old.interval != options.interval;
      await txn.rawUpdate(
        """UPDATE rest_alerts SET revision = revision + 1,
        next_delivery_at = CASE WHEN state = 'consumed' AND ? = 1 THEN ?
          WHEN state = 'consumed' AND ? = 0 THEN NULL ELSE next_delivery_at END
        WHERE state IN ('pending','consumed') AND acknowledged_at IS NULL""",
        [
          reset ? 1 : 0,
          options.repeat ? nowMs + options.interval * 1000 : null,
          options.repeat ? 1 : 0,
        ],
      );
    });
  });

  Future<bool> acknowledge(int id, int sessionId, {int? revision}) => _write(
    () => db.transaction((txn) async {
      final rows = await _active(txn, id: id);
      if (rows.isEmpty) return false;
      final event = rows.single;
      if (event.sessionId != sessionId ||
          !event.awaitingConfirmation ||
          (revision != null && event.revision != revision)) {
        return false;
      }
      await txn.update(
        'rest_alerts',
        {
          'acknowledged_at': nowMs,
          'next_delivery_at': null,
          'revision': event.revision + 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return true;
    }),
  );

  Future<List<RestAlertEvent>> _active(
    DatabaseExecutor executor, {
    int? id,
  }) async {
    final rows = await executor.rawQuery(
      """SELECT a.*, e.name_snapshot, e.target_sets FROM rest_alerts a
      JOIN workout_sessions s ON s.id = a.session_id
      JOIN session_exercises e ON e.id = a.exercise_id AND e.session_id = s.id
      JOIN rest_alert_preferences p ON p.id = 1
      WHERE a.state IN ('pending','consumed') AND a.acknowledged_at IS NULL
        AND p.enabled = 1 AND s.status = 'in_progress' AND s.current_rest_alert_id = a.id
        AND s.current_session_exercise_id = a.exercise_id AND s.current_set_number = a.set_number
        ${id == null ? '' : 'AND a.id = ?'} ORDER BY a.id""",
      id == null ? [] : [id],
    );
    return rows.map(RestAlertEvent.new).toList();
  }

  Future<List<RestAlertEvent>> active() => _active(db);
  Future<List<RestAlertEvent>> awaiting() async =>
      (await active()).where((e) => e.awaitingConfirmation).toList();

  Future<void> markPermissionRequested() => _write(() async {
    await db.update('rest_alert_preferences', {
      'permission_requested': 1,
    }, where: 'id = 1');
  });

  Future<void> setEnabled(bool enabled) => _write(() async {
    await beforePreferencesWrite?.call();
    await db.transaction((txn) async {
      await txn.update('rest_alert_preferences', {
        'enabled': enabled ? 1 : 0,
      }, where: 'id = 1');
      if (!enabled) {
        await txn.rawUpdate("""UPDATE rest_alerts SET state = 'cancelled',
          revision = revision + 1 WHERE state IN ('pending', 'consumed')""");
      } else {
        final rows = await txn.query(
          'workout_sessions',
          where: "status = 'in_progress' AND rest_end_at > ?",
          whereArgs: [nowMs],
        );
        for (final s in rows) {
          await refresh(txn, s['id'] as int, revive: true);
        }
      }
    });
  });

  Future<void> restore({required bool expireElapsed}) => _write(() async {
    await db.transaction((txn) async {
      if (expireElapsed) {
        await txn.rawUpdate(
          """UPDATE rest_alerts SET state = 'expired',
          revision = revision + 1 WHERE state = 'pending' AND due_at <= ?""",
          [nowMs],
        );
        final options = RestAlertOptions.fromMap(
          (await txn.query('rest_alert_preferences')).single,
        );
        await txn.rawUpdate(
          """UPDATE rest_alerts SET next_delivery_at = ?
          WHERE state = 'consumed' AND acknowledged_at IS NULL AND next_delivery_at <= ?""",
          [options.repeat ? nowMs + options.interval * 1000 : null, nowMs],
        );
      }
      final prefs = (await txn.query('rest_alert_preferences')).single;
      if (prefs['enabled'] != 1) return;
      final rows = await txn.query(
        'workout_sessions',
        where: "status = 'in_progress' AND rest_end_at > ?",
        whereArgs: [nowMs],
      );
      for (final s in rows) {
        await refresh(txn, s['id'] as int);
      }
    });
  });

  Future<List<RestAlertEvent>> pending() => _write(() async {
    final rows = await db.rawQuery("""
      SELECT a.*, e.name_snapshot, e.target_sets FROM rest_alerts a
      JOIN workout_sessions s ON s.id = a.session_id
      JOIN session_exercises e ON e.id = a.exercise_id AND e.session_id = s.id
      JOIN rest_alert_preferences p ON p.id = 1
      WHERE a.state = 'pending' AND p.enabled = 1 AND s.status = 'in_progress'
        AND s.current_rest_alert_id = a.id
        AND s.current_session_exercise_id = a.exercise_id
        AND s.current_set_number = a.set_number
      ORDER BY a.id
    """);
    return rows.map(RestAlertEvent.new).toList();
  });

  Future<RestAlertEvent> setContent(
    RestAlertEvent event,
    String title,
    String body,
  ) => _write(() async {
    if (event.title == title && event.body == body) return event;
    return db.transaction((txn) async {
      await txn.rawUpdate(
        """UPDATE rest_alerts SET title = ?, body = ?,
        revision = revision + 1 WHERE id = ? AND revision = ? AND state IN ('pending','consumed') AND acknowledged_at IS NULL""",
        [title, body, event.id, event.revision],
      );
      final rows = await txn.query(
        'rest_alerts',
        where: 'id = ?',
        whereArgs: [event.id],
      );
      return RestAlertEvent(rows.single);
    });
  });

  /// Used by platform fakes and repository tests; Android implements the same
  /// conditional claim without starting a Flutter engine in the background.
  Future<RestAlertEvent?> consume(int id, int revision, {int sequence = 0}) =>
      _write(() async {
        return db.transaction((txn) async {
          final rows = await txn.rawQuery(
            """
        SELECT a.* FROM rest_alerts a JOIN workout_sessions s ON s.id = a.session_id
        JOIN rest_alert_preferences p ON p.id = 1
        WHERE a.id = ? AND a.revision = ? AND a.state IN ('pending','consumed')
          AND a.acknowledged_at IS NULL AND a.delivery_sequence = ? AND p.enabled = 1
          AND s.status = 'in_progress' AND s.current_rest_alert_id = a.id
          AND s.current_session_exercise_id = a.exercise_id AND s.current_set_number = a.set_number
      """,
            [id, revision, sequence],
          );
          if (rows.isEmpty) return null;
          final e = RestAlertEvent(rows.single);
          final at = e.deliveryAt;
          if (at == null || nowMs < at) return null;
          if (!e.awaitingConfirmation && nowMs > e.dueAt + 30000) {
            await txn.update(
              'rest_alerts',
              {'state': 'expired'},
              where: 'id = ?',
              whereArgs: [id],
            );
            return null;
          }
          final options = RestAlertOptions.fromMap(
            (await txn.query('rest_alert_preferences')).single,
          );
          final updated = await txn.update(
            'rest_alerts',
            {
              'state': 'consumed',
              'consumed_at': e.row['consumed_at'] ?? nowMs,
              'delivery_sequence': sequence + 1,
              'next_delivery_at': options.repeat
                  ? nowMs + options.interval * 1000
                  : null,
            },
            where: 'id = ? AND revision = ? AND delivery_sequence = ? AND acknowledged_at IS NULL',
            whereArgs: [id, revision, sequence],
          );
          return updated == 1
              ? RestAlertEvent(
                  (await txn.query(
                    'rest_alerts',
                    where: 'id = ?',
                    whereArgs: [id],
                  )).single,
                )
              : null;
        });
      });
}
