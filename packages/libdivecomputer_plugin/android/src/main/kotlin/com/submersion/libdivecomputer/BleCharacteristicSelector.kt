package com.submersion.libdivecomputer

import java.util.UUID

// Picks the characteristics a BLE dive computer is talked to through.
//
// Pure Kotlin (no Android imports) so it runs as a plain JVM test:
// BleIoStream adapts its live BluetoothGattService objects into the value
// types below and resolves the returned indices back to them. Mirrors
// darwin's BleCharacteristicSelector.swift; the two are pinned to the same
// answers by BleCharacteristicSelectorTest and its Swift twin.
//
// Scoring: write and notify candidates are scored independently so devices
// that split commands and replies across two characteristics pick the right
// pair instead of collapsing onto one. Higher raw scores prefer
// write-without-response and notify over indicate. A preferred-UUID match adds
// +1000 so an explicit per-device mapping always wins over the heuristic and
// over discovery-order tie-breaking.
object BleCharacteristicSelector {

    // Bit values of BluetoothGattCharacteristic.PROPERTY_*, repeated here so
    // this file needs no Android classes.
    const val PROPERTY_READ = 0x02
    const val PROPERTY_WRITE_NO_RESPONSE = 0x04
    const val PROPERTY_WRITE = 0x08
    const val PROPERTY_NOTIFY = 0x10
    const val PROPERTY_INDICATE = 0x20

    data class Characteristic(val uuid: UUID, val properties: Int)

    data class Service(val uuid: UUID, val characteristics: List<Characteristic>)

    // How the selected service delivers the computer's replies.
    enum class ResponseMode {
        // Subscribe to notifications or indications. Every computer but one.
        NOTIFY,
        // Read the characteristic on demand: it can neither notify nor
        // indicate (the Seac Tablet, issue #1454). See ReadPollPolicy.
        READ
    }

    // The credit characteristics of the selected service, as positions in
    // the same input the write/response indices address. `required` is true
    // for Telit, whose bridge carries nothing until credits are granted, and
    // false for u-blox, where a rejected grant falls back to running without
    // flow control (the OSTC nano downloads with no handshake, #280/#394).
    data class TerminalIoCredits(val writeIndex: Int, val notifyIndex: Int, val required: Boolean)

    // Indices rather than UUIDs, so the caller resolves the exact live
    // characteristics even when a peripheral repeats a service UUID.
    data class Selection(
        val serviceIndex: Int,
        val writeIndex: Int,
        val responseIndex: Int,
        val responseMode: ResponseMode,
        val score: Int,
        val terminalIoCredits: TerminalIoCredits?
    )

    // Telit/Stollmann Terminal I/O (TIO), service 0xFEFB.
    //
    // Heinrichs Weikamp computers built on the Telit (formerly Stollmann)
    // BlueMod+SR module (the OSTC 2/3/4/Sport/cR/Plus family) expose their
    // serial bridge behind this service with credit-based flow control (Telit
    // "TIO Implementation Guide" r04). The module carries no UART data until
    // the client subscribes to UART Credits TX and grants initial credits on
    // UART Credits RX (issue #923, OSTC4). Subsurface's qt-ble.cpp handles the
    // same two Heinrichs Weikamp module families: Telit (credits mandatory)
    // and the u-blox serial service (credits optional).
    val TIO_SERVICE_UUID: UUID = UUID.fromString("0000fefb-0000-1000-8000-00805f9b34fb")
    val TIO_DATA_RX_UUID: UUID = UUID.fromString("00000001-0000-1000-8000-008025000000")
    val TIO_DATA_TX_UUID: UUID = UUID.fromString("00000002-0000-1000-8000-008025000000")
    val TIO_CREDITS_RX_UUID: UUID = UUID.fromString("00000003-0000-1000-8000-008025000000")
    val TIO_CREDITS_TX_UUID: UUID = UUID.fromString("00000004-0000-1000-8000-008025000000")

