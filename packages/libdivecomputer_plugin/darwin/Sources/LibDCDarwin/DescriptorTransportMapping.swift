import Foundation

/// Turns libdivecomputer's transport bitmask into the transfer modes the app
/// offers. Pure, so it is unit-testable on its own.
///
/// This mapping is not a formality. The USB tab of the dive computer wizard is
/// a static catalog picker driven entirely by it, so a bit dropped here makes a
/// supported computer unselectable with no error to explain why. That is what
/// issue #1271 was: the Scubapro G2 TEK is a USB HID device, the USB HID bit
/// was dropped, and the model simply was not in the list.
enum DescriptorTransportMapping {
    /// libdivecomputer transport bits, mirroring dc_transport_t. Declared here
    /// rather than taken from libdc_wrapper.h so this file compiles standalone,
    /// outside the CocoaPods build.
    ///
    /// Two tests keep that third copy of the numbers honest, one per link in
    /// the chain: `DescriptorTransportMappingTests` pins these values, and
    /// `test_usbhid_descriptor_match.c` pins the `LIBDC_TRANSPORT_*` constants
    /// they mirror against libdivecomputer's own `dc_transport_t`.
    struct Transport: OptionSet {
        let rawValue: UInt32
        static let serial = Transport(rawValue: 1 << 0)
        static let usb = Transport(rawValue: 1 << 1)
        static let usbhid = Transport(rawValue: 1 << 2)
        static let irda = Transport(rawValue: 1 << 3)
        static let bluetooth = Transport(rawValue: 1 << 4)
        static let ble = Transport(rawValue: 1 << 5)
    }

    /// The transfer modes the app offers, in the order the picker shows them.
    enum Mode: Equatable {
        case ble
        case usb
        case serial
        case infrared
    }

    /// Whether this platform has a USB HID byte pipe behind it.
    ///
    /// macOS has `UsbHidIoStream`; iOS has no USB host role at all, so a HID
    /// device is never reachable there. Reporting a transport with nothing
    /// behind it is what sent HID-only devices into the serial path's "No USB
    /// serial ports found" dead end in issue #143, so the answer has to be the
    /// truth rather than a convenience.
    static var supportsUsbHid: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// Maps a descriptor's transport bitmask to the modes to advertise.
    ///
    /// USB HID is reported as `.usb`, not as a mode of its own: the app has one
    /// USB transfer mode, which is the cable the user is holding, and the
    /// download path works out from the descriptor whether that cable speaks
    /// HID or serial. Bluetooth Classic is deliberately absent, as it was
    /// before: nothing here implements it.
    static func modes(
        for transports: Transport,
        supportsUsbHid: Bool = DescriptorTransportMapping.supportsUsbHid
    ) -> [Mode] {
        var modes: [Mode] = []
        if transports.contains(.ble) {
            modes.append(.ble)
        }
        if transports.contains(.usb)
            || (supportsUsbHid && transports.contains(.usbhid)) {
            modes.append(.usb)
        }
        if transports.contains(.serial) {
            modes.append(.serial)
        }
        if transports.contains(.irda) {
            modes.append(.infrared)
        }
        return modes
    }
}
