package com.submersion.libdivecomputer

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DiveMarshalingTest {
    private fun sampleDive() = ParsedDive(
        fingerprint = "abcd",
        dateTimeYear = 2026, dateTimeMonth = 6, dateTimeDay = 30,
        dateTimeHour = 10, dateTimeMinute = 30, dateTimeSecond = 0,
        dateTimeTimezoneOffset = null,
        maxDepthMeters = 30.5, avgDepthMeters = 18.2, durationSeconds = 2400,
        minTemperatureCelsius = 12.0, maxTemperatureCelsius = 24.0,
        samples = listOf(
            ProfileSample(
                timeSeconds = 60, depthMeters = 5.0, temperatureCelsius = 22.0,
                pressureBar = 190.0, tankIndex = 0, heartRate = null, setpoint = null,
                ppo2 = null, cns = 0.0, rbt = null, decoType = null, decoTime = null,
                decoDepth = null, tts = null, o2Sensor1 = null, o2Sensor2 = null,
                o2Sensor3 = null, o2Sensor4 = null, o2Sensor5 = null, o2Sensor6 = null,
                gasMixIndex = 0,
            ),
        ),
        tanks = listOf(TankInfo(0, 0, 12.0, 200.0, 50.0)),
        gasMixes = listOf(GasMix(0, 32.0, 0.0)),
        events = listOf(DiveEvent(120, "gaschange", mapOf("mix" to "1"))),
        diveMode = "oc", decoAlgorithm = null, gfLow = null, gfHigh = null,
        decoConservatism = null, rawData = byteArrayOf(9, 8, 7), rawFingerprint = null,
        entryLatitude = null, entryLongitude = null, exitLatitude = null, exitLongitude = null,
    )

    @Test
    fun encodesAndDecodesBackToEqualDive() {
        val dive = sampleDive()
        val restored = DiveMarshaling.decode(DiveMarshaling.encode(dive))

        assertEquals(dive.fingerprint, restored.fingerprint)
        assertEquals(dive.maxDepthMeters, restored.maxDepthMeters, 0.0)
        assertEquals(dive.durationSeconds, restored.durationSeconds)
        assertEquals(1, restored.samples.size)
        assertEquals(5.0, restored.samples[0].depthMeters, 0.0)
        assertEquals(1, restored.tanks.size)
        // volumeLiters is nullable on the wire, so a dropped field and a wrong
        // value are distinct regressions. Assert non-null first: otherwise a
        // dropped field surfaces as an NPE that reads like a broken test.
        val volumeLiters = restored.tanks[0].volumeLiters
        assertNotNull("volumeLiters did not survive marshaling", volumeLiters)
        assertEquals(12.0, volumeLiters!!, 0.0)
        assertEquals("gaschange", restored.events[0].type)
        assertArrayEquals(byteArrayOf(9, 8, 7), restored.rawData)
    }
}
