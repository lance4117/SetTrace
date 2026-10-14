# Local database v3

SetTrace keeps plans, plan exercises, workout sessions, session exercises and
session sets in SQLite. Session exercises and sets remain independent snapshots:
editing or deleting the source plan never changes a session's data.

All timestamps are UTC milliseconds since epoch. Rest configuration and saved
workout duration are integer seconds. Training dates use the device's local
calendar at session start. A set is pending only when both completed_at and skipped_at are null.

## Identity, ordering and completion

workout_sessions.current_session_exercise_id refers to the stable ID of an
exercise belonging to that session. The repository validates ownership in each
write transaction. current_exercise_order remains a synchronized display
projection; it is not used as the identity of the current exercise.

session_exercises.sort_order is a contiguous, one-based session order. Only
exercises with zero completed and zero skipped sets can change places; other slots are locked.
Reordering temporarily uses negative orders inside a transaction to preserve the
unique (session_id, sort_order) constraint. No intermediate order is committed.

session_sets.completed_sequence is an internal completion order per session.
Completing a set allocates max(sequence) + 1 in the same transaction. Undo uses
this order, even when completed_at values tie, and clears both fields. It is
not an exercise timer or a user-facing workout metric.

## v1 migration and rollback

New databases and upgraded databases have the same v3 structure. Upgrade adds
the two nullable integer columns without deleting or recreating tables.
The v1 cursor is checked against the first unfinished group in its fixed order.
Valid cursors retain their rest deadline; inconsistent ones follow the existing
cursor repair rules. Completed sessions keep their recorded data. Completion
sequences are backfilled by completed_at then set ID within each session,
preserving the v1 tie-breaking rule. Old timestamps and workout durations do
not change. A failed upgrade rolls back rather than discarding user data.

A v1/v2 application does not support opening a v3 database. A rollback release
must retain v3 support and may disable reordering; do not restore a stale
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


## Deleting saved history

`WorkoutRepository.deleteHistory(id)` accepts only an existing `completed`
session (including an early-saved partial workout). Validation and deletion run
in one transaction; missing or active targets are rejected without writes.
Deleting the session cascades through `session_exercises` and `session_sets`,
including unfinished sets. A cascade error rolls back the entire transaction.
Source plans, plan exercises, other history, and the active session are untouched.
No schema change or migration is required. The history UI recalculates existing
statistics from the remaining sessions; no separate accumulated total is stored.
## v3 skipped sets and rest alerts

session_sets.skipped_at and skip_batch_id describe explicit skipping. They never
fill completed_at/completed_sequence or reduce target_sets. Triggers reject a
completed-and-skipped set and a batch belonging to a different exercise/session.
session_skip_batches stores ordered, reversible skip batches with created_at and
undone_at. Undo completion changes only actual completion; undo skip changes only
its batch. Batch/set rows cascade when the owning session is deleted.

readyToFinish means no pending sets remain; allSetsCompleted still means every
target set was actually done. History shows actual/target, and aggregate statistics
count only completed_at. Sets left pending by early save are not relabeled skipped.

v2→v3 adds nullable skip columns and the skip/alert tables without recreating plans,
snapshots, sets or sessions. v1→v3 first applies the existing v2 identity/sequence
migration. Tests compare old row values and foreign keys and cover failed v1 and v2
upgrades. Old unfinished sets keep null skip fields.

rest_alerts is a durable scheduling/consumption record, identified by its ID and
revision. workout_sessions.current_rest_alert_id identifies the current logical
rest even after natural expiry clears rest_end_at. Natural normalization leaves
the event eligible; explicit cancellation invalidates it. Android conditionally
claims pending events before output and never changes workout/set records.
rest_alert_preferences is a singleton SQLite setting (enabled, permission_requested)
shared by Dart and the native receiver. Theme/language still use shared_preferences.

Rest timestamps and alert due_at/consumed_at are UTC epoch milliseconds. Scheduled
Android intents are projections: an old revision cannot sound after cancellation,
even if cancelling the operating-system alarm failed. See docs/rest-alerts.md.

Rollback builds must read v3 and preserve skipped-group semantics. Disabling new
buttons alone must not make skipped groups pending again. Do not reinstall a v2
binary over v3 data, reset the database or uninstall to roll back.