    // u-blox serial service: one characteristic carries data in both
    // directions and one carries credits in both directions.
    val UBLOX_SERVICE_UUID: UUID = UUID.fromString("2456e1b9-26e2-8f83-e744-f34f01e9d701")
    val UBLOX_DATA_UUID: UUID = UUID.fromString("2456e1b9-26e2-8f83-e744-f34f01e9d703")
    val UBLOX_CREDITS_UUID: UUID = UUID.fromString("2456e1b9-26e2-8f83-e744-f34f01e9d704")

    private val PREFERRED_SERVICE_UUIDS = setOf(
        UUID.fromString("cb3c4555-d670-4670-bc20-b61dbc851e9a"),
        // Biased so the serial bridge always beats the Stollmann vendor
        // service the same devices also advertise, which can tie on raw score.
        TIO_SERVICE_UUID,
        UBLOX_SERVICE_UUID
    )
    private val PREFERRED_WRITE_UUIDS = setOf(
        UUID.fromString("6606ab42-89d5-4a00-a8ce-4eb5e1414ee0"),
        // Telit UART Data RX. Raw scoring already prefers it over UART Credits
        // RX, but commands written to the credits characteristic would be
        // silently swallowed, so the pair is pinned rather than left to the
        // heuristic.
        TIO_DATA_RX_UUID,
        // u-blox FIFO, pinned over the credits characteristic for the same reason.
        UBLOX_DATA_UUID,
        // Halcyon Symbios: the app writes commands to the device's Rx endpoint
        // (00000101). Both Symbios characteristics advertise
        // read+write+indicate and tie on raw score, so a preferred UUID is
        // required to tell them apart. The Tx/Rx names are device-centric:
        // Subsurface's qt-ble.cpp writes commands to 00000101 ("Rx") and reads
        // replies from 00000201 ("Tx"). PR #356 mapped these backwards and the
        // device never answered (issue #288).
        UUID.fromString("00000101-8c3b-4f2c-a59e-8c08224f3253")
    )
    private val PREFERRED_NOTIFY_UUIDS = setOf(
        UUID.fromString("a60b8e5c-b267-44d7-9764-837caf96489e"),
        // Telit UART Data TX (see PREFERRED_WRITE_UUIDS).
        TIO_DATA_TX_UUID,
        // u-blox FIFO carries data in both directions, so it is the notify
        // candidate as well as the write one.
        UBLOX_DATA_UUID,
        // Halcyon Symbios: the device transmits replies on its Tx endpoint
        // (00000201) via indications; the app writes commands on 00000101 (see
        // PREFERRED_WRITE_UUIDS and issue #288).
        UUID.fromString("00000201-8c3b-4f2c-a59e-8c08224f3253")
    )

    // Read-poll services (issue #1454). A few computers expose a data
    // characteristic that can be read and written but cannot notify or
    // indicate, so every reply has to be fetched with a GATT read.
    // libdivecomputer commit 415778c documents the Seac Tablet's layout;
    // Subsurface's qt-ble.cpp reads it the same way (e8e0cea769).
    //
    // Deliberately an allowlist rather than "any read+write characteristic":
    // Generic Access's Device Name is read+write on some peripherals, and a
    // generic tier would connect to it on a computer whose real serial service
    // was simply not recognised, then time out with nothing to explain why.
    val SEAC_SERVICE_UUID: UUID = UUID.fromString("84968ffe-d26d-478a-b953-5010bcf58bca")
    // Rx/Tx in one characteristic: commands are written to it, replies read from it.
    val SEAC_DATA_UUID: UUID = UUID.fromString("43c620c2-1b09-4951-bc1e-9c75298cddeb")

    // Read-poll service UUID to its data characteristic UUID.
    val READ_POLL_SERVICES: Map<UUID, UUID> = mapOf(SEAC_SERVICE_UUID to SEAC_DATA_UUID)

    // Choose the characteristics to talk through, or null if nothing usable.
    // The write/notify pass runs first and is unchanged; the read-poll tier is
    // consulted only when it finds nothing, so no device that already works
    // can be moved onto the read path.
    fun select(services: List<Service>): Selection? =
        selectNotify(services) ?: selectReadPoll(services)

