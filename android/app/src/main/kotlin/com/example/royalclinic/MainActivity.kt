package com.example.royalclinic

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaScannerConnection
import android.content.Context

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.royalclinic/media_scanner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "refreshFile") {
                val filePath = call.argument<String>("path")
                if (filePath != null) {
                    MediaScannerConnection.scanFile(this, arrayOf(filePath), null, null)
                    result.success("File scanned")
                } else {
                    result.error("INVALID_PATH", "File path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}