package com.settrace.settrace

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.AlarmManager
import android.app.Application
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

object DiagnosticsRuntime {
    @Volatile private var runtime: DiagnosticEngine? = null
    fun get(context: Context): DiagnosticEngine = runtime ?: synchronized(this) {
        runtime ?: DiagnosticEngine(context.applicationContext).also { runtime = it }
    }
}

class SetTraceApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val engine = DiagnosticsRuntime.get(this)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        if (previous != null) Thread.setDefaultUncaughtExceptionHandler(DiagnosticCrashHandler(previous) { error ->
            engine.record("diagnostics.unhandled", "failed", "unknown", "unhandled", "fatal", frames = DiagnosticPrivacy.frames(error))
        })
    }
}

/** No filesystem access in the constructor or caller's record path. */
class DiagnosticEngine(private val context: Context, private val testingDirectory: File? = null) {
    private val worker = ScheduledThreadPoolExecutor(1).apply { removeOnCancelPolicy = true }
    private val exportWorker = Executors.newSingleThreadExecutor()
    private val ingress = AtomicInteger()
    private val commands = AtomicInteger()
    private val dropped = AtomicLong()
    private val buffer = DiagnosticBuffer()
    private val process = UUID.randomUUID().toString().replace("-", "")
    private val sequence = AtomicLong()
    private val dartLosses = linkedMapOf<String, Long>()
    private var scheduled = false
    private var clearedInProcess = false
    private var bufferLosses = 0L
    private var store: DiagnosticStore? = null
    private var exporter: DiagnosticExportCoordinator? = null
    @Volatile private var confirmed: DiagnosticOverview? = null
    @Volatile private var exitCapability = if (Build.VERSION.SDK_INT >= 30) "supported" else "unsupported"
    @Volatile private var exitTrace = "not_available"

