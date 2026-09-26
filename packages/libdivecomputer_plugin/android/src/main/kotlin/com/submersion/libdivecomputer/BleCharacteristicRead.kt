package com.submersion.libdivecomputer

import java.util.UUID

// Pure helpers for libdivecomputer's BLE characteristic read ioctl (issue
// #422). The Cressi Goa backend reads its serial, model and firmware from
// three characteristics outside the serial-over-GATT stream, because its BLE
// protocol has no version command. libdc_jni.cpp decodes the request and
// calls BleIoStream.readCharacteristic with the UUID string.
object BleCharacteristicRead {
    // Cressi's UART-like service. Its UUIDs resemble Nordic UART but end in
    // ...e50e24dc10b8, and 6e400003 is a read-only version field here, not
    // the notify line.
    val CRESSI_SERVICE_UUIDS: Set<UUID> = setOf(
        UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dc10b8"),
    )

    private const val MAX_READ_TIMEOUT_MS = 10_000L

    fun parseUuid(value: String): UUID? =
        try {
            UUID.fromString(value)
        } catch (e: IllegalArgumentException) {
            null
        }

    fun readTimeoutMs(streamTimeoutMs: Int): Long =
        if (streamTimeoutMs < 0) MAX_READ_TIMEOUT_MS
        else minOf(streamTimeoutMs.toLong(), MAX_READ_TIMEOUT_MS)
}
