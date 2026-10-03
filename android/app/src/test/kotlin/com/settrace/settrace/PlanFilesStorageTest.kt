package com.settrace.settrace

import java.io.ByteArrayOutputStream
import java.io.OutputStream
import org.junit.Assert.*
import org.junit.Test

class PlanFilesStorageTest {
    private class Entry(private val fail: String? = null) : DownloadEntry {
        val events = mutableListOf<String>()
        val data = ByteArrayOutputStream()
        override val fileName: String = "actual-2.settrace.json"
        override fun open(): OutputStream {
            events.add("open")
            if (fail == "open") throw IllegalStateException("injected")
            return object : OutputStream() {
                override fun write(value: Int) { if (fail == "write") throw IllegalStateException("injected"); data.write(value) }
                override fun flush() { events.add("flush"); if (fail == "flush") throw IllegalStateException("injected") }
                override fun close() { events.add("close"); if (fail == "close") throw IllegalStateException("injected") }
            }
        }
        override fun publish() { events.add("publish"); if (fail == "publish") throw IllegalStateException("injected") }
        override fun discard() { events.add("discard") }
    }
    @Test fun successPublishesOnlyAfterCloseAndReturnsActualName() {
        val entry = Entry()
        val bytes = "训练计划完整内容".toByteArray(Charsets.UTF_8)
        assertEquals("actual-2.settrace.json", writeDownload(entry, bytes))
        assertArrayEquals(bytes, entry.data.toByteArray())
        assertEquals(listOf("open", "flush", "close", "publish"), entry.events)
    }
    @Test fun everyFailureDiscardsOnlyTheCreatedEntryAndNeverSucceeds() {
        for (phase in listOf("open", "write", "flush", "close", "publish")) {
            val entry = Entry(phase)
            try { writeDownload(entry, byteArrayOf(1, 2, 3)); fail("$phase must fail") }
            catch (_: IllegalStateException) { }
            assertEquals("discard", entry.events.last())
            assertEquals(1, entry.events.count { it == "discard" })
            if (phase != "publish") assertFalse(entry.events.contains("publish"))
        }
    }
}
