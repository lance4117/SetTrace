package com.settrace.settrace

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.SimpleTimeZone

/** Fixed pools and cache; evictions are explicit evidence limits, never inferred crashes. */
internal class DiagnosticSummary {
    private data class Operation(val id: String, var event: Map<*, *>, var priority: Int,
        var committed: Boolean, var terminal: Boolean, var order: Long)
    private val cache = linkedMapOf<String, Operation>()
    private val important = linkedMapOf<String, Operation>()
    private val normal = linkedMapOf<String, Operation>()
    private var order = 0L
    var groups = 0L; private set
    var mergeEvictions = 0L; private set
    var omittedImportant = 0L; private set
    var omittedNormal = 0L; private set
    fun offer(event: Map<*, *>) {
        val compact = event.filterKeys { it in setOf("operation_id", "time_utc", "timezone_offset_minutes", "event_name", "phase", "outcome", "reason_code") }
        val id = event["operation_id"] as String
        val score = when {
            event["severity"] == "fatal" -> 5
            event["severity"] == "error" || event["outcome"] == "partial_success" -> 4
            event["severity"] == "warn" -> 3
            event["outcome"] == "unknown" -> 2
            event["phase"] == "started" -> 1
            else -> 0
        }
        val committed = event["outcome"] == "committed" || event["phase"] in setOf("committed", "core_committed")
        val terminal = event["phase"] in setOf("completed", "failed", "rejected", "cancelled")
        // Selected groups remain mergeable even after leaving the recent cache.
        val operation = cache[id] ?: important[id] ?: normal[id] ?: Operation(id, compact, 0, false, false, order).also { groups++ }
        operation.committed = operation.committed || committed
        operation.terminal = operation.terminal || terminal
        if (score >= operation.priority || operation.priority <= 1 && (committed || terminal)) operation.event = compact
        operation.priority = if (operation.priority <= 1 && score <= 1 && (operation.terminal || operation.committed)) 0 else maxOf(score, operation.priority)
        operation.order = ++order
        cache.remove(id); cache[id] = operation
        while (cache.size > 256) { cache.remove(cache.keys.first()); mergeEvictions++ }
        if (operation.priority > 0) {
            normal.remove(id); important[id] = operation
            if (important.size > 64) {
                val victim = important.values.minWith(compareBy<Operation> { it.priority }.thenBy { it.order })
                important.remove(victim.id); omittedImportant++
            }
        } else if (committed || terminal) {
            important.remove(id)
            normal.remove(id); normal[id] = operation
            if (normal.size > 64) { normal.remove(normal.keys.first()); omittedNormal++ }
        }
    }
    fun render(): String {
        val selected = (important.values.sortedWith(compareByDescending<Operation> { it.priority }.thenByDescending { it.order }) +
            normal.values.sortedByDescending { it.order }).take(64).sortedBy { it.order }
        val extraNormal = normal.size - selected.count { it.priority == 0 }
        return buildString {
            append("Operation groups=$groups; merge_cache_evictions=$mergeEvictions (groups beyond cache may repeat).\n")
            append("Summary omitted priority candidates=$omittedImportant; ordinary candidates=${omittedNormal + extraNormal}. Raw validated events remain in ZIP.\n")
            append("Version 1 sound/enabled/round retain legacy meanings. Historical exit subject build is unknown. Absence is not a HyperOS diagnosis.\n")
            for (operation in selected) {
                val event = operation.event
                val utc = (event["time_utc"] as Number).toLong()
                val offset = (event["timezone_offset_minutes"] as Number).toInt()
                val local = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX",Locale.ROOT).apply { timeZone = SimpleTimeZone(offset * 60000,"event_offset") }.format(Date(utc))
                append("$local utc_ms=$utc ${event["event_name"]} phase=${event["phase"]} outcome=${event["outcome"]} reason=${event["reason_code"]} committed=${operation.committed} terminal=${operation.terminal} operation=${operation.id}\n")
            }
        }.also { check(it.toByteArray(Charsets.UTF_8).size <= 30 * 1024) }
    }
}
