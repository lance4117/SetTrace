package com.settrace.settrace

/** Closed, injectable policy. Missing readings never imply permission to sound. */
internal data class RestSoundReadings(val ringer: Int?, val volume: Int?, val interruption: Int?,
    val hasSound: Boolean?, val importance: Int?) {
    val condition: String get() = when {
        ringer == null || volume == null || interruption == null || hasSound == null || importance == null -> "unknown"
        ringer !in 0..2 || volume < 0 || interruption !in 1..4 || importance !in 0..5 -> "unknown"
        ringer != 2 -> "silent"
        volume <= 0 -> "zero_volume"
        interruption != 1 -> "dnd"
        !hasSound -> "channel_silent"
        importance < 3 -> "channel_quiet"
        else -> "allowed"
    }
    fun fields(): Map<String, Any?> = buildMap {
        put("readings_available", condition != "unknown")
        ringer?.takeIf { it in 0..2 }?.let { put("ringer_mode", it) }; volume?.takeIf { it >= 0 }?.let { put("notification_volume", it) }
        interruption?.takeIf { it in 1..4 }?.let { put("interruption_filter", it) }; hasSound?.let { put("channel_has_sound", it) }
        importance?.takeIf { it in 0..5 }?.let { put("channel_importance", it) }; put("sound_condition", condition)
    }
}

internal interface RestSoundHandle {
    fun prepare(ready: () -> Unit, completed: () -> Unit, failed: () -> Unit)
    fun start()
    fun release()
}

/** One instance per runtime; callbacks retain their own session, never the current identity. */
internal class RestSingleSound(private val create: () -> RestSoundHandle?,
    private val timeout: (Long, () -> Unit) -> Unit) {
    private class Session(val handle: RestSoundHandle, val preview: Boolean,
        val observe: (String, String) -> Unit, val terminal: (String) -> Unit) { var ended = false }
    private var current: Session? = null
    val active get() = current != null
    val realActive get() = current?.preview == false
    fun stop(previewOnly: Boolean = false, condition: String = "allowed") {
        val session = current ?: return
        if (!previewOnly || session.preview) finish(session, "stopped", condition)
    }
    private fun finish(session: Session, state: String, condition: String) {
        if (session.ended) return
        session.ended = true
        if (current === session) current = null
        try { session.handle.release() } catch (_: Exception) {}
        session.observe(state, condition); session.terminal(state)
    }
    fun play(preview: Boolean, observe: (String, String) -> Unit, terminal: (String) -> Unit = {}): Boolean {
        if (preview && active) { terminal("busy"); return false }
        stop()
        observe("requested", "allowed")
        val handle = try { create() } catch (_: Exception) { null }
        if (handle == null) { observe("failed", "create_failed"); terminal("failed"); return false }
        val session = Session(handle, preview, observe, terminal)
        current = session
        timeout(10_000) { if (current === session) finish(session, "stopped", "bounded_stop") }
        try {
            handle.prepare({
                if (current === session && !session.ended) {
                    try { handle.start(); observe("started", "allowed") }
                    catch (_: Exception) { finish(session, "failed", "playback_failed") }
                }
            }, { finish(session, "completed", "allowed") }, { finish(session, "failed", "playback_failed") })
        } catch (_: Exception) { finish(session, "failed", "playback_failed") }
        return !session.ended
    }
}

internal data class RestChannelPolicy(val importance: Int = 3, val muted: Boolean = false,
    val userNoVibration: Boolean = false) {
    companion object {
        fun explicitUnknownRelease(api: Int, hasSound: Boolean, userSetSound: Boolean, mutedObserved: Boolean) =
            hasSound && (mutedObserved || api >= 30 && userSetSound)
    }
    fun inherit(other: RestChannelPolicy) = RestChannelPolicy(minOf(importance, other.importance),
        muted || other.muted, userNoVibration || other.userNoVibration)
    fun permits(target: RestChannelPolicy) = target.importance <= importance && (!muted || target.muted) &&
        (!userNoVibration || target.userNoVibration)
}
