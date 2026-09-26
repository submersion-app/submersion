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
}
