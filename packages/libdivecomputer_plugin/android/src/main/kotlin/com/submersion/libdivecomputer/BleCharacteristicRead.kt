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

    // Warnings for a read that came back without a value. libdivecomputer
    // reports every one of them as "Failed to read the characteristic", so
    // the cause has to be logged here, at a level a default debug log keeps.
    fun describeFailedRead(uuid: String, status: Int): String =
        "readCharacteristic: $uuid failed " +
            "(status=$status, ${GattDiagnostics.describeAttStatus(status)})"

    // Pre-API 33 delivers the value on characteristic.value, which can be
    // null even on a successful read.
    fun describeEmptyRead(uuid: String): String =
        "readCharacteristic: $uuid failed: the read succeeded but carried " +
            "no value"

    fun describeDisconnectedRead(uuid: String, status: Int): String =
        "readCharacteristic: $uuid failed: the link dropped before the " +
            "reply arrived (status=$status, " +
            "${GattDiagnostics.describeConnectionStatus(status)})"
}

// Characteristics whose read timed out on this connection (issue #422).
// Android cannot cancel an outstanding readCharacteristic, so its late
// onCharacteristicRead could otherwise satisfy a later read of the same
// characteristic; those reads are refused instead. Called only from the
// libdivecomputer thread.
class CharacteristicReadQuarantine {
    private val timedOut = HashSet<UUID>()

    fun mayRead(uuid: UUID): Boolean = uuid !in timedOut

    fun timedOut(uuid: UUID) {
        timedOut.add(uuid)
    }
}
