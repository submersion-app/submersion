import CoreBluetooth
import Foundation

/// Bridges CoreBluetooth BLE communication to libdivecomputer's synchronous
/// iostream interface using semaphores.
///
/// libdivecomputer calls read/write synchronously on a background thread.
/// This class translates those calls to async CoreBluetooth operations,
/// blocking with semaphores until the BLE operation completes.
class BleIoStream: NSObject, CBPeripheralDelegate {
    private struct CharacteristicCandidate {
        let score: Int
        let write: CBCharacteristic
        let notify: CBCharacteristic
    }

    private static let preferredServiceUUIDs: Set<CBUUID> = [
        CBUUID(string: "CB3C4555-D670-4670-BC20-B61DBC851E9A"),
    ]

    private static let preferredWriteUUIDs: Set<CBUUID> = [
        CBUUID(string: "6606AB42-89D5-4A00-A8CE-4EB5E1414EE0"),
    ]

    private static let preferredNotifyUUIDs: Set<CBUUID> = [
        CBUUID(string: "A60B8E5C-B267-44D7-9764-837CAF96489E"),
    ]

    private static let pelagicGen1TxCharacteristic = CBUUID(
        string: "6606AB42-89D5-4A00-A8CE-4EB5E1414EE0"
    )
    private static let notifySettleDelaySeconds: TimeInterval = 0.3
    private static let bleIoctlType: UInt32 = UInt32(Character("b").asciiValue!)
    private static let bleIoctlGetNameNumber: UInt32 = 0
    private static let directionInput: UInt32 = 1
    private static let maxLogBytes = 24

    let peripheral: CBPeripheral
    private let centralManager: CBCentralManager

    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var bestCandidate: CharacteristicCandidate?
    private var remainingServiceDiscoveries = 0
    private var discoverySignaled = false

    private let readLock = NSLock()
    private var readBuffer = Data()
    private let readSemaphore = DispatchSemaphore(value: 0)
    private let writeSemaphore = DispatchSemaphore(value: 0)
    private let writeReadySemaphore = DispatchSemaphore(value: 0)
    private let connectSemaphore = DispatchSemaphore(value: 0)
    private let discoverSemaphore = DispatchSemaphore(value: 0)

    private var timeoutMs: Int = 10000
    private var connectError: Error?
    private var isReady = false
    private var waitingForNotifyEnable = false
    private var lastWriteError: Error?
    private var hasSeenNotify = false
    private var writeWithoutResponsePreferred = false
    private var consecutiveReadTimeouts = 0

    init(peripheral: CBPeripheral, centralManager: CBCentralManager) {
        self.peripheral = peripheral
        self.centralManager = centralManager
        super.init()
        self.centralManager.delegate = self
        self.peripheral.delegate = self
    }

    /// Build the libdc_io_callbacks_t struct pointing to this instance.
    /// The caller must keep this BleIoStream alive while the callbacks are in use.
    func makeCallbacks() -> libdc_io_callbacks_t {
        let opaque = Unmanaged.passUnretained(self).toOpaque()
        var cbs = libdc_io_callbacks_t()
        cbs.set_timeout = BleIoStream.cSetTimeout
        cbs.read = BleIoStream.cRead
        cbs.write = BleIoStream.cWrite
        cbs.ioctl = BleIoStream.cIoctl
        cbs.close = BleIoStream.cClose
        cbs.poll = BleIoStream.cPoll
        cbs.purge = BleIoStream.cPurge
        cbs.sleep = nil
        cbs.userdata = opaque
        return cbs
    }

    // MARK: - Connection

