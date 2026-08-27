package com.submersion.libdivecomputer

import android.os.Parcel
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SerialDownloadRequestTest {
    @Test
    fun roundTripsThroughParcel() {
        val original = SerialDownloadRequest(
            vendor = "Mares", product = "Puck Pro", model = 0x18,
            name = "Puck Pro", fingerprint = byteArrayOf(1, 2, 3),
        )
        val parcel = Parcel.obtain()
        original.writeToParcel(parcel, 0)
        parcel.setDataPosition(0)
        val restored = SerialDownloadRequest.createFromParcel(parcel)
        parcel.recycle()

        assertEquals("Mares", restored.vendor)
        assertEquals("Puck Pro", restored.product)
        assertEquals(0x18L, restored.model)
        assertEquals("Puck Pro", restored.name)
        assertArrayEquals(byteArrayOf(1, 2, 3), restored.fingerprint)
    }

    @Test
    fun roundTripsNulls() {
        val original = SerialDownloadRequest("v", "p", 1, null, null)
        val parcel = Parcel.obtain()
        original.writeToParcel(parcel, 0)
        parcel.setDataPosition(0)
        val restored = SerialDownloadRequest.createFromParcel(parcel)
        parcel.recycle()
        assertEquals(null, restored.name)
        assertEquals(null, restored.fingerprint)
    }
}
