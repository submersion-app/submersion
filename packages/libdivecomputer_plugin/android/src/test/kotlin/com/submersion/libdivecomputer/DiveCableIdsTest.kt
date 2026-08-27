package com.submersion.libdivecomputer

import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
import com.hoho.android.usbserial.driver.FtdiSerialDriver
import com.hoho.android.usbserial.driver.ProlificSerialDriver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Dive-computer download cables use USB identifiers that no default probe
 * table lists, because the vendors reprogrammed stock bridge chips with their
 * own product IDs. On Android there is no kernel driver to fall back on, so an
 * unlisted cable is simply invisible (issue #732).
 *
 * These are plain-data assertions rather than driver instantiations: the
 * module has JUnit but no Robolectric, so android.hardware.usb.UsbDevice
 * cannot be constructed here.
 */
class DiveCableIdsTest {

    @Test
    fun `recognises the Oceanic and Aeris FTDI cable`() {
        // The Linux kernel names this FTDI_OCEANIC_PID in
        // drivers/usb/serial/ftdi_sio_ids.h. It is the cable from issue #732.
        val cable = DiveCableIds.find(0x0403, 0xF460)
        assertNotNull("0x0403:0xF460 must be a known cable", cable)
        assertEquals(FtdiSerialDriver::class.java, cable!!.driver)
    }

    @Test
    fun `recognises the other reprogrammed FTDI cables`() {
        assertEquals(FtdiSerialDriver::class.java, DiveCableIds.find(0x0403, 0xF680)?.driver)
        assertEquals(FtdiSerialDriver::class.java, DiveCableIds.find(0x0403, 0x87D0)?.driver)
    }

    @Test
    fun `recognises the non-FTDI cables with their own chip drivers`() {
        assertEquals(ProlificSerialDriver::class.java, DiveCableIds.find(0x04B8, 0x0521)?.driver)
        assertEquals(ProlificSerialDriver::class.java, DiveCableIds.find(0x04B8, 0x0522)?.driver)
        assertEquals(CdcAcmSerialDriver::class.java, DiveCableIds.find(0xFFFF, 0x0005)?.driver)
    }

    @Test
    fun `does not claim unrelated devices`() {
        assertNull("an unknown device is not a dive cable", DiveCableIds.find(0x1234, 0x5678))
        // The product ID alone must not be enough to match.
        assertNull("the vendor ID is part of the match", DiveCableIds.find(0x1234, 0xF460))
    }

    @Test
    fun `has no duplicate entries`() {
        // Subsurface's own table lists 0x04B8:0x0521 twice and never lists
        // 0x0522, so the Zeagle cable does not work there. Guard against
        // copying that.
        val keys = DiveCableIds.cables.map { it.vendorId to it.productId }
        assertEquals("every cable appears exactly once", keys.size, keys.toSet().size)
    }

    @Test
    fun `every entry is described`() {
        // The description is what an unfamiliar reader uses to decide whether
        // an entry is still needed.
        assertTrue(DiveCableIds.cables.isNotEmpty())
        assertTrue(
            "every cable carries a description",
            DiveCableIds.cables.all { it.description.isNotBlank() }
        )
    }
}
