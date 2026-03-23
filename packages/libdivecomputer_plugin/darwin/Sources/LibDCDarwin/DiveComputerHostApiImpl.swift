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

    private func performDownload(device: DiscoveredDevice, fingerprint: String?) {
        // Create download session.
        guard let session = libdc_download_session_new() else {
            reportError(code: "session_failed", message: "Failed to create download session")
            return
        }
        self.downloadSession = session

        // Get I/O callbacks based on transport type.
        var ioCallbacks: libdc_io_callbacks_t
        switch device.transport {
        case .serial:
            guard let callbacks = connectSerial(device: device, session: session) else { return }
            ioCallbacks = callbacks
        default:
            guard let callbacks = connectBle(device: device, session: session) else { return }
            ioCallbacks = callbacks
        }

        // Build download callbacks.
        // We pass self as userdata via Unmanaged to receive dive/progress events.
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
            NSLog("[DownloadHost] Dive parsed: depth=%.1fm, duration=%ds, samples=%d",
                  parsedDive.maxDepthMeters, parsedDive.durationSeconds,
                  parsedDive.samples.count)
            DispatchQueue.main.async {
                hostApi.flutterApi.onDiveDownloaded(dive: parsedDive) { _ in }
            }
        }
        downloadCallbacks.userdata = selfPtr

        // Map transport type.
        let transportValue: UInt32
        switch device.transport {
        case .ble:
            transportValue = UInt32(LIBDC_TRANSPORT_BLE)
        case .usb:
            transportValue = UInt32(LIBDC_TRANSPORT_USB)
        case .serial:
            transportValue = UInt32(LIBDC_TRANSPORT_SERIAL)
        case .infrared:
            transportValue = UInt32(LIBDC_TRANSPORT_IRDA)
        }

        // Decode fingerprint from hex string if provided.
        var fingerprintBytes: [UInt8]? = nil
        if let hex = fingerprint, !hex.isEmpty {
            fingerprintBytes = stride(from: 0, to: hex.count, by: 2).compactMap { i in
                let start = hex.index(hex.startIndex, offsetBy: i)
                let end = hex.index(start, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
                return UInt8(hex[start..<end], radix: 16)
            }
        }

        // Run the download (blocks until complete).
        var serial: UInt32 = 0
        var firmware: UInt32 = 0
        var errorBuf = [CChar](repeating: 0, count: 256)
        let result: Int32
        if let fp = fingerprintBytes, !fp.isEmpty {
            result = fp.withUnsafeBufferPointer { buf in
                libdc_download_run(
                    session,
                    device.vendor, device.product, UInt32(device.model),
                    transportValue,
                    &ioCallbacks,
                    buf.baseAddress, UInt32(buf.count),
                    &downloadCallbacks,
                    &serial,
                    &firmware,
                    &errorBuf, errorBuf.count
                )
            }
        } else {
            result = libdc_download_run(
                session,
                device.vendor, device.product, UInt32(device.model),
                transportValue,
                &ioCallbacks,
                nil, 0,
                &downloadCallbacks,
                &serial,
                &firmware,
                &errorBuf, errorBuf.count
            )
        }

        // Format device info as strings for Dart.
        let serialStr: String? = serial > 0 ? String(serial) : nil
        let firmwareStr: String? = firmware > 0 ? String(firmware) : nil
        NSLog("[DownloadHost] Device info: serial=%u, firmware=%u", serial, firmware)

        // Report completion or error.
        NSLog("[DownloadHost] libdc_download_run returned result=%d", result)
        if result == 0 {
            NSLog("[DownloadHost] Download succeeded, sending onDownloadComplete")
            DispatchQueue.main.async { [weak self] in
                self?.flutterApi.onDownloadComplete(
                    totalDives: 0,
                    serialNumber: serialStr,
                    firmwareVersion: firmwareStr
                ) { _ in }
            }
        } else if result == Int32(LIBDC_STATUS_CANCELLED) {
            NSLog("[DownloadHost] Download cancelled, sending onDownloadComplete")
            // Still send completion so the Dart side can import any dives
            // that were downloaded before cancellation.
            DispatchQueue.main.async { [weak self] in
                self?.flutterApi.onDownloadComplete(
                    totalDives: 0,
                    serialNumber: serialStr,
                    firmwareVersion: firmwareStr
                ) { _ in }
            }
        } else {
            let errorMsg = String(cString: errorBuf)
            NSLog("[DownloadHost] Download error (result=%d): %@", result, errorMsg)
            reportError(code: "download_error", message: errorMsg)
        }

        // Cleanup.
        libdc_download_session_free(session)
        self.downloadSession = nil
        self.activeBleStream = nil
        self.activeSerialStream = nil
    }

    // MARK: - Transport Connection

    private func connectBle(
        device: DiscoveredDevice, session: OpaquePointer
    ) -> libdc_io_callbacks_t? {
        guard let uuid = UUID(uuidString: device.address) else {
            reportError(code: "invalid_address", message: "Invalid device address")
            libdc_download_session_free(session)
            self.downloadSession = nil
            return nil
        }

        if let scanner = bleScanner {
            NSLog("[BleHost] Stopping BLE scan before download connect")
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
            NSLog("[BleHost] Resolve/connect attempt %ld (%@) for %@ (%@ %@)",
                  index + 1, plan.label, device.address, device.vendor, device.product)
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
                NSLog("[BleHost] Peripheral resolve failed on attempt %ld", index + 1)
                continue
            }
            NSLog("[BleHost] Peripheral resolved: %@ (%@)",
                  peripheral.identifier.uuidString, peripheral.name ?? "unknown")

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

            NSLog("[BleHost] connectAndDiscover failed on attempt %ld for %@",
                  index + 1, peripheral.identifier.uuidString)
            if peripheral.state != .disconnected {
                centralMgr.cancelPeripheralConnection(peripheral)
            }
        }

        guard let bleStream = connectedStream else {
            reportError(code: "connect_failed", message: "Failed to connect to device")
            libdc_download_session_free(session)
            self.downloadSession = nil
            self.activeBleStream = nil
            return nil
        }
        return bleStream.makeCallbacks()
    }

    private func connectSerial(
        device: DiscoveredDevice, session: OpaquePointer
    ) -> libdc_io_callbacks_t? {
        // macOS does not have auto-probe logic (unlike Linux/Windows) because
        // serial devices are always discovered via SerialScanner first, which
        // provides the exact /dev/cu.* path. Manual model selection on macOS
        // also goes through the scanner, so the address is always a valid
        // device path by the time we reach here.
        let serialStream = SerialIoStream()
        guard serialStream.open(path: device.address) else {
            reportError(
                code: "connect_failed",
                message: "Failed to open serial port: \(device.address)"
            )
            libdc_download_session_free(session)
            self.downloadSession = nil
            return nil
        }
        NSLog("[SerialHost] Opened serial port: %@", device.address)
        self.activeSerialStream = serialStream
        return serialStream.makeCallbacks()
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
                    tts: s.deco_tts == UInt32.max || s.deco_tts == 0 ? nil : Int64(s.deco_tts)
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
            decoConservatism: dive.deco_conservatism == 0 ? nil : Int64(dive.deco_conservatism)
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
            NSLog("[BleResolver] Central powered on, resolving %@", targetIdentifier.uuidString)
            attemptResolveIfReady()
        case .poweredOff, .unauthorized, .unsupported:
            NSLog("[BleResolver] Central unavailable (state=%ld)", central.state.rawValue)
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
                NSLog("[BleResolver] Found cached peripheral %@", targetIdentifier.uuidString)
                finish(peripheral: cached)
                return
            }
        }

        if !isScanning {
            NSLog("[BleResolver] Scanning for %@", targetIdentifier.uuidString)
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
