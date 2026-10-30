package com.settrace.settrace

/** Process-local authority, never reconstructed from a saved 'running' flag. */
internal data class TrainingReminderLease(val session: Int, val epoch: Long,
    val startedElapsed: Long) {
    val expiresElapsed get() = startedElapsed + MAX_LEASE_MS
    fun expired(nowElapsed: Long) = nowElapsed >= expiresElapsed || nowElapsed < startedElapsed
    companion object { const val MAX_LEASE_MS = 4 * 60 * 60 * 1000L }
}

internal object RestNotificationOwnership {
    const val SERVICE_TAG = "settrace.training.reminder"
    const val SERVICE_ID = 10001
    fun isRest(tag: String?, id: Int, owned: Boolean = false) = tag == null && id > 0 && owned
}
