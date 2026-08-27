import Foundation

// Standalone tests for the dive-cable USB allowlist (issue #732).
//
// Only the classification half is exercised. enumerateDiveCables() walks the
// IOKit registry and needs real hardware, so it is deliberately kept as a thin
// wrapper around these pure functions.
//
// The allowlist is fail-closed on purpose. The raw-USB path opens a device and
// writes dive-computer handshake bytes to it, so it must never touch a device
// that merely happens to be an FTDI part: a user's Arduino, radio programming
// cable or JTAG probe is not a dive computer.
//
// Assertions use precondition() so they survive -O.

private func check(_ condition: Bool, _ message: String) {
    precondition(condition, message)
}

// The three FTDI cables. 0xF460 is the one issue #732 reports; the Linux
// kernel names it FTDI_OCEANIC_PID in drivers/usb/serial/ftdi_sio_ids.h.
check(UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0xF460),
    "the Oceanic/Aeris cable is recognised")
check(UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0xF680),
    "the Suunto cable is recognised")
check(UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0x87D0),
    "the Cressi Leonardo cable is recognised")

// Stock FTDI product IDs are claimed by macOS and appear as /dev/cu.usbserial
// nodes, so they belong to the serial path, not this one. Matching them here
// would mean opening the same hardware twice by two different routes.
check(!UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0x6001),
    "a stock FT232 is left to the serial path")
check(!UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0x6015),
    "a stock FT231X is left to the serial path")

// Fail closed on everything else, including the right product ID under the
// wrong vendor.
check(!UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x1234, productId: 0xF460),
    "the product ID alone is not enough to match")
check(!UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0000, productId: 0x0000),
    "an unknown device is rejected")

// The cable name is what the download log and the probe log show the user, so
// a matched device is always nameable.
check(UsbFtdiDeviceEnumerator.cableName(vendorId: 0x0403, productId: 0xF460) != nil,
    "a known cable has a name")
check(UsbFtdiDeviceEnumerator.cableName(vendorId: 0x0403, productId: 0x6001) == nil,
    "an unknown cable has no name")

for cable in UsbFtdiDeviceEnumerator.knownCables {
    check(UsbFtdiDeviceEnumerator.isKnownDiveCable(
            vendorId: cable.vendorId, productId: cable.productId),
        "every table entry matches itself: \(cable.cable)")
    check(!cable.cable.isEmpty, "every table entry is named")
}

// displayName prefers the descriptor string the device reports, because that
// is what the user sees on the cable's packaging, and falls back to our own
// label when the device reports nothing.
let named = UsbFtdiDevice(
    vendorId: 0x0403, productId: 0xF460, locationId: 0x14100000,
    productName: "USB Download Interface")
check(named.displayName == "USB Download Interface",
    "a device that names itself keeps its own name")

let anonymous = UsbFtdiDevice(
    vendorId: 0x0403, productId: 0xF460, locationId: 0x14100000, productName: "")
check(anonymous.displayName == anonymous.cableName,
    "a device that names itself nothing falls back to the cable label")
check(!anonymous.displayName.isEmpty, "the fallback is never empty")

print("UsbFtdiDeviceEnumeratorTests: all assertions passed")
