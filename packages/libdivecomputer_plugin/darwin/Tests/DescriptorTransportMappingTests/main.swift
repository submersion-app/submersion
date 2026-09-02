import Foundation

// Standalone tests for the descriptor transport mapping (issue #1271).
//
// The USB tab of the dive computer wizard is a static catalog picker driven
// entirely by this mapping, so a bit dropped here makes a supported computer
// unselectable with no error to explain why. That is exactly how issue #1271
// presented: a Scubapro G2 TEK downloads fine over Bluetooth on a phone, and on
// a desktop without Bluetooth there was no Scubapro model in the USB list at
// all. Until now the mapping had no test at any layer.
//
// Bitmasks come from libdivecomputer's descriptor.c, never from our
// implementation, so a wrong mapping cannot make its own test pass.
//
// Assertions use precondition() (not assert(), which the optimizer can elide)
// so a failure aborts the run even if these are ever built with -O.

typealias Transport = DescriptorTransportMapping.Transport
typealias Mode = DescriptorTransportMapping.Mode

func expect(_ condition: Bool, _ message: String) {
    precondition(condition, message)
}

func modes(_ transports: Transport, usbHid: Bool = true) -> [Mode] {
    DescriptorTransportMapping.modes(for: transports, supportsUsbHid: usbHid)
}

// descriptor.c:176
//   {"Scubapro", "G2 TEK", ..., DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, ...}
// The reported device. It must be offered under USB, which is the whole point
// of the issue, and the mapping must not invent a serial mode it does not have.
func testG2TekIsOfferedOverUsbAndBluetooth() {
    let result = modes([.usbhid, .ble])
    expect(result == [.ble, .usb], "G2 TEK must be offered over both, got \(result)")
    print("PASS: testG2TekIsOfferedOverUsbAndBluetooth")
}

// descriptor.c:171
//   {"Scubapro", "Aladin Square", ..., DC_TRANSPORT_USBHID, ...}
// USB HID and nothing else, so before this change it was unreachable in the app
// by any route: absent from the USB list and absent from a Bluetooth scan.
func testUsbHidOnlyComputerIsReachable() {
    let result = modes([.usbhid])
    expect(result == [.usb], "a HID-only computer must be offered, got \(result)")
    print("PASS: testUsbHidOnlyComputerIsReachable")
}

// descriptor.c:133-136, the Suunto EON Steel family, and the hardware behind
// issue #143: advertising USB with no HID transport behind it dead-ended the
// download at "No USB serial ports found". On a platform with no USB HID byte
// pipe the honest answer is still Bluetooth only.
func testUsbHidIsHiddenWithoutATransportBehindIt() {
    let result = modes([.usbhid, .ble], usbHid: false)
    expect(result == [.ble], "USB must not be offered with no HID pipe, got \(result)")

    let hidOnly = modes([.usbhid], usbHid: false)
    expect(hidOnly.isEmpty, "a HID-only computer has nowhere to go, got \(hidOnly)")
    print("PASS: testUsbHidIsHiddenWithoutATransportBehindIt")
}

// descriptor.c:309, {"Mares", "Puck Pro", ..., SERIAL | BLE, ...}. Serial is a
// mode of its own on the wire; the Dart layer folds it into the USB tab. This
// pins that the mapping did not start folding it early.
func testSerialStaysSerial() {
    let result = modes([.serial, .ble])
    expect(result == [.ble, .serial], "serial must stay serial, got \(result)")
    print("PASS: testSerialStaysSerial")
}

// descriptor.c:148, {"Uwatec", "Smart Pro", ..., DC_TRANSPORT_IRDA, ...}.
func testInfraredIsItsOwnMode() {
    let result = modes([.irda])
    expect(result == [.infrared], "infrared must map to infrared, got \(result)")
    print("PASS: testInfraredIsItsOwnMode")
}

// descriptor.c:370, {"Shearwater", "Petrel", ..., SERIAL | BLUETOOTH, ...}.
// Bluetooth Classic has no implementation here and never had one, so it must
// not be advertised. Mapping it to .ble would offer a scan that finds nothing.
func testBluetoothClassicIsNotAdvertised() {
    let result = modes([.serial, .bluetooth])
    expect(result == [.serial], "classic Bluetooth must not appear, got \(result)")
    print("PASS: testBluetoothClassicIsNotAdvertised")
}

func testNoTransportsYieldsNoModes() {
    expect(modes([]).isEmpty, "an empty bitmask offers nothing")
    print("PASS: testNoTransportsYieldsNoModes")
}

// The bit values are redeclared in DescriptorTransportMapping so the file
// compiles standalone, which makes them a third copy of numbers that originate
// in libdivecomputer's dc_transport_t. Every test above would keep passing if
// one copy drifted, while the real mapping silently read the wrong bits.
//
// This pins only the Swift copy against the documented values. It cannot see
// dc_transport_t itself, because the standalone build compiles this file with
// swiftc alone and no libdivecomputer headers. The other half of the chain,
// LIBDC_TRANSPORT_* against the real enum, is pinned in
// packages/libdivecomputer_plugin/test/native/test_usbhid_descriptor_match.c,
// where both headers are in scope.
func testBitValuesMatchLibdivecomputer() {
    expect(Transport.serial.rawValue == 1 << 0, "DC_TRANSPORT_SERIAL")
    expect(Transport.usb.rawValue == 1 << 1, "DC_TRANSPORT_USB")
    expect(Transport.usbhid.rawValue == 1 << 2, "DC_TRANSPORT_USBHID")
    expect(Transport.irda.rawValue == 1 << 3, "DC_TRANSPORT_IRDA")
    expect(Transport.bluetooth.rawValue == 1 << 4, "DC_TRANSPORT_BLUETOOTH")
    expect(Transport.ble.rawValue == 1 << 5, "DC_TRANSPORT_BLE")
    print("PASS: testBitValuesMatchLibdivecomputer")
}

testG2TekIsOfferedOverUsbAndBluetooth()
testUsbHidOnlyComputerIsReachable()
testUsbHidIsHiddenWithoutATransportBehindIt()
testSerialStaysSerial()
testInfraredIsItsOwnMode()
testBluetoothClassicIsNotAdvertised()
testNoTransportsYieldsNoModes()
testBitValuesMatchLibdivecomputer()
print("All descriptor transport mapping tests passed")
