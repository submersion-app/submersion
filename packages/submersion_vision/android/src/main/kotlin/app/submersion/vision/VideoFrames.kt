package app.submersion.vision

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import java.nio.ByteBuffer
import kotlin.math.max

/** RGBA pixels of one frame, rows top to bottom. */
class Frame(val width: Int, val height: Int, val rgba: ByteArray)

/**
 * One opened video's frames, read with [MediaMetadataRetriever] at the exact
 * time asked (`OPTION_CLOSEST`), as `FrameExtractor.kt` in the transcoder
 * reads them. Frames are turned as the player shows the video, and fitted
 * so the longer side is at most the size asked. Read-only: the retriever
 * never writes the video. Used from one thread at a time.
 */
class VideoFrames private constructor(
    private val retriever: MediaMetadataRetriever,
    private val naturalWidth: Int,
    private val naturalHeight: Int,
    private val rotation: Int,
    val durationMs: Int,
) {
    /** The video's size as the player shows it, after its rotation. */
    val shownWidth: Int get() = if (quarterTurn) naturalHeight else naturalWidth
    val shownHeight: Int get() = if (quarterTurn) naturalWidth else naturalHeight

    private val quarterTurn: Boolean get() = rotation == 90 || rotation == 270

    /** The frame shown at [ms], or null when it cannot be read. */
    fun frame(ms: Int, maxSide: Int): Frame? {
        val us = ms.toLong() * 1000
        // A square box, so a frame the retriever has already turned keeps
        // its longer side at the size asked.
        val side = minOf(maxSide, max(naturalWidth, naturalHeight))
        val decoded: Bitmap = (
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(us, MediaMetadataRetriever.OPTION_CLOSEST, side, side)
            } else {
                retriever.getFrameAtTime(us, MediaMetadataRetriever.OPTION_CLOSEST)
            }
            ) ?: return null
        val shown = shown(decoded, maxSide)
        if (shown !== decoded) decoded.recycle()
        val argb = if (shown.config == Bitmap.Config.ARGB_8888) shown else shown.copy(Bitmap.Config.ARGB_8888, false)
        if (argb !== shown) shown.recycle()
        // ARGB_8888 is stored R, G, B, A in memory.
        val buffer = ByteBuffer.allocate(argb.byteCount)
        argb.copyPixelsToBuffer(buffer)
        val frame = Frame(argb.width, argb.height, buffer.array())
        argb.recycle()
        return frame
    }

    fun close() {
        try {
            retriever.release()
        } catch (_: Exception) {
        }
    }

    /**
     * [bitmap] fitted within [maxSide] and turned as the player shows it.
     * The retriever turns frames itself; a quarter-turned video whose frame
     * still has the stored shape is turned here, so either way the frame
     * matches the player. A half turn (180) is left to the retriever, which
     * applies every angle (AOSP's android_media_MediaMetadataRetriever.cpp
     * rotates by the frame's mRotationAngle): its shape cannot show whether
     * it was turned, and turning it here again would show it upside down.
     */
    private fun shown(bitmap: Bitmap, maxSide: Int): Bitmap {
        val landscapeShown = shownWidth >= shownHeight
        val landscapeNow = bitmap.width >= bitmap.height
        val turn = quarterTurn && landscapeShown != landscapeNow && naturalWidth != naturalHeight
        val degrees = if (turn) rotation else 0
        val longer = max(bitmap.width, bitmap.height)
        val scale = minOf(1.0, maxSide.toDouble() / longer).toFloat()
        if (degrees == 0 && scale == 1f) return bitmap
        val matrix = Matrix().apply {
            postScale(scale, scale)
            postRotate(degrees.toFloat())
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    companion object {
        /** Opens [path], a file path or a `content://` URI. */
        fun open(context: Context, path: String): VideoFrames {
            val retriever = MediaMetadataRetriever()
            try {
                if (path.startsWith("content://")) {
                    retriever.setDataSource(context, Uri.parse(path))
                } else {
                    retriever.setDataSource(path)
                }
                fun meta(key: Int) = retriever.extractMetadata(key)?.toIntOrNull()
                val width = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                val height = meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                val duration = meta(MediaMetadataRetriever.METADATA_KEY_DURATION)
                if (width == null || height == null || width <= 0 || height <= 0) {
                    throw FrameException("decode_failed", "no video track")
                }
                if (duration == null || duration < 0) {
                    throw FrameException("decode_failed", "no readable length")
                }
                val rotation = ((meta(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) ?: 0) % 360 + 360) % 360
                return VideoFrames(retriever, width, height, rotation, duration)
            } catch (e: Exception) {
                try {
                    retriever.release()
                } catch (_: Exception) {
                }
                if (e is FrameException) throw e
                throw FrameException("decode_failed", e.message ?: "the video could not be opened")
            }
        }
    }
}