    /// Connect to the peripheral and discover services/characteristics.
    /// Blocks until ready or timeout. Returns true on success.
    func connectAndDiscover() -> Bool {
        NSLog(
            "[BleIoStream] connectAndDiscover start for %@ (peripheralState=%ld centralState=%ld)",
            peripheral.identifier.uuidString,
            peripheral.state.rawValue,
            centralManager.state.rawValue
        )

        guard centralManager.state == .poweredOn else {
            NSLog("[BleIoStream] Central not powered on (state=%ld)", centralManager.state.rawValue)
            return false
        }

        connectError = nil
        isReady = false
        waitingForNotifyEnable = false
        discoverySignaled = false
        remainingServiceDiscoveries = 0
        bestCandidate = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        hasSeenNotify = false
        writeWithoutResponsePreferred = false
        consecutiveReadTimeouts = 0

        switch peripheral.state {
        case .connected:
            NSLog("[BleIoStream] Peripheral already connected; skipping connect wait")
        case .connecting:
            NSLog("[BleIoStream] Peripheral already connecting; waiting for callback")
            let result = connectSemaphore.wait(timeout: .now() + .seconds(15))
            if result == .timedOut {
                NSLog("[BleIoStream] Timed out waiting for in-flight connect callback")
                centralManager.cancelPeripheralConnection(peripheral)
                return false
            }
            if let error = connectError {
                NSLog("[BleIoStream] In-flight connect failed: %@", error.localizedDescription)
                centralManager.cancelPeripheralConnection(peripheral)
                return false
            }
        default:
            centralManager.connect(peripheral, options: nil)
            let result = connectSemaphore.wait(timeout: .now() + .seconds(15))
            if result == .timedOut {
                NSLog("[BleIoStream] Timed out waiting for connect callback")
                centralManager.cancelPeripheralConnection(peripheral)
                return false
            }
            if let error = connectError {
                NSLog("[BleIoStream] Connect failed: %@", error.localizedDescription)
                centralManager.cancelPeripheralConnection(peripheral)
                return false
            }
        }

        NSLog("[BleIoStream] Connected; discovering services")
        peripheral.discoverServices(nil)
        let discoverResult = discoverSemaphore.wait(timeout: .now() + .seconds(10))
        if discoverResult == .timedOut {
            NSLog("[BleIoStream] Timed out waiting for service/characteristic discovery")
            centralManager.cancelPeripheralConnection(peripheral)
            return false
        }
        if !isReady {
            NSLog("[BleIoStream] Discovery completed without usable write/notify characteristics")
            centralManager.cancelPeripheralConnection(peripheral)
            return false
        }
        Thread.sleep(forTimeInterval: Self.notifySettleDelaySeconds)
        NSLog("[BleIoStream] Post-notify settle delay complete (%.0f ms)",
              Self.notifySettleDelaySeconds * 1000)
        NSLog("[BleIoStream] Discovery ready (write=%@ notify=%@)",
              writeCharacteristic?.uuid.uuidString ?? "nil",
              notifyCharacteristic?.uuid.uuidString ?? "nil")
        return true
    }

    // MARK: - C Callback Implementations

    private static let cSetTimeout: libdc_io_set_timeout_fn = { userdata, timeout in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        let appliedTimeout: Int
        if timeout < 0 {
            appliedTimeout = Int.max
        } else {
            // BLE links can be briefly delayed during pairing/auth setup.
            appliedTimeout = max(Int(timeout), 3000)
        }
        stream.timeoutMs = appliedTimeout
        NSLog("[BleIoStream] set_timeout requested=%d applied=%ld", timeout, appliedTimeout)
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private static let cRead: libdc_io_read_fn = { userdata, data, size, actual in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        guard let actual else {
            var transferred: size_t = 0
            let status = stream.performRead(data: data!, size: size, actual: &transferred)
            if status != Int32(LIBDC_STATUS_SUCCESS) {
                return status
            }
            return transferred == size ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_TIMEOUT)
        }
        return stream.performRead(data: data!, size: size, actual: actual)
    }

    private static let cWrite: libdc_io_write_fn = { userdata, data, size, actual in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        guard let actual else {
            var transferred: size_t = 0
            return stream.performWrite(data: data!, size: size, actual: &transferred)
        }
        return stream.performWrite(data: data!, size: size, actual: actual)
    }

    private static let cIoctl: libdc_io_ioctl_fn = { userdata, request, data, size in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        return stream.performIoctl(request: request, data: data, size: size)
    }

