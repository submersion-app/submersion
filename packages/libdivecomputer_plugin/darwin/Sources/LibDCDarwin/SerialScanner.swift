import Foundation
#if os(macOS)
import IOKit
import IOKit.serial
#endif

/// Enumerates serial ports on macOS and matches them against libdivecomputer
/// descriptors. On iOS, serial/USB device enumeration is not supported.
class SerialScanner {
    var onDeviceDiscovered: ((DiscoveredDevice) -> Void)?
    var onComplete: (() -> Void)?

    func start() {
        #if os(macOS)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.enumerateSerialPorts()
            DispatchQueue.main.async {
                self?.onComplete?()
            }
        }
        #else
        // iOS does not support serial/USB device enumeration.
        DispatchQueue.main.async { [weak self] in
            self?.onComplete?()
        }
        #endif
    }

    func stop() {
        // Serial enumeration is a one-shot scan; nothing to cancel.
    }

    #if os(macOS)
    private func enumerateSerialPorts() {
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
        guard kr == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

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

            // Use the last path component as the device name for matching.
            let deviceName = (pathCF as NSString).lastPathComponent

            var info = libdc_descriptor_info_t()
            let matched = deviceName.withCString { namePtr -> Int32 in
                libdc_descriptor_match(namePtr, UInt32(LIBDC_TRANSPORT_SERIAL), &info)
            }

            if matched == 1 {
                let device = DiscoveredDevice(
                    vendor: String(cString: info.vendor),
                    product: String(cString: info.product),
                    model: Int64(info.model),
                    address: pathCF,
                    name: "\(String(cString: info.vendor)) \(String(cString: info.product))",
                    transport: .serial
                )

                DispatchQueue.main.async { [weak self] in
                    self?.onDeviceDiscovered?(device)
                }
            }
        }
    }
    #endif
}
