package com.settrace.settrace

import org.junit.Assert.*
import org.junit.Test

class BackupDatabasePolicyTest {
    @Test fun acceptsOnlyExplicitlySupportedVersions() {
        for (version in 0..7) assertEquals(version == 4 || version == 5 || version == 6, BackupDatabasePolicy.supported(version))
    }
    @Test fun refusesUnsettledCoreOperationsButAllowsNormalReminderPolicy() {
        for (kind in listOf("restore", "undo")) {
            for (phase in listOf("preparing", "protected", "indeterminate")) {
                assertTrue(BackupDatabasePolicy.blocksOutput(kind, phase))
            }
            for (phase in listOf("core_committed", "settings_pending", "completed", "aborted")) {
                assertFalse(BackupDatabasePolicy.blocksOutput(kind, phase))
            }
        }
        assertFalse(BackupDatabasePolicy.blocksOutput("export", "preparing"))
        assertTrue(RestDeliveryPolicy.withinWindow(1000, 1000))
    }
}
