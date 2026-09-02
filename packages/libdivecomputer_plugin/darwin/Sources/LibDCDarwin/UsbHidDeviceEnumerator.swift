import Foundation
#if os(macOS)
import IOKit
import IOKit.hid
#endif

/// A USB HID device that a dive computer descriptor has claimed.
struct UsbHidDevice: Equatable {
    let vendorId: UInt16
    let productId: UInt16
    /// IOKit registry entry id, which names this exact service for the life of
    /// the connection. The stream reopens the device from it rather than
    /// carrying an `IOHIDDevice` across the enumerate/open boundary, so nothing
    /// here holds an IOKit object alive between the two.
    let registryEntryId: UInt64
    /// The HID product string, empty when the device reports none.
    let productName: String
    /// The largest input report the device publishes, 0 when it publishes
    /// none; the stream treats that as "fall back to the caller's size".
    ///
    /// There is no output counterpart because IOHIDDeviceSetReport takes the
    /// length it is given, exactly as hidapi's macOS backend does. Windows is
    /// the platform that has to pad a write out to a fixed report length, and
    /// it reads that length from HidP_GetCaps at open time.
    let maxInputReportSize: Int

    /// What to show in logs and probe messages: the device's own name when it
    /// has one, its identifiers otherwise.
    var displayName: String {
        if !productName.isEmpty { return productName }
        return String(format: "HID 0x%04X:0x%04X", vendorId, productId)
    }
}

/// Finds attached USB HID dive computers.
///
/// Unlike `UsbFtdiDeviceEnumerator`, there is no allowlist here. Which HID
/// device belongs to which dive computer is libdivecomputer's knowledge, held
/// in the vendor and product id tables inside `dc_filter_uwatec` and
/// `dc_filter_suunto` and reachable through `libdc_usbhid_match`. The caller
/// passes that question in as `isMatch`, which keeps this file free of a
/// second copy of those tables and free of the wrapper header, so it still
/// compiles standalone.
enum UsbHidDeviceEnumerator {
    #if os(macOS)
    /// Lists attached HID devices the caller's predicate accepts, reporting
    /// every device considered through `log`.
    ///
    /// The reporting is not incidental. Nobody working on this has the
    /// hardware, so a user's debug log has to distinguish "the computer is not
    /// enumerating at all" from "it enumerated but did not match the selected
    /// model" without another round trip.
    ///
    /// Logging goes through an injected closure rather than `NativeLogger`
    /// because `NativeLogger` holds a Pigeon `DiveComputerFlutterApi`, which
    /// only exists inside the CocoaPods build.
    static func enumerateMatching(
        log: ((String) -> Void)? = nil,
        isMatch: (UInt16, UInt16) -> Bool
    ) -> [UsbHidDevice] {
        var devices: [UsbHidDevice] = []
        var considered = 0

        guard let matching = IOServiceMatching(kIOHIDDeviceKey) else {
            log?("IOServiceMatching(\(kIOHIDDeviceKey)) returned nothing")
            return []
        }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            log?("IOServiceGetMatchingServices(\(kIOHIDDeviceKey)) failed: \(kr)")
            return []
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard
                let vendorId = numberProperty(service, kIOHIDVendorIDKey).map({
                    UInt16($0 & 0xFFFF)
                }),
                let productId = numberProperty(service, kIOHIDProductIDKey).map({
                    UInt16($0 & 0xFFFF)
                })
            else { continue }

            var registryEntryId: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(service, &registryEntryId) == KERN_SUCCESS
            else { continue }

            considered += 1
            let productName = stringProperty(service, kIOHIDProductKey) ?? ""
            let idText = String(format: "0x%04X:0x%04X", vendorId, productId)

            guard isMatch(vendorId, productId) else {
                log?("HID \(idText) '\(productName)' is not this dive computer")
                continue
            }

            log?("HID \(idText) '\(productName)' matched the selected model")
            devices.append(
                UsbHidDevice(
                    vendorId: vendorId,
                    productId: productId,
                    registryEntryId: registryEntryId,
                    productName: productName,
                    maxInputReportSize: Int(
                        numberProperty(service, kIOHIDMaxInputReportSizeKey) ?? 0)))
        }

        // Always emitted, so a log with no per-device lines still says whether
        // that means "no HID devices at all" or "the walk itself failed".
        log?("HID enumeration considered \(considered) device(s), "
            + "matched \(devices.count)")
        return devices
    }

    /// Reopens the IOKit service this device was enumerated from.
    ///
    /// Returns nil when the device has been unplugged since, which is the one
    /// case worth distinguishing from an open failure.
    static func makeHidDevice(for device: UsbHidDevice) -> IOHIDDevice? {
        let matching = IORegistryEntryIDMatching(device.registryEntryId)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return IOHIDDeviceCreate(kCFAllocatorDefault, service)
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
    /// iOS has no USB host role, so no HID device is ever reachable.
    static func enumerateMatching(
        log: ((String) -> Void)? = nil,
        isMatch: (UInt16, UInt16) -> Bool
    ) -> [UsbHidDevice] { [] }
    #endif
}
