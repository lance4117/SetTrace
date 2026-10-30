package com.settrace.settrace

import android.app.NotificationManager
import android.content.Context
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteDatabaseLockedException
import java.io.File

internal data class RestAlertSettings(val sound: String, val vibration: Boolean, val repeat: Boolean, val interval: Int)
internal data class RestDelivery(val id: Int, val sessionId: Int, val title: String, val body: String,
    val revision: Int, val sequence: Int, val nextAt: Long?, val settings: RestAlertSettings,
    val diagnosticEpoch: Long? = null, val diagnosticDue: Long? = null) {
    fun payload() = mapOf("id" to id, "session_id" to sessionId, "revision" to revision,
        "sequence" to sequence, "body" to body)
}
internal data class RestClaimFacts(val exists: Boolean = true, val revisionMatches: Boolean = true,
    val roundMatches: Boolean = true, val acknowledged: Boolean = false, val enabled: Boolean = true,
    val sessionValid: Boolean = true, val positionMatches: Boolean = true, val expired: Boolean = false)
internal object RestClaimReason {
    fun rejected(facts: RestClaimFacts): String = when {
        !facts.exists -> "not_found"
        !facts.revisionMatches -> "old_revision"
        facts.acknowledged -> "already_acknowledged"
        !facts.enabled -> "user_disabled"
        !facts.sessionValid -> "invalid_session"
        !facts.positionMatches -> "condition_mismatch"
        !facts.roundMatches -> "old_round"
        facts.expired -> "expired"
        else -> "condition_mismatch"
    }
}
internal data class RestClaimObservation(val reason: String, val claimed: Boolean, val epoch: Long?, val due: Long?, val now: Long, val transition: Boolean = false)
internal class RestStoreUnavailable(val reason: String) : IllegalStateException(reason)
internal data class RestScheduleToken(val id: Int, val revision: Int, val sequence: Int,
    val at: Long, val epoch: Long?, val sessionId: Int)
internal object RestDeliveryPolicy {
    fun withinWindow(now: Long, due: Long) = now >= due && now <= due + 30_000
    fun soundAllowed(normalRinger: Boolean, volume: Int, interruptionsAllowed: Boolean,
                     channelHasSound: Boolean, channelImportance: Int) =
        normalRinger && volume > 0 && interruptionsAllowed && channelHasSound &&
            channelImportance >= NotificationManager.IMPORTANCE_DEFAULT
}

internal object BackupDatabasePolicy {
    fun supported(version: Int) = version == 4 || version == 5 || version == 6
    fun blocksOutput(kind: String, phase: String) = kind in setOf("restore", "undo") &&
        phase in setOf("preparing", "protected", "indeterminate")
}

/** Shared v4/v5/v6 contract; native receivers never migrate or modify workout records. */
internal object RestAlertsStore {
    fun epoch(db: SQLiteDatabase): Long? = if (db.version < 5) null else
        db.rawQuery("SELECT epoch FROM backup_state WHERE id=1", null).use { if (it.moveToFirst()) it.getLong(0) else null }

    fun trainingValid(db: SQLiteDatabase, session: Int): Boolean = !backupPending(db) && db.rawQuery(
        "SELECT s.id FROM workout_sessions s JOIN rest_alert_preferences p ON p.id=1 WHERE s.id=? AND s.status='in_progress' AND p.enabled=1",
        arrayOf(session.toString())).use { it.moveToFirst() }

    fun activeIds(db: SQLiteDatabase): Set<String> = db.rawQuery("""SELECT a.id
        FROM rest_alerts a JOIN workout_sessions s ON s.id=a.session_id AND s.current_rest_alert_id=a.id
        JOIN session_exercises e ON e.id=a.exercise_id AND e.session_id=s.id
        JOIN rest_alert_preferences p ON p.id=1
        WHERE s.status='in_progress' AND p.enabled=1 AND a.acknowledged_at IS NULL
        AND a.state IN ('pending','consumed') AND s.current_session_exercise_id=a.exercise_id
        AND s.current_set_number=a.set_number""",null).use { row ->
        buildSet { while(row.moveToNext()) add(row.getInt(0).toString()) }
    }

