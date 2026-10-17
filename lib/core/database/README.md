# Local database v6

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

New databases and upgraded databases have the same current structure. The v2 upgrade adds
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

## v4 rest reminder acknowledgment and rounds

The v4 migration only extends rest_alert_preferences and rest_alerts. Existing
workout, history, plan, snapshot and deadline values retain their meanings.
Preferences add sound_id (three_tone/double_beep/voice), vibration_enabled,
repeat_enabled and interval_seconds (10/15/30/60). Defaults are three_tone,
vibration on, repeat on, 10 seconds; the existing enabled preference is retained.

A pending event owns its first due_at. A consumed event with acknowledged_at NULL
is awaiting confirmation; delivery_sequence and next_delivery_at identify the
next round. consumed_at remains the first consumption time. Both Dart and Android
claim by id/revision/expected sequence in one transaction. Only the first claim
uses the due_at + 30 second expiry window; late repeat callbacks claim one round
and schedule from actual processing time. Confirmation and cancellation commit
before canceling system projections; stale callbacks cannot revive output.

Upgraded v3 consumed events receive acknowledged_at and never start repeating.
Cold restoration expires elapsed pending first deliveries; valid v4 awaiting
confirmations only resume a future round, without replaying missed intervals.
The Android reader accepts v4, v5 and v6 but never migrates the database. Tests live in
rest_alert_repeating_test.dart and database_migration_test.dart.

## v5 backup control metadata

v4→v5 only adds three tables and an index. Existing business rows, active
sessions, skipped sets, stored durations, valid alerts, and preferences are
unchanged. v1/v2/v3 first follow the existing sequential migrations. A failed
upgrade rolls back both DDL and data; opening never recreates an empty database.

`backup_operations` records id, kind (export/restore/undo), phase, source/target
semantic digests, candidate integrity digest, before_copy_id, restore_settings,
settings_target and settings_results JSON, source/target epoch, undo_of/undone_by,
export_target/export_result, error_code, result_seen, and created/updated times.
Phases are preparing, protected, core_committed, settings_pending, completed,
settings_skipped, aborted, indeterminate, export_pending, export_published.

`backup_copies` records id, operation_id, snapshot_at, trusted relative_path,
digest, schema_version, plan_count, workout_count, byte_count, state
(ready/deleting/missing), and created_at. It has no foreign keys to business
rows. `backup_state` is singleton id=1 with epoch, last_export_operation_id,
last_export_digest, last_export_at, last_export_result, and undo_operation_id.
These tables are control state, not part of exported user data, and must survive
business replacement. Public export bookkeeping is independent of copy exports.

`BackupMetadataRepository.commitCore` accepts the caller's SQLite Transaction:
business replacement, epoch increment, core_committed marker and undo linkage
must commit together. Tests inject failure after the marker and verify all
changes roll back. A duplicate commit fails the phase/epoch precondition.

The native reader accepts ONLY v4/v5/v6. In v5/v6, restore/undo operations in preparing,
protected or indeterminate block native reminder output/navigation. Claim checks
again inside its transaction. Settings-pending does not freeze later valid
training; committed dataset identity is established by the atomic marker.

A rollback/fix build must keep v6 support and preserve recovery files. Installing
a v4-only binary, clearing storage, or restoring a stale backup over later valid
records is not a rollback strategy. Existing archived reports describe their
historical versions and are intentionally unchanged.


## v6 persistent backup order

The v5→v6 migration adds plans.sort_order and workout_sessions.backup_order,
and backup_operations.target_summary for an interrupted result’s original
snapshot time and counts. The summary is not used to verify current data.
Plan order is initialized by the former created_at/id query; completed history
order is initialized by started_at/id. Existing timestamps, local dates, stored
durations, active sessions and backup control metadata remain unchanged. An
active session has no backup order until it is saved. INSERT and completion
triggers atomically append ordinary plans, plan imports and newly saved sessions.
Full restore explicitly assigns array positions, independent of timestamps.
History display and statistics continue using their original date rules.

Frozen v5 upgrade fixtures verify deterministic ties, every original field,
control metadata survival and rollback of a failed v6 DDL migration. Native
reminders explicitly support v4/v5/v6 and never perform schema migration.
Recovery builds must preserve the newest supported schema and recovery files.


The pinned Android shared_preferences_android 2.4.28 legacy API returns the
synchronous SharedPreferences.Editor.commit() result for these preference writes.
LiveBackupPreferences reads confirmed controllers, not an unconfirmed legacy
cache. Changes to the preferences backend must preserve this confirmation
contract and the read-after-restart settings-journal tests. Startup presents an
unseen verified outcome after the versioned notice, before notification navigation.
