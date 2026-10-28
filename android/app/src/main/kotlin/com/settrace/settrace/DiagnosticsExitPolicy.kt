package com.settrace.settrace

import java.io.ByteArrayOutputStream
import java.io.InputStream

/** Raw platform descriptions and tombstones never leave this adapter. */
data class DiagnosticExitCandidate(val time: Long, val reason: Int, val pid: Int, val trace: () -> InputStream?)
data class DiagnosticExitEvidence(val marker: String, val time: Long, val reason: String, val frames: List<String>)
data class DiagnosticExitCollection(val capability: String, val traceStatus: String, val exits: List<DiagnosticExitEvidence>)

object DiagnosticExitPolicy {
    fun severity(reason: String) = if (reason in setOf("user_requested", "user_stopped", "self_exit")) "info" else "warn"
    // Stable ApplicationExitInfo reason values; usable in JVM tests without an
    // Android runtime. Future platform reasons remain explicitly unknown.
    fun reason(value: Int): String = when (value) {
        1 -> "self_exit"; 2 -> "signaled"; 3 -> "low_memory"; 4 -> "crash"
        5 -> "native_crash"; 6 -> "anr"; 7 -> "initialization_failure"
        9 -> "excessive_resource"; 10 -> "user_requested"; 11 -> "user_stopped"
        12 -> "dependency_died"; else -> "unknown"
    }

    fun read(api: Int, enabled: Boolean, source: () -> List<DiagnosticExitCandidate>): DiagnosticExitCollection {
        if (api < 30) return DiagnosticExitCollection("unsupported", "not_available", emptyList())
        if (!enabled) return DiagnosticExitCollection("not_available", "not_available", emptyList())
        val candidates = try { source().take(5) } catch (_: Exception) { return DiagnosticExitCollection("read_failed", "read_failed", emptyList()) }
        if (candidates.isEmpty()) return DiagnosticExitCollection("no_records", "not_available", emptyList())
        var traceStatus = "not_available"
        val exits = candidates.map { info ->
            val frames = mutableListOf<String>()
            try {
                info.trace()?.use { input ->
                    val data = ByteArrayOutputStream(); val bytes = ByteArray(2048)
                    while (data.size() < 64 * 1024 && !Thread.currentThread().isInterrupted) {
                        val count = input.read(bytes, 0, minOf(bytes.size, 64 * 1024 - data.size()))
                        if (count < 0) break
                        data.write(bytes, 0, count)
                    }
                    val pattern = Regex("\\bat ((?:com\\.settrace\\.settrace|java|javax|android|kotlin)\\.[a-zA-Z0-9_.$]+)\\.([a-zA-Z0-9_<>$]+)\\([^:)]*:([0-9]+)\\)")
                    for (match in pattern.findAll(data.toString("UTF-8"))) {
                        val frame = "${match.groupValues[1]}#${match.groupValues[2]}:${match.groupValues[3]}"
                        if (frames.size < 96 && DiagnosticPrivacy.validFrame(frame)) frames.add(frame)
                    }
                    traceStatus = when {
                        data.size() == 64 * 1024 -> "truncated"
                        frames.isEmpty() && data.size() > 0 -> "sanitization_rejected"
                        frames.isNotEmpty() -> "available"
                        else -> "not_available"
                    }
                }
            } catch (_: Exception) { traceStatus = "read_failed" }
            DiagnosticExitEvidence(DiagnosticJson.sha256("${info.time}:${info.reason}:${info.pid}".toByteArray()), info.time, reason(info.reason), frames)
        }
        return DiagnosticExitCollection("supported", traceStatus, exits)
    }
}
