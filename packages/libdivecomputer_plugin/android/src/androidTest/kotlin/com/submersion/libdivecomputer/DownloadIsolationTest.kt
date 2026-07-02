package com.submersion.libdivecomputer

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Proves the whole point of issue #318: a native crash inside the :dc download
 * process must NOT take down the app. Uses the debug crash hook to make :dc
 * SIGSEGV, then asserts the child dies while THIS (test) process survives.
 * No dive computer required -- runs on any emulator/device.
 */
@RunWith(AndroidJUnit4::class)
class DownloadIsolationTest {

    @Test
    fun childCrashKillsOnlyServiceProcess_notThisTestProcess() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val died = CountDownLatch(1)

        val callback = object : IDiveDownloadCallback.Stub() {
            override fun onProgress(current: Int, max: Int) {}
            override fun onDive(pigeonEncodedDive: ByteArray) {}
            override fun onError(code: String, message: String) {}
            override fun onComplete(totalDives: Long) {}
        }

        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                binder ?: return
                // Detect :dc death (both signals).
                try {
                    binder.linkToDeath({ died.countDown() }, 0)
                } catch (_: Throwable) { died.countDown() }
                val svc = IDiveDownloadService.Stub.asInterface(binder)
                // Trigger the deliberate NATIVE crash inside :dc.
                svc.startSerialDownload(
                    SerialDownloadRequest(
                        DiveDownloadService.CRASH_TEST_VENDOR, "x", 0, null, null),
                    callback,
                )
            }
            override fun onServiceDisconnected(name: ComponentName?) { died.countDown() }
        }

        context.bindService(
            Intent(context, DiveDownloadService::class.java),
            connection, Context.BIND_AUTO_CREATE)

        // The child process must die (binder death observed) within a few seconds.
        assertTrue("expected :dc to die from the native crash",
            died.await(10, TimeUnit.SECONDS))

        // Crucially: THIS process is still alive and running assertions.
        // Reaching here at all proves the crash did not propagate.
        assertTrue(true)

        try { context.unbindService(connection) } catch (_: Throwable) {}
    }
}
