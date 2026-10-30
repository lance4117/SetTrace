package com.settrace.settrace

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.util.concurrent.Executors

@RunWith(AndroidJUnit4::class)
class RestAlertsStoreTest {
    private lateinit var context: Context
    private lateinit var db: SQLiteDatabase
    private var oldPath: String? = null
    private val name = "rest-alerts-instrumented-test.db"
    private val due = 1_000_000L
    @Before fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        val prefs = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
        // Remove only markers left by this fixture's historical runs. Never
        // erase production channel restrictions to make a notification pass.
        if (prefs.getString("restriction_source",null) in setOf("qa_muted","qa_blocked","settrace_rest_v2_test_1")) {
            prefs.edit().remove("restriction_source").remove("channel_restricted").commit()
        }
        oldPath = prefs.getString("database_path", null)
        context.deleteDatabase(name)
        db = context.openOrCreateDatabase(name, Context.MODE_PRIVATE, null)
        db.execSQL("CREATE TABLE workout_sessions (id INTEGER PRIMARY KEY, status TEXT, current_rest_alert_id INTEGER, current_session_exercise_id INTEGER, current_set_number INTEGER, rest_end_at INTEGER)")
        db.execSQL("CREATE TABLE session_exercises (id INTEGER PRIMARY KEY, session_id INTEGER)")
        db.execSQL("CREATE TABLE session_sets (id INTEGER PRIMARY KEY, completed_at INTEGER)")
        db.execSQL("CREATE TABLE rest_alert_preferences (id INTEGER PRIMARY KEY, enabled INTEGER, sound_id TEXT DEFAULT 'three_tone', vibration_enabled INTEGER DEFAULT 1, repeat_enabled INTEGER DEFAULT 1, interval_seconds INTEGER DEFAULT 10)")
        db.execSQL("CREATE TABLE rest_alerts (id INTEGER PRIMARY KEY, session_id INTEGER, exercise_id INTEGER, set_number INTEGER, revision INTEGER, due_at INTEGER, state TEXT, title TEXT, body TEXT, consumed_at INTEGER, acknowledged_at INTEGER, delivery_sequence INTEGER DEFAULT 0, next_delivery_at INTEGER)")
        db.execSQL("INSERT INTO workout_sessions VALUES (1, 'in_progress', 7, 2, 3, NULL)")
        db.execSQL("INSERT INTO session_exercises VALUES (2, 1)")
        db.execSQL("INSERT INTO session_sets VALUES (5, 123)")
        db.execSQL("INSERT INTO rest_alert_preferences(id,enabled) VALUES (1, 1)")
        db.execSQL("INSERT INTO rest_alerts VALUES (7, 1, 2, 3, 4, $due, 'pending', 'Rest ended', 'A set 3', NULL, NULL, 0, NULL)")
        db.version = 4
        prefs.edit().putString("database_path", context.getDatabasePath(name).path).commit()
    }
    @After fun cleanup() {
        TrainingReminderService.stopCurrent("platform_cleanup")
        val stopDeadline=android.os.SystemClock.elapsedRealtime()+3000
        while(TrainingReminderService.state=="stopping" && android.os.SystemClock.elapsedRealtime()<stopDeadline) Thread.sleep(25)
        if(db.version !in listOf(4,5,6)) db.version=4
        db.execSQL("UPDATE rest_alert_preferences SET enabled=0")
        RestAlertsRuntime.cancelExcept(context, emptySet())
        db.close()
        val prefs = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
        prefs.edit().remove("identity_7").commit()
        if (oldPath == null) prefs.edit().remove("database_path").commit()
        else prefs.edit().putString("database_path", oldPath).commit()
        context.deleteDatabase(name)
    }
    @Test fun normalizedRestStillClaimsOnceWithoutChangingTraining() {
        assertNotNull(RestAlertsStore.claim(db, 7, 4, due))
        assertNull(RestAlertsStore.claim(db, 7, 4, due))
        db.rawQuery("SELECT completed_at FROM session_sets", null).use {
            assertTrue(it.moveToFirst()); assertEquals(123L, it.getLong(0))
        }
        db.rawQuery("SELECT current_set_number, rest_end_at FROM workout_sessions", null).use {
            assertTrue(it.moveToFirst()); assertEquals(3, it.getInt(0)); assertTrue(it.isNull(1))
        }
    }
    @Test fun observedRejectionsComeFromTheSameTransactionAndObserverCannotChangeClaims() {
        val observations = mutableListOf<RestClaimObservation>()
        val observe: (RestClaimObservation) -> Unit = { assertFalse(db.inTransaction()); observations.add(it) }
        assertNull(RestAlertsStore.claim(db, 7, 3, due, observer = observe))
        assertEquals("old_revision", observations.last().reason)
        assertNull(RestAlertsStore.claim(db, 7, 4, due, 9, observer = observe))
        assertEquals("old_round", observations.last().reason)
        db.execSQL("UPDATE rest_alert_preferences SET enabled=0")
        assertNull(RestAlertsStore.claim(db, 7, 4, due, observer = observe))
        assertEquals("user_disabled", observations.last().reason)
        db.execSQL("UPDATE rest_alert_preferences SET enabled=1")
        assertNotNull(RestAlertsStore.claim(db, 7, 4, due) { throw IllegalStateException("PRIVATE observer failure") })
        db.execSQL("UPDATE rest_alerts SET acknowledged_at=123")
        assertNull(RestAlertsStore.claim(db, 7, 4, due, 1, observer = observe))
        assertEquals("already_acknowledged", observations.last().reason)
    }
    @Test fun staleRevisionCancellationAndPreferenceAreRejected() {
        assertNull(RestAlertsStore.claim(db, 7, 3, due))
        assertNull(RestAlertsStore.claim(db, 999, 4, due))
        db.execSQL("UPDATE rest_alert_preferences SET enabled=0")
        assertNull(RestAlertsStore.claim(db, 7, 4, due))
        db.execSQL("UPDATE rest_alert_preferences SET enabled=1")
        db.execSQL("UPDATE rest_alerts SET state='cancelled', revision=5")
        assertNull(RestAlertsStore.claim(db, 7, 4, due))
        assertNull(RestAlertsStore.claim(db, 7, 5, due))
    }
    @Test fun wrongOwnerTargetAndEndedSessionAreRejected() {
        db.execSQL("UPDATE session_exercises SET session_id=99")
        assertNull(RestAlertsStore.claim(db, 7, 4, due))
        db.execSQL("UPDATE session_exercises SET session_id=1")
        db.execSQL("UPDATE workout_sessions SET current_set_number=4")
        assertNull(RestAlertsStore.claim(db, 7, 4, due))
        db.execSQL("UPDATE workout_sessions SET current_set_number=3, status='completed'")
        assertNull(RestAlertsStore.claim(db, 7, 4, due))
    }
    @Test fun earlyIsPendingAndLateExpires() {
        assertNull(RestAlertsStore.claim(db, 7, 4, due-1))
        assertNull(RestAlertsStore.claim(db, 7, 4, due+30_001))
        db.rawQuery("SELECT state FROM rest_alerts", null).use {
            assertTrue(it.moveToFirst()); assertEquals("expired", it.getString(0))
        }
    }
    @Test fun concurrentConnectionsOnlyOneCanConsume() {
        val pool = Executors.newFixedThreadPool(2)
        try {
            val jobs = (1..2).map { pool.submit<Boolean> {
                RestAlertsStore.withDatabase(context) { connection ->
                    RestAlertsStore.claim(connection, 7, 4, due) != null
                }
            } }
            assertEquals(1, jobs.count { it.get() })
        } finally { pool.shutdown() }
    }

    @Test fun actualBackgroundAlarmDeliversOnceWithNotification() {
        val manager = RestAlertsRuntime.notificationManager(context)
        RestAlertsRuntime.createChannel(context, "Rest QA", "Timing test")
        Assume.assumeTrue("Needs granted notification and exact permissions",
            RestAlertsRuntime.notificationsAllowed(context) && RestAlertsRuntime.exactAllowed(context))
        val deadline = System.currentTimeMillis() + 2_000
        db.execSQL("UPDATE rest_alerts SET due_at=?", arrayOf(deadline))
        RestAlertsRuntime.foreground = false
        RestAlertsRuntime.schedule(context, 7, 4, deadline)
        var observed: Long? = null
        val limit = deadline + 5_000
        while (System.currentTimeMillis() <= limit) {
            db.rawQuery("SELECT consumed_at FROM rest_alerts WHERE id=7", null).use {
                if (it.moveToFirst() && !it.isNull(0)) observed = it.getLong(0)
            }
            if (observed != null && manager.activeNotifications.any { it.id == 7 }) break
            Thread.sleep(100)
        }
        assertNotNull("Alarm did not consume", observed)
        assertTrue("Delivery exceeded five seconds", observed!! - deadline <= 5_000)
        assertEquals(1, manager.activeNotifications.count { it.id == 7 })
        RestAlertsRuntime.deliver(context, 7, 4)
        assertEquals(1, manager.activeNotifications.count { it.id == 7 })
        println("REST_QA deadline=$deadline consumed=$observed latency=${observed!!-deadline}")
    }

    @Test fun replacedAlarmAndCancellationNeverNotifyAtOldDeadline() {
        RestAlertsRuntime.createChannel(context, "Rest QA", "Timing test")
        Assume.assumeTrue(RestAlertsRuntime.exactAllowed(context))
        val original = System.currentTimeMillis() + 700
        val updated = original + 1_400
        db.execSQL("UPDATE rest_alerts SET due_at=?, revision=5", arrayOf(updated))
        RestAlertsRuntime.schedule(context, 7, 4, original)
        RestAlertsRuntime.schedule(context, 7, 5, updated)
        Thread.sleep(1_000)
        db.rawQuery("SELECT state FROM rest_alerts WHERE id=7", null).use {
            assertTrue(it.moveToFirst()); assertEquals("pending", it.getString(0))
        }
        db.execSQL("UPDATE rest_alerts SET state='cancelled', revision=6")
        RestAlertsRuntime.cancelExcept(context, emptySet())
        Thread.sleep(1_400)
        assertFalse(RestAlertsRuntime.notificationManager(context).activeNotifications.any { it.id == 7 })
        assertNull(RestAlertsStore.claim(db, 7, 5, updated))
    }

    @Test fun repeatingRoundsClaimOnceAndAcknowledgeStopsOldCallbacks() {
        var event = RestAlertsStore.claim(db, 7, 4, due)!!
        for (round in 1..5) {
            val now = due + round * 10_000L
            assertNull(RestAlertsStore.claim(db, 7, 4, now - 1, event.sequence))
            val next = RestAlertsStore.claim(db, 7, 4, now, event.sequence)!!
            assertNull(RestAlertsStore.claim(db, 7, 4, now, event.sequence))
            assertEquals(round + 1, next.sequence)
            event = next
        }
        db.execSQL("UPDATE rest_alerts SET acknowledged_at=?, next_delivery_at=NULL", arrayOf(due+50_000L))
        assertNull(RestAlertsStore.claim(db, 7, 4, due+60_000L, event.sequence))
    }
    @Test fun lateRepeatDoesNotReplayMissedIntervals() {
        val first = RestAlertsStore.claim(db, 7, 4, due)!!
        val next = RestAlertsStore.claim(db, 7, 4, due+120_000, first.sequence)!!
        assertEquals(due+130_000, next.nextAt)
        assertNull(RestAlertsStore.claim(db, 7, 4, due+120_000, next.sequence))
    }
    @Test fun systemSoundChannelIsStableAndPreviewDoesNotNotifyOrClaim() {
        val manager = RestAlertsRuntime.notificationManager(context)
        RestAlertsRuntime.createChannel(context,"QA","QA")
        val prefs = context.getSharedPreferences("rest_alerts_native",Context.MODE_PRIVATE)
        val first = prefs.getString("current_channel",null)
        for (legacy in listOf("three_tone","double_beep","voice")) {
            db.execSQL("UPDATE rest_alert_preferences SET sound_id=?",arrayOf(legacy))
            RestAlertsRuntime.createChannel(context,"QA","QA")
            assertEquals(first,prefs.getString("current_channel",null))
        }
        assertTrue(manager.notificationChannels.count { it.id.startsWith("settrace_rest_system_v1_") } <= 2)
        val before = manager.activeNotifications.map { it.id }
        val finished = java.util.concurrent.CountDownLatch(1)
        RestAlertsRuntime.preview(context) { finished.countDown() }
        RestAlertsRuntime.stopPreview(context)
        assertTrue(finished.await(12,java.util.concurrent.TimeUnit.SECONDS))
        assertEquals(before,manager.activeNotifications.map { it.id })
        db.rawQuery("SELECT delivery_sequence FROM rest_alerts WHERE id=7",null).use { assertTrue(it.moveToFirst()); assertEquals(0,it.getInt(0)) }
    }

    @Test fun contentRefreshIsSilentAndNeverClaimsAnotherRound() {
        RestAlertsRuntime.createChannel(context,"QA","QA")
        val now = System.currentTimeMillis()
        db.execSQL("UPDATE rest_alerts SET due_at=?",arrayOf(now))
        RestAlertsRuntime.foreground = false
        RestAlertsRuntime.deliver(context,7,4)
        val manager = RestAlertsRuntime.notificationManager(context)
        assertTrue(manager.activeNotifications.any { it.id == 7 })
        db.execSQL("UPDATE rest_alerts SET title='Updated',revision=5")
        RestAlertsRuntime.refreshNotification(context,7,5)
        val updated = manager.activeNotifications.single { it.id == 7 }.notification
        assertEquals("Updated",updated.extras.getString(android.app.Notification.EXTRA_TITLE))
        assertTrue(updated.flags and android.app.Notification.FLAG_ONLY_ALERT_ONCE != 0)
        db.rawQuery("SELECT delivery_sequence FROM rest_alerts WHERE id=7",null).use { assertTrue(it.moveToFirst());assertEquals(1,it.getInt(0)) }
        manager.cancel(7)
        RestAlertsRuntime.refreshNotification(context,7,5)
        assertFalse(manager.activeNotifications.any { it.id == 7 })
    }

    @Test fun everyIntervalUsesActualClaimTime() {
        for (interval in listOf(10,15,30,60)) {
            db.execSQL("UPDATE rest_alert_preferences SET interval_seconds=?", arrayOf(interval))
            db.execSQL("UPDATE rest_alerts SET state='pending', consumed_at=NULL, delivery_sequence=0, next_delivery_at=NULL")
            val first = RestAlertsStore.claim(db, 7, 4, due)!!
            assertEquals(due + interval * 1000L, first.nextAt)
            val delayed = due + 300_000
            val next = RestAlertsStore.claim(db, 7, 4, delayed, first.sequence)!!
            assertEquals(delayed + interval * 1000L, next.nextAt)
        }
    }
    @Test fun oldIntentAndAcknowledgedOutputAreRejected() {
        RestEndedReceiver().onReceive(context, android.content.Intent(RestAlertsRuntime.ACTION)
            .putExtra("id",7).putExtra("revision",4))
        val event = RestAlertsStore.claim(db,7,4,due)!!
        assertTrue(RestAlertsStore.valid(db,event))
        db.execSQL("UPDATE rest_alerts SET acknowledged_at=?",arrayOf(due))
        assertFalse(RestAlertsStore.valid(db,event))
        RestAlertsRuntime.stopOutput(context,7)
        assertFalse(RestAlertsRuntime.notificationManager(context).activeNotifications.any { it.id == 7 })
    }
    @Test fun switchingSoundsPreservesSystemMuteAndBlock() {
        if (android.os.Build.VERSION.SDK_INT < 26) return
        val prefs = context.getSharedPreferences("rest_alerts_native",Context.MODE_PRIVATE)
        val previous = prefs.getString("current_channel",null)
        val oldRestriction = prefs.getString("restriction_source",null)
        val oldRestricted = prefs.getBoolean("channel_restricted",false)
        val manager = RestAlertsRuntime.notificationManager(context)
        val before = manager.notificationChannels.map { it.id }.toSet()
        try {
            // Create the ordinary double-beep channel first, then switch away and mute.
            db.execSQL("UPDATE rest_alert_preferences SET sound_id='double_beep'")
            RestAlertsRuntime.createChannel(context,"QA","QA")
            val muted = android.app.NotificationChannel("qa_muted", "QA mute", android.app.NotificationManager.IMPORTANCE_DEFAULT)
            muted.setSound(null,null)
            manager.createNotificationChannel(muted)
            prefs.edit().putString("current_channel","qa_muted").commit()
            RestAlertsRuntime.createChannel(context,"QA","QA")
            repeat(3) {
                RestAlertsRuntime.createChannel(context,"QA","QA")
                assertTrue(manager.getNotificationChannel(prefs.getString("current_channel","")!!).sound == null || prefs.getBoolean("channel_restricted",false))
            }
            manager.createNotificationChannel(android.app.NotificationChannel("qa_blocked","QA block",android.app.NotificationManager.IMPORTANCE_NONE))
            prefs.edit().remove("restriction_source").putString("current_channel","qa_blocked").commit()
            RestAlertsRuntime.createChannel(context,"QA","QA")
            assertFalse(RestAlertsRuntime.notificationsAllowed(context))
            val vibrationOff = android.app.NotificationChannel("settrace_rest_v2_test_1", "QA vibration off", android.app.NotificationManager.IMPORTANCE_DEFAULT)
            vibrationOff.setSound(android.net.Uri.parse("android.resource://${context.packageName}/raw/rest_three_tone"), RestAlertsRuntime.attributes())
            vibrationOff.enableVibration(false)
            manager.createNotificationChannel(vibrationOff)
            prefs.edit().remove("restriction_source").putString("current_channel", vibrationOff.id).commit()
            RestAlertsRuntime.createChannel(context,"QA","QA")
            assertTrue(!manager.getNotificationChannel(prefs.getString("current_channel","")!!).shouldVibrate() || prefs.getBoolean("channel_restricted",false))
            db.execSQL("UPDATE rest_alert_preferences SET vibration_enabled=0")
            RestAlertsRuntime.createChannel(context,"QA","QA")
            db.execSQL("UPDATE rest_alert_preferences SET vibration_enabled=1")
            RestAlertsRuntime.createChannel(context,"QA","QA")
            assertTrue(!manager.getNotificationChannel(prefs.getString("current_channel","")!!).shouldVibrate() || prefs.getBoolean("channel_restricted",false))
        } finally {
            manager.notificationChannels.filter { it.id !in before }.forEach { manager.deleteNotificationChannel(it.id) }
            prefs.edit().putString("restriction_source",oldRestriction).putBoolean("channel_restricted",oldRestricted).commit()
            if (previous == null) prefs.edit().remove("current_channel").commit()
            else prefs.edit().putString("current_channel",previous).commit()
        }
    }

    @Test fun unsupportedSchemaIsNeverUpgraded() {
        db.version = 2
        try {
            RestAlertsStore.withDatabase(context) { error("mustNotRun") }
            fail("Expected schema rejection")
        } catch (error: IllegalStateException) { assertEquals("unsupportedDatabase", error.message) }
        assertEquals(2, db.version)
    }

    @Test fun threeSourcesClaimOnlyOneRoundAndNeverStealTheNext() {
        val workers = Executors.newFixedThreadPool(3)
        try {
            repeat(2) { round ->
                val at = if (round == 0) due else due + 10_000
                val barrier = java.util.concurrent.CountDownLatch(1)
                val attempts = (1..3).map { workers.submit<RestDelivery?> {
                    barrier.await()
                    SQLiteDatabase.openDatabase(context.getDatabasePath(name).path, null, SQLiteDatabase.OPEN_READWRITE).use {
                        RestAlertsStore.claim(it, 7, 4, at, round)
                    }
                } }
                barrier.countDown()
                assertEquals(1, attempts.map { it.get(5, java.util.concurrent.TimeUnit.SECONDS) }.count { it != null })
                assertNull(RestAlertsStore.claim(db,7,4,at,round))
            }
        } finally { workers.shutdownNow() }
    }

    @Test fun epochAndEveryRestoreGuardRejectAllObservers() {
        db.execSQL("CREATE TABLE backup_state(id INTEGER PRIMARY KEY, epoch INTEGER)")
        db.execSQL("INSERT INTO backup_state VALUES(1,3)")
        db.execSQL("CREATE TABLE backup_operations(kind TEXT, phase TEXT)")
        db.version = 6
        assertNull(RestAlertsStore.claim(db,7,4,due,expectedEpoch=2))
        for (phase in listOf("preparing","protected","indeterminate")) {
            db.execSQL("DELETE FROM backup_operations")
            db.execSQL("INSERT INTO backup_operations VALUES('restore',?)",arrayOf(phase))
            assertNull(RestAlertsStore.claim(db,7,4,due,expectedEpoch=3))
        }
        db.execSQL("DELETE FROM backup_operations")
        val claimed = RestAlertsStore.claim(db,7,4,due,expectedEpoch=3)!!
        db.execSQL("UPDATE backup_state SET epoch=4")
        assertFalse(RestAlertsStore.valid(db,claimed))
        assertNull(RestAlertsStore.claim(db,7,4,due+10_000,1,expectedEpoch=3))
    }

    @Test fun staleScheduleCannotOverwriteACommittedFutureRound() {
        val futureDue = System.currentTimeMillis()+600_000
        db.execSQL("UPDATE rest_alerts SET due_at=?",arrayOf(futureDue))
        RestAlertsRuntime.schedule(context,7,4,futureDue)
        val accepted = RestAlertsRuntime.lastScheduleObservation
        val event = RestAlertsStore.claim(db,7,4,futureDue)!!
        RestAlertsRuntime.schedule(context,7,4,event.nextAt!!,event.sequence)
        val future = RestAlertsRuntime.lastScheduleObservation
        assertNotSame(accepted, future)
        RestAlertsRuntime.schedule(context,7,4,futureDue,0)
        assertSame(future,RestAlertsRuntime.lastScheduleObservation)
        RestAlertsRuntime.cancelExcept(context, emptySet())
        assertSame(future,RestAlertsRuntime.lastScheduleObservation)
        assertTrue(context.getSharedPreferences("rest_alerts_native",Context.MODE_PRIVATE)
            .getStringSet("ids",emptySet())!!.contains("7"))
    }

    @Test fun statusQueriesHaveNoSchedulingOrTrainingSideEffects() {
        val before = RestAlertsRuntime.lastScheduleObservation
        val serviceBefore = TrainingReminderService.state
        repeat(3) {
            val status = RestDeliveryStatusReader.read(context)
            assertEquals(1,status["version"])
            val fields = status["fields"] as Map<*,*>
            assertEquals("unknown",(fields["vendorAutostart"] as Map<*,*>)["availability"])
            assertEquals("unknown",(fields["alarmArmed"] as Map<*,*>)["availability"])
        }
        assertSame(before, RestAlertsRuntime.lastScheduleObservation)
        assertEquals(serviceBefore,TrainingReminderService.state)
        db.rawQuery("SELECT delivery_sequence FROM rest_alerts WHERE id=7",null).use {
            assertTrue(it.moveToFirst()); assertEquals(0,it.getInt(0))
        }
    }

    @Test fun cleanupDoesNotOwnOngoingServiceNotification() {
        val manager = RestAlertsRuntime.notificationManager(context)
        RestAlertsRuntime.createChannel(context,"QA","QA")
        val channel = context.getSharedPreferences("rest_alerts_native",Context.MODE_PRIVATE).getString("current_channel",null)!!
        val builder = if (android.os.Build.VERSION.SDK_INT >= 26) android.app.Notification.Builder(context,channel) else android.app.Notification.Builder(context)
        manager.notify(TrainingReminderService.NOTIFICATION_ID,builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle("QA ongoing").build())
        manager.notify(81001,builder.setContentTitle("QA unrelated").build())
        try {
            RestAlertsRuntime.cancelExcept(context,emptySet())
            assertTrue(manager.activeNotifications.any { it.id==TrainingReminderService.NOTIFICATION_ID })
            assertTrue(manager.activeNotifications.any { it.id==81001 })
        } finally { manager.cancel(TrainingReminderService.NOTIFICATION_ID); manager.cancel(81001) }
    }

    @Test fun realForegroundServiceStartsOnceIdlesAndStopsWithoutClaiming() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val activity = instrumentation.startActivitySync(android.content.Intent(context, ReminderQaActivity::class.java)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
        fun awaitState(value: String) {
            val end = android.os.SystemClock.elapsedRealtime()+5000
            while (TrainingReminderService.state != value && android.os.SystemClock.elapsedRealtime()<end) Thread.sleep(25)
            assertEquals(value,TrainingReminderService.state)
        }
        try {
            db.execSQL("CREATE TABLE backup_state(id INTEGER PRIMARY KEY, epoch INTEGER)")
            db.execSQL("INSERT INTO backup_state VALUES(1,3)")
            db.execSQL("CREATE TABLE backup_operations(kind TEXT, phase TEXT)")
            db.execSQL("UPDATE rest_alerts SET due_at=?",arrayOf(System.currentTimeMillis()+600_000))
            db.version=6
            RestAlertsRuntime.createChannel(context,"QA","QA")
            TrainingReminderService.start(context,1,"QA training","Return to workout")
            awaitState("running")
            val firstLease = TrainingReminderService.snapshot()["leaseExpiresElapsed"]
            TrainingReminderService.start(context,1,"QA training","Return to workout")
            assertEquals(firstLease,TrainingReminderService.snapshot()["leaseExpiresElapsed"])
            val notificationDeadline = android.os.SystemClock.elapsedRealtime()+5000
            while (RestAlertsRuntime.notificationManager(context).activeNotifications.none { it.id==TrainingReminderService.NOTIFICATION_ID }
                && android.os.SystemClock.elapsedRealtime()<notificationDeadline) Thread.sleep(25)
            assertTrue(RestAlertsRuntime.notificationManager(context).activeNotifications.any { it.id==TrainingReminderService.NOTIFICATION_ID })
            RestAlertsRuntime.cancelExcept(context,emptySet())
            assertTrue(RestAlertsRuntime.notificationManager(context).activeNotifications.any { it.id==TrainingReminderService.NOTIFICATION_ID })
            TrainingReminderService.updateLabels(context,"训练提醒运行中","返回当前训练；后台提醒仍可能延迟。")
            val labelDeadline=android.os.SystemClock.elapsedRealtime()+3000
            while(RestAlertsRuntime.notificationManager(context).activeNotifications.none {
                it.id==TrainingReminderService.NOTIFICATION_ID && it.notification.extras.getString(android.app.Notification.EXTRA_TITLE)=="训练提醒运行中"
            } && android.os.SystemClock.elapsedRealtime()<labelDeadline) Thread.sleep(25)
            assertEquals("训练提醒运行中",RestAlertsRuntime.notificationManager(context).activeNotifications
                .single {it.id==TrainingReminderService.NOTIFICATION_ID}.notification.extras.getString(android.app.Notification.EXTRA_TITLE))
            assertEquals(firstLease,TrainingReminderService.snapshot()["leaseExpiresElapsed"])
            db.rawQuery("SELECT delivery_sequence FROM rest_alerts",null).use { assertTrue(it.moveToFirst()); assertEquals(0,it.getInt(0)) }
            db.execSQL("UPDATE rest_alert_preferences SET enabled=0")
            TrainingReminderService.reconcile(context)
            awaitState("stopped")
            val cleanupDeadline = android.os.SystemClock.elapsedRealtime()+5000
            while (RestAlertsRuntime.notificationManager(context).activeNotifications.any { it.id==TrainingReminderService.NOTIFICATION_ID }
                && android.os.SystemClock.elapsedRealtime()<cleanupDeadline) Thread.sleep(25)
            assertFalse(RestAlertsRuntime.notificationManager(context).activeNotifications.any { it.id==TrainingReminderService.NOTIFICATION_ID })
        } finally {
            TrainingReminderService.stopCurrent("platform_cleanup")
            instrumentation.runOnMainSync { activity.finish() }
        }
    }

    @Test fun serviceBackgroundStartAndUnreadableDatabaseNeverProduceRunning() {
        RestAlertsRuntime.foreground=false
        TrainingReminderService.start(context,1,"QA","QA")
        assertEquals("blocked",TrainingReminderService.state)
        val prefs=context.getSharedPreferences("rest_alerts_native",Context.MODE_PRIVATE)
        val original=prefs.getString("database_path",null)
        try {
            prefs.edit().putString("database_path",context.getDatabasePath("missing-service-qa.db").path).commit()
            RestAlertsRuntime.foreground=true
            try { TrainingReminderService.start(context,1,"QA","QA"); fail("Expected missing database rejection") }
            catch (_: IllegalStateException) { assertEquals("failed",TrainingReminderService.state) }
        } finally { prefs.edit().putString("database_path",original).commit(); RestAlertsRuntime.foreground=false }
    }

    @Test fun serviceAndAlarmInBackgroundShareTheRoundAndReleaseShortLock() {
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        val activity=instrumentation.startActivitySync(android.content.Intent(context,ReminderQaActivity::class.java)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
        try {
            db.execSQL("CREATE TABLE backup_state(id INTEGER PRIMARY KEY,epoch INTEGER)")
            db.execSQL("INSERT INTO backup_state VALUES(1,3)")
            db.execSQL("CREATE TABLE backup_operations(kind TEXT,phase TEXT)")
            db.version=6
            val actualDue=System.currentTimeMillis()+2500
            db.execSQL("UPDATE rest_alerts SET due_at=?",arrayOf(actualDue))
            RestAlertsRuntime.createChannel(context,"QA","QA")
            TrainingReminderService.start(context,1,"QA training","Return to workout")
            val started=android.os.SystemClock.elapsedRealtime()+5000
            while(TrainingReminderService.state!="running" && android.os.SystemClock.elapsedRealtime()<started) Thread.sleep(25)
            assertEquals("running",TrainingReminderService.state)
            RestAlertsRuntime.schedule(context,7,4,actualDue,epoch=3)
            instrumentation.runOnMainSync { activity.moveTaskToBack(true) }
            val end=System.currentTimeMillis()+7000
            var sequence=0
            while(System.currentTimeMillis()<end) {
                db.rawQuery("SELECT delivery_sequence FROM rest_alerts",null).use { it.moveToFirst(); sequence=it.getInt(0) }
                if(sequence>0 && TrainingReminderService.snapshot()["workLockHeld"]==false) break
                Thread.sleep(25)
            }
            assertEquals(1,sequence)
            assertEquals(false,TrainingReminderService.snapshot()["workLockHeld"])
            val notificationEnd=System.currentTimeMillis()+2000
            while(RestAlertsRuntime.notificationManager(context).activeNotifications.none {it.id==7} && System.currentTimeMillis()<notificationEnd) Thread.sleep(25)
            assertTrue(RestAlertsRuntime.notificationManager(context).activeNotifications.any {it.id==7})
            // Emulate the crash cut after commit, before output: a replay of
            // the old round cannot emit again or create another service.
            val output=RestAlertsRuntime.lastOutputObservation
            RestAlertsRuntime.deliver(context,7,4,0,expectedEpoch=3)
            assertSame(output,RestAlertsRuntime.lastOutputObservation)
        } finally {
            TrainingReminderService.stopCurrent("platform_cleanup")
            instrumentation.runOnMainSync { activity.finish() }
        }
    }

    @Test fun databaseFailureInsideServiceWorkReleasesItsActualWakeLock() {
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        val activity=instrumentation.startActivitySync(android.content.Intent(context,ReminderQaActivity::class.java)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
        val prefs=context.getSharedPreferences("rest_alerts_native",Context.MODE_PRIVATE)
        val original=prefs.getString("database_path",null)
        try {
            db.execSQL("CREATE TABLE backup_state(id INTEGER PRIMARY KEY,epoch INTEGER)")
            db.execSQL("INSERT INTO backup_state VALUES(1,3)")
            db.execSQL("CREATE TABLE backup_operations(kind TEXT,phase TEXT)")
            db.version=6
            val actualDue=System.currentTimeMillis()+2500
            db.execSQL("UPDATE rest_alerts SET due_at=?",arrayOf(actualDue))
            RestAlertsRuntime.createChannel(context,"QA","QA")
            TrainingReminderService.start(context,1,"QA","QA")
            val scheduledEnd=System.currentTimeMillis()+2000
            while(RestAlertsRuntime.lastServiceScheduleObservation?.get("dueUtc")!=actualDue && System.currentTimeMillis()<scheduledEnd) Thread.sleep(25)
            assertEquals(actualDue,RestAlertsRuntime.lastServiceScheduleObservation?.get("dueUtc"))
            prefs.edit().putString("database_path",context.getDatabasePath("missing-work-budget-qa.db").path).commit()
            val stopEnd=System.currentTimeMillis()+7000
            while(TrainingReminderService.state!="stopped" && System.currentTimeMillis()<stopEnd) Thread.sleep(25)
            assertEquals("stopped",TrainingReminderService.state)
            assertEquals("read_failed",TrainingReminderService.lastReason)
            assertTrue("Service wake lock leaked after failed DB read",activeServiceWakeLocks().isEmpty())
            db.rawQuery("SELECT delivery_sequence FROM rest_alerts",null).use {it.moveToFirst();assertEquals(0,it.getInt(0))}
        } finally {
            prefs.edit().putString("database_path",original).commit()
            TrainingReminderService.stopCurrent("platform_cleanup")
            instrumentation.runOnMainSync {activity.finish()}
        }
    }

    private fun activeServiceWakeLocks(): List<String> {
        val descriptor=InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand("dumpsys power")
        val lines=android.os.ParcelFileDescriptor.AutoCloseInputStream(descriptor).bufferedReader().use {it.readLines()}
        val start=lines.indexOfFirst {it.trim().startsWith("Wake Locks:")}
        val end=lines.indexOfFirst {it.trim().startsWith("Suspend Blockers:")}
        assertTrue("Active wake lock section unavailable",start>=0 && end>start)
        // Android also prints historical ACQ/REL records. They are not held locks.
        return lines.subList(start,end).filter {it.contains("com.settrace.settrace:RestDelivery")}
    }

    @Test fun queuedServiceWorkTimesOutAndReleasesItsRealLockWithoutClaiming() {
        val instrumentation=InstrumentationRegistry.getInstrumentation()
        val activity=instrumentation.startActivitySync(android.content.Intent(context,ReminderQaActivity::class.java)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
        val release=java.util.concurrent.CountDownLatch(1)
        try {
            db.execSQL("CREATE TABLE backup_state(id INTEGER PRIMARY KEY,epoch INTEGER)")
            db.execSQL("INSERT INTO backup_state VALUES(1,3)")
            db.execSQL("CREATE TABLE backup_operations(kind TEXT,phase TEXT)")
            db.version=6
            val actualDue=System.currentTimeMillis()+2500
            db.execSQL("UPDATE rest_alerts SET due_at=?",arrayOf(actualDue))
            RestAlertsRuntime.createChannel(context,"QA","QA")
            TrainingReminderService.start(context,1,"QA","QA")
            val scheduledEnd=android.os.SystemClock.elapsedRealtime()+2000
            while(RestAlertsRuntime.lastServiceScheduleObservation?.get("dueUtc")!=actualDue && android.os.SystemClock.elapsedRealtime()<scheduledEnd) Thread.sleep(25)
            assertEquals(actualDue,RestAlertsRuntime.lastServiceScheduleObservation?.get("dueUtc"))
            val entered=java.util.concurrent.CountDownLatch(1)
            RestAlertsRuntime.io.execute {entered.countDown();release.await(12,java.util.concurrent.TimeUnit.SECONDS)}
            assertTrue(entered.await(2,java.util.concurrent.TimeUnit.SECONDS))
            val lockEnd=android.os.SystemClock.elapsedRealtime()+4000
            while(TrainingReminderService.snapshot()["workLockHeld"]!=true && android.os.SystemClock.elapsedRealtime()<lockEnd) Thread.sleep(25)
            assertEquals(true,TrainingReminderService.snapshot()["workLockHeld"])
            assertTrue(activeServiceWakeLocks().isNotEmpty())
            val output=RestAlertsRuntime.lastOutputObservation
            Thread.sleep(5200)
            assertTrue("Timed lock must release even while its worker is queued",activeServiceWakeLocks().isEmpty())
            release.countDown()
            RestAlertsRuntime.io.submit {}.get(3,java.util.concurrent.TimeUnit.SECONDS)
            val stopEnd=android.os.SystemClock.elapsedRealtime()+3000
            while(TrainingReminderService.state!="stopped" && android.os.SystemClock.elapsedRealtime()<stopEnd) Thread.sleep(25)
            assertEquals("stopped",TrainingReminderService.state)
            assertEquals("timeout",TrainingReminderService.lastReason)
            assertSame(output,RestAlertsRuntime.lastOutputObservation)
            db.rawQuery("SELECT delivery_sequence FROM rest_alerts",null).use {it.moveToFirst();assertEquals(0,it.getInt(0))}
        } finally {
            release.countDown()
            TrainingReminderService.stopCurrent("platform_cleanup")
            instrumentation.runOnMainSync {activity.finish()}
        }
    }

    @Test fun lockedDatabaseCannotClaimAfterServiceWorkBudgetExpires() {
        db.execSQL("UPDATE rest_alerts SET due_at=?",arrayOf(System.currentTimeMillis()-100))
        val worker=Executors.newSingleThreadExecutor()
        val output=RestAlertsRuntime.lastOutputObservation
        db.beginTransaction()
        try {
            val started=android.os.SystemClock.elapsedRealtime()
            val result=worker.submit<Exception?> {
                try {
                    RestAlertsRuntime.deliver(context,7,4,0,trigger="service_timer",workDeadline=started+200)
                    null
                } catch(error: Exception) {error}
            }.get(6,java.util.concurrent.TimeUnit.SECONDS)
            assertTrue("Expected bounded database refusal",result is RestStoreUnavailable || result is android.database.sqlite.SQLiteDatabaseLockedException)
            assertTrue(android.os.SystemClock.elapsedRealtime()-started<5000)
            assertSame(output,RestAlertsRuntime.lastOutputObservation)
            db.rawQuery("SELECT delivery_sequence FROM rest_alerts",null).use {it.moveToFirst();assertEquals(0,it.getInt(0))}
        } finally {db.endTransaction();worker.shutdownNow()}
    }

    @Test fun mainOutputFailurePropagatesAndNeverReplaysTheCommittedRound() {
        db.execSQL("UPDATE rest_alerts SET due_at=?",arrayOf(System.currentTimeMillis()-100))
        val output=RestAlertsRuntime.lastOutputObservation
        try {
            RestAlertsRuntime.deliver(context,7,4,0,trigger="service_timer",
                workDeadline=android.os.SystemClock.elapsedRealtime()+5000,
                allowed={
                    if(android.os.Looper.myLooper()==android.os.Looper.getMainLooper()) throw IllegalStateException("QA output failure")
                    true
                })
            fail("Expected main-thread failure")
        } catch(error: IllegalStateException) {assertEquals("QA output failure",error.message)}
        assertSame(output,RestAlertsRuntime.lastOutputObservation)
        db.rawQuery("SELECT delivery_sequence FROM rest_alerts",null).use {it.moveToFirst();assertEquals(1,it.getInt(0))}
        RestAlertsRuntime.deliver(context,7,4,0,trigger="service_timer")
        assertSame(output,RestAlertsRuntime.lastOutputObservation)
    }
}
