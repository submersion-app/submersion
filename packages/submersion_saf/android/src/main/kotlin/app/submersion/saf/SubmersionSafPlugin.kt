package app.submersion.saf

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File

private const val CHANNEL = "app.submersion/saf"
private const val OPEN_TREE_REQUEST = 0xC0DE

/**
 * Storage Access Framework helpers for backups.
 *
 * Registered as a plugin (not a manual MainActivity channel) so that
 * GeneratedPluginRegistrant also installs it in the Workmanager background
 * isolate's engine -- letting automatic backups write to the chosen folder
 * with the app closed. All methods except [pickFolder] use applicationContext
 * and need no Activity; [pickFolder] launches ACTION_OPEN_DOCUMENT_TREE.
 */
class SubmersionSafPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPick: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // Transient detach (e.g. rotation): keep any in-flight pick alive so it
        // can complete once the activity reattaches.
        detach()
    }

    override fun onDetachedFromActivity() {
        // Real teardown: complete any in-flight pick as cancelled so the Dart
        // Future resolves and a later pick isn't blocked with "BUSY".
        pendingPick?.success(null)
        pendingPick = null
        detach()
    }

    private fun attach(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    private fun detach() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolder" -> pickFolder(result)
            "writeBackup" -> writeBackup(call, result)
            "readBackup" -> readBackup(call, result)
            "delete" -> delete(call, result)
            "exists" -> exists(call, result)
            "resolveTree" -> resolveTree(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        val act = activity
            ?: return result.error("NO_ACTIVITY", "No foreground activity", null)
        if (pendingPick != null) {
            return result.error("BUSY", "A pick is already in progress", null)
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        act.startActivityForResult(intent, OPEN_TREE_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != OPEN_TREE_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        return try {
            val flags =
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            context.contentResolver.takePersistableUriPermission(uri, flags)
            val name = DocumentFile.fromTreeUri(context, uri)?.name ?: ""
            result.success(mapOf("uri" to uri.toString(), "displayName" to name))
            true
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
            true
        }
    }

    private fun writeBackup(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = call.argument<String>("treeUri")!!
        val fileName = call.argument<String>("fileName")!!
        val sourcePath = call.argument<String>("sourcePath")!!
        try {
            val tree = DocumentFile.fromTreeUri(context, Uri.parse(treeUri))
                ?: return result.error("NO_TREE", "Tree URI did not resolve", null)
            // Replace an existing same-name file so retries don't accumulate "(1)" copies.
            tree.findFile(fileName)?.delete()
            val doc = tree.createFile("application/octet-stream", fileName)
                ?: return result.error("CREATE_FAILED", "createFile returned null", null)
            context.contentResolver.openOutputStream(doc.uri).use { out ->
                if (out == null) {
                    return result.error("OPEN_FAILED", "openOutputStream returned null", null)
                }
                File(sourcePath).inputStream().use { it.copyTo(out) }
            }
            result.success(doc.uri.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        } catch (e: Exception) {
            result.error("WRITE_FAILED", e.localizedMessage, null)
        }
    }

    private fun readBackup(call: MethodCall, result: MethodChannel.Result) {
        val documentUri = call.argument<String>("documentUri")!!
        val destPath = call.argument<String>("destPath")!!
        try {
            context.contentResolver.openInputStream(Uri.parse(documentUri)).use { input ->
                if (input == null) {
                    return result.error("OPEN_FAILED", "openInputStream returned null", null)
                }
                File(destPath).outputStream().use { input.copyTo(it) }
            }
            result.success(null)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.localizedMessage, null)
        } catch (e: Exception) {
            result.error("READ_FAILED", e.localizedMessage, null)
        }
    }

    private fun delete(call: MethodCall, result: MethodChannel.Result) {
        val documentUri = call.argument<String>("documentUri")!!
        val ok = try {
            DocumentFile.fromSingleUri(context, Uri.parse(documentUri))?.delete() ?: false
        } catch (_: Exception) {
            false
        }
        result.success(ok)
    }

    private fun exists(call: MethodCall, result: MethodChannel.Result) {
        val documentUri = call.argument<String>("documentUri")!!
        val ok = try {
            DocumentFile.fromSingleUri(context, Uri.parse(documentUri))?.exists() ?: false
        } catch (_: Exception) {
            false
        }
        result.success(ok)
    }

    private fun resolveTree(call: MethodCall, result: MethodChannel.Result) {
        val treeUri = call.argument<String>("treeUri")!!
        val name = try {
            val df = DocumentFile.fromTreeUri(context, Uri.parse(treeUri))
            if (df != null && df.exists() && df.canWrite()) (df.name ?: "") else null
        } catch (_: Exception) {
            null
        }
        result.success(name)
    }
}
