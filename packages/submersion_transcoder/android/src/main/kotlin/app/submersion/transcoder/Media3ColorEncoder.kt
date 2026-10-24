package app.submersion.transcoder

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.container.Mp4LocationData
import androidx.media3.effect.DefaultVideoFrameProcessor
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.InAppMp4Muxer
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import java.io.File

/**
 * Re-encodes a video with the app's colour timeline applied to every frame
 * (issue #3521), through Media3 [Transformer] with [ColorTimelineEffect].
 * Keeps the codec family (H.264 or HEVC; anything else, or 10-bit H.264,
 * becomes HEVC), dimensions, rotation, frame timing, HDR, the audio (passed
 * through) and the location the Dart side read. Encoder fallback is off, so
 * a source the device cannot encode at full size fails as unsupported rather
 * than shrinking. Writes `<output>.tmp` and renames it on success.
 */
@UnstableApi
object Media3ColorEncoder {
    /** [code] is null on success, else `cancelled`, `unsupported` or `transcode_failed`. */
    fun interface Done {
        fun call(code: String?, message: String?)
    }

    private class Job(
        val transformer: Transformer,
        val tmp: File,
        val poll: Runnable,
        val done: Done,
    )

    // Encodes in flight, by progressId, and cancels that arrived before their
    // encode started (while the source was still being inspected). Touched on
    // the main looper only.
    private val jobs = HashMap<String, Job>()
    private val starting = HashSet<String>()
    private val cancelledEarly = HashSet<String>()
    private val main = Handler(Looper.getMainLooper())

    // A device that cannot edit HDR fails with one of the format codes.
    private val unsupportedCodes = setOf(
        ExportException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED,
        ExportException.ERROR_CODE_ENCODING_FORMAT_UNSUPPORTED,
        ExportException.ERROR_CODE_DECODER_INIT_FAILED,
        ExportException.ERROR_CODE_ENCODER_INIT_FAILED,
    )

    private val hdrCodecCodes = setOf(
        ExportException.ERROR_CODE_DECODING_FAILED,
        ExportException.ERROR_CODE_VIDEO_FRAME_PROCESSING_FAILED,
    )

    private class Source(
        val transfer: SignalTransfer,
        val tenBit: Boolean,
        val videoMime: String,
        val bitrate: Int,
    )

    fun encode(
        context: Context,
        source: String,
        output: String,
        timeline: ColorTimeline,
        location: String?,
        progressId: String,
        onProgress: (Double) -> Unit,
        done: Done,
    ) {
        val tmp = File("$output.tmp")
        if (tmp.exists()) tmp.delete()
        main.post { starting.add(progressId) }
        // Reading the track formats can be slow on large clips; the
        // Transformer itself is Looper-bound, so start it on the main looper.
        Thread {
            val info = try {
                inspect(source)
            } catch (e: Exception) {
                main.post {
                    starting.remove(progressId)
                    cancelledEarly.remove(progressId)
                    done.call("transcode_failed", e.message ?: "unreadable source")
                }
                return@Thread
            }
            main.post {
                start(context, source, output, tmp, timeline, location, info, progressId, onProgress, done)
            }
        }.start()
    }

    fun cancel(progressId: String) {
        main.post {
            val job = jobs.remove(progressId)
            if (job == null) {
                // Not started yet: stop it when it does. A cancel for an
                // encode that already finished is dropped.
                if (progressId in starting) cancelledEarly.add(progressId)
                return@post
            }
            main.removeCallbacks(job.poll)
            job.transformer.cancel()
            job.tmp.delete()
            job.done.call("cancelled", null)
        }
    }

