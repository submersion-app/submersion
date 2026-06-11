import Foundation

/// FIFO of BLE notification payloads that preserves packet boundaries.
///
/// libdivecomputer's BLE protocol parsers (pelagic_i330r, shearwater, ...)
/// expect each dc_iostream_read() to return bytes from at most one GATT
/// notification: they size the packet from its header and discard any extra
/// bytes in the same read. If two notifications are coalesced into one read
/// (e.g. the i330R's trailing FLAG_LAST ack arriving in the same dispatch
/// window as the last data packet), the trailing packet is silently lost and
/// the parser times out waiting for it.
///
/// Threading contract: append() may be called from any thread (the
/// CoreBluetooth delegate queue); read(), poll(), and purge() are expected
/// from a single consumer thread (libdivecomputer's download thread).
final class PacketReadBuffer {
    private let lock = NSLock()
    private var chunks: [Data] = []
    private let semaphore = DispatchSemaphore(value: 0)

    /// Append one notification payload. Empty payloads are ignored because a
    /// zero-byte read is treated as a protocol error by the parsers.
    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        chunks.append(data)
        lock.unlock()
        semaphore.signal()
    }

    /// True if any notification data is buffered.
    var hasData: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !chunks.isEmpty
    }

    /// Copy up to `maxBytes` from the oldest notification into `dest`,
    /// blocking until data arrives or `deadline` passes. A partially
    /// consumed notification stays at the head of the queue, so bytes from
    /// two notifications are never returned by a single call.
    /// Returns the number of bytes copied, or nil on timeout.
    func read(into dest: UnsafeMutableRawPointer, maxBytes: Int,
              deadline: DispatchTime) -> Int? {
        while true {
            lock.lock()
            if let chunk = chunks.first {
                let count = min(maxBytes, chunk.count)
                chunk.withUnsafeBytes { ptr in
                    _ = memcpy(dest, ptr.baseAddress!, count)
                }
                if count < chunk.count {
                    chunks[0] = chunk.subdata(in: count..<chunk.count)
                } else {
                    chunks.removeFirst()
                }
                lock.unlock()
                return count
            }
            lock.unlock()

            // Stale signals (from chunks consumed without waiting) cause a
            // spurious wakeup here; the loop re-checks against the absolute
            // deadline, so they cannot extend the timeout.
            if semaphore.wait(timeout: deadline) == .timedOut {
                return nil
            }
        }
    }

    /// Block until data is available or `deadline` passes, without
    /// consuming anything. Returns true if data is available.
    func poll(deadline: DispatchTime) -> Bool {
        while !hasData {
            // A consumed signal may be stale (its chunk was already read);
            // loop to re-check rather than report a false positive.
            if semaphore.wait(timeout: deadline) == .timedOut {
                return false
            }
        }
        return true
    }

    /// Drop all buffered notifications and pending wakeup signals.
    func purge() {
        lock.lock()
        chunks.removeAll(keepingCapacity: true)
        lock.unlock()
        while semaphore.wait(timeout: .now()) == .success {
            // Drain stale signals so they don't wake a future read.
        }
    }
}