    fun current(db: SQLiteDatabase, id: Int? = null): RestScheduleToken? {
        if (backupPending(db)) return null
        return db.rawQuery("""SELECT a.id,a.revision,a.delivery_sequence,
            CASE WHEN a.state='pending' THEN a.due_at ELSE a.next_delivery_at END,a.session_id
            FROM rest_alerts a JOIN workout_sessions s ON s.id=a.session_id
            JOIN session_exercises e ON e.id=a.exercise_id AND e.session_id=s.id
            JOIN rest_alert_preferences p ON p.id=1
            WHERE s.status='in_progress' AND p.enabled=1 AND s.current_rest_alert_id=a.id
            AND s.current_session_exercise_id=a.exercise_id AND s.current_set_number=a.set_number
            AND a.acknowledged_at IS NULL AND (a.state='pending' OR
                (a.state='consumed' AND p.repeat_enabled=1 AND a.next_delivery_at IS NOT NULL))
            ${if (id == null) "" else "AND a.id=?"} LIMIT 1""",
            id?.let { arrayOf(it.toString()) }).use { row ->
            if (!row.moveToFirst()) null else RestScheduleToken(row.getInt(0),row.getInt(1),row.getInt(2),row.getLong(3),epoch(db),row.getInt(4))
        }
    }
    fun <T> withDatabase(context: Context, deadlineElapsed: Long? = null, action: (SQLiteDatabase) -> T): T {
        fun checkBudget() {
            if (deadlineElapsed != null && android.os.SystemClock.elapsedRealtime() >= deadlineElapsed)
                throw RestStoreUnavailable("timeout")
        }
        checkBudget()
        val path = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
            .getString("database_path", null) ?: error("notInitialized")
        val root = File(context.applicationInfo.dataDir).canonicalPath + File.separator
        require(File(path).canonicalPath.startsWith(root)) { "invalidDatabasePath" }
        check(File(path).exists()) { "databaseMissing" }
        repeat(3) { attempt ->
            checkBudget()
            try {
                SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                    if (deadlineElapsed != null) {
                        val remaining = (deadlineElapsed - android.os.SystemClock.elapsedRealtime()).coerceIn(1L, 5000L)
                        db.rawQuery("PRAGMA busy_timeout=$remaining", null).use { it.moveToFirst() }
                    }
                    check(BackupDatabasePolicy.supported(db.version)) { "unsupportedDatabase" }
                    if (backupPending(db)) throw RestStoreUnavailable("restore_guard")
                    checkBudget()
                    return action(db)
                }
            } catch (error: SQLiteDatabaseLockedException) {
                checkBudget()
                if (attempt == 2) throw error
                Thread.sleep(25L * (attempt + 1))
            }
        }
        error("databaseBusy")
    }
    private fun backupPending(db: SQLiteDatabase): Boolean {
        if (db.version == 4) return false
        check(db.version == 5 || db.version == 6) { "unsupportedDatabase" }
        return db.rawQuery("""SELECT kind,phase FROM backup_operations
            WHERE kind IN ('restore','undo')
            AND phase IN ('preparing','protected','indeterminate') LIMIT 1""", null).use {
            it.moveToFirst() && BackupDatabasePolicy.blocksOutput(it.getString(0), it.getString(1))
        }
    }
    fun settings(db: SQLiteDatabase): RestAlertSettings = db.rawQuery(
        "SELECT sound_id,vibration_enabled,repeat_enabled,interval_seconds FROM rest_alert_preferences WHERE id=1", null).use {
        check(it.moveToFirst()) { "preferencesMissing" }
        RestAlertSettings(it.getString(0), it.getInt(1) == 1, it.getInt(2) == 1, it.getInt(3))
    }
    private const val VALID = """
        FROM rest_alerts a JOIN workout_sessions s ON s.id=a.session_id
        JOIN session_exercises e ON e.id=a.exercise_id AND e.session_id=s.id
        JOIN rest_alert_preferences p ON p.id=1
        WHERE a.id=? AND a.revision=? AND a.acknowledged_at IS NULL AND p.enabled=1
          AND s.status='in_progress' AND s.current_rest_alert_id=a.id
          AND s.current_session_exercise_id=a.exercise_id AND s.current_set_number=a.set_number
    """
    fun valid(db: SQLiteDatabase, event: RestDelivery): Boolean = !backupPending(db) &&
        (event.diagnosticEpoch == null || epoch(db) == event.diagnosticEpoch) && db.rawQuery(
        "SELECT a.id $VALID AND a.state='consumed' AND a.delivery_sequence=?",
        arrayOf(event.id.toString(), event.revision.toString(), event.sequence.toString())).use { it.moveToFirst() }

    fun projection(db: SQLiteDatabase, id: Int, revision: Int): RestDelivery? = if (backupPending(db)) null else db.rawQuery(
        "SELECT a.session_id,a.title,a.body,a.delivery_sequence,a.next_delivery_at $VALID AND a.state='consumed'",
        arrayOf(id.toString(), revision.toString())).use { row ->
        if (!row.moveToFirst()) null else RestDelivery(id,row.getInt(0),row.getString(1),row.getString(2),
            revision,row.getInt(3),if (row.isNull(4)) null else row.getLong(4),settings(db))
    }

    private fun rejection(db: SQLiteDatabase, id: Int, revision: Int, sequence: Int): String = try {
        db.rawQuery("""SELECT a.revision,a.delivery_sequence,a.acknowledged_at,p.enabled,s.status,
            s.current_rest_alert_id=a.id AND s.current_session_exercise_id=a.exercise_id AND s.current_set_number=a.set_number,
            a.state FROM rest_alerts a LEFT JOIN workout_sessions s ON s.id=a.session_id
            LEFT JOIN rest_alert_preferences p ON p.id=1 WHERE a.id=?""", arrayOf(id.toString())).use { row ->
            if (!row.moveToFirst()) "not_found" else RestClaimReason.rejected(RestClaimFacts(
                revisionMatches = row.getInt(0) == revision, roundMatches = row.getInt(1) == sequence,
                acknowledged = !row.isNull(2), enabled = !row.isNull(3) && row.getInt(3) == 1,
                sessionValid = row.getString(4) == "in_progress", positionMatches = !row.isNull(5) && row.getInt(5) == 1,
                expired = row.getString(6) == "expired"))
        }
    } catch (_: Exception) { "unknown" }

    fun claim(db: SQLiteDatabase, id: Int, revision: Int, now: Long, sequence: Int = 0,
              expectedEpoch: Long? = null,
              observer: (RestClaimObservation) -> Unit = {}): RestDelivery? {
        var reason = "unknown"
        var due: Long? = null
        var epoch: Long? = null
        var claimed = false
        var successful = false
        var transition = false
        db.beginTransaction()
        try {
            epoch = try { db.rawQuery("SELECT epoch FROM backup_state WHERE id=1", null).use { if (it.moveToFirst()) it.getLong(0) else null } } catch (_: Exception) { null }
            if (backupPending(db)) { reason = "restore_guard"; return null }
            if (expectedEpoch != null && epoch != expectedEpoch) { reason = "condition_mismatch"; return null }
            val settings = settings(db)
            val event = db.rawQuery("""SELECT a.session_id,a.due_at,a.title,a.body,a.state,
                a.next_delivery_at,a.consumed_at $VALID
                AND a.state IN ('pending','consumed') AND a.delivery_sequence=?""",
                arrayOf(id.toString(), revision.toString(), sequence.toString())).use { row ->
                if (!row.moveToFirst()) { reason = rejection(db, id, revision, sequence); return@use null }
                val first = row.getString(4) == "pending"
                if (!first && (!settings.repeat || row.isNull(5))) { reason = "condition_mismatch"; return@use null }
                val at = if (first) row.getLong(1) else row.getLong(5)
                due = at
                if (now < at) { reason = "condition_mismatch"; return@use null }
                if ((first && !RestDeliveryPolicy.withinWindow(now, at)) || row.getString(2).isBlank()) {
                    reason = if (first && !RestDeliveryPolicy.withinWindow(now, at)) "expired" else "condition_mismatch"
                    db.execSQL("UPDATE rest_alerts SET state='expired', next_delivery_at=NULL WHERE id=?", arrayOf(id))
                    transition = first
                    return@use null
                }
                val next = if (settings.repeat) now + settings.interval * 1000L else null
                val values = ContentValues().apply {
                    put("state", "consumed"); put("consumed_at", if (row.isNull(6)) now else row.getLong(6))
                    put("delivery_sequence", sequence + 1)
                    if (next == null) putNull("next_delivery_at") else put("next_delivery_at", next)
                }
                val changed = db.update("rest_alerts", values,
                    "id=? AND revision=? AND delivery_sequence=? AND acknowledged_at IS NULL",
                    arrayOf(id.toString(), revision.toString(), sequence.toString()))
                claimed = changed == 1
                reason = if (claimed) "none" else "claim_lost"
                if (!claimed) null else RestDelivery(id, row.getInt(0), row.getString(2), row.getString(3),
                    revision, sequence + 1, next, settings, epoch, at)
            }
            db.setTransactionSuccessful()
            successful = true
            return event
        } finally {
            // An endTransaction exception skips the observer: no false commit.
            db.endTransaction()
            try { observer(RestClaimObservation(reason, claimed && successful, epoch, due, now, transition && successful)) } catch (_: Exception) {}
        }
    }
}
