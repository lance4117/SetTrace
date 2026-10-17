package com.settrace.settrace

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import org.junit.Assert.*
import org.junit.Test

class BackupFilesStorageTest {
    private class SizedInput(private var remaining: Long) : InputStream() {
        override fun read(): Int = if (remaining-- > 0) 0 else -1
        override fun read(b: ByteArray, off: Int, len: Int): Int {
            if (remaining == 0L) return -1
            val count = minOf(remaining, len.toLong()).toInt()
            b.fill(0, off, off + count); remaining -= count; return count
        }
    }
    @Test fun copyPreservesBytesAndFlushes() {
        val bytes = "训练 backup".toByteArray(Charsets.UTF_8)
        val out = ByteArrayOutputStream()
        assertEquals(bytes.size.toLong(), copyBackupBounded(ByteArrayInputStream(bytes), out))
        assertArrayEquals(bytes, out.toByteArray())
    }
    @Test fun sizeLimitIsInclusiveWithoutTrustingReportedSize() {
        val sink = object : OutputStream() {
            override fun write(b: Int) {}
            override fun write(b: ByteArray, off: Int, len: Int) {}
        }
        assertEquals(BACKUP_MAX_BYTES, copyBackupBounded(SizedInput(BACKUP_MAX_BYTES), sink))
        try { copyBackupBounded(SizedInput(BACKUP_MAX_BYTES + 1), sink); fail("must reject") }
        catch (e: BackupFileFailure) { assertEquals("tooLarge", e.code) }
    }
    @Test fun digestUsesSha256AndEnforcesLimit() {
        assertEquals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", backupFileDigest(ByteArrayInputStream("abc".toByteArray())))
        try { backupFileDigest(SizedInput(BACKUP_MAX_BYTES + 1)); fail("must reject") }
        catch (e: BackupFileFailure) { assertEquals("tooLarge", e.code) }
    }
    @Test fun readWriteAndFlushFailuresPropagate() {
        for (phase in listOf("read", "write", "flush")) {
            val input = object : ByteArrayInputStream(byteArrayOf(1)) {
                override fun read(b: ByteArray, off: Int, len: Int): Int {
                    if (phase == "read") throw IllegalStateException(phase)
                    return super.read(b, off, len)
                }
            }
            val out = object : OutputStream() {
                override fun write(b: Int) { if (phase == "write") throw IllegalStateException(phase) }
                override fun flush() { if (phase == "flush") throw IllegalStateException(phase) }
            }
            try { copyBackupBounded(input,out); fail("must fail $phase") }
            catch (e: IllegalStateException) { assertEquals(phase,e.message) }
        }
    }
}
