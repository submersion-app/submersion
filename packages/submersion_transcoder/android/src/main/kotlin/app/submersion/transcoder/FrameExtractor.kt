package app.submersion.transcoder

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import java.io.ByteArrayOutputStream

/**
 * Reads still frames out of a video at chosen times, for the app's
 * per-moment colour correction (issue #3520). Read-only: the retriever
 * opens the video and never writes it.
 */
object FrameExtractor {
    /**
     * JPEG bytes for each of [timesMs], fitted inside [maxDimension] square,
     * or null for a time that could not be read. Blocking; call it off the
     * main thread. [path] is a file path or a `content://` URI.
     */
    fun extract(
        context: Context,
        path: String,
        timesMs: List<Int>,
        maxDimension: Int,
        exact: Boolean = false,
    ): List<ByteArray?> {
        val retriever = MediaMetadataRetriever()
        try {
            if (path.startsWith("content://")) {
                retriever.setDataSource(context, Uri.parse(path))
            } else {
                retriever.setDataSource(path)
            }
            return timesMs.map { ms -> frameAt(retriever, ms, maxDimension, exact) }
        } catch (e: Exception) {
            return timesMs.map { null }
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }
    }

    private fun frameAt(
        retriever: MediaMetadataRetriever,
        ms: Int,
        maxDimension: Int,
        exact: Boolean,
    ): ByteArray? {
        val us = ms.toLong() * 1000
        // A nearby keyframe is close enough for colour statistics, and far
        // faster; a white-point pick needs the paused frame itself.
        val option = if (exact) {
            MediaMetadataRetriever.OPTION_CLOSEST
        } else {
            MediaMetadataRetriever.OPTION_CLOSEST_SYNC
        }
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= 27) {
                retriever.getScaledFrameAtTime(us, option, maxDimension, maxDimension)
            } else {
                retriever.getFrameAtTime(us, option)?.let { fit(it, maxDimension) }
            }
        } catch (e: Exception) {
            null
        } ?: return null
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    private fun fit(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val longest = maxOf(bitmap.width, bitmap.height)
        if (longest <= maxDimension) return bitmap
        val scale = maxDimension.toFloat() / longest
        val scaled = Bitmap.createScaledBitmap(
            bitmap,
            maxOf(1, (bitmap.width * scale).toInt()),
            maxOf(1, (bitmap.height * scale).toInt()),
            true,
        )
        bitmap.recycle()
        return scaled
    }
}
