package com.settrace.settrace

import org.junit.Assert.*
import org.junit.Test

class RestSoundTest {
    @Test fun unknownMigrationCannotUnmuteAutomaticallyButExplicitPlatformChoiceCanReleaseIt() {
        assertFalse(RestChannelPolicy.explicitUnknownRelease(29,true,false,false))
        assertFalse(RestChannelPolicy.explicitUnknownRelease(36,false,true,true))
        assertTrue(RestChannelPolicy.explicitUnknownRelease(29,true,false,true))
        assertTrue(RestChannelPolicy.explicitUnknownRelease(36,true,true,false))
    }
    private class Handle : RestSoundHandle {
        lateinit var ready: () -> Unit; lateinit var done: () -> Unit; lateinit var error: () -> Unit
        var starts = 0; var releases = 0; var throwStart = false
        override fun prepare(ready: () -> Unit, completed: () -> Unit, failed: () -> Unit) { this.ready = ready; done = completed; error = failed }
        override fun start() { if (throwStart) throw IllegalStateException("private URI"); starts++ }
        override fun release() { releases++ }
    }
    @Test fun policyReportsSuppressionAndUnknownWithoutFailure() {
        val normal = RestSoundReadings(2,5,1,true,3)
        assertEquals("allowed",normal.condition)
        assertEquals("silent",normal.copy(ringer = 1).condition)
        assertEquals("zero_volume",normal.copy(volume = 0).condition)
        assertEquals("dnd",normal.copy(interruption = 2).condition)
        assertEquals("channel_silent",normal.copy(hasSound = false).condition)
        assertEquals("channel_quiet",normal.copy(importance = 2).condition)
        assertEquals("unknown",normal.copy(volume = null).condition)
        assertEquals("unknown",normal.copy(interruption = 0).condition)
        assertEquals("unknown",normal.copy(importance = -1000).condition)
    }
    @Test fun creationFailureIsObservedAndCannotClaimAgain() {
        val states = mutableListOf<String>()
        val player = RestSingleSound({ null }, { _, _ -> })
        assertFalse(player.play(false, { state, _ -> states.add(state) }))
        assertEquals(listOf("requested","failed"),states)
        assertFalse(player.active)
    }
    @Test fun staleCallbacksAndTimeoutDoNotReleaseNewPlaybackAndPreviewCannotInterruptReal() {
        val first = Handle(); val second = Handle(); val queue = ArrayDeque(listOf(first,second))
        val timers = mutableListOf<() -> Unit>(); val states = mutableListOf<String>()
        val player = RestSingleSound({ queue.removeFirst() }, { _, action -> timers.add(action) })
        player.play(false, { state, _ -> states.add(state) }); first.ready()
        assertFalse(player.play(true, { _, _ -> fail() }))
        player.play(false, { state, _ -> states.add(state) }); second.ready()
        first.done(); first.error(); timers.first()()
        assertEquals(0,second.releases); assertEquals(1,first.releases)
        timers.last()(); second.done()
        assertEquals(1,second.releases); assertFalse(player.active)
        assertEquals(listOf("requested","started","stopped","requested","started","stopped"),states)
    }
    @Test fun asyncErrorAndStartFailureAreTerminalAndReleaseOnce() {
        for (startFailure in listOf(false,true)) {
            val handle = Handle().apply { throwStart = startFailure }
            val states = mutableListOf<String>(); val player = RestSingleSound({ handle }, { _, _ -> })
            player.play(false,{ state, _ -> states.add(state) }); handle.ready(); handle.error(); handle.done()
            assertEquals("failed",states.last()); assertEquals(1,handle.releases)
        }
    }
    @Test fun restrictionsCanOnlyBecomeStricterAndNeverRequireThirdChannel() {
        val normal = RestChannelPolicy()
        for (restricted in listOf(RestChannelPolicy(0),RestChannelPolicy(muted = true),RestChannelPolicy(userNoVibration = true))) {
            assertEquals(restricted,normal.inherit(restricted))
            assertFalse(restricted.permits(normal)); assertTrue(restricted.permits(restricted))
        }
    }
}
