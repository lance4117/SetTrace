package com.settrace.settrace

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteDatabaseLockedException
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.*
import android.provider.Settings
import io.flutter.plugin.common.*
import java.io.File
import java.lang.ref.WeakReference
import java.util.concurrent.Executors
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

internal data class RestDelivery(val id: Int, val sessionId: Int, val title: String, val body: String)
internal object RestDeliveryPolicy {
    fun withinWindow(now: Long, due: Long) = now >= due && now <= due + 30_000
    fun soundAllowed(normalRinger: Boolean, volume: Int, interruptionsAllowed: Boolean,
                     channelHasSound: Boolean, channelImportance: Int) =
        normalRinger && volume > 0 && interruptionsAllowed && channelHasSound &&
            channelImportance >= NotificationManager.IMPORTANCE_DEFAULT
}

/** This reader never upgrades a database or changes workout/set records. */
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
                    check(db.version == 3) { "unsupportedDatabase" }
                    return action(db)
                }
            } catch (error: SQLiteDatabaseLockedException) {
                if (attempt == 2) throw error
                Thread.sleep(25L * (attempt + 1))
            }
        }
        error("databaseBusy")
    }

    fun claim(db: SQLiteDatabase, id: Int, revision: Int, now: Long): RestDelivery? {
        db.beginTransaction()
        try {
            db.rawQuery("""
                SELECT a.session_id, a.due_at, a.title, a.body FROM rest_alerts a
                JOIN workout_sessions s ON s.id = a.session_id
                JOIN session_exercises e ON e.id = a.exercise_id AND e.session_id = s.id
                JOIN rest_alert_preferences p ON p.id = 1
                WHERE a.id = ? AND a.revision = ? AND a.state = 'pending'
                  AND p.enabled = 1 AND s.status = 'in_progress'
                  AND s.current_rest_alert_id = a.id
                  AND s.current_session_exercise_id = a.exercise_id AND s.current_set_number = a.set_number
            """.trimIndent(), arrayOf(id.toString(), revision.toString())).use { row ->
                if (!row.moveToFirst()) { db.setTransactionSuccessful(); return null }
                val due = row.getLong(1)
                if (now < due) { db.setTransactionSuccessful(); return null }
                if (!RestDeliveryPolicy.withinWindow(now, due) || row.getString(2).isBlank()) {
                    db.execSQL("UPDATE rest_alerts SET state = 'expired' WHERE id = ?", arrayOf(id))
                    db.setTransactionSuccessful()
                    return null
                }
                val event = RestDelivery(id, row.getInt(0), row.getString(2), row.getString(3))
                val values = ContentValues().apply {
                    put("state", "consumed")
                    put("consumed_at", now)
                }
                val changed = db.update("rest_alerts", values,
                    "id = ? AND revision = ? AND state = 'pending'", arrayOf(id.toString(), revision.toString()))
                db.setTransactionSuccessful()
                return if (changed == 1) event else null
            }
        } finally { db.endTransaction() }
    }
}

internal object RestAlertsRuntime {
    const val CHANNEL = "settrace_rest_end_v1"
    const val EXTRA_SESSION = "rest_session_id"
    const val ACTION = "com.settrace.settrace.REST_ENDED"
    val io = Executors.newSingleThreadExecutor()
    val main = Handler(Looper.getMainLooper())
    @Volatile var foreground = false
    var bridge = WeakReference<RestAlertsBridge>(null)

