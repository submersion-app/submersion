package app.submersion.nl

import com.google.mlkit.genai.common.DownloadStatus
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
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val CHANNEL = "submersion_nl"
private const val DOWNLOAD_CHANNEL = "submersion_nl/download"
private val SUPPORTED_LANGUAGES = setOf("en", "ko")

/**
 * Gemini Nano through the ML Kit GenAI Prompt API (genai-prompt 1.0.0-beta4).
 * Prompt-only JSON; the Dart side validates the payload against schema v1.
 * The Prompt API is validated for English and Korean only, so other locales
 * are reported as unsupported and the feature stays hidden.
 */
class SubmersionNlPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var downloadChannel: EventChannel
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var model: GenerativeModel? = null
    private var instructions: String = ""
    private var downloadJob: Job? = null

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

    private fun client(): GenerativeModel = model ?: Generation.getClient().also { model = it }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val m = client()
        downloadJob = scope.launch {
            try {
                m.download().collect { status ->
                    when (status) {
                        is DownloadStatus.DownloadStarted -> events.success(0.0)
                        is DownloadStatus.DownloadProgress -> {}
                        is DownloadStatus.DownloadCompleted -> {
                            events.success(1.0)
                            events.endOfStream()
                        }
                        is DownloadStatus.DownloadFailed ->
                            events.error("model_not_ready", status.e.message, null)
                    }
                }
            } catch (e: Exception) {
                events.error("model_not_ready", e.message, null)
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        downloadJob?.cancel()
        downloadJob = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> availability(call.argument<String>("locale") ?: "en", result)
            "prepare" -> {
                instructions = call.argument<String>("instructions") ?: ""
                client()
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
        val m = client()
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
        val m = client()
        scope.launch {
            try {
                val prompt = instructions + "\n\nSentence: " + sentence + "\n"
                val request = generateContentRequest(TextPart(prompt)) { maxOutputTokens = 512 }
                val response = withContext(Dispatchers.IO) { m.generateContent(request) }
                val text = response.candidates.firstOrNull()?.text ?: ""
                result.success(stripFences(text))
            } catch (e: GenAiException) {
                result.error(mapCode(e.errorCode), e.message, null)
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

    private fun mapCode(code: Int): String = when (code) {
        GenAiException.ErrorCode.REQUEST_TOO_LARGE -> "context_exceeded"
        GenAiException.ErrorCode.BUSY,
        GenAiException.ErrorCode.PER_APP_BATTERY_USE_QUOTA_EXCEEDED -> "quota_exceeded"
        GenAiException.ErrorCode.NOT_AVAILABLE,
        GenAiException.ErrorCode.NOT_SUPPORTED,
        GenAiException.ErrorCode.NEEDS_SYSTEM_UPDATE,
        GenAiException.ErrorCode.AICORE_INCOMPATIBLE,
        GenAiException.ErrorCode.NOT_ENOUGH_DISK_SPACE -> "model_not_ready"
        GenAiException.ErrorCode.RESPONSE_PROCESSING_ERROR,
        GenAiException.ErrorCode.RESPONSE_GENERATION_ERROR -> "decoding_failure"
        else -> "unknown"
    }
}
