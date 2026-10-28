package app.submersion

/**
 * An NFC Forum Type 4 tag holding one read-only NDEF message: the buddy
 * card link the swap screen hands over (issue #3728). Kept free of Android
 * types so the APDU exchange is unit-tested on the JVM.
 *
 * A reader selects the NDEF tag application (AID D2760000850101), selects
 * and reads the capability container (file E103), then selects the NDEF
 * file (E104) and reads it: a 2-byte length followed by the message.
 */
class CardEmulationApdu {
    companion object {
        /** The instance [CardEmulationService] answers from. */
        val shared = CardEmulationApdu()

        private val OK = bytes(0x90, 0x00)
        private val NOT_FOUND = bytes(0x6A, 0x82)
        private val NOT_SUPPORTED = bytes(0x6D, 0x00)
        private val WRONG_OFFSET = bytes(0x6B, 0x00)
        private val NDEF_AID = bytes(0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01)
        private val CC_FILE = bytes(0xE1, 0x03)
        private val NDEF_FILE = bytes(0xE1, 0x04)

        /** Capability container: version 2.0, read-only NDEF file E104. */
        private val CAPABILITY_CONTAINER = bytes(
            0x00, 0x0F, // CC length
            0x20, // mapping version 2.0
            0x00, 0x3B, // largest read
            0x00, 0x34, // largest write
            0x04, 0x06, // NDEF file control TLV
            0xE1, 0x04, // NDEF file id
            0x7F, 0xFF, // largest NDEF file
            0x00, // read access: open
            0xFF, // write access: none
        )

        private fun bytes(vararg values: Int) = ByteArray(values.size) { values[it].toByte() }
    }

    private enum class Selected { NONE, CC, NDEF }

    /** The NDEF message presented; null while the swap screen is closed. */
    @Volatile
    var message: ByteArray? = null

    /** True while the app is not in the foreground: no tag is presented. */
    @Volatile
    var paused = false

    private var appSelected = false
    private var selected = Selected.NONE

    /** Forgets the reader's selections when the field drops. */
    fun reset() {
        appSelected = false
        selected = Selected.NONE
    }

    fun process(apdu: ByteArray): ByteArray {
        if (apdu.size < 4) return NOT_SUPPORTED
        // In the background no tag is presented, not even to a reader that
        // selected it before the app paused.
        if (paused) {
            reset()
            return NOT_FOUND
        }
        val ins = apdu[1].toInt() and 0xFF
        val p1 = apdu[2].toInt() and 0xFF
        return when (ins) {
            0xA4 -> select(apdu, p1)
            0xB0 -> readBinary(apdu)
            else -> NOT_SUPPORTED
        }
    }

    private fun select(apdu: ByteArray, p1: Int): ByteArray {
        if (apdu.size < 5) return NOT_FOUND
        val length = apdu[4].toInt() and 0xFF
        if (apdu.size < 5 + length) return NOT_FOUND
        val data = apdu.copyOfRange(5, 5 + length)
        if (p1 == 0x04) {
            appSelected = message != null && data.contentEquals(NDEF_AID)
            selected = Selected.NONE
            return if (appSelected) OK else NOT_FOUND
        }
        if (!appSelected) return NOT_FOUND
        selected = when {
            data.contentEquals(CC_FILE) -> Selected.CC
            data.contentEquals(NDEF_FILE) -> Selected.NDEF
            else -> return NOT_FOUND
        }
        return OK
    }

    private fun readBinary(apdu: ByteArray): ByteArray {
        val file = when (selected) {
            Selected.CC -> CAPABILITY_CONTAINER
            Selected.NDEF -> ndefFile() ?: return NOT_FOUND
            Selected.NONE -> return NOT_FOUND
        }
        val offset = ((apdu[2].toInt() and 0xFF) shl 8) or (apdu[3].toInt() and 0xFF)
        val wanted = if (apdu.size > 4) apdu[4].toInt() and 0xFF else 0
        if (offset >= file.size) return WRONG_OFFSET
        val end = minOf(file.size, offset + if (wanted == 0) 256 else wanted)
        return file.copyOfRange(offset, end) + OK
    }

    /** The NDEF file: the message's 2-byte length, then the message. */
    private fun ndefFile(): ByteArray? {
        val body = message ?: return null
        return byteArrayOf((body.size shr 8).toByte(), (body.size and 0xFF).toByte()) + body
    }
}
