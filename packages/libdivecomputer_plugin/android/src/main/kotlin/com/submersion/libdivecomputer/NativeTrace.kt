package com.submersion.libdivecomputer

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Crash-survivable breadcrumb logger for the native dive-computer download path.
 *
 * [NativeLogger] routes events to Flutter asynchronously (`mainHandler.post` +
 * Pigeon), so the last breadcrumbs before a NATIVE crash (a SIGSEGV/SIGABRT
 * inside `nativeDownloadRun`) never reach `submersion.log` -- the process dies
 * with the events still queued on the main thread, which is exactly why every
 * crash log ends at "nativeDownloadRun (serial)" with nothing after it.
 *
 * This appends to the SAME `submersion.log` SYNCHRONOUSLY on the calling
 * (download) thread. A single unbuffered `write()` syscall per line lands the
 * bytes in the kernel page cache, which outlives the crashed process, so the
 * final line on disk names the operation that died. `fsync` is intentionally
 * omitted: a process crash (not a kernel panic) cannot lose page-cache data, and
 * a per-op fsync would add disk-wait latency to thousands of I/O calls and
 * distort the timing we are trying to observe.
 *
 * Gated on `submersion.log` already existing: Flutter's `LogFileService` creates
 * and writes it only while debug mode is enabled, so this appends exactly when
 * the user has opted into logging and never creates a stray log otherwise.
 */
object NativeTrace {
    // getApplicationSupportDirectory() maps to context.filesDir on Android, and
    // the Flutter log lives at <support>/logs/submersion.log.
    private const val RELATIVE_PATH = "logs/submersion.log"

    // LogEntry.toLogLine uses an ISO-8601 local timestamp truncated to millis.
    private val timestampFormat =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)

    @Volatile
    private var logFile: File? = null

    fun init(context: Context) {
        logFile = File(context.filesDir, RELATIVE_PATH)
    }

    /**
     * Append one structured line synchronously, matching `LogEntry.toLogLine`
     * (`[ts] [SER] [LEVEL] message`) so the debug log viewer parses it inline.
     * A no-op unless debug mode has created the log file.
     */
    @Synchronized
    fun write(level: String, message: String) {
        val file = logFile ?: return
        if (!file.exists()) return
        val line = "[${timestampFormat.format(Date())}] [SER] [$level] $message\n"
        try {
            FileOutputStream(file, true).use { out ->
                out.write(line.toByteArray(Charsets.UTF_8))
            }
        } catch (_: Throwable) {
            // Tracing must never affect the download.
        }
    }

    fun d(message: String) = write("DEBUG", message)

    fun w(message: String) = write("WARN", message)

    fun e(message: String) = write("ERROR", message)
}
