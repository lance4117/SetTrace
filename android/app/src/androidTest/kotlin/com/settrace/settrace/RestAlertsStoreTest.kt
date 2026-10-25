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
        RestAlertsRuntime.cancelExcept(context, emptySet())
        db.close()
        val prefs = context.getSharedPreferences("rest_alerts_native", Context.MODE_PRIVATE)
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
        assertNull(RestAlertsStore.claim(db, 7, 4, due, 9, observe))
        assertEquals("old_round", observations.last().reason)
        db.execSQL("UPDATE rest_alert_preferences SET enabled=0")
        assertNull(RestAlertsStore.claim(db, 7, 4, due, observer = observe))
        assertEquals("user_disabled", observations.last().reason)
        db.execSQL("UPDATE rest_alert_preferences SET enabled=1")
        assertNotNull(RestAlertsStore.claim(db, 7, 4, due) { throw IllegalStateException("PRIVATE observer failure") })
        db.execSQL("UPDATE rest_alerts SET acknowledged_at=123")
        assertNull(RestAlertsStore.claim(db, 7, 4, due, 1, observe))
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
    @Test fun bundledAudioDecodesAndDefaultIsLongEnough() {
        for (name in listOf("rest_three_tone","rest_double_beep","rest_voice_en","rest_voice_zh")) {
            val uri = android.net.Uri.parse("android.resource://${context.packageName}/raw/$name")
            val metadata = android.media.MediaMetadataRetriever()
            try {
                metadata.setDataSource(context, uri)
                val duration = metadata.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)!!.toLong()
                assertTrue("$name too short", duration >= 1000)
                if (name == "rest_three_tone") assertTrue(duration in 1500..2000)
            } finally { metadata.release() }
        }
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
            assertNull(manager.getNotificationChannel(prefs.getString("current_channel","")!!).sound)
            manager.createNotificationChannel(android.app.NotificationChannel("qa_blocked","QA block",android.app.NotificationManager.IMPORTANCE_NONE))
            prefs.edit().putString("current_channel","qa_blocked").commit()
            RestAlertsRuntime.createChannel(context,"QA","QA")
            assertFalse(RestAlertsRuntime.notificationsAllowed(context))
            val vibrationOff = android.app.NotificationChannel("settrace_rest_v2_test_1", "QA vibration off", android.app.NotificationManager.IMPORTANCE_DEFAULT)
            vibrationOff.setSound(android.net.Uri.parse("android.resource://${context.packageName}/raw/rest_three_tone"), RestAlertsRuntime.attributes())
            vibrationOff.enableVibration(false)
            manager.createNotificationChannel(vibrationOff)
            prefs.edit().putString("current_channel", vibrationOff.id).commit()
            RestAlertsRuntime.createChannel(context,"QA","QA")
            assertFalse(manager.getNotificationChannel(prefs.getString("current_channel","")!!).shouldVibrate())
        } finally {
            manager.notificationChannels.filter { it.id !in before }.forEach { manager.deleteNotificationChannel(it.id) }
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
}

