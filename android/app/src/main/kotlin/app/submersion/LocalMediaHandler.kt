package app.submersion

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
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
 *   - pickPersistableTreeUri(): String?
 *       Launches ACTION_OPEN_DOCUMENT_TREE, takes a persistable READ
 *       permission on the chosen tree, and returns its content://tree/...
 *       URI string. Returns null if the user cancelled. Requires an Activity
 *       (set via [attachActivity]) to launch the picker and receive its
 *       result through [onPickTreeResult].
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

    /**
     * The hosting Activity, required to launch the document-tree picker.
     * FlutterActivity extends plain android.app.Activity (not a
     * ComponentActivity), so we cannot use the AndroidX ActivityResult APIs;
     * instead MainActivity forwards startActivityForResult outcomes to
     * [onPickTreeResult].
     */
    private var activity: Activity? = null

    /** Result callback awaiting the folder-tree picker outcome, if any. */
    private var pendingPickResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    /** Wire (or clear) the hosting Activity. Called from MainActivity. */
    fun attachActivity(activity: Activity?) {
        this.activity = activity
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takePersistableUri" -> takePersistableUri(call, result)
            "pickPersistableTreeUri" -> pickPersistableTreeUri(result)
            "resolveBookmark" -> resolveBookmark(call, result)
            "releaseBookmark" -> releaseBookmark(call, result)
            "listPersistedUris" -> listPersistedUris(result)
            "readUriBytes" -> readUriBytes(call, result)
            "enumerateTree" -> enumerateTree(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickPersistableTreeUri(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "No Activity available to launch picker", null)
            return
        }
        if (pendingPickResult != null) {
            result.error("ALREADY_PICKING", "A folder pick is already in progress", null)
            return
        }
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        try {
            act.startActivityForResult(intent, REQUEST_PICK_TREE)
        } catch (e: Exception) {
            pendingPickResult = null
            result.error("PICK_FAILED", e.localizedMessage, null)
        }
    }

    /**
     * Forwarded from MainActivity.onActivityResult. Takes a persistable READ
     * permission on the chosen tree and completes the pending Dart result
     * with the tree URI string (or null on cancellation). Returns true if
     * this handler consumed the result.
     */
    fun onPickTreeResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_TREE) return false
        val result = pendingPickResult ?: return true
        pendingPickResult = null
        val treeUri = data?.data
        if (resultCode != Activity.RESULT_OK || treeUri == null) {
            result.success(null) // cancelled / no selection
            return true
        }
        try {
            context.contentResolver.takePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
            result.success(treeUri.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        }
        return true
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
        // DocumentFile.fromSingleUri / .exists() can throw SecurityException
        // (permission revoked) or IllegalArgumentException (malformed URI);
        // both mean "file is gone from this device's perspective", which the
        // Dart side already handles via the `null` result.
        val exists = try {
            val df = DocumentFile.fromSingleUri(context, uri)
            df != null && df.exists()
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
        result.success(if (exists) uri.toString() else null)
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

    private fun readUriBytes(call: MethodCall, result: MethodChannel.Result) {
        val uriStr = call.argument<String>("uri")
            ?: return result.error("INVALID_ARGS", "uri required", null)
        try {
            val uri = Uri.parse(uriStr)
            val stream = context.contentResolver.openInputStream(uri)
                ?: return result.error("READ_FAILED", "openInputStream returned null", null)
            val bytes = stream.use { it.readBytes() }
            result.success(bytes)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        } catch (e: Exception) {
            result.error("READ_FAILED", e.localizedMessage, null)
        }
    }

    private fun enumerateTree(call: MethodCall, result: MethodChannel.Result) {
        val treeUriStr = call.argument<String>("treeUri")
            ?: return result.error("INVALID_ARGS", "treeUri required", null)
        try {
            val resolver = context.contentResolver
            val treeUri = Uri.parse(treeUriStr)
            val out = ArrayList<HashMap<String, Any>>()
            val stack = ArrayDeque<String>()
            stack.addLast(DocumentsContract.getTreeDocumentId(treeUri))
            while (stack.isNotEmpty()) {
                val parentDocId = stack.removeLast()
                val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)
                resolver.query(
                    childrenUri,
                    arrayOf(
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                        DocumentsContract.Document.COLUMN_MIME_TYPE,
                    ),
                    null, null, null,
                )?.use { c ->
                    while (c.moveToNext()) {
                        val docId = c.getString(0)
                        val name = c.getString(1)
                        val mime = c.getString(2) ?: ""
                        if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                            stack.addLast(docId)
                        } else {
                            val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                            out.add(hashMapOf("basename" to name, "contentUri" to docUri.toString()))
                        }
                    }
                }
            }
            result.success(out)
        } catch (e: Exception) {
            result.error("ENUMERATE_FAILED", e.message, null)
        }
    }

    companion object {
        const val CHANNEL = "com.submersion.app/local_media"

        /** startActivityForResult request code for the document-tree picker. */
        const val REQUEST_PICK_TREE = 0x5542 // 'SU'
    }
}
