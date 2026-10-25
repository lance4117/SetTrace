package com.settrace.settrace

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.ActivityTestRule
import dev.flutter.plugins.integration_test.FlutterTestRunner
import org.junit.Assume.assumeTrue
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runner.notification.RunListener
import org.junit.runner.notification.RunNotifier
import org.junit.runner.notification.Failure

/** Explicitly opted-in fixture APK; never runs with the production Dart target. */
@RunWith(AndroidJUnit4::class)
class DiagnosticsIntegrationTest {
    class Fixture {
        @Rule @JvmField val rule = ActivityTestRule(MainActivity::class.java, true, false)
    }
    @Test fun activeRestAndStartupFailureDiagnosticScenario() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("diagnosticsQa") == "true")
        val failures = mutableListOf<String>()
        val notifier = RunNotifier()
        notifier.addListener(object : RunListener() {
            override fun testFailure(failure: Failure) { failures.add(failure.trace) }
        })
        FlutterTestRunner(Fixture::class.java).run(notifier)
        assertTrue(failures.joinToString("\n"), failures.isEmpty())
    }
}
