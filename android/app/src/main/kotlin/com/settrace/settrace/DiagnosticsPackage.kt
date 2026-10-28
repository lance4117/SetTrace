package com.settrace.settrace

import java.io.File
import java.io.FileOutputStream
import java.io.FilterOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.security.MessageDigest
import java.util.ArrayDeque
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

data class DiagnosticPackage(val file: File, val bytes: Long, val digest: String, val missing: List<String>, val manifest: Map<String, Any?>)
private class DiagnosticArchiveFailure(cause: Exception) : java.io.IOException("write_failed", cause)

internal fun diagnosticDigest(input: InputStream, limit: Long, check: () -> Unit = {}): Pair<Long, String> {
    val digest = MessageDigest.getInstance("SHA-256")
    val buffer = ByteArray(32 * 1024)
    var total = 0L
    while (true) {
        check()
        val count = input.read(buffer)
        if (count < 0) break
        total += count
        if (total > limit) throw DiagnosticFailure("size_limit")
        digest.update(buffer, 0, count)
    }
    return total to digest.digest().joinToString("") { "%02x".format(it) }
}

/** No full ZIP/source copy in memory and no opaque log-file export. */
class DiagnosticPackageBuilder(private val store: DiagnosticStore) {
    fun build(snapshot: DiagnosticSnapshot, environment: Map<String, Any?>?, state: Map<*, *>?, cancelled: () -> Boolean): DiagnosticPackage {
        val missing = snapshot.missing.toMutableSet()
        val cleanEnvironment = sanitizeEnvironment(environment) ?: throw DiagnosticFailure("not_available")
        val cleanState = sanitizeState(state)
        if (state != null && cleanState == null) missing.add("sanitization_rejected")
        if (cleanState?.get("available") != true) missing.add("not_available")
        for (file in store.stagingDirectory.listFiles().orEmpty()) {
            if (!file.isFile || !file.delete()) throw DiagnosticFailure("storage_unavailable")
        }
        val output = File(store.stagingDirectory, "${snapshot.id}.zip")
        val entries = mutableListOf<Map<String, Any?>>()
        val summary = DiagnosticSummary()
        val processBuilds = store.processBuilds()
        val includedBuilds = linkedMapOf<String, Any?>()
        var unknownBuilds = 0L
        val referencedIncidents = linkedSetOf<String>()
        val includedIncidents = linkedSetOf<String>()
        var firstTime: Long? = null
        var lastTime: Long? = null
        var eventCount = 0L
        var manifest: Map<String, Any?> = emptyMap()
        fun check() {
            if (cancelled()) throw DiagnosticFailure("cancelled")
            if (store.clock.monotonicMillis() > snapshot.expires) throw DiagnosticFailure("timeout")
        }
        try {
            FileOutputStream(output).use { fileOutput ->
                val bounded = object : FilterOutputStream(fileOutput) {
                    var total = 0L
                    override fun write(value: Int) { if (++total > store.limits.staging) throw DiagnosticFailure("size_limit"); out.write(value) }
                    override fun write(bytes: ByteArray, offset: Int, count: Int) { if (total + count > store.limits.staging) throw DiagnosticFailure("size_limit"); out.write(bytes, offset, count); total += count }
                }
                ZipOutputStream(bounded).use { zip ->
                    fun entry(name: String, write: (OutputStream) -> Unit) {
                        check()
                        zip.putNextEntry(ZipEntry(name))
                        val digest = MessageDigest.getInstance("SHA-256")
                        var count = 0L
                        val target = object : OutputStream() {
                            override fun write(value: Int) { try { zip.write(value) } catch (error: Exception) { throw DiagnosticArchiveFailure(error) }; digest.update(value.toByte()); count++ }
                            override fun write(bytes: ByteArray, offset: Int, size: Int) { try { zip.write(bytes, offset, size) } catch (error: Exception) { throw DiagnosticArchiveFailure(error) }; digest.update(bytes, offset, size); count += size }
                        }
                        write(target)
                        zip.closeEntry()
                        entries.add(mapOf("path" to name, "bytes" to count, "sha256" to digest.digest().joinToString("") { "%02x".format(it) }))
                    }
                    entry("environment.json") { it.write(DiagnosticJson.bytes(cleanEnvironment)) }
                    if (cleanState != null) entry("state.json") { it.write(DiagnosticJson.bytes(cleanState)) }
                    for ((index, segment) in snapshot.files.withIndex()) {
                        check()
                        if (!segment.file.exists()) { missing.add("missing"); continue }
                        entry("${if (segment.incident) "incidents" else "events"}/${index.toString().padStart(3, '0')}.jsonl") { target ->
                            try {
                                segment.file.bufferedReader(Charsets.UTF_8).use { source ->
                                    val headerText = source.readLine() ?: throw DiagnosticFailure("corrupt_tail")
                                    if (headerText.length > 1024) throw DiagnosticFailure("corrupt_tail")
                                    val header = store.decode(headerText)
                                    if (DiagnosticVocabulary.number(header["schema_version"]) !in 1L..2L || header["generation"] != segment.generation) throw DiagnosticFailure("unsupported_version")
                                    while (true) {
                                        check()
                                        val line = source.readLine() ?: break
                                        if (line.length > (if (segment.incident) 48 * 1024 else 8 * 1024)) throw DiagnosticFailure("size_limit")
                                        val item = store.decode(line)
                                        if (item["schema_version"] != header["schema_version"] || !DiagnosticStoredValidator.valid(item, segment.incident)) throw DiagnosticFailure("sanitization_rejected")
                                        // Re-encode validated values; never copy unvalidated bytes.
                                        target.write(DiagnosticJson.bytes(item)); target.write(10)
                                        if (segment.incident) includedIncidents.add(item["incident_id"] as String)
                                        else {
                                            eventCount++
                                            val time = (item["time_utc"] as Number).toLong()
                                            firstTime = minOf(firstTime ?: time, time); lastTime = maxOf(lastTime ?: time, time)
                                            (item["incident_id"] as? String)?.let { if (referencedIncidents.size < 4096) referencedIncidents.add(it) else missing.add("truncated") }
                                            summary.offer(item)
                                            val identity = item["process_instance"] as String
                                            if (identity !in includedBuilds) {
                                                if (includedBuilds.size < 32) includedBuilds[identity] = processBuilds[identity]
                                                else missing.add("truncated")
                                            }
                                            if (processBuilds[identity] == null) unknownBuilds++

                                        }
                                    }
                                }
                            } catch (error: DiagnosticArchiveFailure) { throw error }
                            catch (error: DiagnosticFailure) {
                                if (error.code in setOf("cancelled", "timeout")) throw error
                                missing.add(error.code)
                            } catch (_: Exception) { missing.add("read_failed") }
                        }
                    }
                    if (referencedIncidents.any { it !in includedIncidents }) missing.add("missing")
                    val summaryText = buildString {
                        append("SetTrace diagnostic report ${snapshot.id}\n")
                        append("Cutoff UTC milliseconds: ${snapshot.cutoff}\n")
                        append("Operation records: $eventCount. Range: ${firstTime ?: "none"} .. ${lastTime ?: "none"}\n")
                        append("Evidence only: committed describes a confirmed business commit; later follow-up failures do not undo it. Missing terminal events are unknown. Requests do not prove a user saw/heard an alert.\n")
                        append("Snapshots have their own capture times. No inferred root cause is asserted. This file is not a backup and is not encrypted.\n")
                        append("Unavailable/limited: ${missing.joinToString(",").ifEmpty { "none known" }}\n")
                        append(summary.render())
                    }
                    check(summaryText.toByteArray(Charsets.UTF_8).size <= 32 * 1024)
                    entry("summary.txt") { it.write(summaryText.toByteArray(Charsets.UTF_8)) }
                    manifest = mapOf(
                        "format" to "settrace.diagnostics", "format_version" to 2,
                        "report_id" to snapshot.id, "created_utc" to store.clock.wallMillis(), "cutoff_utc" to snapshot.cutoff,
                        "application" to cleanEnvironment["application"], "first_event_utc" to firstTime, "last_event_utc" to lastTime,
                        "process_builds" to includedBuilds.toMap(), "events_with_unknown_build" to unknownBuilds,
                        "event_count" to eventCount, "coverage_continuous" to false,
                        "retention_hours" to 168, "log_limit_bytes" to store.limits.events + store.limits.incidents,
                        "known_missing" to missing.toList(), "loss_counts" to store.lossCounts(), "loss_observed_ranges" to store.lossIntervals(), "entries" to entries.toList(),
                        "integrity" to "sha256_not_authentication", "encrypted" to false,
                    )
                    zip.putNextEntry(ZipEntry("manifest.json")); zip.write(DiagnosticJson.bytes(manifest)); zip.closeEntry()
                    zip.finish()
                    fileOutput.fd.sync()
                }
            }
            check()
            // Verify archive structure and all uncompressed resource digests.
            ZipFile(output).use { zip ->
                for (item in entries) {
                    val entry = zip.getEntry(item["path"] as String) ?: throw DiagnosticFailure("verification_failed")
                    val digest = zip.getInputStream(entry).use { diagnosticDigest(it, store.limits.staging, ::check) }
                    if (digest.first != item["bytes"] || digest.second != item["sha256"]) throw DiagnosticFailure("verification_failed")
                }
                if (zip.getEntry("manifest.json") == null) throw DiagnosticFailure("verification_failed")
            }
            val digest = output.inputStream().use { diagnosticDigest(it, store.limits.staging, ::check) }
            return DiagnosticPackage(output, digest.first, digest.second, missing.toList(), manifest)
        } catch (error: Exception) {
            if (!output.delete() && output.exists()) store.loss("write_failed")
            if (error is DiagnosticArchiveFailure && error.cause is DiagnosticFailure) throw error.cause as DiagnosticFailure
            throw error
        }
    }

