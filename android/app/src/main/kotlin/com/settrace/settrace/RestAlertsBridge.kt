package com.settrace.settrace

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
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

internal object RestAlertsRuntime {
    private fun diagnostic(context: Context, name: String, phase: String, outcome: String = "observed", reason: String = "none",
                           id: Int? = null, session: Int? = null, epoch: Long? = null, operation: String? = null,
                           attributes: Map<String, Any?> = emptyMap(), error: Throwable? = null) {
        try {
            DiagnosticsRuntime.get(context).record(name, phase, outcome, reason, if (error == null) "info" else "error",
                objects = buildMap { if (id != null && id > 0) put("rest_alert", id.toLong()); if (session != null && session > 0) put("session", session.toLong()) },
                attributes = attributes, epoch = epoch, operationId = operation, frames = error?.let { DiagnosticPrivacy.frames(it) }.orEmpty())
        } catch (_: Exception) { /* logging cannot change reminder delivery */ }
    }
    fun failed(context: Context, error: Throwable) = diagnostic(context, "rest.output", "failed", "unknown",
        if (error is RestStoreUnavailable) error.reason else "platform", error = error)
    const val CHANNEL = "settrace_rest_end_v1"
    const val EXTRA_SESSION = "rest_session_id"
    const val ACTION = "com.settrace.settrace.REST_ENDED"
    val io = Executors.newSingleThreadExecutor()
    val main = Handler(Looper.getMainLooper())
    @Volatile var foreground = false
    var bridge = WeakReference<RestAlertsBridge>(null)
    private var player: MediaPlayer? = null
    private var playingId: Int? = null
    private fun prefs(context: Context) = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
    fun notificationManager(context: Context) = context.getSystemService(NotificationManager::class.java)
    fun attributes(): AudioAttributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    private fun locale(context: Context) = if (prefs(context).getString("locale", "en")!!.startsWith("zh")) "zh" else "en"
    private fun asset(context: Context, sound: String, language: String = locale(context)): Uri {
        val name = when (sound) { "double_beep" -> "rest_double_beep"; "voice" -> "rest_voice_$language"; else -> "rest_three_tone" }
        return Uri.parse("android.resource://${context.packageName}/raw/$name")
    }
    private fun channelId(context: Context, settings: RestAlertSettings) =
        "settrace_rest_v2_${settings.sound}_${if (settings.sound == "voice") locale(context) else "tone"}_${if (settings.vibration) 1 else 0}"
    fun createChannel(context: Context, name: String, description: String) {
        prefs(context).edit().putString("channel_name", name).putString("channel_description", description).apply()
        val settings = RestAlertsStore.withDatabase(context) { RestAlertsStore.settings(it) }
        val id = ensureChannel(context, settings)
        prefs(context).edit().putString("current_channel", id).apply()
    }
    private fun ensureChannel(context: Context, settings: RestAlertSettings): String {
        var id = channelId(context, settings)
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = notificationManager(context)
            val previous = manager.getNotificationChannel(prefs(context).getString("current_channel", CHANNEL)!!)
            // Returning to an existing sound must also preserve the current system restriction.
            if (previous?.importance == NotificationManager.IMPORTANCE_NONE) id += "_blocked"
            else if (previous != null && previous.sound == null) id += "_muted"
            else if (previous != null && previous.importance < NotificationManager.IMPORTANCE_DEFAULT) id += "_quiet"
            val systemVibrationDisabled = previous != null && previous.id.startsWith("settrace_rest_v2_") &&
                Regex("_1(?:_|$)").containsMatchIn(previous.id) && !previous.shouldVibrate()
            if (systemVibrationDisabled && settings.vibration) id += "_no_vibration"
            val channel = manager.getNotificationChannel(id) ?: NotificationChannel(id,
                prefs(context).getString("channel_name", "")!!,
                minOf(previous?.importance ?: NotificationManager.IMPORTANCE_DEFAULT, NotificationManager.IMPORTANCE_DEFAULT)).apply {
                // Preserve prior system mute/block choices when creating a different sound channel.
                setSound(if (previous != null && previous.sound == null) null else asset(context, settings.sound), attributes())
                vibrationPattern = longArrayOf(0, 160, 120, 160)
                enableVibration(settings.vibration && !systemVibrationDisabled)
            }
            channel.name = prefs(context).getString("channel_name", "")!!
            channel.description = prefs(context).getString("channel_description", "")!!
            manager.createNotificationChannel(channel)
        }
        return id
    }
    fun notificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val manager = notificationManager(context)
        if (!manager.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 26 || (manager.getNotificationChannel(prefs(context).getString("current_channel", CHANNEL)!!)?.importance ?: NotificationManager.IMPORTANCE_NONE) != NotificationManager.IMPORTANCE_NONE
    }
    fun exactAllowed(context: Context): Boolean = Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    fun alarmIntent(context: Context, id: Int, revision: Int, flags: Int, sequence: Int = 0, diagnosticOperation: String? = null): PendingIntent? {
        val intent = Intent(context, RestEndedReceiver::class.java).apply {
            action = ACTION; data = Uri.parse("settrace://rest-alert/$id")
            putExtra("id", id); putExtra("revision", revision); putExtra("sequence", sequence)
            if (diagnosticOperation != null) putExtra("diagnostic_operation", diagnosticOperation)
        }
        return PendingIntent.getBroadcast(context, id, intent, flags or PendingIntent.FLAG_IMMUTABLE)
    }
    fun schedule(context: Context, id: Int, revision: Int, due: Long, sequence: Int = 0, diagnosticOperation: String? = null, epoch: Long? = null) {
        val trace = diagnosticOperation?.takeIf { DiagnosticVocabulary.token.matches(it) } ?: java.util.UUID.randomUUID().toString().replace("-", "")
        val operation = alarmIntent(context, id, revision, PendingIntent.FLAG_UPDATE_CURRENT, sequence, trace)!!
        val alarms = context.getSystemService(AlarmManager::class.java)
        val exact = exactAllowed(context)
        if (exact) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, operation)
        else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, operation)
        val ids = prefs(context).getStringSet("ids", emptySet())!!.toMutableSet().apply { add(id.toString()) }
        check(prefs(context).edit().putStringSet("ids", ids).commit()) { "preferenceWriteFailed" }
        diagnostic(context, if (sequence == 0) "rest.schedule" else "rest.next", "schedule", id = id, epoch = epoch, operation = trace,
            attributes = mapOf("revision" to revision, "round" to sequence, "due_utc" to due, "actual_utc" to System.currentTimeMillis(), "exact_allowed" to exact, "mode" to if (exact) "exact" else "inexact"))
    }
    private fun cancelAlarm(context: Context, id: Int) {
        alarmIntent(context, id, 0, PendingIntent.FLAG_NO_CREATE)?.let {
            context.getSystemService(AlarmManager::class.java).cancel(it); it.cancel()
        }
    }
    fun cancelExcept(context: Context, valid: Set<String>) {
        val ids = prefs(context).getStringSet("ids", emptySet())!!.toMutableSet()
        ids.addAll(notificationManager(context).activeNotifications.map { it.id.toString() })
        for (value in ids.toList()) if (value !in valid) {
            cancelAlarm(context, value.toInt()); notificationManager(context).cancel(value.toInt())
            onMain { if (playingId == value.toInt()) stopPlayback(context) }
            ids.remove(value)
            diagnostic(context, "rest.cancel", "cancelled", "observed", id = value.toInt())
        }
        check(prefs(context).edit().putStringSet("ids", ids).commit()) { "preferenceWriteFailed" }
    }
    private fun onMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) { action(); return }
        val latch = CountDownLatch(1)
        var failure: Throwable? = null
        main.post { try { action() } catch (error: Throwable) { failure = error } finally { latch.countDown() } }
        check(latch.await(5, TimeUnit.SECONDS)) { "outputTimedOut" }
        failure?.let { throw it }
    }
    @Suppress("DEPRECATION")
    private fun vibrator(context: Context) = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    private fun stopPlayback(context: Context) {
        player?.let { try { it.release() } catch (_: Exception) {} }
        player = null; playingId = null
        vibrator(context).cancel()
    }
    fun stopOutput(context: Context, id: Int) {
        cancelAlarm(context, id); notificationManager(context).cancel(id)
        onMain { if (playingId == id) stopPlayback(context) }
        diagnostic(context, "rest.cancel", "cancelled", "observed", id = id)
    }
    fun stopPreview(context: Context) = onMain { if (playingId == -1) stopPlayback(context) }
    private fun play(context: Context, uri: Uri, id: Int) {
        stopPlayback(context)
        val audio = MediaPlayer.create(context, uri, null, attributes(), 0) ?: return
        player = audio; playingId = id
        audio.setOnCompletionListener { if (player === it) { player = null; playingId = null }; it.release() }
        audio.setOnErrorListener { p, _, _ -> if (player === p) { player = null; playingId = null }; p.release(); true }
        audio.start()
    }
    private fun soundAllowed(context: Context, id: String): Boolean {
        val audio = context.getSystemService(AudioManager::class.java)
        val manager = notificationManager(context)
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(id) else null
        return RestDeliveryPolicy.soundAllowed(audio.ringerMode == AudioManager.RINGER_MODE_NORMAL,
            audio.getStreamVolume(AudioManager.STREAM_NOTIFICATION),
            manager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL,
            Build.VERSION.SDK_INT < 26 || channel?.sound != null,
            if (Build.VERSION.SDK_INT < 26) NotificationManager.IMPORTANCE_DEFAULT else channel?.importance ?: 0)
    }
    fun preview(context: Context, sound: String, language: String) {
        require(sound in setOf("three_tone", "double_beep", "voice"))
        val current = prefs(context).getString("current_channel", CHANNEL)!!
        onMain {
            if (playingId == null || playingId == -1) {
                if (soundAllowed(context, current)) play(context, asset(context, sound, if (language.startsWith("zh")) "zh" else "en"), -1)
            }
        }
    }
    private fun notify(context: Context, event: RestDelivery, channelId: String, silent: Boolean) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_SESSION, event.sessionId); putExtra("rest_event_id", event.id); putExtra("rest_revision", event.revision)
            data = Uri.parse("settrace://workout/${event.sessionId}/rest/${event.id}")
        }
        val click = PendingIntent.getActivity(context, event.id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channelId) else Notification.Builder(context)
        builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(event.title).setContentText(event.body).setStyle(Notification.BigTextStyle().bigText(event.body))
            .setContentIntent(click).setAutoCancel(true).setOnlyAlertOnce(silent).setCategory(Notification.CATEGORY_REMINDER)
        if (Build.VERSION.SDK_INT < 26) {
            builder.setSound(asset(context, event.settings.sound), attributes())
            if (event.settings.vibration) builder.setVibrate(longArrayOf(0, 160, 120, 160))
        }
        notificationManager(context).notify(event.id, builder.build())
    }
    fun refreshNotification(context: Context, id: Int, revision: Int) {
        val event = RestAlertsStore.withDatabase(context) { RestAlertsStore.projection(it,id,revision) } ?: return
        val channelId = ensureChannel(context,event.settings)
        onMain {
            // A content/settings refresh never creates a notification or claims a round.
            if (!notificationsAllowed(context) || notificationManager(context).activeNotifications.none { it.id == id } ||
                !RestAlertsStore.withDatabase(context) { RestAlertsStore.valid(it,event) }) return@onMain
            notify(context,event,channelId,silent = true)
        }
    }
    fun deliver(context: Context, id: Int, revision: Int, sequence: Int = 0, diagnosticOperation: String? = null) {
        val trace = diagnosticOperation?.takeIf { DiagnosticVocabulary.token.matches(it) } ?: java.util.UUID.randomUUID().toString().replace("-", "")
        val event = RestAlertsStore.withDatabase(context) { RestAlertsStore.claim(it, id, revision, System.currentTimeMillis(), sequence) { observation ->
            diagnostic(context, "rest.claim", "claim", if (observation.claimed) "committed" else "rejected", observation.reason,
                id = id, epoch = observation.epoch, operation = trace, attributes = buildMap {
                    put("revision", revision); put("round", sequence); put("actual_utc", observation.now)
                    observation.due?.let { put("due_utc", it) }
                })
        } } ?: return
        val channelId = ensureChannel(context, event.settings)
        prefs(context).edit().putString("current_channel", channelId).apply()
        onMain {
            if (!RestAlertsStore.withDatabase(context) { RestAlertsStore.valid(it, event) }) {
                diagnostic(context, "rest.output", "rejected", "rejected", "condition_mismatch", id, event.sessionId, event.diagnosticEpoch, trace)
                return@onMain
            }
            var requestedSound = false
            var requestedVibration = false
            var requestedNotification = false
            val notifications = notificationsAllowed(context)
            if (foreground) {
                bridge.get()?.delivered(event)
                if (soundAllowed(context, channelId)) {
                    val uri = if (Build.VERSION.SDK_INT >= 26) notificationManager(context).getNotificationChannel(channelId)?.sound else asset(context, event.settings.sound)
                    if (uri != null) { play(context, uri, event.id); requestedSound = true }
                }
                val audio = context.getSystemService(AudioManager::class.java)
                val channel = if (Build.VERSION.SDK_INT >= 26) notificationManager(context).getNotificationChannel(channelId) else null
                if (event.settings.vibration && audio.ringerMode != AudioManager.RINGER_MODE_SILENT &&
                    notificationManager(context).currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL &&
                    (Build.VERSION.SDK_INT < 26 || (channel?.shouldVibrate() == true && channel.importance >= NotificationManager.IMPORTANCE_DEFAULT))) {
                    playingId = event.id
                    requestedVibration = true
                    if (Build.VERSION.SDK_INT >= 26) vibrator(context).vibrate(VibrationEffect.createWaveform(longArrayOf(0, 160, 120, 160), -1), attributes())
                    else @Suppress("DEPRECATION") vibrator(context).vibrate(longArrayOf(0, 160, 120, 160), -1)
                }
            } else if (notifications) {
                notify(context, event, channelId, silent = false)
                requestedNotification = true
            }
            val channelAllowed = Build.VERSION.SDK_INT < 26 || (notificationManager(context).getNotificationChannel(channelId)?.importance ?: 0) != NotificationManager.IMPORTANCE_NONE
            diagnostic(context, "rest.output", "output", reason = if (!foreground && !notifications) "permission_denied" else "none",
                id = id, session = event.sessionId, epoch = event.diagnosticEpoch, operation = trace,
                attributes = mapOf("revision" to revision, "round" to event.sequence, "actual_utc" to System.currentTimeMillis(), "foreground" to foreground,
                    "sound" to requestedSound, "vibrate" to requestedVibration, "enabled" to requestedNotification,
                    "notifications_allowed" to notifications, "channel_allowed" to channelAllowed))
        }
        if (event.nextAt != null && (foreground || notificationsAllowed(context)) &&
            RestAlertsStore.withDatabase(context) { RestAlertsStore.valid(it, event) }) {
            schedule(context, event.id, event.revision, event.nextAt, event.sequence, trace, event.diagnosticEpoch)
        }
    }
}

class RestEndedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != RestAlertsRuntime.ACTION || !intent.hasExtra("sequence")) return
        val pending = goAsync()
        RestAlertsRuntime.io.execute {
            try { RestAlertsRuntime.deliver(context.applicationContext, intent.getIntExtra("id", -1),
                intent.getIntExtra("revision", -1), intent.getIntExtra("sequence", -1), intent.getStringExtra("diagnostic_operation")) }
            catch (error: Exception) { RestAlertsRuntime.failed(context, error) }
            finally { pending.finish() }
        }
    }
}

class RestAlertsBridge(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "settrace/rest_alerts")
    private val prefs = activity.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
    private var permissionResult: MethodChannel.Result? = null
    private var dartReady = false
    private var initialTap: Map<String, Int>? = activity.intent.takeSession()
    init { channel.setMethodCallHandler(this); RestAlertsRuntime.bridge = WeakReference(this) }
    private fun Intent.takeSession(): Map<String, Int>? {
        if (!hasExtra(RestAlertsRuntime.EXTRA_SESSION)) return null
        val session = getIntExtra(RestAlertsRuntime.EXTRA_SESSION, -1)
        val id = getIntExtra("rest_event_id", -1); val revision = getIntExtra("rest_revision", -1)
        removeExtra(RestAlertsRuntime.EXTRA_SESSION); removeExtra("rest_event_id"); removeExtra("rest_revision")
        if (session <= 0) return null
        return mutableMapOf("session_id" to session).apply { if (id > 0) put("id", id); if (revision > 0) put("revision", revision) }
    }
    fun onNewIntent(intent: Intent) { intent.takeSession()?.let { if (dartReady) channel.invokeMethod("notificationTap", it) else initialTap = it } }
    internal fun delivered(event: RestDelivery) { channel.invokeMethod("delivered", event.payload()) }
    fun onPermissionResult(code: Int): Boolean {
        if (code != 47201) return false
        permissionResult?.success(null); permissionResult = null; return true
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "requestNotifications") {
            if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                if (permissionResult != null) { result.error("permissionBusy", null, null); return }
                permissionResult = result; activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 47201)
            } else result.success(null)
            return
        }
        if (call.method == "takeInitialTap") { dartReady = true; result.success(initialTap); initialTap = null; return }
        if (call.method == "openSettings") {
            try {
                val exact = call.argument<Boolean>("exact") == true
                val intent = if (exact && Build.VERSION.SDK_INT >= 31) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${activity.packageName}"))
                    else if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                        .putExtra(Settings.EXTRA_CHANNEL_ID, prefs.getString("current_channel", RestAlertsRuntime.CHANNEL))
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
                        require(File(path).canonicalPath.startsWith(File(activity.applicationInfo.dataDir).canonicalPath + File.separator)) { "invalidDatabasePath" }
                        if (prefs.getString("database_path", null) != path) check(prefs.edit().putString("database_path", path).commit())
                        RestAlertsRuntime.createChannel(activity, call.argument<String>("channelName") ?: "", call.argument<String>("description") ?: "")
                        null
                    }
                    "configureOutput" -> {
                        val language = call.argument<String>("locale") ?: "en"
                        prefs.edit().putString("locale", language).commit()
                        RestAlertsRuntime.createChannel(activity, prefs.getString("channel_name", "")!!, prefs.getString("channel_description", "")!!)
                        null
                    }
                    "capabilities" -> mapOf("notifications" to RestAlertsRuntime.notificationsAllowed(activity), "exact" to RestAlertsRuntime.exactAllowed(activity))
                    "schedule" -> {
                        val at = call.argument<Number>("next_delivery_at") ?: call.argument<Number>("due_at")!!
                        RestAlertsRuntime.schedule(activity, call.argument<Number>("id")!!.toInt(), call.argument<Number>("revision")!!.toInt(), at.toLong(), call.argument<Number>("delivery_sequence")?.toInt() ?: 0, call.argument<String>("diagnostic_operation"), call.argument<Number>("diagnostic_epoch")?.toLong()); null
                    }
                    "deliver" -> { RestAlertsRuntime.deliver(activity, call.argument<Number>("id")!!.toInt(), call.argument<Number>("revision")!!.toInt(), call.argument<Number>("sequence")?.toInt() ?: 0, call.argument<String>("diagnostic_operation")); null }
                    "cancelExcept" -> { RestAlertsRuntime.cancelExcept(activity, (call.argument<List<Number>>("ids") ?: emptyList()).map { it.toInt().toString() }.toSet()); null }
                    "refreshNotification" -> { RestAlertsRuntime.refreshNotification(activity,call.argument<Number>("id")!!.toInt(),call.argument<Number>("revision")!!.toInt()); null }
                    "stopOutput" -> { RestAlertsRuntime.stopOutput(activity, call.argument<Number>("id")!!.toInt()); null }
                    "preview" -> { RestAlertsRuntime.preview(activity, call.argument<String>("sound")!!, call.argument<String>("locale") ?: "en"); null }
                    "stopPreview" -> { RestAlertsRuntime.stopPreview(activity); null }
                    else -> throw IllegalArgumentException("unknownMethod")
                }
                RestAlertsRuntime.main.post { result.success(output) }
            } catch (error: Exception) { RestAlertsRuntime.failed(activity, error); RestAlertsRuntime.main.post { result.error("reminderOperationFailed", error.javaClass.simpleName, null) } }
        }
    }
    fun dispose() {
        channel.setMethodCallHandler(null); permissionResult?.error("activityClosed", null, null); permissionResult = null
        RestAlertsRuntime.stopPreview(activity)
        if (RestAlertsRuntime.bridge.get() === this) RestAlertsRuntime.bridge.clear()
    }
}
