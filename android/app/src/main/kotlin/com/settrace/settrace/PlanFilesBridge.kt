package com.settrace.settrace

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import java.nio.charset.CodingErrorAction
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal interface DownloadEntry {
    val fileName: String
    fun open(): OutputStream
    fun publish()
    fun discard()
}

// Kept separate so write/close/publication failure behavior can be tested.
internal fun writeDownload(entry: DownloadEntry, bytes: ByteArray): String {
    try {
        entry.open().use { it.write(bytes); it.flush() }
        entry.publish()
        return entry.fileName
    } catch (error: Exception) {
        try { entry.discard() } catch (_: Exception) { }
        throw error
    }
}

class PlanFilesBridge(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    companion object {
        const val MAX_BYTES = 2 * 1024 * 1024
        private const val PICK = 47101
        private const val PERMISSION = 47102
    }
    private class Request(val result: MethodChannel.Result, val kind: String, val bytes: ByteArray? = null) {
        val completed = AtomicBoolean(false)
    }
    private val channel = MethodChannel(messenger, "settrace/plan_transfer")
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private var pending: Request? = null
    private var disposed = false
    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) { result.success(mapOf("status" to "cancelled")); return }
        if (pending != null) { result.success(mapOf("status" to "error", "code" to "fileBusy")); return }
        when (call.method) {
            "saveFile" -> {
                val text = call.argument<String>("text")
                if (text == null || text.isBlank()) { result.success(error("emptyContent")); return }
                val bytes = text.toByteArray(Charsets.UTF_8)
                if (bytes.size > MAX_BYTES) { result.success(error("fileTooLarge")); return }
                val request = Request(result, "save", bytes)
                pending = request
                if (Build.VERSION.SDK_INT <= 28 && activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), PERMISSION)
                } else save(request)
            }
            "pickFile" -> {
                val request = Request(result, "pick")
                pending = request
                try {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    activity.startActivityForResult(intent, PICK)
                } catch (_: Exception) { finish(request, error("filePickerFailed")) }
            }
            else -> result.notImplemented()
        }
    }
    fun onPermissionResult(code: Int, grants: IntArray): Boolean {
        if (code != PERMISSION) return false
        val request = pending?.takeIf { it.kind == "save" } ?: return true
        if (grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED) save(request)
        else finish(request, error("permissionDenied"))
        return true
    }
    fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != PICK) return false
        val request = pending?.takeIf { it.kind == "pick" } ?: return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { finish(request, mapOf("status" to "cancelled")); return true }
        io.execute {
            try {
                val size = activity.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
                }
                if (size != null && size > MAX_BYTES) throw FileFailure("fileTooLarge")
                val bytes = activity.contentResolver.openInputStream(uri)?.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    var count: Int
                    while (input.read(buffer).also { count = it } != -1) {
                        if (Thread.currentThread().isInterrupted) throw IllegalStateException("cancelled")
                        if (output.size() + count > MAX_BYTES) throw FileFailure("fileTooLarge")
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                } ?: throw IllegalStateException("fileReadFailed")
                if (bytes.isEmpty()) throw FileFailure("fileEmpty")
                val text = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString()
                finish(request, mapOf("status" to "success", "text" to text))
            } catch (e: FileFailure) { finish(request, error(e.code)) }
            catch (_: Exception) { finish(request, error("fileReadFailed")) }
        }
        return true
    }
    private fun save(request: Request) {
        io.execute {
            try {
                val stamp = SimpleDateFormat("yyyy-MM-dd-HHmmss-SSS", Locale.ROOT).format(Date())
                val name = "SetTrace-plans-$stamp.settrace.json"
                val entry = if (Build.VERSION.SDK_INT >= 29) mediaEntry(name) else legacyEntry(name)
                val actual = writeDownload(entry, request.bytes!!)
                finish(request, mapOf("status" to "success", "fileName" to actual, "location" to "downloads"))
            } catch (_: Exception) { finish(request, error("fileSaveFailed")) }
        }
    }
    private fun mediaEntry(proposed: String): DownloadEntry {
        val resolver = activity.contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val used = mutableSetOf<String>()
        resolver.query(collection, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), "${MediaStore.MediaColumns.RELATIVE_PATH} = ?", arrayOf("${Environment.DIRECTORY_DOWNLOADS}/"), null)?.use { cursor ->
            while (cursor.moveToNext()) used.add(cursor.getString(0))
        }
        val name = uniqueName(proposed) { used.contains(it) }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, values) ?: throw IllegalStateException("Downloads unavailable")
        return object : DownloadEntry {
            override val fileName: String get() = resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) it.getString(0) else name } ?: name
            override fun open(): OutputStream = resolver.openOutputStream(uri, "w") ?: throw IllegalStateException("Cannot open download")
            override fun publish() {
                if (Thread.currentThread().isInterrupted) throw IllegalStateException("Cancelled")
                if (resolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null) != 1) throw IllegalStateException("Cannot publish")
            }
            override fun discard() { resolver.delete(uri, null, null) }
        }
    }
    @Suppress("DEPRECATION")
    private fun legacyEntry(proposed: String): DownloadEntry {
        if (Environment.getExternalStorageState() != Environment.MEDIA_MOUNTED) throw IllegalStateException("Downloads unavailable")
        val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!dir.exists() && !dir.mkdirs()) throw IllegalStateException("Cannot create Downloads")
        val temporary = File.createTempFile(".settrace-", ".partial", dir)
        return object : DownloadEntry {
            private var target: File? = null
            override val fileName: String get() = target?.name ?: throw IllegalStateException("Not published")
            override fun open(): OutputStream = FileOutputStream(temporary)
            override fun publish() {
                if (Thread.currentThread().isInterrupted) throw IllegalStateException("Cancelled")
                // createNewFile reserves a distinct destination without replacing existing backups.
                var attempt = 0
                var output: File
                do { output = File(dir, numberedName(proposed, attempt++)) } while (!output.createNewFile())
                target = output
                FileOutputStream(output).use { destination -> temporary.inputStream().use { it.copyTo(destination) }; destination.fd.sync() }
                if (!temporary.delete()) throw IllegalStateException("Cannot clean temporary download")
            }
            override fun discard() { temporary.delete(); target?.delete() }
        }
    }
    private fun numberedName(name: String, index: Int): String = if (index == 0) name else name.removeSuffix(".settrace.json") + "-$index.settrace.json"
    private fun uniqueName(name: String, exists: (String) -> Boolean): String {
        var index = 0
        while (exists(numberedName(name, index))) index++
        return numberedName(name, index)
    }
    private class FileFailure(val code: String) : IllegalArgumentException(code)
    private fun error(code: String) = mapOf("status" to "error", "code" to code)
    private fun finish(request: Request, value: Map<String, Any>) {
        main.post {
            if (request.completed.compareAndSet(false, true)) {
                if (pending === request) pending = null
                request.result.success(value)
            }
        }
    }
    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        pending?.let { finish(it, mapOf("status" to "cancelled")) }
        io.shutdownNow()
    }
}
