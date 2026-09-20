package app.submersion.nl

import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val CHANNEL = "submersion_nl"
private const val DOWNLOAD_CHANNEL = "submersion_nl/download"
private val SUPPORTED_LANGUAGES = setOf("en", "ko")

/**
 * Gemini Nano through the ML Kit GenAI Prompt API. Prompt-only JSON; the
 * Dart side validates the payload against schema v1. The Prompt API is
 * validated for English and Korean only, so other locales are reported as
 * unsupported and the feature stays hidden.
 */
class SubmersionNlPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var downloadChannel: EventChannel
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var model: GenerativeModel? = null
    private var instructions: String = ""

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        downloadChannel = EventChannel(binding.binaryMessenger, DOWNLOAD_CHANNEL)
        downloadChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        downloadChannel.setStreamHandler(null)
        model?.close()
        scope.cancel()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val m = model ?: Generation.getClient().also { model = it }
        scope.launch {
            try {
                m.download(object : DownloadCallback {
                    override fun onDownloadStarted(bytesToDownload: Long) {
                        events.success(0.0)
                    }

                    override fun onDownloadProgress(totalBytesDownloaded: Long) {}

                    override fun onDownloadCompleted() {
                        events.success(1.0)
                        events.endOfStream()
                    }

                    override fun onDownloadFailed(e: GenAiException) {
                        events.error("model_not_ready", e.message, null)
                    }
                })
            } catch (e: Exception) {
                events.error("model_not_ready", e.message, null)
            }
        }
    }

    override fun onCancel(arguments: Any?) {}

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> availability(call.argument<String>("locale") ?: "en", result)
            "prepare" -> {
                instructions = call.argument<String>("instructions") ?: ""
                if (model == null) model = Generation.getClient()
                result.success(null)
            }
            "compile" -> {
                val sentence = call.argument<String>("sentence")
                if (sentence == null) {
                    result.error("decoding_failure", "missing sentence", null)
                    return
                }
                compile(sentence, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun availability(localeTag: String, result: MethodChannel.Result) {
        val language = localeTag.substringBefore('-').substringBefore('_').lowercase()
        if (language !in SUPPORTED_LANGUAGES) {
            result.success("unsupportedLocale")
            return
        }
        val m = model ?: Generation.getClient().also { model = it }
        scope.launch {
            try {
                val status = withContext(Dispatchers.IO) { m.checkStatus() }
                result.success(
                    when (status) {
                        FeatureStatus.AVAILABLE -> "available"
                        FeatureStatus.DOWNLOADABLE -> "downloadable"
                        FeatureStatus.DOWNLOADING -> "downloading"
                        else -> "deviceNotEligible"
                    }
                )
            } catch (e: Exception) {
                result.success("deviceNotEligible")
            }
        }
    }

    private fun compile(sentence: String, result: MethodChannel.Result) {
        val m = model ?: Generation.getClient().also { model = it }
        scope.launch {
            try {
                val prompt = instructions + "\n\nSentence: " + sentence + "\n"
                val response = withContext(Dispatchers.IO) {
                    m.generateContent(generateContentRequest(TextPart(prompt)) { maxOutputTokens = 512 })
                }
                val text = response.candidates.firstOrNull()?.text ?: ""
                result.success(stripFences(text))
            } catch (e: GenAiException) {
                result.error(mapCode(e), e.message, null)
            } catch (e: Exception) {
                result.error("unknown", e.message, null)
            }
        }
    }

    private fun stripFences(text: String): String {
        val trimmed = text.trim()
        if (!trimmed.startsWith("```")) return trimmed
        return trimmed.removePrefix("```json").removePrefix("```").removeSuffix("```").trim()
    }

    private fun mapCode(e: GenAiException): String {
        val name = e.errorCode.toString()
        return when {
            name.contains("REQUEST_TOO_LARGE") -> "context_exceeded"
            name.contains("QUOTA") || name.contains("BUSY") -> "quota_exceeded"
            name.contains("NOT_AVAILABLE") || name.contains("NOT_READY") || name.contains("DOWNLOAD") -> "model_not_ready"
            name.contains("SAFETY") || name.contains("BLOCKED") -> "guardrail"
            else -> "unknown"
        }
    }
}
