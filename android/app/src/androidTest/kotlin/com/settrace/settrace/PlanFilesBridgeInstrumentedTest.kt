package com.settrace.settrace

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** Real Android resolver/looper tests; picker UI and downloads are verified separately. */
@RunWith(AndroidJUnit4::class)
class PlanFilesBridgeInstrumentedTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private class PickerActivity(context: Context) : Activity() {
        init { attachBaseContext(context) }
        var picker: Intent? = null
        override fun startActivityForResult(intent: Intent, requestCode: Int) { picker = intent }
    }
    private class Messenger : BinaryMessenger {
        override fun send(channel: String, message: ByteBuffer?) { }
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) { }
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) { }
    }
    private class Result : MethodChannel.Result {
        val latch = CountDownLatch(1)
        val calls = AtomicInteger(0)
        var value: Any? = null
        override fun success(result: Any?) { value = result; calls.incrementAndGet(); latch.countDown() }
        override fun error(code: String, message: String?, details: Any?) { throw AssertionError(message) }
        override fun notImplemented() { throw AssertionError("Unimplemented") }
        fun await(): Map<*, *> { assertTrue("Native request timed out", latch.await(10, TimeUnit.SECONDS)); return value as Map<*, *> }
    }
    private fun read(uri: Uri): Map<*, *> {
        lateinit var activity: PickerActivity
        instrumentation.runOnMainSync { activity = PickerActivity(context) }
        lateinit var bridge: PlanFilesBridge
        val result = Result()
        instrumentation.runOnMainSync {
            bridge = PlanFilesBridge(activity, Messenger())
            bridge.onMethodCall(MethodCall("pickFile", null), result)
            assertEquals(Intent.ACTION_OPEN_DOCUMENT, activity.picker!!.action)
            assertEquals("*/*", activity.picker!!.type)
            assertFalse(activity.picker!!.hasExtra(Intent.EXTRA_MIME_TYPES))
            bridge.onActivityResult(47101, Activity.RESULT_OK, Intent().setData(uri))
        }
        val value = result.await()
        instrumentation.runOnMainSync {
            // A repeated/stale callback cannot complete a request twice or reuse old text.
            bridge.onActivityResult(47101, Activity.RESULT_OK, Intent().setData(uri))
            bridge.dispose()
        }
        instrumentation.waitForIdleSync()
        assertEquals(1, result.calls.get())
        return value
    }
    @Test fun readsUtf8AndRejectsEmptyOversizedInvalidOrUnreadableFiles() {
        val file = File(context.cacheDir, "native-plan-qa.txt")
        try {
            file.writeText("\uFEFF{\"name\":\"练背\"}", Charsets.UTF_8)
            assertEquals("\uFEFF{\"name\":\"练背\"}", read(Uri.fromFile(file))["text"])
            file.writeBytes(byteArrayOf())
            assertEquals("error", read(Uri.fromFile(file))["status"])
            // File URI supplies no metadata size; this exercises the streaming cap.
            file.writeBytes(ByteArray(PlanFilesBridge.MAX_BYTES + 1) { 65 })
            assertEquals("fileTooLarge", read(Uri.fromFile(file))["code"])
            file.writeBytes(byteArrayOf(0xC3.toByte(), 0x28))
            assertEquals("error", read(Uri.fromFile(file))["status"])
            file.delete()
            assertEquals("error", read(Uri.fromFile(file))["status"])
            // App has no READ_CONTACTS grant: resolver denies access.
            assertEquals("error", read(Uri.parse("content://com.android.contacts/contacts/1"))["status"])
        } finally { file.delete() }
    }
    @Test fun cancelledAndDisposedPickersNeverReturnStaleContent() {
        lateinit var activity: PickerActivity
        instrumentation.runOnMainSync { activity = PickerActivity(context) }
        lateinit var bridge: PlanFilesBridge
        val cancelled = Result()
        instrumentation.runOnMainSync {
            bridge = PlanFilesBridge(activity, Messenger())
            bridge.onMethodCall(MethodCall("pickFile", null), cancelled)
            bridge.onActivityResult(47101, Activity.RESULT_CANCELED, null)
        }
        assertEquals("cancelled", cancelled.await()["status"])
        val disposed = Result()
        instrumentation.runOnMainSync {
            bridge.onMethodCall(MethodCall("pickFile", null), disposed)
            bridge.dispose()
        }
        assertEquals("cancelled", disposed.await()["status"])
        instrumentation.runOnMainSync {
            bridge.onActivityResult(47101, Activity.RESULT_OK, Intent().setData(Uri.parse("file:///stale.json")))
        }
        instrumentation.waitForIdleSync()
        assertEquals(1, cancelled.calls.get())
        assertEquals(1, disposed.calls.get())
    }
    @Test fun publicDownloadsCollisionsAndWriteFailureCleanup() {
        lateinit var bridge: PlanFilesBridge
        instrumentation.runOnMainSync { bridge = PlanFilesBridge(PickerActivity(context), Messenger()) }
        val factory = PlanFilesBridge::class.java.getDeclaredMethod(
            if (android.os.Build.VERSION.SDK_INT >= 29) "mediaEntry" else "legacyEntry", String::class.java
        ).apply { isAccessible = true }
        val dir = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS)
        fun entry(name: String) = factory.invoke(bridge, name) as DownloadEntry
        val first = entry("QA-native-collision.settrace.json")
        var second: DownloadEntry? = null
        try {
            val original = "original backup".toByteArray()
            val firstName = writeDownload(first, original)
            second = entry("QA-native-collision.settrace.json")
            val secondName = writeDownload(second, "second backup".toByteArray())
            assertNotEquals(firstName, secondName)
            assertArrayEquals(original, File(dir, firstName).readBytes())
            assertEquals("second backup", File(dir, secondName).readText())
            val beforeFailure = dir.list()!!.toSet()
            val failed = entry("QA-native-failure.settrace.json")
            val fault = object : DownloadEntry by failed {
                override fun open(): java.io.OutputStream = object : java.io.FilterOutputStream(failed.open()) {
                    override fun write(bytes: ByteArray, offset: Int, length: Int) {
                        out.write(bytes, offset, 1)
                        throw IllegalStateException("Injected storage interruption")
                    }
                }
            }
            try { writeDownload(fault, byteArrayOf(1, 2, 3)); fail("Must fail") }
            catch (_: IllegalStateException) { }
            assertEquals(beforeFailure, dir.list()!!.toSet())
            assertArrayEquals(original, File(dir, firstName).readBytes())
        } finally {
            first.discard(); second?.discard()
            instrumentation.runOnMainSync { bridge.dispose() }
        }
    }
    @Test fun clipboardQaRelay() {
        val mode = InstrumentationRegistry.getArguments().getString("clipboardMode")
        org.junit.Assume.assumeTrue("Explicit clipboard QA fixture required", mode == "capture" || mode == "install")
        if (mode == "capture") captureClipboardForCrossDeviceQa() else installForwardedClipboardForCrossDeviceQa()
    }
    private fun foregroundApp() {
        instrumentation.startActivitySync(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        instrumentation.waitForIdleSync()
    }
    /** Run explicitly after tapping the actual app's Copy button, never in the default suite. */
    private fun captureClipboardForCrossDeviceQa() {
        foregroundApp()
        instrumentation.runOnMainSync {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val text = clipboard.primaryClip?.getItemAt(0)?.text?.toString()
            assertNotNull("Tap Copy in app before capture", text)
            assertTrue(text!!.contains("settrace.training-plans"))
            File(context.cacheDir, "qa-clipboard.txt").writeText(text, Charsets.UTF_8)
        }
    }
    /** Host forwards the captured bytes into this cache file, then actual app handles paste. */
    private fun installForwardedClipboardForCrossDeviceQa() {
        foregroundApp()
        instrumentation.runOnMainSync {
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val text = File(context.cacheDir, "qa-clipboard.txt").readText(Charsets.UTF_8)
            clipboard.setPrimaryClip(ClipData.newPlainText("Plan QA", text))
        }
    }
}
