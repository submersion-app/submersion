package app.submersion

import org.junit.Assert.assertArrayEquals
import org.junit.Before
import org.junit.Test

/**
 * The Type 4 NDEF tag a phone presents while the buddy card swap screen is
 * open (issue #3728): select the NDEF application, read the capability
 * container, then read the NDEF file in chunks.
 */
class CardEmulationApduTest {
    private lateinit var apdu: CardEmulationApdu

    private val ok = bytes(0x90, 0x00)
    private val notFound = bytes(0x6A, 0x82)
    private val selectApp = bytes(
        0x00, 0xA4, 0x04, 0x00, 0x07, 0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01, 0x00,
    )
    private val selectCc = bytes(0x00, 0xA4, 0x00, 0x0C, 0x02, 0xE1, 0x03)
    private val selectNdef = bytes(0x00, 0xA4, 0x00, 0x0C, 0x02, 0xE1, 0x04)

    private fun bytes(vararg values: Int) = ByteArray(values.size) { values[it].toByte() }

    private fun readBinary(offset: Int, length: Int) =
        bytes(0x00, 0xB0, offset shr 8, offset and 0xFF, length)

    @Before
    fun setUp() {
        apdu = CardEmulationApdu()
    }

    @Test
    fun selectAidThenCcThenReadBinaryReturnsTheCapabilityContainer() {
        apdu.message = bytes(0xD1, 0x01, 0x01, 0x55, 0x04)
        assertArrayEquals(ok, apdu.process(selectApp))
        assertArrayEquals(ok, apdu.process(selectCc))
        val cc = apdu.process(readBinary(0, 15))
        assertArrayEquals(
            bytes(
                0x00, 0x0F, 0x20, 0x00, 0x3B, 0x00, 0x34,
                0x04, 0x06, 0xE1, 0x04, 0x7F, 0xFF, 0x00, 0xFF,
            ) + ok,
            cc,
        )
    }

    @Test
    fun selectNdefThenReadBinaryReturnsTheLengthPrefixedMessageInSlices() {
        val message = bytes(0xD1, 0x01, 0x03, 0x55, 0x04, 0x61, 0x62)
        apdu.message = message
        apdu.process(selectApp)
        assertArrayEquals(ok, apdu.process(selectNdef))
        assertArrayEquals(bytes(0x00, 0x07) + ok, apdu.process(readBinary(0, 2)))
        assertArrayEquals(
            bytes(0xD1, 0x01, 0x03) + ok,
            apdu.process(readBinary(2, 3)),
        )
        assertArrayEquals(
            bytes(0x55, 0x04, 0x61, 0x62) + ok,
            apdu.process(readBinary(5, 10)),
        )
    }

    @Test
    fun anUnknownFileIsNotFound() {
        apdu.message = bytes(0xD1)
        apdu.process(selectApp)
        assertArrayEquals(notFound, apdu.process(bytes(0x00, 0xA4, 0x00, 0x0C, 0x02, 0xE1, 0x05)))
    }

    @Test
    fun anUnknownInstructionIsNotSupported() {
        assertArrayEquals(bytes(0x6D, 0x00), apdu.process(bytes(0x00, 0xCA, 0x00, 0x00, 0x00)))
    }

    @Test
    fun withNoMessageTheApplicationIsNotThere() {
        apdu.message = null
        assertArrayEquals(notFound, apdu.process(selectApp))
    }

    @Test
    fun readingBeforeSelectingAFileIsRefused() {
        apdu.message = bytes(0xD1)
        apdu.process(selectApp)
        assertArrayEquals(notFound, apdu.process(readBinary(0, 2)))
    }

    @Test
    fun readingFromTheEndOfTheFileIsAWrongOffset() {
        apdu.message = bytes(0xD1, 0x01)
        apdu.process(selectApp)
        apdu.process(selectNdef)
        // The NDEF file is 2 length bytes plus 2 message bytes.
        assertArrayEquals(bytes(0x6B, 0x00), apdu.process(readBinary(4, 2)))
        assertArrayEquals(bytes(0x6B, 0x00), apdu.process(readBinary(9, 2)))
    }

    @Test
    fun pausingStopsAnsweringUntilResumed() {
        apdu.message = bytes(0xD1)
        apdu.paused = true
        assertArrayEquals(notFound, apdu.process(selectApp))
        apdu.paused = false
        assertArrayEquals(ok, apdu.process(selectApp))
    }

    @Test
    fun aReaderAlreadyInsideTheTagGetsNothingOncePaused() {
        apdu.message = bytes(0xD1, 0x01)
        apdu.process(selectApp)
        apdu.process(selectNdef)
        apdu.paused = true
        assertArrayEquals(notFound, apdu.process(readBinary(0, 2)))
        assertArrayEquals(notFound, apdu.process(selectCc))
    }
}
