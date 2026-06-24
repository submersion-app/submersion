import Foundation

// Standalone tests for serialReadFully: the accumulating serial read that
// satisfies libdivecomputer's "exactly N bytes or timeout" contract
// (mirrors third_party/libdivecomputer/src/serial_posix.c dc_serial_read).
//
// Regression coverage for issue #334: macOS USB-serial drivers deliver data
// in ~64-byte USB bulk chunks, so a single poll()+read() returns only the
// first chunk of a multi-chunk packet (the 140-byte Mares Puck Pro version
// block). The earlier single-read implementation truncated the packet, which
// desynced libdivecomputer's framing and made every probe fail with rc=-8.
//
// A socketpair stands in for the serial fd: poll()/read() behave the same on
// both, and writing in delayed chunks reproduces the USB chunking exactly,
// without needing a physical dive computer.
//
// Assertions use precondition() (not assert(), which the optimizer can elide)
// so a failure aborts the run even if these are ever built with -O.

private func makeSocketPair() -> (Int32, Int32) {
    var fds: [Int32] = [0, 0]
    let rc = socketpair(AF_UNIX, SOCK_STREAM, 0, &fds)
    precondition(rc == 0, "socketpair failed: \(errno)")
    return (fds[0], fds[1])
}

private func distinctivePattern(_ count: Int) -> [UInt8] {
    // A non-zero, position-dependent pattern: catches truncation, zero-fill,
    // and byte-offset bugs that an all-zero buffer would hide.
    var bytes = [UInt8](repeating: 0, count: count)
    for i in 0..<count { bytes[i] = UInt8((i &* 7 &+ 3) & 0xFF) }
    return bytes
}

// Write every byte or fail the test: a short/failed write would otherwise make
// a test pass or fail for the wrong reason.
private func writeChecked(_ fd: Int32, _ bytes: [UInt8]) {
    let n = bytes.withUnsafeBytes { write(fd, $0.baseAddress, bytes.count) }
    precondition(n == bytes.count, "test setup: short/failed write \(n)/\(bytes.count)")
}

// A 140-byte packet arriving as 63 + 77 bytes (the observed Mares split) must
// be fully accumulated, not truncated to the first USB chunk.
private func test_accumulates_across_usb_chunks() {
    let (readFd, writeFd) = makeSocketPair()
    defer { close(readFd); close(writeFd) }

    let total = 140
    let firstChunk = 63
    let expected = distinctivePattern(total)

    let writer = Thread {
        writeChecked(writeFd, Array(expected[0..<firstChunk]))
        // Force the reader to make at least two iterations: the second chunk
        // is not yet on the wire when the first read() returns.
        Thread.sleep(forTimeInterval: 0.05)
        writeChecked(writeFd, Array(expected[firstChunk..<total]))
    }
    writer.start()

    var buf = [UInt8](repeating: 0xFF, count: total)
    let outcome = buf.withUnsafeMutableBytes { p in
        serialReadFully(fd: readFd, into: p.baseAddress!, size: total, timeoutMs: 3000)
    }

    precondition(outcome.status == .success,
                 "expected .success, got \(outcome.status)")
    precondition(outcome.bytesRead == total,
                 "expected \(total) bytes, got \(outcome.bytesRead)")
    precondition(buf == expected, "buffer content mismatch (truncation or zero-fill)")
    print("PASS: accumulates a 140-byte packet split across USB-sized chunks")
}

// When fewer than `size` bytes ever arrive (the line stays open, nothing more
// comes), the read must report .timeout with the partial count -- NOT .success.
// libdivecomputer's drivers retry on timeout; a short *success* (the original
// #334 bug) makes them mis-frame the packet instead of retrying.
private func test_short_read_reports_timeout_not_success() {
    let (readFd, writeFd) = makeSocketPair()
    defer { close(readFd); close(writeFd) }

    let sent = 50
    let payload = distinctivePattern(sent)
    writeChecked(writeFd, payload)
    // No further writes and the port stays open: the requested 140 never
    // completes, so the read must time out rather than see EOF.

    var buf = [UInt8](repeating: 0xFF, count: 140)
    let outcome = buf.withUnsafeMutableBytes { p in
        serialReadFully(fd: readFd, into: p.baseAddress!, size: 140, timeoutMs: 150)
    }

    precondition(outcome.status == .timeout,
                 "short read must be .timeout, got \(outcome.status)")
    precondition(outcome.bytesRead == sent,
                 "expected partial count \(sent), got \(outcome.bytesRead)")
    precondition(Array(buf[0..<sent]) == payload, "partial bytes corrupted")
    print("PASS: short read reports .timeout with the partial byte count")
}

// EOF (the port closes mid-packet, e.g. the device is unplugged) must surface
// as .io, not .timeout, so the caller fails fast instead of burning retries on
// a dead fd. poll() wakes on POLLHUP and the following read() returns 0.
private func test_eof_reports_io() {
    let (readFd, writeFd) = makeSocketPair()
    defer { close(readFd) }

    let sent = 40
    let payload = distinctivePattern(sent)
    writeChecked(writeFd, payload)
    close(writeFd)  // signal EOF once the 40 buffered bytes are drained

    var buf = [UInt8](repeating: 0xFF, count: 140)
    let outcome = buf.withUnsafeMutableBytes { p in
        serialReadFully(fd: readFd, into: p.baseAddress!, size: 140, timeoutMs: 3000)
    }

    precondition(outcome.status == .io, "EOF must be .io, got \(outcome.status)")
    precondition(outcome.bytesRead == sent,
                 "expected \(sent) drained bytes, got \(outcome.bytesRead)")
    print("PASS: EOF (port closed mid-packet) reports .io")
}

// The common case: the whole packet is already buffered, so a single iteration
// satisfies the request.
private func test_reads_when_all_bytes_already_available() {
    let (readFd, writeFd) = makeSocketPair()
    defer { close(readFd); close(writeFd) }

    let total = 64
    let expected = distinctivePattern(total)
    writeChecked(writeFd, expected)

    var buf = [UInt8](repeating: 0, count: total)
    let outcome = buf.withUnsafeMutableBytes { p in
        serialReadFully(fd: readFd, into: p.baseAddress!, size: total, timeoutMs: 3000)
    }

    precondition(outcome.status == .success, "expected .success, got \(outcome.status)")
    precondition(outcome.bytesRead == total, "expected \(total), got \(outcome.bytesRead)")
    precondition(buf == expected, "buffer content mismatch")
    print("PASS: reads a fully-buffered packet in one pass")
}

test_accumulates_across_usb_chunks()
test_short_read_reports_timeout_not_success()
test_eof_reports_io()
test_reads_when_all_bytes_already_available()
print("All SerialReadLoop tests passed.")
