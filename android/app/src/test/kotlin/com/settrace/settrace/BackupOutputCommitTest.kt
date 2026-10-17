package com.settrace.settrace
import org.junit.Assert.*
import org.junit.Test
class BackupOutputCommitTest {
    @Test fun publishesOnlyClosedRereadOutputAfterVerifiedMarker() {
        val events=mutableListOf<String>()
        commitBackupOutput({events.add("write-close")},{events.add("reread");true},
            {events.add("verified")},{events.add("publish")},{events.add("published")},{events.add("cleanup")})
        assertEquals(listOf("write-close","reread","verified","publish","published"),events)
    }
    @Test fun readWriteSpaceCloseAndIntegrityFailuresNeverPublish() {
        for (phase in listOf("read","write","space","close","reread","integrity")) {
            var published=false;var cleaned=0
            try {
                commitBackupOutput(
                    {if(phase in listOf("read","write","space","close")) throw java.io.IOException(phase)},
                    {if(phase=="reread") throw java.io.IOException(phase);phase!="integrity"},
                    {},{published=true},{},{cleaned++})
                fail(phase)
            } catch (_: Exception) {}
            assertFalse(phase,published);assertEquals(phase,1,cleaned)
        }
    }
    @Test fun verifiedOutputSurvivesJournalAndPublicationFailures() {
        for (phase in listOf("verified-journal","publish","published-journal")) {
            var cleaned=false
            try {
                commitBackupOutput({}, {true},
                    {if(phase=="verified-journal") throw java.io.IOException(phase)},
                    {if(phase=="publish") throw java.io.IOException(phase)},
                    {if(phase=="published-journal") throw java.io.IOException(phase)}, {cleaned=true})
                fail(phase)
            } catch (_: java.io.IOException) {}
            assertFalse("retain verified target for $phase",cleaned)
        }
    }
    @Test fun cleanupFailurePreservesOriginalError() {
        try {
            commitBackupOutput({throw java.io.IOException("no-space")},{true},{},{},{},{throw java.io.IOException("cleanup-failed")})
            fail("must fail")
        } catch(e:java.io.IOException) {assertEquals("no-space",e.message)}
    }
}
