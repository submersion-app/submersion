package com.submersion.libdivecomputer

import com.submersion.libdivecomputer.BleCharacteristicSelector.Characteristic
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_INDICATE
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_NOTIFY
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_READ
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_WRITE
import com.submersion.libdivecomputer.BleCharacteristicSelector.PROPERTY_WRITE_NO_RESPONSE
import com.submersion.libdivecomputer.BleCharacteristicSelector.ResponseMode
import com.submersion.libdivecomputer.BleCharacteristicSelector.Selection
import com.submersion.libdivecomputer.BleCharacteristicSelector.Service
import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

// JVM port of darwin/Tests/BleCharacteristicSelectorTests. Both platforms must
// choose the same characteristics for the same GATT table, so the cases and
// their expectations are kept identical; a change to one belongs in both.
class BleCharacteristicSelectorTest {

    private companion object {
        const val R = PROPERTY_READ
        const val W = PROPERTY_WRITE
        const val WNR = PROPERTY_WRITE_NO_RESPONSE
        const val N = PROPERTY_NOTIFY
        const val I = PROPERTY_INDICATE

        const val HALCYON_SERVICE = "00000001-8c3b-4f2c-a59e-8c08224f3253"
        const val HALCYON_RX = "00000101-8c3b-4f2c-a59e-8c08224f3253"
        const val HALCYON_TX = "00000201-8c3b-4f2c-a59e-8c08224f3253"
        const val PELAGIC_WRITE = "6606ab42-89d5-4a00-a8ce-4eb5e1414ee0"
        const val PREFERRED_SERVICE = "cb3c4555-d670-4670-bc20-b61dbc851e9a"
        const val TIO_SERVICE = "0000fefb-0000-1000-8000-00805f9b34fb"
        const val TIO_DATA_RX = "00000001-0000-1000-8000-008025000000"
        const val TIO_DATA_TX = "00000002-0000-1000-8000-008025000000"
        const val TIO_CREDITS_RX = "00000003-0000-1000-8000-008025000000"
        const val TIO_CREDITS_TX = "00000004-0000-1000-8000-008025000000"
        const val VENDOR_SERVICE = "53544d54-4552-494f-5345-525631303030"
        const val VENDOR_WRITE = "53544d01-4552-494f-5345-525631303030"
        const val VENDOR_NOTIFY = "53544d02-4552-494f-5345-525631303030"
        const val UBLOX_SERVICE = "2456e1b9-26e2-8f83-e744-f34f01e9d701"
        const val UBLOX_DATA = "2456e1b9-26e2-8f83-e744-f34f01e9d703"
        const val UBLOX_CREDITS = "2456e1b9-26e2-8f83-e744-f34f01e9d704"
        const val SEAC_SERVICE = "84968ffe-d26d-478a-b953-5010bcf58bca"
        const val SEAC_DATA = "43c620c2-1b09-4951-bc1e-9c75298cddeb"
    }

    private data class Resolved(val write: UUID, val response: UUID, val serviceIndex: Int)

    private fun uuid(value: String): UUID = UUID.fromString(value)

    private fun char(id: String, vararg properties: Int) =
        Characteristic(uuid(id), properties.fold(0) { acc, p -> acc or p })

    private fun service(id: String, vararg characteristics: Characteristic) =
        Service(uuid(id), characteristics.toList())

    // Resolve a selection back to UUIDs the way BleIoStream does, by index.
    private fun resolve(services: List<Service>, selection: Selection?): Resolved? {
        selection ?: return null
        val chars = services[selection.serviceIndex].characteristics
        return Resolved(
            chars[selection.writeIndex].uuid,
            chars[selection.responseIndex].uuid,
            selection.serviceIndex
        )
    }

