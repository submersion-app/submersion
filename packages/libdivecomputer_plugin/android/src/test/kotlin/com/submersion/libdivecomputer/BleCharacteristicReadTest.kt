package com.submersion.libdivecomputer

import java.util.UUID
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BleCharacteristicReadTest {
    @Test
    fun parsesTheUuidStringTheJniLayerPasses() {
        assertEquals(
            UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dc10b8"),
            BleCharacteristicRead.parseUuid("6e400003-b5a3-f393-e0a9-e50e24dc10b8"),
        )
    }

    @Test
    fun rejectsAMalformedUuid() {
        assertNull(BleCharacteristicRead.parseUuid("not-a-uuid"))
        assertNull(BleCharacteristicRead.parseUuid(""))
    }

    @Test
    fun cressiServiceIsPreferred() {
        assertTrue(
            UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dc10b8") in
                BleCharacteristicRead.CRESSI_SERVICE_UUIDS
        )
    }

    // Every wait on the download thread must be bounded: libdivecomputer's
    // negative "no timeout" would otherwise block forever on a lost callback.
    @Test
    fun readWaitIsBounded() {
        assertEquals(10_000L, BleCharacteristicRead.readTimeoutMs(-1))
        assertEquals(10_000L, BleCharacteristicRead.readTimeoutMs(60_000))
        assertEquals(5_000L, BleCharacteristicRead.readTimeoutMs(5_000))
    }

    // A refused read used to be logged only at DEBUG, so a default debug log
    // carried libdivecomputer's bare "Failed to read the characteristic" and
    // nothing about why (issue #422). The warning names the ATT status.
    @Test
    fun describesAReadTheComputerRefused() {
        assertEquals(
            "readCharacteristic: 6e400003-b5a3-f393-e0a9-e50e24dc10b8 failed " +
                "(status=5, insufficient authentication; the stored pairing " +
                "keys are stale or the computer demanded encryption)",
            BleCharacteristicRead.describeFailedRead(
                "6e400003-b5a3-f393-e0a9-e50e24dc10b8", 5),
        )
    }

    // A link that drops mid-read wakes the waiter with no value; the warning
    // must say so in the connection status space, not the ATT one.
    @Test
    fun describesALinkLostDuringTheRead() {
        assertEquals(
            "readCharacteristic: 6e400003-b5a3-f393-e0a9-e50e24dc10b8 failed: " +
                "the link dropped before the reply arrived (status=19, " +
                "the computer closed the connection)",
            BleCharacteristicRead.describeDisconnectedRead(
                "6e400003-b5a3-f393-e0a9-e50e24dc10b8", 19),
        )
    }

    @Test
    fun describesASuccessfulReadWithNoValue() {
        assertEquals(
            "readCharacteristic: 6e400003-b5a3-f393-e0a9-e50e24dc10b8 failed: " +
                "the read succeeded but carried no value",
            BleCharacteristicRead.describeEmptyRead(
                "6e400003-b5a3-f393-e0a9-e50e24dc10b8"),
        )
    }

    // A timed-out read cannot be cancelled on Android, so its late callback
    // could satisfy a later read of the same characteristic; refuse those.
    @Test
    fun timedOutCharacteristicIsQuarantined() {
        val quarantine = CharacteristicReadQuarantine()
        val version = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dc10b8")
        val other = UUID.fromString("6e400004-b5a3-f393-e0a9-e50e24dc10b8")
        assertTrue(quarantine.mayRead(version))
        quarantine.timedOut(version)
        assertEquals(false, quarantine.mayRead(version))
        assertTrue(quarantine.mayRead(other))
    }
}
