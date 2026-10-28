package app.submersion

import android.app.Activity
import android.content.ComponentName
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Turns the buddy card tag on and off for the swap screen (issue #3728).
 *
 * Methods (channel: app.submersion/card_emulation):
 *   - isSupported(): Boolean, whether this phone can emulate a tag
 *   - start(bytes): presents the NDEF message, and asks Android to prefer
 *     this app for the NDEF tag application while it is in the foreground
 *   - stop(): presents nothing; a reader then finds no tag here
 */
class CardEmulationHandler(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodCallHandler {

    companion object {
        const val CHANNEL = "app.submersion/card_emulation"
    }

    init {
        channel.setMethodCallHandler(this)
    }

    private val component = ComponentName(activity, CardEmulationService::class.java)

    private fun cardEmulation(): CardEmulation? {
        val adapter = NfcAdapter.getDefaultAdapter(activity) ?: return null
        return CardEmulation.getInstance(adapter)
    }

    /**
     * Android asks for the preferred service to be released in onPause; it
     * is taken back on resume while the swap screen still shares a card.
     */
    fun onPause() {
        CardEmulationApdu.shared.paused = true
        runCatching { cardEmulation()?.unsetPreferredService(activity) }
    }

    fun onResume() {
        CardEmulationApdu.shared.paused = false
        if (CardEmulationApdu.shared.message != null) {
            runCatching { cardEmulation()?.setPreferredService(activity, component) }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(
                activity.packageManager.hasSystemFeature(
                    PackageManager.FEATURE_NFC_HOST_CARD_EMULATION,
                ) && NfcAdapter.getDefaultAdapter(activity)?.isEnabled == true,
            )
            "start" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null) {
                    result.error("badArgs", "start needs the NDEF bytes", null)
                    return
                }
                CardEmulationApdu.shared.message = bytes
                runCatching { cardEmulation()?.setPreferredService(activity, component) }
                result.success(null)
            }
            "stop" -> {
                CardEmulationApdu.shared.message = null
                CardEmulationApdu.shared.reset()
                runCatching { cardEmulation()?.unsetPreferredService(activity) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
