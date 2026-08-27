import CoreBluetooth
import Foundation

// Standalone test runner for BleConnectFailure (no XCTest: the LibDCDarwin
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

/// A CoreBluetooth error as CoreBluetooth itself reports it.
func cbError(_ code: CBError.Code) -> NSError {
    return NSError(domain: CBErrorDomain, code: code.rawValue, userInfo: nil)
}

// 1. The error the reporter's iPad logged against a Perdix 3 whose pairing
// record had gone stale (issue #865): CoreBluetooth refuses the connection
// outright with "Peer removed pairing information".
do {
    expect(
        BleConnectFailure.fromConnectError(cbError(.peerRemovedPairingInformation))
            == .stalePairing,
        "peerRemovedPairingInformation classifies as stale pairing")
}

// 2. The other side of the same coin: the peer still accepts the connection but
// the link cannot be encrypted with the stored key, so encryption times out.
do {
    expect(
        BleConnectFailure.fromConnectError(cbError(.encryptionTimedOut)) == .stalePairing,
        "encryptionTimedOut classifies as stale pairing")
}

// 3. An ordinary connection timeout is not a pairing problem -- the computer
// was simply out of range or had left its BLE menu.
do {
    expect(
        BleConnectFailure.fromConnectError(cbError(.connectionTimeout)) == .other,
        "connectionTimeout is not a pairing failure")
}

// 4. didFailToConnect is allowed to report no error at all.
do {
    expect(BleConnectFailure.fromConnectError(nil) == .other,
           "a missing error classifies as other")
}

// 5. The classifier must key off the CoreBluetooth domain, not the bare code.
// POSIX errno 14 is EFAULT and errno 15 is ENOTBLK; neither says anything
// about pairing, and misreading one as a stale bond would send the user off to
// Bluetooth settings for nothing.
do {
    let posix = NSError(
        domain: NSPOSIXErrorDomain,
        code: CBError.Code.peerRemovedPairingInformation.rawValue,
        userInfo: nil)
    expect(BleConnectFailure.fromConnectError(posix) == .other,
           "a matching code in another error domain is not a pairing failure")
}

// 6. Only a stale bond is terminal. Apple exposes no API to delete a pairing
// record, so no amount of retrying inside the app can clear one -- the download
// path must stop and hand the user the fix instead of burning a second attempt
// (the iPad log shows attempt 2 failing identically 500 ms later).
do {
    expect(BleConnectFailure.stalePairing.isTerminal,
           "stale pairing is terminal: only the user can clear the bond")
    expect(!BleConnectFailure.discoveryStalled.isTerminal,
           "a discovery stall is worth one more attempt")
    expect(!BleConnectFailure.other.isTerminal,
           "an unclassified failure is worth one more attempt")
}

// 7. Every failure has to name an error code for the Dart layer, and the codes
// have to stay distinct: DownloadStepWidget switches on them to pick which
// piece of advice to show.
do {
    expect(BleConnectFailure.stalePairing.errorCode == "stale_pairing",
           "stale pairing reports the stale_pairing code")
    expect(BleConnectFailure.discoveryStalled.errorCode == "discovery_stalled",
           "a discovery stall reports the discovery_stalled code")
    expect(BleConnectFailure.other.errorCode == "connect_failed",
           "an unclassified failure keeps the existing connect_failed code")
}

if failures > 0 {
    print("\(failures) test(s) failed")
    exit(1)
}
print("All BleConnectFailure tests passed")
