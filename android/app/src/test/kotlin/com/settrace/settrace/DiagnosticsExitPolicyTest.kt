package com.settrace.settrace

import java.io.ByteArrayInputStream
import java.io.IOException
import org.junit.Assert.*
import org.junit.Test

class DiagnosticsExitPolicyTest {
    @Test fun normalExitsAreInfoButCrashAnrResourceAndUnknownRemainDistinct() {
        for (reason in listOf("user_requested","user_stopped","self_exit")) assertEquals("info",DiagnosticExitPolicy.severity(reason))
        for (reason in listOf("crash","native_crash","anr","low_memory","unknown")) assertEquals("warn",DiagnosticExitPolicy.severity(reason))
    }
    @Test fun unsupportedDisabledEmptyAndFailedReadsHaveDistinctCapabilities() {
        val forbidden = { throw AssertionError("platform must not be called") }
        assertEquals("unsupported", DiagnosticExitPolicy.read(28, true, forbidden).capability)
        assertEquals("not_available", DiagnosticExitPolicy.read(36, false, forbidden).capability)
        assertEquals("no_records", DiagnosticExitPolicy.read(30, true) { emptyList() }.capability)
        assertEquals("read_failed", DiagnosticExitPolicy.read(31, true) { throw SecurityException("PRIVATE") }.capability)
    }
    @Test fun reasonsAreEvidenceNotAnInferredCrashAndRawTraceIsNeverRetained() {
        val raw = "PRIVATE name SQL content://private/path\n at com.settrace.settrace.Work.run(Private.kt:12)\n at private.user.Name.value(Secret.kt:9)"
        val reasons = listOf(4, 5, 6, 3, 10)
        val result = DiagnosticExitPolicy.read(36, true) { reasons.map { DiagnosticExitCandidate(1000, it, 42) { ByteArrayInputStream(raw.toByteArray()) } } }
        assertEquals(listOf("crash", "native_crash", "anr", "low_memory", "user_requested"), result.exits.map { it.reason })
        assertEquals(listOf("com.settrace.settrace.Work#run:12"), result.exits.first().frames)
        assertFalse(result.toString().contains("PRIVATE"))
        assertFalse(result.toString().contains("Private.kt"))
        assertEquals("user_stopped", DiagnosticExitPolicy.reason(11))
        assertEquals("unknown", DiagnosticExitPolicy.reason(999))
    }
    @Test fun optionalTraceAbsenceFailureRejectionAndTruncationAreReported() {
        fun collect(trace: () -> java.io.InputStream?) = DiagnosticExitPolicy.read(36, true) { listOf(DiagnosticExitCandidate(1000, 6, 42, trace)) }
        assertEquals("not_available", collect { null }.traceStatus)
        assertEquals("read_failed", collect { throw IOException("PRIVATE") }.traceStatus)
        assertEquals("sanitization_rejected", collect { ByteArrayInputStream("PRIVATE tombstone".toByteArray()) }.traceStatus)
        assertEquals("truncated", collect { ByteArrayInputStream(ByteArray(80 * 1024) { 65 }) }.traceStatus)
        assertEquals("anr", collect { null }.exits.single().reason)
    }
    @Test fun exitConsumptionIsPersistentBoundedAndRespectsRecordingStartAndRetention() {
        val f = DiagnosticsStoreTest.Fixture()
        try {
            val store = f.store()
            val marker = "f".repeat(64)
            assertFalse(store.consumeExit(marker, f.clock.wall - 1))
            assertTrue(store.consumeExit(marker, f.clock.wall))
            assertFalse(f.store().consumeExit(marker, f.clock.wall))
            f.clock.advance(store.limits.retentionMillis + 1)
            assertFalse(store.consumeExit("e".repeat(64), f.clock.wall - store.limits.retentionMillis - 1))
            store.setEnabled(false)
            assertFalse(store.consumeExit("d".repeat(64), f.clock.wall))
        } finally { f.dispose() }
    }
}
