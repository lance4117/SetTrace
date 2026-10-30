package com.settrace.settrace

import org.junit.Assert.*
import org.junit.Test

class TrainingReminderPolicyTest {
    @Test fun leaseIncludesSleepAndDoesNotUseWallClockOrPassiveCallbacks() {
        val lease = TrainingReminderLease(1, 3, 100)
        assertFalse(lease.expired(lease.expiresElapsed - 1))
        assertTrue(lease.expired(lease.expiresElapsed))
        assertTrue(lease.expired(lease.expiresElapsed + 60_000))
        assertTrue(lease.expired(99))
        assertEquals(4 * 60 * 60 * 1000L, lease.expiresElapsed - lease.startedElapsed)
    }
    @Test fun restCleanupNeverOwnsTheServiceOrTaggedNotifications() {
        assertTrue(RestNotificationOwnership.isRest(null, 7, true))
        assertFalse(RestNotificationOwnership.isRest(null, 7))
        assertFalse(RestNotificationOwnership.isRest(null, TrainingReminderService.NOTIFICATION_ID))
        assertFalse(RestNotificationOwnership.isRest("another.module", 7))
    }
}
