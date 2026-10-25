package com.settrace.settrace

import java.security.MessageDigest
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

data class DiagnosticOverview(
    val enabled: Boolean, val generation: String, val bytes: Long, val eventCount: Long,
    val firstTime: Long?, val lastTime: Long?, val detailedUntil: Long?,
    val missing: List<String>, val limited: Boolean,
) {
    fun toWire(): Map<String, Any?> = mapOf("enabled" to enabled, "generation" to generation, "bytes" to bytes, "event_count" to eventCount, "first_time" to firstTime, "last_time" to lastTime, "detailed_until" to detailedUntil, "missing" to missing, "limited" to limited)
}

enum class DiagnosticExportStage {
    collecting, packaging, writing_unpublished, verifying, publishing,
    cancelling, cancelled, saved, saved_partial, failed, unknown;
    val terminal: Boolean get() = this in setOf(cancelled, saved, saved_partial, failed, unknown)
}

data class DiagnosticExportState(
    val id: String, val stage: DiagnosticExportStage, val cancellable: Boolean,
    val fileName: String? = null, val bytes: Long? = null,
    val reason: String? = null, val missing: List<String> = emptyList(),
) {
    fun toWire(): Map<String, Any?> = mapOf("export_id" to id, "stage" to stage.name, "cancellable" to cancellable, "file_name" to fileName, "bytes" to bytes, "reason" to reason, "missing" to missing)
}

class DiagnosticFailure(val code: String) : java.io.IOException(code)

/** Platform-independent contract. No Android or third-party JSON dependency. */
object DiagnosticVocabulary {
    val events = setOf(
        "startup.begin", "startup.database", "startup.ready", "startup.recovery", "startup.exit",
        "plan.create", "plan.read", "plan.edit", "plan.delete", "plan.reorder", "plan.exercise_create", "plan.exercise_edit", "plan.exercise_delete",
        "workout.start", "workout.recover", "workout.complete", "workout.undo_complete", "workout.restore_skipped", "workout.skip_remaining",
        "workout.edit", "workout.reorder", "workout.rest_adjust", "workout.rest_end", "workout.save", "workout.discard",
        "rest.synchronize", "rest.schedule", "rest.claim", "rest.output", "rest.next", "rest.acknowledge", "rest.cancel",
        "history.read", "history.delete", "history.refresh", "plan_transfer.parse", "plan_transfer.import", "plan_transfer.export", "plan_transfer.copy",
        "backup.export", "backup.protect", "backup.restore", "backup.undo", "backup.settings", "backup.recovery",
        "settings.save", "navigation.notification", "diagnostics.policy", "diagnostics.export", "diagnostics.clear", "diagnostics.loss", "diagnostics.unhandled"
    )
    val phases = setOf("started", "validation", "transaction", "committed", "readback", "refresh", "schedule", "claim", "output", "acknowledged", "cancelled", "preparing", "protected", "core_committed", "settings_pending", "completed", "inspecting", "rejected", "failed")
    val outcomes = setOf("committed", "rejected", "cancelled", "rolled_back_confirmed", "partial_success", "unknown", "observed")
    val levels = setOf("debug", "info", "warn", "error", "fatal")
    val reasons = setOf(
        "crash", "native_crash", "anr", "low_memory", "user_requested", "user_stopped", "self_exit", "signaled", "excessive_resource", "dependency_died", "initialization_failure",
        "none", "validation", "stale_position", "not_found", "active_session", "no_completed_sets", "position_locked", "name_conflict",
        "unsupported_version", "invalid_format", "size_limit", "permission_denied", "permission_permanent", "channel_disabled", "exact_alarm_unavailable",
        "storage_unavailable", "no_space", "io", "sqlite", "platform", "state", "format", "unhandled", "unknown", "cancelled",
        "old_revision", "old_round", "already_acknowledged", "expired", "invalid_session", "restore_guard", "condition_mismatch", "claim_lost",
        "foreground", "background", "user_disabled", "followup_failed", "read_failed", "write_failed", "verification_failed", "publication_unknown",
        "missing", "unsupported", "not_available", "truncated", "sanitization_rejected", "queue_overflow", "rate_limited", "clock_changed",
        "corrupt_tail", "corrupt_control", "busy", "timeout", "incomplete", "initialization"
    )
    val objectTypes = setOf("plan", "exercise", "session", "session_exercise", "backup", "rest_alert")
    val counts = setOf("count", "before_count", "after_count", "target_count", "completed_count", "skipped_count", "revision", "round", "due_utc", "actual_utc", "source_epoch", "target_epoch", "duration_ms", "bytes")
    val flags = setOf("enabled", "repeat", "sound", "vibrate", "notifications_allowed", "channel_allowed", "exact_allowed", "foreground")
    val values = setOf("exact", "inexact", "foreground", "background", "disabled", "unsupported", "unknown", "system", "light", "dark", "teal", "blue", "violet", "graphite", "en", "zh")
    val envelopeKeys = setOf("schema_version", "event_name", "phase", "outcome", "severity", "reason_code", "operation_id", "parent_operation_id", "durable_backup_operation", "process_instance", "sequence", "monotonic_us", "clock_domain", "time_utc", "timezone_offset_minutes", "dataset_epoch", "generation", "attributes", "objects", "frames")
    val token = Regex("[a-f0-9]{32}")
    const val MAX_NUMBER = 9007199254740991L
    fun number(value: Any?): Long? {
        if (value !is Byte && value !is Short && value !is Int && value !is Long) return null
        return (value as Number).toLong().takeIf { it in 0..MAX_NUMBER }
    }
}

