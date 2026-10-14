"""Build and inspect fixtures for an isolated Android QA emulator only.
Never run this against a personal/device database. The input is a local copy of
the independently created QA AVD's settrace.db; uploads happen while app is stopped.
"""
import argparse
import json
import sqlite3
import time

parser = argparse.ArgumentParser()
parser.add_argument("database")
parser.add_argument("operation", choices=["seed_v2", "inspect", "deadline"])
parser.add_argument("--seconds", type=int, default=30)
args = parser.parse_args()
db = sqlite3.connect(args.database)
db.row_factory = sqlite3.Row
db.execute("PRAGMA foreign_keys=ON")
if args.operation == "seed_v2":
    assert db.execute("PRAGMA user_version").fetchone()[0] == 2
    assert db.execute("SELECT COUNT(*) FROM workout_sessions").fetchone()[0] == 0
    now = int(time.time() * 1000)
    plan = db.execute("INSERT INTO plans(name,created_at,updated_at) VALUES(?,?,?)",
                      ("Rest QA Plan", now, now)).lastrowid
    plan_exercises = []
    for i, name in enumerate(["QA Press", "QA Row"], 1):
        plan_exercises.append(db.execute("""INSERT INTO plan_exercises
          (plan_id,name,sort_order,target_sets,rest_between_sets_seconds,rest_after_exercise_seconds)
          VALUES(?,?,?,4,30,30)""", (plan, name, i)).lastrowid)
    for saved in [True, False]:
        session = db.execute("""INSERT INTO workout_sessions
          (source_plan_id,plan_name_snapshot,started_at,started_local_date,status,
          current_exercise_order,current_set_number,ended_at,duration_seconds,rest_kind,rest_started_at,rest_end_at)
          VALUES(?,?,?,?,?,1,3,?,?,?, ?, ?)""",
          (plan, "Rest QA Plan", now-120000, time.strftime("%Y-%m-%d"),
           "completed" if saved else "in_progress", now if saved else None,
           120 if saved else None, None if saved else "between_sets",
           None if saved else now, None if saved else now+300000)).lastrowid
        for i, exercise in enumerate(plan_exercises, 1):
            action = db.execute("""INSERT INTO session_exercises
              (session_id,source_exercise_id,name_snapshot,sort_order,target_sets,
              rest_between_sets_seconds,rest_after_exercise_seconds)
              VALUES(?,?,?,?,4,30,30)""", (session, exercise, ["QA Press","QA Row"][i-1], i)).lastrowid
            for n in range(1, 5):
                done = i == 1 and n <= 2
                db.execute("""INSERT INTO session_sets
                  (session_exercise_id,set_number,completed_at,completed_sequence)
                  VALUES(?,?,?,?)""", (action, n, now-60000+n if done else None, n if done else None))
            if i == 1:
                db.execute("UPDATE workout_sessions SET current_session_exercise_id=? WHERE id=?",
                           (action, session))
    db.commit()
elif args.operation == "deadline":
    deadline = int(time.time()*1000) + args.seconds*1000
    current = db.execute("SELECT * FROM workout_sessions WHERE status='in_progress'").fetchone()
    assert current is not None and current["rest_end_at"] is not None
    db.execute("UPDATE workout_sessions SET rest_end_at=? WHERE id=?", (deadline, current["id"]))
    if db.execute("PRAGMA user_version").fetchone()[0] >= 3:
        db.execute("""UPDATE rest_alerts SET due_at=?, revision=revision+1,
          state='pending', consumed_at=NULL WHERE id=?""",
          (deadline, current["current_rest_alert_id"]))
    db.commit()
print(json.dumps({
    "version": db.execute("PRAGMA user_version").fetchone()[0],
    "plans": [dict(r) for r in db.execute("SELECT id,name FROM plans")],
    "sessions": [dict(r) for r in db.execute("SELECT * FROM workout_sessions")],
    "sets": [dict(r) for r in db.execute("SELECT * FROM session_sets ORDER BY id")],
}, ensure_ascii=False, indent=2))
db.close()

