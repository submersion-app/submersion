package app.submersion.vision

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The `submersion_vision/frames` channel: video frames and the device's
 * state for the ONNX engine (piece 3 of marine life identification). It
 * knows nothing about models. Every call runs on one background thread, in
 * order, and replies on the main thread.
 */
class SubmersionVisionPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var worker: ExecutorService
    private val main = Handler(Looper.getMainLooper())
    private val videos = HashMap<Int, VideoFrames>()
    private var nextHandle = 1

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        worker = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, "submersion_vision/frames")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        worker.execute {
            videos.values.forEach { it.close() }
            videos.clear()
        }
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        worker.execute {
            val reply: Any? = try {
                handle(call)
            } catch (e: FrameException) {
                main.post { result.error(e.code, e.message, null) }
                return@execute
            } catch (e: Throwable) {
                // Throwable, not Exception: an OutOfMemoryError on a large
                // frame fails that frame instead of leaving the call unanswered.
                main.post { result.error("decode_failed", e.message ?: e.toString(), null) }
                return@execute
            }
            main.post {
                if (reply === NotImplemented) result.notImplemented() else result.success(reply)
            }
        }
    }

    private fun handle(call: MethodCall): Any? = when (call.method) {
        "open" -> {
            val path = call.argument<String>("path") ?: throw FrameException("bad_arguments", "path")
            val video = VideoFrames.open(context, path)
            val handle = nextHandle++
            videos[handle] = video
            mapOf(
                "handle" to handle,
                "width" to video.shownWidth,
                "height" to video.shownHeight,
                "durationMs" to video.durationMs,
            )
        }
        "next" -> {
            val video = video(call)
            val atOrAfter = int(call, "atOrAfterMs")
            if (atOrAfter >= video.durationMs) {
                null
            } else {
                // The retriever gives the frame closest to the time, at most
                // half a frame earlier, and not its own time: it is reported
                // at the time asked (frame_reader.dart's contract).
                video.frame(atOrAfter, int(call, "maxSide"))?.let { frame ->
                    mapOf(
                        "ms" to atOrAfter,
                        "width" to frame.width,
                        "height" to frame.height,
                        "rgba" to frame.rgba,
                    )
                }
            }
        }
        "frameAt" -> {
            val video = video(call)
            video.frame(int(call, "ms"), int(call, "maxSide"))?.let { frame ->
                mapOf("width" to frame.width, "height" to frame.height, "rgba" to frame.rgba)
            }
        }
        "close" -> {
            val handle = int(call, "handle")
            videos.remove(handle)?.close()
            null
        }
        "deviceState" -> deviceState()
        else -> NotImplemented
    }

    private fun video(call: MethodCall): VideoFrames =
        videos[int(call, "handle")] ?: throw FrameException("decode_failed", "the video is not open")

    private fun int(call: MethodCall, key: String): Int =
        (call.argument<Number>(key) ?: throw FrameException("bad_arguments", key)).toInt()

    /**
     * Whether the device is severely hot (API 29 and later; earlier, never),
     * and how its memory stands, as the system reports it.
     */
    private fun deviceState(): Map<String, Any> {
        val thermalSevere = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            power.currentThermalStatus >= PowerManager.THERMAL_STATUS_SEVERE
        } else {
            false
        }
        val memory = ActivityManager.MemoryInfo()
        (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(memory)
        return mapOf(
            "thermalSevere" to thermalSevere,
            "lowMemory" to memory.lowMemory,
            "availableBytes" to memory.availMem,
        )
    }

    private object NotImplemented
}

/** A failure with the engine's error code. */
class FrameException(val code: String, message: String) : Exception(message)
