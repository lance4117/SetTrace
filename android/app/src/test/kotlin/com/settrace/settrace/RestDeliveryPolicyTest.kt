package com.settrace.settrace

import org.junit.Assert.*
import org.junit.Test

class RestDeliveryPolicyTest {
    @Test fun rejectionReasonsAreFiniteAndDoNotGuessUnobservedFacts() {
        assertEquals("not_found", RestClaimReason.rejected(RestClaimFacts(exists = false)))
        assertEquals("old_revision", RestClaimReason.rejected(RestClaimFacts(revisionMatches = false)))
        assertEquals("old_round", RestClaimReason.rejected(RestClaimFacts(roundMatches = false)))
        assertEquals("already_acknowledged", RestClaimReason.rejected(RestClaimFacts(acknowledged = true)))
        assertEquals("user_disabled", RestClaimReason.rejected(RestClaimFacts(enabled = false)))
        assertEquals("invalid_session", RestClaimReason.rejected(RestClaimFacts(sessionValid = false)))
        assertEquals("condition_mismatch", RestClaimReason.rejected(RestClaimFacts(positionMatches = false)))
        assertEquals("expired", RestClaimReason.rejected(RestClaimFacts(expired = true)))
        assertEquals("condition_mismatch", RestClaimReason.rejected(RestClaimFacts()))
    }
    @Test fun acceptsOnlyDueAndRecentCallbacks() {
        val due = 1_000_000L
        assertFalse(RestDeliveryPolicy.withinWindow(due - 1, due))
        assertTrue(RestDeliveryPolicy.withinWindow(due, due))
        assertTrue(RestDeliveryPolicy.withinWindow(due + 5_000, due))
        assertTrue(RestDeliveryPolicy.withinWindow(due + 30_000, due))
        assertFalse(RestDeliveryPolicy.withinWindow(due + 30_001, due))
    }
    @Test fun soundRespectsMutedDisabledAndSilentChannels() {
        assertTrue(RestDeliveryPolicy.soundAllowed(true, 5, true, true, 3))
        assertFalse(RestDeliveryPolicy.soundAllowed(false, 5, true, true, 3))
        assertFalse(RestDeliveryPolicy.soundAllowed(true, 0, true, true, 3))
        assertFalse(RestDeliveryPolicy.soundAllowed(true, 5, false, true, 3))
        assertFalse(RestDeliveryPolicy.soundAllowed(true, 5, true, false, 3))
        assertFalse(RestDeliveryPolicy.soundAllowed(true, 5, true, true, 0))
        assertFalse(RestDeliveryPolicy.soundAllowed(true, 5, true, true, 2))
    }
}
