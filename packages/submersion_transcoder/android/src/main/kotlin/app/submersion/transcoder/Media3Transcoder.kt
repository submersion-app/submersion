package app.submersion.transcoder

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File

/**
 * Native Android transcoding via AndroidX Media3 [Transformer]. Mirrors the
 * darwin AVFoundation engine: H.264 + AAC .mp4, scale to a height cap without
 * upscaling, write `<output>.tmp` then rename on success.
 */
object Media3Transcoder {

    /**
     * Reads display dimensions / duration / overall bitrate. Returns null when
     * the file is not a readable video, so the Dart side treats it as
     * "cannot transcode" and uploads the original.
     */
    fun probe(path: String): Map<String, Any>? {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val w = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val h = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            if (w == null || h == null || w == 0 || h == 0) return null
            // Rotation swaps stored width/height for the display orientation.
            val rot = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            val dispW = if (rot == 90 || rot == 270) h else w
            val dispH = if (rot == 90 || rot == 270) w else h
            val durationMs = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val bitrate = r.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toLongOrNull() ?: 0L
            mapOf(
                "width" to dispW,
                "height" to dispH,
                "durationMs" to durationMs.toInt(),
                "overallBitrateKbps" to (bitrate / 1000).toInt(),
            )
        } catch (e: Exception) {
            null
        } finally {
            r.release()
        }
    }

    /**
     * Transcodes [source] into [output]. Must be invoked on a Looper thread
     * (the caller posts to the main looper). [onDone] receives null on success
     * or an error message; [onProgress] receives 0..1 fractions.
     */
    fun transcode(
        context: Context,
        source: String,
        output: String,
        maxHeight: Int,
        videoBitrateKbps: Int,
        @Suppress("UNUSED_PARAMETER") audioBitrateKbps: Int,
        onProgress: (Double) -> Unit,
        onDone: (String?) -> Unit,
    ) {
        val tmp = File("$output.tmp")
        if (tmp.exists()) tmp.delete()

        val handler = Handler(Looper.getMainLooper())

        // probe() uses MediaMetadataRetriever, which can be slow on large
        // clips, so read the source height off the main thread. The Transformer
        // itself is Looper-bound (it delivers listener callbacks and reports
        // progress on the thread it is started on), so hop back to the main
        // looper for all Transformer work once the height is known.
        Thread {
            val srcHeight = probe(source)?.get("height") as? Int ?: maxHeight
            handler.post {
                startTransform(
                    context = context,
                    source = source,
                    output = output,
                    tmp = tmp,
                    handler = handler,
                    srcHeight = srcHeight,
                    maxHeight = maxHeight,
                    videoBitrateKbps = videoBitrateKbps,
                    onProgress = onProgress,
                    onDone = onDone,
                )
            }
        }.start()
    }

    /**
     * Builds and starts the Media3 [Transformer]. Must run on a Looper thread
     * (the caller posts it to the main looper); the listener resolves [onDone]
     * on that same thread.
     */
    @androidx.annotation.OptIn(markerClass = [UnstableApi::class])
    private fun startTransform(
        context: Context,
        source: String,
        output: String,
        tmp: File,
        handler: Handler,
        srcHeight: Int,
        maxHeight: Int,
        videoBitrateKbps: Int,
        onProgress: (Double) -> Unit,
        onDone: (String?) -> Unit,
    ) {
        try {
            // Never upscale: only resize when the source is taller than the cap.
            val effectiveHeight = minOf(maxHeight, srcHeight)
            val videoEffects: List<Effect> =
                if (effectiveHeight < srcHeight) {
                    listOf(Presentation.createForHeight(effectiveHeight))
                } else {
                    emptyList()
                }

            val encoderFactory = DefaultEncoderFactory.Builder(context)
                .setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder()
                        .setBitrate(videoBitrateKbps * 1000)
                        .build())
                .build()

            val edited = EditedMediaItem.Builder(
                MediaItem.fromUri(Uri.fromFile(File(source))))
                .setEffects(Effects(/* audioProcessors= */ emptyList(), videoEffects))
                .build()

            val progressHolder = ProgressHolder()
            lateinit var transformer: Transformer

            val poll = object : Runnable {
                override fun run() {
                    if (transformer.getProgress(progressHolder)
                        == Transformer.PROGRESS_STATE_AVAILABLE) {
                        onProgress(progressHolder.progress / 100.0)
                    }
                    handler.postDelayed(this, 200)
                }
            }

            transformer = Transformer.Builder(context)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactory)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(
                        composition: Composition,
                        exportResult: ExportResult,
                    ) {
                        handler.removeCallbacks(poll)
                        onProgress(1.0)
                        // Finalize atomically. renameTo fails if the destination
                        // exists, so remove any stale output first (tmp is a
                        // complete rendition at this point); if the rename still
                        // fails, delete the .tmp so we never leave debris
                        // (contract: never leave a "<output>.tmp" behind).
                        val outputFile = File(output)
                        outputFile.delete()
                        if (tmp.renameTo(outputFile)) {
                            onDone(null)
                        } else {
                            tmp.delete()
                            onDone("rename failed")
                        }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        handler.removeCallbacks(poll)
                        tmp.delete()
                        onDone(exportException.message ?: "transform failed")
                    }
                })
                .build()

            transformer.start(edited, tmp.absolutePath)
            handler.postDelayed(poll, 200)
        } catch (e: Exception) {
            // A synchronous failure setting up or starting the Transformer
            // (invalid input, unsupported format) would otherwise never invoke
            // onDone, hanging the awaiting Dart caller. Stop any poll, clean up
            // the tmp so we leave no debris, and report the failure.
            handler.removeCallbacksAndMessages(null)
            tmp.delete()
            onDone(e.message ?: "transcode setup failed")
        }
    }
}
