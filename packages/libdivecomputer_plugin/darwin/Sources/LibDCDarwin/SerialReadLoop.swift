import Foundation

/// Outcome of a serial read: the libdivecomputer status it maps to plus the
/// number of bytes actually transferred (reported even on timeout/error, like
/// serial_posix.c's `*actual = nbytes`).
enum SerialReadStatus: Equatable {
    case success
    case timeout
    case io
}

struct SerialReadOutcome: Equatable {
    let status: SerialReadStatus
    let bytesRead: Int
}

/// Blocking read that accumulates exactly `size` bytes from a POSIX serial fd,
/// re-polling on the remaining timeout between chunks.
///
/// This mirrors libdivecomputer's own serial backend
/// (third_party/libdivecomputer/src/serial_posix.c `dc_serial_read`), whose
/// contract every libdivecomputer driver relies on: a read of N bytes returns
/// exactly N bytes or `DC_STATUS_TIMEOUT` — never a short success.
///
/// macOS/iOS USB-serial drivers (FTDI, CP210x, CH34x, ...) hand data to
/// userspace one ~64-byte USB bulk packet at a time, so a single `read()`
/// returns only the first chunk of a larger device response. The Mares Puck
/// Pro (ICONHD family) answers the version command with a 140-byte block; a
/// single read returned ~63 bytes, libdivecomputer then read a mid-packet byte
/// as the framing trailer (`Unexpected packet trailer byte`), and every probe
/// failed with rc=-8 ("No dive computer found"). Looping here until the whole
/// packet arrives is what makes the same driver that works in Subsurface work
/// here (issue #334).
///
/// `timeoutMs` follows libdivecomputer semantics: negative blocks indefinitely,
/// zero polls without blocking, positive bounds the *total* wait across all
/// iterations.
func serialReadFully(
    fd: Int32, into buffer: UnsafeMutableRawPointer, size: Int, timeoutMs: Int32
) -> SerialReadOutcome {
    var received = 0

    // Absolute monotonic deadline, computed once on the first iteration when a
    // finite positive timeout is in effect (matches serial_posix.c's `target`).
    var deadlineNanos: UInt64 = 0
    var deadlineInitialized = false

    while received < size {
        // Per-iteration poll timeout in milliseconds.
        let pollTimeout: Int32
        if timeoutMs > 0 {
            let now = DispatchTime.now().uptimeNanoseconds
            if !deadlineInitialized {
                deadlineNanos = now &+ UInt64(timeoutMs) &* 1_000_000
                deadlineInitialized = true
                pollTimeout = timeoutMs
            } else if now < deadlineNanos {
                // Round the remaining time up to the next millisecond so we
                // never poll with 0 while time genuinely remains.
                let remainingNanos = deadlineNanos - now
                let remainingMs = (remainingNanos + 999_999) / 1_000_000
                pollTimeout = remainingMs > UInt64(Int32.max)
                    ? Int32.max : Int32(remainingMs)
            } else {
                pollTimeout = 0
            }
        } else if timeoutMs == 0 {
            pollTimeout = 0
        } else {
            pollTimeout = -1  // Block indefinitely.
        }

        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let ready = poll(&pfd, 1, pollTimeout)
        if ready < 0 {
            if errno == EINTR { continue }
            return SerialReadOutcome(status: .io, bytesRead: received)
        }
        if ready == 0 {
            break  // Genuine timeout: no data arrived within the deadline.
        }

        // poll() also wakes on error/hangup, not just readable data. POLLERR or
        // POLLNVAL (invalid fd) is a hard failure: surface it as .io so the
        // caller fails fast instead of mis-reading it as a timeout. POLLHUP can
        // accompany still-buffered data, so fall through and let read() drain
        // it; an empty read (0) below is then the real end of stream.
        if (pfd.revents & (Int16(POLLERR) | Int16(POLLNVAL))) != 0 {
            return SerialReadOutcome(status: .io, bytesRead: received)
        }

        let n = read(fd, buffer.advanced(by: received), size - received)
        if n < 0 {
            if errno == EINTR || errno == EAGAIN { continue }
            return SerialReadOutcome(status: .io, bytesRead: received)
        }
        if n == 0 {
            // EOF: the port closed mid-packet (e.g. the device was unplugged).
            // That is an I/O failure, not a timeout -- don't burn driver
            // retries on a dead fd.
            return SerialReadOutcome(status: .io, bytesRead: received)
        }
        received += n
    }

    return SerialReadOutcome(
        status: received == size ? .success : .timeout, bytesRead: received)
}
