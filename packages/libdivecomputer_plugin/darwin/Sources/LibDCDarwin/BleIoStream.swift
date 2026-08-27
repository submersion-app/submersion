import CoreBluetooth
import Foundation

/// Bridges CoreBluetooth BLE communication to libdivecomputer's synchronous
/// iostream interface using semaphores.
///
/// libdivecomputer calls read/write synchronously on a background thread.
/// This class translates those calls to async CoreBluetooth operations,
/// blocking with semaphores until the BLE operation completes.
class BleIoStream: NSObject, CBPeripheralDelegate {
    // Characteristic scoring and the device-specific Tx/Rx preferences live in
    // BleCharacteristicSelector so they can be unit-tested standalone.

    private static let pelagicGen1TxCharacteristic = CBUUID(
        string: "6606AB42-89D5-4A00-A8CE-4EB5E1414EE0"
    )
    private static let notifySettleDelaySeconds: TimeInterval = 0.3
    /// Bound on the opening credit grant.
    ///
    /// Deliberately fixed rather than derived from `timeoutMs`. This runs
    /// inside connectAndDiscover, before libdivecomputer has been handed the
    /// iostream callbacks, so `set_timeout` cannot have been called yet and
    /// `timeoutMs` is still its 10000 ms initialiser -- the two are the same
    /// number. Following the caller's timeout would also let libdivecomputer's
    /// negative "no timeout" (mapped to `.distantFuture` on the I/O path) hang
    /// connection setup indefinitely. The neighbouring setup waits are bounded
    /// the same way: 15 s to connect, 10 s to discover.
    private static let creditGrantTimeoutSeconds: DispatchTimeInterval = .seconds(10)
    private static let bleIoctlType: UInt32 = UInt32(Character("b").asciiValue!)
    private static let bleIoctlGetNameNumber: UInt32 = 0
    private static let bleIoctlGetPinCodeNumber: UInt32 = 1
    private static let bleIoctlAccessCodeNumber: UInt32 = 2
    private static let ioctlDirRead: UInt32 = 1
    private static let ioctlDirWrite: UInt32 = 2
    private static let pinTimeoutSeconds: TimeInterval = 60
    private static let directionInput: UInt32 = 1
    private static let maxLogBytes = 24

    let peripheral: CBPeripheral
    private let centralManager: CBCentralManager

    /// Which subscription the discovery state machine is waiting on. Telit
    /// Terminal I/O devices subscribe to UART Credits TX before UART Data TX;
    /// everything else goes straight to `.dataNotify`.
    private enum NotifySetupStep {
        case idle
        case creditsNotify
        case dataNotify
    }

    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    /// UART Credits RX/TX, non-nil only for Telit Terminal I/O devices.
    private var creditsWriteCharacteristic: CBCharacteristic?
    private var creditsNotifyCharacteristic: CBCharacteristic?
    private var creditsRequired = false
    /// Grant awaiting its write confirmation, for mid-transfer top-ups only.
    private var pendingTopUpGrant: UInt8?
    private var creditPolicy = TerminalIoCreditPolicy()
    private var discoveredServices: [(service: CBService, characteristics: [CBCharacteristic])] = []
    private var remainingServiceDiscoveries = 0
    private var discoverySignaled = false

    private let packetBuffer = PacketReadBuffer()
    private let writeSemaphore = DispatchSemaphore(value: 0)
    private let writeReadySemaphore = DispatchSemaphore(value: 0)
    private let creditSemaphore = DispatchSemaphore(value: 0)
    private let connectSemaphore = DispatchSemaphore(value: 0)
    private let discoverSemaphore = DispatchSemaphore(value: 0)

    private var timeoutMs: Int = 10000
    private var connectError: Error?
    private var isReady = false
    private var notifySetupStep: NotifySetupStep = .idle
    private var lastWriteError: Error?
    private var lastCreditWriteError: Error?
    private var hasSeenNotify = false
    private var writeWithoutResponsePreferred = false
    private var consecutiveReadTimeouts = 0

