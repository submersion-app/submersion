package app.submersion.ocr

import android.graphics.BitmapFactory
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL = "submersion_ocr"

/**
 * On-device text recognition via ML Kit (Latin script, bundled model).
 *
 * Same channel contract as the darwin (Vision) and Windows
 * (Windows.Media.Ocr) implementations: one map per recognized line with
 * top-left-origin pixel coordinates.
 */
class SubmersionOcrPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "recognizeText") {
            result.notImplemented()
            return
        }
        val bytes = call.argument<ByteArray>("image")
        if (bytes == null) {
            result.error("bad_args", "expected {'image': bytes}", null)
            return
        }
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        if (bitmap == null) {
            result.error("decode_failed", "Could not decode image", null)
            return
        }
        val imageWidth = bitmap.width.toDouble()
        val imageHeight = bitmap.height.toDouble()
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(InputImage.fromBitmap(bitmap, 0))
            .addOnSuccessListener { visionText ->
                val lines = mutableListOf<Map<String, Any?>>()
                for (block in visionText.textBlocks) {
                    for (line in block.lines) {
                        val box = line.boundingBox ?: continue
                        lines.add(
                            mapOf(
                                "text" to line.text,
                                "left" to box.left.toDouble(),
                                "top" to box.top.toDouble(),
                                "width" to box.width().toDouble(),
                                "height" to box.height().toDouble(),
                                "confidence" to line.confidence.toDouble(),
                                "imageWidth" to imageWidth,
                                "imageHeight" to imageHeight,
                            ),
                        )
                    }
                }
                result.success(lines)
            }
            .addOnFailureListener { e ->
                result.error("ocr_failed", e.message, null)
            }
            .addOnCompleteListener {
                recognizer.close()
            }
    }
}
