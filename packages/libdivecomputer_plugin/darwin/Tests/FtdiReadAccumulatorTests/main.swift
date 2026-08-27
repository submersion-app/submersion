import Foundation

// Standalone tests for FtdiReadAccumulator, which satisfies libdivecomputer's
// "return exactly N bytes or time out" read contract on top of FTDI bulk-IN
// transfers (issue #732).
//
// This is the same contract serialReadFully enforces for POSIX serial fds.
// Every libdivecomputer driver relies on it: a short success makes the driver
// read a mid-packet byte as a framing trailer, which is precisely how issue
// #334 failed. Here the problem is worse than plain chunking, because each
// bulk packet also carries two modem-status bytes that are not payload.
//
// A scripted packet source stands in for the USB pipe, so no hardware is
// needed. Assertions use precondition() so they survive -O.

private func check(_ condition: Bool, _ message: String) {
    precondition(condition, message)
}

private let packetSize = 8
private let statusHeader: [UInt8] = [0x01, 0x60]

/// Wraps `payload` in as many status-prefixed packets as it needs.
private func packetize(_ payload: [UInt8]) -> [[UInt8]] {
    let bodySize = packetSize - statusHeader.count
    if payload.isEmpty { return [statusHeader] }
    return stride(from: 0, to: payload.count, by: bodySize).map { start in
        statusHeader + Array(payload[start..<min(start + bodySize, payload.count)])
    }
}

/// A non-zero, position-dependent pattern: catches truncation, zero-fill and
/// byte-offset bugs that an all-zero buffer would hide.
private func distinctivePattern(_ count: Int) -> [UInt8] {
    (0..<count).map { UInt8(($0 &* 7 &+ 3) & 0xFF) }
}

/// Hands out scripted packets one call at a time, then reports idle.
private final class ScriptedSource {
    private var queue: [FtdiPacketResult]
    private(set) var callCount = 0

    init(_ queue: [FtdiPacketResult]) { self.queue = queue }

    func next(_ deadlineMs: Int32) -> FtdiPacketResult {
        callCount += 1
        return queue.isEmpty ? .idle : queue.removeFirst()
    }
}

private func readIntoArray(
    _ accumulator: FtdiReadAccumulator, size: Int, timeoutMs: Int32,
    source: ScriptedSource
) -> (FtdiReadOutcome, [UInt8]) {
    var buffer = [UInt8](repeating: 0, count: size)
    let outcome = buffer.withUnsafeMutableBytes { raw in
        accumulator.read(
            into: raw.baseAddress!, size: size, timeoutMs: timeoutMs,
            readPacket: source.next)
    }
    return (outcome, buffer)
}

// A response spanning several packets must be reassembled into one exact read.
// This is the 140-byte-version-block shape from issue #334.
do {
    let payload = distinctivePattern(20)
    let source = ScriptedSource(packetize(payload).map { .packet($0) })
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    let (outcome, buffer) = readIntoArray(
        accumulator, size: 20, timeoutMs: 1000, source: source)

    check(outcome.status == .success, "a complete multi-packet response succeeds")
    check(outcome.bytesRead == 20, "bytesRead is \(outcome.bytesRead), expected 20")
    check(buffer == payload, "payload was reassembled with status bytes removed")
    check(accumulator.pendingCount == 0, "nothing is left over")
}

// Payload beyond the requested size is kept for the next call rather than
// discarded. Dropping it would lose the head of the next device response.
do {
    let payload = distinctivePattern(12)
    let source = ScriptedSource(packetize(payload).map { .packet($0) })
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)

    let (first, firstBuffer) = readIntoArray(
        accumulator, size: 4, timeoutMs: 1000, source: source)
    check(first.status == .success, "the first short read succeeds")
    check(firstBuffer == Array(payload[0..<4]), "the first read gets the first bytes")
    check(accumulator.pendingCount == 2,
        "surplus from the first packet is retained, got \(accumulator.pendingCount)")

    let callsAfterFirst = source.callCount
    let (second, secondBuffer) = readIntoArray(
        accumulator, size: 2, timeoutMs: 1000, source: source)
    check(second.status == .success, "the second read succeeds")
    check(secondBuffer == Array(payload[4..<6]), "the second read continues the stream")
    check(source.callCount == callsAfterFirst,
        "a read served entirely from the buffer issues no USB transfer")
}

// A response that never completes must report timeout, not a short success.
do {
    let source = ScriptedSource(packetize(distinctivePattern(3)).map { .packet($0) })
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    let (outcome, _) = readIntoArray(
        accumulator, size: 10, timeoutMs: 50, source: source)

    check(outcome.status == .timeout, "an incomplete response times out")
    check(outcome.bytesRead == 3,
        "partial byte count is still reported, got \(outcome.bytesRead)")
}

// Bare keep-alive packets carry no payload and must not be mistaken for data
// or for end-of-stream. They arrive once per latency-timer period whenever the
// device is quiet.
do {
    let payload = distinctivePattern(3)
    var script: [FtdiPacketResult] = [.packet(statusHeader), .packet(statusHeader)]
    script.append(contentsOf: packetize(payload).map { .packet($0) })
    let source = ScriptedSource(script)
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    let (outcome, buffer) = readIntoArray(
        accumulator, size: 3, timeoutMs: 1000, source: source)

    check(outcome.status == .success, "keep-alives are skipped and the read completes")
    check(buffer == payload, "payload survives the keep-alives")
}

// A hard transport error is distinct from a timeout: libdivecomputer retries a
// timeout but not an I/O failure, so an unplugged cable must not look like a
// slow device.
do {
    let source = ScriptedSource([.failure])
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    let (outcome, _) = readIntoArray(
        accumulator, size: 4, timeoutMs: 1000, source: source)

    check(outcome.status == .io, "a transport failure reports io, not timeout")
}

// A zero-length read is a no-op that must not issue a transfer.
do {
    let source = ScriptedSource([])
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    var scratch: UInt8 = 0
    let outcome = withUnsafeMutableBytes(of: &scratch) { raw in
        accumulator.read(
            into: raw.baseAddress!, size: 0, timeoutMs: 1000,
            readPacket: source.next)
    }
    check(outcome.status == .success, "a zero-length read succeeds")
    check(outcome.bytesRead == 0, "a zero-length read transfers nothing")
    check(source.callCount == 0, "a zero-length read issues no USB transfer")
}

// discardPending backs the purge callback: after it, buffered payload from
// before the purge must not surface in a later read.
do {
    let source = ScriptedSource(packetize(distinctivePattern(6)).map { .packet($0) })
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    _ = readIntoArray(accumulator, size: 2, timeoutMs: 1000, source: source)
    check(accumulator.pendingCount > 0, "test setup: there should be surplus to discard")

    accumulator.discardPending()
    check(accumulator.pendingCount == 0, "discardPending clears the buffer")
}

print("FtdiReadAccumulatorTests: all assertions passed")
