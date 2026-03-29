package com.submersion.libdivecomputer

import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Centralized logger that sends log events back to Flutter via Pigeon
 * while also logging to Android logcat.
 */
object NativeLogger {
    private var flutterApi: DiveComputerFlutterApi? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setFlutterApi(api: DiveComputerFlutterApi?) {
        flutterApi = api
    }

    fun d(tag: String, category: String, message: String) {
        Log.d(tag, message)
        sendToFlutter(category, "DEBUG", message)
    }

    fun i(tag: String, category: String, message: String) {
        Log.i(tag, message)
        sendToFlutter(category, "INFO", message)
    }

    fun w(tag: String, category: String, message: String) {
        Log.w(tag, message)
        sendToFlutter(category, "WARN", message)
    }

    fun e(tag: String, category: String, message: String) {
        Log.e(tag, message)
        sendToFlutter(category, "ERROR", message)
    }

    private fun sendToFlutter(category: String, level: String, message: String) {
        val api = flutterApi ?: return
        mainHandler.post {
            try {
                api.onLogEvent(category, level, message) {}
            } catch (_: Exception) {
                // Don't let logging failures crash the app
            }
        }
    }
}
