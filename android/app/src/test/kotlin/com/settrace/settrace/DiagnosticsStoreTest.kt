package com.settrace.settrace

import java.io.File
import java.io.IOException
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class DiagnosticsStoreTest {
    internal class Clock(var wall: Long = 1_800_000_000_000, var mono: Long = 1000, override var boot: String = "boot-1") : DiagnosticClock {
        override fun wallMillis() = wall
        override fun monotonicMillis() = mono
        fun advance(millis: Long) { wall += millis; mono += millis }
    }
    /** Platform JSON decoding is injected. Fixtures only decode known encoded
     * events and flat headers; Android integration tests use real JSONObject. */
    internal class Fixture {
        val clock = Clock()
        val root = Files.createTempDirectory("settrace-diagnostics-test").toFile()
        val known = mutableMapOf<String, Map<*, *>>()
        var sequence = 0
        val limits = DiagnosticLimits(events = 6200, incidents = 4000, eventSegment = 2400, incidentSegment = 2000, maxSegments = 20)
        fun decode(text: String): Map<*, *> {
            known[text]?.let { return it }
            if (!text.startsWith("{\"kind\":\"segment\"")) throw IOException("fixture rejects unknown JSON")
            val values = linkedMapOf<String, Any>()
            for (match in Regex("\"([a-z_]+)\":(?:\"([^\"]*)\"|([0-9]+))").findAll(text)) values[match.groupValues[1]] = if (match.groupValues[3].isNotEmpty()) match.groupValues[3].toLong() else match.groupValues[2]
            return values
        }
        fun store(beforeControl: (() -> Unit)? = null, beforeWrite: (() -> Unit)? = null, beforeDelete: (() -> Unit)? = null, customLimits: DiagnosticLimits = limits) = DiagnosticStore(root, clock, ::decode, customLimits, beforeControl, beforeWrite, beforeDelete)
        fun record(store: DiagnosticStore, failed: Boolean = false, frames: Boolean = false): DiagnosticRecord {
            val input = mapOf<String, Any?>(
                "schema_version" to 1, "event_name" to "workout.complete", "phase" to if (failed) "failed" else "committed", "outcome" to if (failed) "unknown" else "committed", "severity" to if (failed) "error" else "info",
                "reason_code" to if (failed) "io" else "none", "operation_id" to "b".repeat(32), "process_instance" to "c".repeat(32), "sequence" to ++sequence,
                "monotonic_us" to clock.mono * 1000, "clock_domain" to "dart", "time_utc" to clock.wall, "timezone_offset_minutes" to 480,
                "dataset_epoch" to 1, "generation" to store.generation, "attributes" to mapOf("completed_count" to 1), "objects" to mapOf("session" to 42),
                "frames" to if (frames) listOf("package:settrace/core/database/app_database.dart:20:2") else emptyList<String>()
            )
            val result = store.privacy.sanitize(input, store.generation, clock.wall)!!
            known[String(result.eventBytes)] = result.event
            if (result.incidentBytes != null) known[String(result.incidentBytes)] = mapOf("schema_version" to 1, "incident_id" to result.event["incident_id"], "time_utc" to clock.wall, "reason_code" to input["reason_code"], "frames" to input["frames"])
            return result
        }
        fun dispose() { root.deleteRecursively() }
    }

    @Test fun testTemporaryFilesStayOnDDrive() {
        assertTrue("Tests must inherit task-specific D: TEMP/TMP", System.getProperty("java.io.tmpdir").startsWith("D:", ignoreCase = true))
    }
    @Test fun lossCountsSurviveRestartButExpireWithTheirObservedRange() {
        val fixture = Fixture()
        try {
            val first = fixture.store(); first.loss("queue_overflow", 5); first.flush()
            val second = fixture.store()
            assertEquals(5L, second.lossCounts()["queue_overflow"])
            assertTrue(second.lossIntervals().containsKey("queue_overflow"))
            fixture.clock.advance(fixture.limits.retentionMillis)
            second.flush()
            assertTrue(second.lossCounts().isEmpty())
            assertFalse(fixture.store().overview().missing.contains("queue_overflow"))
        } finally { fixture.dispose() }
    }
    @Test fun rotationNeverExceedsBudgetAndContinuesRecording() {
        val fixture = Fixture()
        try {
            val store = fixture.store()
            repeat(50) { store.append(fixture.record(store, frames = true)); fixture.clock.advance(1) }
            val overview = store.overview()
            assertTrue(overview.bytes <= fixture.limits.events + fixture.limits.incidents)
            assertEquals(fixture.clock.wall - 1, overview.lastTime)
            assertTrue(overview.eventCount > 0)
            assertTrue(store.metadataBytes() <= fixture.limits.metadata)
            assertTrue(File(fixture.root, "incidents").listFiles()!!.sumOf { it.length() } <= fixture.limits.incidents)
        } finally { fixture.dispose() }
    }
    @Test fun retentionUsesMonotonicTimeDespiteWallClockRollback() {
        val fixture = Fixture()
        try {
            val store = fixture.store(); store.append(fixture.record(store))
            fixture.clock.wall -= 100_000
            assertEquals(1L, store.overview().eventCount)
            fixture.clock.mono += fixture.limits.retentionMillis
            assertEquals(0L, store.overview().eventCount)
            assertFalse("Expired loss evidence must not mark all future packages partial", store.overview().missing.contains("clock_changed"))
        } finally { fixture.dispose() }
    }
    @Test fun crossBootUnknownAgeIsExcludedAndLongInactivityExpires() {
        val fixture = Fixture()
        try {
            var store = fixture.store(); store.append(fixture.record(store)); store.flush()
            fixture.clock.boot = "boot-2"; fixture.clock.wall -= 5000; fixture.clock.mono = 10
            store = fixture.store()
            assertEquals(0L, store.overview().eventCount)
            store.append(fixture.record(store)); store.flush()
            fixture.clock.boot = "boot-3"; fixture.clock.advance(fixture.limits.retentionMillis + 1)
            assertEquals(0L, fixture.store().overview().eventCount)
        } finally { fixture.dispose() }
    }
    @Test fun disabledPolicySurvivesRestartAndFailedSaveKeepsConfirmedValue() {
        val fixture = Fixture()
        try {
            var fail = false
            val store = fixture.store(beforeControl = { if (fail) throw IOException("injected") })
            fail = true
            try { store.setEnabled(false); fail("must fail") } catch (_: IOException) { }
            assertTrue(store.enabled)
            fail = false; store.setEnabled(false)
            val restarted = fixture.store()
            assertFalse(restarted.enabled)
            restarted.append(fixture.record(restarted))
            assertEquals(0L, restarted.overview().eventCount)
        } finally { fixture.dispose() }
    }
    @Test fun corruptOrUnknownControlDoesNotDefaultBackToEnabled() {
        val fixture = Fixture()
        try {
            fixture.store()
            File(fixture.root, "control.properties").writeText("version=99\nenabled=true\n")
            val store = fixture.store()
            assertFalse(store.enabled)
            assertTrue(store.overview().limited)
            assertTrue(store.overview().missing.contains("corrupt_control"))
            store.setEnabled(true)
            assertTrue(fixture.store().enabled)
        } finally { fixture.dispose() }
    }
    @Test fun detailedModeExpiresAndNeverRestartsOrRevivesAfterReenable() {
        val fixture = Fixture()
        try {
            var store = fixture.store(); store.setDetailed(true)
            assertTrue(store.detailed)
            fixture.clock.advance(30L * 60 * 1000)
            assertFalse(store.detailed)
            store.setDetailed(true); store = fixture.store()
            assertFalse(store.detailed)
            store.setDetailed(true); store.setEnabled(false); store.setEnabled(true)
            assertFalse(store.detailed)
        } finally { fixture.dispose() }
    }
    @Test fun clearRejectsOldQueuedRecordsRotatesKeyAndKeepsUserPreference() {
        val fixture = Fixture()
        try {
            val store = fixture.store(); val oldRecord = fixture.record(store)
            store.append(oldRecord)
            val previousToken = store.privacy.objectToken("session", 1, 42, "process")
            store.setDetailed(true)
            store.clear(); store.append(oldRecord)
            assertEquals(0L, store.overview().eventCount)
            assertTrue(store.detailed)
            assertNotEquals(previousToken, store.privacy.objectToken("session", 1, 42, "process"))
            store.append(fixture.record(store)); assertEquals(1L, store.overview().eventCount)
            store.setEnabled(false); store.clear()
            assertFalse(store.enabled)
        } finally { fixture.dispose() }
    }
    @Test fun partialClearIsRecoverableAndCannotReexportOldGeneration() {
        val fixture = Fixture()
        try {
            var blockDelete = false
            val store = fixture.store(beforeDelete = { if (blockDelete) throw IOException("injected") })
            store.append(fixture.record(store)); val oldGeneration = store.generation
            blockDelete = true
            try { store.clear(); fail("must report partial failure") } catch (error: DiagnosticFailure) { assertEquals("incomplete", error.code) }
            assertNotEquals(oldGeneration, store.generation)
            assertTrue(store.overview().bytes > 0)
            assertEquals(0L, store.overview().eventCount)
            val snapshot = store.beginSnapshot()
            assertTrue(snapshot.files.isEmpty())
            store.releaseSnapshot(snapshot.id)
            assertEquals(0L, fixture.store().overview().bytes)
        } finally { fixture.dispose() }
    }
    @Test fun snapshotPinsAreBoundedAndBlockClearUntilTaskEnds() {
        val fixture = Fixture()
        try {
            val store = fixture.store(); store.append(fixture.record(store))
            val snapshot = store.beginSnapshot()
            try { store.clear(); fail("must require cancellation or completion") } catch (error: DiagnosticFailure) { assertEquals("busy", error.code) }
            repeat(100) { store.append(fixture.record(store)) }
            assertTrue(store.overview().bytes <= fixture.limits.events + fixture.limits.incidents)
            assertTrue(snapshot.files.first().file.exists())
            fixture.clock.advance(30_001)
            repeat(30) { store.append(fixture.record(store)) }
            store.releaseSnapshot(snapshot.id)
            store.clear(); assertEquals(0L, store.overview().bytes)
        } finally { fixture.dispose() }
    }
    @Test fun damagedTailKeepsValidPrefixAndReportsKnownLoss() {
        val fixture = Fixture()
        try {
            val store = fixture.store(); store.append(fixture.record(store)); store.flush()
            val file = File(fixture.root, "events").listFiles()!!.single()
            file.appendText("{\"private malformed content")
            val restarted = fixture.store()
            assertEquals(1L, restarted.overview().eventCount)
            assertTrue(restarted.overview().missing.contains("corrupt_tail"))
            assertFalse(file.readText().contains("private malformed"))
        } finally { fixture.dispose() }
    }
    @Test fun writerFailureIsObservationFailureAndDoesNotThrowToCaller() {
        val fixture = Fixture()
        try {
            val store = fixture.store(beforeWrite = { throw IOException("disk full") })
            store.append(fixture.record(store))
            assertTrue(store.overview().limited)
            assertTrue(store.overview().missing.contains("write_failed"))
            assertEquals(0L, store.overview().eventCount)
        } finally { fixture.dispose() }
    }
    @Test fun boundedQueuePrefersCommitWithoutUnboundedGrowth() {
        val fixture = Fixture()
        try {
            val store = fixture.store()
            val regular = fixture.record(store).let { it.copy(event = it.event + mapOf("phase" to "started", "outcome" to "observed")) }
            val commit = fixture.record(store)
            val buffer = DiagnosticBuffer(regular.cost * 2, 2)
            assertTrue(buffer.offer(regular)); assertTrue(buffer.offer(regular))
            assertTrue(buffer.offer(commit))
            assertTrue(buffer.bytes <= regular.cost * 2)
            assertEquals(1L, buffer.dropped)
            buffer.clear()
            assertTrue(buffer.offer(regular)); assertTrue(buffer.offer(regular))
            assertTrue("A first error evicts ordinary queued observations", buffer.offer(fixture.record(store, failed = true)))
            assertEquals(2L, buffer.dropped)
            buffer.clear(); assertEquals(0, buffer.bytes)
        } finally { fixture.dispose() }
    }
    @Test fun errorStormRetainsFirstIncidentAndCountsDuplicates() {
        val fixture = Fixture()
        try {
            val store = fixture.store()
            repeat(1000) { store.append(fixture.record(store, failed = true, frames = true)) }
            store.flush()
            val text = File(fixture.root, "events").listFiles()!!.joinToString { it.readText() }
            assertTrue(text.contains("\"aggregation_count\":999"))
            assertTrue(store.overview().bytes <= fixture.limits.events + fixture.limits.incidents)
            assertEquals(1, File(fixture.root, "incidents").listFiles()!!.size)
        } finally { fixture.dispose() }
    }
}
