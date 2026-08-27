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

// 1. Halcyon Symbios (issue #288). On a real device BOTH characteristics
// advertise read+write+indicate (confirmed by the GATT discovery log on the
// issue), so the raw write/notify scores tie and a preferred UUID must decide
// the pair. The Tx/Rx names are device-centric -- Subsurface's qt-ble.cpp
// labels 00000101 "Rx" and 00000201 "Tx" and writes commands to the device's
// Rx while reading replies from the device's Tx. So the app must WRITE to
// 00000101 (halcyonRx) and SUBSCRIBE on 00000201 (halcyonTx). PR #356 mapped
// these backwards (wrote to Tx, listened on Rx); the device received the write
// at the ATT layer but never answered (result=-7). This asserts the corrected
// mapping that matches the known-working Subsurface implementation.
do {
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: halcyonService),
            characteristics: [
                char(halcyonRx, [.read, .write, .indicate]),
                char(halcyonTx, [.read, .write, .indicate]),
            ]
        )
    ]
    let result = resolve(services, BleCharacteristicSelector.select(services: services))
    expect(result?.write == CBUUID(string: halcyonRx),
           "halcyon: app writes commands to the device Rx (00000101), "
               + "got \(result?.write.uuidString ?? "nil")")
    expect(result?.notify == CBUUID(string: halcyonTx),
           "halcyon: app reads replies from the device Tx (00000201), "
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

// 9. Heinrichs Weikamp OSTC4 (issue #923). The real GATT table enumerated from
// the reporter's device: the Telit/Stollmann Terminal I/O service alongside the
// Stollmann vendor service. The transport must land on the TIO service, write
// commands to UART Data RX, listen on UART Data TX, and surface the credit
// characteristics so the caller can run the handshake that opens the UART
// bridge. Without the handshake the first command write fails and
// libdivecomputer reports "Failed to send the command".
do {
    let tioService = "0000FEFB-0000-1000-8000-00805F9B34FB"
    let dataRx = "00000001-0000-1000-8000-008025000000"
    let dataTx = "00000002-0000-1000-8000-008025000000"
    let creditsRx = "00000003-0000-1000-8000-008025000000"
    let creditsTx = "00000004-0000-1000-8000-008025000000"
    let vendorService = "53544D54-4552-494F-5345-525631303030"
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: tioService),
            characteristics: [
                char(dataRx, [.writeWithoutResponse]),
                char(dataTx, [.notify]),
                char(creditsRx, [.write]),
                char(creditsTx, [.indicate]),
            ]
        ),
        // The vendor service ties on raw score (writeNoResponse+notify = 8) and
        // would win on discovery order if the TIO service were not preferred.
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: vendorService),
            characteristics: [
                char("53544D01-4552-494F-5345-525631303030", [.writeWithoutResponse]),
                char("53544D02-4552-494F-5345-525631303030", [.notify]),
            ]
        ),
    ]
    let selection = BleCharacteristicSelector.select(services: services)
    let result = resolve(services, selection)
    expect(result?.serviceIndex == 0, "ostc4: Terminal I/O service selected over the vendor service")
    expect(result?.write == CBUUID(string: dataRx), "ostc4: commands go to UART Data RX")
    expect(result?.notify == CBUUID(string: dataTx), "ostc4: replies arrive on UART Data TX")
    expect(selection?.terminalIoCredits?.writeIndex == 2, "ostc4: UART Credits RX located")
    expect(selection?.terminalIoCredits?.notifyIndex == 3, "ostc4: UART Credits TX located")
    expect(selection?.terminalIoCredits?.required == true,
           "ostc4: Telit credits are mandatory (bridge stays closed without them)")
}

// 10. Discovery order must not decide it: the same two services in the reverse
// order still select the Terminal I/O service.
do {
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "53544D54-4552-494F-5345-525631303030"),
            characteristics: [
                char("53544D01-4552-494F-5345-525631303030", [.writeWithoutResponse]),
                char("53544D02-4552-494F-5345-525631303030", [.notify]),
            ]
        ),
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "0000FEFB-0000-1000-8000-00805F9B34FB"),
            characteristics: [
                char("00000001-0000-1000-8000-008025000000", [.writeWithoutResponse]),
                char("00000002-0000-1000-8000-008025000000", [.notify]),
                char("00000003-0000-1000-8000-008025000000", [.write]),
                char("00000004-0000-1000-8000-008025000000", [.indicate]),
            ]
        ),
    ]
    let selection = BleCharacteristicSelector.select(services: services)
    expect(selection?.serviceIndex == 1,
           "ostc4-reordered: Terminal I/O service wins regardless of discovery order")
    expect(selection?.terminalIoCredits != nil,
           "ostc4-reordered: credit characteristics still located")
}

