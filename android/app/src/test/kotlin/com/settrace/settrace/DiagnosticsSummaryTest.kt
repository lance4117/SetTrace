package com.settrace.settrace

import org.junit.Assert.*
import org.junit.Test

class DiagnosticsSummaryTest {
    private fun event(id: Int, phase: String = "completed", severity: String = "info", outcome: String = "committed") = mapOf(
        "operation_id" to id.toString(16).padStart(32,'0'), "time_utc" to 1_800_000_000_000L,
        "timezone_offset_minutes" to 480, "event_name" to "workout.complete", "phase" to phase,
        "severity" to severity, "outcome" to outcome, "reason_code" to "none")
    @Test fun pendingGapIsRetainedAndWallClockRollbackUsesObservationOrder() {
        val summary = DiagnosticSummary()
        summary.offer(event(1,"started",outcome = "observed"))
        summary.offer(event(2,"started",outcome = "observed"))
        summary.offer(event(2).plus("time_utc" to 1_700_000_000_000L))
        val text = summary.render()
        assertTrue(text.contains("terminal=false")); assertTrue(text.contains("phase=completed"))
        assertTrue(text.indexOf("operation=" + 1.toString(16).padStart(32,'0')) < text.indexOf("operation=" + 2.toString(16).padStart(32,'0')))
    }
    @Test fun earlyFailureSurvivesNormalTrafficAndCommitCompletionAreMerged() {
        val summary = DiagnosticSummary()
        summary.offer(event(1,"committed")); summary.offer(event(1,"refresh","error","partial_success"))
        repeat(2000) { summary.offer(event(it+2,"committed")); summary.offer(event(it+2)) }
        val text = summary.render()
        assertTrue(text.contains("outcome=partial_success")); assertTrue(text.contains("committed=true"))
        assertEquals(64,text.lines().count { it.contains("operation=") })
        assertTrue(text.contains("+08:00")); assertTrue(text.toByteArray().size < 32*1024)
        assertEquals(1,text.lines().count { it.endsWith("operation=" + 1.toString(16).padStart(32,'0')) })
        assertTrue(summary.mergeEvictions > 0)
    }
    @Test fun priorityOverflowIsBoundedDeterministicAndExplicit() {
        fun render(): String {
            val summary = DiagnosticSummary()
            repeat(1000) { summary.offer(event(it,"failed","error","unknown")) }
            assertEquals(936L,summary.omittedImportant)
            return summary.render()
        }
        assertEquals(render(),render())
    }
}
