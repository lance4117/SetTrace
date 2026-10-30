package com.settrace.settrace

import android.Manifest
import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager

/** Read-only: never creates a channel, service, alarm or permission request. */
internal object RestDeliveryStatusReader {
    fun read(context: Context): Map<String, Any?> {
        val captured = System.currentTimeMillis()
        val fields = linkedMapOf<String, Any?>()
        fun field(name: String, availability: String = "available", reason: String? = null, read: () -> Any?) {
            fields[name] = try { mapOf("availability" to availability,
                "value" to read(), "observedUtc" to captured, "reason" to reason) }
            catch (_: Exception) { mapOf("availability" to "read_failed", "value" to null,
                "observedUtc" to captured, "reason" to "read_failed") }
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        val power = context.getSystemService(PowerManager::class.java)
        val prefs = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
        field("appNotifications") { manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) }
        fun channel(name: String, id: String?) {
            try {
            if (Build.VERSION.SDK_INT < 26) field(name, "unsupported", "unsupported") { null }
            else if (id == null || manager.getNotificationChannel(id) == null) field(name, "unknown", "missing") { null }
            else field(name) { manager.getNotificationChannel(id)?.importance?.let { it > 0 } }
            } catch (_: Exception) { field(name, "read_failed", "read_failed") { null } }
        }
        channel("restChannel", prefs.getString("current_channel", null))
        channel("serviceChannel", TrainingReminderService.CHANNEL)
        field("exactAlarm") { RestAlertsRuntime.exactAllowed(context) }
        field("batteryOptimizationExempt") { power.isIgnoringBatteryOptimizations(context.packageName) }
        field("powerSave") { power.isPowerSaveMode }
        field("deviceIdle") { power.isDeviceIdleMode }
        if (Build.VERSION.SDK_INT >= 28) field("backgroundRestricted") {
            context.getSystemService(ActivityManager::class.java).isBackgroundRestricted
        } else field("backgroundRestricted", "unsupported", "unsupported") { null }
        field("vendorAutostart", "unknown", "unsupported") { null }
        field("vendorBatteryPolicy", "unknown", "unsupported") { null }
        field("service") { TrainingReminderService.snapshot() }
        field("alarmArmed", "unknown", "not_available") { null }
        field("currentReminder") {
            RestAlertsStore.withDatabase(context) { db ->
                val epoch = RestAlertsStore.epoch(db)
                db.rawQuery("""SELECT a.id,a.revision,a.delivery_sequence,a.due_at,a.next_delivery_at,a.state
                    FROM rest_alerts a JOIN workout_sessions s ON s.current_rest_alert_id=a.id AND s.id=a.session_id
                    JOIN rest_alert_preferences p ON p.id=1
                    WHERE s.status='in_progress' AND p.enabled=1 AND a.acknowledged_at IS NULL
                    AND a.state IN ('pending','consumed')
                    AND s.current_session_exercise_id=a.exercise_id AND s.current_set_number=a.set_number LIMIT 1""", null).use { row ->
                    if (!row.moveToFirst()) null else mapOf("datasetEpoch" to epoch, "id" to row.getInt(0),
                        "revision" to row.getInt(1), "sequence" to row.getInt(2), "dueUtc" to row.getLong(3),
                        "nextDueUtc" to if (row.isNull(4)) null else row.getLong(4), "state" to row.getString(5))
                }
            }
        }
        // Observations carry their own event token; consumers must not combine
        // historical requests for one event with another current reminder.
        field("lastScheduleAccepted") { RestAlertsRuntime.lastScheduleObservation }
        field("lastServiceScheduled") { RestAlertsRuntime.lastServiceScheduleObservation }
        field("lastRecovery") { RestAlertsRuntime.lastRecoveryObservation }
        field("lastClaim") { RestAlertsRuntime.lastClaimObservation }
        field("lastOutputRequest") { RestAlertsRuntime.lastOutputObservation }
        field("deliveryMode") {
            if (!RestAlertsRuntime.notificationsAllowed(context)) "foreground_only"
            else if (TrainingReminderService.state == "running" && TrainingReminderService.snapshot()["leaseExpired"] != true) "service_and_alarm" else "alarm_only"
        }
        return mapOf("version" to 1, "capturedUtc" to captured,
            "instance" to TrainingReminderService.runtimeInstance, "fields" to fields)
    }
}
