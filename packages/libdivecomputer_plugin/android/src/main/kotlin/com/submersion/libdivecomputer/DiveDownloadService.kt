package com.submersion.libdivecomputer

import android.app.Service
import android.content.Intent
import android.os.IBinder
import java.util.concurrent.Executors

/**
 * Bound Service that runs the serial download in its OWN process (:dc, declared
 * in the manifest). A native SIGSEGV during the download kills only this
 * process; SerialDownloadClient (main process) sees the binder die and reports
 * an error, so the app never dies. One download at a time. See issue #318.
 */
class DiveDownloadService : Service() {

    private val executor = Executors.newSingleThreadExecutor()
    @Volatile private var runner: SerialDownloadRunner? = null

    private val binder = object : IDiveDownloadService.Stub() {
        override fun startSerialDownload(
            request: SerialDownloadRequest,
            callback: IDiveDownloadCallback,
        ) {
            executor.execute {
                // Debug-only isolation proof: a reserved vendor triggers a real
                // native crash so tests can verify :dc dies without killing the app.
                if (request.vendor == CRASH_TEST_VENDOR) {
                    LibdcWrapper.nativeDebugCrash()
                    return@execute
                }
                val r = SerialDownloadRunner(applicationContext)
                runner = r
                try {
                    r.run(request, callback)
                } catch (t: Throwable) {
                    // Java-level failure (not a native crash): report, don't die.
                    try {
                        callback.onError("download_error",
                            "Download failed unexpectedly (${t.javaClass.simpleName}).")
                    } catch (_: Throwable) { /* main process gone */ }
                } finally {
                    runner = null
                }
            }
        }

        override fun cancel() {
            runner?.cancel()
        }
    }

    override fun onBind(intent: Intent?): IBinder = binder

    companion object {
        const val CRASH_TEST_VENDOR = "__crash_test__"
    }
}
