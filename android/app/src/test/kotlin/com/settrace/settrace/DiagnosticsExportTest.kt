package com.settrace.settrace

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.util.Properties
import java.util.concurrent.Executor
import java.util.zip.ZipFile
import org.junit.Assert.*
import org.junit.Test

class DiagnosticsExportTest {
    private class Work : Executor {
        private var action: Runnable? = null
        override fun execute(command: Runnable) { check(action == null); action = command }
        fun run() { val current = action!!; action = null; current.run() }
    }
    private class Entry(override val name: String) : DiagnosticPublicEntry {
        override val locator = "test:owned"
        val bytes = ByteArrayOutputStream()
        var delivered = false
        var unknown = false
        var discarded = false
        var onClose: (() -> Unit)? = null
        var onPublish: (() -> Unit)? = null
        var failWrite = false
        override fun output(): OutputStream = object : OutputStream() {
            override fun write(value: Int) { if (failWrite) throw IOException("injected"); bytes.write(value) }
            override fun write(value: ByteArray, offset: Int, length: Int) { if (failWrite) throw IOException("injected"); bytes.write(value, offset, length) }
            override fun close() { onClose?.invoke() }
        }
        override fun input() = ByteArrayInputStream(bytes.toByteArray())
        override fun publish() { delivered = true; onPublish?.invoke() }
        override fun published(): Boolean? = if (unknown) null else delivered
        override fun discardPending(): Boolean { if (delivered || unknown) return false; discarded = true; return true }
    }
    private class PublicFiles : DiagnosticPublicFiles {
        var entry: Entry? = null
        var reservations = 0
        var afterCreation: (() -> Unit)? = null
        var missing = false
        override fun reserve(id: String, proposed: String, beforeReservation: (String) -> Unit): DiagnosticPublicEntry {
            reservations++
            // Simulate a provider's collision-safe actual name.
            val actual = proposed.removeSuffix(".zip") + " (1).zip"
            beforeReservation(actual)
            val result = Entry(actual)
            entry = result
            afterCreation?.invoke()
            return result
        }
        override fun find(id: String, name: String, locator: String?): DiagnosticPublicEntry? = if (missing) null else entry
    }
    private fun environment(time: Long): Map<String, Any?> = mapOf("application" to mapOf("package" to "com.settrace.settrace", "version" to "0.2.4", "build" to "10", "supported_database_schema" to 6), "android_api" to 36, "captured_utc" to time, "exit_information" to "supported")
    private fun state(time: Long): Map<String, Any?> = mapOf("available" to true, "captured_utc" to time, "active" to false)

