import Foundation

// Standalone test runner for SerialPortEnumerator's pure logic (no XCTest: the
// LibDCDarwin package cannot build under SwiftPM because it depends on Flutter
// modules only present in the CocoaPods build). Run via darwin/run_native_tests.sh.
//
// Only the pure functions (isUsbSerialCalloutPath, candidatePorts) are exercised
// here; enumerateUsbSerialPaths() touches live IOKit hardware state and is not
// unit-testable.

var failures = 0

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message) (main.swift:\(line))")
        failures += 1
    }
}

// 1. USB-to-serial bridge chips are recognized (full /dev paths).
expect(SerialPortEnumerator.isUsbSerialCalloutPath("/dev/cu.usbserial-A12345"),
       "FTDI cu.usbserial (the Mares Puck Pro cable) is a candidate")
expect(SerialPortEnumerator.isUsbSerialCalloutPath("/dev/cu.usbmodem1101"),
       "CDC-ACM cu.usbmodem is a candidate")
expect(SerialPortEnumerator.isUsbSerialCalloutPath("/dev/cu.SLAB_USBtoUART"),
       "Silicon Labs CP210x cu.SLAB_USBtoUART is a candidate")
expect(SerialPortEnumerator.isUsbSerialCalloutPath("/dev/cu.wchusbserial1420"),
       "WCH CH34x cu.wchusbserial is a candidate")

// 2. Bare names (no /dev prefix) classify the same way.
expect(SerialPortEnumerator.isUsbSerialCalloutPath("cu.usbserial-A12345"),
       "bare cu.usbserial name is a candidate")

// 3. Built-in / non-serial callout devices are excluded (both present on a
//    typical Mac; opening the Bluetooth port can block).
expect(!SerialPortEnumerator.isUsbSerialCalloutPath("/dev/cu.Bluetooth-Incoming-Port"),
       "Bluetooth callout port is excluded")
expect(!SerialPortEnumerator.isUsbSerialCalloutPath("/dev/cu.debug-console"),
       "debug-console is excluded")
expect(!SerialPortEnumerator.isUsbSerialCalloutPath("/dev/cu.wlan-debug"),
       "unknown built-in port is excluded (fail-closed)")

// 4. candidatePorts: an explicit /dev path is trusted verbatim and ignores the
//    available list (discovered-device / power-user case).
expect(SerialPortEnumerator.candidatePorts(
        address: "/dev/cu.usbserial-X",
        available: ["/dev/cu.usbserial-OTHER"]) == ["/dev/cu.usbserial-X"],
       "explicit /dev path passes through unchanged")

// 5. candidatePorts: a synthetic manual-selection id (contains a space, not a
//    path) falls back to the filtered enumeration; the Bluetooth port is dropped.
expect(SerialPortEnumerator.candidatePorts(
        address: "Mares_Puck Pro_24",
        available: ["/dev/cu.usbserial-X", "/dev/cu.Bluetooth-Incoming-Port"])
        == ["/dev/cu.usbserial-X"],
       "synthetic id selects USB-serial ports, excludes Bluetooth")

// 6. candidatePorts: no USB-serial ports available -> empty (drives the
//    "no_serial_ports" error in the host impl).
expect(SerialPortEnumerator.candidatePorts(
        address: "Mares_Puck Pro_24",
        available: ["/dev/cu.Bluetooth-Incoming-Port"]).isEmpty,
       "no USB-serial ports -> empty candidate list")
expect(SerialPortEnumerator.candidatePorts(
        address: "Mares_Puck Pro_24", available: []).isEmpty,
       "empty availability -> empty candidate list")

if failures == 0 {
    print("\nAll SerialPortEnumerator tests passed.")
    exit(0)
} else {
    print("\n\(failures) SerialPortEnumerator test(s) failed.")
    exit(1)
}
