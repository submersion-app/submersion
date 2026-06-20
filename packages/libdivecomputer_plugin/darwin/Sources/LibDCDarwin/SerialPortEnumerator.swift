import Foundation
#if os(macOS)
import IOKit
import IOKit.serial
#endif

/// Enumerates and classifies macOS serial callout devices for dive-computer
/// downloads over USB-to-serial cables (e.g. the FTDI cable on a Mares Puck
/// Pro).
///
/// The classification and candidate-selection logic is pure (no IOKit, no
/// Flutter) so it can be unit-tested standalone via darwin/run_native_tests.sh.
/// Only `enumerateUsbSerialPaths()` touches IOKit, and only on macOS.
///
/// Why an allowlist rather than "open every serial port": opening some built-in
/// callout devices (notably `/dev/cu.Bluetooth-Incoming-Port`) can block, and
/// probing unrelated ports would send dive-computer handshake bytes to devices
/// that are not dive computers. The allowlist mirrors the Linux/Windows backends
/// which restrict auto-probe to USB-to-serial adapters.
enum SerialPortEnumerator {
    /// Known USB-to-serial bridge chip callout-device name prefixes (lowercased):
    /// - `cu.usbserial`     FTDI FT232 (the Mares Puck Pro cable)
    /// - `cu.usbmodem`      USB CDC-ACM
    /// - `cu.slab_usbtouart` Silicon Labs CP210x
    /// - `cu.wchusbserial`  WCH CH34x
    private static let allowedPrefixes = [
        "cu.usbserial",
        "cu.usbmodem",
        "cu.slab_usbtouart",
        "cu.wchusbserial",
    ]

    /// True if `path` names a USB-to-serial callout device safe to probe.
    ///
    /// Operates on the last path component so it works for both full paths
    /// (`/dev/cu.usbserial-A1`) and bare names (`cu.usbserial-A1`). Fail-closed:
    /// anything not matching a known USB-serial prefix is rejected, and built-in
    /// Bluetooth / debug-console callout devices are excluded explicitly.
    static func isUsbSerialCalloutPath(_ path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        let lower = name.lowercased()

        // Belt-and-suspenders denylist for built-in ports that must never be
        // probed, even if a future macOS were to name one with a USB prefix.
        if lower.hasPrefix("cu.bluetooth") || lower == "cu.debug-console" {
            return false
        }

        return allowedPrefixes.contains { lower.hasPrefix($0) }
    }

    /// Resolves the list of serial ports to try for a download.
    ///
    /// - If `address` is an explicit device path (`/dev/...`), trust it and use
    ///   it directly (the discovered-device / power-user case).
    /// - Otherwise (a synthetic manual-selection id like `Mares_Puck Pro_24`),
    ///   fall back to every available USB-to-serial port and let the caller probe
    ///   each one. This mirrors the Linux/Windows auto-probe.
    static func candidatePorts(address: String, available: [String]) -> [String] {
        if address.hasPrefix("/dev/") {
            return [address]
        }
        return available.filter(isUsbSerialCalloutPath)
    }

    #if os(macOS)
    /// Lists USB-to-serial callout devices currently present on the system.
    ///
    /// Uses the same IOKit query as `SerialScanner` (`kIOSerialBSDServiceValue`
    /// + `kIOCalloutDeviceKey`), then filters to USB-serial adapters via
    /// `isUsbSerialCalloutPath`. Returns paths like `/dev/cu.usbserial-A1`.
    static func enumerateUsbSerialPaths() -> [String] {
        let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary
        matchingDict[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes
        var iterator: io_iterator_t = 0

        let mainPort: mach_port_t
        if #available(macOS 12.0, *) {
            mainPort = kIOMainPortDefault
        } else {
            mainPort = kIOMasterPortDefault
        }
        let kr = IOServiceGetMatchingServices(mainPort, matchingDict, &iterator)
        guard kr == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var paths: [String] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let pathCF = IORegistryEntryCreateCFProperty(
                service,
                kIOCalloutDeviceKey as CFString,
                kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? String else { continue }

            paths.append(pathCF)
        }

        return paths.filter(isUsbSerialCalloutPath)
    }
    #else
    /// Serial/USB enumeration is not available on iOS.
    static func enumerateUsbSerialPaths() -> [String] { return [] }
    #endif
}
