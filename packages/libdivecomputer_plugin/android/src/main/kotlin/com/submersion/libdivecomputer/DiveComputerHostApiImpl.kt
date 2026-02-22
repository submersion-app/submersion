package com.submersion.libdivecomputer

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import java.util.Calendar
import java.util.TimeZone
import java.util.concurrent.Executors

// Transport bitmask values matching libdc_wrapper.h.
private const val LIBDC_TRANSPORT_SERIAL = 1 shl 0
private const val LIBDC_TRANSPORT_USB = 1 shl 1
private const val LIBDC_TRANSPORT_USBHID = 1 shl 2
private const val LIBDC_TRANSPORT_IRDA = 1 shl 3
private const val LIBDC_TRANSPORT_BLE = 1 shl 5

private const val LIBDC_STATUS_CANCELLED = -10

class DiveComputerHostApiImpl(
    private val context: Context,
    private val messenger: BinaryMessenger
) : DiveComputerHostApi {

    private val flutterApi = DiveComputerFlutterApi(messenger)
    private val executor = Executors.newSingleThreadExecutor()
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
        when (transport) {
            TransportType.BLE -> startBleDiscovery()
            else -> reportError("unsupported_transport",
                "Transport $transport not yet supported on Android")
        }
        callback(Result.success(Unit))
    }

    override fun stopDiscovery() {
        bleScanner?.stop()
        bleScanner = null
    }

    private fun startBleDiscovery() {
        val scanner = BleScanner(context)
        scanner.onDeviceDiscovered = { device ->
            flutterApi.onDeviceDiscovered(device) { }
        }
        scanner.onComplete = {
            flutterApi.onDiscoveryComplete { }
        }
        bleScanner = scanner
        scanner.start()
    }

    // MARK: - Download

    override fun startDownload(
        device: DiscoveredDevice,
        callback: (Result<Unit>) -> Unit
    ) {
        callback(Result.success(Unit))

        executor.execute {
            performDownload(device)
        }
    }

    override fun cancelDownload() {
        if (downloadSessionPtr != 0L) {
            LibdcWrapper.nativeDownloadCancel(downloadSessionPtr)
        }
    }

    private fun performDownload(device: DiscoveredDevice) {
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

        if (!bleStream.connectAndDiscover()) {
            reportError("connect_failed", "Failed to connect to device")
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
                flutterApi.onDownloadProgress(progress) { }
            }

            override fun onDive(divePtr: Long) {
                val parsedDive = convertParsedDive(divePtr)
                flutterApi.onDiveDownloaded(parsedDive) { }
            }
        }

        // Run the download.
        val errorBuf = ByteArray(256)
        val result = LibdcWrapper.nativeDownloadRun(
            sessionPtr,
            device.vendor, device.product,
            device.model.toInt(), transportValue,
            bleStream, downloadCallback, errorBuf
        )

        // Report completion or error.
        if (result == 0) {
            flutterApi.onDownloadComplete(0, null, null) { }
        } else if (result != LIBDC_STATUS_CANCELLED) {
            val errorMsg = String(errorBuf).trim('\u0000')
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

        // Convert datetime to epoch seconds.
        val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        cal.set(
            LibdcWrapper.nativeGetDiveYear(divePtr),
            LibdcWrapper.nativeGetDiveMonth(divePtr) - 1,  // Calendar months are 0-based
            LibdcWrapper.nativeGetDiveDay(divePtr),
            LibdcWrapper.nativeGetDiveHour(divePtr),
            LibdcWrapper.nativeGetDiveMinute(divePtr),
            LibdcWrapper.nativeGetDiveSecond(divePtr)
        )
        val epoch = cal.timeInMillis / 1000

        // Convert samples.
        val sampleCount = LibdcWrapper.nativeGetDiveSampleCount(divePtr)
        val samples = (0 until sampleCount).mapNotNull { i ->
            val s = LibdcWrapper.nativeGetDiveSample(divePtr, i) ?: return@mapNotNull null
            ProfileSample(
                timeSeconds = (s[0] / 1000.0).toLong(),
                depthMeters = s[1],
                temperatureCelsius = if (s[2].isNaN()) null else s[2],
                pressureBar = if (s[3].isNaN()) null else s[3],
                tankIndex = if (s[4].toLong() == 0xFFFFFFFFL) null else s[4].toLong(),
                heartRate = null
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

        return ParsedDive(
            fingerprint = fingerprint,
            dateTimeEpoch = epoch,
            maxDepthMeters = maxDepth,
            avgDepthMeters = avgDepth,
            durationSeconds = LibdcWrapper.nativeGetDiveDuration(divePtr).toLong(),
            minTemperatureCelsius = if (minTemp.isNaN()) null else minTemp,
            maxTemperatureCelsius = if (maxTemp.isNaN()) null else maxTemp,
            samples = samples,
            tanks = tanks,
            gasMixes = gasMixes,
            events = emptyList(),
            diveMode = diveMode
        )
    }

    // MARK: - Version

    override fun getLibdivecomputerVersion(): String {
        return LibdcWrapper.nativeGetVersion()
    }

    // MARK: - Helpers

    private fun reportError(code: String, message: String) {
        flutterApi.onError(DiveComputerError(code = code, message = message)) { }
    }
}