object DiagnosticJson {
    fun encode(value: Any?): String = when (value) {
        null -> "null"
        is String -> buildString {
            append('"')
            for (character in value) when (character) {
                '"' -> append("\\\"")
                '\\' -> append("\\\\")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                else -> if (character.code < 32) append("\\u%04x".format(character.code)) else append(character)
            }
            append('"')
        }
        is Boolean, is Byte, is Short, is Int, is Long -> value.toString()
        is Map<*, *> -> value.entries.joinToString(",", "{", "}") { (key, item) -> require(key is String); encode(key) + ":" + encode(item) }
        is Iterable<*> -> value.joinToString(",", "[", "]") { encode(it) }
        else -> throw IllegalArgumentException("unsupported_json_type")
    }
    fun bytes(value: Any?): ByteArray = encode(value).toByteArray(Charsets.UTF_8)
    fun sha256(value: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(value).joinToString("") { "%02x".format(it) }
}

data class DiagnosticRecord(
    val event: Map<String, Any?>,
    val frames: List<String>,
    val eventBytes: ByteArray,
    val incidentBytes: ByteArray?,
) {
    // Budget UTF16 strings, maps/lists and the encoded copies conservatively.
    val cost: Int get() = (eventBytes.size + (incidentBytes?.size ?: 0)) * 4 + 1024
    val critical: Boolean get() = event["outcome"] == "committed" || event["phase"] in setOf("committed", "core_committed") || event["severity"] == "fatal"
    val aggregationKey: String get() = DiagnosticJson.sha256(DiagnosticJson.bytes(listOf(event["event_name"], event["phase"], event["reason_code"], event["objects"], event["attributes"], event["incident_id"])))
}

class DiagnosticPrivacy(private val key: ByteArray, private val namespace: String) {
    fun backupCorrelation(identity: String): String {
        require(DiagnosticVocabulary.token.matches(identity))
        val mac = Mac.getInstance("HmacSHA256"); mac.init(SecretKeySpec(key, "HmacSHA256"))
        // The existing durable ledger ID survives dataset replacement. This is
        // a separate namespace from epoch-scoped numeric business object IDs.
        return mac.doFinal("$namespace|backup_ledger|$identity".toByteArray(Charsets.UTF_8)).take(16).joinToString("") { "%02x".format(it) }
    }
    fun objectToken(kind: String, epoch: Long?, identity: Any, process: String): String {
        require(kind in DiagnosticVocabulary.objectTypes)
        require(DiagnosticVocabulary.number(identity) != null || kind == "backup" && identity is String && DiagnosticVocabulary.token.matches(identity))
        val epochScope = epoch?.toString() ?: "unknown:$process"
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal("$namespace|$kind|$epochScope|$identity".toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }

    fun sanitize(input: Map<*, *>, generation: String, observedUtc: Long): DiagnosticRecord? {
        if (input.keys.any { it !in DiagnosticVocabulary.envelopeKeys } || input.size > 20) return null
        if (DiagnosticVocabulary.number(input["schema_version"]) != 1L || input["generation"] != generation) return null
        val name = input["event_name"] as? String ?: return null
        if (name !in DiagnosticVocabulary.events) return null
        val backup = input["durable_backup_operation"]
        if (backup != null && (!name.startsWith("backup.") || backup !is String || !DiagnosticVocabulary.token.matches(backup))) return null
        for ((field, values) in mapOf("phase" to DiagnosticVocabulary.phases, "outcome" to DiagnosticVocabulary.outcomes, "severity" to DiagnosticVocabulary.levels, "reason_code" to DiagnosticVocabulary.reasons)) if (input[field] !in values) return null
        for (field in listOf("operation_id", "process_instance")) if (!DiagnosticVocabulary.token.matches(input[field] as? String ?: "")) return null
        val parent = input["parent_operation_id"]
        if (parent != null && (parent !is String || !DiagnosticVocabulary.token.matches(parent))) return null
        val clock = input["clock_domain"]
        if (clock != "dart" && clock != "android" && clock != "unknown") return null
        val sequence = DiagnosticVocabulary.number(input["sequence"]) ?: return null
        val monotonic = if (clock == "unknown" && input["monotonic_us"] == null) null else DiagnosticVocabulary.number(input["monotonic_us"]) ?: return null
        val time = DiagnosticVocabulary.number(input["time_utc"]) ?: return null
        val timezone = (input["timezone_offset_minutes"] as? Number)?.toInt() ?: return null
        if (timezone !in -1080..1080) return null
        val epoch = input["dataset_epoch"]?.let { DiagnosticVocabulary.number(it) ?: return null }
        val attributes = input["attributes"] as? Map<*, *> ?: return null
        if (attributes.size > 24) return null
        val cleanAttributes = linkedMapOf<String, Any>()
        for ((rawField, value) in attributes) {
            val field = rawField as? String ?: return null
            cleanAttributes[field] = when {
                field in DiagnosticVocabulary.counts -> DiagnosticVocabulary.number(value) ?: return null
                field in DiagnosticVocabulary.flags && value is Boolean -> value
                field == "mode" && value in DiagnosticVocabulary.values -> value as String
                else -> return null
            }
        }
        val rawObjects = input["objects"] as? Map<*, *> ?: return null
        if (rawObjects.size > 6) return null
        val process = input["process_instance"] as String
        val objects = linkedMapOf<String, String>()
        for ((kind, identity) in rawObjects) {
            if (kind !in DiagnosticVocabulary.objectTypes) return null
            val safe = DiagnosticVocabulary.number(identity) ?: if (kind == "backup" && identity is String && DiagnosticVocabulary.token.matches(identity)) identity else return null
            objects[kind as String] = objectToken(kind, epoch, safe, process)
        }
        val rawFrames = input["frames"] as? List<*> ?: return null
        if (rawFrames.size > 96) return null
        val frames = rawFrames.map { frame ->
            if (frame !is String || !framePattern.matches(frame)) return null
            frame
        }
        if (frames.sumOf { it.toByteArray(Charsets.UTF_8).size } > 32 * 1024) return null
        val incidentId = if (frames.isEmpty()) null else DiagnosticJson.sha256(DiagnosticJson.bytes(listOf(input["reason_code"], frames)))
        val event = linkedMapOf<String, Any?>(
            "schema_version" to 1, "event_name" to name, "module" to name.substringBefore('.'), "origin" to if (clock == "unknown") "android" else clock,
            "phase" to input["phase"], "outcome" to input["outcome"], "severity" to input["severity"], "reason_code" to input["reason_code"],
            "operation_id" to input["operation_id"], "parent_operation_id" to parent, "correlation_id" to if (backup is String) backupCorrelation(backup) else input["operation_id"],
            "process_instance" to process, "sequence" to sequence, "monotonic_us" to monotonic, "clock_domain" to if (clock == "unknown") "unknown" else "$clock:$process",
            "time_utc" to time, "observed_time_utc" to observedUtc, "timezone_offset_minutes" to timezone,
            "dataset_epoch" to epoch, "generation" to generation, "attributes" to cleanAttributes, "objects" to objects, "incident_id" to incidentId,
        )
        val eventBytes = DiagnosticJson.bytes(event)
        if (eventBytes.size > 8 * 1024) return null
        val incidentBytes = incidentId?.let { DiagnosticJson.bytes(mapOf("schema_version" to 1, "incident_id" to it, "time_utc" to time, "reason_code" to input["reason_code"], "frames" to frames)) }
        return DiagnosticRecord(event, frames, eventBytes, incidentBytes)
    }

    companion object {
        private val framePattern = Regex("(?:package:(?:settrace|flutter)/[a-zA-Z0-9_/]+\\.dart:[0-9]+(?::[0-9]+)?|dart:[a-z_][a-zA-Z0-9_/]*(?:\\.dart)?:[0-9]+(?::[0-9]+)?|(?:com\\.settrace\\.settrace|java|javax|android|kotlin)\\.[a-zA-Z0-9_.$]+#[a-zA-Z0-9_<>$]+:[0-9]+)")
        fun validFrame(value: String): Boolean = framePattern.matches(value)
        fun frames(error: Throwable): List<String> = error.stackTrace.take(96).mapNotNull { frame ->
            val candidate = "${frame.className}#${frame.methodName}:${frame.lineNumber.coerceAtLeast(0)}"
            candidate.takeIf { it.length <= 320 && framePattern.matches(it) }
        }
    }
}
