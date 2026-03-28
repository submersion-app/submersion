package com.submersion.libdivecomputer

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.os.Handler
import android.os.Looper
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

// Bluetooth permissions are requested at the Dart layer before BLE methods are called.
@SuppressLint("MissingPermission")
class DiveComputerHostApiImpl(
    private val context: Context,
    private val messenger: BinaryMessenger
) : DiveComputerHostApi {

    private val flutterApi = DiveComputerFlutterApi(messenger)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var bleScanner: BleScanner? = null
    private var downloadSessionPtr: Long = 0
    private var activeBleStream: BleIoStream? = null

    // MARK: - Device Descriptors

    override fun getDeviceDescriptors(callback: (Result<List<DeviceDescriptor>>) -> Unit) {
        executor.execute {
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
            performDownload(device, fingerprint)
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
        // Create download session.
        val sessionPtr = LibdcWrapper.nativeDownloadSessionNew()
        if (sessionPtr == 0L) {
            reportError("session_failed", "Failed to create download session")
            return
        }
        downloadSessionPtr = sessionPtr

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

        // Map transport type.
        val transportValue = when (device.transport) {
            TransportType.BLE -> LIBDC_TRANSPORT_BLE
            TransportType.USB -> LIBDC_TRANSPORT_USB
            TransportType.SERIAL -> LIBDC_TRANSPORT_SERIAL
            TransportType.INFRARED -> LIBDC_TRANSPORT_IRDA
        }

        // Set up download callbacks.
        val downloadCallback = object : DownloadCallback {
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
                mainHandler.post { flutterApi.onDiveDownloaded(parsedDive) { } }
            }
        }

        // Decode hex fingerprint to ByteArray for libdivecomputer.
        val fingerprintBytes: ByteArray? = fingerprint?.takeIf { it.isNotEmpty() }?.let { hex ->
            hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        }

        // Run the download.
        val errorBuf = ByteArray(256)
        android.util.Log.d("DiveComputerHost", "nativeDownloadRun: vendor=${device.vendor} product=${device.product} model=${device.model} name=${device.name}")
        val result = try {
            LibdcWrapper.nativeDownloadRun(
                sessionPtr,
                device.vendor, device.product,
                device.model.toInt(), transportValue,
                bleStream, device.name,
                fingerprintBytes,
                downloadCallback, errorBuf
            )
        } catch (e: Throwable) {
            android.util.Log.e("DiveComputerHost", "nativeDownloadRun threw", e)
            -999
        }
        android.util.Log.d("DiveComputerHost", "nativeDownloadRun returned: $result")

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
                android.util.Log.w("DiveComputerHost",
                    "Auth failure (GATT status 5), removing stale bond and retrying")
                bleStream.close()
                bleStream.removeBond()
                activeBleStream = null
                LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
                downloadSessionPtr = 0
                performDownload(device, fingerprint, isRetry = true)
                return
            }

            val errorMsg = String(errorBuf).trim('\u0000')
            android.util.Log.e("DiveComputerHost", "download error: $errorMsg")
            reportError("download_error", errorMsg)
        }

        // Cleanup.
        LibdcWrapper.nativeDownloadSessionFree(sessionPtr)
        downloadSessionPtr = 0
        activeBleStream = null
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
                tts = if (s[13].toLong() == UINT32_SENTINEL || s[13].toLong() == 0L) null else s[13].toLong()
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
            samples = samples,
            tanks = tanks,
            gasMixes = gasMixes,
            events = events,
            diveMode = diveMode,
            decoAlgorithm = decoAlgorithm,
            gfLow = gfLow,
            gfHigh = gfHigh,
            decoConservatism = decoConservatism
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
        return LibdcWrapper.nativeGetVersion()
    }

    // MARK: - Helpers

    private fun reportError(code: String, message: String) {
        mainHandler.post {
            flutterApi.onError(DiveComputerError(code = code, message = message)) { }
        }
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
