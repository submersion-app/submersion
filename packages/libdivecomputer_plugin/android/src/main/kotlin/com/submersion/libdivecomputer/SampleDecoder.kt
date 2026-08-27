package com.submersion.libdivecomputer

internal const val UINT32_SENTINEL: Long = 4294967295L // UINT32_MAX = unavailable

/** Per-sample pressure slots the JNI side packs. Mirrors LIBDC_MAX_TANKS in libdc_wrapper.h. */
internal const val LIBDC_MAX_TANKS = 16

/**
 * Field count marshalled per sample by nativeGetDiveSample. The JNI side packs
 * these positionally and must be changed together with this file. Append only:
 * inserting a field silently renumbers every field after it, with no error on
 * either side.
 */
internal const val SAMPLE_FIELD_COUNT = 28 + LIBDC_MAX_TANKS

/** Index of the first per-tank pressure slot. Matches LIBDC_TANK_PRESSURE_OFFSET in libdc_jni.cpp. */
private const val TANK_PRESSURE_OFFSET = 28

private fun sentinelLong(s: DoubleArray, i: Int): Long? =
    if (s[i].toLong() == UINT32_SENTINEL) null else s[i].toLong()

private fun cellMillivolt(s: DoubleArray, i: Int): Long? =
    if (s.size < 28) null else sentinelLong(s, i)

/**
 * Every tank's pressure at this sample, indexed by tank index, NaN decoded to
 * null. Trailing nulls are trimmed and an all-null sample decodes to null, so an
 * ordinary single-transmitter dive carries a one-element list per sample.
 *
 * Issue #1223: libdivecomputer reports one pressure per air-integrated
 * transmitter, so a sample can carry several and `pressureBar`/`tankIndex` keep
 * only the last of them.
 */
private fun tankPressures(s: DoubleArray): List<Double?>? {
    if (s.size < SAMPLE_FIELD_COUNT) return null
    val values = ArrayList<Double?>(LIBDC_MAX_TANKS)
    for (t in 0 until LIBDC_MAX_TANKS) {
        val v = s[TANK_PRESSURE_OFFSET + t]
        values.add(if (v.isNaN()) null else v)
    }
    while (values.isNotEmpty() && values.last() == null) {
        values.removeAt(values.size - 1)
    }
    return if (values.isEmpty()) null else values
}

/**
 * Decodes one positional sample array into a [ProfileSample]. Shared by the
 * BLE/USB host API and the serial download runner so the two cannot drift.
 */
internal fun decodeProfileSample(s: DoubleArray): ProfileSample = ProfileSample(
    timeSeconds = (s[0] / 1000.0).toLong(),
    depthMeters = s[1],
    temperatureCelsius = if (s[2].isNaN()) null else s[2],
    pressureBar = if (s[3].isNaN()) null else s[3],
    tankIndex = sentinelLong(s, 4),
    tankPressuresBar = tankPressures(s),
    heartRate = sentinelLong(s, 5),
    heading = if (s.size < 22 || s[21].toLong() == UINT32_SENTINEL) null else s[21],
    setpoint = if (s[6].isNaN()) null else s[6],
    ppo2 = if (s[7].isNaN()) null else s[7],
    cns = if (s[8].isNaN()) null else s[8],
    rbt = sentinelLong(s, 9),
    decoType = sentinelLong(s, 10),
    decoTime = sentinelLong(s, 11),
    decoDepth = if (s[12].isNaN()) null else s[12],
    tts = if (s[13].toLong() == UINT32_SENTINEL || s[13].toLong() == 0L) null else s[13].toLong(),
    o2Sensor1 = if (s[14].isNaN()) null else s[14],
    o2Sensor2 = if (s[15].isNaN()) null else s[15],
    o2Sensor3 = if (s[16].isNaN()) null else s[16],
    o2Sensor4 = if (s[17].isNaN()) null else s[17],
    o2Sensor5 = if (s[18].isNaN()) null else s[18],
    o2Sensor6 = if (s[19].isNaN()) null else s[19],
    o2SensorMv1 = cellMillivolt(s, 22),
    o2SensorMv2 = cellMillivolt(s, 23),
    o2SensorMv3 = cellMillivolt(s, 24),
    o2SensorMv4 = cellMillivolt(s, 25),
    o2SensorMv5 = cellMillivolt(s, 26),
    o2SensorMv6 = cellMillivolt(s, 27),
    gasMixIndex = sentinelLong(s, 20),
)
