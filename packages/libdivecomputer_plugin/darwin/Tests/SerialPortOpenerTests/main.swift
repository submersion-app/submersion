import Foundation

// Standalone test runner for SerialPortOpener (no XCTest: the LibDCDarwin
// package cannot build under SwiftPM because it depends on Flutter modules only
// present in the CocoaPods build). Run via darwin/run_native_tests.sh.
//
// Covers issue #291: a sandboxed macOS build without
// com.apple.security.device.serial is denied open(2) on /dev/cu.* with EPERM,
// but the old code returned a bare Bool, so the log only ever said "Failed to
// open serial port" with no reason. These tests pin the errno -> reason mapping
// and the fd/failure contract.

var failures = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message) (main.swift:\(line))")
        failures += 1
    }
}

// 1. EPERM is the sandbox denial. It must name the entitlement cause, because
//    a plain "Operation not permitted" reads as a driver/cable fault and sent
//    issue #291 down a two-month dead end.
let epermReason = serialOpenFailureReason(errnoValue: EPERM)
expect(epermReason.lowercased().contains("permitted"),
       "EPERM reason states the operation was not permitted")
expect(epermReason.lowercased().contains("entitlement"),
       "EPERM reason names the missing macOS serial entitlement")

// 2. Distinct, actionable text for the other realistic open(2) failures, so
//    they are never confused with the sandbox case.
expect(serialOpenFailureReason(errnoValue: EBUSY).lowercased().contains("another"),
       "EBUSY reason points at another application holding the port")
expect(serialOpenFailureReason(errnoValue: ENOENT).lowercased().contains("no longer"),
       "ENOENT reason suggests the port vanished (cable unplugged)")
expect(!serialOpenFailureReason(errnoValue: EACCES).isEmpty,
       "EACCES reason is non-empty")

// 3. Every mapped reason is distinguishable from the others.
let mapped = [EPERM, EACCES, EBUSY, ENOENT].map {
    serialOpenFailureReason(errnoValue: $0)
}
expect(Set(mapped).count == mapped.count,
       "each mapped errno produces a distinct reason")

// 4. An unmapped errno still yields the system description rather than an
//    empty string (fail-informative, never fail-silent).
let unmapped = serialOpenFailureReason(errnoValue: EDOM)
expect(!unmapped.isEmpty, "unmapped errno falls back to a non-empty description")
expect(unmapped.contains(String(cString: strerror(EDOM))),
       "unmapped errno includes the strerror text")

// 5. Success path: /dev/null accepts the same open(2) flags a serial callout
//    device does, and exists on every machine (including CI runners with no
//    serial hardware attached).
switch openSerialPort(path: "/dev/null") {
case .success(let fd):
    expect(fd >= 0, "opening /dev/null yields a valid descriptor")
    close(fd)
case .failure(let failure):
    expect(false, "opening /dev/null should succeed (got \(failure.reason))")
}

// 6. Failure path carries the real errno, not just a boolean.
switch openSerialPort(path: "/dev/cu.submersion-nonexistent-291") {
case .success(let fd):
    close(fd)
    expect(false, "a nonexistent port must not open")
case .failure(let failure):
    expect(failure.errnoValue == ENOENT,
           "a nonexistent port reports ENOENT, not a bare failure")
    expect(!failure.reason.isEmpty, "the failure carries a human-readable reason")
}

if failures == 0 {
    print("\nAll SerialPortOpener tests passed.")
    exit(0)
} else {
    print("\n\(failures) SerialPortOpener test(s) failed.")
    exit(1)
}
