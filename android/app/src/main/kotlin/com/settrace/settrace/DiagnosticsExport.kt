package com.settrace.settrace

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.Properties
import java.util.concurrent.Executor

interface DiagnosticPublicEntry {
    val locator: String
    val name: String
    fun output(): OutputStream
    fun input(): InputStream
    fun publish()
    /** null is not proof of either publication or absence. */
    fun published(): Boolean?
    fun discardPending(): Boolean
}

interface DiagnosticPublicFiles {
    fun reserve(id: String, proposed: String, beforeReservation: (String) -> Unit): DiagnosticPublicEntry
    fun find(id: String, name: String, locator: String?): DiagnosticPublicEntry?
}

/** Export state is independent of business writes and survives Activity loss.
 * Only the most recent task is retained, within the auxiliary metadata budget.
 */
class DiagnosticExportCoordinator(
    private val store: DiagnosticStore,
    private val files: DiagnosticPublicFiles,
    private val executor: Executor,
    private val observer: (DiagnosticExportState) -> Unit = {},
    private val environment: () -> Map<String, Any?>?,
) {
    private val journalFile = File(store.root, "export.properties")
    private var journal = Properties()
    @Volatile private var status: DiagnosticExportState? = null
    @Volatile private var cancellation = false
    @Volatile private var active = false
    private var source: DiagnosticPackage? = null

    init {
        try {
            DiagnosticAtomicFile.recover(journalFile)
            if (journalFile.exists()) {
                require(journalFile.length() <= 64 * 1024)
                journalFile.inputStream().use { journal.load(it) }
                require(journal.getProperty("version") == "1")
                require(DiagnosticVocabulary.token.matches(journal.getProperty("id", "")))
                require(journal.stringPropertyNames().all { it in setOf("version", "id", "stage", "name", "locator", "bytes", "digest", "missing", "reason") })
                val recorded = DiagnosticExportStage.valueOf(journal.getProperty("stage"))
                val stage = if (recorded.terminal) recorded else DiagnosticExportStage.unknown
                status = stateFromJournal(stage, if (stage == DiagnosticExportStage.unknown) "publication_unknown" else journal.getProperty("reason"))
            }
        } catch (_: Exception) {
            // An unreadable ownership record must never trigger automatic retry
            // or deletion of a potentially delivered public file.
            journal = Properties()
            status = DiagnosticExportState("0".repeat(32), DiagnosticExportStage.unknown, false, reason = "publication_unknown")
        }
    }

    fun current(): DiagnosticExportState? = status
    fun busy(): Boolean = active
    fun needsInspection(): Boolean = status?.stage == DiagnosticExportStage.unknown

    @Synchronized fun start(snapshot: DiagnosticSnapshot, state: Map<*, *>?): DiagnosticExportState {
        if (active) { if (status?.id == snapshot.id) return status!!; store.releaseSnapshot(snapshot.id); throw DiagnosticFailure("busy") }
        if (needsInspection()) { store.releaseSnapshot(snapshot.id); throw DiagnosticFailure("publication_unknown") }
        cancellation = false; active = true; source = null
        val stamp = SimpleDateFormat("yyyy-MM-dd-HHmmss-SSS", Locale.ROOT).format(Date(snapshot.cutoff))
        journal = Properties().apply {
            setProperty("version", "1"); setProperty("id", snapshot.id)
            setProperty("name", "SetTrace-diagnostics-$stamp-${snapshot.id}.zip")
            setProperty("stage", DiagnosticExportStage.collecting.name)
        }
        val initial = DiagnosticExportState(snapshot.id, DiagnosticExportStage.collecting, true)
        status = initial
        try { saveJournal() } catch (error: Exception) { active = false; store.releaseSnapshot(snapshot.id); throw error }
        executor.execute { run(snapshot, state) }
        return initial
    }

    fun cancel(id: String): DiagnosticExportState {
        synchronized(this) {
            val current = status ?: throw DiagnosticFailure("missing")
            if (id != current.id) throw DiagnosticFailure("not_found")
            if (current.cancellable && !current.stage.terminal) {
                cancellation = true
                status = current.copy(stage = DiagnosticExportStage.cancelling, cancellable = false)
            }
            return status!!
        }
    }

    private fun checkCancellation() { if (cancellation) throw DiagnosticFailure("cancelled") }

    private fun run(snapshot: DiagnosticSnapshot, state: Map<*, *>?) {
        var destination: DiagnosticPublicEntry? = null
        var publicationStarted = false
        var reservationStarted = false
        try {
            checkCancellation()
            transition(DiagnosticExportStage.packaging)
            val built = DiagnosticPackageBuilder(store).build(snapshot, environment(), state) { cancellation }
            source = built
            journal.setProperty("bytes", built.bytes.toString()); journal.setProperty("digest", built.digest)
            journal.setProperty("missing", built.missing.joinToString(","))
            saveJournal()
            checkCancellation()
            reservationStarted = true
            destination = files.reserve(snapshot.id, journal.getProperty("name")) { planned ->
                checkCancellation()
                journal.setProperty("name", planned); saveJournal()
            }
            journal.setProperty("name", destination.name); journal.setProperty("locator", destination.locator)
            saveJournal()
            transition(DiagnosticExportStage.writing_unpublished)
            destination.output().use { output ->
                built.file.inputStream().use { input ->
                    val buffer = ByteArray(32 * 1024)
                    var total = 0L
                    while (true) {
                        checkCancellation()
                        val count = input.read(buffer)
                        if (count < 0) break
                        total += count
                        if (total > store.limits.staging) throw DiagnosticFailure("size_limit")
                        output.write(buffer, 0, count)
                    }
                    output.flush()
                }
            }
            transition(DiagnosticExportStage.verifying)
            if (!verify(destination, ::checkCancellation)) throw DiagnosticFailure("verification_failed")
            synchronized(this) {
                checkCancellation()
                publicationStarted = true
                status = status!!.copy(stage = DiagnosticExportStage.publishing, cancellable = false)
            }
            journal.setProperty("stage", DiagnosticExportStage.publishing.name); saveJournal()
            destination.publish()
            if (destination.published() != true || !verify(destination)) throw DiagnosticFailure("publication_unknown")
            transition(if (built.missing.isEmpty()) DiagnosticExportStage.saved else DiagnosticExportStage.saved_partial)
        } catch (error: Exception) {
            var reason = when (error) { is DiagnosticFailure -> error.code; is SecurityException -> "permission_denied"; else -> "storage_unavailable" }
            var stage = if (reason == "cancelled") DiagnosticExportStage.cancelled else DiagnosticExportStage.failed
            if (publicationStarted) {
                try {
                    if (destination?.published() == true && verify(destination)) {
                        stage = if (source?.missing.isNullOrEmpty()) DiagnosticExportStage.saved else DiagnosticExportStage.saved_partial
                        reason = "none"
                    } else if (destination?.published() != false) { stage = DiagnosticExportStage.unknown; reason = "publication_unknown" }
                    else if (destination?.discardPending() != true) { stage = DiagnosticExportStage.unknown; reason = "publication_unknown" }
                } catch (_: Exception) { stage = DiagnosticExportStage.unknown; reason = "publication_unknown" }
            } else if (destination != null) {
                try { if (!destination.discardPending()) { stage = DiagnosticExportStage.unknown; reason = "publication_unknown" } }
                catch (_: Exception) { stage = DiagnosticExportStage.unknown; reason = "publication_unknown" }
            } else if (reservationStarted || journal.getProperty("locator") != null) {
                stage = DiagnosticExportStage.unknown; reason = "publication_unknown"
            }
            try { transition(stage, reason) }
            catch (_: Exception) { status = status!!.copy(stage = if (stage in setOf(DiagnosticExportStage.saved, DiagnosticExportStage.saved_partial)) stage else DiagnosticExportStage.unknown, cancellable = false, reason = "publication_unknown") }
        } finally {
            val temporary = source?.file
            if (temporary != null && !temporary.delete() && temporary.exists()) store.loss("write_failed")
            source = null
            store.releaseSnapshot(snapshot.id)
            active = false
        }
    }

    private fun verify(entry: DiagnosticPublicEntry?, check: () -> Unit = {}): Boolean {
        if (entry == null) return false
        val expectedSize = journal.getProperty("bytes")?.toLongOrNull() ?: return false
        val expectedHash = journal.getProperty("digest") ?: return false
        val actual = entry.input().use { diagnosticDigest(it, store.limits.staging, check) }
        return actual.first == expectedSize && actual.second == expectedHash
    }

    private fun transition(stage: DiagnosticExportStage, reason: String? = null) {
        synchronized(this) {
            val current = status ?: throw DiagnosticFailure("missing")
            // A cancellation intention cannot be overwritten by late progress.
            if (cancellation && !stage.terminal && stage != DiagnosticExportStage.publishing) throw DiagnosticFailure("cancelled")
            status = current.copy(stage = stage, cancellable = !stage.terminal && stage != DiagnosticExportStage.publishing, fileName = journal.getProperty("name"), bytes = journal.getProperty("bytes")?.toLongOrNull(), reason = reason, missing = journal.getProperty("missing", "").split(',').filter { it in DiagnosticVocabulary.reasons })
            journal.setProperty("stage", stage.name)
            if (reason != null) journal.setProperty("reason", reason) else journal.remove("reason")
        }
        saveJournal()
        // Publication belongs to later diagnostics, after the sealed ZIP cutoff.
        try { observer(status!!) } catch (_: Exception) { /* observation never changes publication */ }
    }

    /** User-driven only. Never republishes or recreates any file. */
    @Synchronized fun inspect(): DiagnosticExportState {
        if (active) return status ?: throw DiagnosticFailure("busy")
        val current = status ?: throw DiagnosticFailure("missing")
        if (journal.getProperty("id") == null) return current
        try {
            val destination = files.find(current.id, journal.getProperty("name"), journal.getProperty("locator"))
            val stage: DiagnosticExportStage
            val reason: String?
            when {
                destination == null -> { stage = DiagnosticExportStage.failed; reason = "missing" }
                destination.published() == true && verify(destination) -> { stage = if (journal.getProperty("missing", "").isEmpty()) DiagnosticExportStage.saved else DiagnosticExportStage.saved_partial; reason = null }
                destination.published() == false -> {
                    if (!destination.discardPending()) throw DiagnosticFailure("publication_unknown")
                    stage = DiagnosticExportStage.failed; reason = "incomplete"
                }
                else -> throw DiagnosticFailure("publication_unknown")
            }
            journal.setProperty("locator", destination?.locator ?: journal.getProperty("locator", ""))
            if (destination != null) journal.setProperty("name", destination.name)
            transition(stage, reason)
        } catch (_: Exception) { status = current.copy(stage = DiagnosticExportStage.unknown, cancellable = false, reason = "publication_unknown") }
        return status!!
    }

    private fun stateFromJournal(stage: DiagnosticExportStage, reason: String?): DiagnosticExportState = DiagnosticExportState(
        journal.getProperty("id"), stage, false, journal.getProperty("name"), journal.getProperty("bytes")?.toLongOrNull(), reason,
        journal.getProperty("missing", "").split(',').filter { it in DiagnosticVocabulary.reasons }
    )

    private fun saveJournal() {
        val data = ByteArrayOutputStream().also { journal.store(it, "SetTrace diagnostic export v1") }.toByteArray()
        if (data.size > 64 * 1024 || store.metadataBytes() + data.size * 2 > store.limits.metadata) throw DiagnosticFailure("size_limit")
        DiagnosticAtomicFile.write(journalFile, data)
    }
}
