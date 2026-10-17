package com.settrace.settrace

import android.app.NotificationManager
import android.content.Context
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteDatabaseLockedException
import java.io.File

internal data class RestAlertSettings(val sound: String, val vibration: Boolean, val repeat: Boolean, val interval: Int)
internal data class RestDelivery(val id: Int, val sessionId: Int, val title: String, val body: String,
    val revision: Int, val sequence: Int, val nextAt: Long?, val settings: RestAlertSettings) {
    fun payload() = mapOf("id" to id, "session_id" to sessionId, "revision" to revision,
        "sequence" to sequence, "body" to body)
}
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
    fun <T> withDatabase(context: Context, action: (SQLiteDatabase) -> T): T {
        val path = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
            .getString("database_path", null) ?: error("notInitialized")
        val root = File(context.applicationInfo.dataDir).canonicalPath + File.separator
        require(File(path).canonicalPath.startsWith(root)) { "invalidDatabasePath" }
        check(File(path).exists()) { "databaseMissing" }
        repeat(3) { attempt ->
            try {
                SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                    check(BackupDatabasePolicy.supported(db.version)) { "unsupportedDatabase" }
                    check(!backupPending(db)) { "backupPending" }
                    return action(db)
                }
            } catch (error: SQLiteDatabaseLockedException) {
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
    fun valid(db: SQLiteDatabase, event: RestDelivery): Boolean = !backupPending(db) && db.rawQuery(
        "SELECT a.id $VALID AND a.state='consumed' AND a.delivery_sequence=?",
        arrayOf(event.id.toString(), event.revision.toString(), event.sequence.toString())).use { it.moveToFirst() }

    fun projection(db: SQLiteDatabase, id: Int, revision: Int): RestDelivery? = if (backupPending(db)) null else db.rawQuery(
        "SELECT a.session_id,a.title,a.body,a.delivery_sequence,a.next_delivery_at $VALID AND a.state='consumed'",
        arrayOf(id.toString(), revision.toString())).use { row ->
        if (!row.moveToFirst()) null else RestDelivery(id,row.getInt(0),row.getString(1),row.getString(2),
            revision,row.getInt(3),if (row.isNull(4)) null else row.getLong(4),settings(db))
    }

    fun claim(db: SQLiteDatabase, id: Int, revision: Int, now: Long, sequence: Int = 0): RestDelivery? {
        db.beginTransaction()
        try {
            if (backupPending(db)) return null
            val settings = settings(db)
            val event = db.rawQuery("""SELECT a.session_id,a.due_at,a.title,a.body,a.state,
                a.next_delivery_at,a.consumed_at $VALID
                AND a.state IN ('pending','consumed') AND a.delivery_sequence=?""",
                arrayOf(id.toString(), revision.toString(), sequence.toString())).use { row ->
                if (!row.moveToFirst()) return@use null
                val first = row.getString(4) == "pending"
                if (!first && (!settings.repeat || row.isNull(5))) return@use null
                val at = if (first) row.getLong(1) else row.getLong(5)
                if (now < at) return@use null
                if ((first && !RestDeliveryPolicy.withinWindow(now, at)) || row.getString(2).isBlank()) {
                    db.execSQL("UPDATE rest_alerts SET state='expired', next_delivery_at=NULL WHERE id=?", arrayOf(id))
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
                if (changed != 1) null else RestDelivery(id, row.getInt(0), row.getString(2), row.getString(3),
                    revision, sequence + 1, next, settings)
            }
            db.setTransactionSuccessful()
            return event
        } finally { db.endTransaction() }
    }
}