    private let pinSemaphore = DispatchSemaphore(value: 0)
    private var pendingPinCode: String?
    private var deviceAddress: String = ""

    /// Callback invoked on the main thread when a PIN code is needed.
    /// Set by DiveComputerHostApiImpl before download starts.
    var onPinCodeRequired: ((String) -> Void)?

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

    /// Called from main thread to supply PIN code for BLE authentication.
    func submitPinCode(_ pin: String) {
        pendingPinCode = pin
        pinSemaphore.signal()
    }

    /// Set the device address for access code storage.
    func setDeviceAddress(_ address: String) {
        deviceAddress = address
    }

    // MARK: - Connection

    /// Connect to the peripheral and discover services/characteristics.
    /// Blocks until ready or timeout. Returns nil once the stream is usable,
    /// or the reason the attempt was abandoned.
    func connectAndDiscover() -> BleConnectFailure? {
        NativeLogger.d(
            "BleIoStream", category: "BLE",
            "connectAndDiscover start for \(self.peripheral.identifier.uuidString)"
                + " (peripheralState=\(self.peripheral.state.rawValue)"
                + " centralState=\(self.centralManager.state.rawValue))"
        )

        guard centralManager.state == .poweredOn else {
            NativeLogger.w(
                "BleIoStream", category: "BLE",
                "Central not powered on (state=\(self.centralManager.state.rawValue))"
            )
            return .other
        }

        connectError = nil
        isReady = false
        notifySetupStep = .idle
        discoverySignaled = false
        remainingServiceDiscoveries = 0
        discoveredServices.removeAll()
        writeCharacteristic = nil
        notifyCharacteristic = nil
        creditsWriteCharacteristic = nil
        creditsNotifyCharacteristic = nil
        creditsRequired = false
        pendingTopUpGrant = nil
        creditPolicy = TerminalIoCreditPolicy()
        lastCreditWriteError = nil
        hasSeenNotify = false
        writeWithoutResponsePreferred = false
        consecutiveReadTimeouts = 0

        switch peripheral.state {
        case .connected:
            NativeLogger.d("BleIoStream", category: "BLE",
                "Peripheral already connected; skipping connect wait")
        case .connecting:
            NativeLogger.d("BleIoStream", category: "BLE",
                "Peripheral already connecting; waiting for callback")
            let result = connectSemaphore.wait(timeout: .now() + .seconds(15))
            if result == .timedOut {
                NativeLogger.w("BleIoStream", category: "BLE",
                    "Timed out waiting for in-flight connect callback")
                centralManager.cancelPeripheralConnection(peripheral)
                return .other
            }
            if let error = connectError {
                NativeLogger.e("BleIoStream", category: "BLE",
                    "In-flight connect failed: \(error.localizedDescription)")
                centralManager.cancelPeripheralConnection(peripheral)
                return BleConnectFailure.fromConnectError(error)
            }
        default:
            centralManager.connect(peripheral, options: nil)
            let result = connectSemaphore.wait(timeout: .now() + .seconds(15))
            if result == .timedOut {
                NativeLogger.w("BleIoStream", category: "BLE",
                    "Timed out waiting for connect callback")
                centralManager.cancelPeripheralConnection(peripheral)
                return .other
            }
            if let error = connectError {
                NativeLogger.e("BleIoStream", category: "BLE",
                    "Connect failed: \(error.localizedDescription)")
                centralManager.cancelPeripheralConnection(peripheral)
                return BleConnectFailure.fromConnectError(error)
            }
        }

        // CoreBluetooth exposes no connection-interval/priority API (unlike
        // Android's requestConnectionPriority or Windows' preferred connection
        // parameters): iOS negotiates the interval from the peripheral's
        // preferred values. High-rate dumps (e.g. the OSTC nano logbook, #280)
        // therefore rely on the device pacing itself; the hw_ostc3 read fix
        // handles correctly-delivered data and a retry covers transient loss.
        NativeLogger.d("BleIoStream", category: "BLE", "Connected; discovering services")
        peripheral.discoverServices(nil)
        let discoverResult = discoverSemaphore.wait(timeout: .now() + .seconds(10))
        if discoverResult == .timedOut {
            // The link is up but the peer never answered, so this is not the
            // "no usable characteristics" case below: nothing was enumerated at
            // all. On macOS that is what a stale bond looks like -- iOS names
            // the condition, macOS just waits (issue #865).
            NativeLogger.w("BleIoStream", category: "BLE",
                "Timed out waiting for service/characteristic discovery")
            centralManager.cancelPeripheralConnection(peripheral)
            return .discoveryStalled
        }
        if !isReady {
            NativeLogger.w("BleIoStream", category: "BLE",
                "Discovery completed without usable write/notify characteristics")
            centralManager.cancelPeripheralConnection(peripheral)
            return .other
        }
        // A Telit Terminal I/O module keeps its UART bridge closed until the
        // client grants initial credits, so the first command write would fail
        // outright without this (issue #923).
        if !grantInitialCredits() {
            centralManager.cancelPeripheralConnection(peripheral)
            return .other
        }
        Thread.sleep(forTimeInterval: Self.notifySettleDelaySeconds)
        NativeLogger.d("BleIoStream", category: "BLE",
            "Post-notify settle delay complete (\(Int(Self.notifySettleDelaySeconds * 1000)) ms)")
        NativeLogger.d("BleIoStream", category: "BLE",
            "Discovery ready (write=\(self.writeCharacteristic?.uuid.uuidString ?? "nil")"
                + " notify=\(self.notifyCharacteristic?.uuid.uuidString ?? "nil"))")
        return nil
    }

