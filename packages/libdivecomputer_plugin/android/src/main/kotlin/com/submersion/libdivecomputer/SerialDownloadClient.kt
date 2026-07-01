package com.submersion.libdivecomputer

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Main-process client for the :dc download service. Binds the service, forwards
 * the request, re-emits its callbacks to Flutter via the existing Pigeon API,
 * and -- the whole point -- detects a :dc crash via linkToDeath and reports it
 * as a normal error so the app never dies. No in-process fallback. See #318.
 */
class SerialDownloadClient(
    private val context: Context,
    private val flutterApi: DiveComputerFlutterApi,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val inFlight = AtomicBoolean(false)
    private var service: IDiveDownloadService? = null
    private var pending: SerialDownloadRequest? = null

    private val deathRecipient = IBinder.DeathRecipient {
        // Fires when :dc dies (native SIGSEGV or OS kill) mid-download.
        onChildGone("The download process stopped unexpectedly — please try again.")
    }

    private val callback = object : IDiveDownloadCallback.Stub() {
        override fun onProgress(current: Int, max: Int) {
            postProgress(current, max)
        }
        override fun onDive(pigeonEncodedDive: ByteArray) {
            val dive = DiveMarshaling.decode(pigeonEncodedDive)
            mainHandler.post { flutterApi.onDiveDownloaded(dive) { } }
        }
        override fun onError(code: String, message: String) {
            finish()
            mainHandler.post {
                flutterApi.onError(DiveComputerError(code = code, message = message)) { }
            }
        }
        override fun onComplete(totalDives: Long) {
            finish()
            mainHandler.post { flutterApi.onDownloadComplete(totalDives, null, null) { } }
        }
    }

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            binder ?: return
            try {
                binder.linkToDeath(deathRecipient, 0)
            } catch (_: Throwable) { /* already dead -> onServiceDisconnected handles it */ }
            val svc = IDiveDownloadService.Stub.asInterface(binder)
            service = svc
            val req = pending ?: return
            try {
                svc.startSerialDownload(req, callback)
            } catch (_: Throwable) {
                onChildGone("Could not start the download process.")
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            // Backup signal for a process death that didn't fire linkToDeath.
            onChildGone("The download process stopped unexpectedly — please try again.")
        }
    }

    fun start(request: SerialDownloadRequest) {
        if (!inFlight.compareAndSet(false, true)) return
        pending = request
        val intent = Intent(context, DiveDownloadService::class.java)
        val bound = try {
            context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
        } catch (_: Throwable) { false }
        if (!bound) {
            // No in-process fallback: report and stop.
            inFlight.set(false)
            mainHandler.post {
                flutterApi.onError(DiveComputerError(
                    code = "download_error",
                    message = "Could not start the download process.")) { }
            }
        }
    }

    fun cancel() {
        try { service?.cancel() } catch (_: Throwable) { /* dying anyway */ }
    }

    private fun postProgress(current: Int, max: Int) {
        val progress = DownloadProgress(
            current = current.toLong(), total = max.toLong(), status = "downloading")
        mainHandler.post { flutterApi.onDownloadProgress(progress) { } }
    }

    private fun onChildGone(message: String) {
        // Only report if a download was actually in-flight (ignore benign unbind).
        if (!inFlight.compareAndSet(true, false)) { unbind(); return }
        unbind()
        mainHandler.post {
            flutterApi.onError(DiveComputerError(code = "download_crashed", message = message)) { }
        }
    }

    private fun finish() {
        inFlight.set(false)
        unbind()
    }

    private fun unbind() {
        val svc = service
        service = null
        pending = null
        try {
            svc?.asBinder()?.unlinkToDeath(deathRecipient, 0)
        } catch (_: Throwable) { }
        try {
            context.unbindService(connection)
        } catch (_: Throwable) { }
    }
}
