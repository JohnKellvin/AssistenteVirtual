package com.jarvis.jarvis_android

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jarvis/janela").setMethodCallHandler { call, result ->
            when (call.method) {
                "temPermissao" -> result.success(Settings.canDrawOverlays(this))
                "pedirPermissao" -> {
                    val i = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                    startActivity(i)
                    result.success(null)
                }
                "mostrar" -> {
                    if (!Settings.canDrawOverlays(this)) { result.success(false); return@setMethodCallHandler }
                    val i = Intent(this, FloatingService::class.java)
                        .putExtra("standby", call.argument<Boolean>("standby") ?: false)
                        .putExtra("nome", call.argument<String>("nome") ?: "Jarvis")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                    result.success(true)
                }
                "esconder" -> { stopService(Intent(this, FloatingService::class.java)); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
}
