package com.settrace.settrace

/** Debug-only visible host for native service lifecycle tests, without Flutter
 * initialization or writes to the user's workout database. */
class ReminderQaActivity : android.app.Activity() {
    override fun onResume() { super.onResume(); RestAlertsRuntime.foreground = true }
    override fun onPause() { RestAlertsRuntime.foreground = false; super.onPause() }
}
