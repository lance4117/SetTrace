package com.settrace.settrace

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
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
    @Volatile var lastScheduleAcceptedUtc: Long? = null
    @Volatile var lastClaimUtc: Long? = null
    @Volatile var lastOutputRequestedUtc: Long? = null
    @Volatile var lastSource: String? = null
    @Volatile var lastScheduleObservation: Map<String, Any?>? = null
    @Volatile var lastClaimObservation: Map<String, Any?>? = null
    @Volatile var lastOutputObservation: Map<String, Any?>? = null
    @Volatile var lastServiceScheduleObservation: Map<String, Any?>? = null
    @Volatile var lastRecoveryObservation: Map<String, Any?>? = null
    fun recoveryObservation(mode: String?) {
        if (mode in setOf("cold_history","warm_current","settings_refresh","native_callback"))
            lastRecoveryObservation = mapOf("mode" to mode, "observedUtc" to System.currentTimeMillis())
    }
    private fun observation(id: Int, revision: Int, epoch: Long?, trigger: String) = mapOf(
        "id" to id, "revision" to revision, "datasetEpoch" to epoch,
        "observedUtc" to System.currentTimeMillis(), "source" to source(trigger))
    fun serviceObservation(context: Context, state: String, reason: String, leaseExpires: Long? = null,
                           sessionId: Int? = null, datasetEpoch: Long? = null) = diagnostic(
        context, "rest.service", "completed", reason = reason.takeIf { it in DiagnosticVocabulary.reasons } ?: "none",
        session = sessionId, epoch = datasetEpoch,
        attributes = buildMap {
            put("service_state", state); put("cancel_reason", cancellationReason(reason))
            leaseExpires?.let { put("lease_expires_elapsed", it) }
        })
    fun serviceScheduleObservation(context: Context, token: RestScheduleToken) {
        lastServiceScheduleObservation = observation(token.id, token.revision, token.epoch, "service_timer") +
            mapOf("round" to token.sequence, "dueUtc" to token.at)
        diagnostic(context, if (token.sequence == 0) "rest.schedule" else "rest.next", "schedule",
            id = token.id, epoch = token.epoch, session = token.sessionId,
            attributes = mapOf("source" to "service_timer", "trigger" to "service_timer",
                "revision" to token.revision, "round" to token.sequence, "due_utc" to token.at))
    }
    private fun diagnostic(context: Context, name: String, phase: String, outcome: String = "observed", reason: String = "none",
                           id: Int? = null, session: Int? = null, epoch: Long? = null, operation: String? = null,
                           attributes: Map<String, Any?> = emptyMap(), error: Throwable? = null) {
        try {
            DiagnosticsRuntime.get(context).record(name, phase, outcome, reason, if (error == null) "info" else "error",
                objects = buildMap { if (id != null && id > 0) put("rest_alert", id.toLong()); if (session != null && session > 0) put("session", session.toLong()) },
                attributes = attributes + if (id != null) mapOf("identity_unknown" to (epoch == null)) else emptyMap(), epoch = epoch, operationId = operation, frames = error?.let { DiagnosticPrivacy.frames(it) }.orEmpty())
        } catch (_: Exception) { /* logging cannot change reminder delivery */ }
    }
    fun failed(context: Context, error: Throwable) = diagnostic(context, "rest.output", "failed", "unknown",
        if (error is RestStoreUnavailable) error.reason else "platform", error = error)
    private fun cancelled(context: Context, id: Int, operation: String? = null, trigger: String = "platform_cleanup", cancellationReason: String = "unknown") {
        val parts = prefs(context).getString("identity_$id", null)?.split(':')
        val epoch = parts?.getOrNull(0)?.toLongOrNull()
        diagnostic(context, "rest.cancel", "cancelled", id = id, epoch = epoch, operation = operation,
            attributes = buildMap {
                put("trigger", trigger); put("identity_unknown", epoch == null)
                put("cancel_reason", cancellationReason)
                parts?.getOrNull(1)?.toLongOrNull()?.let { put("revision", it) }
                parts?.getOrNull(2)?.toLongOrNull()?.let { put("round", it) }
            })
        prefs(context).edit().remove("identity_$id").apply()
    }
    fun callback(context: Context, intent: Intent) {
        recoveryObservation("native_callback")
        val id = intent.getIntExtra("id", -1)
        diagnostic(context, "rest.callback", "started", id = id,
            epoch = if (intent.hasExtra("diagnostic_epoch")) intent.getLongExtra("diagnostic_epoch", -1).takeIf { it >= 0 } else null,
            operation = intent.getStringExtra("diagnostic_operation"), attributes = mapOf("trigger" to "alarm", "source" to "alarm",
                "revision" to intent.getIntExtra("revision", 0).coerceAtLeast(0), "round" to intent.getIntExtra("sequence", 0).coerceAtLeast(0)))
    }
    const val CHANNEL = "settrace_rest_end_v1"
    const val EXTRA_SESSION = "rest_session_id"
    const val ACTION = "com.settrace.settrace.REST_ENDED"
    val io = Executors.newSingleThreadExecutor()
    val main = Handler(Looper.getMainLooper())
    @Volatile var foreground = false
    fun cancellationReason(reason: String?): String = reason?.takeIf {
            it in DiagnosticVocabulary.enumFields.getValue("cancel_reason")
        } ?: "unknown"
    var bridge = WeakReference<RestAlertsBridge>(null)
    private var soundUri: Uri? = null
    private val sound = RestSingleSound(create = {
        soundUri?.let { uri ->
            val audio = MediaPlayer()
            try {
                audio.setAudioAttributes(attributes())
                audio.setDataSource(soundContext!!, uri)
                object : RestSoundHandle {
                    override fun prepare(ready: () -> Unit, completed: () -> Unit, failed: () -> Unit) {
                        audio.setOnPreparedListener { ready() }; audio.setOnCompletionListener { completed() }
                        audio.setOnErrorListener { _, _, _ -> failed(); true }; audio.prepareAsync()
                    }
                    override fun start() = audio.start()
                    override fun release() = audio.release()
                }
            } catch (error: Exception) { audio.release(); throw error }
        }
    }, timeout = { delay, action -> main.postDelayed({ action() }, delay) })
    private var soundContext: Context? = null
    private var playingId: Int? = null
    private var playingSource: String? = null
    private fun prefs(context: Context) = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
    fun notificationManager(context: Context) = context.getSystemService(NotificationManager::class.java)
    fun attributes(): AudioAttributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    private fun channelId(settings: RestAlertSettings) = "settrace_rest_system_v1_${if (settings.vibration) 1 else 0}"
    fun createChannel(context: Context, name: String, description: String) {
        prefs(context).edit().putString("channel_name", name).putString("channel_description", description).apply()
        val settings = RestAlertsStore.withDatabase(context) { RestAlertsStore.settings(it) }
        ensureChannel(context, settings)
    }
    private fun channelPolicy(channel: NotificationChannel): RestChannelPolicy = RestChannelPolicy(
        channel.importance, channel.sound == null,
        (channel.id.endsWith("_1") || Regex("_1(?:_|$)").containsMatchIn(channel.id)) && !channel.shouldVibrate())
    // Only this serial executor migrates. Never store a user URI in preferences or diagnostics.
    private fun ensureChannel(context: Context, settings: RestAlertSettings): String {
        val id = channelId(settings)
        if (Build.VERSION.SDK_INT < 26) return id
        val manager = notificationManager(context)
        val saved = prefs(context).getString("current_channel", null)
        val restrictionSource = prefs(context).getString("restriction_source", null)
        val previous = (restrictionSource ?: saved)?.let { manager.getNotificationChannel(it) }
        val legacy = if (previous != null) listOf(previous) else manager.notificationChannels.filter {
            it.id == CHANNEL || it.id.startsWith("settrace_rest_v2_") || it.id.startsWith("settrace_rest_system_v1_") }
        var policy = RestChannelPolicy(muted = previous == null && (restrictionSource != null || legacy.size > 1))
        for (channel in legacy) policy = policy.inherit(channelPolicy(channel))
        val source = previous ?: legacy.singleOrNull()
        val desiredSound = if (policy.muted) null else source?.sound?.takeUnless {
            it.scheme == "android.resource" && it.authority == context.packageName
        } ?: Settings.System.DEFAULT_NOTIFICATION_URI
        val target = manager.getNotificationChannel(id) ?: NotificationChannel(id,
            prefs(context).getString("channel_name", "Rest reminders")!!, policy.importance).apply {
            setSound(desiredSound, attributes()); vibrationPattern = longArrayOf(0,160,120,160)
            enableVibration(settings.vibration && !policy.userNoVibration)
        }
        target.name = prefs(context).getString("channel_name", "Rest reminders")!!
        target.description = prefs(context).getString("channel_description", "")!!
        manager.createNotificationChannel(target)
        val actual = manager.getNotificationChannel(id) ?: throw IllegalStateException("channelMissing")
        val explicitRelease = restrictionSource == "unknown" && RestChannelPolicy.explicitUnknownRelease(
            Build.VERSION.SDK_INT, actual.sound != null, Build.VERSION.SDK_INT >= 30 && actual.hasUserSetSound(),
            prefs(context).getBoolean("unknown_target_muted_seen", false))
        val restricted = !explicitRelease && (!policy.permits(channelPolicy(actual).copy(userNoVibration = !actual.shouldVibrate())) ||
            (desiredSound != null && desiredSound != Settings.System.DEFAULT_NOTIFICATION_URI && actual.sound != null && actual.sound != desiredSound))
        // The app-off variant cannot itself prove a user's vibration ban.
        // Keep its actual source while off, so toggling back cannot bypass it.
        val vibrationSource = if (policy.userNoVibration && !settings.vibration)
            previous?.id ?: legacy.firstOrNull { channelPolicy(it).userNoVibration }?.id else null
        val nextSource = if (restricted) previous?.id ?: restrictionSource ?: "unknown" else vibrationSource
        // Re-evaluated from the current platform on every use, so explicit user unmute works.
        check(prefs(context).edit().putBoolean("channel_restricted", restricted)
            .putInt("sound_migration", 1).putString("current_channel", id)
            .putString("restriction_source", nextSource)
            .putBoolean("unknown_target_muted_seen", nextSource == "unknown" &&
                (actual.sound == null || prefs(context).getBoolean("unknown_target_muted_seen",false))).commit())
        return id
    }
    fun notificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val manager = notificationManager(context)
        if (!manager.areNotificationsEnabled()) return false
        return !prefs(context).getBoolean("channel_restricted", false) && (Build.VERSION.SDK_INT < 26 || (manager.getNotificationChannel(prefs(context).getString("current_channel", CHANNEL)!!)?.importance ?: NotificationManager.IMPORTANCE_NONE) != NotificationManager.IMPORTANCE_NONE)
    }
    fun exactAllowed(context: Context): Boolean = Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
    fun alarmIntent(context: Context, id: Int, revision: Int, flags: Int, sequence: Int = 0, diagnosticOperation: String? = null, epoch: Long? = null): PendingIntent? {
        val intent = Intent(context, RestEndedReceiver::class.java).apply {
            action = ACTION; data = Uri.parse("settrace://rest-alert/$id")
            putExtra("id", id); putExtra("revision", revision); putExtra("sequence", sequence)
            if (diagnosticOperation != null) putExtra("diagnostic_operation", diagnosticOperation)
            epoch?.let { putExtra("diagnostic_epoch", it) }
        }
        return PendingIntent.getBroadcast(context, id, intent, flags or PendingIntent.FLAG_IMMUTABLE)
    }
    fun schedule(context: Context, id: Int, revision: Int, due: Long, sequence: Int = 0, diagnosticOperation: String? = null, epoch: Long? = null, trigger: String = "unknown") {
        // Re-read under the same DB lock used by claims. A stale Dart sync must
        // not overwrite the alarm for the next committed round.
        RestAlertsStore.withDatabase(context) { db ->
            db.beginTransaction()
            try {
                val token = RestAlertsStore.current(db, id)
                if (token == null || token.revision != revision || token.sequence != sequence || token.at != due ||
                    (epoch != null && token.epoch != epoch)) return@withDatabase
                scheduleCurrent(context, token, diagnosticOperation, trigger)
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
        TrainingReminderService.reconcile(context)
    }
    private fun scheduleCurrent(context: Context, token: RestScheduleToken, diagnosticOperation: String?, trigger: String) {
        val (id, revision, sequence, due, epoch) = token
        val trace = diagnosticOperation?.takeIf { DiagnosticVocabulary.token.matches(it) } ?: java.util.UUID.randomUUID().toString().replace("-", "")
        val operation = alarmIntent(context, id, revision, PendingIntent.FLAG_UPDATE_CURRENT, sequence, trace, epoch)!!
        val alarms = context.getSystemService(AlarmManager::class.java)
        val exact = exactAllowed(context)
        var usedExact = exact
        try {
            if (exact) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, operation)
            else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, operation)
        } catch (_: SecurityException) {
            usedExact = false
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, operation)
        }
        lastScheduleAcceptedUtc = System.currentTimeMillis()
        lastScheduleObservation = observation(id, revision, epoch, "alarm") +
            mapOf("round" to sequence, "dueUtc" to due, "mode" to if (usedExact) "exact" else "inexact")
        val ids = prefs(context).getStringSet("ids", emptySet())!!.toMutableSet().apply { add(id.toString()) }
        check(prefs(context).edit().putStringSet("ids", ids).putString("identity_$id", "${epoch ?: "unknown"}:$revision:$sequence").commit()) { "preferenceWriteFailed" }
        diagnostic(context, if (sequence == 0) "rest.schedule" else "rest.next", "schedule", id = id, epoch = epoch, operation = trace,
            attributes = mapOf("trigger" to trigger, "source" to "alarm", "revision" to revision, "round" to sequence, "due_utc" to due, "actual_utc" to System.currentTimeMillis(), "exact_allowed" to usedExact, "mode" to if (usedExact) "exact" else "inexact"))
    }
    private fun cancelAlarm(context: Context, id: Int) {
        alarmIntent(context, id, 0, PendingIntent.FLAG_NO_CREATE)?.let {
            context.getSystemService(AlarmManager::class.java).cancel(it); it.cancel()
        }
    }
    fun cancelExcept(context: Context, valid: Set<String>, operation: String? = null, trigger: String = "platform_cleanup", reason: String = "unknown") {
        // `valid` is only the Dart observation. Re-read the durable current set:
        // an older queued cleanup must not cancel a newly committed reminder.
        val durableValid = try { RestAlertsStore.withDatabase(context) { RestAlertsStore.activeIds(it) } }
            catch (error: RestStoreUnavailable) { if(error.reason=="restore_guard") emptySet() else throw error }
        val ids = prefs(context).getStringSet("ids", emptySet())!!.toMutableSet()
        ids.addAll(notificationManager(context).activeNotifications.filter {
            RestNotificationOwnership.isRest(it.tag, it.id,
                it.id.toString() in ids || it.notification.extras.getBoolean("settrace.rest", false))
        }.map { it.id.toString() })
        for (value in ids.toList()) if (value !in durableValid) {
            cancelAlarm(context, value.toInt()); notificationManager(context).cancel(value.toInt())
            onMain { if (playingId == value.toInt()) stopPlayback(context) }
            ids.remove(value)
            cancelled(context, value.toInt(), operation, trigger, reason)
        }
        check(prefs(context).edit().putStringSet("ids", ids).commit()) { "preferenceWriteFailed" }
    }
    private fun onMain(deadlineElapsed: Long? = null, action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) { action(); return }
        val latch = CountDownLatch(1)
        var failure: Throwable? = null
        main.post { try { action() } catch (error: Throwable) { failure = error } finally { latch.countDown() } }
        val remaining = deadlineElapsed?.let { (it - SystemClock.elapsedRealtime()).coerceIn(0L, 5000L) } ?: 5000L
        check(latch.await(remaining, TimeUnit.MILLISECONDS)) { "outputTimedOut" }
        failure?.let { throw it }
    }
    @Suppress("DEPRECATION")
    private fun vibrator(context: Context) = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    private fun stopPlayback(context: Context) {
        sound.stop(); playingId = null; playingSource = null; vibrator(context).cancel()
    }
    fun stopServicePlayback(context: Context) = main.post {
        if (playingSource == "service_timer") stopPlayback(context)
    }
    fun stopOutput(context: Context, id: Int, operation: String? = null, trigger: String = "platform_cleanup", reason: String = "unknown") {
        val stillCurrent = try { RestAlertsStore.withDatabase(context) { id.toString() in RestAlertsStore.activeIds(it) } }
            catch (error: RestStoreUnavailable) { if(error.reason=="restore_guard") false else throw error }
        if (stillCurrent) return
        cancelAlarm(context, id); notificationManager(context).cancel(id)
        onMain { if (playingId == id) stopPlayback(context) }
        cancelled(context, id, operation, trigger, reason)
        TrainingReminderService.reconcile(context)
    }
    fun stopPreview(context: Context) = onMain { sound.stop(previewOnly = true); if (playingId == -1) playingId = null }
    private fun readings(context: Context, id: String): RestSoundReadings = try {
        val audio = context.getSystemService(AudioManager::class.java)
        val manager = notificationManager(context)
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(id) else null
        val uri = effectiveUri(context,id)
        val hasSound = uri != null && (uri != Settings.System.DEFAULT_NOTIFICATION_URI ||
            RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_NOTIFICATION) != null)
        RestSoundReadings(audio.ringerMode, audio.getStreamVolume(AudioManager.STREAM_NOTIFICATION), manager.currentInterruptionFilter,
            hasSound,
            if (!manager.areNotificationsEnabled() || prefs(context).getBoolean("channel_restricted", false)) 0 else if (Build.VERSION.SDK_INT < 26) 3 else channel?.importance)
    } catch (_: Exception) { RestSoundReadings(null,null,null,null,null) }
    private fun effectiveUri(context: Context, id: String): Uri? = if (Build.VERSION.SDK_INT >= 26)
        notificationManager(context).getNotificationChannel(id)?.sound else Settings.System.DEFAULT_NOTIFICATION_URI
    fun soundStatus(context: Context): Map<String, Any?> {
        val settings = RestAlertsStore.withDatabase(context) { RestAlertsStore.settings(it) }
        val id = ensureChannel(context, settings)
        val facts = readings(context, id)
        return mapOf("condition" to facts.condition, "custom" to (effectiveUri(context,id)?.let { it != Settings.System.DEFAULT_NOTIFICATION_URI } ?: false))
    }
    private fun play(context: Context, channelId: String, id: Int, epoch: Long?, trace: String?, revision: Int?, round: Int?,
                     preview: Boolean = false, terminal: (String) -> Unit = {}, trigger: String = "unknown"): Boolean {
        val facts = readings(context, channelId)
        val fields = facts.fields() + buildMap<String, Any?> {
            put("trigger", if (preview) "preview" else trigger)
            revision?.let { put("revision", it) }; round?.let { put("round", it) }
        }
        fun observe(state: String, condition: String) {
            diagnostic(context, "rest.audio", "output", reason = if (state == "failed") "platform" else "none",
                id = id.takeIf { it > 0 }, epoch = epoch, operation = trace,
                attributes = fields + mapOf("audio_state" to state, "sound_condition" to condition),
                error = if (state == "failed") IllegalStateException() else null)
        }
        if (facts.condition != "allowed") { observe("suppressed", facts.condition); terminal(facts.condition); return false }
        if (!preview) stopPlayback(context)
        soundUri = effectiveUri(context, channelId); soundContext = context.applicationContext
        val started = sound.play(preview, ::observe, terminal)
        if (started) { playingId = id; playingSource = trigger }
        return started
    }
    fun preview(context: Context, terminal: (String) -> Unit) {
        val settings = RestAlertsStore.withDatabase(context) { RestAlertsStore.settings(it) }
        val id = ensureChannel(context, settings)
        onMain {
            if (playingId != null && playingId != -1) terminal("busy")
            else play(context, id, -1, null, java.util.UUID.randomUUID().toString().replace("-", ""), null, null, true, terminal)
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
            .addExtras(Bundle().apply { putBoolean("settrace.rest", true) })
            .setContentTitle(event.title).setContentText(event.body).setStyle(Notification.BigTextStyle().bigText(event.body))
            .setContentIntent(click).setAutoCancel(true).setOnlyAlertOnce(silent).setCategory(Notification.CATEGORY_REMINDER)
        if (Build.VERSION.SDK_INT < 26) {
            builder.setSound(Settings.System.DEFAULT_NOTIFICATION_URI, attributes())
            if (event.settings.vibration) builder.setVibrate(longArrayOf(0, 160, 120, 160))
        }
        val notification = builder.build()
        if (prefs(context).getBoolean("channel_restricted", false)) {
            notification.sound = null; notification.vibrate = null
            if (Build.VERSION.SDK_INT >= 26) {
                // An immutable target cannot inherit stricter policy: do not bypass it.
                return
            }
        }
        notificationManager(context).notify(event.id, notification)
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
    private fun source(trigger: String) = when (trigger) {
        "alarm" -> "alarm"
        "service_timer" -> "service_timer"
        "resume" -> "warm_resume"
        "startup" -> "cold_recovery"
        "settings_change" -> "settings_refresh"
        else -> "foreground_poll"
    }
    fun deliver(context: Context, id: Int, revision: Int, sequence: Int = 0, diagnosticOperation: String? = null, trigger: String = "unknown",
                expectedEpoch: Long? = null, workDeadline: Long? = null, allowed: () -> Boolean = { true }) {
        if (!allowed()) return
        if (workDeadline != null && SystemClock.elapsedRealtime() >= workDeadline) return
        val trace = diagnosticOperation?.takeIf { DiagnosticVocabulary.token.matches(it) } ?: java.util.UUID.randomUUID().toString().replace("-", "")
        val event = RestAlertsStore.withDatabase(context, workDeadline) {
            if (!allowed() || (workDeadline != null && SystemClock.elapsedRealtime() >= workDeadline)) return@withDatabase null
            if (it.version >= 5 && expectedEpoch == null) {
                diagnostic(context, "rest.claim", "rejected", "rejected", "condition_mismatch", id = id,
                    operation = trace, attributes = mapOf("identity_unknown" to true, "source" to source(trigger)))
                return@withDatabase null
            }
            RestAlertsStore.claim(it, id, revision, System.currentTimeMillis(), sequence, expectedEpoch) { observation ->
            diagnostic(context, "rest.claim", "claim", if (observation.claimed) "committed" else "rejected", observation.reason,
                id = id, epoch = observation.epoch, operation = trace, attributes = buildMap {
                    put("revision", revision); put("round", sequence); put("actual_utc", observation.now)
                    observation.due?.let { put("due_utc", it) }
                    put("identity_unknown", observation.epoch == null)
                    put("source", source(trigger))
                })
            if (observation.transition) diagnostic(context,"rest.transition","committed","committed",observation.reason,
                id = id, epoch = observation.epoch, operation = trace, attributes = mapOf("before_state" to "pending", "after_state" to "expired", "trigger" to trigger, "revision" to revision, "round" to sequence))
        } } ?: return
        lastClaimUtc = System.currentTimeMillis(); lastSource = source(trigger)
        lastClaimObservation = observation(id, revision, event.diagnosticEpoch, trigger)
        prefs(context).edit().putString("identity_$id", "${event.diagnosticEpoch ?: "unknown"}:$revision:$sequence").apply()
        val channelId = ensureChannel(context, event.settings)
        prefs(context).edit().putString("current_channel", channelId).apply()
        onMain(workDeadline) {
            if (!allowed()) return@onMain
            if (workDeadline != null && SystemClock.elapsedRealtime() >= workDeadline) return@onMain
            if (!RestAlertsStore.withDatabase(context, workDeadline) { RestAlertsStore.valid(it, event) }) {
                diagnostic(context, "rest.output", "rejected", "rejected", "condition_mismatch", id, event.sessionId, event.diagnosticEpoch, trace)
                return@onMain
            }
            if (!allowed() || (workDeadline != null && SystemClock.elapsedRealtime() >= workDeadline)) return@onMain
            var requestedSound = false
            var requestedVibration = false
            var requestedNotification = false
            val notifications = notificationsAllowed(context)
            if (foreground) {
                bridge.get()?.delivered(event)
                requestedSound = readings(context, channelId).condition == "allowed"
                play(context, channelId, event.id, event.diagnosticEpoch, trace, revision, sequence, trigger = trigger)
                val audio = context.getSystemService(AudioManager::class.java)
                val channel = if (Build.VERSION.SDK_INT >= 26) notificationManager(context).getNotificationChannel(channelId) else null
                if (!prefs(context).getBoolean("channel_restricted", false) && event.settings.vibration && audio.ringerMode != AudioManager.RINGER_MODE_SILENT &&
                    notificationManager(context).currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL &&
                    (Build.VERSION.SDK_INT < 26 || (channel?.shouldVibrate() == true && channel.importance >= NotificationManager.IMPORTANCE_DEFAULT))) {
                    playingId = event.id
                    playingSource = trigger
                    requestedVibration = true
                    if (Build.VERSION.SDK_INT >= 26) vibrator(context).vibrate(VibrationEffect.createWaveform(longArrayOf(0, 160, 120, 160), -1), attributes())
                    else @Suppress("DEPRECATION") vibrator(context).vibrate(longArrayOf(0, 160, 120, 160), -1)
                }
            } else if (notifications && !prefs(context).getBoolean("channel_restricted", false)) {
                notify(context, event, channelId, silent = false)
                requestedNotification = true
                requestedSound = readings(context, channelId).condition == "allowed"
                requestedVibration = event.settings.vibration && (Build.VERSION.SDK_INT < 26 || notificationManager(context).getNotificationChannel(channelId)?.shouldVibrate() == true)
            }
            val channelAllowed = Build.VERSION.SDK_INT < 26 || (notificationManager(context).getNotificationChannel(channelId)?.importance ?: 0) != NotificationManager.IMPORTANCE_NONE
            lastOutputRequestedUtc = System.currentTimeMillis()
            lastOutputObservation = observation(id, revision, event.diagnosticEpoch, trigger)
            diagnostic(context, "rest.output", "output", reason = if (!foreground && !notifications) "permission_denied" else "none",
                id = id, session = event.sessionId, epoch = event.diagnosticEpoch, operation = trace,
                attributes = mapOf("revision" to revision, "round" to sequence, "next_round" to event.sequence, "actual_utc" to System.currentTimeMillis(), "foreground" to foreground,
                    "sound_requested" to requestedSound, "vibration_requested" to requestedVibration, "notification_requested" to requestedNotification, "trigger" to trigger,
                    "notifications_allowed" to notifications, "channel_allowed" to channelAllowed, "source" to source(trigger)))
        }
        if (event.nextAt != null && (foreground || notificationsAllowed(context)) &&
            RestAlertsStore.withDatabase(context) { RestAlertsStore.valid(it, event) }) {
            schedule(context, event.id, event.revision, event.nextAt, event.sequence, trace, event.diagnosticEpoch, trigger)
        }
    }
}

class RestEndedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != RestAlertsRuntime.ACTION || !intent.hasExtra("sequence")) return
        val pending = goAsync()
        RestAlertsRuntime.io.execute {
            try {
                RestAlertsRuntime.callback(context, intent)
                RestAlertsRuntime.deliver(context.applicationContext, intent.getIntExtra("id", -1),
                intent.getIntExtra("revision", -1), intent.getIntExtra("sequence", -1), intent.getStringExtra("diagnostic_operation"), "alarm",
                    if (intent.hasExtra("diagnostic_epoch")) intent.getLongExtra("diagnostic_epoch", -1) else null) }
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
        if (call.method == "takeInitialTap") { dartReady = true; TrainingReminderService.dartInitialized = true; result.success(initialTap); initialTap = null; return }
        if (call.method == "openSettings") {
            TrainingReminderService.settingsReturn = true
            try {
                val exact = call.argument<Boolean>("exact") == true
                val intent = if (exact && Build.VERSION.SDK_INT >= 31) Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${activity.packageName}"))
                    else if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                        .putExtra(Settings.EXTRA_CHANNEL_ID, prefs.getString("restriction_source", null)?.takeUnless { it == "unknown" } ?: prefs.getString("current_channel", RestAlertsRuntime.CHANNEL))
                    else Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                activity.startActivity(intent); result.success(null)
            } catch (_: Exception) {
                try {
                    activity.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName))
                    result.success(null)
                } catch (_: Exception) { result.error("settingsUnavailable", null, null) }
            }
            return
        }
        if (call.method == "preview") {
            RestAlertsRuntime.io.execute {
                try { RestAlertsRuntime.preview(activity) { state -> RestAlertsRuntime.main.post { result.success(mapOf("state" to state)) } } }
                catch (_: Exception) { RestAlertsRuntime.main.post { result.error("previewFailed", null, null) } }
            }
            return
        }
        RestAlertsRuntime.io.execute {
            try {
                val cancellationReason = RestAlertsRuntime.cancellationReason(call.argument<String>("cancel_reason"))
                val output: Any? = when (call.method) {
                    "initialRecoveryIsWarm" -> (TrainingReminderService.dartInitialized || TrainingReminderService.state == "running")
                    "takeSettingsReturn" -> TrainingReminderService.settingsReturn.also { TrainingReminderService.settingsReturn = false }
                    "startTraining" -> { TrainingReminderService.start(activity.applicationContext, call.argument<Number>("session_id")!!.toInt(), call.argument<String>("title")!!, call.argument<String>("body")!!); null }
                    "reconcileTraining" -> { RestAlertsRuntime.recoveryObservation(call.argument<String>("recovery")); TrainingReminderService.reconcile(activity.applicationContext); null }
                    "suspendTraining" -> { TrainingReminderService.stopCurrent("restore_guard"); null }
                    "trainingLabels" -> { TrainingReminderService.updateLabels(activity.applicationContext, call.argument<String>("title")!!, call.argument<String>("body")!!); null }
                    "deliveryStatus" -> RestDeliveryStatusReader.read(activity.applicationContext)
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
                        RestAlertsRuntime.schedule(activity, call.argument<Number>("id")!!.toInt(), call.argument<Number>("revision")!!.toInt(), at.toLong(), call.argument<Number>("delivery_sequence")?.toInt() ?: 0, call.argument<String>("diagnostic_operation"), (call.argument<Number>("dataset_epoch") ?: call.argument<Number>("diagnostic_epoch"))?.toLong(), call.argument<String>("diagnostic_trigger") ?: "unknown"); null
                    }
                    "deliver" -> { RestAlertsRuntime.deliver(activity, call.argument<Number>("id")!!.toInt(), call.argument<Number>("revision")!!.toInt(), call.argument<Number>("sequence")?.toInt() ?: 0, call.argument<String>("diagnostic_operation"), call.argument<String>("diagnostic_trigger") ?: "unknown", call.argument<Number>("dataset_epoch")?.toLong()); null }
                    "cancelExcept" -> { RestAlertsRuntime.cancelExcept(activity, (call.argument<List<Number>>("ids") ?: emptyList()).map { it.toInt().toString() }.toSet(), call.argument<String>("diagnostic_operation"), call.argument<String>("diagnostic_trigger") ?: "platform_cleanup", cancellationReason); null }
                    "refreshNotification" -> { RestAlertsRuntime.refreshNotification(activity,call.argument<Number>("id")!!.toInt(),call.argument<Number>("revision")!!.toInt()); null }
                    "stopOutput" -> { RestAlertsRuntime.stopOutput(activity, call.argument<Number>("id")!!.toInt(), call.argument<String>("diagnostic_operation"), call.argument<String>("diagnostic_trigger") ?: "platform_cleanup", cancellationReason); null }
                    "soundStatus" -> RestAlertsRuntime.soundStatus(activity)
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