    fun sound(context: Context) = Uri.parse("android.resource://${context.packageName}/raw/rest_end")
    fun notificationManager(context: Context) = context.getSystemService(NotificationManager::class.java)
    fun attributes(): AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_NOTIFICATION).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    fun createChannel(context: Context, name: String, description: String) {
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = notificationManager(context)
            val channel = manager.getNotificationChannel(CHANNEL)
                ?: NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_DEFAULT).apply {
                    setSound(sound(context), attributes())
                    enableVibration(false)
                }
            channel.name = name
            channel.description = description
            manager.createNotificationChannel(channel)
        }
    }
    fun notificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val manager = notificationManager(context)
        if (!manager.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 26 ||
            manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
    }
    fun exactAllowed(context: Context): Boolean {
        val alarms = context.getSystemService(AlarmManager::class.java)
        return Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()
    }
    fun alarmIntent(context: Context, id: Int, revision: Int, flags: Int): PendingIntent? {
        val intent = Intent(context, RestEndedReceiver::class.java).apply {
            action = ACTION
            data = Uri.parse("settrace://rest-alert/$id")
            putExtra("id", id); putExtra("revision", revision)
        }
        return PendingIntent.getBroadcast(context, id, intent, flags or PendingIntent.FLAG_IMMUTABLE)
    }

    fun schedule(context: Context, id: Int, revision: Int, due: Long) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val operation = alarmIntent(context, id, revision, PendingIntent.FLAG_UPDATE_CURRENT)!!
        if (exactAllowed(context)) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, operation)
        else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, operation)
        val prefs = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
        val ids = prefs.getStringSet("ids", emptySet())!!.toMutableSet().apply { add(id.toString()) }
        check(prefs.edit().putStringSet("ids", ids).commit()) { "preferenceWriteFailed" }
    }
    fun cancelExcept(context: Context, valid: Set<String>) {
        val prefs = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
        val ids = prefs.getStringSet("ids", emptySet())!!.toMutableSet()
        for (value in ids.toList()) if (!valid.contains(value)) {
            val id = value.toInt()
            alarmIntent(context, id, 0, PendingIntent.FLAG_NO_CREATE)?.let {
                context.getSystemService(AlarmManager::class.java).cancel(it); it.cancel()
            }
            notificationManager(context).cancel(id)
            ids.remove(value)
        }
        check(prefs.edit().putStringSet("ids", ids).commit()) { "preferenceWriteFailed" }
    }

    fun deliver(context: Context, id: Int, revision: Int) {
        val event = RestAlertsStore.withDatabase(context) { db ->
            RestAlertsStore.claim(db, id, revision, System.currentTimeMillis())
        } ?: return
        val completed = CountDownLatch(1)
        main.post {
          try {
            if (foreground) {
                bridge.get()?.delivered(event.body)
                val audio = context.getSystemService(AudioManager::class.java)
                val manager = notificationManager(context)
                val notificationChannel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(CHANNEL) else null
                if (RestDeliveryPolicy.soundAllowed(
                    audio.ringerMode == AudioManager.RINGER_MODE_NORMAL,
                    audio.getStreamVolume(AudioManager.STREAM_NOTIFICATION),
                    manager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL,
                    Build.VERSION.SDK_INT < 26 || notificationChannel?.sound != null,
                    if (Build.VERSION.SDK_INT < 26) NotificationManager.IMPORTANCE_DEFAULT else notificationChannel?.importance ?: NotificationManager.IMPORTANCE_NONE)) {
                    val player = MediaPlayer.create(context, R.raw.rest_end, attributes(), 0)
                    player?.setOnCompletionListener { it.release() }
                    player?.setOnErrorListener { p, _, _ -> p.release(); true }
                    player?.start()
                }
            } else if (notificationsAllowed(context)) {
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra(EXTRA_SESSION, event.sessionId)
                    data = Uri.parse("settrace://workout/${event.sessionId}")
                }
                val click = PendingIntent.getActivity(context, event.id, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
                builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                    .setContentTitle(event.title).setContentText(event.body)
                    .setStyle(Notification.BigTextStyle().bigText(event.body))
                    .setContentIntent(click).setAutoCancel(true).setOnlyAlertOnce(true)
                    .setCategory(Notification.CATEGORY_REMINDER)
                if (Build.VERSION.SDK_INT < 26) builder.setSound(sound(context), attributes())
                notificationManager(context).notify(event.id, builder.build())
            }
          } finally { completed.countDown() }
        }
        check(completed.await(5, TimeUnit.SECONDS)) { "deliveryTimedOut" }
    }
}

class RestEndedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != RestAlertsRuntime.ACTION) return
        val pending = goAsync()
        RestAlertsRuntime.io.execute {
            try { RestAlertsRuntime.deliver(context.applicationContext, intent.getIntExtra("id", -1), intent.getIntExtra("revision", -1)) }
            catch (error: Exception) { android.util.Log.w("SetTraceRest", "reminderDeliveryFailed", error) }
            finally { pending.finish() }
        }
    }
}