    private fun inspect(path: String): Source {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/")) continue
                val colorTransfer =
                    if (format.containsKey(MediaFormat.KEY_COLOR_TRANSFER)) {
                        format.getInteger(MediaFormat.KEY_COLOR_TRANSFER)
                    } else {
                        0
                    }
                val transfer = when (colorTransfer) {
                    MediaFormat.COLOR_TRANSFER_ST2084 -> SignalTransfer.PQ
                    MediaFormat.COLOR_TRANSFER_HLG -> SignalTransfer.HLG
                    else -> SignalTransfer.SDR
                }
                val profile =
                    if (format.containsKey(MediaFormat.KEY_PROFILE)) {
                        format.getInteger(MediaFormat.KEY_PROFILE)
                    } else {
                        0
                    }
                val tenBit = transfer != SignalTransfer.SDR || profile in TEN_BIT_PROFILES
                // No 10-bit H.264 encoders exist on Android; such a clip becomes HEVC.
                val videoMime =
                    if (mime == MimeTypes.VIDEO_H264 && !tenBit) MimeTypes.VIDEO_H264
                    else MimeTypes.VIDEO_H265
                return Source(transfer, tenBit, videoMime, bitrateOf(path))
            }
            throw IllegalArgumentException("no video track in the source")
        } finally {
            extractor.release()
        }
    }

    /** The transfer of [path]'s video track, or null when it cannot be read. */
    private fun transferOf(path: String): SignalTransfer? = try {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            (0 until extractor.trackCount)
                .map { extractor.getTrackFormat(it) }
                .firstOrNull { it.getString(MediaFormat.KEY_MIME)?.startsWith("video/") == true }
                ?.let { format ->
                    when (
                        if (format.containsKey(MediaFormat.KEY_COLOR_TRANSFER)) {
                            format.getInteger(MediaFormat.KEY_COLOR_TRANSFER)
                        } else {
                            0
                        }
                    ) {
                        MediaFormat.COLOR_TRANSFER_ST2084 -> SignalTransfer.PQ
                        MediaFormat.COLOR_TRANSFER_HLG -> SignalTransfer.HLG
                        else -> SignalTransfer.SDR
                    }
                }
        } finally {
            extractor.release()
        }
    } catch (e: Exception) {
        null
    }

    private val TEN_BIT_PROFILES = setOf(
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10,
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10,
        MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10Plus,
        MediaCodecInfo.CodecProfileLevel.AVCProfileHigh10,
    )

    private fun bitrateOf(path: String): Int {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            val bps = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
                ?.toLongOrNull() ?: 0L
            bps.coerceIn(4_000_000L, 100_000_000L).toInt()
        } catch (e: Exception) {
            4_000_000
        } finally {
            retriever.release()
        }
    }

    /** `+20.5000-087.0000+000.000/` to latitude and longitude. */
    private fun parseIso6709(text: String?): Pair<Float, Float>? {
        val match = Regex("""^([+-]\d{1,2}(?:\.\d+)?)([+-]\d{1,3}(?:\.\d+)?)""")
            .find(text ?: return null) ?: return null
        val lat = match.groupValues[1].toFloatOrNull() ?: return null
        val lon = match.groupValues[2].toFloatOrNull() ?: return null
        return lat to lon
    }

    private fun start(
        context: Context,
        source: String,
        output: String,
        tmp: File,
        timeline: ColorTimeline,
        location: String?,
        info: Source,
        progressId: String,
        onProgress: (Double) -> Unit,
        done: Done,
    ) {
        starting.remove(progressId)
        if (cancelledEarly.remove(progressId)) {
            done.call("cancelled", null)
            return
        }
        try {
            val encoderFactory = DefaultEncoderFactory.Builder(context)
                .setEnableFallback(false)
                .setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder().setBitrate(info.bitrate).build(),
                )
                .build()
            // The matrix works on gamma-encoded SDR values, as the app's
            // viewer draws them; HDR always arrives linear.
            val frameProcessorFactory = DefaultVideoFrameProcessor.Factory.Builder()
                .setSdrWorkingColorSpace(DefaultVideoFrameProcessor.WORKING_COLOR_SPACE_ORIGINAL)
                .build()
            val place = parseIso6709(location)
            val muxerFactory = InAppMp4Muxer.Factory { entries ->
                if (place != null) entries.add(Mp4LocationData(place.first, place.second))
            }
            val edited = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(source))))
                .setEffects(
                    Effects(
                        /* audioProcessors= */ emptyList(),
                        listOf(ColorTimelineEffect(timeline, info.transfer)),
                    ),
                )
                .build()

            val progressHolder = ProgressHolder()
            lateinit var transformer: Transformer
            val poll = object : Runnable {
                override fun run() {
                    if (transformer.getProgress(progressHolder) ==
                        Transformer.PROGRESS_STATE_AVAILABLE
                    ) {
                        onProgress(progressHolder.progress / 100.0)
                    }
                    main.postDelayed(this, 200)
                }
            }

            transformer = Transformer.Builder(context)
                .setVideoMimeType(info.videoMime)
                .setEncoderFactory(encoderFactory)
                .setVideoFrameProcessorFactory(frameProcessorFactory)
                .setMuxerFactory(muxerFactory)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        if (jobs.remove(progressId) == null) return
                        main.removeCallbacks(poll)
                        onProgress(1.0)
                        // An HDR source must come out HDR: a device that
                        // tone-mapped it instead cannot do this encode.
                        if (info.transfer != SignalTransfer.SDR &&
                            transferOf(tmp.absolutePath) != info.transfer
                        ) {
                            tmp.delete()
                            done.call("unsupported", "HDR could not be kept on this device")
                            return
                        }
                        val outputFile = File(output)
                        outputFile.delete()
                        if (tmp.renameTo(outputFile)) {
                            done.call(null, null)
                        } else {
                            tmp.delete()
                            done.call("transcode_failed", "rename failed")
                        }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        if (jobs.remove(progressId) == null) return
                        main.removeCallbacks(poll)
                        tmp.delete()
                        // A device whose decoder cannot read its own HDR or
                        // 10-bit clip cannot do this at all, which is not a
                        // fault (an emulator's software decoder is one).
                        val hdrCodecFailure =
                            info.tenBit && exportException.errorCode in hdrCodecCodes
                        val code =
                            if (exportException.errorCode in unsupportedCodes || hdrCodecFailure) {
                                "unsupported"
                            } else {
                                "transcode_failed"
                            }
                        done.call(code, exportException.message ?: "colour encode failed")
                    }
                })
                .build()

            jobs[progressId] = Job(transformer, tmp, poll, done)
            transformer.start(edited, tmp.absolutePath)
            main.postDelayed(poll, 200)
        } catch (e: Exception) {
            jobs.remove(progressId)
            tmp.delete()
            done.call("transcode_failed", e.message ?: "colour encode setup failed")
        }
    }
}