    @Test fun mixedPackagePreservesEventVersionsAndMissingHistoricalBuildIsUnknown() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store()
            store.append(fixture.record(store)); store.append(fixture.record(store,version = 2))
            val built = DiagnosticPackageBuilder(store).build(store.beginSnapshot(),environment(fixture.clock.wall),state(fixture.clock.wall)) { false }
            assertEquals(2,built.manifest["format_version"])
            assertEquals(2L,built.manifest["event_count"])
            assertEquals(2L,built.manifest["events_with_unknown_build"])
            val mapping = built.manifest["process_builds"] as Map<*,*>
            assertTrue(mapping.containsKey("c".repeat(32))); assertNull(mapping["c".repeat(32)])
            ZipFile(built.file).use { zip ->
                val eventText = zip.entries().asSequence().filter { it.name.startsWith("events/") }.joinToString("") { zip.getInputStream(it).bufferedReader().readText() }
                assertTrue(eventText.contains("\"schema_version\":1")); assertTrue(eventText.contains("\"schema_version\":2"))
            }
        } finally { fixture.dispose() }
    }
    @Test fun packageContainsValidatedResourcesManifestAndReadableEvidence() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store()
            store.append(fixture.record(store, frames = true))
            val snapshot = store.beginSnapshot()
            val built = DiagnosticPackageBuilder(store).build(snapshot, environment(fixture.clock.wall), state(fixture.clock.wall)) { false }
            assertEquals(2, built.manifest["format_version"])
            assertEquals("settrace.diagnostics", built.manifest["format"])
            assertEquals(1L, built.manifest["event_count"])
            assertFalse(built.manifest["coverage_continuous"] as Boolean)
            ZipFile(built.file).use { zip ->
                val summary = zip.getInputStream(zip.getEntry("summary.txt")).bufferedReader().readText()
                assertTrue(summary.contains("committed describes a confirmed business commit"))
                assertTrue(summary.contains("workout.complete"))
                val all = zip.entries().asSequence().joinToString { zip.getInputStream(it).bufferedReader().readText() }
                assertFalse(all.contains("\"session\":42"))
                assertFalse(all.contains("control.properties"))
                assertFalse(all.contains("export.properties"))
                assertFalse(all.contains(File(fixture.root, "control.properties").readText().substringAfter("key=").substringBefore('\n').trim()))
            }
            assertTrue(built.bytes <= store.limits.staging)
            store.releaseSnapshot(snapshot.id)
        } finally { fixture.dispose() }
    }
    @Test fun environmentOnlyPackageHasNoFabricatedOperationRange() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store(); val snapshot = store.beginSnapshot()
            val built = DiagnosticPackageBuilder(store).build(snapshot, environment(fixture.clock.wall), state(fixture.clock.wall)) { false }
            assertEquals(0L, built.manifest["event_count"])
            assertNull(built.manifest["first_event_utc"])
            assertNull(built.manifest["last_event_utc"])
            assertTrue(built.missing.isEmpty())
            store.releaseSnapshot(snapshot.id)
        } finally { fixture.dispose() }
    }
    @Test fun unavailableNecessaryEnvironmentCannotBecomeEmptySuccess() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store(); val snapshot = store.beginSnapshot()
            try { DiagnosticPackageBuilder(store).build(snapshot, null, null) { false }; fail("no empty success") } catch (error: DiagnosticFailure) { assertEquals("not_available", error.code) }
            assertTrue(store.stagingDirectory.listFiles()!!.isEmpty())
            store.releaseSnapshot(snapshot.id)
        } finally { fixture.dispose() }
    }
    @Test fun unsafeStateAndDamagedOptionalEventsAreOmittedWithoutRawLeak() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store(); store.append(fixture.record(store)); val snapshot = store.beginSnapshot()
            snapshot.files.first().file.appendText("{\"private\":\"PRIVATE_SQL_AND_FILENAME\"}\n")
            val built = DiagnosticPackageBuilder(store).build(snapshot, environment(fixture.clock.wall), mapOf("name" to "PRIVATE_SQL_AND_FILENAME")) { false }
            assertTrue(built.missing.contains("sanitization_rejected"))
            ZipFile(built.file).use { zip -> assertFalse(zip.entries().asSequence().joinToString { zip.getInputStream(it).bufferedReader().readText() }.contains("PRIVATE_SQL_AND_FILENAME")) }
            store.releaseSnapshot(snapshot.id)
        } finally { fixture.dispose() }
    }
    @Test fun packageCancellationAndSizeLimitCleanPrivateOutput() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            var store = fixture.store(); var snapshot = store.beginSnapshot()
            try { DiagnosticPackageBuilder(store).build(snapshot, environment(fixture.clock.wall), state(fixture.clock.wall)) { true }; fail("cancel") } catch (error: DiagnosticFailure) { assertEquals("cancelled", error.code) }
            assertTrue(store.stagingDirectory.listFiles()!!.isEmpty()); store.releaseSnapshot(snapshot.id)
            store = fixture.store(customLimits = fixture.limits.copy(staging = 32)); snapshot = store.beginSnapshot()
            try { DiagnosticPackageBuilder(store).build(snapshot, environment(fixture.clock.wall), state(fixture.clock.wall)) { false }; fail("size limit") } catch (error: DiagnosticFailure) { assertEquals("size_limit", error.code) }
            assertTrue(store.stagingDirectory.listFiles()!!.isEmpty()); store.releaseSnapshot(snapshot.id)
        } finally { fixture.dispose() }
    }
    @Test fun successUsesActualNameAndOnlyReturnsAfterPublicationAndVerification() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store(); val work = Work(); val files = PublicFiles()
            val coordinator = DiagnosticExportCoordinator(store, files, work) { environment(fixture.clock.wall) }
            val initial = coordinator.start(store.beginSnapshot(), state(fixture.clock.wall))
            assertEquals(DiagnosticExportStage.collecting, initial.stage)
            assertTrue(coordinator.busy())
            work.run()
            assertEquals(DiagnosticExportStage.saved, coordinator.current()!!.stage)
            assertEquals(files.entry!!.name, coordinator.current()!!.fileName)
            assertTrue(files.entry!!.delivered)
            assertFalse(files.entry!!.discarded)
            assertFalse(coordinator.busy())
            assertTrue(store.stagingDirectory.listFiles()!!.isEmpty())
        } finally { fixture.dispose() }
    }
    @Test fun cancelBeforeStartAndDuringCopyNeverPublishes() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store(); val work = Work(); val files = PublicFiles()
            val coordinator = DiagnosticExportCoordinator(store, files, work) { environment(fixture.clock.wall) }
            var initial = coordinator.start(store.beginSnapshot(), state(fixture.clock.wall))
            coordinator.cancel(initial.id); work.run()
            assertEquals(DiagnosticExportStage.cancelled, coordinator.current()!!.stage)
            assertEquals(0, files.reservations)
            initial = coordinator.start(store.beginSnapshot(), state(fixture.clock.wall))
            files.afterCreation = { files.entry!!.onClose = { coordinator.cancel(initial.id) } }
            work.run()
            assertEquals(DiagnosticExportStage.cancelled, coordinator.current()!!.stage)
            assertTrue(files.entry!!.discarded)
            assertFalse(files.entry!!.delivered)
        } finally { fixture.dispose() }
    }
    @Test fun cancellationAtPublishCannotDeleteDeliveredFileOrClaimCancelled() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store(); val work = Work(); val files = PublicFiles()
            val coordinator = DiagnosticExportCoordinator(store, files, work) { environment(fixture.clock.wall) }
            val initial = coordinator.start(store.beginSnapshot(), state(fixture.clock.wall))
            files.afterCreation = { files.entry!!.onPublish = { val result = coordinator.cancel(initial.id); assertEquals(DiagnosticExportStage.publishing, result.stage) } }
            work.run()
            assertEquals(DiagnosticExportStage.saved, coordinator.current()!!.stage)
            assertFalse(files.entry!!.discarded)
        } finally { fixture.dispose() }
    }
    @Test fun exceptionAfterActualPublishRecoversVerifiedSuccess() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store(); val work = Work(); val files = PublicFiles()
            val coordinator = DiagnosticExportCoordinator(store, files, work) { environment(fixture.clock.wall) }
            coordinator.start(store.beginSnapshot(), state(fixture.clock.wall))
            files.afterCreation = { files.entry!!.onPublish = { throw IOException("result lost after publication") } }
            work.run()
            assertEquals(DiagnosticExportStage.saved, coordinator.current()!!.stage)
            assertFalse(files.entry!!.discarded)
        } finally { fixture.dispose() }
    }
    @Test fun restartInspectsOriginalDestinationAndNeverRegenerates() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store(); val work = Work(); val files = PublicFiles()
            val original = DiagnosticExportCoordinator(store, files, work) { environment(fixture.clock.wall) }
            original.start(store.beginSnapshot(), state(fixture.clock.wall)); work.run()
            val journalFile = File(fixture.root, "export.properties")
            val journal = Properties().also { journalFile.inputStream().use { input -> it.load(input) } }
            journal.setProperty("stage", "publishing"); journalFile.outputStream().use { journal.store(it, "simulate exit before receipt") }
            val restarted = DiagnosticExportCoordinator(store, files, work) { environment(fixture.clock.wall) }
            assertEquals(DiagnosticExportStage.unknown, restarted.current()!!.stage)
            assertEquals(DiagnosticExportStage.saved, restarted.inspect().stage)
            assertEquals(1, files.reservations)
            files.missing = true
            assertEquals(DiagnosticExportStage.failed, restarted.inspect().stage)
            assertEquals(1, files.reservations)
        } finally { fixture.dispose() }
    }
    @Test fun ownershipGapAndUnknownPublicationRequireInspectionWithoutDeletingDeliveredOutput() {
        val fixture = DiagnosticsStoreTest.Fixture()
        try {
            val store = fixture.store(); val work = Work(); val files = PublicFiles()
            val coordinator = DiagnosticExportCoordinator(store, files, work) { environment(fixture.clock.wall) }
            coordinator.start(store.beginSnapshot(), state(fixture.clock.wall))
            files.afterCreation = { throw IOException("created before journal receipt") }
            work.run()
            assertEquals(DiagnosticExportStage.unknown, coordinator.current()!!.stage)
            assertFalse(files.entry!!.discarded)
            assertEquals(DiagnosticExportStage.failed, coordinator.inspect().stage)
            assertTrue(files.entry!!.discarded)
            files.afterCreation = { files.entry!!.onPublish = { files.entry!!.unknown = true } }
            coordinator.start(store.beginSnapshot(), state(fixture.clock.wall)); work.run()
            assertEquals(DiagnosticExportStage.unknown, coordinator.current()!!.stage)
            assertTrue(files.entry!!.delivered)
            assertFalse(files.entry!!.discarded)
            try { coordinator.start(store.beginSnapshot(), state(fixture.clock.wall)); fail("must inspect first") } catch (error: DiagnosticFailure) { assertEquals("publication_unknown", error.code) }
            assertEquals(2, files.reservations)
        } finally { fixture.dispose() }
    }
    @Test fun originalCrashHandlerRunsEvenWhenRecordingThrows() {
        var delegated = false
        val error = IllegalStateException("private exception")
        val handler = DiagnosticCrashHandler(Thread.UncaughtExceptionHandler { _, received -> assertSame(error, received); delegated = true }) { throw OutOfMemoryError("diagnostics must not replace termination") }
        handler.uncaughtException(Thread.currentThread(), error)
        assertTrue(delegated)
    }
}