    // MARK: - Terminal I/O credits

    /// Write the opening credit grant to Credits RX and wait for the
    /// confirmation. A no-op (success) on devices with no credit
    /// characteristics.
    private func grantInitialCredits() -> Bool {
        guard let creditsChar = creditsWriteCharacteristic else { return true }

        let amount = TerminalIoCreditPolicy.initialGrant
        drainSemaphore(creditSemaphore)
        lastCreditWriteError = nil
        NativeLogger.d("BleIoStream", category: "BLE",
            "Terminal I/O: granting \(amount) initial credits on"
                + " \(creditsChar.uuid.uuidString)")
        peripheral.writeValue(Data([amount]), for: creditsChar, type: .withResponse)

        if creditSemaphore.wait(
            timeout: .now() + Self.creditGrantTimeoutSeconds) == .timedOut {
            return creditGrantFailed("timed out granting initial credits")
        }
        if let error = lastCreditWriteError {
            return creditGrantFailed(
                "initial credit grant failed: \(error.localizedDescription)")
        }
        creditPolicy.opened(with: amount)
        NativeLogger.d("BleIoStream", category: "BLE",
            "Terminal I/O: bridge open (credits=\(self.creditPolicy.credits))")
        return true
    }

    /// Decide what a failed opening grant means for this module family.
    ///
    /// A Telit bridge carries nothing without credits, so the connection is
    /// dead. The u-blox serial service treats flow control as optional and
    /// already works with no handshake at all, so drop back to that rather
    /// than fail a device that would otherwise download fine.
    private func creditGrantFailed(_ reason: String) -> Bool {
        if creditsRequired {
            NativeLogger.e("BleIoStream", category: "BLE", "Terminal I/O: \(reason)")
            return false
        }
        NativeLogger.w("BleIoStream", category: "BLE",
            "Terminal I/O: \(reason); continuing without credit flow control")
        creditsWriteCharacteristic = nil

        // Unsubscribe rather than merely ignoring the credit indications. The
        // point is not the discarded delegate callbacks but that the module
        // stops transmitting them at all: this fallback exists for the OSTC
        // nano, whose downloads are already lost to a saturated delegate queue
        // and BLE link (#394), so spending neither airtime nor queue time on a
        // channel we have given up on matters.
        if let creditsNotify = creditsNotifyCharacteristic {
            if creditsNotify.isNotifying {
                peripheral.setNotifyValue(false, for: creditsNotify)
            }
            creditsNotifyCharacteristic = nil
        }
        return true
    }

