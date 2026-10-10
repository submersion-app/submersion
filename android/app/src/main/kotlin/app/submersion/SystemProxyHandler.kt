package app.submersion

import android.content.Context
import android.net.ConnectivityManager
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Tells Dart which proxy Android would use (issue #3217).
 *
 * Methods (channel: app.submersion/system_proxy):
 *   - resolve({url}): Map, same contract as the Apple handlers:
 *       kind "none", kind "fixed" (type, host, port, bypass, viaPac), or
 *       kind "unavailable" (reason).
 *
 * A Wi-Fi network configured with a PAC URL is served by Android's local
 * PAC proxy, reported here as localhost:<port>, so it needs no PAC engine.
 * If a device reports only the PAC URL, Dart is told it is unsupported.
 */
class SystemProxyHandler(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodCallHandler {

    companion object {
        const val CHANNEL = "app.submersion/system_proxy"
    }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "resolve") {
            result.notImplemented()
            return
        }
        try {
            result.success(resolve())
        } catch (e: Exception) {
            result.error("system_proxy", e.message, null)
        }
    }

    private fun resolve(): Map<String, Any?> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val info = cm.defaultProxy ?: return mapOf("kind" to "none")
        val pacUrl = info.pacFileUrl
        val hasPac = pacUrl != null && pacUrl != Uri.EMPTY
        val host = info.host
        if (host.isNullOrEmpty() || info.port <= 0) {
            return if (hasPac) {
                mapOf("kind" to "unavailable", "reason" to "pacUnsupported")
            } else {
                mapOf("kind" to "none")
            }
        }
        return mapOf(
            "kind" to "fixed",
            "type" to "http",
            "host" to host,
            "port" to info.port,
            "bypass" to (info.exclusionList?.toList() ?: emptyList<String>()),
            "viaPac" to hasPac,
        )
    }
}
