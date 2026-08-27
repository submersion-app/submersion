package app.submersion.transcoder

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val METHODS = "submersion_transcoder/methods"
private const val PROGRESS = "submersion_transcoder/progress"

/**
 * Android side of the submersion_transcoder plugin. Implements the same
 * method + event channel contract as the darwin (AVFoundation) plugin so the
 * shared Dart [ChannelTranscodeEngine] talks to either without change.
 */
class SubmersionTranscoderPlugin :
    FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methods: MethodChannel
    private lateinit var progress: EventChannel
    private lateinit var context: Context
    private var progressSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, METHODS)
        methods.setMethodCallHandler(this)
        progress = EventChannel(binding.binaryMessenger, PROGRESS)
        progress.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        progress.setStreamHandler(null)
        // Drop any active sink so we never retain a stale reference or emit
        // progress after the engine is gone.
        progressSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "probe" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.success(null)
                    return
                }
                // MediaMetadataRetriever can be slow on large clips; keep it off
                // the platform (main) thread so the UI never blocks. The result
                // must still be delivered on the main thread.
                val mainHandler = Handler(Looper.getMainLooper())
                Thread {
                    val probe = Media3Transcoder.probe(path)
                    mainHandler.post { result.success(probe) }
                }.start()
            }
            "transcode" -> {
                val source = call.argument<String>("source")
                val output = call.argument<String>("output")
                val maxHeight = call.argument<Int>("maxHeight")
                val videoBitrateKbps = call.argument<Int>("videoBitrateKbps")
                val audioBitrateKbps = call.argument<Int>("audioBitrateKbps")
                val progressId = call.argument<String>("progressId")
                if (source == null || output == null || maxHeight == null ||
                    videoBitrateKbps == null || audioBitrateKbps == null ||
                    progressId == null
                ) {
                    result.error("bad_args", "missing transcode arguments", null)
                    return
                }
                // Transformer must run on a Looper thread; the listener resolves
                // the Flutter result on that same (main) thread.
                Handler(Looper.getMainLooper()).post {
                    try {
                        Media3Transcoder.transcode(
                            context = context,
                            source = source,
                            output = output,
                            maxHeight = maxHeight,
                            videoBitrateKbps = videoBitrateKbps,
                            audioBitrateKbps = audioBitrateKbps,
                            onProgress = { fraction ->
                                progressSink?.success(
                                    mapOf(
                                        "progressId" to progressId,
                                        "fraction" to fraction,
                                    ),
                                )
                            },
                            onDone = { error ->
                                if (error == null) {
                                    result.success(null)
                                } else {
                                    result.error("transcode_failed", error, null)
                                }
                            },
                        )
                    } catch (e: Exception) {
                        // Any synchronous throw escaping the posted Runnable would
                        // crash the app and leave the MethodChannel result
                        // unresolved. Surface it as a channel error instead.
                        result.error(
                            "transcode_failed",
                            e.message ?: "transcode failed",
                            null,
                        )
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        progressSink = events
    }

    override fun onCancel(arguments: Any?) {
        progressSink = null
    }
}
