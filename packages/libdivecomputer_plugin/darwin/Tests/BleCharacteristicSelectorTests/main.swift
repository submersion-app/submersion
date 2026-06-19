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

let halcyonService = "00000001-8C3B-4F2C-A59E-8C08224F3253"
let halcyonRx = "00000101-8C3B-4F2C-A59E-8C08224F3253"
let halcyonTx = "00000201-8C3B-4F2C-A59E-8C08224F3253"

// 1. Halcyon Symbios (issue #288): the device exposes an Rx characteristic
// (00000101: read+write+indicate, where the app receives replies) and a Tx
// characteristic (00000201: write, where the app sends commands). Both
// advertise plain write and tie on raw score, and Rx has the lower handle, so
// the generic scorer would pick Rx for writing and the device never answers.
// Commands must go to Tx; replies must be read from Rx.
do {
    let service = BleCharacteristicSelector.Service(
        uuid: CBUUID(string: halcyonService),
        characteristics: [
            char(halcyonRx, [.read, .write, .indicate]),
            char(halcyonTx, [.write]),
        ]
    )
    let selection = BleCharacteristicSelector.select(services: [service])
    expect(selection?.writeUUID == CBUUID(string: halcyonTx),
           "halcyon: command write characteristic is Tx (00000201), "
               + "got \(selection?.writeUUID.uuidString ?? "nil")")
    expect(selection?.notifyUUID == CBUUID(string: halcyonRx),
           "halcyon: notify characteristic is Rx (00000101), "
               + "got \(selection?.notifyUUID.uuidString ?? "nil")")
}

// 2. Regression: a device with one write-only and one notify-only
// characteristic (e.g. Aqualung i300C) must keep them split.
do {
    let writeUUID = "0000fefb-0000-1000-8000-00805f9b34fb"
    let notifyUUID = "0000fefc-0000-1000-8000-00805f9b34fb"
    let service = BleCharacteristicSelector.Service(
        uuid: CBUUID(string: "0000fef5-0000-1000-8000-00805f9b34fb"),
        characteristics: [
            char(writeUUID, [.write, .writeWithoutResponse]),
            char(notifyUUID, [.notify]),
        ]
    )
    let selection = BleCharacteristicSelector.select(services: [service])
    expect(selection?.writeUUID == CBUUID(string: writeUUID),
           "split: write characteristic chosen correctly")
    expect(selection?.notifyUUID == CBUUID(string: notifyUUID),
           "split: notify characteristic chosen correctly")
}

// 3. Regression: a single characteristic that is both writable and
// notifiable (common pattern) is used for both roles.
do {
    let combined = "0000ffe1-0000-1000-8000-00805f9b34fb"
    let service = BleCharacteristicSelector.Service(
        uuid: CBUUID(string: "0000ffe0-0000-1000-8000-00805f9b34fb"),
        characteristics: [
            char(combined, [.writeWithoutResponse, .notify]),
        ]
    )
    let selection = BleCharacteristicSelector.select(services: [service])
    expect(selection?.writeUUID == CBUUID(string: combined),
           "combined: single characteristic used for write")
    expect(selection?.notifyUUID == CBUUID(string: combined),
           "combined: single characteristic used for notify")
}

// 4. A service with no notify/indicate characteristic yields no selection,
// even if it has a writable characteristic.
do {
    let service = BleCharacteristicSelector.Service(
        uuid: CBUUID(string: "0000180a-0000-1000-8000-00805f9b34fb"),
        characteristics: [
            char("00002a29-0000-1000-8000-00805f9b34fb", [.read]),
        ]
    )
    expect(BleCharacteristicSelector.select(services: [service]) == nil,
           "no-notify: service without a notify characteristic is not selected")
}

if failures == 0 {
    print("All BleCharacteristicSelector tests passed.")
    exit(0)
} else {
    print("\(failures) BleCharacteristicSelector test(s) FAILED.")
    exit(1)
}
