package com.submersion.libdivecomputer

import android.content.Context
import android.hardware.usb.UsbManager
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialProber

private const val RUNNER_LIBDC_TRANSPORT_SERIAL = 1 shl 0
private const val RUNNER_LIBDC_STATUS_CANCELLED = -10
private const val RUNNER_UINT32_SENTINEL: Long = 4294967295L  // UINT32_MAX = unavailable

/**
 * Runs the serial dive-computer download inside the :dc process. A native
 * SIGSEGV here kills only :dc; the main process detects it and reports an error
 * (see SerialDownloadClient). Adapted from DiveComputerHostApiImpl's in-process
 * serial download; emits results through the AIDL callback instead of Pigeon.
 *
 * NOTE: convertParsedDive / mapEventType below are duplicated verbatim from
 * DiveComputerHostApiImpl (they read the native dive pointer, which is valid in
 * whichever process owns it). FOLLOW-UP: once this branch builds in CI, extract
 * them into a shared `DiveConverter` object used by both the BLE (in-process)
 * and serial (:dc) paths, to remove the duplication.
 */
class SerialDownloadRunner(private val context: Context) {

    @Volatile private var sessionPtr: Long = 0

    // Buffering across the multi-port probe, exactly as the in-process version:
    // dives accumulate while probing >1 adapter so a wrong port cannot leak
    // phantom dives; flushed on success, discarded on failure.
    private val diveBufferLock = Any()
    private var isBufferingDives = false
    private val bufferedDives = mutableListOf<ParsedDive>()

    fun cancel() {
        val ptr = sessionPtr
        if (ptr != 0L) LibdcWrapper.nativeDownloadCancel(ptr)
    }

    fun run(request: SerialDownloadRequest, cb: IDiveDownloadCallback) {
        NativeTrace.init(context)
        if (LibdcWrapper.loadError != null) {
            cb.onError("native_unavailable",
                "The dive-computer engine failed to load. Please update Submersion.")
            return
        }
        val session = LibdcWrapper.nativeDownloadSessionNew()
        if (session == 0L) {
            cb.onError("download_error", "Could not start a download session.")
            return
        }
        sessionPtr = session
        try {
            runProbe(request, session, cb)
        } finally {
            LibdcWrapper.nativeDownloadSessionFree(session)
            sessionPtr = 0
        }
    }

    private fun runProbe(request: SerialDownloadRequest, session: Long, cb: IDiveDownloadCallback) {
        val usbManager = context.getSystemService(Context.USB_SERVICE) as? UsbManager
        val drivers: List<UsbSerialDriver> = usbManager?.let {
            UsbSerialProber.getDefaultProber().findAllDrivers(it)
        } ?: emptyList()

        if (drivers.isEmpty()) {
            cb.onError("no_serial_ports",
                "No USB serial ports found. Is the dive computer connected and powered on?")
            return
        }

        val fingerprintBytes = request.fingerprint?.takeIf { it.isNotEmpty() }
        val buffering = drivers.size > 1
        synchronized(diveBufferLock) { isBufferingDives = buffering; bufferedDives.clear() }

        val downloadCallback = object : DownloadCallback {
            override fun onProgress(current: Int, maximum: Int) {
                cb.onProgress(current, maximum)
            }
            override fun onDive(divePtr: Long) {
                val parsed = convertParsedDive(divePtr)
                val buffered = synchronized(diveBufferLock) {
                    if (isBufferingDives) { bufferedDives.add(parsed); true } else false
                }
                if (!buffered) cb.onDive(DiveMarshaling.encode(parsed))
            }
        }

        val probeLog = StringBuilder()
        var anyOpened = false
        var lastResult = -1
        var lastErrorMsg = ""

        for (driver in drivers) {
            synchronized(diveBufferLock) { bufferedDives.clear() }
            val stream = UsbSerialIoStream(context, driver)
            val probeDev = driver.device
            NativeTrace.d(
                "probe ${driver.javaClass.simpleName} " +
                    "vid=0x${Integer.toHexString(probeDev.vendorId)} " +
                    "pid=0x${Integer.toHexString(probeDev.productId)} name=${probeDev.deviceName}"
            )
            if (!stream.open()) {
                NativeTrace.w("stream.open() failed for ${probeDev.deviceName}")
                probeLog.append("  ${probeDev.deviceName}: failed to open\n")
                continue
            }
            anyOpened = true
            val errorBuf = ByteArray(256)
            var thrownMsg: String? = null
            NativeTrace.d("nativeDownloadRun begin vendor=${request.vendor} product=${request.product} model=${request.model}")
            val result = try {
                LibdcWrapper.nativeDownloadRun(
                    session, request.vendor, request.product,
                    request.model.toInt(), RUNNER_LIBDC_TRANSPORT_SERIAL,
                    stream, request.name, fingerprintBytes, downloadCallback, errorBuf
                )
            } catch (e: Throwable) {
                NativeTrace.e("nativeDownloadRun threw: ${e.message}")
                thrownMsg = e.message
                -999
            }
            NativeTrace.d("nativeDownloadRun returned rc=$result")
            stream.close()
            lastResult = result
            lastErrorMsg = String(errorBuf, Charsets.UTF_8).takeWhile { it.code != 0 }
                .ifEmpty { thrownMsg ?: "Download failed (rc=$result)" }
            if (result == 0 || result == RUNNER_LIBDC_STATUS_CANCELLED) break
            probeLog.append("  ${probeDev.deviceName}: download failed (rc=$result)\n")
        }

        val divesToFlush: List<ParsedDive> = synchronized(diveBufferLock) {
            val succeeded = lastResult == 0 || lastResult == RUNNER_LIBDC_STATUS_CANCELLED
            val list = if (succeeded) ArrayList(bufferedDives) else emptyList()
            bufferedDives.clear(); isBufferingDives = false; list
        }
        for (dive in divesToFlush) cb.onDive(DiveMarshaling.encode(dive))

        when {
            !anyOpened ->
                cb.onError("connect_failed", "No dive computer found. Ports tried:\n$probeLog")
            lastResult == 0 || lastResult == RUNNER_LIBDC_STATUS_CANCELLED ->
                cb.onComplete(divesToFlush.size.toLong())
            drivers.size > 1 ->
                cb.onError("connect_failed", "No dive computer found. Ports tried:\n$probeLog")
            else ->
                cb.onError("download_error", lastErrorMsg)
        }
    }