// 11. Devices with no credit characteristics must be left exactly as they
// were: no handshake, so every currently-working device stays on today's
// plain write/notify path.
do {
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "0000ffe0-0000-1000-8000-00805f9b34fb"),
            characteristics: [char("0000ffe1-0000-1000-8000-00805f9b34fb",
                                   [.writeWithoutResponse, .notify])]
        )
    ]
    expect(BleCharacteristicSelector.select(services: services)?.terminalIoCredits == nil,
           "non-TIO: no credit handshake requested")
}

// 12. A partial Telit layout -- data characteristics with no credit pair, and
// not u-blox either -- is an unknown shape and must not trigger a handshake.
do {
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "0000FEFB-0000-1000-8000-00805F9B34FB"),
            characteristics: [
                char("00000001-0000-1000-8000-008025000000", [.writeWithoutResponse]),
                char("00000002-0000-1000-8000-008025000000", [.notify]),
            ]
        )
    ]
    expect(BleCharacteristicSelector.select(services: services)?.terminalIoCredits == nil,
           "partial-TIO: incomplete characteristic set does not trigger the handshake")
}

// 13. u-blox serial service: one characteristic carries data in both
// directions and one carries credits in both directions, so the write and
// notify roles collapse onto the same index on each side. Credits are
// OPTIONAL here -- a device on this service (the OSTC nano, #280/#394)
// downloads today with no handshake at all, so a rejected grant must be able
// to fall back rather than fail the connection.
do {
    let ubloxData = "2456E1B9-26E2-8F83-E744-F34F01E9D703"
    let ubloxCredits = "2456E1B9-26E2-8F83-E744-F34F01E9D704"
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "2456E1B9-26E2-8F83-E744-F34F01E9D701"),
            characteristics: [
                char(ubloxData, [.writeWithoutResponse, .notify]),
                char(ubloxCredits, [.write, .indicate]),
            ]
        )
    ]
    let selection = BleCharacteristicSelector.select(services: services)
    let result = resolve(services, selection)
    expect(result?.write == CBUUID(string: ubloxData), "ublox: commands go to the FIFO characteristic")
    expect(result?.notify == CBUUID(string: ubloxData), "ublox: replies arrive on the same FIFO characteristic")
    expect(selection?.terminalIoCredits?.writeIndex == 1, "ublox: credits characteristic located for writes")
    expect(selection?.terminalIoCredits?.notifyIndex == 1, "ublox: same characteristic used for credit indications")
    expect(selection?.terminalIoCredits?.required == false,
           "ublox: credits are optional, so a failed grant can fall back")
}

// 14. The u-blox credits characteristic must never be mistaken for the data
// characteristic. Here credits advertise write-without-response + notify --
// the top raw score on both sides -- so only the preferred-UUID pin on the
// FIFO keeps commands off the credits endpoint.
do {
    let ubloxData = "2456E1B9-26E2-8F83-E744-F34F01E9D703"
    let ubloxCredits = "2456E1B9-26E2-8F83-E744-F34F01E9D704"
    let services = [
        BleCharacteristicSelector.Service(
            uuid: CBUUID(string: "2456E1B9-26E2-8F83-E744-F34F01E9D701"),
            characteristics: [
                char(ubloxCredits, [.writeWithoutResponse, .notify]),
                char(ubloxData, [.write, .indicate]),
            ]
        )
    ]
    let result = resolve(services, BleCharacteristicSelector.select(services: services))
    expect(result?.write == CBUUID(string: ubloxData),
           "ublox-pin: FIFO wins the write role despite the lower raw score")
    expect(result?.notify == CBUUID(string: ubloxData),
           "ublox-pin: FIFO wins the notify role despite the lower raw score")
}

if failures == 0 {
    print("All BleCharacteristicSelector tests passed.")
    exit(0)
} else {
    print("\(failures) BleCharacteristicSelector test(s) FAILED.")
    exit(1)
}
