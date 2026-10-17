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
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors

internal const val BACKUP_MAX_BYTES = 64L * 1024 * 1024
internal class BackupFileFailure(val code: String) : Exception(code)

internal fun copyBackupBounded(input: InputStream, output: OutputStream): Long {
    val buffer = ByteArray(64 * 1024)
    var total = 0L
    while (true) {
        val count = input.read(buffer)
        if (count == -1) break
        total += count
        if (total > BACKUP_MAX_BYTES) throw BackupFileFailure("tooLarge")
        if (Thread.currentThread().isInterrupted) throw BackupFileFailure("cancelled")
        output.write(buffer, 0, count)
    }
    output.flush()
    return total
}

internal fun backupFileDigest(input: InputStream): String {
    val digest = MessageDigest.getInstance("SHA-256")
    var total = 0L
    val buffer = ByteArray(64 * 1024)
    while (true) {
        val count = input.read(buffer)
        if (count == -1) break
        total += count
        if (total > BACKUP_MAX_BYTES) throw BackupFileFailure("tooLarge")
        digest.update(buffer, 0, count)
    }
    return digest.digest().joinToString("") { "%02x".format(it) }
}

class BackupFilesBridge(private val activity: Activity, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    companion object { private const val PICK = 47201; private const val PERMISSION = 47202 }
    private val channel = MethodChannel(messenger, "settrace/backup_files")
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val stage = File(activity.cacheDir, "backup-stage").apply { mkdirs() }
    private val recovery = File(activity.filesDir, "backup-recovery").apply { mkdirs() }
    private val journal = File(activity.filesDir, "backup-export-journal").apply { mkdirs() }
    private var pending: MethodChannel.Result? = null
    private var permissionAction: (() -> Map<String, Any?>)? = null
    private var candidate: String? = null
    private var disposed = false
    init { channel.setMethodCallHandler(this) }

    private fun safe(value: String): String {
        require(Regex("^[a-zA-Z0-9_-]+$").matches(value)) { "invalidToken" }
        return value
    }
    private fun staged(token: String) = File(stage, "${safe(token)}.json").also {
        require(it.canonicalFile.parentFile == stage.canonicalFile) { "invalidToken" }
    }
    private fun recordFile(id: String) = File(journal, "${safe(id)}.json")
    private fun load(id: String) = JSONObject(recordFile(id).readText())
    private fun save(id: String, record: JSONObject) {
        val target = recordFile(id)
        val tmp = File(journal, "${safe(id)}.partial")
        FileOutputStream(tmp).use { it.write(record.toString().toByteArray(Charsets.UTF_8)); it.fd.sync() }
        if (!tmp.renameTo(target)) throw BackupFileFailure("journalFailed")
    }
    private fun ok(vararg values: Pair<String, Any?>) = mapOf("status" to "success", *values)
    private fun finish(value: Map<String, Any?>) = main.post {
        val result = pending
        pending = null
        permissionAction = null
        FilePickerGate.release(this)
        result?.success(value)
    }
    private fun work(action: () -> Map<String, Any?>) {
        io.execute {
            try { finish(action()) }
            catch (e: BackupFileFailure) { finish(mapOf("status" to "error", "code" to e.code)) }
            catch (_: SecurityException) { finish(mapOf("status" to "error", "code" to "permissionDenied")) }
            catch (_: Exception) { finish(mapOf("status" to "error", "code" to "storage")) }
        }
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) { result.success(mapOf("status" to "cancelled")); return }
        if (pending != null) { result.success(mapOf("status" to "error", "code" to "busy")); return }
        pending = result
        if (call.method == "pick") {
            if (!FilePickerGate.acquire(this)) { finish(mapOf("status" to "error", "code" to "busy")); return }
            try {
                candidate?.let { staged(it).delete() }; candidate = null
                activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE); type = "*/*"
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }, PICK)
            } catch (_: Exception) { finish(mapOf("status" to "error", "code" to "pickerFailed")) }
            return
        }
        val action = {
            when (call.method) {
                "initialize" -> ok("stageRoot" to stage.canonicalPath, "recoveryRoot" to recovery.canonicalPath)
                "allocate" -> { val token = UUID.randomUUID().toString(); check(staged(token).createNewFile()); ok("token" to token) }
                "discard" -> { val file = staged(call.argument<String>("token")!!); if (file.exists()) check(file.delete()); ok() }
                "reserve" -> reserve(safe(call.argument<String>("requestId")!!), safe(call.argument<String>("token")!!))
                "publish" -> publish(safe(call.argument<String>("requestId")!!))
                "inspect" -> inspect(safe(call.argument<String>("requestId")!!))
                "cleanup" -> { cleanup(safe(call.argument<String>("requestId")!!)); ok() }
                else -> throw BackupFileFailure("unsupported")
            }
        }
        if (call.method == "reserve" && Build.VERSION.SDK_INT <= 28 &&
            activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            permissionAction = action
            activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), PERMISSION)
        } else work(action)
    }
    fun onPermissionResult(code: Int, grants: IntArray): Boolean {
        if (code != PERMISSION) return false
        val action = permissionAction ?: return true
        if (grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED) work(action)
        else finish(mapOf("status" to "error", "code" to "permissionDenied"))
        return true
    }
    fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code != PICK) return false
        if (pending == null) return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { finish(mapOf("status" to "cancelled")); return true }
        work {
            val token = UUID.randomUUID().toString()
            val file = staged(token)
            try {
                var name = "backup.settrace.json"
                activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
                    if (it.moveToFirst()) {
                        if (!it.isNull(0)) name = it.getString(0)
                        if (!it.isNull(1) && it.getLong(1) > BACKUP_MAX_BYTES) throw BackupFileFailure("tooLarge")
                    }
                }
                val bytes = activity.contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(file).use { out -> copyBackupBounded(input, out).also { out.fd.sync() } }
                } ?: throw BackupFileFailure("readFailed")
                candidate = token
                ok("token" to token, "fileName" to name, "bytes" to bytes)
            } catch (e: Exception) { file.delete(); throw e }
        }
        return true
    }
    @Suppress("DEPRECATION")
    private fun reserve(id: String, token: String): Map<String, Any?> {
        if (recordFile(id).exists()) return receipt(id, load(id))
        val source = staged(token)
        val digest = source.inputStream().use(::backupFileDigest)
        val stamp = SimpleDateFormat("yyyy-MM-dd-HHmmss-SSS", Locale.ROOT).format(Date())
        val name = "SetTrace-backup-$stamp-$id.settrace.json"
        // Persist ownership/name before reserving any public destination.
        val record = JSONObject().put("id", id).put("token", token).put("name", name)
            .put("digest", digest).put("bytes", source.length()).put("state", "reserving")
        save(id, record)
        if (Build.VERSION.SDK_INT >= 29) {
            val uri = activity.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name); put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }) ?: throw BackupFileFailure("reserveFailed")
            record.put("uri", uri.toString())
        } else {
            val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloads.exists()) check(downloads.mkdirs())
            val target = File(downloads, name)
            check(target.createNewFile()) // never overwrite even a collision
            record.put("path", target.canonicalPath)
        }
        record.put("state", "reserved"); save(id, record)
        return receipt(id, record)
    }
    private fun receipt(id: String, record: JSONObject) = ok("requestId" to id,
        "fileName" to record.getString("name"), "location" to "downloads",
        "target" to record.optString("uri", record.optString("path", "")),
        "bytes" to record.getLong("bytes"), "state" to record.getString("state"))
    private fun input(record: JSONObject): InputStream = if (record.has("uri"))
        activity.contentResolver.openInputStream(Uri.parse(record.getString("uri"))) ?: throw BackupFileFailure("readFailed")
        else File(record.getString("path")).inputStream()
    private fun publish(id: String): Map<String, Any?> {
        val record = load(id)
        if (record.getString("state") == "published") return inspect(id)
        if (record.getString("state") != "reserved") throw BackupFileFailure("pendingVerification")
        commitBackupOutput(
            writeAndClose = {
            val source = staged(record.getString("token"))
            if (source.inputStream().use(::backupFileDigest) != record.getString("digest")) throw BackupFileFailure("sourceChanged")
            if (record.has("uri")) {
                activity.contentResolver.openFileDescriptor(Uri.parse(record.getString("uri")), "w")?.use { fd ->
                    FileOutputStream(fd.fileDescriptor).use { out -> source.inputStream().use { copyBackupBounded(it, out) }; out.fd.sync() }
                } ?: throw BackupFileFailure("writeFailed")
            } else {
                val target = File(record.getString("path"))
                val tmp = File(target.parentFile, ".${target.name}.partial")
                FileOutputStream(tmp).use { out -> source.inputStream().use { copyBackupBounded(it, out) }; out.fd.sync() }
                check(tmp.inputStream().use(::backupFileDigest) == record.getString("digest"))
                check(tmp.renameTo(target))
            }
            },
            verify = { input(record).use(::backupFileDigest) == record.getString("digest") },
            markVerified = { record.put("state", "verified"); save(id, record) },
            publish = {
                if (record.has("uri") && Build.VERSION.SDK_INT >= 29) {
                    check(activity.contentResolver.update(Uri.parse(record.getString("uri")), ContentValues().apply {
                        put(MediaStore.MediaColumns.IS_PENDING, 0)
                    }, null, null) == 1)
                }
            },
            markPublished = { record.put("state", "published"); save(id, record) },
            discardIncomplete = {
                record.put("state", "failed"); save(id, record)
                cleanup(id)
            },
        )
        return receipt(id, record)
    }
    private fun inspect(id: String): Map<String, Any?> {
        if (!recordFile(id).exists()) return ok("requestId" to id, "state" to "cleaned")
        val record = load(id)
        if (record.getString("state") == "cleaned") return receipt(id, record)
        // A process exit can happen between destination creation and journaling
        // its URI. Recover only this app's uniquely named reservation.
        if (!record.has("uri") && !record.has("path")) {
            if (Build.VERSION.SDK_INT >= 29) {
                activity.contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    arrayOf(MediaStore.MediaColumns._ID),
                    "${MediaStore.MediaColumns.DISPLAY_NAME} = ? AND ${MediaStore.MediaColumns.OWNER_PACKAGE_NAME} = ?",
                    arrayOf(record.getString("name"), activity.packageName), null)?.use {
                    if (it.count > 1) throw BackupFileFailure("pendingVerification")
                    if (it.moveToFirst()) record.put("uri", android.content.ContentUris.withAppendedId(
                        MediaStore.Downloads.EXTERNAL_CONTENT_URI, it.getLong(0)).toString())
                }
            } else {
                @Suppress("DEPRECATION")
                val target = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), record.getString("name"))
                if (target.exists()) record.put("path", target.canonicalPath)
            }
            if (!record.has("uri") && !record.has("path")) {
                record.put("state", "cleaned"); save(id, record)
                return receipt(id, record)
            }
            save(id, record)
        }
        if (record.getString("state") == "failed") {
            cleanup(id)
            return receipt(id, load(id))
        }
        val matches = input(record).use(::backupFileDigest) == record.getString("digest")
        if (!matches) {
            // Never remove an output previously verified or published.
            if (record.getString("state") in listOf("reserving", "reserved")) {
                record.put("state", "failed"); save(id, record); cleanup(id)
                return receipt(id, load(id))
            }
            throw BackupFileFailure("verifyFailed")
        }
        var published = !record.has("uri")
        if (record.has("uri") && Build.VERSION.SDK_INT >= 29) {
            activity.contentResolver.query(Uri.parse(record.getString("uri")), arrayOf(MediaStore.MediaColumns.IS_PENDING), null, null, null)?.use {
                published = it.moveToFirst() && it.getInt(0) == 0
            }
            if (!published) {
                // The complete bytes were reread successfully; finish only
                // publication, never copy or overwrite the file again.
                check(activity.contentResolver.update(Uri.parse(record.getString("uri")), ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }, null, null) == 1)
                published = true
            }
        }
        if (published) { record.put("state", "published"); save(id, record) }
        return receipt(id, record)
    }
    private fun cleanup(id: String) {
        val record = load(id)
        check(record.getString("state") == "failed") { "cannotDeleteCompletedOutput" }
        if (record.has("uri")) {
            val uri = Uri.parse(record.getString("uri"))
            if (activity.contentResolver.delete(uri, null, null) == 0) {
                activity.contentResolver.query(uri, arrayOf(MediaStore.MediaColumns._ID), null, null, null)?.use {
                    check(!it.moveToFirst()) { "cleanupFailed" }
                } ?: throw BackupFileFailure("cleanupFailed")
            }
        }
        else if (record.has("path")) {
            val target = File(record.getString("path"))
            if (target.exists()) check(target.delete())
            val tmp = File(target.parentFile, ".${target.name}.partial")
            if (tmp.exists()) check(tmp.delete())
        }
        record.put("state", "cleaned"); save(id, record)
    }
    fun dispose() {
        disposed = true; channel.setMethodCallHandler(null)
        FilePickerGate.release(this)
        pending?.success(mapOf("status" to "cancelled")); pending = null
        io.shutdown() // Finish durable journal/file operations already admitted.
    }
}
