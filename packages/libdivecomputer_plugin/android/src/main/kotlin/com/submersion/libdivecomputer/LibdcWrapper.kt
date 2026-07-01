package com.submersion.libdivecomputer

// Kotlin wrapper around libdivecomputer JNI functions.
// Each method delegates to a native C++ function via JNI.
object LibdcWrapper {
    // Null if the native library loaded successfully; otherwise the load
    // failure. Captured here instead of thrown from the static initializer so
    // callers can check [loadError] and report a clear error, rather than
    // letting an UnsatisfiedLinkError surface as an uncaught ExceptionIn-
    // InitializerError on a background thread and kill the process. This is the
    // failure mode behind issue #318: a 4 KB-aligned liblibdc_jni.so fails to
    // load on Android 15+ devices that use 16 KB memory pages (e.g. Xiaomi 15T
    // Pro), crashing the app silently the instant a download starts.
    val loadError: Throwable? =
        runCatching { System.loadLibrary("libdc_jni") }.exceptionOrNull()

    // Version
    external fun nativeGetVersion(): String

    // Descriptor iterator
    external fun nativeDescriptorIteratorNew(): Long
    external fun nativeDescriptorIteratorNext(iterPtr: Long, info: DescriptorInfo): Int
    external fun nativeDescriptorIteratorFree(iterPtr: Long)

    // BLE discovery helper
    external fun nativeDescriptorMatch(
        name: String,
        transport: Int,
        info: DescriptorInfo
    ): Boolean

    // Download session
    external fun nativeDownloadSessionNew(): Long
    external fun nativeDownloadCancel(sessionPtr: Long)
    external fun nativeDownloadSessionFree(sessionPtr: Long)
    external fun nativeDownloadRun(
        sessionPtr: Long,
        vendor: String,
        product: String,
        model: Int,
        transport: Int,
        ioHandler: IoHandler,
        devName: String?,
        fingerprint: ByteArray?,
        downloadCallback: DownloadCallback,
        errorBuf: ByteArray
    ): Int

    // Debug-only: deliberately crash the current process natively (issue #318
    // process-isolation test). Only ever reached via DiveDownloadService's
    // __crash_test__ path; never in normal operation.
    external fun nativeDebugCrash()

    // Dive data access (reads fields from a native dive pointer)
    external fun nativeGetDiveYear(divePtr: Long): Int
    external fun nativeGetDiveMonth(divePtr: Long): Int
    external fun nativeGetDiveDay(divePtr: Long): Int
    external fun nativeGetDiveHour(divePtr: Long): Int
    external fun nativeGetDiveMinute(divePtr: Long): Int
    external fun nativeGetDiveSecond(divePtr: Long): Int
    external fun nativeGetDiveTimezone(divePtr: Long): Int
    external fun nativeGetDiveMaxDepth(divePtr: Long): Double
    external fun nativeGetDiveAvgDepth(divePtr: Long): Double
    external fun nativeGetDiveDuration(divePtr: Long): Int
    external fun nativeGetDiveMinTemp(divePtr: Long): Double
    external fun nativeGetDiveMaxTemp(divePtr: Long): Double
    external fun nativeGetDiveEntryLatitude(divePtr: Long): Double
    external fun nativeGetDiveEntryLongitude(divePtr: Long): Double
    external fun nativeGetDiveExitLatitude(divePtr: Long): Double
    external fun nativeGetDiveExitLongitude(divePtr: Long): Double
    external fun nativeGetDiveMode(divePtr: Long): Int
    external fun nativeGetDiveFingerprint(divePtr: Long): String
    external fun nativeGetDiveSampleCount(divePtr: Long): Int
    external fun nativeGetDiveSample(divePtr: Long, index: Int): DoubleArray?
    external fun nativeGetDiveGasmixCount(divePtr: Long): Int
    external fun nativeGetDiveGasmix(divePtr: Long, index: Int): DoubleArray?
    external fun nativeGetDiveTankCount(divePtr: Long): Int
    external fun nativeGetDiveTank(divePtr: Long, index: Int): DoubleArray?

    // Event data access
    external fun nativeGetDiveEventCount(divePtr: Long): Int
    external fun nativeGetDiveEvent(divePtr: Long, index: Int): LongArray?

    // Decompression model access
    external fun nativeGetDiveDecoModel(divePtr: Long): IntArray?

    // Raw dive data access
    external fun nativeGetDiveRawData(divePtr: Long): ByteArray?
    external fun nativeGetDiveRawFingerprint(divePtr: Long): ByteArray?
}

// Mutable data class for receiving descriptor info from JNI.
class DescriptorInfo {
    @JvmField var vendor: String = ""
    @JvmField var product: String = ""
    @JvmField var model: Int = 0
    @JvmField var transports: Int = 0
}

// Base I/O operations called from native code. The JNI bridge resolves these
// by name on whichever concrete handler is passed to nativeDownloadRun.
interface IoHandler {
    fun read(size: Int, timeoutMs: Int): ByteArray?
    fun write(data: ByteArray, timeoutMs: Int): Int
    fun purge(direction: Int)
    fun close()
}

// BLE I/O: adds PIN and access-code negotiation for encrypted peripherals.
interface BleIoHandler : IoHandler {
    fun onPinCodeRequired(address: String): String
    fun getAccessCode(address: String): ByteArray?
    fun setAccessCode(address: String, code: ByteArray)
}

// Serial I/O: adds serial line-control (baud/data/parity/stop/flow + DTR/RTS).
// The line-control methods return 0 on success and non-zero on failure; the
// JNI bridge maps that to LIBDC_STATUS_SUCCESS / LIBDC_STATUS_IO. The bridge
// wires these callbacks only when the handler implements them, so BLE handlers
// are unaffected.
interface SerialIoHandler : IoHandler {
    fun configure(
        baudRate: Int,
        dataBits: Int,
        parity: Int,
        stopBits: Int,
        flowControl: Int
    ): Int
    fun setDtr(value: Int): Int
    fun setRts(value: Int): Int
}

// Interface for download event callbacks from native code.
interface DownloadCallback {
    fun onProgress(current: Int, maximum: Int)
    fun onDive(divePtr: Long)
}
