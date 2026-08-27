import Foundation
#if os(macOS)
import IOKit
import IOKit.usb
#endif

/// A USB device matched against the dive-cable allowlist.
struct UsbFtdiDevice: Equatable {
    let vendorId: UInt16
    let productId: UInt16
    /// IOKit `locationID`, which identifies the physical port. Used to reopen
    /// the same device later, since two identical cables share a product ID.
    let locationId: UInt32
    /// The USB product-name descriptor, empty when the device reports none.
    let productName: String

    /// The dive-cable label from the allowlist.
    var cableName: String {
        UsbFtdiDeviceEnumerator.cableName(vendorId: vendorId, productId: productId)
            ?? "USB device"
    }

    /// What to show in logs and probe messages: the device's own name when it
    /// has one, our label otherwise.
    var displayName: String {
        productName.isEmpty ? cableName : productName
    }
}

/// Finds dive-computer download cables that the operating system has not
/// exposed as serial ports.
///
/// The Aeris/Oceanic cable is an FTDI chip with a custom product ID that
/// Apple's AppleUSBFTDI driver does not claim, so macOS creates no
/// `/dev/cu.usbserial-*` node for it and `SerialPortEnumerator` finds nothing
/// (issue #732). The device is still present in the IOKit registry, and
/// because nothing has claimed it, it can be opened directly.
///
/// The classification is pure so it can be unit-tested standalone; only
/// `enumerateDiveCables()` touches IOKit, and only on macOS. This mirrors
/// `SerialPortEnumerator`.
enum UsbFtdiDeviceEnumerator {
    /// USB identifiers of dive-computer download cables driven over raw USB.
    ///
    /// Fail-closed by design. This path opens a device and writes dive-computer
    /// handshake bytes to it, so it must never match a device that merely
    /// happens to use an FTDI chip.
    ///
    /// Stock FTDI product IDs (0x6001, 0x6010, 0x6011, 0x6014, 0x6015) are
    /// deliberately absent: macOS claims those and publishes them as serial
    /// ports, so they belong to `SerialPortEnumerator`. Only the reprogrammed
    /// dive-vendor IDs are listed. macOS currently claims 0xF680 and 0x87D0
    /// too, so in practice only 0xF460 reaches this path today; the other two
    /// are here because Apple's list has changed between OS releases before.
    static let knownCables: [(vendorId: UInt16, productId: UInt16, cable: String)] = [
        // Linux names this FTDI_OCEANIC_PID in drivers/usb/serial/ftdi_sio_ids.h.
        (0x0403, 0xF460, "Oceanic / Aeris / Sherwood / Hollis cable"),
        (0x0403, 0xF680, "Suunto Sports Instrument cable"),
        (0x0403, 0x87D0, "Cressi Leonardo cable"),
    ]

    /// The cable label for a USB identifier pair, or nil if it is not one of
    /// ours.
    static func cableName(vendorId: UInt16, productId: UInt16) -> String? {
        knownCables.first {
            $0.vendorId == vendorId && $0.productId == productId
        }?.cable
    }

    /// True if this identifier pair names a dive-computer download cable.
    static func isKnownDiveCable(vendorId: UInt16, productId: UInt16) -> Bool {
        cableName(vendorId: vendorId, productId: productId) != nil
    }

