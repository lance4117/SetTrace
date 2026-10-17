package com.settrace.settrace

/** Both file formats share one Android document-picker slot. */
internal object FilePickerGate {
    private var owner: Any? = null
    @Synchronized fun acquire(request: Any): Boolean {
        if (owner != null) return false
        owner = request
        return true
    }
    @Synchronized fun release(request: Any) { if (owner === request) owner = null }
}
