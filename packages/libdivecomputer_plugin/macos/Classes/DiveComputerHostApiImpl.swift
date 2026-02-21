import FlutterMacOS
import CoreBluetooth

class DiveComputerHostApiImpl: DiveComputerHostApi {
    private let messenger: FlutterBinaryMessenger
    private let flutterApi: DiveComputerFlutterApi
    private var bleScanner: BleScanner?
    private var downloadSession: OpaquePointer?  // libdc_download_session_t*
    private var activeBleStream: BleIoStream?

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
        default:
            flutterApi.onError(error: DiveComputerError(
                code: "unsupported_transport",
                message: "Transport \(transport) not yet supported on macOS"
            )) { _ in }
        }
        completion(.success(()))
    }

    func stopDiscovery() throws {
        bleScanner?.stop()
        bleScanner = nil
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

    // MARK: - Download

    func startDownload(device: DiscoveredDevice, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.performDownload(device: device)
        }
    }

    func cancelDownload() throws {
        if let session = downloadSession {
            libdc_download_cancel(session)
        }
    }

    private func performDownload(device: DiscoveredDevice) {
        // Create download session.
        guard let session = libdc_download_session_new() else {
            reportError(code: "session_failed", message: "Failed to create download session")
            return
        }
        self.downloadSession = session

        guard let uuid = UUID(uuidString: device.address) else {
            reportError(code: "invalid_address", message: "Invalid device address")
            libdc_download_session_free(session)
            self.downloadSession = nil
            return
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
            return
        }
        self.activeBleStream = bleStream

        // Build I/O callbacks.
        var ioCallbacks = bleStream.makeCallbacks()

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

        // Run the download (blocks until complete).
        var errorBuf = [CChar](repeating: 0, count: 256)
        let result = libdc_download_run(
            session,
            device.vendor, device.product, UInt32(device.model),
            transportValue,
            &ioCallbacks,
            nil, 0,  // No fingerprint for now (download all dives)
            &downloadCallbacks,
            &errorBuf, errorBuf.count
        )

        // Report completion or error.
        NSLog("[DownloadHost] libdc_download_run returned result=%d", result)
        if result == 0 {
            NSLog("[DownloadHost] Download succeeded, sending onDownloadComplete")
            DispatchQueue.main.async { [weak self] in
                self?.flutterApi.onDownloadComplete(totalDives: 0) { _ in }
            }
        } else if result == Int32(LIBDC_STATUS_CANCELLED) {
            NSLog("[DownloadHost] Download cancelled, sending onDownloadComplete")
            // Still send completion so the Dart side can import any dives
            // that were downloaded before cancellation.
            DispatchQueue.main.async { [weak self] in
                self?.flutterApi.onDownloadComplete(totalDives: 0) { _ in }
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

        // Convert datetime to epoch seconds.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = Int(dive.year)
        components.month = Int(dive.month)
        components.day = Int(dive.day)
        components.hour = Int(dive.hour)
        components.minute = Int(dive.minute)
        components.second = Int(dive.second)
        let epoch = calendar.date(from: components).map {
            Int64($0.timeIntervalSince1970)
        } ?? 0

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
                    heartRate: nil
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

        return ParsedDive(
            fingerprint: fingerprintHex,
            dateTimeEpoch: epoch,
            maxDepthMeters: dive.max_depth,
            avgDepthMeters: dive.avg_depth,
            durationSeconds: Int64(dive.duration),
            minTemperatureCelsius: dive.min_temp.isNaN ? nil : dive.min_temp,
            maxTemperatureCelsius: dive.max_temp.isNaN ? nil : dive.max_temp,
            samples: samples,
            tanks: tanks,
            gasMixes: gasMixes,
            events: [],
            diveMode: diveModeStr
        )
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
