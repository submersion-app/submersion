import Foundation

// Standalone test runner for BleWriteModePolicy (no XCTest: the LibDCDarwin
// package cannot build under SwiftPM because it depends on Flutter modules
// only present in the CocoaPods build). Run via run_native_tests.sh.

var failures = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message) (main.swift:\(line))")
        failures += 1
    }
}

// Characteristic UUIDs as CBUUID.uuidString reports them (upper case).
let shearwater = "27B7570B-359E-45A3-91BB-CF7E70049BD2"
let pelagicGen1 = "6606AB42-89D5-4A00-A8CE-4EB5E1414EE0"
let generic = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

// 1. Shearwater (issue #4332): its characteristic offers both write modes,
// and requests go out without waiting for an ATT write response, the way the
// Android transport already sends them. Waiting for the response cost up to a
// connection interval on every block request of a download.
expect(
    BleWriteModePolicy.prefersWithoutResponse(
        characteristicUuid: shearwater,
        supportsWrite: true,
        supportsWriteWithoutResponse: true),
    "shearwater: both modes offered, without-response preferred")

// 2. The match ignores case, so a lower-case UUID string still matches.
expect(
    BleWriteModePolicy.prefersWithoutResponse(
        characteristicUuid: shearwater.lowercased(),
        supportsWrite: true,
        supportsWriteWithoutResponse: true),
    "shearwater: lower-case UUID still matches")

// 3. A Shearwater characteristic that lacks write-without-response keeps the
// acknowledged write: the preference never asks for a mode that is missing.
expect(
    !BleWriteModePolicy.prefersWithoutResponse(
        characteristicUuid: shearwater,
        supportsWrite: true,
        supportsWriteWithoutResponse: false),
    "shearwater: without-response missing, acknowledged write kept")

// 4. Pelagic gen 1 TX is unchanged: always without-response.
expect(
    BleWriteModePolicy.prefersWithoutResponse(
        characteristicUuid: pelagicGen1,
        supportsWrite: true,
        supportsWriteWithoutResponse: true),
    "pelagic gen1: without-response preferred")

// 5. Every other characteristic offering both modes is unchanged: the
// acknowledged write stays the default.
expect(
    !BleWriteModePolicy.prefersWithoutResponse(
        characteristicUuid: generic,
        supportsWrite: true,
        supportsWriteWithoutResponse: true),
    "generic: both modes offered, acknowledged write kept")

// 6. A characteristic offering only write-without-response uses it.
expect(
    BleWriteModePolicy.prefersWithoutResponse(
        characteristicUuid: generic,
        supportsWrite: false,
        supportsWriteWithoutResponse: true),
    "generic: only without-response offered, used")

// 7. A characteristic offering only the acknowledged write uses it.
expect(
    !BleWriteModePolicy.prefersWithoutResponse(
        characteristicUuid: generic,
        supportsWrite: true,
        supportsWriteWithoutResponse: false),
    "generic: only acknowledged write offered, used")

if failures == 0 {
    print("All BleWriteModePolicy tests passed.")
    exit(0)
} else {
    print("\(failures) BleWriteModePolicy test(s) FAILED.")
    exit(1)
}