    private static let cClose: libdc_io_close_fn = { userdata in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        stream.centralManager.cancelPeripheralConnection(stream.peripheral)
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private static let cPurge: libdc_io_purge_fn = { userdata, direction in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        return stream.performPurge(direction: direction)
    }

    private static let cPoll: libdc_io_poll_fn = { userdata, timeout in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        stream.readLock.lock()
        let available = stream.readBuffer.count
        stream.readLock.unlock()
        if available > 0 { return Int32(LIBDC_STATUS_SUCCESS) }

        if timeout == 0 { return Int32(LIBDC_STATUS_TIMEOUT) }

        let deadline: DispatchTime = timeout < 0 ? .distantFuture :
            .now() + .milliseconds(Int(timeout))
        let result = stream.readSemaphore.wait(timeout: deadline)
        if result == .timedOut { return Int32(LIBDC_STATUS_TIMEOUT) }

        // Re-signal since we consumed the signal but didn't consume data.
        stream.readSemaphore.signal()
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    // MARK: - I/O Operations

    private func performRead(data: UnsafeMutableRawPointer, size: size_t,
                              actual: UnsafeMutablePointer<size_t>) -> Int32 {
        let deadline: DispatchTime = timeoutMs == Int.max ? .distantFuture :
            .now() + .milliseconds(timeoutMs)

        while true {
            readLock.lock()
            let available = readBuffer.count
            if available > 0 {
                let bytesToRead = min(size, readBuffer.count)
                _ = readBuffer.withUnsafeBytes { ptr in
                    memcpy(data, ptr.baseAddress!, bytesToRead)
                }
                readBuffer.removeFirst(bytesToRead)
                readLock.unlock()
                actual.pointee = bytesToRead
                return Int32(LIBDC_STATUS_SUCCESS)
            }
            readLock.unlock()

            if readSemaphore.wait(timeout: deadline) == .timedOut {
                actual.pointee = 0
                consecutiveReadTimeouts += 1
                maybeFlipWriteModeAfterReadTimeout()
                return Int32(LIBDC_STATUS_TIMEOUT)
            }
        }
    }

    private func performWrite(data: UnsafeRawPointer, size: size_t,
                               actual: UnsafeMutablePointer<size_t>) -> Int32 {
        guard let characteristic = writeCharacteristic else {
            return Int32(LIBDC_STATUS_IO)
        }

        let writeData = Data(bytes: data, count: size)
        let properties = characteristic.properties
        let supportsWriteWithResponse = properties.contains(.write)
        let supportsWriteWithoutResponse = properties.contains(.writeWithoutResponse)
        let writeType: CBCharacteristicWriteType
        if supportsWriteWithResponse && supportsWriteWithoutResponse {
            writeType = writeWithoutResponsePreferred ? .withoutResponse : .withResponse
        } else if supportsWriteWithoutResponse {
            writeType = .withoutResponse
        } else if supportsWriteWithResponse {
            writeType = .withResponse
        } else {
            NSLog("[BleIoStream] write characteristic %@ has no write properties",
                  characteristic.uuid.uuidString)
            return Int32(LIBDC_STATUS_IO)
        }

        if writeType == .withResponse {
            drainSemaphore(writeSemaphore)
            lastWriteError = nil
        } else if !peripheral.canSendWriteWithoutResponse {
            drainSemaphore(writeReadySemaphore)
            let writeReadyDeadline: DispatchTime =
                timeoutMs == Int.max ? .distantFuture : .now() + .milliseconds(timeoutMs)
            let ready = writeReadySemaphore.wait(timeout: writeReadyDeadline)
            if ready == .timedOut {
                NSLog("[BleIoStream] write blocked waiting for canSendWriteWithoutResponse")
                return Int32(LIBDC_STATUS_TIMEOUT)
            }
        }
        NSLog(
            "[BleIoStream] write %@ %@ bytes=%ld data=%@",
            writeType == .withResponse ? "withResponse" : "withoutResponse",
            characteristic.uuid.uuidString,
            size,
            Self.hexString(writeData, maxBytes: Self.maxLogBytes)
        )
        peripheral.writeValue(writeData, for: characteristic, type: writeType)

        if writeType == .withResponse {
            let writeDeadline: DispatchTime =
                timeoutMs == Int.max ? .distantFuture : .now() + .milliseconds(timeoutMs)
            let result = writeSemaphore.wait(
                timeout: writeDeadline
            )
            if result == .timedOut {
                NSLog("[BleIoStream] write withResponse timed out for %@", characteristic.uuid.uuidString)
                if supportsWriteWithoutResponse {
                    writeWithoutResponsePreferred = true
                    NSLog("[BleIoStream] Switching preferred write mode to withoutResponse after timeout")
                }
                return Int32(LIBDC_STATUS_TIMEOUT)
            }
            if let error = lastWriteError {
                NSLog("[BleIoStream] write withResponse failed for %@: %@",
                      characteristic.uuid.uuidString, error.localizedDescription)
                if supportsWriteWithoutResponse {
                    writeWithoutResponsePreferred = true
                    NSLog("[BleIoStream] Switching preferred write mode to withoutResponse after write error")
                }
                return Int32(LIBDC_STATUS_IO)
            }
        }

        actual.pointee = size
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func performPurge(direction: UInt32) -> Int32 {
        guard (direction & Self.directionInput) != 0 else {
            return Int32(LIBDC_STATUS_SUCCESS)
        }

        readLock.lock()
        readBuffer.removeAll(keepingCapacity: true)
        readLock.unlock()
        drainSemaphore(readSemaphore)
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func drainSemaphore(_ semaphore: DispatchSemaphore) {
        while semaphore.wait(timeout: .now()) == .success {
            // Drain all pending signals to avoid stale wakeups.
        }
    }

    private static func hexString(_ data: Data, maxBytes: Int) -> String {
        if data.isEmpty { return "<empty>" }
        let limit = min(maxBytes, data.count)
        let bytes = [UInt8](data.prefix(limit))
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        if data.count > limit {
            return "\(hex)...(+\(data.count - limit))"
        }
        return hex
    }

    private static func propertySummary(_ properties: CBCharacteristicProperties) -> String {
        var values: [String] = []
        if properties.contains(.read) { values.append("read") }
        if properties.contains(.write) { values.append("write") }
        if properties.contains(.writeWithoutResponse) { values.append("writeNoRsp") }
        if properties.contains(.notify) { values.append("notify") }
        if properties.contains(.indicate) { values.append("indicate") }
        if properties.contains(.notifyEncryptionRequired) { values.append("notifyEnc") }
        if properties.contains(.indicateEncryptionRequired) { values.append("indicateEnc") }
        if properties.contains(.authenticatedSignedWrites) { values.append("signedWrite") }
        if values.isEmpty { return "none" }
        return values.joined(separator: ",")
    }

    private func initialWriteWithoutResponsePreference(for characteristic: CBCharacteristic) -> Bool {
        let properties = characteristic.properties
        if characteristic.uuid == Self.pelagicGen1TxCharacteristic {
            return true
        }
        return properties.contains(.writeWithoutResponse) && !properties.contains(.write)
    }

    private func maybeFlipWriteModeAfterReadTimeout() {
        guard consecutiveReadTimeouts == 1 else { return }
        guard let characteristic = writeCharacteristic else { return }
        let properties = characteristic.properties
        guard properties.contains(.write) && properties.contains(.writeWithoutResponse) else { return }
        writeWithoutResponsePreferred.toggle()
        NSLog(
            "[BleIoStream] Read timed out before response; flipping preferred write mode to %@",
            writeWithoutResponsePreferred ? "withoutResponse" : "withResponse"
        )
    }

    private func performIoctl(request: UInt32, data: UnsafeMutableRawPointer?,
                               size: size_t) -> Int32 {
        let ioctlType = (request >> 8) & 0xFF
        let ioctlNumber = request & 0xFF
        if ioctlType == Self.bleIoctlType && ioctlNumber == Self.bleIoctlGetNameNumber {
            guard let data, size > 0 else {
                return Int32(LIBDC_STATUS_INVALIDARGS)
            }
            guard let name = peripheral.name, !name.isEmpty else {
                return Int32(LIBDC_STATUS_UNSUPPORTED)
            }
            guard let cString = name.cString(using: .utf8), !cString.isEmpty else {
                return Int32(LIBDC_STATUS_UNSUPPORTED)
            }

            let maxCount = Int(size)
            let copyCount = min(cString.count, maxCount)
            _ = cString.withUnsafeBytes { bytes in
                memcpy(data, bytes.baseAddress!, copyCount)
            }
            if copyCount == maxCount {
                data.assumingMemoryBound(to: CChar.self)[maxCount - 1] = 0
            }
            NSLog("[BleIoStream] ioctl BLE_GET_NAME -> %@", name)
            return Int32(LIBDC_STATUS_SUCCESS)
        }

        return Int32(LIBDC_STATUS_UNSUPPORTED)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            NSLog("[BleIoStream] didDiscoverServices failed: %@", error.localizedDescription)
            signalDiscoveryReady()
            return
        }
        guard let services = peripheral.services else {
            NSLog("[BleIoStream] didDiscoverServices returned nil services")
            signalDiscoveryReady()
            return
        }

        if services.isEmpty {
            NSLog("[BleIoStream] No services discovered")
            signalDiscoveryReady()
            return
        }

        remainingServiceDiscoveries = services.count
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                     didDiscoverCharacteristicsFor service: CBService,
                     error: Error?) {
        if let error {
            NSLog("[BleIoStream] didDiscoverCharacteristics failed for %@: %@",
                  service.uuid.uuidString, error.localizedDescription)
        } else if let characteristics = service.characteristics {
            NSLog("[BleIoStream] Discovered %ld characteristics for %@",
                  characteristics.count, service.uuid.uuidString)
            updateBestCandidate(service: service, characteristics: characteristics)
        }

        if remainingServiceDiscoveries > 0 {
            remainingServiceDiscoveries -= 1
        }
        if remainingServiceDiscoveries == 0 {
            finalizeCharacteristicSelection()
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                     didUpdateValueFor characteristic: CBCharacteristic,
                     error: Error?) {
        if let error {
            NSLog("[BleIoStream] didUpdateValue error for %@: %@",
                  characteristic.uuid.uuidString, error.localizedDescription)
            return
        }
        if let notify = notifyCharacteristic, characteristic.uuid != notify.uuid {
            return
        }
        guard let value = characteristic.value else { return }
        hasSeenNotify = true
        consecutiveReadTimeouts = 0
        NSLog("[BleIoStream] notify %@ bytes=%ld data=%@",
              characteristic.uuid.uuidString,
              value.count,
              Self.hexString(value, maxBytes: Self.maxLogBytes))
        readLock.lock()
        readBuffer.append(value)
        readLock.unlock()
        readSemaphore.signal()
    }

    func peripheral(_ peripheral: CBPeripheral,
                     didWriteValueFor characteristic: CBCharacteristic,
                     error: Error?) {
        lastWriteError = error
        if let error {
            NSLog("[BleIoStream] didWriteValue error for %@: %@",
                  characteristic.uuid.uuidString, error.localizedDescription)
        } else {
            NSLog("[BleIoStream] didWriteValue ok for %@", characteristic.uuid.uuidString)
        }
        writeSemaphore.signal()
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let notify = notifyCharacteristic, characteristic.uuid == notify.uuid else {
            return
        }
        guard waitingForNotifyEnable else { return }
        waitingForNotifyEnable = false

        if let error {
            NSLog("[BleIoStream] Failed enabling notify for %@: %@",
                  characteristic.uuid.uuidString, error.localizedDescription)
            signalDiscoveryReady()
            return
        }
        if !characteristic.isNotifying {
            NSLog("[BleIoStream] Notify not active for %@", characteristic.uuid.uuidString)
            signalDiscoveryReady()
            return
        }
        NSLog("[BleIoStream] Notify enabled for %@", characteristic.uuid.uuidString)
        isReady = true
        signalDiscoveryReady()
    }

    private func signalDiscoveryReady() {
        guard !discoverySignaled else { return }
        discoverySignaled = true
        discoverSemaphore.signal()
    }

    private func updateBestCandidate(service: CBService, characteristics: [CBCharacteristic]) {
        var bestWrite: (characteristic: CBCharacteristic, score: Int)?
        var bestNotify: (characteristic: CBCharacteristic, score: Int)?

        for characteristic in characteristics {
            let props = characteristic.properties

            if props.contains(.write) || props.contains(.writeWithoutResponse) {
                var writeScore = 0
                if props.contains(.writeWithoutResponse) { writeScore += 4 }
                if props.contains(.write) { writeScore += 2 }
                if Self.preferredWriteUUIDs.contains(characteristic.uuid) { writeScore += 1000 }
                if bestWrite == nil || writeScore > bestWrite!.score {
                    bestWrite = (characteristic, writeScore)
                }
            }

            if props.contains(.notify) || props.contains(.indicate) {
                var notifyScore = 0
                if props.contains(.notify) { notifyScore += 4 }
                if props.contains(.indicate) { notifyScore += 2 }
                if Self.preferredNotifyUUIDs.contains(characteristic.uuid) { notifyScore += 1000 }
                if bestNotify == nil || notifyScore > bestNotify!.score {
                    bestNotify = (characteristic, notifyScore)
                }
            }
        }

        guard let write = bestWrite, let notify = bestNotify else {
            return
        }

        var serviceScore = write.score + notify.score
        if Self.preferredServiceUUIDs.contains(service.uuid) {
            serviceScore += 1000
        }

        if let existing = bestCandidate, existing.score >= serviceScore {
            return
        }

        bestCandidate = CharacteristicCandidate(
            score: serviceScore,
            write: write.characteristic,
            notify: notify.characteristic
        )
    }

    private func finalizeCharacteristicSelection() {
        guard let candidate = bestCandidate else {
            NSLog("[BleIoStream] No suitable write/notify characteristic pair found")
            signalDiscoveryReady()
            return
        }

        writeCharacteristic = candidate.write
        notifyCharacteristic = candidate.notify
        writeWithoutResponsePreferred = initialWriteWithoutResponsePreference(for: candidate.write)
        NSLog("[BleIoStream] Selected write=%@ (%@) notify=%@ (%@) (score=%d)",
              candidate.write.uuid.uuidString,
              Self.propertySummary(candidate.write.properties),
              candidate.notify.uuid.uuidString,
              Self.propertySummary(candidate.notify.properties),
              candidate.score)
        NSLog("[BleIoStream] Initial write mode preference: %@",
              writeWithoutResponsePreferred ? "withoutResponse" : "withResponse")
        if candidate.notify.isNotifying {
            isReady = true
            signalDiscoveryReady()
            return
        }
        waitingForNotifyEnable = true
        peripheral.setNotifyValue(true, for: candidate.notify)
    }
}

// MARK: - CBCentralManagerDelegate (connection callbacks)

extension BleIoStream: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("[BleIoStream] central state updated: %ld", central.state.rawValue)
    }

    func centralManager(_ central: CBCentralManager,
                         didConnect peripheral: CBPeripheral) {
        NSLog("[BleIoStream] didConnect %@", peripheral.identifier.uuidString)
        connectError = nil
        connectSemaphore.signal()
    }

    func centralManager(_ central: CBCentralManager,
                         didFailToConnect peripheral: CBPeripheral,
                         error: Error?) {
        if let error {
            NSLog("[BleIoStream] didFailToConnect %@: %@",
                  peripheral.identifier.uuidString, error.localizedDescription)
        } else {
            NSLog("[BleIoStream] didFailToConnect %@ (no error)",
                  peripheral.identifier.uuidString)
        }
        connectError = error
        connectSemaphore.signal()
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        writeReadySemaphore.signal()
    }
}
