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
        db.execSQL("CREATE TABLE rest_alert_preferences (id INTEGER PRIMARY KEY, enabled INTEGER)")
        db.execSQL("CREATE TABLE rest_alerts (id INTEGER PRIMARY KEY, session_id INTEGER, exercise_id INTEGER, set_number INTEGER, revision INTEGER, due_at INTEGER, state TEXT, title TEXT, body TEXT, consumed_at INTEGER)")
        db.execSQL("INSERT INTO workout_sessions VALUES (1, 'in_progress', 7, 2, 3, NULL)")
        db.execSQL("INSERT INTO session_exercises VALUES (2, 1)")
        db.execSQL("INSERT INTO session_sets VALUES (5, 123)")
        db.execSQL("INSERT INTO rest_alert_preferences VALUES (1, 1)")
        db.execSQL("INSERT INTO rest_alerts VALUES (7, 1, 2, 3, 4, $due, 'pending', 'Rest ended', 'A set 3', NULL)")
        db.version = 3
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

    @Test fun unsupportedSchemaIsNeverUpgraded() {
        db.version = 2
        try {
            RestAlertsStore.withDatabase(context) { error("mustNotRun") }
            fail("Expected schema rejection")
        } catch (error: IllegalStateException) { assertEquals("unsupportedDatabase", error.message) }
        assertEquals(2, db.version)
    }
}