    private fun sanitizeEnvironment(value: Map<String, Any?>?): Map<String, Any?>? {
        if (value == null || value.keys.any { it !in setOf("application", "android_api", "android_version", "device_model", "captured_utc", "notifications_allowed", "exact_allowed", "exit_information", "exit_trace") }) return null
        if (DiagnosticVocabulary.number(value["android_api"]) == null || DiagnosticVocabulary.number(value["captured_utc"]) == null) return null
        val application = value["application"] as? Map<*, *> ?: return null
        if (application.keys.any { it !in setOf("package", "version", "build", "supported_database_schema", "obfuscated") }) return null
        if (application["package"] != "com.settrace.settrace") return null
        val safeText = Regex("[a-zA-Z0-9 ._+()/-]{1,96}")
        for (key in listOf("version", "build")) { val text = application[key]; if (text != null && (text !is String || !Regex(if (key == "build") "[0-9]{1,20}" else "[a-zA-Z0-9._+()-]{1,64}").matches(text))) return null }
        if (application["supported_database_schema"] != null && DiagnosticVocabulary.number(application["supported_database_schema"]) == null) return null
        if (application["obfuscated"] != null && application["obfuscated"] !is Boolean) return null
        for (key in listOf("android_version", "device_model")) { val text = value[key]; if (text != null && (text !is String || !safeText.matches(text))) return null }
        for (key in listOf("notifications_allowed", "exact_allowed")) if (value[key] != null && value[key] !is Boolean) return null
        if (value["exit_information"] !in setOf("supported", "unsupported", "not_available", "no_records", "read_failed")) return null
        if (value["exit_trace"] != null && value["exit_trace"] !in setOf("available", "not_available", "read_failed", "sanitization_rejected", "truncated")) return null
        return value
    }

    private fun sanitizeState(value: Map<*, *>?): Map<String, Any?>? {
        if (value == null || value.size > 16) return null
        val flags = setOf("available", "active")
        val numbers = setOf("captured_utc", "target_count", "completed_count", "skipped_count", "revision", "due_utc", "dataset_epoch")
        if (value.any { (key, item) -> when (key) { in flags -> item !is Boolean; in numbers -> DiagnosticVocabulary.number(item) == null; "reason" -> item !in DiagnosticVocabulary.reasons; else -> true } }) return null
        if (value["available"] !is Boolean || DiagnosticVocabulary.number(value["captured_utc"]) == null) return null
        return value.entries.associate { it.key as String to it.value }
    }
}
