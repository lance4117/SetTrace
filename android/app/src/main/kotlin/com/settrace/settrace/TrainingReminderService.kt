package com.settrace.settrace

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.os.*
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.util.UUID

/** Native due-time observer. All claims still go through RestAlertsStore. */
class TrainingReminderService : Service() {
    private var lease: TrainingReminderLease? = null
    private var dueTask: Runnable? = null
    private var leaseTask: Runnable? = null
    private var projected: RestScheduleToken? = null
    private var workLock: PowerManager.WakeLock? = null
    @Volatile private var stopped = false
    private var displayed: Notification? = null
    private val notificationChanges = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            RestAlertsRuntime.io.execute { reconcile(this@TrainingReminderService) }
        }
    }
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 28) {
            val filter = IntentFilter(NotificationManager.ACTION_APP_BLOCK_STATE_CHANGED).apply {
                addAction(NotificationManager.ACTION_NOTIFICATION_CHANNEL_BLOCK_STATE_CHANGED)
            }
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(notificationChanges, filter, RECEIVER_NOT_EXPORTED)
            else registerReceiver(notificationChanges, filter)
        }
    }

    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || !RestAlertsRuntime.foreground) {
            stopSelf(); return START_NOT_STICKY
        }
        try {
            ensureChannel(this)
            val session = intent.getIntExtra("session", -1)
            val epoch = intent.getLongExtra("epoch", -1)
            check(session > 0 && epoch >= 0)
            val click = PendingIntent.getActivity(this, RestNotificationOwnership.SERVICE_ID,
                Intent(this, MainActivity::class.java).apply {
                    this.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra(RestAlertsRuntime.EXTRA_SESSION, session)
                    data = android.net.Uri.parse("settrace://training-service/$session")
                }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
                else Notification.Builder(this)
            if (Build.VERSION.SDK_INT >= 31) builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            if (Build.VERSION.SDK_INT >= 26) builder.setGroup(RestNotificationOwnership.SERVICE_TAG)
                .setGroupAlertBehavior(Notification.GROUP_ALERT_SUMMARY)
            val notification = builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(intent.getStringExtra("title"))
                .setContentText(intent.getStringExtra("body")).setContentIntent(click)
                .setStyle(Notification.BigTextStyle().bigText(intent.getStringExtra("body")))
                .setOngoing(true).setOnlyAlertOnce(true).setCategory(Notification.CATEGORY_SERVICE)
                .setSound(null).setVibrate(null).build()
            displayed = notification
            // FGS uses the same tag chosen by the framework (null). Reserve a
            // negative ID so reminder cleanup never treats it as an event ID.
            if (Build.VERSION.SDK_INT >= 34) startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(NOTIFICATION_ID, notification)
            if (lease == null) lease = TrainingReminderLease(session, epoch, SystemClock.elapsedRealtime())
            check(lease!!.session == session && lease!!.epoch == epoch)
            instance = this
            state = "running"; lastReason = "none"
            transition(this, "running", "none")
            leaseTask?.let { RestAlertsRuntime.main.removeCallbacks(it) }
            leaseTask = Runnable { stop("lease_timeout") }.also {
                RestAlertsRuntime.main.postDelayed(it, (lease!!.expiresElapsed - SystemClock.elapsedRealtime()).coerceAtLeast(0))
            }
            RestAlertsRuntime.io.execute { reconcile(this) }
        } catch (error: Exception) {
            state = "failed"; transition(this, "failed", "platform"); stop("platform")
        }
        return START_NOT_STICKY
    }

    private fun usable(): Boolean {
        if (stopped) return false
        if (lease?.expired(SystemClock.elapsedRealtime()) != false) {
            stop("lease_timeout"); return false
        }
        return true
    }

    private fun project(token: RestScheduleToken?) {
        if (!usable() || projected == token) return
        dueTask?.let { RestAlertsRuntime.main.removeCallbacks(it) }
        dueTask = null; projected = token
        if (token == null) return
        RestAlertsRuntime.serviceScheduleObservation(this, token)
        dueTask = Runnable {
            if (!usable()) return@Runnable
            val deadline = minOf(SystemClock.elapsedRealtime() + 5000, lease!!.expiresElapsed)
            val lock = getSystemService(PowerManager::class.java).newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK, "com.settrace.settrace:RestDelivery")
            lock.setReferenceCounted(false); workLock = lock
            try { lock.acquire(5000) } catch (_: Exception) { stop("platform"); return@Runnable }
            RestAlertsRuntime.io.execute {
                try {
                    if (stopped || lease?.expired(SystemClock.elapsedRealtime()) != false) {
                        stop("lease_timeout"); return@execute
                    }
                    if (SystemClock.elapsedRealtime() >= deadline) { stop("timeout"); return@execute }
                    blockedReason(this, lease!!, deadline)?.let { stop(it); return@execute }
                    RestAlertsRuntime.deliver(this, token.id, token.revision, token.sequence,
                        trigger = "service_timer", expectedEpoch = token.epoch, workDeadline = deadline,
                        allowed = { !stopped && lease?.expired(SystemClock.elapsedRealtime()) == false })
                    // A failed/early claim must not spin. Other observers or a
                    // committed training change can project a new token.
                } catch (error: Exception) {
                    RestAlertsRuntime.failed(this, error); stop(if (error is RestStoreUnavailable) error.reason else "platform")
                } finally {
                    synchronized(lock) { if (lock.isHeld) lock.release() }
                    if (workLock === lock) workLock = null
                }
            }
        }.also { RestAlertsRuntime.main.postDelayed(it, (token.at - System.currentTimeMillis()).coerceAtLeast(0)) }
    }

    @Synchronized internal fun stop(reason: String) {
        if (stopped) return
        stopped = true
        dueTask?.let { RestAlertsRuntime.main.removeCallbacks(it) }
        leaseTask?.let { RestAlertsRuntime.main.removeCallbacks(it) }
        dueTask = null; leaseTask = null; projected = null
        RestAlertsRuntime.stopServicePlayback(this)
        workLock?.let { synchronized(it) { if (it.isHeld) it.release() } }; workLock = null
        state = "stopping"; lastReason = reason
        transition(this, "stopping", reason)
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        stopSelf()
    }
    override fun onTaskRemoved(rootIntent: Intent?) { stop("task_removed"); super.onTaskRemoved(rootIntent) }
    override fun onTimeout(startId: Int) { stop("timeout") }
    override fun onTimeout(startId: Int, fgsType: Int) { stop("timeout") }
    override fun onDestroy() {
        stop(lastReason.takeUnless { it == "none" } ?: "unknown")
        if (instance === this) instance = null
        state = "stopped"
        transition(this, "stopped", lastReason)
        if (Build.VERSION.SDK_INT >= 28) try { unregisterReceiver(notificationChanges) } catch (_: Exception) {}
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "settrace_training_service_v1"
        const val NOTIFICATION_ID = -10001
        val runtimeInstance: String = UUID.randomUUID().toString().replace("-", "")
        @Volatile private var instance: TrainingReminderService? = null
        @Volatile var state = "stopped"; private set
        @Volatile var lastReason = "none"; private set
        @Volatile var dartInitialized = false
        @Volatile var settingsReturn = false
        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= 26) {
                val prefs = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
                val name = prefs.getString("service_title", "Training reminders")!!
                context.getSystemService(NotificationManager::class.java).createNotificationChannel(
                    NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_LOW).apply {
                        setSound(null, null); enableVibration(false); setShowBadge(false)
                    })
            }
        }
        internal fun channelAllowed(context: Context): Boolean = Build.VERSION.SDK_INT < 26 ||
            context.getSystemService(NotificationManager::class.java).getNotificationChannel(CHANNEL)?.importance?.let { it > 0 } == true
        private fun blockedReason(context: Context, lease: TrainingReminderLease, deadlineElapsed: Long? = null): String? {
            if (!RestAlertsRuntime.notificationsAllowed(context) || !channelAllowed(context)) return "permission_lost"
            return try { RestAlertsStore.withDatabase(context, deadlineElapsed) { db ->
                if (RestAlertsStore.epoch(db) != lease.epoch) return@withDatabase "restore_guard"
                val enabled = db.rawQuery("SELECT enabled FROM rest_alert_preferences WHERE id=1",null).use { it.moveToFirst() && it.getInt(0)==1 }
                if (!enabled) return@withDatabase "user_disabled"
                db.rawQuery("SELECT status FROM workout_sessions WHERE id=?",arrayOf(lease.session.toString())).use {
                    if (!it.moveToFirst()) "workout_discarded"
                    else if (it.getString(0)!="in_progress") "workout_saved" else null
                }
            } } catch (error: RestStoreUnavailable) { throw error }
            catch (_: Exception) { throw RestStoreUnavailable("read_failed") }
        }

        internal fun start(context: Context, session: Int, title: String, body: String) {
            if (instance != null || state == "starting") return
            if (!RestAlertsRuntime.foreground) {
                state = "blocked"; lastReason = "background"; transition(context,state,lastReason); return
            }
            val epoch = try { RestAlertsStore.withDatabase(context) {
                if (!RestAlertsStore.trainingValid(it, session)) null else RestAlertsStore.epoch(it)
            } } catch (error: Exception) {
                state = "failed"; lastReason = if (error is RestStoreUnavailable) error.reason else "read_failed"
                transition(context,state,lastReason); throw error
            }
            if (epoch == null) { state="blocked"; lastReason="invalid_session"; transition(context,state,lastReason); return }
            context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE).edit().putString("service_title", title).apply()
            ensureChannel(context)
            if (!RestAlertsRuntime.notificationsAllowed(context) || !channelAllowed(context)) {
                state = "blocked"; lastReason = "permission_denied"; transition(context, state, lastReason); return
            }
            state = "starting"; transition(context, state, "none")
            try {
                val intent = Intent(context, TrainingReminderService::class.java)
                    .putExtra("session", session).putExtra("epoch", epoch).putExtra("title", title).putExtra("body", body)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
            } catch (error: Exception) {
                state = "failed"; lastReason = "platform"; transition(context, state, lastReason); throw error
            }
        }
        internal fun reconcile(context: Context) {
            val service = instance ?: return
            val lease = service.lease ?: return
            if (lease.expired(SystemClock.elapsedRealtime())) { service.stop("lease_timeout"); return }
            try {
                blockedReason(context, lease)?.let { service.stop(it); return }
                val token = RestAlertsStore.withDatabase(context) { RestAlertsStore.current(it) }
                RestAlertsRuntime.main.post { if (instance === service) service.project(token) }
            } catch (error: Exception) { service.stop(if (error is RestStoreUnavailable) error.reason else "read_failed") }
        }
        internal fun stopCurrent(reason: String) { instance?.stop(reason) }
        internal fun updateLabels(context: Context, title: String, body: String) {
            RestAlertsRuntime.main.post {
                val service = instance ?: return@post
                val notification = service.displayed ?: return@post
                if (service.stopped || (notification.extras.getString(Notification.EXTRA_TITLE) == title &&
                    notification.extras.getString(Notification.EXTRA_TEXT) == body)) return@post
                val updated = Notification.Builder.recoverBuilder(context, notification)
                    .setContentTitle(title).setContentText(body).setStyle(Notification.BigTextStyle().bigText(body))
                    .setOnlyAlertOnce(true).build()
                service.displayed = updated
                context.getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, updated)
            }
        }
        internal fun snapshot(): Map<String, Any?> = mapOf("state" to state,
            "leaseExpiresElapsed" to instance?.lease?.expiresElapsed,
            "leaseExpired" to instance?.lease?.expired(SystemClock.elapsedRealtime()),
            "workLockHeld" to (instance?.workLock?.isHeld == true), "reason" to lastReason)
        private fun transition(context: Context, next: String, reason: String) {
            val authority = (context as? TrainingReminderService)?.lease
            RestAlertsRuntime.serviceObservation(context, next, reason,
                authority?.expiresElapsed, authority?.session, authority?.epoch)
            // Private operational metadata, excluded from platform and logical
            // backups. It is never evidence that an instance is still running.
            RestAlertsRuntime.io.execute {
                val file = AtomicFile(File(context.noBackupFilesDir, "training_reminder_control.json"))
                var stream: java.io.FileOutputStream? = null
                try {
                    stream = file.startWrite()
                    stream.write(JSONObject(mapOf("state" to next, "reason" to reason, "instance" to runtimeInstance,
                        "leaseExpiresElapsed" to (context as? TrainingReminderService)?.lease?.expiresElapsed,
                        "observedUtc" to System.currentTimeMillis())).toString().toByteArray())
                    file.finishWrite(stream)
                } catch (_: Exception) { stream?.let { file.failWrite(it) } }
            }
        }
    }
}