    /// Account for one received packet and top the module back up when its
    /// balance runs low, so a multi-thousand-notification logbook dump does
    /// not stall once the opening grant is spent.
    ///
    /// Called on the CoreBluetooth delegate queue, so the write is issued
    /// without waiting for its confirmation: blocking this queue starves
    /// notification delivery and loses bytes (issue #394). The balance is
    /// therefore credited later, in didWriteValueFor, once the module has
    /// actually acknowledged the grant -- counting it here would overstate the
    /// balance whenever a write failed, and an overstated balance stalls the
    /// transfer permanently (see TerminalIoCreditPolicy).
    private func replenishCredits() {
        guard let creditsChar = creditsWriteCharacteristic,
            let grant = creditPolicy.packetReceived()
        else { return }

        pendingTopUpGrant = grant
        peripheral.writeValue(Data([grant]), for: creditsChar, type: .withResponse)
        NativeLogger.d("BleIoStream", category: "BLE",
            "Terminal I/O: requesting \(grant) more credits"
                + " (balance=\(self.creditPolicy.credits))")
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
        NativeLogger.d("BleIoStream", category: "BLE",
            "set_timeout requested=\(timeout) applied=\(appliedTimeout)")
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private static let cRead: libdc_io_read_fn = { userdata, data, size, actual in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        guard let actual else {
            var transferred: size_t = 0
            return stream.performRead(data: data!, size: size, actual: &transferred)
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
        if stream.packetBuffer.hasData { return Int32(LIBDC_STATUS_SUCCESS) }

        if timeout == 0 { return Int32(LIBDC_STATUS_TIMEOUT) }

        let deadline: DispatchTime = timeout < 0 ? .distantFuture :
            .now() + .milliseconds(Int(timeout))
        return stream.packetBuffer.poll(deadline: deadline)
            ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_TIMEOUT)
    }

    // MARK: - I/O Operations

    private func performRead(data: UnsafeMutableRawPointer, size: size_t,
                              actual: UnsafeMutablePointer<size_t>) -> Int32 {
        let deadline: DispatchTime = timeoutMs == Int.max ? .distantFuture :
            .now() + .milliseconds(timeoutMs)

        // The buffer returns bytes from at most one BLE notification per
        // call: libdivecomputer's packet parsers size each read from the
        // packet header and would silently drop a second packet coalesced
        // into the same read (lost FLAG_LAST ack -> spurious timeout).
        guard let bytesToRead = packetBuffer.read(
            into: data, maxBytes: size, deadline: deadline) else {
            actual.pointee = 0
            consecutiveReadTimeouts += 1
            maybeFlipWriteModeAfterReadTimeout()
            return Int32(LIBDC_STATUS_TIMEOUT)
        }
        actual.pointee = bytesToRead
        return Int32(LIBDC_STATUS_SUCCESS)
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
            NativeLogger.e("BleIoStream", category: "BLE",
                "write characteristic \(characteristic.uuid.uuidString) has no write properties")
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
                NativeLogger.w("BleIoStream", category: "BLE",
                    "write blocked waiting for canSendWriteWithoutResponse")
                return Int32(LIBDC_STATUS_TIMEOUT)
            }
        }
        NativeLogger.d("BleIoStream", category: "BLE",
            "write \(writeType == .withResponse ? "withResponse" : "withoutResponse")"
                + " \(characteristic.uuid.uuidString)"
                + " bytes=\(size)"
                + " data=\(Self.hexString(writeData, maxBytes: Self.maxLogBytes))"
        )
        peripheral.writeValue(writeData, for: characteristic, type: writeType)

