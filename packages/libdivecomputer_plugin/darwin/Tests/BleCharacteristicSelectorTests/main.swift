import CoreBluetooth
import Foundation

// Standalone test runner for BleCharacteristicSelector (no XCTest: the
// LibDCDarwin package cannot build under SwiftPM because it depends on Flutter
// modules only present in the CocoaPods build). Run via run_native_tests.sh.

var failures = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message) (main.swift:\(line))")
        failures += 1
    }
}

func char(_ uuid: String, _ properties: CBCharacteristicProperties)
    -> BleCharacteristicSelector.Characteristic {
    BleCharacteristicSelector.Characteristic(uuid: CBUUID(string: uuid), properties: properties)
}

/// Resolve a selection back to concrete UUIDs the way BleIoStream does, by
/// indexing into the original services. Returns nil for a nil selection.
func resolve(_ services: [BleCharacteristicSelector.Service],
             _ selection: BleCharacteristicSelector.Selection?)
    -> (write: CBUUID, notify: CBUUID, serviceIndex: Int)? {
    guard let selection else { return nil }
    let service = services[selection.serviceIndex]
    return (
        service.characteristics[selection.writeIndex].uuid,
        service.characteristics[selection.notifyIndex].uuid,
        selection.serviceIndex
    )
}

let halcyonService = "00000001-8C3B-4F2C-A59E-8C08224F3253"
let halcyonRx = "00000101-8C3B-4F2C-A59E-8C08224F3253"
let halcyonTx = "00000201-8C3B-4F2C-A59E-8C08224F3253"
let pelagicWrite = "6606AB42-89D5-4A00-A8CE-4EB5E1414EE0"
let preferredService = "CB3C4555-D670-4670-BC20-B61DBC851E9A"

// 1. Halcyon Symbios (issue #288): Rx (00000101: read+write+indicate, app
// receives replies) and Tx (00000201: write, app sends commands). Both
// advertise plain write and tie on raw score, with Rx at the lower handle, so
// the generic scorer would pick Rx for writing and the device never answers.
// Commands must go to Tx; replies must be read from Rx.
do {
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: halcyonService),
            characteristics: [
                char(halcyonRx, [.read, .write, .indicate]),
                char(halcyonTx, [.write]),
            ]
        )
    ]
    let result = resolve(services, BleCharacteristicSelector.select(services: services))
    expect(result?.write == CBUUID(string: halcyonTx),
           "halcyon: command write characteristic is Tx (00000201), "
               + "got \(result?.write.uuidString ?? "nil")")
    expect(result?.notify == CBUUID(string: halcyonRx),
           "halcyon: notify characteristic is Rx (00000101), "
               + "got \(result?.notify.uuidString ?? "nil")")
}

// 2. Regression: a device with one write-only and one notify-only
// characteristic (e.g. Aqualung i300C) must keep them split. Exercises the
// write-without-response (+4) write-score branch.
do {
    let writeUUID = "0000fefb-0000-1000-8000-00805f9b34fb"
    let notifyUUID = "0000fefc-0000-1000-8000-00805f9b34fb"
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "0000fef5-0000-1000-8000-00805f9b34fb"),
            characteristics: [
                char(writeUUID, [.write, .writeWithoutResponse]),
                char(notifyUUID, [.notify]),
            ]
        )
    ]
    let result = resolve(services, BleCharacteristicSelector.select(services: services))
    expect(result?.write == CBUUID(string: writeUUID), "split: write characteristic chosen")
    expect(result?.notify == CBUUID(string: notifyUUID), "split: notify characteristic chosen")
}

// 3. Regression: a single characteristic that is both writable and notifiable
// is used for both roles.
do {
    let combined = "0000ffe1-0000-1000-8000-00805f9b34fb"
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "0000ffe0-0000-1000-8000-00805f9b34fb"),
            characteristics: [char(combined, [.writeWithoutResponse, .notify])]
        )
    ]
    let result = resolve(services, BleCharacteristicSelector.select(services: services))
    expect(result?.write == CBUUID(string: combined), "combined: single char used for write")
    expect(result?.notify == CBUUID(string: combined), "combined: single char used for notify")
}

// 4. A service with no notify/indicate characteristic is not selectable.
do {
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "0000180a-0000-1000-8000-00805f9b34fb"),
            characteristics: [char("00002a29-0000-1000-8000-00805f9b34fb", [.read])]
        )
    ]
    expect(BleCharacteristicSelector.select(services: services) == nil,
           "no-notify: service without a notify characteristic is not selected")
}

