import Foundation

// Standalone test runner for PacketReadBuffer (no XCTest: the LibDCDarwin
// package cannot build under SwiftPM because it depends on Flutter modules
// only present in the CocoaPods build). Run via darwin/run_native_tests.sh.

var failures = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message) (main.swift:\(line))")
        failures += 1
    }
}

func readBytes(_ buffer: PacketReadBuffer, max: Int, timeoutMs: Int) -> [UInt8]? {
    var dest = [UInt8](repeating: 0, count: max)
    let deadline = DispatchTime.now() + .milliseconds(timeoutMs)
    let count: Int? = dest.withUnsafeMutableBytes { ptr in
        buffer.read(into: ptr.baseAddress!, maxBytes: max, deadline: deadline)
    }
    guard let count else { return nil }
    return Array(dest[0..<count])
}

// 1. The i330R bug: a 69-byte last-data packet and the 6-byte FLAG_LAST ack
// arrive as separate notifications in the same dispatch window. Each read
// must return bytes from at most one notification, never both coalesced.
do {
    let buffer = PacketReadBuffer()
    var lastData = Data([0xCD, 0x80, 0x0D, 0xD6, 0x40])
    lastData.append(Data(repeating: 0xAA, count: 64))
    let flagLast = Data([0xCD, 0xC0, 0x0D, 0x88, 0x01, 0x02])
    buffer.append(lastData)
    buffer.append(flagLast)

    let first = readBytes(buffer, max: 260, timeoutMs: 100)
    expect(first?.count == 69,
           "coalesced: first read returns only the 69-byte packet, got \(String(describing: first?.count))")
    let second = readBytes(buffer, max: 260, timeoutMs: 100)
    expect(second?.count == 6,
           "coalesced: second read returns the 6-byte FLAG_LAST ack, got \(String(describing: second?.count))")
    expect(second == [0xCD, 0xC0, 0x0D, 0x88, 0x01, 0x02],
           "coalesced: FLAG_LAST ack bytes intact")
}

// 2. Partial consumption: a small read drains the head chunk across calls
// before the next chunk becomes visible.
do {
    let buffer = PacketReadBuffer()
    buffer.append(Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))
    buffer.append(Data([99, 98]))

    expect(readBytes(buffer, max: 4, timeoutMs: 100) == [1, 2, 3, 4],
           "partial: first 4 bytes of head chunk")
    expect(readBytes(buffer, max: 260, timeoutMs: 100) == [5, 6, 7, 8, 9, 10],
           "partial: remainder of head chunk only, not the next chunk")
    expect(readBytes(buffer, max: 260, timeoutMs: 100) == [99, 98],
           "partial: next chunk afterwards")
}

// 3. Timeout on empty buffer.
do {
    let buffer = PacketReadBuffer()
    let start = DispatchTime.now()
    let result = readBytes(buffer, max: 16, timeoutMs: 100)
    let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6
    expect(result == nil, "timeout: empty buffer read returns nil")
    expect(elapsedMs >= 90, "timeout: waited near the deadline (\(elapsedMs) ms)")
}

// 4. Purge drops buffered chunks and stale wakeups.
do {
    let buffer = PacketReadBuffer()
    buffer.append(Data([1, 2, 3]))
    buffer.append(Data([4, 5, 6]))
    buffer.purge()
    expect(readBytes(buffer, max: 16, timeoutMs: 100) == nil,
           "purge: no data after purge despite earlier appends")
}

// 5. Poll is non-consuming and honors timeout.
do {
    let buffer = PacketReadBuffer()
    expect(!buffer.poll(deadline: DispatchTime.now() + .milliseconds(50)),
           "poll: empty buffer times out")
    buffer.append(Data([7, 7]))
    expect(buffer.poll(deadline: DispatchTime.now() + .milliseconds(50)),
           "poll: sees buffered data")
    expect(readBytes(buffer, max: 16, timeoutMs: 100) == [7, 7],
           "poll: did not consume the data")
}

// 6. Cross-thread delivery: a read blocked on an empty buffer wakes when a
// notification arrives from another thread (CoreBluetooth delegate queue).
do {
    let buffer = PacketReadBuffer()
    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(50)) {
        buffer.append(Data([42]))
    }
    expect(readBytes(buffer, max: 16, timeoutMs: 1000) == [42],
           "cross-thread: blocked read receives late append")
}

// 7. FIFO order across chunks.
do {
    let buffer = PacketReadBuffer()
    buffer.append(Data([1]))
    buffer.append(Data([2]))
    buffer.append(Data([3]))
    expect(readBytes(buffer, max: 16, timeoutMs: 100) == [1], "fifo: first")
    expect(readBytes(buffer, max: 16, timeoutMs: 100) == [2], "fifo: second")
    expect(readBytes(buffer, max: 16, timeoutMs: 100) == [3], "fifo: third")
}

// 8. Empty notifications are ignored: a zero-byte read would be treated as
// a protocol error by libdivecomputer packet parsers.
do {
    let buffer = PacketReadBuffer()
    buffer.append(Data())
    buffer.append(Data([5]))
    expect(readBytes(buffer, max: 16, timeoutMs: 100) == [5],
           "empty append: skipped, real chunk returned")
}

// 9. Purge also drops pending wakeup signals: a poll right after purge must
// not report data based on a stale signal from a purged chunk.
do {
    let buffer = PacketReadBuffer()
    buffer.append(Data([1]))
    buffer.append(Data([2]))
    buffer.purge()
    expect(!buffer.poll(deadline: DispatchTime.now() + .milliseconds(50)),
           "purge: poll sees no data from stale signals")
}

// 10. Signals left over from chunks consumed without waiting must not make
// poll report data on an empty buffer.
do {
    let buffer = PacketReadBuffer()
    buffer.append(Data([1, 2, 3]))
    _ = readBytes(buffer, max: 16, timeoutMs: 100)
    expect(!buffer.poll(deadline: DispatchTime.now() + .milliseconds(50)),
           "stale signal: poll on drained buffer returns false")
}

if failures == 0 {
    print("All PacketReadBuffer tests passed.")
    exit(0)
} else {
    print("\(failures) PacketReadBuffer test(s) FAILED.")
    exit(1)
}
