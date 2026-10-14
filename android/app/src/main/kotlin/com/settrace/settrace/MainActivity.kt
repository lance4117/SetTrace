package com.settrace.settrace

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var planFiles: PlanFilesBridge? = null
    private var restAlerts: RestAlertsBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        planFiles = PlanFilesBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        restAlerts = RestAlertsBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onResume() {
        super.onResume()
        RestAlertsRuntime.foreground = true
    }
    override fun onPause() {
        RestAlertsRuntime.foreground = false
        super.onPause()
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        restAlerts?.onNewIntent(intent)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (planFiles?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (restAlerts?.onPermissionResult(requestCode) == true) return
        if (planFiles?.onPermissionResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
    override fun onDestroy() {
        planFiles?.dispose(); planFiles = null
        restAlerts?.dispose(); restAlerts = null
        super.onDestroy()
    }
}
