#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
import CoreBluetooth

class DiveComputerHostApiImpl: DiveComputerHostApi {
    private let messenger: FlutterBinaryMessenger
    private let flutterApi: DiveComputerFlutterApi
    private var bleScanner: BleScanner?
    private var downloadSession: OpaquePointer?  // libdc_download_session_t*
    private var activeBleStream: BleIoStream?
    private var serialScanner: SerialScanner?
    private var activeSerialStream: SerialIoStream?

    // Dive buffering for the multi-port serial probe. When more than one serial
    // port is a candidate (manual model selection with no exact path), each port
    // is tried with a full download; dives from a wrong port must not be sent to
    // Flutter. While `isBufferingDives` is set, on_dive accumulates into
    // `bufferedDives` instead of dispatching; the probe flushes on success and
    // discards on failure. Guarded by `diveBufferLock` because on_dive fires on
    // libdivecomputer's download thread.
    private var isBufferingDives = false
    private var bufferedDives: [ParsedDive] = []
    private let diveBufferLock = NSLock()

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        self.flutterApi = DiveComputerFlutterApi(binaryMessenger: messenger)
    }

    // MARK: - Device Descriptors

    func getDeviceDescriptors(completion: @escaping (Result<[DeviceDescriptor], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var descriptors: [DeviceDescriptor] = []

            guard let iter = libdc_descriptor_iterator_new() else {
                completion(.success([]))
                return
            }

            var info = libdc_descriptor_info_t()
            while libdc_descriptor_iterator_next(iter, &info) == 0 {
                let vendor = info.vendor.map { String(cString: $0) } ?? ""
                let product = info.product.map { String(cString: $0) } ?? ""
                let transports = Self.mapTransports(info.transports)

                descriptors.append(DeviceDescriptor(
                    vendor: vendor,
                    product: product,
                    model: Int64(info.model),
                    transports: transports
                ))
            }

            libdc_descriptor_iterator_free(iter)
            completion(.success(descriptors))
        }
    }

    private static func mapTransports(_ bitmask: UInt32) -> [TransportType] {
        var transports: [TransportType] = []
        if bitmask & UInt32(LIBDC_TRANSPORT_BLE) != 0 {
            transports.append(.ble)
        }
        if bitmask & UInt32(LIBDC_TRANSPORT_USB) != 0 ||
           bitmask & UInt32(LIBDC_TRANSPORT_USBHID) != 0 {
            transports.append(.usb)
        }
        if bitmask & UInt32(LIBDC_TRANSPORT_SERIAL) != 0 {
            transports.append(.serial)
        }
        if bitmask & UInt32(LIBDC_TRANSPORT_IRDA) != 0 {
            transports.append(.infrared)
        }
        return transports
    }

    // MARK: - Discovery

    func startDiscovery(transport: TransportType, completion: @escaping (Result<Void, Error>) -> Void) {
        switch transport {
        case .ble:
            startBleDiscovery()
        case .serial:
            startSerialDiscovery()
        default:
            let platformName: String
            #if os(iOS)
            platformName = "iOS"
            #elseif os(macOS)
            platformName = "macOS"
            #endif
            flutterApi.onError(error: DiveComputerError(
                code: "unsupported_transport",
                message: "Transport \(transport) not yet supported on \(platformName)"
            )) { _ in }
        }
        completion(.success(()))
    }

    func stopDiscovery() throws {
        bleScanner?.stop()
        bleScanner = nil
        serialScanner?.stop()
        serialScanner = nil
    }

    private func startBleDiscovery() {
        bleScanner?.stop()
        let scanner = BleScanner()
        scanner.onDeviceDiscovered = { [weak self] device in
            DispatchQueue.main.async {
                self?.flutterApi.onDeviceDiscovered(device: device) { _ in }
            }
        }
        scanner.onComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.flutterApi.onDiscoveryComplete { _ in }
            }
        }
        self.bleScanner = scanner
        scanner.start()
    }

    private func startSerialDiscovery() {
        serialScanner?.stop()
        let scanner = SerialScanner()
        scanner.onDeviceDiscovered = { [weak self] device in
            DispatchQueue.main.async {
                self?.flutterApi.onDeviceDiscovered(device: device) { _ in }
            }
        }
        scanner.onComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.flutterApi.onDiscoveryComplete { _ in }
            }
        }
        self.serialScanner = scanner
        scanner.start()
    }

    // MARK: - Download

    func startDownload(device: DiscoveredDevice, fingerprint: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.performDownload(device: device, fingerprint: fingerprint)
        }
    }

    func cancelDownload() throws {
        if let session = downloadSession {
            libdc_download_cancel(session)
        }
    }

    func submitPinCode(pinCode: String) throws {
        guard let stream = activeBleStream else {
            throw PigeonError(code: "no_stream", message: "No active BLE stream", details: nil)
        }
        stream.submitPinCode(pinCode)
    }

    /// Result of a single libdc_download_run attempt.
    private struct RunResult {
        let rc: Int32
        let serial: UInt32
        let firmware: UInt32
        let errorMessage: String
    }

    private func performDownload(device: DiscoveredDevice, fingerprint: String?) {
        // Create download session.
        guard let session = libdc_download_session_new() else {
            reportError(code: "session_failed", message: "Failed to create download session")
            return
        }
        self.downloadSession = session

        // Register a C-compatible log callback so libdivecomputer's internal
        // diagnostic messages flow through NativeLogger to Flutter.
        libdc_set_log_callback(
            { (level: Int32, message: UnsafePointer<CChar>?, _: UnsafeMutableRawPointer?) in
                guard let message = message else { return }
                let msg = String(cString: message)
                // Map dc_loglevel_t to NativeLogger severity.
                // DC_LOGLEVEL_NONE=0, ERROR=1, WARNING=2, INFO=3, DEBUG=4, ALL=5
                switch level {
                case 1:
                    NativeLogger.e("libdc", category: "LDC", msg)
                case 2:
                    NativeLogger.w("libdc", category: "LDC", msg)
                case 3:
                    NativeLogger.i("libdc", category: "LDC", msg)
                default:
                    NativeLogger.d("libdc", category: "LDC", msg)
                }
            },
            nil
        )

        let downloadCallbacks = makeDownloadCallbacks()
        let fingerprintBytes = decodeFingerprint(fingerprint)

        // Dispatch by transport. Exhaustive (no `default:`) on purpose: the
        // original "Invalid device address" bug was a `.usb` device silently
        // falling into the BLE path via a default case. Keeping this exhaustive
        // forces any future transport to be handled explicitly.
        switch device.transport {
        case .ble:
            performBleDownload(
                device: device, session: session,
                downloadCallbacks: downloadCallbacks, fingerprint: fingerprintBytes)
        case .serial, .usb:
            // Serial-over-USB (e.g. Mares Puck Pro on an FTDI cable). The Dart
            // layer folds libdivecomputer's serial transport into `.usb`, so both
            // route here and download over LIBDC_TRANSPORT_SERIAL.
            performSerialDownload(
                device: device, session: session,
                downloadCallbacks: downloadCallbacks, fingerprint: fingerprintBytes)
        case .infrared:
            reportError(
                code: "unsupported_transport",
                message: "Infrared transport is not supported on this platform")
        }

        // Cleanup (single owner of the session, so no path double-frees).
        libdc_download_session_free(session)
        self.downloadSession = nil
        self.activeBleStream = nil
        self.activeSerialStream = nil
    }

    /// Builds the progress/dive callbacks. `on_dive` buffers instead of
    /// dispatching while a multi-port serial probe is in progress.
    private func makeDownloadCallbacks() -> libdc_download_callbacks_t {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var downloadCallbacks = libdc_download_callbacks_t()
        downloadCallbacks.on_progress = { current, maximum, userdata in
            let hostApi = Unmanaged<DiveComputerHostApiImpl>.fromOpaque(userdata!).takeUnretainedValue()
            let progress = DownloadProgress(
                current: Int64(current),
                total: Int64(maximum),
                status: "downloading"
            )
            DispatchQueue.main.async {
                hostApi.flutterApi.onDownloadProgress(progress: progress) { _ in }
            }
        }
        downloadCallbacks.on_dive = { divePtr, userdata in
            let hostApi = Unmanaged<DiveComputerHostApiImpl>.fromOpaque(userdata!).takeUnretainedValue()
            guard let dive = divePtr else { return }
            let parsedDive = hostApi.convertParsedDive(dive.pointee)
            NativeLogger.d("DiveComputerHost", category: "LDC",
                "Dive parsed: depth=\(parsedDive.maxDepthMeters)m, duration=\(parsedDive.durationSeconds)s, samples=\(parsedDive.samples.count)")
            hostApi.diveBufferLock.lock()
            let buffering = hostApi.isBufferingDives
            if buffering {
                hostApi.bufferedDives.append(parsedDive)
            }
            hostApi.diveBufferLock.unlock()
            if !buffering {
                DispatchQueue.main.async {
                    hostApi.flutterApi.onDiveDownloaded(dive: parsedDive) { _ in }
                }
            }
        }
        downloadCallbacks.userdata = selfPtr
        return downloadCallbacks
    }

    /// Decodes a hex fingerprint string to bytes for incremental download.
    private func decodeFingerprint(_ hex: String?) -> [UInt8]? {
        guard let hex = hex, !hex.isEmpty else { return nil }
        return stride(from: 0, to: hex.count, by: 2).compactMap { i in
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end = hex.index(start, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            return UInt8(hex[start..<end], radix: 16)
        }
    }

    /// Runs a single blocking download attempt over the given I/O callbacks.
    /// Callbacks are passed by value and copied to locals so libdc_download_run
    /// can take mutable pointers to them.
    private func runOnce(
        session: OpaquePointer,
        device: DiscoveredDevice,
        transportValue: UInt32,
        ioCallbacks: libdc_io_callbacks_t,
        fingerprint: [UInt8]?,
        downloadCallbacks: libdc_download_callbacks_t
    ) -> RunResult {
        var io = ioCallbacks
        var dl = downloadCallbacks
        var serial: UInt32 = 0
        var firmware: UInt32 = 0
        var errorBuf = [CChar](repeating: 0, count: 256)
        let result: Int32
        if let fp = fingerprint, !fp.isEmpty {
            result = fp.withUnsafeBufferPointer { buf in
                libdc_download_run(
                    session,
                    device.vendor, device.product, UInt32(device.model),
                    transportValue,
                    &io,
                    buf.baseAddress, UInt32(buf.count),
                    &dl,
                    &serial, &firmware,
                    &errorBuf, errorBuf.count
                )
            }
        } else {
            result = libdc_download_run(
                session,
                device.vendor, device.product, UInt32(device.model),
                transportValue,
                &io,
                nil, 0,
                &dl,
                &serial, &firmware,
                &errorBuf, errorBuf.count
            )
        }
        return RunResult(
            rc: result, serial: serial, firmware: firmware,
            errorMessage: String(cString: errorBuf))
    }

    /// Reports the final outcome of a download attempt to Flutter
    /// (success/cancelled -> onDownloadComplete, otherwise download_error).
    private func reportDownloadResult(_ result: RunResult) {
        let serialStr: String? = result.serial > 0 ? String(result.serial) : nil
        let firmwareStr: String? = result.firmware > 0 ? String(result.firmware) : nil
        NativeLogger.i("DiveComputerHost", category: "LDC",
            "Device info: serial=\(result.serial), firmware=\(result.firmware)")
        NativeLogger.d("DiveComputerHost", category: "LDC",
            "libdc_download_run returned result=\(result.rc)")

        if result.rc == 0 {
            NativeLogger.i("DiveComputerHost", category: "LDC", "Download succeeded, sending onDownloadComplete")
            DispatchQueue.main.async { [weak self] in
                self?.flutterApi.onDownloadComplete(
                    totalDives: 0, serialNumber: serialStr, firmwareVersion: firmwareStr) { _ in }
            }
        } else if result.rc == Int32(LIBDC_STATUS_CANCELLED) {
            NativeLogger.i("DiveComputerHost", category: "LDC", "Download cancelled, sending onDownloadComplete")
            // Still send completion so the Dart side can import any dives
            // that were downloaded before cancellation.
            DispatchQueue.main.async { [weak self] in
                self?.flutterApi.onDownloadComplete(
                    totalDives: 0, serialNumber: serialStr, firmwareVersion: firmwareStr) { _ in }
            }
        } else {
            NativeLogger.e("DiveComputerHost", category: "LDC",
                "Download error (result=\(result.rc)): \(result.errorMessage)")
            reportError(code: "download_error", message: result.errorMessage)
        }
    }

    /// BLE download: resolve/connect the peripheral, then run once.
    private func performBleDownload(
        device: DiscoveredDevice, session: OpaquePointer,
        downloadCallbacks: libdc_download_callbacks_t, fingerprint: [UInt8]?
    ) {
        guard let ioCallbacks = connectBle(device: device) else { return }
        let result = runOnce(
            session: session, device: device,
            transportValue: UInt32(LIBDC_TRANSPORT_BLE),
            ioCallbacks: ioCallbacks, fingerprint: fingerprint,
            downloadCallbacks: downloadCallbacks)
        reportDownloadResult(result)
    }

    /// Serial-over-USB download with auto-probe, mirroring the Linux/Windows
    /// backends. A single candidate (an explicit /dev path, or the sole USB
    /// serial port) is opened and run directly. Multiple candidates (manual
    /// model selection with several adapters attached) are each tried with a
    /// full download, buffering dives so a wrong port cannot leak phantom dives.
    private func performSerialDownload(
        device: DiscoveredDevice, session: OpaquePointer,
        downloadCallbacks: libdc_download_callbacks_t, fingerprint: [UInt8]?
    ) {
        let transportValue = UInt32(LIBDC_TRANSPORT_SERIAL)
        let available = SerialPortEnumerator.enumerateUsbSerialPaths()
        let candidates = SerialPortEnumerator.candidatePorts(
            address: device.address, available: available)

        if candidates.isEmpty {
            reportError(
                code: "no_serial_ports",
                message: "No USB serial ports found. Is the dive computer connected and powered on?")
            return
        }

        // Single candidate: open directly and report the real outcome (an open
        // failure is a clear connect error; a comms failure is download_error).
        if candidates.count == 1 {
            let port = candidates[0]
            let stream = SerialIoStream()
            guard stream.open(path: port) else {
                reportError(code: "connect_failed", message: "Failed to open serial port: \(port)")
                return
            }
            NativeLogger.i("DiveComputerHost", category: "SER", "Opened serial port: \(port)")
            self.activeSerialStream = stream
            let result = runOnce(
                session: session, device: device, transportValue: transportValue,
                ioCallbacks: stream.makeCallbacks(), fingerprint: fingerprint,
                downloadCallbacks: downloadCallbacks)
            stream.close()
            self.activeSerialStream = nil
            reportDownloadResult(result)
            return
        }

        // Multi-candidate probe: buffer dives until a port succeeds.
        diveBufferLock.lock()
        isBufferingDives = true
        bufferedDives.removeAll()
        diveBufferLock.unlock()

        var probeLog = ""
        var anyOpened = false
        var lastResult = RunResult(
            rc: Int32(LIBDC_STATUS_IO), serial: 0, firmware: 0, errorMessage: "")

        for port in candidates {
            diveBufferLock.lock()
            bufferedDives.removeAll()
            diveBufferLock.unlock()

            let stream = SerialIoStream()
            guard stream.open(path: port) else {
                probeLog += "  \(port): failed to open\n"
                continue
            }
            anyOpened = true
            NativeLogger.i("DiveComputerHost", category: "SER", "Probing serial port: \(port)")
            self.activeSerialStream = stream
            let result = runOnce(
                session: session, device: device, transportValue: transportValue,
                ioCallbacks: stream.makeCallbacks(), fingerprint: fingerprint,
                downloadCallbacks: downloadCallbacks)
            lastResult = result
            stream.close()
            self.activeSerialStream = nil

            if result.rc == 0 || result.rc == Int32(LIBDC_STATUS_CANCELLED) {
                break
            }
            probeLog += "  \(port): download failed (rc=\(result.rc))\n"
            NativeLogger.w("DiveComputerHost", category: "SER", "Probe failed on \(port) rc=\(result.rc)")
        }

        // Flush buffered dives on success OR cancellation (a cancel still sends
        // onDownloadComplete so the Dart side can import dives downloaded before
        // the cancel); discard only on real failure. Safe because a wrong port
        // fails to handshake and emits no dives, and the buffer is cleared per
        // attempt, so it only ever holds the actively-downloading port's dives.
        let succeeded = lastResult.rc == 0 || lastResult.rc == Int32(LIBDC_STATUS_CANCELLED)
        diveBufferLock.lock()
        let divesToFlush = succeeded ? bufferedDives : []
        bufferedDives.removeAll()
        isBufferingDives = false
        diveBufferLock.unlock()
        for dive in divesToFlush {
            DispatchQueue.main.async { [weak self] in
                self?.flutterApi.onDiveDownloaded(dive: dive) { _ in }
            }
        }

        if !anyOpened {
            reportError(
                code: "connect_failed",
                message: "No dive computer found. Ports tried:\n\(probeLog)")
            return
        }
        if lastResult.rc != 0 && lastResult.rc != Int32(LIBDC_STATUS_CANCELLED) {
            reportError(
                code: "connect_failed",
                message: "No dive computer found. Ports tried:\n\(probeLog)")
            return
        }
        reportDownloadResult(lastResult)
    }

    // MARK: - Transport Connection

    private func connectBle(
        device: DiscoveredDevice
    ) -> libdc_io_callbacks_t? {
        guard let uuid = UUID(uuidString: device.address) else {
            reportError(code: "invalid_address", message: "Invalid device address")
            return nil
        }

        if let scanner = bleScanner {
            NativeLogger.d("DiveComputerHost", category: "BLE", "Stopping BLE scan before download connect")
            scanner.stop()
            bleScanner = nil
        }

        // Resolve/connect with a fallback retry:
        // 1) cached-or-scan for speed
        // 2) scan-only to avoid stale cached peripheral state.
        let resolvePlans: [(label: String, allowCachedPeripherals: Bool, timeout: TimeInterval)] = [
            ("cached-or-scan", true, 15),
            ("scan-only", false, 20),
        ]
        var connectedStream: BleIoStream?

        for (index, plan) in resolvePlans.enumerated() {
            NativeLogger.d("DiveComputerHost", category: "BLE",
                "Resolve/connect attempt \(index + 1) (\(plan.label)) for \(device.address) (\(device.vendor) \(device.product))")
            let queue = DispatchQueue(
                label: "com.submersion.ble-download.\(index + 1)",
                qos: .userInitiated
            )
            let resolver = BlePeripheralResolver(
                targetIdentifier: uuid,
                queue: queue,
                allowCachedPeripherals: plan.allowCachedPeripherals
            )
            guard let peripheral = resolver.resolve(timeout: plan.timeout),
                  let centralMgr = resolver.centralManager else {
                NativeLogger.w("DiveComputerHost", category: "BLE", "Peripheral resolve failed on attempt \(index + 1)")
                continue
            }
            NativeLogger.i("DiveComputerHost", category: "BLE",
                "Peripheral resolved: \(peripheral.identifier.uuidString) (\(peripheral.name ?? "unknown"))")

            let stream = BleIoStream(peripheral: peripheral, centralManager: centralMgr)
            stream.setDeviceAddress(device.address)
            stream.onPinCodeRequired = { [weak self] address in
                self?.flutterApi.onPinCodeRequired(deviceAddress: address) { _ in }
            }
            self.activeBleStream = stream
            if stream.connectAndDiscover() {
                connectedStream = stream
                break
            }

            NativeLogger.w("DiveComputerHost", category: "BLE",
                "connectAndDiscover failed on attempt \(index + 1) for \(peripheral.identifier.uuidString)")
            if peripheral.state != .disconnected {
                centralMgr.cancelPeripheralConnection(peripheral)
            }
        }

        guard let bleStream = connectedStream else {
            reportError(code: "connect_failed", message: "Failed to connect to device")
            self.activeBleStream = nil
            return nil
        }
        return bleStream.makeCallbacks()
    }

    // MARK: - Dive Conversion

    private func convertParsedDive(_ dive: libdc_parsed_dive_t) -> ParsedDive {
        // Convert fingerprint to hex string.
        // C fixed-size arrays import as tuples in Swift - use withUnsafeBytes.
        var mutableDive = dive
        let fingerprintHex = withUnsafeBytes(of: &mutableDive.fingerprint) { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            return (0..<Int(dive.fingerprint_size)).map { i in
                String(format: "%02x", bytes[i])
            }.joined()
        }

        // Map DC_TIMEZONE_NONE (INT32_MIN) to nil.
        let timezoneOffset: Int64? = dive.timezone == Int32.min ? nil : Int64(dive.timezone)

        // Convert samples (samples is a pointer, not a tuple - subscript works).
        var samples: [ProfileSample] = []
        if let samplesPtr = dive.samples {
            for i in 0..<Int(dive.sample_count) {
                let s = samplesPtr[i]
                samples.append(ProfileSample(
                    timeSeconds: Int64(s.time_ms / 1000),
                    depthMeters: s.depth,
                    temperatureCelsius: s.temperature.isNaN ? nil : s.temperature,
                    pressureBar: s.pressure.isNaN ? nil : s.pressure,
                    tankIndex: s.tank == UInt32.max ? nil : Int64(s.tank),
                    heartRate: s.heartbeat == UInt32.max ? nil : Int64(s.heartbeat),
                    setpoint: s.setpoint.isNaN ? nil : s.setpoint,
                    ppo2: s.ppo2.isNaN ? nil : s.ppo2,
                    cns: s.cns.isNaN ? nil : s.cns,
                    rbt: s.rbt == UInt32.max ? nil : Int64(s.rbt),
                    decoType: s.deco_type == UInt32.max ? nil : Int64(s.deco_type),
                    decoTime: s.deco_time == UInt32.max ? nil : Int64(s.deco_time),
                    decoDepth: s.deco_depth.isNaN ? nil : s.deco_depth,
                    tts: s.deco_tts == UInt32.max || s.deco_tts == 0 ? nil : Int64(s.deco_tts),
                    // C `double o2_sensor[6]` imports as a 6-tuple.
                    o2Sensor1: s.o2_sensor.0.isNaN ? nil : s.o2_sensor.0,
                    o2Sensor2: s.o2_sensor.1.isNaN ? nil : s.o2_sensor.1,
                    o2Sensor3: s.o2_sensor.2.isNaN ? nil : s.o2_sensor.2,
                    o2Sensor4: s.o2_sensor.3.isNaN ? nil : s.o2_sensor.3,
                    o2Sensor5: s.o2_sensor.4.isNaN ? nil : s.o2_sensor.4,
                    o2Sensor6: s.o2_sensor.5.isNaN ? nil : s.o2_sensor.5
                ))
            }
        }

        // Convert gas mixes (C fixed-size array -> tuple, use withUnsafeBytes).
        var gasMixes: [GasMix] = []
        withUnsafeBytes(of: &mutableDive.gasmixes) { rawBuffer in
            let gmBuffer = rawBuffer.bindMemory(to: libdc_gasmix_t.self)
            for i in 0..<Int(dive.gasmix_count) {
                let gm = gmBuffer[i]
                gasMixes.append(GasMix(
                    index: Int64(i),
                    o2Percent: gm.oxygen * 100.0,
                    hePercent: gm.helium * 100.0
                ))
            }
        }

        // Convert tanks (C fixed-size array -> tuple, use withUnsafeBytes).
        var tanks: [TankInfo] = []
        withUnsafeBytes(of: &mutableDive.tanks) { rawBuffer in
            let tkBuffer = rawBuffer.bindMemory(to: libdc_tank_t.self)
            for i in 0..<Int(dive.tank_count) {
                let tk = tkBuffer[i]
                tanks.append(TankInfo(
                    index: Int64(i),
                    gasMixIndex: Int64(tk.gasmix),
                    volumeLiters: tk.volume > 0 ? tk.volume : nil,
                    startPressureBar: tk.beginpressure > 0 ? tk.beginpressure : nil,
                    endPressureBar: tk.endpressure > 0 ? tk.endpressure : nil
                ))
            }
        }

        // Map dive mode.
        let diveModeStr: String?
        switch dive.dive_mode {
        case 0: diveModeStr = "freedive"
        case 1: diveModeStr = "gauge"
        case 2: diveModeStr = "open_circuit"
        case 3: diveModeStr = "ccr"
        case 4: diveModeStr = "scr"
        default: diveModeStr = nil
        }

        // Convert events.
        var events: [DiveEvent] = []
        if let eventsPtr = dive.events {
            for i in 0..<Int(dive.event_count) {
                let e = eventsPtr[i]
                guard e.type != 0 else { continue }  // skip SAMPLE_EVENT_NONE
                let typeName = Self.mapEventType(e.type)
                let data: [String: String] = [
                    "flags": String(e.flags),
                    "value": String(e.value),
                ]
                events.append(DiveEvent(
                    timeSeconds: Int64(e.time_ms / 1000),
                    type: typeName,
                    data: data
                ))
            }
        }

        // Map decompression model.
        let decoAlgorithm: String?
        switch dive.deco_model_type {
        case 1: decoAlgorithm = "buhlmann"
        case 2: decoAlgorithm = "vpm"
        case 3: decoAlgorithm = "rgbm"
        case 4: decoAlgorithm = "dciem"
        default: decoAlgorithm = nil
        }

        // Copy raw dive data bytes if available.
        let rawData: FlutterStandardTypedData?
        if dive.raw_data != nil && dive.raw_data_size > 0 {
            rawData = FlutterStandardTypedData(bytes: Data(bytes: dive.raw_data, count: Int(dive.raw_data_size)))
        } else {
            rawData = nil
        }

        let rawFingerprint: FlutterStandardTypedData?
        if dive.raw_fingerprint != nil && dive.raw_fingerprint_size > 0 {
            rawFingerprint = FlutterStandardTypedData(bytes: Data(bytes: dive.raw_fingerprint, count: Int(dive.raw_fingerprint_size)))
        } else {
            rawFingerprint = nil
        }

        return ParsedDive(
            fingerprint: fingerprintHex,
            dateTimeYear: Int64(dive.year),
            dateTimeMonth: Int64(dive.month),
            dateTimeDay: Int64(dive.day),
            dateTimeHour: Int64(dive.hour),
            dateTimeMinute: Int64(dive.minute),
            dateTimeSecond: Int64(dive.second),
            dateTimeTimezoneOffset: timezoneOffset,
            maxDepthMeters: dive.max_depth,
            avgDepthMeters: dive.avg_depth,
            durationSeconds: Int64(dive.duration),
            minTemperatureCelsius: dive.min_temp.isNaN ? nil : dive.min_temp,
            maxTemperatureCelsius: dive.max_temp.isNaN ? nil : dive.max_temp,
            samples: samples,
            tanks: tanks,
            gasMixes: gasMixes,
            events: events,
            diveMode: diveModeStr,
            decoAlgorithm: decoAlgorithm,
            // GF values use 0 as "unknown" sentinel per C struct contract.
            // Valid GF values are always 20-100% in practice.
            gfLow: dive.gf_low == 0 ? nil : Int64(dive.gf_low),
            gfHigh: dive.gf_high == 0 ? nil : Int64(dive.gf_high),
            // Note: deco_conservatism uses 0 for both "neutral" and "not reported".
            // Cannot distinguish these without a C layer change.
            decoConservatism: dive.deco_conservatism == 0 ? nil : Int64(dive.deco_conservatism),
            rawData: rawData,
            rawFingerprint: rawFingerprint,
            entryLatitude: dive.entry_latitude.isNaN ? nil : dive.entry_latitude,
            entryLongitude: dive.entry_longitude.isNaN ? nil : dive.entry_longitude,
            exitLatitude: dive.exit_latitude.isNaN ? nil : dive.exit_latitude,
            exitLongitude: dive.exit_longitude.isNaN ? nil : dive.exit_longitude
        )
    }

    private static func mapEventType(_ type: UInt32) -> String {
        switch type {
        case 0: return "none"
        case 1: return "deco"
        case 2: return "ascent"
        case 3: return "ceiling"
        case 4: return "workload"
        case 5: return "transmitter"
        case 6: return "violation"
        case 7: return "bookmark"
        case 8: return "surface"
        case 9: return "safetystop"
        case 10: return "gaschange"
        case 11: return "safetystop_voluntary"
        case 12: return "safetystop_mandatory"
        case 13: return "deepstop"
        case 14: return "ceiling_safetystop"
        case 15: return "floor"
        case 16: return "divetime"
        case 17: return "maxdepth"
        case 18: return "OLF"
        case 19: return "PO2"
        case 20: return "airtime"
        case 21: return "rgbm"
        case 22: return "heading"
        case 23: return "tissuelevel"
        case 24: return "gaschange2"
        default: return "unknown_\(type)"
        }
    }

    // MARK: - Parse Raw Dive Data

    func parseRawDiveData(
        vendor: String,
        product: String,
        model: Int64,
        data: FlutterStandardTypedData,
        completion: @escaping (Result<ParsedDive, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var dive = libdc_parsed_dive_t()
            var errorBuf = [CChar](repeating: 0, count: 256)

            let result = data.data.withUnsafeBytes { rawPtr -> Int32 in
                guard let baseAddress = rawPtr.baseAddress else { return -1 }
                return libdc_parse_raw_dive(
                    vendor,
                    product,
                    UInt32(model),
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    UInt32(data.data.count),
                    &dive,
                    &errorBuf,
                    errorBuf.count
                )
            }

            if result != 0 {
                let errorMsg = String(cString: errorBuf)
                free(dive.samples)
                free(dive.events)
                DispatchQueue.main.async {
                    completion(.failure(PigeonError(
                        code: "PARSE_ERROR",
                        message: "Failed to parse raw dive data: \(errorMsg)",
                        details: nil
                    )))
                }
                return
            }

            let parsedDive = self.convertParsedDive(dive)
            free(dive.samples)
            free(dive.events)

            DispatchQueue.main.async {
                completion(.success(parsedDive))
            }
        }
    }

    // MARK: - Version

    func getLibdivecomputerVersion() throws -> String {
        guard let versionPtr = libdc_get_version() else {
            return "unknown"
        }
        return String(cString: versionPtr)
    }

    // MARK: - Helpers

    private func reportError(code: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.flutterApi.onError(error: DiveComputerError(
                code: code,
                message: message
            )) { _ in }
        }
    }
}