    #if os(macOS)
    /// Lists attached dive cables, reporting every USB device considered
    /// through `log`.
    ///
    /// The reporting is not incidental. Nobody working on this has the
    /// hardware, so a user's debug log has to distinguish "the cable is not
    /// enumerating at all" from "it enumerated but the allowlist rejected it"
    /// without another round trip.
    ///
    /// Logging goes through an injected closure rather than `NativeLogger`
    /// because `NativeLogger` holds a Pigeon `DiveComputerFlutterApi`, which
    /// only exists inside the CocoaPods build. Depending on it here would make
    /// this file impossible to compile standalone, and standalone compilation
    /// is the whole reason the allowlist lives in its own file.
    ///
    /// IOKit class names a USB device may be registered under.
    ///
    /// Both are queried and the results merged, rather than picking one. The
    /// modern stack registers devices as `IOUSBHostDevice`, while the legacy
    /// `IOUSBDevice` name is what libusb's Darwin backend has always matched
    /// on and is kept working for compatibility. Which one a given macOS
    /// release answers to could not be confirmed on the development machine,
    /// because it has no USB peripherals attached at all, so asking for both
    /// costs one extra registry walk and removes the guess entirely.
    private static let usbDeviceClassNames = ["IOUSBHostDevice", "IOUSBDevice"]

    /// Lists attached dive cables, reporting every USB device considered
    /// through `log`.
    ///
    /// The reporting is not incidental. Nobody working on this has the
    /// hardware, so a user's debug log has to distinguish "the cable is not
    /// enumerating at all" from "it enumerated but the allowlist rejected it"
    /// without another round trip.
    ///
    /// Logging goes through an injected closure rather than `NativeLogger`
    /// because `NativeLogger` holds a Pigeon `DiveComputerFlutterApi`, which
    /// only exists inside the CocoaPods build. Depending on it here would make
    /// this file impossible to compile standalone, and standalone compilation
    /// is the whole reason the allowlist lives in its own file.
    static func enumerateDiveCables(log: ((String) -> Void)? = nil) -> [UsbFtdiDevice] {
        var devices: [UsbFtdiDevice] = []
        // Keyed by location, which names the physical port, so a device seen
        // under both class names is only reported and probed once.
        var seenLocations = Set<UInt32>()
        var considered = 0

        for className in usbDeviceClassNames {
            guard let matching = IOServiceMatching(className) else { continue }

            var iterator: io_iterator_t = 0
            let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
            guard kr == KERN_SUCCESS else {
                log?("IOServiceGetMatchingServices(\(className)) failed: \(kr)")
                continue
            }
            defer { IOObjectRelease(iterator) }

            var service = IOIteratorNext(iterator)
            while service != 0 {
                defer {
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }

                guard
                    let vendorId = numberProperty(service, "idVendor").map({
                        UInt16($0 & 0xFFFF)
                    }),
                    let productId = numberProperty(service, "idProduct").map({
                        UInt16($0 & 0xFFFF)
                    })
                else { continue }

                let locationId = UInt32(numberProperty(service, "locationID") ?? 0)
                guard seenLocations.insert(locationId).inserted else { continue }
                considered += 1

                let productName = stringProperty(service, "USB Product Name") ?? ""
                let idText = String(format: "0x%04X:0x%04X", vendorId, productId)
                if isKnownDiveCable(vendorId: vendorId, productId: productId) {
                    log?("USB \(idText) '\(productName)' matched the dive-cable allowlist")
                    devices.append(
                        UsbFtdiDevice(
                            vendorId: vendorId, productId: productId,
                            locationId: locationId, productName: productName))
                } else {
                    log?("USB \(idText) '\(productName)' is not a known dive cable")
                }
            }
        }

        // Always emitted, so a log with no per-device lines still says whether
        // that means "no USB devices at all" or "the walk itself failed".
        log?("USB enumeration considered \(considered) device(s), "
            + "matched \(devices.count) dive cable(s)")
        return devices
    }

    private static func numberProperty(_ service: io_service_t, _ key: String) -> UInt64? {
        guard
            let value = IORegistryEntryCreateCFProperty(
                service, key as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? NSNumber
        else { return nil }
        return value.uint64Value
    }

    private static func stringProperty(_ service: io_service_t, _ key: String) -> String? {
        IORegistryEntryCreateCFProperty(
            service, key as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String
    }
    #else
    /// Raw USB host access is not available on iOS.
    static func enumerateDiveCables(log: ((String) -> Void)? = nil) -> [UsbFtdiDevice] { [] }
    #endif
}
