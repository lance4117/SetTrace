import 'package:sqflite/sqflite.dart';

/// A single read-only statement: no recovery, write admission, names or values.
Future<Map<String, Object?>> diagnosticState(Database db) async {
  final rows = await db.rawQuery('''
    SELECT b.epoch AS dataset_epoch, s.id AS active_id, s.rest_end_at AS due_utc,
      (SELECT COALESCE(SUM(e.target_sets),0) FROM session_exercises e WHERE e.session_id=s.id) AS target_count,
      (SELECT COUNT(*) FROM session_sets ss JOIN session_exercises e ON e.id=ss.session_exercise_id
        WHERE e.session_id=s.id AND ss.completed_at IS NOT NULL) AS completed_count,
      (SELECT COUNT(*) FROM session_sets ss JOIN session_exercises e ON e.id=ss.session_exercise_id
        WHERE e.session_id=s.id AND ss.skipped_at IS NOT NULL) AS skipped_count
    FROM backup_state b LEFT JOIN workout_sessions s ON s.status='in_progress' WHERE b.id=1 LIMIT 1
  ''');
  if (rows.isEmpty) throw StateError('diagnosticStateUnavailable');
  final row = rows.single;
  return {
    'available': true,
    'captured_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
    'active': row['active_id'] != null,
    for (final field in [
      'dataset_epoch',
      'due_utc',
      'target_count',
      'completed_count',
      'skipped_count',
    ])
      if (row[field] is int && (row[field] as int) >= 0) field: row[field],
  };
}