private final class BlePeripheralResolver: NSObject, CBCentralManagerDelegate {
    let targetIdentifier: UUID
    let queue: DispatchQueue
    private let allowCachedPeripherals: Bool
    private let semaphore = DispatchSemaphore(value: 0)

    private(set) var centralManager: CBCentralManager?
    private var foundPeripheral: CBPeripheral?
    private var isScanning = false
    private var resolved = false

    init(targetIdentifier: UUID, queue: DispatchQueue, allowCachedPeripherals: Bool = true) {
        self.targetIdentifier = targetIdentifier
        self.queue = queue
        self.allowCachedPeripherals = allowCachedPeripherals
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: queue)
    }

    func resolve(timeout: TimeInterval) -> CBPeripheral? {
        queue.async { [weak self] in
            self?.attemptResolveIfReady()
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            queue.async { [weak self] in
                self?.finish(peripheral: nil)
            }
            return nil
        }

        return queue.sync { foundPeripheral }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard !resolved else { return }

        switch central.state {
        case .poweredOn:
            NativeLogger.d("DiveComputerHost", category: "BLE", "Central powered on, resolving \(targetIdentifier.uuidString)")
            attemptResolveIfReady()
        case .poweredOff, .unauthorized, .unsupported:
            NativeLogger.w("DiveComputerHost", category: "BLE", "Central unavailable (state=\(central.state.rawValue))")
            finish(peripheral: nil)
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard !resolved else { return }
        guard peripheral.identifier == targetIdentifier else { return }
        finish(peripheral: peripheral)
    }

    private func attemptResolveIfReady() {
        guard !resolved else { return }
        guard let central = centralManager, central.state == .poweredOn else { return }

        if allowCachedPeripherals {
            if let cached = central.retrievePeripherals(withIdentifiers: [targetIdentifier]).first {
                NativeLogger.d("DiveComputerHost", category: "BLE", "Found cached peripheral \(targetIdentifier.uuidString)")
                finish(peripheral: cached)
                return
            }
        }

        if !isScanning {
            NativeLogger.d("DiveComputerHost", category: "BLE", "Scanning for \(targetIdentifier.uuidString)")
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
            isScanning = true
        }
    }

    private func finish(peripheral: CBPeripheral?) {
        guard !resolved else { return }
        resolved = true
        foundPeripheral = peripheral
        if isScanning, let central = centralManager {
            central.stopScan()
            isScanning = false
        }
        semaphore.signal()
    }
}
