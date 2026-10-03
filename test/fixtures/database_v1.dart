import 'package:sqflite/sqflite.dart';

Future<void> createLegacyV1(Database db, int version) async {
  await db.execute('''
      CREATE TABLE plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  await db.execute('''
      CREATE TABLE plan_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        target_sets INTEGER NOT NULL CHECK(target_sets >= 1),
        rest_between_sets_seconds INTEGER NOT NULL CHECK(rest_between_sets_seconds >= 0),
        rest_after_exercise_seconds INTEGER NOT NULL CHECK(rest_after_exercise_seconds >= 0),
        default_weight_kg REAL,
        UNIQUE(plan_id, sort_order)
      )
    ''');
  await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_plan_id INTEGER REFERENCES plans(id) ON DELETE SET NULL,
        plan_name_snapshot TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        started_local_date TEXT NOT NULL,
        ended_at INTEGER,
        duration_seconds INTEGER,
        status TEXT NOT NULL CHECK(status IN ('in_progress', 'completed')),
        current_exercise_order INTEGER NOT NULL,
        current_set_number INTEGER NOT NULL,
        rest_kind TEXT CHECK(rest_kind IN ('between_sets', 'between_exercises')),
        rest_started_at INTEGER,
        rest_end_at INTEGER
      )
    ''');
  await db.execute(
    "CREATE UNIQUE INDEX one_active_session ON workout_sessions(status) WHERE status = 'in_progress'",
  );
  await db.execute(
    'CREATE INDEX sessions_by_date ON workout_sessions(started_local_date, ended_at)',
  );
  await db.execute('''
      CREATE TABLE session_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
        source_exercise_id INTEGER REFERENCES plan_exercises(id) ON DELETE SET NULL,
        name_snapshot TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        target_sets INTEGER NOT NULL CHECK(target_sets >= 1),
        rest_between_sets_seconds INTEGER NOT NULL,
        rest_after_exercise_seconds INTEGER NOT NULL,
        default_weight_kg REAL,
        UNIQUE(session_id, sort_order)
      )
    ''');
  await db.execute('''
      CREATE TABLE session_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_exercise_id INTEGER NOT NULL REFERENCES session_exercises(id) ON DELETE CASCADE,
        set_number INTEGER NOT NULL CHECK(set_number >= 1),
        completed_at INTEGER,
        UNIQUE(session_exercise_id, set_number)
      )
    ''');
  await db.execute(
    'CREATE INDEX sets_by_exercise ON session_sets(session_exercise_id, set_number)',
  );
}