// 5. Empty input yields no selection.
do {
    expect(BleCharacteristicSelector.select(services: []) == nil,
           "empty: no services yields nil")
}

// 6. A preferred-service UUID (+1000) wins over a service with a higher raw
// score, and the preferred-write UUID (+1000) is chosen within it. The plain
// service has the higher raw score (writeNoResponse+notify = 4+4) yet the
// preferred service still wins.
do {
    let plainService = "0000aaaa-0000-1000-8000-00805f9b34fb"
    let plainWrite = "0000aab1-0000-1000-8000-00805f9b34fb"
    let plainNotify = "0000aab2-0000-1000-8000-00805f9b34fb"
    let prefNotify = "0000bbb2-0000-1000-8000-00805f9b34fb"
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: plainService),
            characteristics: [
                char(plainWrite, [.writeWithoutResponse]),
                char(plainNotify, [.notify]),
            ]
        ),
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: preferredService),
            characteristics: [
                char(pelagicWrite, [.write]),  // preferred-write +1000
                char(prefNotify, [.indicate]),
            ]
        ),
    ]
    let result = resolve(services, BleCharacteristicSelector.select(services: services))
    expect(result?.serviceIndex == 1, "preferred: preferred service wins despite lower raw score")
    expect(result?.write == CBUUID(string: pelagicWrite), "preferred: preferred write UUID wins")
}

// 7. Copilot review: resolution must not be UUID-only. Two service instances
// share the same UUID; the SECOND scores higher (notify +4 vs indicate +2).
// The selection must identify the second instance by index so the caller
// resolves the correct live characteristics, not the first same-UUID service.
do {
    let dupUUID = "0000dddd-0000-1000-8000-00805f9b34fb"
    let firstWrite = "0000dd01-0000-1000-8000-00805f9b34fb"
    let firstNotify = "0000dd02-0000-1000-8000-00805f9b34fb"
    let secondWrite = "0000dd03-0000-1000-8000-00805f9b34fb"
    let secondNotify = "0000dd04-0000-1000-8000-00805f9b34fb"
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: dupUUID),
            characteristics: [char(firstWrite, [.write]), char(firstNotify, [.indicate])]
        ),
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: dupUUID),
            characteristics: [char(secondWrite, [.write]), char(secondNotify, [.notify])]
        ),
    ]
    let result = resolve(services, BleCharacteristicSelector.select(services: services))
    expect(result?.serviceIndex == 1,
           "dup-uuid: higher-scoring same-UUID instance selected by index")
    expect(result?.write == CBUUID(string: secondWrite),
           "dup-uuid: write resolves to the correct service instance")
    expect(result?.notify == CBUUID(string: secondNotify),
           "dup-uuid: notify resolves to the correct service instance")
}

// 8. Within one service, a later notify candidate with a higher score
// (notify +4) replaces an earlier lower one (indicate +2); likewise a later
// write candidate (writeNoResponse +4) replaces an earlier write (+2).
do {
    let writeLow = "0000ee01-0000-1000-8000-00805f9b34fb"
    let notifyLow = "0000ee02-0000-1000-8000-00805f9b34fb"
    let notifyHigh = "0000ee03-0000-1000-8000-00805f9b34fb"
    let writeHigh = "0000ee04-0000-1000-8000-00805f9b34fb"
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "0000ee00-0000-1000-8000-00805f9b34fb"),
            characteristics: [
                char(writeLow, [.write]),  // score 2
                char(notifyLow, [.indicate]),  // score 2
                char(notifyHigh, [.notify]),  // score 4 -> replaces notifyLow
                char(writeHigh, [.writeWithoutResponse]),  // score 4 -> replaces writeLow
            ]
        )
    ]
    let result = resolve(services, BleCharacteristicSelector.select(services: services))
    expect(result?.write == CBUUID(string: writeHigh),
           "higher-score: later write candidate replaces the earlier one")
    expect(result?.notify == CBUUID(string: notifyHigh),
           "higher-score: later notify candidate replaces the earlier one")
}

if failures == 0 {
    print("All BleCharacteristicSelector tests passed.")
    exit(0)
} else {
    print("\(failures) BleCharacteristicSelector test(s) FAILED.")
    exit(1)
}
