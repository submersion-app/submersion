package app.submersion.transcoder

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram

/** How the frames this effect sees encode light. */
enum class SignalTransfer { SDR, PQ, HLG }

/** One key of the app's colour timeline: a 4x5 matrix `timeMs` into the clip. */
class ColorTimelineKey(val timeMs: Double, val matrix: FloatArray)

/** The timeline, interpolated the way the Dart `ColorTimeline.matrixAt` does. */
class ColorTimeline(keys: List<ColorTimelineKey>) {
    private val keys = keys.sortedBy { it.timeMs }

    fun matrixAt(timeMs: Double): FloatArray {
        if (keys.isEmpty()) return IDENTITY
        if (timeMs <= keys.first().timeMs) return keys.first().matrix
        if (timeMs >= keys.last().timeMs) return keys.last().matrix
        // The first key at or after timeMs, by binary search: asked per frame.
        var low = 1
        var high = keys.size - 1
        while (low < high) {
            val mid = (low + high) ushr 1
            if (keys[mid].timeMs < timeMs) low = mid + 1 else high = mid
        }
        val lo = keys[low - 1]
        val hi = keys[low]
        val f = ((timeMs - lo.timeMs) / (hi.timeMs - lo.timeMs)).toFloat()
        return FloatArray(20) { lo.matrix[it] + (hi.matrix[it] - lo.matrix[it]) * f }
    }

    private companion object {
        val IDENTITY = floatArrayOf(
            1f, 0f, 0f, 0f, 0f,
            0f, 1f, 0f, 0f, 0f,
            0f, 0f, 1f, 0f, 0f,
            0f, 0f, 0f, 1f, 0f,
        )
    }
}

/**
 * Applies the colour timeline to every frame (issue #3521), with the one
 * formula `color_math.dart` pins. Media3 hands SDR frames over gamma-encoded
 * (the encoder asks for the original working colour space), so the matrix
 * works on them directly; HDR frames come linear in BT.2020 (PQ normalised
 * to 10,000 cd/m2, HLG as scene light), which the shader takes to the
 * extended sRGB space relative to SDR white and back.
 */
@UnstableApi
class ColorTimelineEffect(
    private val timeline: ColorTimeline,
    private val transfer: SignalTransfer,
) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram {
        // Media3 found HDR the container did not declare: which curve the
        // frames use is unknown, and SDR maths on linear light would come out
        // wrong, so the encode fails (and the diver is offered the original).
        if (useHdr && transfer == SignalTransfer.SDR) {
            throw VideoFrameProcessingException("HDR frames with an unknown transfer")
        }
        return ColorTimelineShaderProgram(
            timeline,
            if (useHdr) transfer else SignalTransfer.SDR,
            useHdr,
        )
    }
}

@UnstableApi
private class ColorTimelineShaderProgram(
    private val timeline: ColorTimeline,
    transfer: SignalTransfer,
    useHdr: Boolean,
) : BaseGlShaderProgram(useHdr, /* texturePoolCapacity= */ 1) {
    private val program = GlProgram(VERTEX, FRAGMENT)
    private val mode = transfer.ordinal.toFloat()

    init {
        program.setBufferAttribute(
            "aFramePosition",
            GlUtil.getNormalizedCoordinateBounds(),
            GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE,
        )
        program.setFloatsUniform("uTo709", columnMajor(TO_709))
        program.setFloatsUniform("uTo2020", columnMajor(TO_2020))
        program.setFloatUniform("uMode", mode)
    }

    override fun configure(inputWidth: Int, inputHeight: Int): Size = Size(inputWidth, inputHeight)

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        // Presentation time, as the player's position reads it, which is what
        // the app's timeline is sampled against.
        val m = timeline.matrixAt(presentationTimeUs / 1000.0)
        program.use()
        program.setSamplerTexIdUniform("uTexSampler", inputTexId, /* texUnitIndex= */ 0)
        for (row in 0 until 3) {
            program.setFloatsUniform(
                "uRow$row",
                floatArrayOf(
                    m[row * 5], m[row * 5 + 1], m[row * 5 + 2],
                    m[row * 5 + 3] + m[row * 5 + 4] / 255f,
                ),
            )
        }
        program.bindAttributesAndUniforms()
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GlUtil.checkGlError()
    }

    override fun release() {
        super.release()
        program.delete()
    }

    private companion object {
        // Linear BT.709 to BT.2020 (ITU-R BT.2087) and its exact inverse, as
        // in color_math.dart, row-major.
        val TO_2020 = doubleArrayOf(
            0.627403895934699, 0.329283038377884, 0.043313065687417,
            0.069097289358232, 0.919540395075459, 0.011362315566309,
            0.016391438875150, 0.088013307877226, 0.895595253247624,
        )
        val TO_709: DoubleArray = invert3(TO_2020)

        fun invert3(m: DoubleArray): DoubleArray {
            val (a, b, c) = Triple(m[0], m[1], m[2])
            val (d, e, f) = Triple(m[3], m[4], m[5])
            val (g, h, i) = Triple(m[6], m[7], m[8])
            val det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
            return doubleArrayOf(
                (e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det,
                (f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det,
                (d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det,
            )
        }

        /** GLSL matrices are column-major. */
        fun columnMajor(m: DoubleArray): FloatArray =
            FloatArray(9) { m[(it % 3) * 3 + it / 3].toFloat() }

        const val VERTEX = """
            attribute vec4 aFramePosition;
            varying vec2 vTexSamplingCoord;
            void main() {
              gl_Position = aFramePosition;
              vTexSamplingCoord = vec2(aFramePosition.x * 0.5 + 0.5, aFramePosition.y * 0.5 + 0.5);
            }
        """

        const val FRAGMENT = """
            precision highp float;
            uniform sampler2D uTexSampler;
            uniform vec4 uRow0;
            uniform vec4 uRow1;
            uniform vec4 uRow2;
            uniform float uMode;
            uniform mat3 uTo709;
            uniform mat3 uTo2020;
            varying vec2 vTexSamplingCoord;

            float srgbEnc(float l) {
              float x = abs(l);
              float v = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1.0 / 2.4) - 0.055;
              return l < 0.0 ? -v : v;
            }
            float srgbDec(float v) {
              float x = abs(v);
              float l = x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4);
              return v < 0.0 ? -l : l;
            }
            vec3 apply(vec3 c) {
              return vec3(dot(uRow0.xyz, c) + uRow0.w, dot(uRow1.xyz, c) + uRow1.w,
                dot(uRow2.xyz, c) + uRow2.w);
            }

            void main() {
              vec4 s = texture2D(uTexSampler, vTexSamplingCoord);
              if (uMode < 0.5) {
                gl_FragColor = vec4(clamp(apply(s.rgb), 0.0, 1.0), s.a);
                return;
              }
              // Media3's linear units to linear relative to SDR white: PQ is
              // normalised to 10,000 cd/m2 (SDR white 203), HLG is scene light
              // (SDR white at the 75% signal, 0.26496).
              float scale = uMode < 1.5 ? 10000.0 / 203.0 : 1.0 / 0.26496256042100724;
              vec3 l709 = uTo709 * (s.rgb * scale);
              vec3 e = vec3(srgbEnc(l709.r), srgbEnc(l709.g), srgbEnc(l709.b));
              vec3 k = apply(e);
              vec3 d = vec3(srgbDec(k.r), srgbDec(k.g), srgbDec(k.b));
              vec3 back = max(uTo2020 * d, 0.0) / scale;
              gl_FragColor = vec4(clamp(back, 0.0, 1.0), s.a);
            }
        """
    }
}
