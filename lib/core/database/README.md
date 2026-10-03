# Local database v2

SetTrace keeps plans, plan exercises, workout sessions, session exercises and
session sets in SQLite. Session exercises and sets remain independent snapshots:
editing or deleting the source plan never changes a session's data.

All timestamps are UTC milliseconds since epoch. Rest configuration and saved
workout duration are integer seconds. Training dates use the device's local
calendar at session start. A null completed_at means an unfinished set.

## Identity, ordering and completion

workout_sessions.current_session_exercise_id refers to the stable ID of an
exercise belonging to that session. The repository validates ownership in each
write transaction. current_exercise_order remains a synchronized display
projection; it is not used as the identity of the current exercise.

session_exercises.sort_order is a contiguous, one-based session order. Only
exercises with zero completed sets can change places; other slots are locked.
Reordering temporarily uses negative orders inside a transaction to preserve the
unique (session_id, sort_order) constraint. No intermediate order is committed.

session_sets.completed_sequence is an internal completion order per session.
Completing a set allocates max(sequence) + 1 in the same transaction. Undo uses
this order, even when completed_at values tie, and clears both fields. It is
not an exercise timer or a user-facing workout metric.

## v1 migration and rollback

New databases and upgraded databases have the same v2 structure. Upgrade adds
the two nullable integer columns without deleting or recreating tables.
The v1 cursor is checked against the first unfinished group in its fixed order.
Valid cursors retain their rest deadline; inconsistent ones follow the existing
cursor repair rules. Completed sessions keep their recorded data. Completion
sequences are backfilled by completed_at then set ID within each session,
preserving the v1 tie-breaking rule. Old timestamps and workout durations do
not change. A failed upgrade rolls back rather than discarding user data.

A v1 application does not support opening a v2 database. A rollback release
must retain v2 support and may disable reordering; do not restore a stale
database over newer workouts or ask the user to uninstall the app.

## Plan import and export

SQLite remains the only live plan store. Export reads selected plans and their
ordered exercises in one transaction and creates a temporary JSON snapshot.
Import validates all plans before a single write transaction. New IDs and current
creation timestamps are allocated locally; exercise order is one-based.
Name collisions return an updated preview before any inserts. Any insert failure
rolls back the whole batch. Existing plans, session snapshots, rest deadlines and
history are untouched. The database version and tables do not change.
See docs/plan-transfer-format.md for the portable format and its limits.