    init {
        worker.execute {
            try {
                val clock = object : DiagnosticClock {
                    override val boot: String = try { "boot:" + Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT) } catch (_: Exception) { "process:$process" }
                    override fun wallMillis() = System.currentTimeMillis()
                    override fun monotonicMillis() = SystemClock.elapsedRealtime()
                }
                val root = testingDirectory ?: File(context.noBackupFilesDir, "diagnostics")
                val value = DiagnosticStore(root, clock, ::decodeObject)
                store = value
                registerBuild(value, process)
                // Private staging is disposable after process loss; only the
                // bounded journal is needed to inspect the existing public file.
                for (file in value.stagingDirectory.listFiles().orEmpty()) if (file.isFile && !file.delete() && file.exists()) value.loss("write_failed")
                exporter = DiagnosticExportCoordinator(value, AndroidDiagnosticDownloads(context), exportWorker, environment = ::environment, observer = { result ->
                    val saved = result.stage in setOf(DiagnosticExportStage.saved, DiagnosticExportStage.saved_partial)
                    record("diagnostics.export", if (saved) "completed" else if (result.stage == DiagnosticExportStage.cancelled) "cancelled" else if (result.stage.terminal) "failed" else "preparing",
                        if (saved) { if (result.stage == DiagnosticExportStage.saved_partial) "partial_success" else "committed" } else if (result.stage == DiagnosticExportStage.cancelled) "cancelled" else "unknown",
                        result.reason?.takeIf { it in DiagnosticVocabulary.reasons } ?: "none", if (result.stage == DiagnosticExportStage.failed) "error" else "info",
                        operationId = result.id)
                })
                confirmed = value.overview()
                nativeEnvelope("startup.begin", "started", "observed", "none", "info", emptyMap(), emptyMap(), null, null, emptyList(), null, false)?.let { buffer.offer(it) }
                collectExitInformation(value)
                scheduleDrain()
            } catch (_: Exception) { /* query reports unavailable, business starts independently */ }
        }
    }

    @Suppress("DEPRECATION")
    private fun registerBuild(value: DiagnosticStore, identity: String) {
        try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            value.registerBuild(identity, info.versionName, if (Build.VERSION.SDK_INT >= 28) info.longVersionCode.toString() else info.versionCode.toString())
        } catch (_: Exception) { value.loss("not_available") }
    }

    fun record(name: String, phase: String, outcome: String = "observed", reason: String = "none", severity: String = "info",
               objects: Map<String, Long> = emptyMap(), attributes: Map<String, Any?> = emptyMap(), epoch: Long? = null,
               operationId: String? = null, frames: List<String> = emptyList(), time: Long? = null, unknownClock: Boolean = false) {
        if (confirmed?.enabled == false) return
        // Immutable small copies prevent caller mutations after admission.
        if (objects.size > 6 || attributes.size > 24 || attributes.any { (key, value) -> key.length > 64 || value is String && value.length > 96 || value !is String && value !is Number && value !is Boolean && value != null } || frames.size > 96 || frames.any { it.length > 2048 }) { dropped.incrementAndGet(); return }
        val copiedObjects = objects.toMap(); val copiedAttributes = attributes.toMap(); val copiedFrames = frames.toList()
        val cost = (copiedFrames.sumOf { it.length } + copiedObjects.size * 100 + copiedAttributes.size * 80 + 2048) * 4
        if (!reserve(cost)) return
        val admittedGeneration = confirmed?.generation
        worker.execute {
            try {
                val value = store ?: return@execute
                if (admittedGeneration != null && admittedGeneration != value.generation || admittedGeneration == null && clearedInProcess) return@execute
                nativeEnvelope(name, phase, outcome, reason, severity, copiedObjects, copiedAttributes, epoch, operationId, copiedFrames, time, unknownClock)?.let { buffer.offer(it) }
                scheduleDrain()
            } catch (_: Exception) { dropped.incrementAndGet() }
            finally { ingress.addAndGet(-cost) }
        }
    }

    private fun nativeEnvelope(name: String, phase: String, outcome: String, reason: String, severity: String,
                               objects: Map<String, Long>, attributes: Map<String, Any?>, epoch: Long?, operation: String?, frames: List<String>, time: Long?, unknownClock: Boolean): DiagnosticRecord? {
        val value = store ?: return null
        registerBuild(value, process)
        if (!value.enabled) return null
        return value.privacy.sanitize(mapOf(
            "schema_version" to 2, "event_name" to name, "phase" to phase, "outcome" to outcome, "severity" to severity,
            "reason_code" to reason, "operation_id" to (operation ?: UUID.randomUUID().toString().replace("-", "")), "process_instance" to process,
            "sequence" to sequence.incrementAndGet(), "monotonic_us" to if (unknownClock) null else SystemClock.elapsedRealtimeNanos() / 1000,
            "clock_domain" to if (unknownClock) "unknown" else "android", "time_utc" to (time ?: System.currentTimeMillis()),
            "timezone_offset_minutes" to TimeZone.getDefault().getOffset(time ?: System.currentTimeMillis()) / 60000,
            "dataset_epoch" to epoch, "generation" to value.generation, "attributes" to attributes, "objects" to objects, "frames" to frames
        ), value.generation, System.currentTimeMillis())
    }

    private fun reserve(cost: Int): Boolean {
        if (cost > 128 * 1024) { dropped.incrementAndGet(); return false }
        while (true) {
            val current = ingress.get()
            if (current + cost > 128 * 1024) { dropped.incrementAndGet(); return false }
            if (ingress.compareAndSet(current, current + cost)) return true
        }
    }

    fun submit(method: String, arguments: Map<*, *>, callback: (Map<String, Any?>) -> Unit) {
        val records = if (method == "recordBatch") arguments["records"] as? List<*> else null
        if (method == "recordBatch" && (records == null || records.size > 128 || records.any { it !is String || it.length > 40 * 1024 })) { callback(mapOf("error" to "size_limit")); return }
        val cost = records?.sumOf { (it as String).length * 2 + 128 } ?: 0
        if (cost > 0 && !reserve(cost)) { callback(mapOf("error" to "busy")); return }
        if (commands.incrementAndGet() > 16) { commands.decrementAndGet(); if (cost > 0) ingress.addAndGet(-cost); callback(mapOf("error" to "busy")); return }
        worker.execute {
            try {
                val value = store ?: throw DiagnosticFailure("storage_unavailable")
                val output = when (method) {
                    "recordBatch" -> {
                        recordDartLoss(arguments, value)
                        (arguments["process_instance"] as? String)?.let { registerBuild(value, it) }
                        if (value.enabled) for (text in records.orEmpty()) {
                            try {
                                val raw = decodeObject(text as String).toMutableMap()
                                // A pre-policy startup record is admissible only
                                // before any clear in this process. Never retag
                                // an old generation after clear.
                                if (raw["generation"] == null && !clearedInProcess) raw["generation"] = value.generation
                                val record = value.privacy.sanitize(raw, value.generation, System.currentTimeMillis())
                                if (record == null) value.loss("sanitization_rejected") else buffer.offer(record)
                            } catch (_: Exception) { value.loss("sanitization_rejected") }
                        }
                        scheduleDrain(); mapOf("accepted" to true)
                    }
                    "overview" -> { drain(); value.overview().also { confirmed = it }.toWire() }
                    "setEnabled" -> { val enabled = arguments["enabled"] as? Boolean ?: throw DiagnosticFailure("validation"); val result = value.setEnabled(enabled); if (!enabled) buffer.clear(); confirmed = result; if (enabled) record("diagnostics.policy", "completed", attributes = mapOf("enabled" to true)); result.toWire() }
                    "setDetailed" -> { val result = value.setDetailed(arguments["enabled"] as? Boolean ?: throw DiagnosticFailure("validation")); confirmed = result; record("diagnostics.policy", "completed", attributes = buildMap { put("enabled", value.enabled); put("count", if (result.detailedUntil != null) 1 else 0); result.detailedUntil?.let { put("due_utc", it) } }); result.toWire() }
                    "clear" -> {
                        if (exporter?.busy() == true) throw DiagnosticFailure("busy")
                        val previousGeneration = value.generation
                        try { value.clear().also { confirmed = it; record("diagnostics.clear", "completed", "committed") }.toWire() } finally {
                            if (value.generation != previousGeneration) { buffer.clear(); bufferLosses = buffer.dropped; dropped.set(0); dartLosses.clear(); clearedInProcess = true }
                            confirmed = value.overview()
                        }
                    }
                    "startExport" -> {
                        val target = exporter ?: throw DiagnosticFailure("storage_unavailable")
                        if (target.busy() || target.needsInspection()) target.current()!!.toWire()
                        else { drain(); recordDartLoss(arguments, value); target.start(value.beginSnapshot(), arguments["state"] as? Map<*, *>).toWire() }
                    }
                    "exportStatus" -> { val result = exporter?.current() ?: throw DiagnosticFailure("missing"); if (arguments["export_id"] != result.id) throw DiagnosticFailure("not_found"); result.toWire() }
                    "cancelExport" -> (exporter ?: throw DiagnosticFailure("missing")).cancel(arguments["export_id"] as? String ?: throw DiagnosticFailure("validation")).toWire()
                    "inspectExport" -> (exporter ?: throw DiagnosticFailure("missing")).inspect().toWire()
                    else -> throw DiagnosticFailure("unsupported")
                }
                callback(output)
            } catch (error: Exception) {
                callback(mapOf("error" to when (error) { is DiagnosticFailure -> error.code; is SecurityException -> "permission_denied"; else -> "storage_unavailable" }))
            } finally { commands.decrementAndGet(); if (cost > 0) ingress.addAndGet(-cost) }
        }
    }

    private fun recordDartLoss(arguments: Map<*, *>, value: DiagnosticStore) {
        if (!value.enabled || arguments["generation"] != value.generation && (arguments["generation"] != null || clearedInProcess)) return
        val identity = arguments["process_instance"] as? String ?: return
        val count = DiagnosticVocabulary.number(arguments["dart_dropped"]) ?: return
        if (!DiagnosticVocabulary.token.matches(identity)) return
        val prior = dartLosses[identity] ?: 0
        if (count > prior) value.loss("queue_overflow", count - prior)
        dartLosses[identity] = maxOf(prior, count)
        while (dartLosses.size > 8) dartLosses.remove(dartLosses.keys.first())
    }
    internal fun closeForTests() {
        worker.submit { drain() }.get(5, TimeUnit.SECONDS)
        worker.shutdownNow(); exportWorker.shutdownNow()
    }

    private fun scheduleDrain() {
        if (scheduled) return
        scheduled = true
        worker.schedule({ scheduled = false; drain() }, 1, TimeUnit.SECONDS)
    }

    private fun drain() {
        val value = store ?: return
        val lost = dropped.getAndSet(0)
        val bufferDropped = buffer.dropped
        if (value.enabled && lost + bufferDropped - bufferLosses > 0) {
            val count = lost + bufferDropped - bufferLosses
            value.loss("queue_overflow", count)
            // A direct, once-per-drain observation avoids recursive loss
            // logging when the admission queue itself is full.
            nativeEnvelope("diagnostics.loss", "completed", "observed", "queue_overflow", "warn", emptyMap(), mapOf("count" to count), null, null, emptyList(), null, false)?.let { value.append(it) }
        }
        bufferLosses = bufferDropped
        while (true) { val record = buffer.take() ?: break; value.append(record) }
        value.flush(); confirmed = value.overview()
    }

    @Suppress("DEPRECATION")
    private fun environment(): Map<String, Any?> {
        val info = try { context.packageManager.getPackageInfo(context.packageName, 0) } catch (_: Exception) { null }
        val safe = Regex("[a-zA-Z0-9 ._+()/-]{1,96}")
        return mapOf(
            "application" to mapOf("package" to context.packageName, "version" to info?.versionName?.takeIf { safe.matches(it) }, "build" to info?.let { if (Build.VERSION.SDK_INT >= 28) it.longVersionCode.toString() else it.versionCode.toString() }, "supported_database_schema" to 6),
            "android_api" to Build.VERSION.SDK_INT, "android_version" to Build.VERSION.RELEASE.takeIf { safe.matches(it) }, "device_model" to Build.MODEL.takeIf { safe.matches(it) },
            "captured_utc" to System.currentTimeMillis(), "notifications_allowed" to (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled(),
            "exact_allowed" to if (Build.VERSION.SDK_INT >= 31) (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).canScheduleExactAlarms() else true,
            "exit_information" to exitCapability, "exit_trace" to exitTrace
        )
    }

    @android.annotation.TargetApi(30)
    private fun collectExitInformation(value: DiagnosticStore) {
        if (Build.VERSION.SDK_INT < 30 || !value.enabled) {
            exitCapability = if (Build.VERSION.SDK_INT < 30) "unsupported" else "not_available"
            return
        }
        val exitWorker = Executors.newSingleThreadExecutor { task -> Thread(task, "settrace-exit-info").apply { isDaemon = true } }
        val task = exitWorker.submit<DiagnosticExitCollection> {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            DiagnosticExitPolicy.read(Build.VERSION.SDK_INT, value.enabled) {
                manager.getHistoricalProcessExitReasons(context.packageName, 0, 5).map { info ->
                    DiagnosticExitCandidate(info.timestamp, info.reason, info.pid) { info.traceInputStream }
                }
            }
        }
        try {
            val collection = task.get(250, TimeUnit.MILLISECONDS)
            exitCapability = collection.capability; exitTrace = collection.traceStatus
            for (exit in collection.exits) if (value.consumeExit(exit.marker, exit.time)) {
                nativeEnvelope("startup.exit", "completed", "observed", exit.reason, DiagnosticExitPolicy.severity(exit.reason), emptyMap(), mapOf("subject_build_unknown" to true), null, null, exit.frames, exit.time, true)?.let { buffer.offer(it) }
            }
        } catch (_: Exception) { exitCapability = "read_failed"; exitTrace = "read_failed"; task.cancel(true) }
        finally { exitWorker.shutdownNow() }
    }

    fun shutdownForTest() { worker.shutdown(); worker.awaitTermination(5, TimeUnit.SECONDS); exportWorker.shutdown(); exportWorker.awaitTermination(5, TimeUnit.SECONDS) }

    companion object {
        fun decodeObject(text: String): Map<*, *> {
            if (text.length > 48 * 1024 || text.count { it == '{' } > 12 || text.count { it == '[' } > 8) throw DiagnosticFailure("size_limit")
            fun convert(value: Any?, depth: Int): Any? {
                if (depth > 4) throw DiagnosticFailure("size_limit")
                return when (value) {
                    JSONObject.NULL, null -> null
                    is JSONObject -> { if (value.length() > 40) throw DiagnosticFailure("size_limit"); value.keys().asSequence().associateWith { key -> convert(value.get(key), depth + 1) } }
                    is JSONArray -> { if (value.length() > 96) throw DiagnosticFailure("size_limit"); (0 until value.length()).map { convert(value.get(it), depth + 1) } }
                    is String, is Boolean, is Int, is Long -> value
                    else -> throw DiagnosticFailure("sanitization_rejected")
                }
            }
            return convert(JSONObject(text), 0) as Map<*, *>
        }
    }
}

