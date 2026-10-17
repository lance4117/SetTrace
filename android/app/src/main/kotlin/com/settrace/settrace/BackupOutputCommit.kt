package com.settrace.settrace

/** Publish only closed, reread output. Keep verified files on uncertain results. */
internal fun commitBackupOutput(
    writeAndClose: () -> Unit,
    verify: () -> Boolean,
    markVerified: () -> Unit,
    publish: () -> Unit,
    markPublished: () -> Unit,
    discardIncomplete: () -> Unit,
) {
    var verified = false
    try {
        writeAndClose()
        if (!verify()) throw BackupFileFailure("verifyFailed")
        verified = true
        markVerified()
        publish()
        markPublished()
    } catch (error: Exception) {
        if (!verified) {
            try { discardIncomplete() } catch (_: Exception) { /* durable reservation permits cleanup retry */ }
        }
        throw error
    }
}
