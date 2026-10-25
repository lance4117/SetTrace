package com.settrace.settrace

import android.content.Context
import android.os.Build
import android.os.StrictMode
import android.provider.MediaStore
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.zip.ZipInputStream

@RunWith(AndroidJUnit4::class)
class DiagnosticsPlatformTest {
    private val context: Context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private fun command(engine: DiagnosticEngine, method: String, args: Map<String, Any?> = emptyMap()): Map<String, Any?> {
        val latch = CountDownLatch(1)
        var output: Map<String, Any?>? = null
        engine.submit(method, args) { output = it; latch.countDown() }
        assertTrue("$method callback", latch.await(10, TimeUnit.SECONDS))
        return output!!
    }
    private fun root() = File(context.noBackupFilesDir, "diagnostics-test-${UUID.randomUUID()}")

    @Test fun noActivityWriterUsesNoBackupAndRejectsPrivateContentBeforeDisk() {
        val root = root(); val engine = DiagnosticEngine(context, root)
        try {
            assertTrue(root.canonicalPath.startsWith(context.noBackupFilesDir.canonicalPath + File.separator))
            command(engine, "overview")
            val old = StrictMode.getThreadPolicy()
            StrictMode.setThreadPolicy(StrictMode.ThreadPolicy.Builder().detectDiskReads().detectDiskWrites().penaltyDeath().build())
            try {
                engine.record("workout.complete", "committed", "committed", objects = mapOf("session" to 42), epoch = 9)
                engine.record("workout.complete", "failed", attributes = mapOf("name" to "PRIVATE_NAME_WEIGHT_URI_SENTINEL"))
            } finally { StrictMode.setThreadPolicy(old) }
            val value = command(engine, "overview")
            assertTrue((value["event_count"] as Long) >= 1)
            val events = File(root, "events").listFiles()!!.joinToString("") { it.readText() }
            assertFalse(events.contains("PRIVATE_NAME_WEIGHT_URI_SENTINEL"))
            assertFalse(events.contains("\"session\":42"))
            assertTrue(events.contains("\"session\":\""))
        } finally { engine.closeForTests(); root.deleteRecursively() }
    }
    @Test fun disabledNoEngineRecordingAndClearRespectConfirmedGeneration() {
        val root = root(); var engine = DiagnosticEngine(context, root)
        try {
            command(engine, "overview")
            command(engine, "setEnabled", mapOf("enabled" to false))
            val first = command(engine, "clear")
            repeat(100) { engine.record("rest.output", "output") }
            assertEquals(0L, command(engine, "overview")["event_count"])
            engine.closeForTests(); engine = DiagnosticEngine(context, root)
            assertEquals(false, command(engine, "overview")["enabled"])
            engine.record("rest.output", "output")
            assertEquals(0L, command(engine, "overview")["event_count"])
            command(engine, "setEnabled", mapOf("enabled" to true))
            val cleared = command(engine, "clear")
            assertNotEquals(first["generation"], cleared["generation"])
            command(engine, "recordBatch", mapOf("records" to emptyList<String>(), "generation" to first["generation"], "process_instance" to "c".repeat(32), "dart_dropped" to 999))
            assertFalse((command(engine, "overview")["missing"] as List<*>).contains("queue_overflow"))
            command(engine, "recordBatch", mapOf("records" to emptyList<String>(), "generation" to cleared["generation"], "process_instance" to "c".repeat(32), "dart_dropped" to 2))
            assertTrue((command(engine, "overview")["missing"] as List<*>).contains("queue_overflow"))
            engine.record("rest.output", "output", attributes = mapOf("round" to 1))
            assertTrue((command(engine, "overview")["event_count"] as Long) >= 1L)
            val recorded = File(root, "events").listFiles()!!.joinToString("") { it.readText() }
            assertTrue(recorded.contains("rest.output"))
            assertTrue(recorded.contains("diagnostics.clear"))
        } finally { engine.closeForTests(); root.deleteRecursively() }
    }
    @Test fun realDownloadsPublishesVerifiedReadableZipAndInspectionDoesNotDuplicate() {
        assumeTrue(Build.VERSION.SDK_INT >= 29)
        val root = root(); val engine = DiagnosticEngine(context, root)
        var publicUri: android.net.Uri? = null
        try {
            command(engine, "overview")
            engine.record("workout.complete", "committed", "committed", objects = mapOf("session" to 1), epoch = 0)
            val started = command(engine, "startExport", mapOf("state" to mapOf("available" to true, "captured_utc" to System.currentTimeMillis(), "active" to true)))
            val id = started["export_id"] as String
            var result = started
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(30)
            while (result["stage"] !in setOf("saved", "saved_partial", "failed", "unknown", "cancelled") && System.nanoTime() < deadline) {
                Thread.sleep(50); result = command(engine, "exportStatus", mapOf("export_id" to id))
            }
            assertTrue(result.toString(), result["stage"] in setOf("saved", "saved_partial"))
            val name = result["file_name"] as String
            context.contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.IS_PENDING, MediaStore.MediaColumns.RELATIVE_PATH),
                "${MediaStore.MediaColumns.DISPLAY_NAME}=?", arrayOf(name), null)!!.use {
                assertEquals(1, it.count); assertTrue(it.moveToFirst()); assertEquals(0, it.getInt(1)); assertEquals("Download/", it.getString(2))
                publicUri = android.content.ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, it.getLong(0))
            }
            val entries = linkedMapOf<String, ByteArray>()
            ZipInputStream(context.contentResolver.openInputStream(publicUri!!)!!).use { zip ->
                while (true) { val entry = zip.nextEntry ?: break; entries[entry.name] = zip.readBytes(); zip.closeEntry() }
            }
            val manifest = JSONObject(String(entries["manifest.json"]!!))
            assertEquals("settrace.diagnostics", manifest.getString("format"))
            val listed = manifest.getJSONArray("entries")
            for (index in 0 until listed.length()) {
                val entry = listed.getJSONObject(index)
                val bytes = entries[entry.getString("path")]!!
                assertEquals(entry.getLong("bytes"), bytes.size.toLong())
                assertEquals(entry.getString("sha256"), DiagnosticJson.sha256(bytes))
            }
            assertFalse(entries.values.joinToString("") { String(it) }.contains("\"session\":1"))
            val inspected = command(engine, "inspectExport")
            assertEquals(name, inspected["file_name"]); assertEquals(id, inspected["export_id"])
            command(engine, "clear")
            assertNotNull(context.contentResolver.openInputStream(publicUri!!)?.use { it.read() })
        } finally {
            publicUri?.let { context.contentResolver.delete(it, null, null) }
            engine.closeForTests(); root.deleteRecursively()
        }
    }
}
