import Foundation

/// How a read finished, mapped onto a libdivecomputer status by the caller.
enum FtdiReadStatus: Equatable {
    case success
    case timeout
    case io
}

/// Outcome of a read. `bytesRead` is reported even on timeout or error, which
/// matches libdivecomputer's own serial backend (`*actual = nbytes`).
struct FtdiReadOutcome: Equatable {
    let status: FtdiReadStatus
    let bytesRead: Int
}

/// Result of one bulk-IN transfer.
///
/// `idle` and `failure` are kept apart on purpose: libdivecomputer retries a
/// timeout but treats an I/O error as fatal, so an unplugged cable must not be
/// reported as a merely slow device.
enum FtdiPacketResult {
    /// Raw transfer bytes, status header included.
    case packet([UInt8])
    /// Nothing arrived before the transfer's own deadline.
    case idle
    /// The transfer failed at the USB layer.
    case failure
}

/// Accumulates exactly the requested number of payload bytes from FTDI bulk-IN
/// transfers, buffering any surplus for the next call.
///
/// libdivecomputer's read contract, which every driver relies on, is "return
/// exactly `size` bytes or `DC_STATUS_TIMEOUT`" and never a short success. Two
/// separate things make that non-trivial here:
///
/// 1. USB delivers one bulk packet at a time, so a large device response
///    arrives across several transfers. Returning the first one truncates the
///    packet and desyncs the driver's framing, which is what made issue #334
///    fail with "Unexpected packet trailer byte".
/// 2. Each FTDI packet is prefixed with two modem-status bytes that are not
///    payload, so the byte counts at the USB layer and at the driver layer
///    differ, and surplus payload can straddle a packet boundary.
///
/// Reads are always issued one whole packet at a time. Asking for a partial
/// packet risks an overflow condition on the host controller, which is the
/// same constraint the Android side hit in issue #318.
final class FtdiReadAccumulator {
    private let packetSize: Int
    private var pending: [UInt8] = []

    /// - Parameter packetSize: the bulk-IN endpoint's maximum packet size,
    ///   read from the endpoint descriptor (64 on full-speed FTDI parts).
    init(packetSize: Int) {
        self.packetSize = packetSize
    }

    /// Payload bytes buffered from a previous read.
    var pendingCount: Int { pending.count }

    /// Drops buffered payload. Backs the `purge` callback: after libdivecomputer
    /// purges the input direction, bytes received before the purge must not
    /// surface in a later read.
    func discardPending() {
        pending.removeAll(keepingCapacity: true)
    }

    /// Reads exactly `size` payload bytes into `buffer`.
    ///
    /// `timeoutMs` follows libdivecomputer semantics: negative blocks
    /// indefinitely, zero polls without blocking, positive bounds the total
    /// wait across every transfer this call makes.
    ///
    /// - Parameter readPacket: issues one bulk-IN transfer, given the
    ///   milliseconds remaining before the deadline.
    func read(
        into buffer: UnsafeMutableRawPointer, size: Int, timeoutMs: Int32,
        readPacket: (Int32) -> FtdiPacketResult
    ) -> FtdiReadOutcome {
        guard size > 0 else { return FtdiReadOutcome(status: .success, bytesRead: 0) }

        // Absolute monotonic deadline, computed once, so the total wait is
        // bounded no matter how many transfers it takes.
        var deadlineNanos: UInt64 = 0
        var deadlineInitialized = false

        // The loop is labelled because the exits live inside a switch, where a
        // bare `break` would leave the switch and keep looping forever.
        readLoop: while pending.count < size {
            let remainingMs: Int32
            if timeoutMs > 0 {
                let now = DispatchTime.now().uptimeNanoseconds
                if !deadlineInitialized {
                    deadlineNanos = now &+ UInt64(timeoutMs) &* 1_000_000
                    deadlineInitialized = true
                    remainingMs = timeoutMs
                } else if now < deadlineNanos {
                    // Round up to the next millisecond so a transfer is never
                    // issued with a zero deadline while time genuinely remains.
                    let remainingNanos = deadlineNanos - now
                    let millis = (remainingNanos + 999_999) / 1_000_000
                    remainingMs = millis > UInt64(Int32.max) ? Int32.max : Int32(millis)
                } else {
                    remainingMs = 0
                }
                if remainingMs == 0 { break readLoop }
            } else if timeoutMs == 0 {
                remainingMs = 0
            } else {
                remainingMs = -1
            }

            switch readPacket(remainingMs) {
            case .failure:
                let delivered = min(pending.count, size)
                copyOut(to: buffer, count: delivered)
                return FtdiReadOutcome(status: .io, bytesRead: delivered)
            case .idle:
                // Nothing arrived within this transfer's own deadline. With a
                // non-blocking budget there is nothing left to wait for;
                // otherwise loop and let the deadline decide.
                if timeoutMs == 0 { break readLoop }
            case .packet(let raw):
                // A packet carrying only the status header is the chip's
                // keep-alive. It contributes no payload but is not
                // end-of-stream, so keep waiting rather than giving up.
                pending.append(
                    contentsOf: FtdiProtocol.stripStatusBytes(
                        from: raw[...], packetSize: packetSize))
            }
        }

        if pending.count >= size {
            copyOut(to: buffer, count: size)
            return FtdiReadOutcome(status: .success, bytesRead: size)
        }

        // Short read: reported as a timeout, never as a partial success, because
        // libdivecomputer's contract has no partial success and a driver that
        // received one would read a mid-packet byte as a framing trailer. What
        // did arrive is still written out and counted, matching serial_posix.c,
        // which sets *actual even when it returns DC_STATUS_TIMEOUT.
        let delivered = pending.count
        copyOut(to: buffer, count: delivered)
        return FtdiReadOutcome(status: .timeout, bytesRead: delivered)
    }

    /// Moves `count` bytes out of the buffer and into `destination`.
    private func copyOut(to destination: UnsafeMutableRawPointer, count: Int) {
        guard count > 0 else { return }
        pending.withUnsafeBytes { source in
            destination.copyMemory(from: source.baseAddress!, byteCount: count)
        }
        pending.removeFirst(count)
    }
}
