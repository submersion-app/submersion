package com.submersion.libdivecomputer

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.hardware.usb.UsbManager
import android.os.Handler
import android.os.Looper
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialProber
import io.flutter.plugin.common.BinaryMessenger
import java.util.concurrent.Executors

// Transport bitmask values matching libdc_wrapper.h.
private const val LIBDC_TRANSPORT_SERIAL = 1 shl 0
private const val LIBDC_TRANSPORT_USB = 1 shl 1
private const val LIBDC_TRANSPORT_USBHID = 1 shl 2
private const val LIBDC_TRANSPORT_IRDA = 1 shl 3
private const val LIBDC_TRANSPORT_BLE = 1 shl 5

private const val LIBDC_STATUS_CANCELLED = -10
private const val UINT32_SENTINEL: Long = 4294967295L  // UINT32_MAX = unavailable
private const val GATT_INSUFFICIENT_AUTHENTICATION = 5

private const val TAG = "DiveComputerHost"

// Bluetooth permissions are requested at the Dart layer before BLE methods are called.
@SuppressLint("MissingPermission")
class DiveComputerHostApiImpl(
    private val context: Context,
    private val messenger: BinaryMessenger
) : DiveComputerHostApi {

    private val flutterApi = DiveComputerFlutterApi(messenger).also {
        NativeLogger.setFlutterApi(it)
    }
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var bleScanner: BleScanner? = null
    private var downloadSessionPtr: Long = 0
    private var activeBleStream: BleIoStream? = null
    private var activeSerialStream: UsbSerialIoStream? = null

    // Dive buffering for the multi-port USB-serial probe (see macOS parity).
    // While buffering, onDive accumulates instead of dispatching so dives from a
    // wrong port are not leaked to Flutter; flushed on success, discarded on
    // failure. Guarded because onDive fires on libdivecomputer's download thread.
    private val diveBufferLock = Any()
    private var isBufferingDives = false
    private val bufferedDives = mutableListOf<ParsedDive>()

    // MARK: - Device Descriptors

    override fun getDeviceDescriptors(callback: (Result<List<DeviceDescriptor>>) -> Unit) {
        executor.execute {
            // If the native library failed to load, return an empty list rather
            // than crashing on the native call below (issue #318). The download
            // path surfaces the user-facing error.
            if (LibdcWrapper.loadError != null) {
                NativeLogger.e(
                    TAG, "LDC",
                    "getDeviceDescriptors: native library unavailable: " +
                        "${LibdcWrapper.loadError?.javaClass?.simpleName}"
                )
                callback(Result.success(emptyList()))
                return@execute
            }
            val descriptors = mutableListOf<DeviceDescriptor>()
            val iterPtr = LibdcWrapper.nativeDescriptorIteratorNew()
            if (iterPtr == 0L) {
                callback(Result.success(emptyList()))
                return@execute
            }

            val info = DescriptorInfo()
            while (LibdcWrapper.nativeDescriptorIteratorNext(iterPtr, info) == 0) {
                descriptors.add(
                    DeviceDescriptor(
                        vendor = info.vendor,
                        product = info.product,
                        model = info.model.toLong(),
                        transports = mapTransports(info.transports)
                    )
                )
            }

            LibdcWrapper.nativeDescriptorIteratorFree(iterPtr)
            callback(Result.success(descriptors))
        }
    }

    private fun mapTransports(bitmask: Int): List<TransportType> {
        val transports = mutableListOf<TransportType>()
        if (bitmask and LIBDC_TRANSPORT_BLE != 0) transports.add(TransportType.BLE)
        if (bitmask and LIBDC_TRANSPORT_USB != 0 ||
            bitmask and LIBDC_TRANSPORT_USBHID != 0
        ) {
            transports.add(TransportType.USB)
        }
        if (bitmask and LIBDC_TRANSPORT_SERIAL != 0) transports.add(TransportType.SERIAL)
        if (bitmask and LIBDC_TRANSPORT_IRDA != 0) transports.add(TransportType.INFRARED)
        return transports
    }

    // MARK: - Discovery

    override fun startDiscovery(
        transport: TransportType,
        callback: (Result<Unit>) -> Unit
    ) {
        try {
            when (transport) {
                TransportType.BLE -> startBleDiscovery()
                else -> reportError("unsupported_transport",
                    "Transport $transport not yet supported on Android")
            }
            callback(Result.success(Unit))
        } catch (e: SecurityException) {
            callback(Result.failure(
                FlutterError("permission_denied",
                    "Bluetooth permission not granted. Please allow Bluetooth access in Settings.",
                    e.message)))
        } catch (e: Exception) {
            callback(Result.failure(
                FlutterError("discovery_error",
                    "Failed to start discovery: ${e.message}",
                    e.message)))
        }
    }

    override fun stopDiscovery() {
        bleScanner?.stop()
        bleScanner = null
    }

    private fun startBleDiscovery() {
        // BleScanner identifies devices via LibdcWrapper.nativeDescriptorMatch on
        // the (async) scan-result thread. Bail with a clear error if the native
        // library never loaded, rather than crashing there (issue #318).
        if (!nativeLibraryReady()) return

        val scanner = BleScanner(context)
        scanner.onDeviceDiscovered = { device ->
            mainHandler.post { flutterApi.onDeviceDiscovered(device) { } }
        }
        scanner.onComplete = {
            mainHandler.post { flutterApi.onDiscoveryComplete { } }
        }
        bleScanner = scanner
        scanner.start()
    }

    // MARK: - Download

    override fun startDownload(
        device: DiscoveredDevice,
        fingerprint: String?,
        callback: (Result<Unit>) -> Unit
    ) {
        callback(Result.success(Unit))

        executor.execute {
            // Backstop: convert any native-level failure into a reported error
            // instead of an uncaught Throwable that kills the executor thread
            // and the app (issue #318).
            try {
                performDownload(device, fingerprint)
            } catch (t: Throwable) {
                NativeLogger.e(
                    TAG, "LDC",
                    "download crashed: ${t.javaClass.simpleName}: ${t.message}"
                )
                reportError(
                    "download_error",
                    "Download failed unexpectedly (${t.javaClass.simpleName})."
                )
            }
        }
    }

    override fun cancelDownload() {
        if (downloadSessionPtr != 0L) {
            LibdcWrapper.nativeDownloadCancel(downloadSessionPtr)
        }
    }

    override fun submitPinCode(pinCode: String) {
        activeBleStream?.submitPinCode(pinCode)
    }

    private fun performDownload(device: DiscoveredDevice, fingerprint: String? = null, isRetry: Boolean = false) {
        // Fail clearly if the native library never loaded, rather than crashing
        // on the first native call below (issue #318).
        if (!nativeLibraryReady()) return

        // Create download session.
        val sessionPtr = LibdcWrapper.nativeDownloadSessionNew()
        if (sessionPtr == 0L) {
            reportError("session_failed", "Failed to create download session")
            return
        }
        downloadSessionPtr = sessionPtr

        // Dispatch by transport. Exhaustive (no `else`) on purpose so a future
        // transport must be handled explicitly rather than silently mis-routed.
        // Each branch owns its own session cleanup.
        when (device.transport) {
            TransportType.BLE ->
                performBleDownload(device, sessionPtr, fingerprint, isRetry)
            TransportType.SERIAL, TransportType.USB ->
                // Serial-over-USB (e.g. Mares Puck Pro). The Dart layer folds
                // libdivecomputer's serial transport into `.usb`, so both route
                // here and download over LIBDC_TRANSPORT_SERIAL.
                performUsbSerialDownload(device, sessionPtr, fingerprint)
            TransportType.INFRARED -> {
                reportError("unsupported_transport", "Infrared transport is not supported on Android")
                LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
                downloadSessionPtr = 0
            }
        }
    }

    // Progress/dive callbacks shared by the BLE and serial paths. onDive buffers
    // instead of dispatching while a multi-port serial probe is in progress.
    private fun makeDownloadCallback(): DownloadCallback = object : DownloadCallback {
        override fun onProgress(current: Int, maximum: Int) {
            val progress = DownloadProgress(
                current = current.toLong(),
                total = maximum.toLong(),
                status = "downloading"
            )
            mainHandler.post { flutterApi.onDownloadProgress(progress) { } }
        }

        override fun onDive(divePtr: Long) {
            val parsedDive = convertParsedDive(divePtr)
            val buffering = synchronized(diveBufferLock) {
                if (isBufferingDives) {
                    bufferedDives.add(parsedDive)
                    true
                } else {
                    false
                }
            }
            if (!buffering) {
                mainHandler.post { flutterApi.onDiveDownloaded(parsedDive) { } }
            }
        }
    }

    // Decode hex fingerprint to ByteArray for libdivecomputer (incremental download).
    private fun decodeFingerprint(fingerprint: String?): ByteArray? =
        fingerprint?.takeIf { it.isNotEmpty() }?.let { hex ->
            hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        }

    private fun performBleDownload(
        device: DiscoveredDevice,
        sessionPtr: Long,
        fingerprint: String?,
        isRetry: Boolean
    ) {
        // Connect BLE.
        val bluetoothManager =
            context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bluetoothManager?.adapter
        val btDevice = adapter?.getRemoteDevice(device.address)
        if (btDevice == null) {
            reportError("not_found", "Device not found")
            LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
            downloadSessionPtr = 0
            return
        }

        val bleStream = BleIoStream(context, btDevice)
        activeBleStream = bleStream

        bleStream.onPinRequired = { address ->
            flutterApi.onPinCodeRequired(address) {}
        }

        if (!bleStream.connectAndDiscover()) {
            reportError("connect_failed", "Failed to connect to device")
            LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
            downloadSessionPtr = 0
            activeBleStream = null
            return
        }

        // Ensure the device is bonded before starting the download.
        // Devices using encrypted BLE services (e.g. Aqualung i300C on
        // the Pelagic service) need an established bond. createBond()
        // works here because we have an active GATT connection.
        if (!bleStream.ensureBonded()) {
            reportError("bond_failed", "Failed to pair with device")
            bleStream.close()
            LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
            downloadSessionPtr = 0
            activeBleStream = null
            return
        }

        val downloadCallback = makeDownloadCallback()
        val fingerprintBytes = decodeFingerprint(fingerprint)

        // Run the download.
        val errorBuf = ByteArray(256)
        NativeLogger.d(TAG, "LDC", "nativeDownloadRun: vendor=${device.vendor} product=${device.product} model=${device.model} name=${device.name}")
        val result = try {
            LibdcWrapper.nativeDownloadRun(
                sessionPtr,
                device.vendor, device.product,
                device.model.toInt(), LIBDC_TRANSPORT_BLE,
                bleStream, device.name,
                fingerprintBytes,
                downloadCallback, errorBuf
            )
        } catch (e: Throwable) {
            NativeLogger.e(TAG, "LDC", "nativeDownloadRun threw: ${e.message}")
            -999
        }
        NativeLogger.d(TAG, "LDC", "nativeDownloadRun returned: $result")

        // Report completion or error.
        if (result == 0) {
            mainHandler.post { flutterApi.onDownloadComplete(0, null, null) { } }
        } else if (result != LIBDC_STATUS_CANCELLED) {
            // If the download failed because the remote device rejected our
            // encryption keys (GATT status 5), the bond is stale. Remove
            // it so that a fresh pairing can be negotiated on retry.
            if (!isRetry &&
                bleStream.lastDisconnectStatus == GATT_INSUFFICIENT_AUTHENTICATION
            ) {
                NativeLogger.w(TAG, "BLE", "Auth failure (GATT status 5), removing stale bond and retrying")
                bleStream.close()
                bleStream.removeBond()
                activeBleStream = null
                LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
                downloadSessionPtr = 0
                performDownload(device, fingerprint, isRetry = true)
                return
            }

            val errorMsg = String(errorBuf).trim('\u0000')
            NativeLogger.e(TAG, "LDC", "download error: $errorMsg")
            reportError("download_error", errorMsg)
        }

        // Cleanup.
        LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
        downloadSessionPtr = 0
        activeBleStream = null
    }

    // Serial-over-USB download with auto-probe, mirroring the macOS/Linux/Windows
    // backends. Connected USB-to-serial adapters are enumerated via the vendored
    // usb-serial-for-android prober; each is tried with a full download. With
    // more than one candidate, dives are buffered so a wrong adapter cannot leak
    // phantom dives (flushed on success, discarded on failure).
    private fun performUsbSerialDownload(
        device: DiscoveredDevice,
        sessionPtr: Long,
        fingerprint: String?
    ) {
        val usbManager = context.getSystemService(Context.USB_SERVICE) as? UsbManager
        val drivers: List<UsbSerialDriver> = usbManager?.let {
            UsbSerialProber.getDefaultProber().findAllDrivers(it)
        } ?: emptyList()

        if (drivers.isEmpty()) {
            reportError(
                "no_serial_ports",
                "No USB serial ports found. Is the dive computer connected and powered on?"
            )
            LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
            downloadSessionPtr = 0
            return
        }

        val downloadCallback = makeDownloadCallback()
        val fingerprintBytes = decodeFingerprint(fingerprint)
        val buffering = drivers.size > 1
        synchronized(diveBufferLock) {
            isBufferingDives = buffering
            bufferedDives.clear()
        }

        val probeLog = StringBuilder()
        var anyOpened = false
        var lastResult = -1
        var lastErrorMsg = ""

        for (driver in drivers) {
            synchronized(diveBufferLock) { bufferedDives.clear() }

            val stream = UsbSerialIoStream(context, driver)
            if (!stream.open()) {
                probeLog.append("  ${driver.device.deviceName}: failed to open\n")
                continue
            }
            anyOpened = true
            activeSerialStream = stream
            NativeLogger.d(TAG, "SER", "nativeDownloadRun (serial): ${driver.device.deviceName}")

            val errorBuf = ByteArray(256)
            var thrownMsg: String? = null
            val result = try {
                LibdcWrapper.nativeDownloadRun(
                    sessionPtr,
                    device.vendor, device.product,
                    device.model.toInt(), LIBDC_TRANSPORT_SERIAL,
                    stream, device.name,
                    fingerprintBytes,
                    downloadCallback, errorBuf
                )
            } catch (e: Throwable) {
                NativeLogger.e(TAG, "LDC", "nativeDownloadRun threw: ${e.message}")
                thrownMsg = e.message
                -999
            }
            stream.close()
            activeSerialStream = null
            lastResult = result
            // Prefer libdivecomputer's error text; fall back to the thrown
            // exception message (errorBuf is empty when the JNI call throws) or a
            // generic code, so download_error is never blank.
            lastErrorMsg = String(errorBuf).takeWhile { it.code != 0 }.ifEmpty {
                thrownMsg ?: "Download failed (rc=$result)"
            }

            if (result == 0 || result == LIBDC_STATUS_CANCELLED) break
            probeLog.append("  ${driver.device.deviceName}: download failed (rc=$result)\n")
            NativeLogger.w(TAG, "SER", "Probe failed on ${driver.device.deviceName} rc=$result")
        }

        // Flush buffered dives on success OR cancellation (a cancel still posts
        // onDownloadComplete so the Dart side can import dives downloaded before
        // the cancel); discard only on real failure. Safe because a wrong port
        // fails to handshake and emits no dives, and the buffer is cleared per
        // attempt, so it only ever holds the actively-downloading port's dives.
        val divesToFlush: List<ParsedDive> = synchronized(diveBufferLock) {
            val succeeded = lastResult == 0 || lastResult == LIBDC_STATUS_CANCELLED
            val list = if (succeeded) ArrayList(bufferedDives) else emptyList()
            bufferedDives.clear()
            isBufferingDives = false
            list
        }
        for (dive in divesToFlush) {
            mainHandler.post { flutterApi.onDiveDownloaded(dive) { } }
        }

        when {
            !anyOpened ->
                reportError("connect_failed", "No dive computer found. Ports tried:\n$probeLog")
            lastResult == 0 || lastResult == LIBDC_STATUS_CANCELLED ->
                mainHandler.post { flutterApi.onDownloadComplete(0, null, null) { } }
            drivers.size > 1 ->
                reportError("connect_failed", "No dive computer found. Ports tried:\n$probeLog")
            else ->
                reportError("download_error", lastErrorMsg)
        }

        LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
        downloadSessionPtr = 0
        activeSerialStream = null
    }

    // MARK: - Dive Conversion

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
                tankIndex = if (s[4].toLong() == UINT32_SENTINEL) null else s[4].toLong(),
                heartRate = if (s[5].toLong() == UINT32_SENTINEL) null else s[5].toLong(),
                setpoint = if (s[6].isNaN()) null else s[6],
                ppo2 = if (s[7].isNaN()) null else s[7],
                cns = if (s[8].isNaN()) null else s[8],
                rbt = if (s[9].toLong() == UINT32_SENTINEL) null else s[9].toLong(),
                decoType = if (s[10].toLong() == UINT32_SENTINEL) null else s[10].toLong(),
                decoTime = if (s[11].toLong() == UINT32_SENTINEL) null else s[11].toLong(),
                decoDepth = if (s[12].isNaN()) null else s[12],
                tts = if (s[13].toLong() == UINT32_SENTINEL || s[13].toLong() == 0L) null else s[13].toLong(),
                o2Sensor1 = if (s[14].isNaN()) null else s[14],
                o2Sensor2 = if (s[15].isNaN()) null else s[15],
                o2Sensor3 = if (s[16].isNaN()) null else s[16],
                o2Sensor4 = if (s[17].isNaN()) null else s[17],
                o2Sensor5 = if (s[18].isNaN()) null else s[18],
                o2Sensor6 = if (s[19].isNaN()) null else s[19]
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

    // MARK: - Parse Raw Dive Data

    override fun parseRawDiveData(
        vendor: String,
        product: String,
        model: Long,
        data: ByteArray,
        callback: (Result<ParsedDive>) -> Unit
    ) {
        callback(Result.failure(
            FlutterError("UNSUPPORTED",
                "Raw dive parsing not yet implemented on Android",
                null)))
    }

    // MARK: - Version

    override fun getLibdivecomputerVersion(): String {
        if (LibdcWrapper.loadError != null) return "unavailable"
        return try {
            LibdcWrapper.nativeGetVersion()
        } catch (t: Throwable) {
            "unavailable"
        }
    }

    // MARK: - Helpers

    private fun reportError(code: String, message: String) {
        mainHandler.post {
            flutterApi.onError(DiveComputerError(code = code, message = message)) { }
        }
    }

    // Reports a clear, actionable error (instead of crashing) when the native
    // libdivecomputer JNI library failed to load. The usual cause is an
    // UnsatisfiedLinkError from a 4 KB-aligned liblibdc_jni.so on a 16 KB-page
    // Android 15+ device (issue #318); without this guard the failure surfaced
    // as a silent process death the moment a download started. Returns true
    // when the native library is usable.
    private fun nativeLibraryReady(): Boolean {
        val err = LibdcWrapper.loadError ?: return true
        NativeLogger.e(
            TAG, "LDC",
            "Native library unavailable: ${err.javaClass.simpleName}: ${err.message}"
        )
        reportError(
            "native_library_unavailable",
            "Dive computer support could not be loaded on this device " +
                "(${err.javaClass.simpleName}). Please update Submersion to the " +
                "latest version."
        )
        return false
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