        if writeType == .withResponse {
            let writeDeadline: DispatchTime =
                timeoutMs == Int.max ? .distantFuture : .now() + .milliseconds(timeoutMs)
            let result = writeSemaphore.wait(
                timeout: writeDeadline
            )
            if result == .timedOut {
                NativeLogger.w("BleIoStream", category: "BLE",
                    "write withResponse timed out for \(characteristic.uuid.uuidString)")
                if supportsWriteWithoutResponse {
                    writeWithoutResponsePreferred = true
                    NativeLogger.d("BleIoStream", category: "BLE",
                        "Switching preferred write mode to withoutResponse after timeout")
                }
                return Int32(LIBDC_STATUS_TIMEOUT)
            }
            if let error = lastWriteError {
                NativeLogger.e("BleIoStream", category: "BLE",
                    "write withResponse failed for \(characteristic.uuid.uuidString):"
                        + " \(error.localizedDescription)")
                if supportsWriteWithoutResponse {
                    writeWithoutResponsePreferred = true
                    NativeLogger.d("BleIoStream", category: "BLE",
                        "Switching preferred write mode to withoutResponse after write error")
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

        packetBuffer.purge()
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
        // Snapshot before logging: the message is built later on the logger
        // queue, and reading this mutable flag there would race with the I/O
        // queue that toggles it.
        let preferWithoutResponse = writeWithoutResponsePreferred
        NativeLogger.d("BleIoStream", category: "BLE",
            "Read timed out before response; flipping preferred write mode to"
                + " \(preferWithoutResponse ? "withoutResponse" : "withResponse")"
        )
    }

    private static let accessCodeKeyPrefix = "ble_access_code_"

    private func loadAccessCode() -> Data? {
        let key = Self.accessCodeKeyPrefix + deviceAddress
        return UserDefaults.standard.data(forKey: key)
    }

    private func saveAccessCode(_ data: Data) {
        let key = Self.accessCodeKeyPrefix + deviceAddress
        UserDefaults.standard.set(data, forKey: key)
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
            NativeLogger.d("BleIoStream", category: "BLE",
                "ioctl BLE_GET_NAME -> \(name)")
            return Int32(LIBDC_STATUS_SUCCESS)
        }

        if ioctlType == Self.bleIoctlType && ioctlNumber == Self.bleIoctlGetPinCodeNumber {
            guard let data, size > 0 else {
                return Int32(LIBDC_STATUS_INVALIDARGS)
            }

            NativeLogger.d("BleIoStream", category: "BLE",
                "ioctl BLE_GET_PINCODE -> requesting PIN from user")
            pendingPinCode = nil

            // Dispatch callback to main thread BEFORE blocking.
            let address = deviceAddress
            DispatchQueue.main.async { [weak self] in
                self?.onPinCodeRequired?(address)
            }

            // Block on semaphore until submitPinCode() is called.
            let result = pinSemaphore.wait(timeout: .now() + Self.pinTimeoutSeconds)
            if result == .timedOut {
                NativeLogger.w("BleIoStream", category: "BLE", "PIN entry timed out")
                return Int32(LIBDC_STATUS_TIMEOUT)
            }

            guard let pin = pendingPinCode, !pin.isEmpty else {
                NativeLogger.w("BleIoStream", category: "BLE", "PIN entry cancelled")
                return Int32(LIBDC_STATUS_CANCELLED)
            }

            guard let cString = pin.cString(using: .utf8), !cString.isEmpty else {
                return Int32(LIBDC_STATUS_IO)
            }

            let maxCount = Int(size)
            let copyCount = min(cString.count, maxCount)
            _ = cString.withUnsafeBytes { bytes in
                memcpy(data, bytes.baseAddress!, copyCount)
            }
            if copyCount == maxCount {
                data.assumingMemoryBound(to: CChar.self)[maxCount - 1] = 0
            }
            NativeLogger.d("BleIoStream", category: "BLE",
                "ioctl BLE_GET_PINCODE -> PIN provided (\(pin.count) chars)")
            return Int32(LIBDC_STATUS_SUCCESS)
        }

        if ioctlType == Self.bleIoctlType && ioctlNumber == Self.bleIoctlAccessCodeNumber {
            let direction = (request >> 30) & 0x3
            guard let data, size > 0 else {
                return Int32(LIBDC_STATUS_INVALIDARGS)
            }

            if direction == Self.ioctlDirRead {
                // GET access code
                guard let stored = loadAccessCode(), !stored.isEmpty else {
                    NativeLogger.d("BleIoStream", category: "BLE",
                        "ioctl BLE_GET_ACCESSCODE -> not found")
                    return Int32(LIBDC_STATUS_UNSUPPORTED)
                }
                let copyCount = min(stored.count, Int(size))
                _ = stored.withUnsafeBytes { bytes in
                    memcpy(data, bytes.baseAddress!, copyCount)
                }
                NativeLogger.d("BleIoStream", category: "BLE",
                    "ioctl BLE_GET_ACCESSCODE -> found (\(stored.count) bytes)")
                return Int32(LIBDC_STATUS_SUCCESS)
            }

            if direction == Self.ioctlDirWrite {
                // SET access code
                let accessData = Data(bytes: data, count: Int(size))
                saveAccessCode(accessData)
                NativeLogger.d("BleIoStream", category: "BLE",
                    "ioctl BLE_SET_ACCESSCODE -> stored (\(size) bytes)")
                return Int32(LIBDC_STATUS_SUCCESS)
            }
        }

        return Int32(LIBDC_STATUS_UNSUPPORTED)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            NativeLogger.e("BleIoStream", category: "BLE",
                "didDiscoverServices failed: \(error.localizedDescription)")
            signalDiscoveryReady()
            return
        }
        guard let services = peripheral.services else {
            NativeLogger.w("BleIoStream", category: "BLE",
                "didDiscoverServices returned nil services")
            signalDiscoveryReady()
            return
        }

        if services.isEmpty {
            NativeLogger.w("BleIoStream", category: "BLE", "No services discovered")
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
            NativeLogger.e("BleIoStream", category: "BLE",
                "didDiscoverCharacteristics failed for \(service.uuid.uuidString):"
                    + " \(error.localizedDescription)")
        } else if let characteristics = service.characteristics {
            NativeLogger.d("BleIoStream", category: "BLE",
                "Discovered \(characteristics.count) characteristics for \(service.uuid.uuidString)")
            for characteristic in characteristics {
                NativeLogger.d("BleIoStream", category: "BLE",
                    "  characteristic \(characteristic.uuid.uuidString)"
                        + " (\(Self.propertySummary(characteristic.properties)))")
            }
            discoveredServices.append((service: service, characteristics: characteristics))
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
            NativeLogger.e("BleIoStream", category: "BLE",
                "didUpdateValue error for \(characteristic.uuid.uuidString):"
                    + " \(error.localizedDescription)")
            return
        }
        if let notify = notifyCharacteristic, characteristic.uuid != notify.uuid {
            return
        }
        guard let value = characteristic.value else { return }
        hasSeenNotify = true
        consecutiveReadTimeouts = 0
        // Hand the payload to the consumer before logging. Under the OSTC
        // download fire-hose (hundreds of notifications/second) any work left on
        // this CoreBluetooth delegate queue delays draining the next
        // notification; if the queue falls behind, iOS drops notifications and
        // the download loses bytes (issue #394). append() is O(1) and the log
        // is dispatched off this queue by NativeLogger.
        packetBuffer.append(value)
        replenishCredits()
        NativeLogger.d("BleIoStream", category: "BLE",
            "notify \(characteristic.uuid.uuidString)"
                + " bytes=\(value.count)"
                + " data=\(Self.hexString(value, maxBytes: Self.maxLogBytes))")
    }

