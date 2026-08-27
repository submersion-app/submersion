package com.submersion.libdivecomputer

import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
import com.hoho.android.usbserial.driver.FtdiSerialDriver
import com.hoho.android.usbserial.driver.ProlificSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialProber

/**
 * USB identifiers of dive-computer download cables, and the bridge-chip driver
 * each one needs.
 *
 * Dive-computer vendors buy stock USB-to-serial bridge chips and reprogram
 * them with their own product IDs, so a default probe table does not recognise
 * them. On desktop platforms a kernel or vendor driver usually picks them up
 * anyway; on Android there is none, so an unlisted cable is invisible to the
 * app no matter what the user does (issue #732).
 *
 * Registering an identifier here is additive: it can only make a device
 * recognised that previously was not.
 */
object DiveCableIds {

    data class Cable(
        val vendorId: Int,
        val productId: Int,
        val driver: Class<out UsbSerialDriver>,
        val description: String,
    )

    val cables: List<Cable> = listOf(
        // FTDI chips with reprogrammed product IDs. The Linux kernel names the
        // first of these FTDI_OCEANIC_PID in drivers/usb/serial/ftdi_sio_ids.h.
        Cable(
            0x0403, 0xF460, FtdiSerialDriver::class.java,
            "Oceanic / Aeris / Sherwood / Hollis cable"
        ),
        Cable(
            0x0403, 0xF680, FtdiSerialDriver::class.java,
            "Suunto Sports Instrument cable"
        ),
        Cable(
            0x0403, 0x87D0, FtdiSerialDriver::class.java,
            "Cressi Leonardo cable"
        ),

        // Seiko/Epson bridge chips, handled by the Prolific driver.
        Cable(
            0x04B8, 0x0521, ProlificSerialDriver::class.java,
            "Mares Nemo and Cressi cable"
        ),
        Cable(
            0x04B8, 0x0522, ProlificSerialDriver::class.java,
            "Zeagle cable"
        ),

        // The Mares Icon HD presents a CDC-ACM interface under a placeholder
        // vendor ID.
        Cable(
            0xFFFF, 0x0005, CdcAcmSerialDriver::class.java,
            "Mares Icon HD cable"
        ),
    )

    /** The cable with these USB identifiers, or null if it is not one of ours. */
    fun find(vendorId: Int, productId: Int): Cable? =
        cables.firstOrNull { it.vendorId == vendorId && it.productId == productId }

    /**
     * A prober that knows the stock identifiers plus every dive cable above.
     *
     * Built fresh on each call, because [UsbSerialProber.getDefaultProbeTable]
     * returns a new table each time and mutating a shared one would compound
     * entries.
     */
    fun prober(): UsbSerialProber {
        val table = UsbSerialProber.getDefaultProbeTable()
        for (cable in cables) {
            table.addProduct(cable.vendorId, cable.productId, cable.driver)
        }
        return UsbSerialProber(table)
    }
}
