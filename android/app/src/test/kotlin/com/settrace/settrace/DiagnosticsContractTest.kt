package com.settrace.settrace

import org.junit.Assert.*
import org.junit.Test

class DiagnosticsContractTest {
    @Test fun durableBackupCorrelationSurvivesEpochChangeWithoutExportingLedgerId() {
        val first = envelope().apply { put("event_name", "backup.restore"); put("durable_backup_operation", "e".repeat(32)); put("dataset_epoch", 0L) }
        val second = first.toMutableMap().apply { put("event_name", "backup.settings"); put("dataset_epoch", 1L); put("process_instance", "d".repeat(32)) }
        val before = privacy.sanitize(first, generation, 2000)!!
        val after = privacy.sanitize(second, generation, 3000)!!
        assertEquals(before.event["correlation_id"], after.event["correlation_id"])
        assertFalse(String(before.eventBytes).contains("e".repeat(32)))
        first["event_name"] = "workout.complete"
        assertNull(privacy.sanitize(first, generation, 2000))
    }
    private val generation = "a".repeat(32)
    private val privacy = DiagnosticPrivacy(ByteArray(32) { 7 }, "local")
    private fun envelope() = mutableMapOf<String, Any?>(
        "schema_version" to 1, "event_name" to "workout.complete", "phase" to "committed", "outcome" to "committed", "severity" to "info",
        "reason_code" to "none", "operation_id" to "b".repeat(32), "process_instance" to "c".repeat(32), "sequence" to 1,
        "monotonic_us" to 50L, "clock_domain" to "dart", "time_utc" to 1000L, "timezone_offset_minutes" to 480,
        "dataset_epoch" to 1, "generation" to generation, "attributes" to mapOf("completed_count" to 1), "objects" to mapOf("session" to 42), "frames" to emptyList<String>()
    )
    @Test fun rejectsUnlistedDataBeforePersistence() {
        for ((field, value) in mapOf("message" to "private", "sql" to "private", "path" to "content://private")) {
            val raw = envelope(); raw[field] = value
            assertNull(privacy.sanitize(raw, generation, 2000))
        }
        val raw = envelope(); raw["attributes"] = mapOf("count" to "private")
        assertNull(privacy.sanitize(raw, generation, 2000))
        raw["attributes"] = mapOf("count" to Double.POSITIVE_INFINITY)
        assertNull(privacy.sanitize(raw, generation, 2000))
        raw["attributes"] = emptyMap<String, Any>(); raw["frames"] = listOf("/storage/user/private.kt:1")
        assertNull(privacy.sanitize(raw, generation, 2000))
    }
    @Test fun epochTypeAndNamespaceSeparateIdentitiesWithoutExposingRawId() {
        val token = privacy.objectToken("session", 1, 42, "process")
        assertEquals(token, privacy.objectToken("session", 1, 42, "another_process"))
        assertNotEquals(token, privacy.objectToken("session", 2, 42, "process"))
        assertNotEquals(token, privacy.objectToken("plan", 1, 42, "process"))
        assertNotEquals(token, DiagnosticPrivacy(ByteArray(32) { 7 }, "after_clear").objectToken("session", 1, 42, "process"))
        assertNotEquals(privacy.objectToken("session", null, 42, "one"), privacy.objectToken("session", null, 42, "two"))
        assertEquals(64, token.length)
    }
    @Test fun observedTimeClockDomainAndCommitArePreserved() {
        val record = privacy.sanitize(envelope(), generation, 2000)!!
        assertEquals(1000L, record.event["time_utc"])
        assertEquals(2000L, record.event["observed_time_utc"])
        assertEquals("dart:" + "c".repeat(32), record.event["clock_domain"])
        assertTrue(record.critical)
        assertEquals(privacy.objectToken("session", 1, 42, "c".repeat(32)), (record.event["objects"] as Map<*, *>)["session"])
        assertNull(privacy.sanitize(envelope(), "d".repeat(32), 2000))
    }
    @Test fun incidentsAreSeparateAndUnknownCodeCannotCarryExceptionText() {
        val raw = envelope(); raw["frames"] = listOf("package:settrace/core/database/app_database.dart:20:2")
        val record = privacy.sanitize(raw, generation, 2000)!!
        assertNotNull(record.incidentBytes)
        assertFalse(String(record.eventBytes).contains("app_database.dart"))
        raw["reason_code"] = "private exception message"
        assertNull(privacy.sanitize(raw, generation, 2000))
    }
    @Test fun nativeErrorFramesNeverIncludeMessagesOrExternalPaths() {
        val error = IllegalStateException("private SQL arguments")
        error.stackTrace = arrayOf(StackTraceElement("com.settrace.settrace.SomeClass", "run", "/private/user.kt", 7), StackTraceElement("private.user.Name", "value", "name", 3))
        assertEquals(listOf("com.settrace.settrace.SomeClass#run:7"), DiagnosticPrivacy.frames(error))
        assertFalse(DiagnosticJson.encode(DiagnosticPrivacy.frames(error)).contains("private"))
    }
    @Test fun previousProcessExitDoesNotInventAMonotonicOccurrenceTime() {
        val raw = envelope(); raw["event_name"] = "startup.exit"; raw["clock_domain"] = "unknown"; raw["monotonic_us"] = null
        val record = privacy.sanitize(raw, generation, 2000)!!
        assertEquals("unknown", record.event["clock_domain"])
        assertNull(record.event["monotonic_us"])
        assertTrue(DiagnosticStoredValidator.valid(record.event, false))
    }
}