    func peripheral(_ peripheral: CBPeripheral,
                     didWriteValueFor characteristic: CBCharacteristic,
                     error: Error?) {
        if let error {
            NativeLogger.e("BleIoStream", category: "BLE",
                "didWriteValue error for \(characteristic.uuid.uuidString):"
                    + " \(error.localizedDescription)")
        } else {
            NativeLogger.d("BleIoStream", category: "BLE",
                "didWriteValue ok for \(characteristic.uuid.uuidString)")
        }

        // Credit grants share this callback with command writes but not their
        // semaphore: signalling writeSemaphore here would release a command
        // write that is still in flight and desynchronise the protocol.
        if let credits = creditsWriteCharacteristic,
            characteristic.uuid == credits.uuid {
            // A mid-transfer top-up has no waiter; settle it against the
            // policy here. Only now is the module known to hold the grant.
            if let grant = pendingTopUpGrant {
                pendingTopUpGrant = nil
                if error == nil {
                    creditPolicy.grantAccepted(grant)
                    NativeLogger.d("BleIoStream", category: "BLE",
                        "Terminal I/O: \(grant) credits acknowledged"
                            + " (balance=\(self.creditPolicy.credits))")
                } else {
                    // Leave the balance uncredited so the next packet retries.
                    creditPolicy.grantFailed()
                    NativeLogger.w("BleIoStream", category: "BLE",
                        "Terminal I/O: credit grant not acknowledged; will retry")
                }
                return
            }
            lastCreditWriteError = error
            creditSemaphore.signal()
            return
        }

        // Only the selected command characteristic drives writeSemaphore.
        // Matching positively rather than "anything that is not credits"
        // matters once the u-blox fallback has cleared the credit
        // characteristics: a late completion for a timed-out credit grant
        // would otherwise fall through here and wake a command write that is
        // still in flight, desynchronising the protocol.
        guard let dataCharacteristic = writeCharacteristic,
            characteristic.uuid == dataCharacteristic.uuid
        else {
            return
        }

        lastWriteError = error
        writeSemaphore.signal()
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        let expected: CBCharacteristic?
        switch notifySetupStep {
        case .idle: return
        case .creditsNotify: expected = creditsNotifyCharacteristic
        case .dataNotify: expected = notifyCharacteristic
        }
        guard let expected, characteristic.uuid == expected.uuid else { return }

        let step = notifySetupStep
        notifySetupStep = .idle

        let failure: String?
        if let error {
            failure = "failed enabling notify: \(error.localizedDescription)"
        } else if !characteristic.isNotifying {
            failure = "notify not active"
        } else {
            failure = nil
        }

        if let failure {
            // A failed credits subscription is survivable on u-blox, whose
            // flow control is optional; on Telit it is the end of the road.
            if step == .creditsNotify, !creditsRequired {
                // creditGrantFailed clears the credit characteristics; the
                // subscription never came up here, so it has nothing to undo.
                _ = creditGrantFailed(failure)
                subscribeToDataNotifications()
                return
            }
            NativeLogger.e("BleIoStream", category: "BLE",
                "\(failure) for \(characteristic.uuid.uuidString)")
            signalDiscoveryReady()
            return
        }

        NativeLogger.d("BleIoStream", category: "BLE",
            "Notify enabled for \(characteristic.uuid.uuidString)")

        if step == .creditsNotify {
            // Credits TX is live; Data TX comes next.
            subscribeToDataNotifications()
            return
        }
        isReady = true
        signalDiscoveryReady()
    }

