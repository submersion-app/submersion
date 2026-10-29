package app.submersion

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

/**
 * Presents the diver's buddy card as an NFC Forum Type 4 tag while the swap
 * screen is open (issue #3728). The tag logic lives in [CardEmulationApdu];
 * [CardEmulationHandler] sets the message the swap screen hands it.
 */
class CardEmulationService : HostApduService() {
    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray =
        CardEmulationApdu.shared.process(commandApdu ?: ByteArray(0))

    override fun onDeactivated(reason: Int) {
        CardEmulationApdu.shared.reset()
    }
}
