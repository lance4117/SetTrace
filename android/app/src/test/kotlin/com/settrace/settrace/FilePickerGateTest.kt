package com.settrace.settrace
import org.junit.Assert.*
import org.junit.Test
class FilePickerGateTest {
    @Test fun formatsAndDuplicateRequestsShareOneSlotAndOnlyOwnerCanRelease() {
        val backup=Any();val plan=Any()
        try {
            assertTrue(FilePickerGate.acquire(backup))
            assertFalse(FilePickerGate.acquire(backup))
            assertFalse(FilePickerGate.acquire(plan))
            FilePickerGate.release(plan)
            assertFalse(FilePickerGate.acquire(plan))
            FilePickerGate.release(backup)
            assertTrue(FilePickerGate.acquire(plan))
            assertFalse(FilePickerGate.acquire(backup))
        } finally {FilePickerGate.release(backup);FilePickerGate.release(plan)}
    }
}