    private func signalDiscoveryReady() {
        guard !discoverySignaled else { return }
        discoverySignaled = true
        discoverSemaphore.signal()
    }

    private func finalizeCharacteristicSelection() {
        let services = discoveredServices.map { entry in
            BleCharacteristicSelector.Service(
                uuid: entry.service.uuid,
                characteristics: entry.characteristics.map {
                    BleCharacteristicSelector.Characteristic(
                        uuid: $0.uuid, properties: $0.properties)
                }
            )
        }

        guard let selection = BleCharacteristicSelector.select(services: services) else {
            NativeLogger.w("BleIoStream", category: "BLE",
                "No suitable write/notify characteristic pair found")
            signalDiscoveryReady()
            return
        }

        // `services` is built from `discoveredServices` in the same order, so
        // the selection's indices address the exact live characteristics --
        // unambiguous even if the peripheral exposes duplicate service UUIDs.
        let entry = discoveredServices[selection.serviceIndex]
        let writeChar = entry.characteristics[selection.writeIndex]
        let notifyChar = entry.characteristics[selection.notifyIndex]

        writeCharacteristic = writeChar
        notifyCharacteristic = notifyChar
        if let credits = selection.terminalIoCredits {
            creditsWriteCharacteristic = entry.characteristics[credits.writeIndex]
            creditsNotifyCharacteristic = entry.characteristics[credits.notifyIndex]
            creditsRequired = credits.required
            NativeLogger.d("BleIoStream", category: "BLE",
                "Credit flow control detected"
                    + " (\(credits.required ? "Telit, required" : "u-blox, optional")):"
                    + " creditsRx=\(entry.characteristics[credits.writeIndex].uuid.uuidString)"
                    + " creditsTx=\(entry.characteristics[credits.notifyIndex].uuid.uuidString)")
        }
        writeWithoutResponsePreferred = initialWriteWithoutResponsePreference(for: writeChar)
        NativeLogger.d("BleIoStream", category: "BLE",
            "Selected write=\(writeChar.uuid.uuidString)"
                + " (\(Self.propertySummary(writeChar.properties)))"
                + " notify=\(notifyChar.uuid.uuidString)"
                + " (\(Self.propertySummary(notifyChar.properties)))"
                + " (score=\(selection.score))")
        let preferWithoutResponse = writeWithoutResponsePreferred
        NativeLogger.d("BleIoStream", category: "BLE",
            "Initial write mode preference:"
                + " \(preferWithoutResponse ? "withoutResponse" : "withResponse")")
        // Terminal I/O requires UART Credits TX to be subscribed before UART
        // Data TX (Telit TIO Implementation Guide r04 sections 6.4 and 6.2,
        // and the same order in Subsurface's qt-ble.cpp).
        if let creditsNotify = creditsNotifyCharacteristic, !creditsNotify.isNotifying {
            notifySetupStep = .creditsNotify
            peripheral.setNotifyValue(true, for: creditsNotify)
            return
        }
        subscribeToDataNotifications()
    }

