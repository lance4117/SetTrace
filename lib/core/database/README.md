# Local database v1

SetTrace keeps its core data in one SQLite database (`settrace.db`). The five
tables are `plans`, `plan_exercises`, `workout_sessions`, `session_exercises`,
and `session_sets`. The session tables are snapshots: editing or deleting a
plan does not rewrite an ongoing or saved workout.

All timestamps are UTC milliseconds since epoch. `started_local_date` is a
`YYYY-MM-DD` key captured using the device's local calendar when a workout
starts. A workout crossing midnight belongs to its start date. Rest values and
saved workout duration use integer seconds; a plan's rest values are multiples
of 30 seconds. Weight, when present, is a default hint in kilograms and is not
recorded per set. A null `completed_at` means the set has not been completed.

Database upgrades belong in `AppDatabase._upgrade`; released user data must
not be handled by deleting and recreating the database. The partial unique
index on `workout_sessions` permits only one `in_progress` row.
