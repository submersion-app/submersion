import Foundation

// Standalone test runner for ReadPollPolicy (no XCTest: the LibDCDarwin
// package cannot build under SwiftPM because it depends on Flutter modules
// only present in the CocoaPods build). Run via run_native_tests.sh.
// Mirrored case for case by ReadPollPolicyTest.kt on Android.

var failures = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message) (main.swift:\(line))")
        failures += 1
    }
}

// 1. An idle policy issues one read, then waits while it is in flight rather
// than stacking a second request behind it.
do {
    var policy = ReadPollPolicy()
    expect(policy.next(nowMs: 0) == .issueRead, "idle: first read is issued")
    expect(policy.readInFlight, "idle: the read is recorded as in flight")
    expect(policy.next(nowMs: 5) == .wait, "idle: a second read is not stacked")
    expect(policy.next(nowMs: 10_000) == .wait, "idle: still waiting however long it takes")
}

// 2. A value with data is queued, and the next read goes out at once.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    expect(policy.completed(hasData: true, nowMs: 50), "data: the value is queued")
    expect(policy.next(nowMs: 50) == .issueRead, "data: the next read is issued immediately")
}

// 3. An empty value is not queued, and the re-read waits retryDelayMs.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    expect(!policy.completed(hasData: false, nowMs: 1000), "empty: nothing is queued")
    expect(policy.next(nowMs: 1099) == .wait, "empty: no re-read before the retry delay")
    expect(policy.next(nowMs: 1100) == .issueRead, "empty: re-read once the delay has passed")
}

// 4. A read the platform refused to issue backs off the same way.
do {
    var policy = ReadPollPolicy()
    expect(policy.next(nowMs: 0) == .issueRead, "refused: read requested")
    policy.issueFailed(nowMs: 0)
    expect(!policy.readInFlight, "refused: nothing is in flight")
    expect(policy.next(nowMs: 99) == .wait, "refused: no retry before the delay")
    expect(policy.next(nowMs: 100) == .issueRead, "refused: retried after the delay")
}

// 5. purge() while a read is in flight discards its late value: it answers a
// command libdivecomputer has abandoned. The next read is not delayed.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    policy.purge()
    expect(!policy.completed(hasData: true, nowMs: 500), "purge: the late value is dropped")
    expect(policy.next(nowMs: 500) == .issueRead, "purge: the next read is issued at once")
    expect(policy.completed(hasData: true, nowMs: 600), "purge: the read after that is queued")
}

// 6. purge() with nothing in flight discards nothing later.
do {
    var policy = ReadPollPolicy()
    policy.purge()
    _ = policy.next(nowMs: 0)
    expect(policy.completed(hasData: true, nowMs: 10), "idle-purge: the next value is queued")
}

// 7. A discarded read that came back empty does not start a backoff.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    policy.purge()
    expect(!policy.completed(hasData: false, nowMs: 500), "purged-empty: nothing is queued")
    expect(policy.next(nowMs: 500) == .issueRead, "purged-empty: no backoff")
}

// 8. After close() every read fails and late completions are ignored, so a
// reader waiting with no timeout returns instead of blocking forever.
do {
    var policy = ReadPollPolicy()
    _ = policy.next(nowMs: 0)
    policy.close()
    expect(policy.next(nowMs: 1) == .closed, "close: reads fail")
    expect(!policy.completed(hasData: true, nowMs: 2), "close: a late value is dropped")
    expect(policy.next(nowMs: 3) == .closed, "close: still closed")
}

// 9. A device that answers every read with an empty value, over a 6000 ms
// deadline, polled every millisecond: reads go out once per retry delay,
// never in a tight loop.
do {
    var policy = ReadPollPolicy()
    var issued = 0
    var now: UInt64 = 0
    while now < 6000 {
        if policy.next(nowMs: now) == .issueRead {
            issued += 1
            _ = policy.completed(hasData: false, nowMs: now)
        }
        now += 1
    }
    expect(issued == 60, "no-spin: one read per 100 ms over 6000 ms, got \(issued)")
}

if failures == 0 {
    print("All ReadPollPolicy tests passed.")
    exit(0)
} else {
    print("\(failures) ReadPollPolicy test(s) FAILED.")
    exit(1)
}
