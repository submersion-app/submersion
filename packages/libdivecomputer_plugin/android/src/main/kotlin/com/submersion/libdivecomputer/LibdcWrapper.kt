package com.submersion.libdivecomputer

// Kotlin wrapper around libdivecomputer JNI functions.
// Each method delegates to a native C++ function via JNI.
object LibdcWrapper {
    init {
        System.loadLibrary("libdc_jni")
    }

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
        ioHandler: BleIoHandler,
        downloadCallback: DownloadCallback,
        errorBuf: ByteArray
    ): Int

    // Dive data access (reads fields from a native dive pointer)
    external fun nativeGetDiveYear(divePtr: Long): Int
    external fun nativeGetDiveMonth(divePtr: Long): Int
    external fun nativeGetDiveDay(divePtr: Long): Int
    external fun nativeGetDiveHour(divePtr: Long): Int
    external fun nativeGetDiveMinute(divePtr: Long): Int
    external fun nativeGetDiveSecond(divePtr: Long): Int
    external fun nativeGetDiveMaxDepth(divePtr: Long): Double
    external fun nativeGetDiveAvgDepth(divePtr: Long): Double
    external fun nativeGetDiveDuration(divePtr: Long): Int
    external fun nativeGetDiveMinTemp(divePtr: Long): Double
    external fun nativeGetDiveMaxTemp(divePtr: Long): Double
    external fun nativeGetDiveMode(divePtr: Long): Int
    external fun nativeGetDiveFingerprint(divePtr: Long): String
    external fun nativeGetDiveSampleCount(divePtr: Long): Int
    external fun nativeGetDiveSample(divePtr: Long, index: Int): DoubleArray?
    external fun nativeGetDiveGasmixCount(divePtr: Long): Int
    external fun nativeGetDiveGasmix(divePtr: Long, index: Int): DoubleArray?
    external fun nativeGetDiveTankCount(divePtr: Long): Int
    external fun nativeGetDiveTank(divePtr: Long, index: Int): DoubleArray?
}

// Mutable data class for receiving descriptor info from JNI.
class DescriptorInfo {
    @JvmField var vendor: String = ""
    @JvmField var product: String = ""
    @JvmField var model: Int = 0
    @JvmField var transports: Int = 0
}

// Interface for BLE I/O operations called from native code.
interface BleIoHandler {
    fun read(size: Int, timeoutMs: Int): ByteArray?
    fun write(data: ByteArray, timeoutMs: Int): Int
    fun close()
}

// Interface for download event callbacks from native code.
interface DownloadCallback {
    fun onProgress(current: Int, maximum: Int)
    fun onDive(divePtr: Long)
}
