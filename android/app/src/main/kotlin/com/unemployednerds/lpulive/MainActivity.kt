package com.unemployednerds.lpulive

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.lpulive_unofficial.LifecycleHandler

class MainActivity: FlutterActivity() {
    private val lifecycleHandler = LifecycleHandler()
    private val FOREGROUND_SERVICE_PERMISSION_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up lifecycle handler
        lifecycleHandler.setMethodChannel(flutterEngine)
        registerActivityLifecycleCallbacks(lifecycleHandler)
        
        // Set up foreground service method channel
        val foregroundServiceChannel = io.flutter.plugin.common.MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, 
            "com.lpulive.foreground_service"
        )
        
        foregroundServiceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val chatToken = call.argument<String>("chatToken")
                    if (checkForegroundServicePermission()) {
                        startForegroundService(chatToken)
                        result.success(true)
                    } else {
                        requestForegroundServicePermission()
                        result.success(false)
                    }
                }
                "stopForegroundService" -> {
                    stopForegroundService()
                    result.success(true)
                }
                "checkForegroundServicePermission" -> {
                    result.success(checkForegroundServicePermission())
                }
                "requestForegroundServicePermission" -> {
                    requestForegroundServicePermission()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun startForegroundService(chatToken: String?) {
        val intent = Intent(this, WebSocketForegroundService::class.java).apply {
            action = WebSocketForegroundService.ACTION_START_SERVICE
            putExtra(WebSocketForegroundService.EXTRA_CHAT_TOKEN, chatToken)
        }
        startForegroundService(intent)
    }
    
    private fun stopForegroundService() {
        val intent = Intent(this, WebSocketForegroundService::class.java).apply {
            action = WebSocketForegroundService.ACTION_STOP_SERVICE
        }
        startService(intent)
    }
    
    private fun checkForegroundServicePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Permission not required for older versions
        }
    }
    
    private fun requestForegroundServicePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK),
                FOREGROUND_SERVICE_PERMISSION_REQUEST_CODE
            )
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == FOREGROUND_SERVICE_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                android.util.Log.d("MainActivity", "Foreground service permission granted")
            } else {
                android.util.Log.d("MainActivity", "Foreground service permission denied")
            }
        }
    }
}
