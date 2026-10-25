package com.settrace.settrace

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.security.SecureRandom
import java.util.ArrayDeque
import java.util.Properties
import java.util.UUID

interface DiagnosticClock {
    fun wallMillis(): Long
    fun monotonicMillis(): Long
    val boot: String
}

data class DiagnosticLimits(
    val events: Long = 16L * 1024 * 1024,
    val incidents: Long = 4L * 1024 * 1024,
    val eventSegment: Int = 1024 * 1024,
    val incidentSegment: Int = 512 * 1024,
    val metadata: Long = 1024 * 1024,
    val staging: Long = 24L * 1024 * 1024,
    val retentionMillis: Long = 7L * 24 * 60 * 60 * 1000,
    val maxSegments: Int = 128,
)

class DiagnosticBuffer(private val maximum: Int = 512 * 1024, private val maxRecords: Int = 256) {
    private val records = ArrayDeque<DiagnosticRecord>()
    var bytes: Int = 0; private set
    var dropped: Long = 0; private set
    @Synchronized fun offer(record: DiagnosticRecord): Boolean {
        if (record.cost > maximum) { dropped++; return false }
        if (record.critical || record.event["severity"] == "error") {
            val iterator = records.iterator()
            while ((bytes + record.cost > maximum || records.size >= maxRecords) && iterator.hasNext()) {
                val candidate = iterator.next()
                if (!candidate.critical && candidate.event["severity"] !in setOf("error", "fatal")) { iterator.remove(); bytes -= candidate.cost; dropped++ }
            }
        }
        if (bytes + record.cost > maximum || records.size >= maxRecords) { dropped++; return false }
        records.addLast(record); bytes += record.cost
        return true
    }
    @Synchronized fun take(): DiagnosticRecord? = records.pollFirst()?.also { bytes -= it.cost }
    @Synchronized fun clear() { records.clear(); bytes = 0 }
}

/** Crash-safe replacement on API24 and on the Windows JVM used by unit tests.
 * A prepared file is never a committed policy. A missing primary recovers backup.
 */
object DiagnosticAtomicFile {
    fun recover(file: File) {
        val backup = File(file.path + ".bak")
        if (!file.exists() && backup.exists() && !backup.renameTo(file)) throw DiagnosticFailure("storage_unavailable")
        if (file.exists()) backup.delete()
        File(file.path + ".new").delete()
    }
    fun write(file: File, data: ByteArray, beforeCommit: (() -> Unit)? = null) {
        recover(file)
        val prepared = File(file.path + ".new")
        val backup = File(file.path + ".bak")
        try {
            FileOutputStream(prepared).use { output -> output.write(data); output.fd.sync() }
            beforeCommit?.invoke()
            if (file.exists() && !file.renameTo(backup)) throw DiagnosticFailure("write_failed")
            if (!prepared.renameTo(file)) {
                if (backup.exists()) backup.renameTo(file)
                throw DiagnosticFailure("write_failed")
            }
            // Publication is committed. Backup cleanup cannot turn it into a
            // falsely reported policy-write failure.
            backup.delete()
        } catch (error: Exception) {
            prepared.delete()
            if (!file.exists() && backup.exists()) backup.renameTo(file)
            throw error
        }
    }
}

data class DiagnosticSegment(
    val file: File, val incident: Boolean, val generation: String,
    val retentionUtc: Long, val boot: String, val monotonic: Long,
    var count: Long = 0, var first: Long? = null, var last: Long? = null,
    var readable: Boolean = true,
)

data class DiagnosticSnapshot(val id: String, val cutoff: Long, val expires: Long, val files: List<DiagnosticSegment>, val missing: List<String>)

