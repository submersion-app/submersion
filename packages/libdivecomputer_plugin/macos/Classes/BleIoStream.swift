import CoreBluetooth
import Foundation

/// Bridges CoreBluetooth BLE communication to libdivecomputer's synchronous
/// iostream interface using semaphores.
///
/// libdivecomputer calls read/write synchronously on a background thread.
/// This class translates those calls to async CoreBluetooth operations,
/// blocking with semaphores until the BLE operation completes.
class BleIoStream: NSObject, CBPeripheralDelegate {
    let peripheral: CBPeripheral
    private let centralManager: CBCentralManager

    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    private let readLock = NSLock()
    private var readBuffer = Data()
    private let readSemaphore = DispatchSemaphore(value: 0)
    private let writeSemaphore = DispatchSemaphore(value: 0)
    private let connectSemaphore = DispatchSemaphore(value: 0)
    private let discoverSemaphore = DispatchSemaphore(value: 0)

    private var timeoutMs: Int = 10000
    private var connectError: Error?
    private var isReady = false

    init(peripheral: CBPeripheral, centralManager: CBCentralManager) {
        self.peripheral = peripheral
        self.centralManager = centralManager
        super.init()
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
        cbs.sleep = nil
        cbs.userdata = opaque
        return cbs
    }

    // MARK: - Connection

    /// Connect to the peripheral and discover services/characteristics.
    /// Blocks until ready or timeout. Returns true on success.
    func connectAndDiscover() -> Bool {
        centralManager.connect(peripheral, options: nil)
        let result = connectSemaphore.wait(timeout: .now() + .seconds(15))
        if result == .timedOut || connectError != nil {
            return false
        }

        peripheral.discoverServices(nil)
        let discoverResult = discoverSemaphore.wait(timeout: .now() + .seconds(10))
        return discoverResult == .success && isReady
    }

    // MARK: - C Callback Implementations

    private static let cSetTimeout: libdc_io_set_timeout_fn = { userdata, timeout in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        stream.timeoutMs = timeout < 0 ? Int.max : Int(timeout)
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private static let cRead: libdc_io_read_fn = { userdata, data, size, actual in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        return stream.performRead(data: data!, size: size, actual: actual!)
    }

    private static let cWrite: libdc_io_write_fn = { userdata, data, size, actual in
        let stream = Unmanaged<BleIoStream>.fromOpaque(userdata!).takeUnretainedValue()
        return stream.performWrite(data: data!, size: size, actual: actual!)
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
        var totalRead: size_t = 0
        while totalRead < size {
            readLock.lock()
            let available = readBuffer.count
            readLock.unlock()

            if available > 0 {
                readLock.lock()
                let bytesToRead = min(size - totalRead, readBuffer.count)
                readBuffer.withUnsafeBytes { ptr in
                    memcpy(data.advanced(by: totalRead), ptr.baseAddress!, bytesToRead)
                }
                readBuffer.removeFirst(bytesToRead)
                readLock.unlock()
                totalRead += bytesToRead
            } else {
                let deadline: DispatchTime = timeoutMs == Int.max ? .distantFuture :
                    .now() + .milliseconds(timeoutMs)
                let result = readSemaphore.wait(timeout: deadline)
                if result == .timedOut {
                    actual.pointee = totalRead
                    return totalRead > 0 ? Int32(LIBDC_STATUS_SUCCESS) :
                                           Int32(LIBDC_STATUS_TIMEOUT)
                }
            }
        }
        actual.pointee = totalRead
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func performWrite(data: UnsafeRawPointer, size: size_t,
                               actual: UnsafeMutablePointer<size_t>) -> Int32 {
        guard let characteristic = writeCharacteristic else {
            return Int32(LIBDC_STATUS_IO)
        }

        let writeData = Data(bytes: data, count: size)
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ?
            .withoutResponse : .withResponse

        peripheral.writeValue(writeData, for: characteristic, type: writeType)

        if writeType == .withResponse {
            let result = writeSemaphore.wait(
                timeout: .now() + .milliseconds(timeoutMs)
            )
            if result == .timedOut {
                return Int32(LIBDC_STATUS_TIMEOUT)
            }
        }

        actual.pointee = size
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func performIoctl(request: UInt32, data: UnsafeMutableRawPointer?,
                               size: size_t) -> Int32 {
        // Handle BLE-specific ioctls (name query, characteristic read/write).
        // For now, return unsupported for operations we don't handle.
        return Int32(LIBDC_STATUS_UNSUPPORTED)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            discoverSemaphore.signal()
            return
        }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                     didDiscoverCharacteristicsFor service: CBService,
                     error: Error?) {
        guard error == nil, let characteristics = service.characteristics else {
            return
        }

        for char in characteristics {
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                notifyCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            }
            if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                writeCharacteristic = char
            }
        }

        if writeCharacteristic != nil && notifyCharacteristic != nil {
            isReady = true
            discoverSemaphore.signal()
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                     didUpdateValueFor characteristic: CBCharacteristic,
                     error: Error?) {
        guard error == nil, let value = characteristic.value else { return }
        readLock.lock()
        readBuffer.append(value)
        readLock.unlock()
        readSemaphore.signal()
    }

    func peripheral(_ peripheral: CBPeripheral,
                     didWriteValueFor characteristic: CBCharacteristic,
                     error: Error?) {
        writeSemaphore.signal()
    }
}

// MARK: - CBCentralManagerDelegate (connection callbacks)

extension BleIoStream: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // No-op: state managed by BleScanner's centralManager
    }

    func centralManager(_ central: CBCentralManager,
                         didConnect peripheral: CBPeripheral) {
        connectError = nil
        connectSemaphore.signal()
    }

    func centralManager(_ central: CBCentralManager,
                         didFailToConnect peripheral: CBPeripheral,
                         error: Error?) {
        connectError = error
        connectSemaphore.signal()
    }
}
