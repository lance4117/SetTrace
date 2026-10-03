package com.settrace.settrace

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var planFiles: PlanFilesBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        planFiles = PlanFilesBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (planFiles?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (planFiles?.onPermissionResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
    override fun onDestroy() {
        planFiles?.dispose()
        planFiles = null
        super.onDestroy()
    }
}