    // The first allowlisted read-poll service whose data characteristic can
    // be both read and written, or null.
    private fun selectReadPoll(services: List<Service>): Selection? {
        for ((serviceIndex, service) in services.withIndex()) {
            val dataUuid = READ_POLL_SERVICES[service.uuid] ?: continue
            val index = service.characteristics.indexOfFirst { it.uuid == dataUuid }
            if (index < 0) continue
            val props = service.characteristics[index].properties
            if (props and PROPERTY_READ == 0) continue
            if (props and (PROPERTY_WRITE or PROPERTY_WRITE_NO_RESPONSE) == 0) continue
            return Selection(
                serviceIndex = serviceIndex,
                writeIndex = index,
                responseIndex = index,
                responseMode = ResponseMode.READ,
                score = 0,
                terminalIoCredits = null
            )
        }
        return null
    }

    private fun writeScore(characteristic: Characteristic): Int? {
        val props = characteristic.properties
        if (props and (PROPERTY_WRITE or PROPERTY_WRITE_NO_RESPONSE) == 0) return null
        var score = 0
        if (props and PROPERTY_WRITE_NO_RESPONSE != 0) score += 4
        if (props and PROPERTY_WRITE != 0) score += 2
        if (PREFERRED_WRITE_UUIDS.contains(characteristic.uuid)) score += 1000
        return score
    }

    private fun notifyScore(characteristic: Characteristic): Int? {
        val props = characteristic.properties
        if (props and (PROPERTY_NOTIFY or PROPERTY_INDICATE) == 0) return null
        var score = 0
        if (props and PROPERTY_NOTIFY != 0) score += 4
        if (props and PROPERTY_INDICATE != 0) score += 2
        if (PREFERRED_NOTIFY_UUIDS.contains(characteristic.uuid)) score += 1000
        return score
    }

    // Best write/notify pair across all services. Ties keep the earliest
    // candidate in the order the caller supplies (BLE discovery order).
    private fun selectNotify(services: List<Service>): Selection? {
        var best: Selection? = null
        for ((serviceIndex, service) in services.withIndex()) {
            var bestWrite = -1
            var bestWriteScore = -1
            var bestNotify = -1
            var bestNotifyScore = -1
            for ((index, characteristic) in service.characteristics.withIndex()) {
                val ws = writeScore(characteristic)
                if (ws != null && ws > bestWriteScore) {
                    bestWrite = index
                    bestWriteScore = ws
                }
                val ns = notifyScore(characteristic)
                if (ns != null && ns > bestNotifyScore) {
                    bestNotify = index
                    bestNotifyScore = ns
                }
            }
            if (bestWrite < 0 || bestNotify < 0) continue

            var score = bestWriteScore + bestNotifyScore
            if (PREFERRED_SERVICE_UUIDS.contains(service.uuid)) score += 1000
            if (best != null && best.score >= score) continue
            best = Selection(
                serviceIndex = serviceIndex,
                writeIndex = bestWrite,
                responseIndex = bestNotify,
                responseMode = ResponseMode.NOTIFY,
                score = score,
                terminalIoCredits = terminalIoCredits(service)
            )
        }
        return best
    }

    // The credit characteristics of a service, or null unless a complete known
    // layout is present, so every other device keeps its plain write/notify
    // path. Telit needs all four UART characteristics; u-blox needs its data
    // and credits pair.
    private fun terminalIoCredits(service: Service): TerminalIoCredits? {
        fun index(uuid: UUID): Int = service.characteristics.indexOfFirst { it.uuid == uuid }

        val creditsRx = index(TIO_CREDITS_RX_UUID)
        val creditsTx = index(TIO_CREDITS_TX_UUID)
        if (index(TIO_DATA_RX_UUID) >= 0 && index(TIO_DATA_TX_UUID) >= 0 &&
            creditsRx >= 0 && creditsTx >= 0
        ) {
            return TerminalIoCredits(creditsRx, creditsTx, required = true)
        }
        val ubloxCredits = index(UBLOX_CREDITS_UUID)
        if (index(UBLOX_DATA_UUID) >= 0 && ubloxCredits >= 0) {
            return TerminalIoCredits(ubloxCredits, ubloxCredits, required = false)
        }
        return null
    }
}
