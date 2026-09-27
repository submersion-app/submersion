import Foundation

/// One GATT characteristic read in flight (issue #422).
///
/// CoreBluetooth delivers a read reply through the same
/// `peripheral(_:didUpdateValueFor:error:)` callback as a notification, with
/// nothing to tell the two apart. While a read is pending, the first update
/// for its characteristic is the reply and must not reach the download's
/// packet buffer; every other update flows to it as before.
///
/// `begin`, `wait` and `cancel` run on the libdivecomputer thread; `complete`
/// runs on the CoreBluetooth delegate queue, which must never block (#394).
final class PendingCharacteristicRead {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var pendingUUID: String?
    private var value: Data?
    /// Characteristics whose read timed out. CoreBluetooth cannot cancel an
    /// outstanding readValue, so its late reply could otherwise satisfy a
    /// later read of the same characteristic; those are refused instead.
    private var quarantined: Set<String> = []

    /// Starts a read. Returns false when the characteristic is quarantined.
    @discardableResult
    func begin(uuid: String) -> Bool {
        while semaphore.wait(timeout: .now()) == .success {}
        lock.lock()
        defer { lock.unlock() }
        let key = uuid.uppercased()
        if quarantined.contains(key) { return false }
        pendingUUID = key
        value = nil
        return true
    }

    /// Returns true when the update was this read's reply (consumed).
    func complete(uuid: String, value: Data?) -> Bool {
        lock.lock()
        guard let pending = pendingUUID, pending == uuid.uppercased() else {
            lock.unlock()
            return false
        }
        pendingUUID = nil
        self.value = value
        lock.unlock()
        semaphore.signal()
        return true
    }

    func wait(timeout: DispatchTime) -> Data? {
        let result = semaphore.wait(timeout: timeout)
        lock.lock()
        defer { lock.unlock() }
        if result != .success, let pending = pendingUUID {
            quarantined.insert(pending)
        }
        pendingUUID = nil
        return result == .success ? value : nil
    }

    /// Wakes a waiter with no value (disconnect).
    func cancel() {
        lock.lock()
        let wasPending = pendingUUID != nil
        pendingUUID = nil
        value = nil
        lock.unlock()
        if wasPending { semaphore.signal() }
    }
}
