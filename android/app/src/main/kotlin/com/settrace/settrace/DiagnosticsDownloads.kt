package com.settrace.settrace

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream
import java.io.FilterOutputStream
import java.io.InputStream
import java.io.OutputStream

/** App-owned generated destinations only; no caller-supplied source URI. */
class AndroidDiagnosticDownloads(private val context: Context) : DiagnosticPublicFiles {
    override fun reserve(id: String, proposed: String, beforeReservation: (String) -> Unit): DiagnosticPublicEntry {
        require(DiagnosticVocabulary.token.matches(id))
        if (Build.VERSION.SDK_INT >= 29) {
            beforeReservation(proposed)
            val uri = context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, proposed)
                put(MediaStore.MediaColumns.TITLE, id)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/zip")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }) ?: throw DiagnosticFailure("storage_unavailable")
            var actual: String? = null
            context.contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use { cursor -> if (cursor.moveToFirst()) actual = cursor.getString(0) }
            val name = actual ?: throw DiagnosticFailure("publication_unknown")
            if (!validName(name, id)) throw DiagnosticFailure("publication_unknown")
            return MediaEntry(ContentUris.parseId(uri), name)
        }
        @Suppress("DEPRECATION")
        if (context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) throw DiagnosticFailure("permission_denied")
        val directory = downloadDirectory()
        for (suffix in 0 until 32) {
            val name = if (suffix == 0) proposed else proposed.removeSuffix(".zip") + "-$suffix.zip"
            if (!validName(name, id)) throw DiagnosticFailure("validation")
            beforeReservation(name)
            val target = File(directory, name)
            if (!target.createNewFile()) continue
            val partial = File(directory, ".$name.partial")
            if (!partial.createNewFile()) {
                if (target.length() == 0L) target.delete()
                continue
            }
            return LegacyEntry(name)
        }
        throw DiagnosticFailure("name_conflict")
    }

    override fun find(id: String, name: String, locator: String?): DiagnosticPublicEntry? {
        require(DiagnosticVocabulary.token.matches(id) && validName(name, id))
        if (Build.VERSION.SDK_INT >= 29) {
            if (locator?.startsWith("media:") == true) {
                val identity = locator.substringAfter(':').toLongOrNull()?.takeIf { it > 0 } ?: throw DiagnosticFailure("publication_unknown")
                val entry = MediaEntry(identity, name)
                return if (entry.existsAndOwned()) entry else null
            }
            var identity: Long? = null
            context.contentResolver.query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.OWNER_PACKAGE_NAME} = ? AND (${MediaStore.MediaColumns.TITLE} = ? OR ${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?)",
                arrayOf(context.packageName, id, "%$id%"), null)?.use { cursor ->
                if (cursor.count > 1) throw DiagnosticFailure("publication_unknown")
                if (cursor.moveToFirst()) identity = cursor.getLong(0)
            } ?: throw DiagnosticFailure("publication_unknown")
            return identity?.let { MediaEntry(it, name) }
        }
        if (context.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) throw DiagnosticFailure("permission_denied")
        if (locator != null && locator != "legacy:$name") throw DiagnosticFailure("publication_unknown")
        val entry = LegacyEntry(name)
        if (!entry.target.exists() && !entry.partial.exists()) return null
        // Before the ownership locator was committed, an existing legacy path
        // cannot be distinguished from a collision. Keep it, report unknown.
        if (locator == null) throw DiagnosticFailure("publication_unknown")
        return entry
    }

    @android.annotation.TargetApi(29)
    private inner class MediaEntry(private val identity: Long, override val name: String) : DiagnosticPublicEntry {
        private val uri get() = ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, identity)
        override val locator get() = "media:$identity"
        fun existsAndOwned(): Boolean {
            var exists = false
            context.contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.OWNER_PACKAGE_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    if (cursor.getString(0) != context.packageName) throw DiagnosticFailure("publication_unknown")
                    exists = true
                }
            } ?: throw DiagnosticFailure("publication_unknown")
            return exists
        }
        override fun output(): OutputStream {
            if (!existsAndOwned() || published() != false) throw DiagnosticFailure("publication_unknown")
            val descriptor = context.contentResolver.openFileDescriptor(uri, "w") ?: throw DiagnosticFailure("storage_unavailable")
            val stream = ParcelFileDescriptor.AutoCloseOutputStream(descriptor)
            return object : FilterOutputStream(stream) {
                override fun write(bytes: ByteArray, offset: Int, size: Int) { out.write(bytes, offset, size) }
                override fun close() { try { descriptor.fileDescriptor.sync() } finally { out.close() } }
            }
        }
        override fun input(): InputStream {
            if (!existsAndOwned()) throw DiagnosticFailure("missing")
            return context.contentResolver.openInputStream(uri) ?: throw DiagnosticFailure("read_failed")
        }
        override fun publish() {
            if (!existsAndOwned()) throw DiagnosticFailure("missing")
            val updated = context.contentResolver.update(uri, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
            if (updated != 1) throw DiagnosticFailure("publication_unknown")
        }
        override fun published(): Boolean? {
            if (!existsAndOwned()) return null
            var result: Boolean? = null
            context.contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.IS_PENDING), null, null, null)?.use { cursor -> if (cursor.moveToFirst()) result = cursor.getInt(0) == 0 }
            return result
        }
        override fun discardPending(): Boolean {
            if (!existsAndOwned()) return true
            if (published() != false) return false
            return context.contentResolver.delete(uri, null, null) == 1
        }
    }

    private inner class LegacyEntry(override val name: String) : DiagnosticPublicEntry {
        val target = File(downloadDirectory(), name)
        val partial = File(downloadDirectory(), ".$name.partial")
        override val locator get() = "legacy:$name"
        override fun output(): OutputStream {
            if (!partial.exists() || !target.exists() || target.length() != 0L) throw DiagnosticFailure("publication_unknown")
            return object : FileOutputStream(partial) { override fun close() { try { fd.sync() } finally { super.close() } } }
        }
        override fun input(): InputStream = (if (partial.exists()) partial else target).inputStream()
        override fun publish() {
            if (!target.exists() || target.length() != 0L || !partial.exists()) throw DiagnosticFailure("publication_unknown")
            if (!partial.renameTo(target)) throw DiagnosticFailure("publication_unknown")
        }
        override fun published(): Boolean? = when {
            partial.exists() && target.exists() && target.length() == 0L -> false
            !partial.exists() && target.exists() && target.length() > 0L -> true
            !target.exists() && !partial.exists() -> null
            else -> null
        }
        override fun discardPending(): Boolean {
            if (published() == true || target.exists() && target.length() > 0L) return false
            val partialGone = !partial.exists() || partial.delete()
            val reservationGone = !target.exists() || target.delete()
            return partialGone && reservationGone
        }
    }

    @Suppress("DEPRECATION")
    private fun downloadDirectory(): File = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).also {
        if (!it.isDirectory && !it.mkdirs()) throw DiagnosticFailure("storage_unavailable")
    }
    private fun validName(name: String, id: String): Boolean = name.length <= 192 && Regex("SetTrace-diagnostics-[a-zA-Z0-9 ._()-]*${Regex.escape(id)}[a-zA-Z0-9 ._()-]*\\.zip").matches(name)
}
