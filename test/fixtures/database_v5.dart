// Frozen pre-ordering v5 schema for upgrade compatibility tests.
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LegacyAppDatabaseV5 {
  LegacyAppDatabaseV5._(this.db);

  final Database db;

  static Future<LegacyAppDatabaseV5> open({
    String? filePath,
    DatabaseFactory? factory,
  }) async {
    final databaseFactory = factory ?? databaseFactoryDefault;
    final path = filePath ?? p.join(await getDatabasesPath(), 'settrace.db');
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createV1(db, 1);
          await _upgrade(db, 1, version);
        },
        onUpgrade: _upgrade,
      ),
    );
    return LegacyAppDatabaseV5._(db);
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
    if (oldVersion < 3 && newVersion >= 3) {
      await db.execute('''
        CREATE TABLE session_skip_batches (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
          session_exercise_id INTEGER NOT NULL REFERENCES session_exercises(id) ON DELETE CASCADE,
          created_at INTEGER NOT NULL,
          undone_at INTEGER
        )
      ''');
      await db.execute(
        'ALTER TABLE session_sets ADD COLUMN skipped_at INTEGER',
      );
      await db.execute(
        '''ALTER TABLE session_sets ADD COLUMN skip_batch_id INTEGER
        REFERENCES session_skip_batches(id)''',
      );
      for (final operation in ['INSERT', 'UPDATE']) {
        await db.execute('''
          CREATE TRIGGER sets_state_${operation.toLowerCase()}
          BEFORE $operation ON session_sets
          WHEN (NEW.completed_at IS NOT NULL AND NEW.skipped_at IS NOT NULL)
            OR ((NEW.skipped_at IS NULL) != (NEW.skip_batch_id IS NULL))
            OR (NEW.skip_batch_id IS NOT NULL AND NOT EXISTS (
              SELECT 1 FROM session_skip_batches b JOIN session_exercises e
                ON e.id = b.session_exercise_id
              WHERE b.id = NEW.skip_batch_id AND b.undone_at IS NULL
                AND b.session_exercise_id = NEW.session_exercise_id
                AND b.session_id = e.session_id))
          BEGIN SELECT RAISE(ABORT, 'invalid_set_state'); END
        ''');
      }
      await db.execute('''
        CREATE TRIGGER skip_batch_owner BEFORE INSERT ON session_skip_batches
        WHEN NOT EXISTS (SELECT 1 FROM session_exercises
          WHERE id = NEW.session_exercise_id AND session_id = NEW.session_id)
        BEGIN SELECT RAISE(ABORT, 'invalid_skip_owner'); END
      ''');
      await db.execute('''
        CREATE TABLE rest_alert_preferences (
          id INTEGER PRIMARY KEY CHECK(id = 1),
          enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0, 1)),
          permission_requested INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.insert('rest_alert_preferences', {'id': 1});
      await db.execute('''
        CREATE TABLE rest_alerts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
          exercise_id INTEGER NOT NULL REFERENCES session_exercises(id) ON DELETE CASCADE,
          set_number INTEGER NOT NULL,
          revision INTEGER NOT NULL DEFAULT 1,
          due_at INTEGER NOT NULL,
          state TEXT NOT NULL CHECK(state IN ('pending', 'consumed', 'cancelled', 'expired')),
          title TEXT NOT NULL DEFAULT '',
          body TEXT NOT NULL DEFAULT '',
          consumed_at INTEGER
        )
      ''');
      await db.execute(
        'CREATE INDEX alerts_by_session ON rest_alerts(session_id, state)',
      );
      await db.execute(
        'ALTER TABLE workout_sessions ADD COLUMN current_rest_alert_id INTEGER',
      );
    }
    if (oldVersion < 4 && newVersion >= 4) {
      await db.execute(
        "ALTER TABLE rest_alert_preferences ADD COLUMN sound_id TEXT NOT NULL DEFAULT 'three_tone' CHECK(sound_id IN ('three_tone','double_beep','voice'))",
      );
      await db.execute(
        'ALTER TABLE rest_alert_preferences ADD COLUMN vibration_enabled INTEGER NOT NULL DEFAULT 1 CHECK(vibration_enabled IN (0,1))',
      );
      await db.execute(
        'ALTER TABLE rest_alert_preferences ADD COLUMN repeat_enabled INTEGER NOT NULL DEFAULT 1 CHECK(repeat_enabled IN (0,1))',
      );
      await db.execute(
        'ALTER TABLE rest_alert_preferences ADD COLUMN interval_seconds INTEGER NOT NULL DEFAULT 10 CHECK(interval_seconds IN (10,15,30,60))',
      );
      await db.execute(
        'ALTER TABLE rest_alerts ADD COLUMN acknowledged_at INTEGER',
      );
      await db.execute(
        'ALTER TABLE rest_alerts ADD COLUMN delivery_sequence INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE rest_alerts ADD COLUMN next_delivery_at INTEGER',
      );
      // v3 consumption is terminal; upgrading must never create an old repeat chain.
      await db.execute(
        "UPDATE rest_alerts SET acknowledged_at = COALESCE(consumed_at, due_at) WHERE state = 'consumed'",
      );
    }
    if (oldVersion < 5 && newVersion >= 5) {
      await db.execute('''
        CREATE TABLE backup_operations (
          id TEXT PRIMARY KEY NOT NULL,
          kind TEXT NOT NULL CHECK(kind IN ('export','restore','undo')),
          phase TEXT NOT NULL CHECK(phase IN ('preparing','protected',
            'core_committed','settings_pending','completed','settings_skipped',
            'aborted','indeterminate','export_pending','export_published')),
          source_digest TEXT NOT NULL,
          target_digest TEXT NOT NULL,
          candidate_digest TEXT,
          before_copy_id TEXT,
          restore_settings INTEGER NOT NULL CHECK(restore_settings IN (0,1)),
          settings_target TEXT,
          settings_results TEXT NOT NULL DEFAULT '{}',
          source_epoch INTEGER NOT NULL,
          target_epoch INTEGER,
          undo_of TEXT,
          undone_by TEXT,
          export_target TEXT,
          export_result TEXT,
          error_code TEXT,
          result_seen INTEGER NOT NULL DEFAULT 0 CHECK(result_seen IN (0,1)),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE backup_copies (
          id TEXT PRIMARY KEY NOT NULL,
          operation_id TEXT,
          snapshot_at TEXT NOT NULL,
          relative_path TEXT NOT NULL UNIQUE,
          digest TEXT NOT NULL,
          schema_version INTEGER NOT NULL,
          plan_count INTEGER NOT NULL,
          workout_count INTEGER NOT NULL,
          byte_count INTEGER NOT NULL,
          state TEXT NOT NULL CHECK(state IN ('ready','deleting','missing')),
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE backup_state (
          id INTEGER PRIMARY KEY CHECK(id=1),
          epoch INTEGER NOT NULL DEFAULT 0,
          last_export_operation_id TEXT,
          last_export_digest TEXT,
          last_export_at INTEGER,
          last_export_result TEXT,
          undo_operation_id TEXT
        )
      ''');
      await db.insert('backup_state', {'id': 1});
      await db.execute(
        'CREATE INDEX backup_operations_by_phase ON backup_operations(phase, created_at)',
      );
    }
    if (newVersion != 5) {
      throw StateError(
        'No migration from database v$oldVersion to v$newVersion',
      );
    }
  }

  Future<void> close() => db.close();
}
