package com.example.lpulive_unofficial

import android.app.Activity
import android.app.Application
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class LifecycleHandler : Application.ActivityLifecycleCallbacks {
    private val channelName = "com.lpulive.lifecycle"
    private var methodChannel: MethodChannel? = null

    fun setMethodChannel(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, channelName)
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        // Activity created
    }

    override fun onActivityStarted(activity: Activity) {
        // Activity started
    }

    override fun onActivityResumed(activity: Activity) {
        // App resumed - notify Flutter
        methodChannel?.invokeMethod("onAppResumed", null)
    }

    override fun onActivityPaused(activity: Activity) {
        // App paused - notify Flutter
        methodChannel?.invokeMethod("onAppPaused", null)
    }

    override fun onActivityStopped(activity: Activity) {
        // Activity stopped
    }

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {
        // Save instance state
    }

    override fun onActivityDestroyed(activity: Activity) {
        // Activity destroyed - notify Flutter
        methodChannel?.invokeMethod("onAppDetached", null)
    }
}

