package com.settrace.settrace

/** Recording is best effort and must always preserve the original terminator. */
class DiagnosticCrashHandler(private val previous: Thread.UncaughtExceptionHandler, private val observe: (Throwable) -> Unit) : Thread.UncaughtExceptionHandler {
    override fun uncaughtException(thread: Thread, error: Throwable) {
        try { observe(error) } catch (_: Throwable) { }
        finally { previous.uncaughtException(thread, error) }
    }
}
