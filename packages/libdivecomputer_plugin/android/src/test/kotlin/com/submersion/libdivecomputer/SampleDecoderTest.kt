package com.submersion.libdivecomputer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The JNI layer marshals each sample as a positional DoubleArray, a contract no
 * compiler checks on either side. These tests pin the indices (issue #810).
 */
class SampleDecoderTest {
    private fun sampleArray(): DoubleArray {
        val a = DoubleArray(SAMPLE_FIELD_COUNT) { Double.NaN }
        a[0] = 60000.0 // time_ms
        a[1] = 12.5 // depth
        a[4] = UINT32_SENTINEL.toDouble() // tank
        a[5] = UINT32_SENTINEL.toDouble() // heartbeat
        a[9] = UINT32_SENTINEL.toDouble() // rbt
        a[10] = UINT32_SENTINEL.toDouble() // deco_type
        a[11] = UINT32_SENTINEL.toDouble() // deco_time
        a[13] = UINT32_SENTINEL.toDouble() // deco_tts
        a[20] = UINT32_SENTINEL.toDouble() // gasmix
        a[21] = UINT32_SENTINEL.toDouble() // heading
        a[22] = 58.0 // cell 1 mV
        a[23] = 61.0 // cell 2 mV
        a[24] = 43.0 // cell 3 mV
        a[25] = UINT32_SENTINEL.toDouble()
        a[26] = UINT32_SENTINEL.toDouble()
        a[27] = UINT32_SENTINEL.toDouble()
        return a
    }

    @Test
    fun `millivolts decode from indices 22 through 27`() {
        val s = decodeProfileSample(sampleArray())
        assertEquals(58L, s.o2SensorMv1)
        assertEquals(61L, s.o2SensorMv2)
        assertEquals(43L, s.o2SensorMv3)
        assertNull(s.o2SensorMv4)
        assertNull(s.o2SensorMv5)
        assertNull(s.o2SensorMv6)
    }

    /** Appending must not disturb the fields that were already there. */
    @Test
    fun `appending millivolts leaves the earlier fields in place`() {
        val a = sampleArray()
        a[20] = 2.0 // gasmix
        a[21] = 175.0 // heading
        val s = decodeProfileSample(a)
        assertEquals(60L, s.timeSeconds)
        assertEquals(12.5, s.depthMeters, 1e-9)
        assertEquals(2L, s.gasMixIndex)
        assertEquals(175.0, s.heading!!, 1e-9)
    }

    /** A stale .so returns the old 22-wide array; decoding must not throw. */
    @Test
    fun `short array yields null millivolts`() {
        val s = decodeProfileSample(sampleArray().copyOf(22))
        assertNull(s.o2SensorMv1)
        assertNull(s.o2SensorMv6)
        assertEquals(12.5, s.depthMeters, 1e-9)
    }

    /** Zero is a real reading here: the C layer already mapped "absent" to the
     * sentinel, so the decoder must not treat 0 as missing. */
    @Test
    fun `zero millivolts decodes as zero not null`() {
        val a = sampleArray()
        a[22] = 0.0
        assertEquals(0L, decodeProfileSample(a).o2SensorMv1)
    }

    /** Issue #1223: a sample can carry one pressure per air-integrated
     * transmitter, packed one slot per tank from index 28. */
    @Test
    fun `tank pressures decode from index 28 onward`() {
        val a = sampleArray()
        a[28] = 192.6 // tank 0 (O2)
        a[29] = 191.4 // tank 1 (diluent)
        assertEquals(listOf(192.6, 191.4), decodeProfileSample(a).tankPressuresBar)
    }

    /** A transmitter out of comms leaves a hole, not a zero. */
    @Test
    fun `a tank with no reading decodes as null within the list`() {
        val a = sampleArray()
        a[29] = 191.4
        assertEquals(listOf(null, 191.4), decodeProfileSample(a).tankPressuresBar)
    }

    /** Trailing empty slots are trimmed, so a single-transmitter dive carries a
     * one-element list rather than a full LIBDC_MAX_TANKS one. */
    @Test
    fun `trailing empty tanks are trimmed`() {
        val a = sampleArray()
        a[28] = 200.0
        assertEquals(listOf(200.0), decodeProfileSample(a).tankPressuresBar)
    }

    /** A sample with no pressure at all carries no list. */
    @Test
    fun `all-NaN tank pressures decode as null`() {
        assertNull(decodeProfileSample(sampleArray()).tankPressuresBar)
    }

    /** A stale .so returns the pre-#1223 28-wide array; the Dart layer then
     * falls back to pressureBar/tankIndex rather than seeing a bogus list. */
    @Test
    fun `short array yields null tank pressures`() {
        val a = sampleArray()
        a[3] = 190.0 // pressure
        a[4] = 0.0 // tank
        val s = decodeProfileSample(a.copyOf(28))
        assertNull(s.tankPressuresBar)
        assertEquals(190.0, s.pressureBar!!, 1e-9)
        assertEquals(0L, s.tankIndex)
    }
}