    // 1. Halcyon Symbios (#288): both characteristics are read+write+indicate,
    // so only the preferred UUIDs decide. Write to the device Rx (00000101),
    // listen on the device Tx (00000201), as Subsurface does.
    @Test
    fun halcyonWritesRxAndListensOnTx() {
        val services = listOf(
            service(HALCYON_SERVICE, char(HALCYON_RX, R, W, I), char(HALCYON_TX, R, W, I))
        )
        val selection = BleCharacteristicSelector.select(services)
        val result = resolve(services, selection)
        assertEquals(uuid(HALCYON_RX), result?.write)
        assertEquals(uuid(HALCYON_TX), result?.response)
        assertEquals(ResponseMode.NOTIFY, selection?.responseMode)
    }

    // 2. A write-only and a notify-only characteristic stay split (i300C).
    @Test
    fun splitWriteAndNotifyStaySplit() {
        val write = "0000fefb-0000-1000-8000-00805f9b34fb"
        val notify = "0000fefc-0000-1000-8000-00805f9b34fb"
        val services = listOf(
            service("0000fef5-0000-1000-8000-00805f9b34fb", char(write, W, WNR), char(notify, N))
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(uuid(write), result?.write)
        assertEquals(uuid(notify), result?.response)
    }

    // 3. One writable, notifiable characteristic serves both roles.
    @Test
    fun combinedCharacteristicServesBothRoles() {
        val combined = "0000ffe1-0000-1000-8000-00805f9b34fb"
        val services = listOf(service("0000ffe0-0000-1000-8000-00805f9b34fb", char(combined, WNR, N)))
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(uuid(combined), result?.write)
        assertEquals(uuid(combined), result?.response)
    }

    // 4. A service with no notify/indicate characteristic is not selectable.
    @Test
    fun serviceWithoutNotifyIsNotSelected() {
        val services = listOf(
            service("0000180a-0000-1000-8000-00805f9b34fb", char("00002a29-0000-1000-8000-00805f9b34fb", R))
        )
        assertNull(BleCharacteristicSelector.select(services))
    }

    // 5. Empty input yields no selection.
    @Test
    fun emptyInputYieldsNothing() {
        assertNull(BleCharacteristicSelector.select(emptyList()))
    }

    // 6. A preferred service (+1000) beats a higher raw score, and the preferred
    // write UUID is chosen within it.
    @Test
    fun preferredServiceWinsOverHigherRawScore() {
        val services = listOf(
            service(
                "0000aaaa-0000-1000-8000-00805f9b34fb",
                char("0000aab1-0000-1000-8000-00805f9b34fb", WNR),
                char("0000aab2-0000-1000-8000-00805f9b34fb", N)
            ),
            service(
                PREFERRED_SERVICE,
                char(PELAGIC_WRITE, W),
                char("0000bbb2-0000-1000-8000-00805f9b34fb", I)
            )
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(1, result?.serviceIndex)
        assertEquals(uuid(PELAGIC_WRITE), result?.write)
    }

    // 7. Two instances of one service UUID: the higher-scoring second instance
    // is identified by index, not by UUID.
    @Test
    fun duplicateServiceUuidResolvedByIndex() {
        val dup = "0000dddd-0000-1000-8000-00805f9b34fb"
        val secondWrite = "0000dd03-0000-1000-8000-00805f9b34fb"
        val secondNotify = "0000dd04-0000-1000-8000-00805f9b34fb"
        val services = listOf(
            service(
                dup,
                char("0000dd01-0000-1000-8000-00805f9b34fb", W),
                char("0000dd02-0000-1000-8000-00805f9b34fb", I)
            ),
            service(dup, char(secondWrite, W), char(secondNotify, N))
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(1, result?.serviceIndex)
        assertEquals(uuid(secondWrite), result?.write)
        assertEquals(uuid(secondNotify), result?.response)
    }

    // 8. A later, higher-scoring candidate replaces an earlier one.
    @Test
    fun laterHigherScoringCandidateWins() {
        val notifyHigh = "0000ee03-0000-1000-8000-00805f9b34fb"
        val writeHigh = "0000ee04-0000-1000-8000-00805f9b34fb"
        val services = listOf(
            service(
                "0000ee00-0000-1000-8000-00805f9b34fb",
                char("0000ee01-0000-1000-8000-00805f9b34fb", W),
                char("0000ee02-0000-1000-8000-00805f9b34fb", I),
                char(notifyHigh, N),
                char(writeHigh, WNR)
            )
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(uuid(writeHigh), result?.write)
        assertEquals(uuid(notifyHigh), result?.response)
    }

    // 9. OSTC4 (#923): the Terminal I/O service beats the Stollmann vendor
    // service, and the credit characteristics are located.
    @Test
    fun ostc4SelectsTerminalIoWithCredits() {
        val services = listOf(
            service(
                TIO_SERVICE,
                char(TIO_DATA_RX, WNR),
                char(TIO_DATA_TX, N),
                char(TIO_CREDITS_RX, W),
                char(TIO_CREDITS_TX, I)
            ),
            service(VENDOR_SERVICE, char(VENDOR_WRITE, WNR), char(VENDOR_NOTIFY, N))
        )
        val selection = BleCharacteristicSelector.select(services)
        val result = resolve(services, selection)
        assertEquals(0, result?.serviceIndex)
        assertEquals(uuid(TIO_DATA_RX), result?.write)
        assertEquals(uuid(TIO_DATA_TX), result?.response)
        assertEquals(2, selection?.terminalIoCredits?.writeIndex)
        assertEquals(3, selection?.terminalIoCredits?.notifyIndex)
        assertEquals(true, selection?.terminalIoCredits?.required)
    }

    // 10. Reversed discovery order still selects Terminal I/O.
    @Test
    fun ostc4ReorderedStillSelectsTerminalIo() {
        val services = listOf(
            service(VENDOR_SERVICE, char(VENDOR_WRITE, WNR), char(VENDOR_NOTIFY, N)),
            service(
                TIO_SERVICE,
                char(TIO_DATA_RX, WNR),
                char(TIO_DATA_TX, N),
                char(TIO_CREDITS_RX, W),
                char(TIO_CREDITS_TX, I)
            )
        )
        val selection = BleCharacteristicSelector.select(services)
        assertEquals(1, selection?.serviceIndex)
        assertNotNull(selection?.terminalIoCredits)
    }

    // 11. No credit characteristics, no handshake.
    @Test
    fun nonTerminalIoDeviceGetsNoHandshake() {
        val services = listOf(
            service("0000ffe0-0000-1000-8000-00805f9b34fb", char("0000ffe1-0000-1000-8000-00805f9b34fb", WNR, N))
        )
        assertNull(BleCharacteristicSelector.select(services)?.terminalIoCredits)
    }

    // 12. A partial Telit layout does not trigger the handshake.
    @Test
    fun partialTerminalIoLayoutGetsNoHandshake() {
        val services = listOf(service(TIO_SERVICE, char(TIO_DATA_RX, WNR), char(TIO_DATA_TX, N)))
        assertNull(BleCharacteristicSelector.select(services)?.terminalIoCredits)
    }

    // 13. u-blox: data both ways on one characteristic, credits on another,
    // and credits optional.
    @Test
    fun ubloxUsesFifoWithOptionalCredits() {
        val services = listOf(
            service(UBLOX_SERVICE, char(UBLOX_DATA, WNR, N), char(UBLOX_CREDITS, W, I))
        )
        val selection = BleCharacteristicSelector.select(services)
        val result = resolve(services, selection)
        assertEquals(uuid(UBLOX_DATA), result?.write)
        assertEquals(uuid(UBLOX_DATA), result?.response)
        assertEquals(1, selection?.terminalIoCredits?.writeIndex)
        assertEquals(1, selection?.terminalIoCredits?.notifyIndex)
        assertEquals(false, selection?.terminalIoCredits?.required)
    }

    // 14. The u-blox credits characteristic never takes the data role, even
    // with the top raw score on both sides.
    @Test
    fun ubloxCreditsNeverTakeTheDataRole() {
        val services = listOf(
            service(UBLOX_SERVICE, char(UBLOX_CREDITS, WNR, N), char(UBLOX_DATA, W, I))
        )
        val result = resolve(services, BleCharacteristicSelector.select(services))
        assertEquals(uuid(UBLOX_DATA), result?.write)
        assertEquals(uuid(UBLOX_DATA), result?.response)
    }

    // 15. The Seac Tablet (issue #1454) as Android enumerates it, with Generic
    // Access (Device Name can be read+write) and Device Information first. Only
    // the Seac service is chosen, in read mode, one characteristic both ways.
    @Test
    fun seacTabletSelectsReadMode() {
        val services = listOf(
            service("00001800-0000-1000-8000-00805f9b34fb", char("00002a00-0000-1000-8000-00805f9b34fb", R, W)),
            service("0000180a-0000-1000-8000-00805f9b34fb", char("00002a29-0000-1000-8000-00805f9b34fb", R)),
            service(SEAC_SERVICE, char(SEAC_DATA, R, W))
        )
        val selection = BleCharacteristicSelector.select(services)
        val result = resolve(services, selection)
        assertEquals(ResponseMode.READ, selection?.responseMode)
        assertEquals(2, result?.serviceIndex)
        assertEquals(uuid(SEAC_DATA), result?.write)
        assertEquals(uuid(SEAC_DATA), result?.response)
        assertNull(selection?.terminalIoCredits)
    }

    // 16. The allowlist is the whole read tier.
    @Test
    fun readOnlyShapeOutsideTheAllowlistIsNotSelected() {
        assertNull(BleCharacteristicSelector.select(listOf(
            service("0000ffe0-0000-1000-8000-00805f9b34fb", char(SEAC_DATA, R, W))
        )))
        assertNull(BleCharacteristicSelector.select(listOf(
            service(SEAC_SERVICE, char("0000ffe1-0000-1000-8000-00805f9b34fb", R, W))
        )))
    }

    // 17. Strict fallback: a write/notify service wins in either order.
    @Test
    fun notifyServiceBeatsTheReadPollService() {
        val notifyService = service("0000ffe0-0000-1000-8000-00805f9b34fb", char("0000ffe1-0000-1000-8000-00805f9b34fb", WNR, N))
        val seac = service(SEAC_SERVICE, char(SEAC_DATA, R, W))

        val seacFirst = BleCharacteristicSelector.select(listOf(seac, notifyService))
        assertEquals(ResponseMode.NOTIFY, seacFirst?.responseMode)
        assertEquals(1, seacFirst?.serviceIndex)

        val seacLast = BleCharacteristicSelector.select(listOf(notifyService, seac))
        assertEquals(ResponseMode.NOTIFY, seacLast?.responseMode)
        assertEquals(0, seacLast?.serviceIndex)
    }

    // 18. READ plus a write property are both required; write-without-response
    // alone is enough for the write side.
    @Test
    fun allowlistedCharacteristicNeedsReadAndWrite() {
        fun selectSeac(vararg properties: Int) =
            BleCharacteristicSelector.select(listOf(service(SEAC_SERVICE, char(SEAC_DATA, *properties))))
        assertNull(selectSeac(W))
        assertNull(selectSeac(R))
        assertEquals(ResponseMode.READ, selectSeac(R, WNR)?.responseMode)
    }

    // 19. Firmware that adds notify gets the ordinary notify path.
    @Test
    fun seacCharacteristicThatNotifiesUsesTheNotifyPath() {
        val services = listOf(service(SEAC_SERVICE, char(SEAC_DATA, R, W, N)))
        assertEquals(ResponseMode.NOTIFY, BleCharacteristicSelector.select(services)?.responseMode)
    }
}