/** All methods run off the UI thread; no business database or write lease. */
class DiagnosticStore(
    val root: File,
    val clock: DiagnosticClock,
    val decode: (String) -> Map<*, *>,
    val limits: DiagnosticLimits = DiagnosticLimits(),
    private val beforeControlCommit: (() -> Unit)? = null,
    private val beforeDataWrite: (() -> Unit)? = null,
    private val beforeFileDelete: (() -> Unit)? = null,
) {
    private val controlFile = File(root, "control.properties")
    private val eventDirectory = File(root, "events")
    private val incidentDirectory = File(root, "incidents")
    val stagingDirectory = File(root, "staging")
    private var control = Properties()
    private val segments = mutableListOf<DiagnosticSegment>()
    private val active = mutableMapOf<Boolean, DiagnosticSegment>()
    private val incidentIds = LinkedHashSet<String>()
    private var snapshot: DiagnosticSnapshot? = null
    private var detailedDeadline = 0L
    private var detailedWall: Long? = null
    private var policyReadable = false
    private var lastWall = clock.wallMillis()
    private val missing = linkedSetOf<String>()
    private val losses = linkedMapOf<String, Long>()
    private data class LossRange(val first: Long, var last: Long, val boot: String, var mono: Long, val firstMono: Long = mono)
    private val lossRanges = linkedMapOf<String, LossRange>()
    private var nextFile = 0
    private val aggregations = linkedMapOf<String, Aggregation>()
    private data class Aggregation(val record: DiagnosticRecord, val first: Long, var last: Long, var count: Long = 0)

    val generation: String get() = control.getProperty("generation")
    val enabled: Boolean get() = policyReadable && control.getProperty("enabled") == "true"
    val detailed: Boolean get() = enabled && clock.monotonicMillis() < detailedDeadline
    val privacy: DiagnosticPrivacy get() = DiagnosticPrivacy(hex(control.getProperty("key")), generation)

    init {
        for (directory in listOf(root, eventDirectory, incidentDirectory, stagingDirectory)) {
            if (!directory.isDirectory && !directory.mkdirs()) throw DiagnosticFailure("storage_unavailable")
        }
        control = freshControl(true)
        try {
            DiagnosticAtomicFile.recover(controlFile)
            if (controlFile.exists()) {
                if (controlFile.length() > 16 * 1024) throw DiagnosticFailure("corrupt_control")
                val loaded = Properties().also { properties -> controlFile.inputStream().use { properties.load(it) } }
                require(loaded.getProperty("version") == "1")
                require(loaded.getProperty("enabled") in setOf("true", "false"))
                require(DiagnosticVocabulary.token.matches(loaded.getProperty("generation", "")))
                require(Regex("[a-f0-9]{64}").matches(loaded.getProperty("key", "")))
                require(loaded.stringPropertyNames().all { it in setOf("version", "enabled", "enabled_since", "exit_seen", "generation", "key", "clearing", "last_wall", "last_boot", "last_mono") || it.substringBefore('.') in setOf("loss", "loss_first", "loss_last", "loss_boot", "loss_mono", "loss_first_mono") && it.substringAfter('.') in DiagnosticVocabulary.reasons })
                control = loaded
                for (reason in DiagnosticVocabulary.reasons) {
                    val count = loaded.getProperty("loss.$reason")?.toLongOrNull() ?: continue
                    val first = loaded.getProperty("loss_first.$reason")?.toLongOrNull() ?: continue
                    val last = loaded.getProperty("loss_last.$reason")?.toLongOrNull() ?: continue
                    val mono = loaded.getProperty("loss_mono.$reason")?.toLongOrNull() ?: continue
                    if (count > 0 && first >= 0 && last >= first) {
                        losses[reason] = count
                        lossRanges[reason] = LossRange(first, last, loaded.getProperty("loss_boot.$reason", "unknown"), mono, loaded.getProperty("loss_first_mono.$reason")?.toLongOrNull() ?: mono)
                        missing.add(reason)
                    }
                }
            } else {
                saveControl(control)
            }
            policyReadable = true
        } catch (_: Exception) {
            missing.add("corrupt_control")
            control.setProperty("enabled", "false")
        }
        val priorWall = control.getProperty("last_wall")?.toLongOrNull()
        if (priorWall != null && clock.wallMillis() < priorWall && control.getProperty("last_boot") != clock.boot) loss("clock_changed")
        scan()
        if (control.getProperty("clearing") == "true") finishClear()
        prune()
    }

    private fun freshControl(enabled: Boolean): Properties = Properties().apply {
        setProperty("version", "1"); setProperty("enabled", enabled.toString())
        setProperty("generation", UUID.randomUUID().toString().replace("-", ""))
        val secret = ByteArray(32).also { SecureRandom().nextBytes(it) }
        setProperty("key", secret.joinToString("") { "%02x".format(it) })
        setProperty("clearing", "false")
        setProperty("enabled_since", clock.wallMillis().toString())
    }

    private fun saveControl(next: Properties) {
        val bytes = ByteArrayOutputStream().also { next.store(it, "SetTrace diagnostics control v1") }.toByteArray()
        if (bytes.size > 16 * 1024 || metadataBytes() + bytes.size * 2 > limits.metadata) throw DiagnosticFailure("size_limit")
        DiagnosticAtomicFile.write(controlFile, bytes, beforeControlCommit)
    }

    fun metadataBytes(): Long = root.listFiles()?.filter { it.isFile }?.sumOf { it.length() } ?: throw DiagnosticFailure("read_failed")

    @Synchronized fun loss(reason: String, amount: Long = 1) {
        if (reason !in DiagnosticVocabulary.reasons) return
        expireLosses()
        missing.add(reason)
        losses[reason] = ((losses[reason] ?: 0).coerceAtMost(Long.MAX_VALUE - amount.coerceAtLeast(0)) + amount.coerceAtLeast(0))
        val now = clock.wallMillis()
        val range = lossRanges[reason]
        if (range == null) lossRanges[reason] = LossRange(now, now, clock.boot, clock.monotonicMillis())
        else { range.last = maxOf(range.first, now); range.mono = clock.monotonicMillis() }
    }

    private fun expireLosses() {
        for ((reason, range) in lossRanges.toMap()) {
            val age = if (range.boot == clock.boot && clock.monotonicMillis() >= range.firstMono) clock.monotonicMillis() - range.firstMono else clock.wallMillis() - range.first
            if (age < 0 || age >= limits.retentionMillis) { losses.remove(reason); lossRanges.remove(reason); missing.remove(reason) }
        }
    }

    @Synchronized fun setEnabled(value: Boolean): DiagnosticOverview {
        val next = Properties().also { it.putAll(control) }
        next.setProperty("enabled", value.toString())
        if (value && !enabled) next.setProperty("enabled_since", clock.wallMillis().toString())
        saveControl(next)
        control = next; policyReadable = true; missing.remove("corrupt_control")
        if (!value) { detailedDeadline = 0; detailedWall = null; aggregations.clear() }
        return overview()
    }

    @Synchronized fun setDetailed(value: Boolean): DiagnosticOverview {
        if (value && !enabled) throw DiagnosticFailure("user_disabled")
        detailedDeadline = if (value) clock.monotonicMillis() + 30 * 60 * 1000 else 0
        detailedWall = if (value) clock.wallMillis() + 30 * 60 * 1000 else null
        return overview()
    }

    @Synchronized fun accept(input: Map<*, *>): Boolean {
        if (!enabled) return false
        val record = privacy.sanitize(input, generation, clock.wallMillis())
        if (record == null) { loss("sanitization_rejected"); return false }
        if (record.event["severity"] == "debug" && !detailed) return false
        append(record)
        return true
    }

    @Synchronized fun append(record: DiagnosticRecord) {
        if (!enabled || record.event["generation"] != generation) return
        if (record.event["severity"] == "debug" && !detailed) return
        val now = clock.monotonicMillis()
        val aggregate = !record.critical && record.event["severity"] in setOf("warn", "error")
        if (aggregate) {
            val prior = aggregations[record.aggregationKey]
            if (prior != null && now - prior.first in 0 until 60_000) { prior.count++; prior.last = now; return }
            if (prior != null) flushAggregation(prior)
            if (aggregations.size >= 128) { val oldest = aggregations.entries.first(); flushAggregation(oldest.value); aggregations.remove(oldest.key) }
            aggregations[record.aggregationKey] = Aggregation(record, now, now)
        }
        try {
            prune()
            if (record.incidentBytes != null) {
                val id = record.event["incident_id"] as String
                if (id !in incidentIds) {
                    if (writeLine(true, record.incidentBytes, (record.event["time_utc"] as Number).toLong())) incidentIds.add(id)
                    while (incidentIds.size > 256) incidentIds.remove(incidentIds.first())
                }
            }
            writeLine(false, record.eventBytes, (record.event["time_utc"] as Number).toLong())
        } catch (_: Exception) { loss("write_failed") }
    }

    private fun flushAggregation(value: Aggregation) {
        if (value.count == 0L) return
        val summary = value.record.event.toMutableMap()
        summary["aggregation_count"] = value.count
        summary["aggregation_first_mono"] = value.first
        summary["aggregation_last_mono"] = value.last
        try { writeLine(false, DiagnosticJson.bytes(summary), (summary["time_utc"] as Number).toLong()) }
        catch (_: Exception) { loss("write_failed") }
        value.count = 0
    }

    @Synchronized fun flush() {
        if (enabled) for (value in aggregations.values) flushAggregation(value)
        prune()
        if (policyReadable) {
            val next = Properties().also { it.putAll(control) }
            next.setProperty("last_wall", clock.wallMillis().toString())
            next.setProperty("last_boot", clock.boot)
            next.setProperty("last_mono", clock.monotonicMillis().toString())
            for (key in next.stringPropertyNames().toList()) if (key.substringBefore('.') in setOf("loss", "loss_first", "loss_last", "loss_boot", "loss_mono", "loss_first_mono")) next.remove(key)
            for ((reason, count) in losses) {
                val range = lossRanges[reason] ?: continue
                next.setProperty("loss.$reason", count.toString())
                next.setProperty("loss_first.$reason", range.first.toString()); next.setProperty("loss_last.$reason", range.last.toString())
                next.setProperty("loss_boot.$reason", range.boot); next.setProperty("loss_mono.$reason", range.mono.toString())
                next.setProperty("loss_first_mono.$reason", range.firstMono.toString())
            }
            try { saveControl(next); control = next } catch (_: Exception) { loss("write_failed") }
        }
    }

    private fun writeLine(incident: Boolean, bytes: ByteArray, time: Long): Boolean {
        beforeDataWrite?.invoke()
        val maximumSegment = if (incident) limits.incidentSegment else limits.eventSegment
        if (bytes.size + 512 > maximumSegment || (!incident && bytes.size > 8 * 1024)) { loss("size_limit"); return false }
        val line = bytes + byteArrayOf(10)
        var current = active[incident]
        if (current == null || current.file.length() + line.size > maximumSegment || expired(current)) {
            active.remove(incident)
            val directory = if (incident) incidentDirectory else eventDirectory
            val file = File(directory, "$generation-${clock.wallMillis().coerceAtLeast(0)}-${nextFile++}.jsonl")
            val header = mapOf("kind" to "segment", "schema_version" to 1, "generation" to generation, "retention_utc" to clock.wallMillis(), "boot" to clock.boot, "monotonic_ms" to clock.monotonicMillis())
            val headerBytes = DiagnosticJson.bytes(header) + byteArrayOf(10)
            if (!makeRoom(incident, headerBytes.size + line.size)) { loss("queue_overflow"); return false }
            if (!file.createNewFile()) throw DiagnosticFailure("write_failed")
            FileOutputStream(file).use { it.write(headerBytes) }
            current = DiagnosticSegment(file, incident, generation, clock.wallMillis(), clock.boot, clock.monotonicMillis())
            segments.add(current); active[incident] = current
        } else if (!makeRoom(incident, line.size)) { loss("queue_overflow"); return false }
        FileOutputStream(current.file, true).use { it.write(line) }
        if (!incident) { current.count++; current.first = minOf(current.first ?: time, time); current.last = maxOf(current.last ?: time, time) }
        return true
    }

    private fun makeRoom(incident: Boolean, incoming: Int): Boolean {
        val maximum = if (incident) limits.incidents else limits.events
        while (logBytes(incident) + incoming > maximum || segments.size >= limits.maxSegments) {
            val victim = segments.filter { it.incident == incident && !pinned(it) && active[incident] != it }.minByOrNull { it.retentionUtc } ?: return false
            remove(victim)
        }
        return true
    }

    private fun logBytes(incident: Boolean): Long = (if (incident) incidentDirectory else eventDirectory).listFiles()?.filter { it.isFile }?.sumOf { it.length() } ?: throw DiagnosticFailure("read_failed")

    private fun pinned(segment: DiagnosticSegment): Boolean = snapshot?.let { clock.monotonicMillis() < it.expires && it.files.any { file -> file.file == segment.file } } == true

    private fun expired(segment: DiagnosticSegment): Boolean {
        val now = clock.wallMillis()
        if (segment.boot == clock.boot && clock.monotonicMillis() >= segment.monotonic) return clock.monotonicMillis() - segment.monotonic >= limits.retentionMillis
        if ("clock_changed" in missing && now < segment.retentionUtc) return true
        return now < segment.retentionUtc || now - segment.retentionUtc >= limits.retentionMillis
    }

    private fun remove(segment: DiagnosticSegment) {
        beforeFileDelete?.invoke()
        if (!segment.file.delete() && segment.file.exists()) throw DiagnosticFailure("write_failed")
        segments.remove(segment)
        if (active[segment.incident] == segment) active.remove(segment.incident)
        if (segment.incident) incidentIds.clear()
    }

    @Synchronized fun prune() {
        expireLosses()
        if (clock.wallMillis() < lastWall) loss("clock_changed")
        lastWall = clock.wallMillis()
        for (segment in segments.toList()) if (!pinned(segment) && expired(segment)) {
            try { remove(segment) } catch (_: Exception) { loss("write_failed") }
        }
        for (incident in listOf(false, true)) {
            try { makeRoom(incident, 0) } catch (_: Exception) { loss("write_failed") }
        }
    }

    private fun scan() {
        for ((directory, incident) in listOf(eventDirectory to false, incidentDirectory to true)) {
            val files = directory.listFiles() ?: throw DiagnosticFailure("read_failed")
            for (file in files.sortedBy { it.name }) {
                if (!file.isFile) continue
                if (!Regex("[a-f0-9]{32}-[0-9]+-[0-9]+\\.jsonl").matches(file.name)) {
                    segments.add(DiagnosticSegment(file, incident, "unknown", file.lastModified(), "unknown", 0, readable = false)); loss("unsupported_version"); continue
                }
                try {
                    if (file.length() > (if (incident) limits.incidentSegment else limits.eventSegment)) { loss("size_limit"); if (!file.delete()) loss("write_failed"); continue }
                    RandomAccessFile(file, "rw").use { reader ->
                        val firstLine = reader.readLine() ?: throw DiagnosticFailure("corrupt_tail")
                        if (firstLine.length > 1024) throw DiagnosticFailure("corrupt_tail")
                        val header = decode(firstLine)
                        val retention = DiagnosticVocabulary.number(header["retention_utc"]) ?: throw DiagnosticFailure("corrupt_tail")
                        val segment = DiagnosticSegment(file, incident, file.name.substringBefore('-'), retention, header["boot"] as? String ?: "unknown", DiagnosticVocabulary.number(header["monotonic_ms"]) ?: 0)
                        segments.add(segment)
                        if (header["schema_version"] != 1 && header["schema_version"] != 1L) { segment.readable = false; loss("unsupported_version"); return@use }
                        var goodEnd = reader.filePointer
                        while (reader.filePointer < reader.length()) {
                            val line = reader.readLine()
                            val end = reader.filePointer
                            val complete = if (end > 0) { reader.seek(end - 1); val newline = reader.read() == 10; reader.seek(end); newline } else false
                            try {
                                if (line == null || line.length > (if (incident) 48 * 1024 else 8 * 1024) || !complete) throw DiagnosticFailure("corrupt_tail")
                                val item = decode(line)
                                if (!DiagnosticStoredValidator.valid(item, incident)) throw DiagnosticFailure("sanitization_rejected")
                                if (!incident) {
                                    val time = (item["time_utc"] as Number).toLong()
                                    segment.count++; segment.first = minOf(segment.first ?: time, time); segment.last = maxOf(segment.last ?: time, time)
                                }
                                goodEnd = reader.filePointer
                            } catch (_: Exception) { loss("corrupt_tail"); reader.setLength(goodEnd); break }
                        }
                    }
                } catch (_: Exception) {
                    if (file.exists() && segments.none { it.file == file }) segments.add(DiagnosticSegment(file, incident, file.name.substringBefore('-'), file.name.split('-').getOrNull(1)?.toLongOrNull() ?: file.lastModified(), "unknown", 0, readable = false))
                    loss("read_failed")
                }
            }
        }
    }

    @Synchronized fun overview(): DiagnosticOverview {
        prune()
        if (!detailed) { detailedDeadline = 0; detailedWall = null }
        val visible = segments.filter { !it.incident && it.readable && (control.getProperty("clearing") != "true" || it.generation == generation) }
        return DiagnosticOverview(enabled, generation, logBytes(false) + logBytes(true), visible.sumOf { it.count }, visible.mapNotNull { it.first }.minOrNull(), visible.mapNotNull { it.last }.maxOrNull(), detailedWall, missing.toList(), missing.any { it !in setOf("rate_limited") })
    }

    @Synchronized fun beginSnapshot(): DiagnosticSnapshot {
        if (snapshot != null) throw DiagnosticFailure("busy")
        flush(); active.clear()
        val available = segments.filter { it.readable && !expired(it) && (control.getProperty("clearing") != "true" || it.generation == generation) }.map { it.copy() }
        return DiagnosticSnapshot(UUID.randomUUID().toString().replace("-", ""), clock.wallMillis(), clock.monotonicMillis() + 30_000, available, missing.toList()).also { snapshot = it }
    }

    @Synchronized fun releaseSnapshot(id: String) { if (snapshot?.id == id) snapshot = null }
    @Synchronized fun clear(): DiagnosticOverview {
        if (snapshot != null) throw DiagnosticFailure("busy")
        val next = freshControl(enabled)
        next.setProperty("clearing", "true")
        saveControl(next); control = next; policyReadable = true
        active.clear(); aggregations.clear(); incidentIds.clear()
        losses.clear(); lossRanges.clear(); missing.clear()
        if (!finishClear()) throw DiagnosticFailure("incomplete")
        return overview()
    }

    private fun finishClear(): Boolean {
        var success = true
        for (segment in segments.toList()) if (segment.generation != generation) try { remove(segment) } catch (_: Exception) { success = false }
        for (file in stagingDirectory.listFiles().orEmpty()) if (file.isFile) try {
            beforeFileDelete?.invoke()
            if (!file.delete() && file.exists()) success = false
        } catch (_: Exception) { success = false }
        if (!success) { loss("incomplete"); return false }
        val next = Properties().also { it.putAll(control) }; next.setProperty("clearing", "false")
        try { saveControl(next); control = next } catch (_: Exception) { loss("incomplete"); return false }
        missing.remove("incomplete")
        return true
    }

    fun lossCounts(): Map<String, Long> = synchronized(this) { expireLosses(); losses.toMap() }
    fun lossIntervals(): Map<String, Any?> = synchronized(this) {
        expireLosses(); lossRanges.mapValues { (_, value) -> mapOf("first_observed_utc" to value.first, "last_observed_utc" to value.last) }
    }
    @Synchronized fun consumeExit(marker: String, time: Long): Boolean {
        if (!enabled || !Regex("[a-f0-9]{64}").matches(marker) || time < (control.getProperty("enabled_since")?.toLongOrNull() ?: Long.MAX_VALUE) || clock.wallMillis() - time !in 0 until limits.retentionMillis) return false
        val seen = control.getProperty("exit_seen", "").split(',').filter { Regex("[a-f0-9]{64}").matches(it) }
        if (marker in seen) return false
        val next = Properties().also { it.putAll(control) }
        next.setProperty("exit_seen", (seen.takeLast(7) + marker).joinToString(","))
        return try { saveControl(next); control = next; true } catch (_: Exception) { loss("write_failed"); false }
    }
    companion object {
        private fun hex(value: String): ByteArray = value.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }
}

