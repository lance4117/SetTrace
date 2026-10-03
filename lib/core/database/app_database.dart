import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open({
    String? filePath,
    DatabaseFactory? factory,
  }) async {
    final databaseFactory = factory ?? databaseFactoryDefault;
    final path = filePath ?? p.join(await getDatabasesPath(), 'settrace.db');
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createV1(db, 1);
          await _upgrade(db, 1, version);
        },
        onUpgrade: _upgrade,
      ),
    );
    return AppDatabase._(db);
  }

  static DatabaseFactory get databaseFactoryDefault => databaseFactory;

  static Future<void> _createV1(Database db, int version) async {
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

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute(
        'ALTER TABLE workout_sessions ADD COLUMN current_session_exercise_id INTEGER',
      );
      await db.execute(
        'ALTER TABLE session_sets ADD COLUMN completed_sequence INTEGER',
      );
      final sessions = await db.query('workout_sessions');
      for (final session in sessions) {
        final id = session['id'] as int;
        final exercises = await db.query(
          'session_exercises',
          where: 'session_id = ?',
          whereArgs: [id],
          orderBy: 'sort_order ASC',
        );
        if (exercises.isEmpty) continue;
        final mapped = exercises
            .where((e) => e['sort_order'] == session['current_exercise_order'])
            .firstOrNull;
        final pending = await db.rawQuery(
          '''
          SELECT se.id, se.sort_order, ss.set_number FROM session_sets ss
          JOIN session_exercises se ON se.id = ss.session_exercise_id
          WHERE se.session_id = ? AND ss.completed_at IS NULL
          ORDER BY se.sort_order, ss.set_number LIMIT 1
        ''',
          [id],
        );
        final values = <String, Object?>{
          'current_session_exercise_id': (mapped ?? exercises.last)['id'],
        };
        if (session['status'] == 'in_progress' && pending.isNotEmpty) {
          final next = pending.single;
          values.addAll({
            'current_session_exercise_id': next['id'],
            'current_exercise_order': next['sort_order'],
            'current_set_number': next['set_number'],
          });
          if (session['current_exercise_order'] != next['sort_order'] ||
              session['current_set_number'] != next['set_number']) {
            values.addAll({
              'rest_kind': null,
              'rest_started_at': null,
              'rest_end_at': null,
            });
          }
        }
        await db.update(
          'workout_sessions',
          values,
          where: 'id = ?',
          whereArgs: [id],
        );
        final completed = await db.rawQuery(
          '''
          SELECT ss.id FROM session_sets ss
          JOIN session_exercises se ON se.id = ss.session_exercise_id
          WHERE se.session_id = ? AND ss.completed_at IS NOT NULL
          ORDER BY ss.completed_at, ss.id
        ''',
          [id],
        );
        for (var i = 0; i < completed.length; i++) {
          await db.update(
            'session_sets',
            {'completed_sequence': i + 1},
            where: 'id = ?',
            whereArgs: [completed[i]['id']],
          );
        }
      }
    }
    if (newVersion != 2) {
      throw StateError(
        'No migration from database v$oldVersion to v$newVersion',
      );
    }
  }

  Future<void> close() => db.close();
}
