package com.submersion.libdivecomputer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins [libdcClockSyncStatusName] to `libdc_clock_sync_status_t` in
 * `macos/Classes/libdc_wrapper.h`. The C table is checked against the enum by
 * `test/native/test_event_type_names.c`; this JVM twin cannot see the header,
 * so the values are spelled out here and must be kept in step.
 */
class LibdcDownloadInfoTest {
    @Test
    fun clockSyncStatusNamesFollowTheCEnum() {
        assertEquals("not_requested", libdcClockSyncStatusName(0))
        assertEquals("synced", libdcClockSyncStatusName(1))
        assertEquals("unsupported", libdcClockSyncStatusName(2))
        assertEquals("failed", libdcClockSyncStatusName(3))
        assertEquals("unknown", libdcClockSyncStatusName(4))
        assertEquals("unknown", libdcClockSyncStatusName(-1))
    }

    @Test
    fun deviceInfoIsFormattedUnsignedAndZeroMeansAbsent() {
        assertNull(libdcUnsignedOrNull(0))
        assertEquals("74691", libdcUnsignedOrNull(74691))
        // A serial above 2^31 arrives as a negative Int through JNI.
        assertEquals("4294967295", libdcUnsignedOrNull(-1))
    }
}