class RestAlertsBridge(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "settrace/rest_alerts")
    private val prefs = activity.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
    private var permissionResult: MethodChannel.Result? = null
    private var dartReady = false
    private var initialTap: Int? = activity.intent.takeSession()
    init {
        channel.setMethodCallHandler(this)
        RestAlertsRuntime.bridge = WeakReference(this)
    }
    private fun Intent.takeSession(): Int? {
        if (!hasExtra(RestAlertsRuntime.EXTRA_SESSION)) return null
        val id = getIntExtra(RestAlertsRuntime.EXTRA_SESSION, -1)
        removeExtra(RestAlertsRuntime.EXTRA_SESSION)
        return id.takeIf { it > 0 }
    }
    fun onNewIntent(intent: Intent) {
        intent.takeSession()?.let { id ->
            if (dartReady) channel.invokeMethod("notificationTap", id) else initialTap = id
        }
    }
    fun delivered(body: String) { channel.invokeMethod("delivered", body) }
    fun onPermissionResult(code: Int): Boolean {
        if (code != 47201) return false
        permissionResult?.success(null); permissionResult = null
        return true
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "requestNotifications") {
            if (Build.VERSION.SDK_INT >= 33 &&
                activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                if (permissionResult != null) { result.error("permissionBusy", null, null); return }
                permissionResult = result
                activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 47201)
            } else result.success(null)
            return
        }
        if (call.method == "takeInitialTap") { dartReady = true; result.success(initialTap); initialTap = null; return }
        if (call.method == "openSettings") {
            try {
                val exact = call.argument<Boolean>("exact") == true
                val intent = if (exact && Build.VERSION.SDK_INT >= 31)
                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${activity.packageName}"))
                else Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                activity.startActivity(intent); result.success(null)
            } catch (_: Exception) { result.error("settingsUnavailable", null, null) }
            return
        }
        RestAlertsRuntime.io.execute {
            try {
                val output: Any? = when (call.method) {
                    "initialize" -> {
                        val path = call.argument<String>("path") ?: error("databaseMissing")
                        val root = File(activity.applicationInfo.dataDir).canonicalPath + File.separator
                        require(File(path).canonicalPath.startsWith(root)) { "invalidDatabasePath" }
                        check(prefs.edit().putString("database_path", path).commit()) { "preferenceWriteFailed" }
                        RestAlertsRuntime.createChannel(activity, call.argument<String>("channelName") ?: "",
                            call.argument<String>("description") ?: "")
                        null
                    }
                    "capabilities" -> mapOf("notifications" to RestAlertsRuntime.notificationsAllowed(activity),
                        "exact" to RestAlertsRuntime.exactAllowed(activity))
                    "schedule" -> {
                        RestAlertsRuntime.schedule(activity,
                            call.argument<Number>("id")!!.toInt(),
                            call.argument<Number>("revision")!!.toInt(),
                            call.argument<Number>("due_at")!!.toLong())
                        null
                    }
                    "deliver" -> {
                        RestAlertsRuntime.deliver(activity,
                            call.argument<Number>("id")!!.toInt(), call.argument<Number>("revision")!!.toInt())
                        null
                    }
                    "cancelExcept" -> {
                        val valid = (call.argument<List<Number>>("ids") ?: emptyList()).map { it.toInt().toString() }.toSet()
                        RestAlertsRuntime.cancelExcept(activity, valid)
                        null
                    }
                    else -> throw IllegalArgumentException("unknownMethod")
                }
                RestAlertsRuntime.main.post { result.success(output) }
            } catch (error: Exception) {
                RestAlertsRuntime.main.post { result.error("reminderOperationFailed", error.javaClass.simpleName, null) }
            }
        }
    }
    fun dispose() {
        channel.setMethodCallHandler(null)
        permissionResult?.error("activityClosed", null, null)
        permissionResult = null
        if (RestAlertsRuntime.bridge.get() === this) RestAlertsRuntime.bridge.clear()
    }
}