class DiagnosticsBridge(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "settrace/diagnostics")
    private val engine = DiagnosticsRuntime.get(activity)
    private val main = Handler(Looper.getMainLooper())
    private var permission: MethodChannel.Result? = null
    private var disposed = false
    init { channel.setMethodCallHandler(this) }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) { result.success(mapOf("error" to "cancelled")); return }
        if (call.method == "requestExportPermission") {
            if (Build.VERSION.SDK_INT <= 28 && activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                if (permission != null) { result.success(mapOf("error" to "busy")); return }
                permission = result
                activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), PERMISSION)
            } else result.success(emptyMap<String, Any>())
            return
        }
        if (call.method == "openAppSettings") {
            try { activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", activity.packageName, null))); result.success(emptyMap<String, Any>()) }
            catch (_: Exception) { result.success(mapOf("error" to "platform")) }
            return
        }
        engine.submit(call.method, call.arguments as? Map<*, *> ?: emptyMap<String, Any>()) { output -> main.post { if (!disposed) result.success(output) } }
    }
    fun onPermissionResult(code: Int, grants: IntArray): Boolean {
        if (code != PERMISSION) return false
        val result = permission ?: return true
        permission = null
        if (grants.firstOrNull() == PackageManager.PERMISSION_GRANTED) result.success(emptyMap<String, Any>())
        else result.success(mapOf("error" to if (!activity.shouldShowRequestPermissionRationale(Manifest.permission.WRITE_EXTERNAL_STORAGE)) "permission_permanent" else "permission_denied"))
        return true
    }
    fun dispose() { disposed = true; permission?.success(mapOf("error" to "cancelled")); permission = null; channel.setMethodCallHandler(null) }
    companion object { private const val PERMISSION = 48872 }
}
