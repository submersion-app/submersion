package app.submersion

import android.content.Context
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Tells Dart what this device is called, so peers can be named on the
 * "Devices on this backend" page instead of shown as a hex id (issue #1194).
 *
 * Android's hostname is 'localhost' on effectively every device, so
 * Platform.localHostname -- which names desktops correctly -- identifies
 * nothing here. These fields are what a phone actually knows about itself.
 *
 * Methods (channel: app.submersion/device_name):
 *   - getDeviceIdentity(): Map<String, String?>
 *       name         the owner's chosen device name, or null
 *       manufacturer Build.MANUFACTURER ('samsung', 'Google')
 *       model        Build.MODEL ('SM-S921B', 'Pixel 8 Pro')
 *
 * Composition and fallback live Dart-side in DeviceDisplayNameService, where
 * they are unit-testable; this handler only reports raw facts.
 */
class DeviceNameHandler(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodCallHandler {

    companion object {
        const val CHANNEL = "app.submersion/device_name"
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getDeviceIdentity" -> result.success(
                mapOf(
                    "name" to ownerName(),
                    "manufacturer" to Build.MANUFACTURER,
                    "model" to Build.MODEL,
                )
            )
            else -> result.notImplemented()
        }
    }

    /**
     * The name the owner typed under Settings > About phone > Device name.
     * Readable without any permission. Null on ROMs that never set it, and on
     * a device whose owner never changed it -- Dart then composes the model.
     */
    private fun ownerName(): String? = try {
        Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
    } catch (e: Exception) {
        // Never fail a sync over a cosmetic name.
        null
    }
}
