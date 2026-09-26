package com.submersion.libdivecomputer

/**
 * Wire name of the clock sync outcome reported by `libdc_download_run`
 * (issue #1216): the JVM twin of `libdc_clock_sync_status_name` in the C
 * wrapper, which every other platform calls directly. Kept in Kotlin because
 * the `:dc` process and the JVM unit tests both need it without a native
 * call. Pinned to `libdc_clock_sync_status_t` by [LibdcDownloadInfoTest].
 */
internal fun libdcClockSyncStatusName(status: Int): String = when (status) {
    0 -> "not_requested"
    1 -> "synced"
    2 -> "unsupported"
    3 -> "failed"
    else -> "unknown"
}

/**
 * Formats a device serial or firmware number the way the other bindings do
 * (decimal, unsigned), or null when libdivecomputer reported none. The value
 * crosses JNI as a signed Int, so a high serial arrives negative.
 */
internal fun libdcUnsignedOrNull(value: Int): String? =
    if (value == 0) null else (value.toLong() and 0xFFFFFFFFL).toString()

// Decodes nativeDownloadSessionReportedDevice's [product, model] pair.
internal data class ReportedDevice(val product: String, val model: Long)

internal fun reportedDeviceOrNull(raw: Array<String>?): ReportedDevice? {
    if (raw == null || raw.size != 2 || raw[0].isEmpty()) return null
    val model = raw[1].toLongOrNull() ?: return null
    return ReportedDevice(raw[0], model)
}