/** Persisted files are revalidated, never exported as trusted opaque bytes. */
object DiagnosticStoredValidator {
    fun valid(item: Map<*, *>, incident: Boolean): Boolean {
        if (DiagnosticVocabulary.number(item["schema_version"]) != 1L) return false
        if (DiagnosticVocabulary.number(item["time_utc"]) == null) return false
        if (incident) {
            if (item.keys.any { it !in setOf("schema_version", "incident_id", "time_utc", "reason_code", "frames") }) return false
            if (!Regex("[a-f0-9]{64}").matches(item["incident_id"] as? String ?: "")) return false
            if (item["reason_code"] !in DiagnosticVocabulary.reasons) return false
            val frames = item["frames"] as? List<*> ?: return false
            return frames.size <= 96 && frames.all { it is String && DiagnosticPrivacy.validFrame(it) } && frames.sumOf { (it as String).length } <= 32 * 1024
        }
        val keys = setOf("schema_version", "event_name", "module", "origin", "phase", "outcome", "severity", "reason_code", "operation_id", "parent_operation_id", "correlation_id", "process_instance", "sequence", "monotonic_us", "clock_domain", "time_utc", "observed_time_utc", "timezone_offset_minutes", "dataset_epoch", "generation", "attributes", "objects", "incident_id", "aggregation_count", "aggregation_first_mono", "aggregation_last_mono")
        if (item.keys.any { it !in keys } || item["event_name"] !in DiagnosticVocabulary.events || item["phase"] !in DiagnosticVocabulary.phases || item["outcome"] !in DiagnosticVocabulary.outcomes || item["severity"] !in DiagnosticVocabulary.levels || item["reason_code"] !in DiagnosticVocabulary.reasons) return false
        val name = item["event_name"] as String
        if (item["module"] != name.substringBefore('.') || item["origin"] !in setOf("dart", "android")) return false
        for (key in listOf("operation_id", "correlation_id", "process_instance", "generation")) if (!DiagnosticVocabulary.token.matches(item[key] as? String ?: "")) return false
        if (item["clock_domain"] != "unknown" && item["clock_domain"] != "${item["origin"]}:${item["process_instance"]}") return false
        if (item["parent_operation_id"] != null && !DiagnosticVocabulary.token.matches(item["parent_operation_id"] as? String ?: "")) return false
        if (item["incident_id"] != null && !Regex("[a-f0-9]{64}").matches(item["incident_id"] as? String ?: "")) return false
        for (key in listOf("sequence", "observed_time_utc")) if (DiagnosticVocabulary.number(item[key]) == null) return false
        if (item["clock_domain"] == "unknown") { if (item["monotonic_us"] != null) return false }
        else if (DiagnosticVocabulary.number(item["monotonic_us"]) == null) return false
        for (key in listOf("dataset_epoch", "aggregation_count", "aggregation_first_mono", "aggregation_last_mono")) if (item[key] != null && DiagnosticVocabulary.number(item[key]) == null) return false
        val timezone = item["timezone_offset_minutes"] as? Number ?: return false
        if (timezone.toInt() !in -1080..1080) return false
        val attributes = item["attributes"] as? Map<*, *> ?: return false
        if (attributes.size > 24 || attributes.any { (key, value) -> when (key) { in DiagnosticVocabulary.counts -> DiagnosticVocabulary.number(value) == null; in DiagnosticVocabulary.flags -> value !is Boolean; "mode" -> value !in DiagnosticVocabulary.values; else -> true } }) return false
        val objects = item["objects"] as? Map<*, *> ?: return false
        return objects.size <= 6 && objects.all { (key, value) -> key in DiagnosticVocabulary.objectTypes && value is String && Regex("[a-f0-9]{64}").matches(value) }
    }
}