    private func subscribeToDataNotifications() {
        guard let notifyChar = notifyCharacteristic else {
            signalDiscoveryReady()
            return
        }
        if notifyChar.isNotifying {
            isReady = true
            signalDiscoveryReady()
            return
        }
        notifySetupStep = .dataNotify
        peripheral.setNotifyValue(true, for: notifyChar)
    }
}

// MARK: - CBCentralManagerDelegate (connection callbacks)

extension BleIoStream: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NativeLogger.d("BleIoStream", category: "BLE",
            "central state updated: \(central.state.rawValue)")
    }

    func centralManager(_ central: CBCentralManager,
                         didConnect peripheral: CBPeripheral) {
        NativeLogger.d("BleIoStream", category: "BLE",
            "didConnect \(peripheral.identifier.uuidString)")
        connectError = nil
        connectSemaphore.signal()
    }

    func centralManager(_ central: CBCentralManager,
                         didFailToConnect peripheral: CBPeripheral,
                         error: Error?) {
        if let error {
            NativeLogger.e("BleIoStream", category: "BLE",
                "didFailToConnect \(peripheral.identifier.uuidString):"
                    + " \(error.localizedDescription)")
        } else {
            NativeLogger.w("BleIoStream", category: "BLE",
                "didFailToConnect \(peripheral.identifier.uuidString) (no error)")
        }
        connectError = error
        connectSemaphore.signal()
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        writeReadySemaphore.signal()
    }
}