    // ---- Duplicated verbatim from DiveComputerHostApiImpl (see class note) ----

    private fun convertParsedDive(divePtr: Long): ParsedDive {
        val fingerprint = LibdcWrapper.nativeGetDiveFingerprint(divePtr)

        // Pass raw datetime components through to Dart.
        // Map DC_TIMEZONE_NONE (INT_MIN) to null.
        val timezone = LibdcWrapper.nativeGetDiveTimezone(divePtr)
        val timezoneOffset: Long? = if (timezone == Int.MIN_VALUE) null else timezone.toLong()

        // Convert samples.
        val sampleCount = LibdcWrapper.nativeGetDiveSampleCount(divePtr)
        val samples = (0 until sampleCount).mapNotNull { i ->
            val s = LibdcWrapper.nativeGetDiveSample(divePtr, i) ?: return@mapNotNull null
            ProfileSample(
                timeSeconds = (s[0] / 1000.0).toLong(),
                depthMeters = s[1],
                temperatureCelsius = if (s[2].isNaN()) null else s[2],
                pressureBar = if (s[3].isNaN()) null else s[3],
                tankIndex = if (s[4].toLong() == RUNNER_UINT32_SENTINEL) null else s[4].toLong(),
                heartRate = if (s[5].toLong() == RUNNER_UINT32_SENTINEL) null else s[5].toLong(),
                setpoint = if (s[6].isNaN()) null else s[6],
                ppo2 = if (s[7].isNaN()) null else s[7],
                cns = if (s[8].isNaN()) null else s[8],
                rbt = if (s[9].toLong() == RUNNER_UINT32_SENTINEL) null else s[9].toLong(),
                decoType = if (s[10].toLong() == RUNNER_UINT32_SENTINEL) null else s[10].toLong(),
                decoTime = if (s[11].toLong() == RUNNER_UINT32_SENTINEL) null else s[11].toLong(),
                decoDepth = if (s[12].isNaN()) null else s[12],
                tts = if (s[13].toLong() == RUNNER_UINT32_SENTINEL || s[13].toLong() == 0L) null else s[13].toLong(),
                o2Sensor1 = if (s[14].isNaN()) null else s[14],
                o2Sensor2 = if (s[15].isNaN()) null else s[15],
                o2Sensor3 = if (s[16].isNaN()) null else s[16],
                o2Sensor4 = if (s[17].isNaN()) null else s[17],
                o2Sensor5 = if (s[18].isNaN()) null else s[18],
                o2Sensor6 = if (s[19].isNaN()) null else s[19],
                gasMixIndex = if (s[20].toLong() == RUNNER_UINT32_SENTINEL) null else s[20].toLong(),
            )
        }

        // Convert gas mixes.
        val gasmixCount = LibdcWrapper.nativeGetDiveGasmixCount(divePtr)
        val gasMixes = (0 until gasmixCount).mapNotNull { i ->
            val gm = LibdcWrapper.nativeGetDiveGasmix(divePtr, i) ?: return@mapNotNull null
            GasMix(
                index = i.toLong(),
                o2Percent = gm[0] * 100.0,
                hePercent = gm[1] * 100.0
            )
        }

        // Convert tanks.
        val tankCount = LibdcWrapper.nativeGetDiveTankCount(divePtr)
        val tanks = (0 until tankCount).mapNotNull { i ->
            val tk = LibdcWrapper.nativeGetDiveTank(divePtr, i) ?: return@mapNotNull null
            TankInfo(
                index = i.toLong(),
                gasMixIndex = tk[0].toLong(),
                volumeLiters = if (tk[1] > 0) tk[1] else null,
                startPressureBar = if (tk[3] > 0) tk[3] else null,
                endPressureBar = if (tk[4] > 0) tk[4] else null
            )
        }

        // Map dive mode.
        val diveMode = when (LibdcWrapper.nativeGetDiveMode(divePtr)) {
            0 -> "freedive"
            1 -> "gauge"
            2 -> "open_circuit"
            3 -> "ccr"
            4 -> "scr"
            else -> null
        }

        val maxDepth = LibdcWrapper.nativeGetDiveMaxDepth(divePtr)
        val avgDepth = LibdcWrapper.nativeGetDiveAvgDepth(divePtr)
        val minTemp = LibdcWrapper.nativeGetDiveMinTemp(divePtr)
        val maxTemp = LibdcWrapper.nativeGetDiveMaxTemp(divePtr)
        val entryLat = LibdcWrapper.nativeGetDiveEntryLatitude(divePtr)
        val entryLon = LibdcWrapper.nativeGetDiveEntryLongitude(divePtr)
        val exitLat = LibdcWrapper.nativeGetDiveExitLatitude(divePtr)
        val exitLon = LibdcWrapper.nativeGetDiveExitLongitude(divePtr)

        // Convert events.
        val eventCount = LibdcWrapper.nativeGetDiveEventCount(divePtr)
        val events = (0 until eventCount).mapNotNull { i ->
            val e = LibdcWrapper.nativeGetDiveEvent(divePtr, i) ?: return@mapNotNull null
            if (e[1] == 0L) return@mapNotNull null  // skip EVENT_NONE
            DiveEvent(
                timeSeconds = e[0] / 1000,
                type = mapEventType(e[1].toInt()),
                data = mapOf("flags" to e[2].toString(), "value" to e[3].toString())
            )
        }

        // Convert deco model.
        val decoInfo = LibdcWrapper.nativeGetDiveDecoModel(divePtr)
        val decoAlgorithm = decoInfo?.let {
            when (it[0]) {
                1 -> "buhlmann"
                2 -> "vpm"
                3 -> "rgbm"
                4 -> "dciem"
                else -> null
            }
        }
        val gfLow = decoInfo?.let { if (it[2] == 0) null else it[2].toLong() }
        val gfHigh = decoInfo?.let { if (it[3] == 0) null else it[3].toLong() }
        val decoConservatism = decoInfo?.let { if (it[1] == 0) null else it[1].toLong() }

        // Copy raw dive data bytes if available.
        val rawData = LibdcWrapper.nativeGetDiveRawData(divePtr)
        val rawFingerprint = LibdcWrapper.nativeGetDiveRawFingerprint(divePtr)

        return ParsedDive(
            fingerprint = fingerprint,
            dateTimeYear = LibdcWrapper.nativeGetDiveYear(divePtr).toLong(),
            dateTimeMonth = LibdcWrapper.nativeGetDiveMonth(divePtr).toLong(),
            dateTimeDay = LibdcWrapper.nativeGetDiveDay(divePtr).toLong(),
            dateTimeHour = LibdcWrapper.nativeGetDiveHour(divePtr).toLong(),
            dateTimeMinute = LibdcWrapper.nativeGetDiveMinute(divePtr).toLong(),
            dateTimeSecond = LibdcWrapper.nativeGetDiveSecond(divePtr).toLong(),
            dateTimeTimezoneOffset = timezoneOffset,
            maxDepthMeters = maxDepth,
            avgDepthMeters = avgDepth,
            durationSeconds = LibdcWrapper.nativeGetDiveDuration(divePtr).toLong(),
            minTemperatureCelsius = if (minTemp.isNaN()) null else minTemp,
            maxTemperatureCelsius = if (maxTemp.isNaN()) null else maxTemp,
            entryLatitude = if (entryLat.isNaN()) null else entryLat,
            entryLongitude = if (entryLon.isNaN()) null else entryLon,
            exitLatitude = if (exitLat.isNaN()) null else exitLat,
            exitLongitude = if (exitLon.isNaN()) null else exitLon,
            samples = samples,
            tanks = tanks,
            gasMixes = gasMixes,
            events = events,
            diveMode = diveMode,
            decoAlgorithm = decoAlgorithm,
            gfLow = gfLow,
            gfHigh = gfHigh,
            decoConservatism = decoConservatism,
            rawData = rawData,
            rawFingerprint = rawFingerprint
        )
    }

    private fun mapEventType(type: Int): String = when (type) {
        0 -> "none"
        1 -> "deco"
        2 -> "ascent"
        3 -> "ceiling"
        4 -> "workload"
        5 -> "transmitter"
        6 -> "violation"
        7 -> "bookmark"
        8 -> "surface"
        9 -> "safetystop"
        10 -> "gaschange"
        11 -> "safetystop_voluntary"
        12 -> "safetystop_mandatory"
        13 -> "deepstop"
        14 -> "ceiling_safetystop"
        15 -> "floor"
        16 -> "divetime"
        17 -> "maxdepth"
        18 -> "OLF"
        19 -> "PO2"
        20 -> "airtime"
        21 -> "rgbm"
        22 -> "heading"
        23 -> "tissuelevel"
        24 -> "gaschange2"
        else -> "unknown_$type"
    }
}
