package com.submersion.libdivecomputer

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

// Exercises the nativeParseRawDive / nativeParsedDiveFree JNI boundary against
// a real Shearwater Teric raw dive blob. Instrumented rather than a plain JVM
// test because it needs ART and liblibdc_jni.so.
@RunWith(AndroidJUnit4::class)
class RawDiveParseTest {
    private lateinit var rawDive: ByteArray

    @Before
    fun setUp() {
        assertNull("native library failed to load", LibdcWrapper.loadError)
        rawDive = InstrumentationRegistry.getInstrumentation().context
            .assets.open(FIXTURE).use { it.readBytes() }
        assertEquals(22144, rawDive.size)
    }

    @Test
    fun parsesFixtureIntoExpectedFields() {
        val errorBuf = ByteArray(256)
        val ptr = LibdcWrapper.nativeParseRawDive(VENDOR, PRODUCT, MODEL, rawDive, errorBuf)
        assertNotEquals(errorMessage(errorBuf), 0L, ptr)
        try {
            assertEquals(28.55976, LibdcWrapper.nativeGetDiveMaxDepth(ptr), 0.001)
            assertEquals(1256, LibdcWrapper.nativeGetDiveDuration(ptr))
            assertEquals(2026, LibdcWrapper.nativeGetDiveYear(ptr))
            assertEquals(5, LibdcWrapper.nativeGetDiveMonth(ptr))
            assertEquals(3, LibdcWrapper.nativeGetDiveDay(ptr))
            assertEquals(15, LibdcWrapper.nativeGetDiveHour(ptr))
            assertEquals(8, LibdcWrapper.nativeGetDiveMinute(ptr))
            assertEquals(41, LibdcWrapper.nativeGetDiveSecond(ptr))
            assertTrue(LibdcWrapper.nativeGetDiveSampleCount(ptr) > 0)
        } finally {
            LibdcWrapper.nativeParsedDiveFree(ptr)
        }
    }

    @Test
    fun unknownDescriptorReturnsZeroAndWritesError() {
        val errorBuf = ByteArray(256)
        val ptr = LibdcWrapper.nativeParseRawDive(
            "Nonexistent", "Device", 0, rawDive, errorBuf
        )
        assertEquals(0L, ptr)
        assertTrue(errorMessage(errorBuf).contains("No descriptor"))
    }

    // A truncated blob must fail cleanly (or parse to a freeable handle) rather
    // than read past the end of the buffer.
    @Test
    fun truncatedDataDoesNotCrash() {
        val ptr = LibdcWrapper.nativeParseRawDive(
            VENDOR, PRODUCT, MODEL, rawDive.copyOf(32), ByteArray(256)
        )
        LibdcWrapper.nativeParsedDiveFree(ptr)
    }

    // Repeated parse/free must not accumulate native memory: nativeParsedDiveFree
    // has to release samples and events, not just the struct.
    @Test
    fun repeatedParseAndFreeSucceeds() {
        repeat(50) {
            val ptr = LibdcWrapper.nativeParseRawDive(
                VENDOR, PRODUCT, MODEL, rawDive, ByteArray(256)
            )
            assertNotEquals(0L, ptr)
            LibdcWrapper.nativeParsedDiveFree(ptr)
        }
    }

    // errorBuf is a fixed 256-byte C buffer; strip the NUL padding.
    private fun errorMessage(errorBuf: ByteArray) = String(errorBuf).trim('\u0000')

    private companion object {
        const val FIXTURE = "shearwater_teric_dive.bin"
        const val VENDOR = "Shearwater"
        const val PRODUCT = "Teric"
        const val MODEL = 8
    }
}
