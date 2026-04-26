package app.submersion

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Handles persistable URI permission management for the Media Source
 * Extension feature.
 *
 * Methods (channel: com.submersion.app/local_media):
 *   - takePersistableUri(uri: String): String
 *       Calls ContentResolver.takePersistableUriPermission with read flag
 *       and returns the URI string itself (which Dart-side stores as
 *       MediaItem.bookmarkRef).
 *   - resolveBookmark(bookmarkRef: String): String?
 *       Returns the URI as a string if the resource still exists, null if
 *       the underlying file is gone.
 *   - releaseBookmark(bookmarkRef: String): Unit
 *       Calls ContentResolver.releasePersistableUriPermission.
 *   - listPersistedUris(): List<String>
 *       Returns all persisted URI permissions for the Settings UI's URI
 *       budget display (Android caps at 128 per app).
 */
class LocalMediaHandler(
    private val context: Context,
    private val channel: MethodChannel,
) : MethodCallHandler {

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takePersistableUri" -> takePersistableUri(call, result)
            "resolveBookmark" -> resolveBookmark(call, result)
            "releaseBookmark" -> releaseBookmark(call, result)
            "listPersistedUris" -> listPersistedUris(result)
            else -> result.notImplemented()
        }
    }

    private fun takePersistableUri(call: MethodCall, result: MethodChannel.Result) {
        val uriStr = call.argument<String>("uri")
            ?: return result.error("INVALID_ARGS", "uri required", null)
        val uri = Uri.parse(uriStr)
        try {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            context.contentResolver.takePersistableUriPermission(uri, flags)
            result.success(uriStr)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        }
    }

    private fun resolveBookmark(call: MethodCall, result: MethodChannel.Result) {
        val ref = call.argument<String>("bookmarkRef")
            ?: return result.error("INVALID_ARGS", "bookmarkRef required", null)
        val uri = Uri.parse(ref)
        val df = DocumentFile.fromSingleUri(context, uri)
        if (df == null || !df.exists()) {
            result.success(null)
            return
        }
        result.success(uri.toString())
    }

    private fun releaseBookmark(call: MethodCall, result: MethodChannel.Result) {
        val ref = call.argument<String>("bookmarkRef")
            ?: return result.error("INVALID_ARGS", "bookmarkRef required", null)
        val uri = Uri.parse(ref)
        try {
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            context.contentResolver.releasePersistableUriPermission(uri, flags)
        } catch (_: SecurityException) {
            // Already released -- harmless.
        }
        result.success(null)
    }

    private fun listPersistedUris(result: MethodChannel.Result) {
        val uris = context.contentResolver.persistedUriPermissions
            .map { it.uri.toString() }
        result.success(uris)
    }

    companion object {
        const val CHANNEL = "com.submersion.app/local_media"
    }
}
