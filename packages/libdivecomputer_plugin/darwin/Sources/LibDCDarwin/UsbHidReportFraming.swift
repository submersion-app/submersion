import Foundation

/// Pure USB HID report framing. No I/O, so it is unit-testable on its own.
///
/// libdivecomputer's transport contract puts the HID report id in the first
/// byte of the write buffer (src/usbhid.c:757-763). IOHIDDeviceSetReport takes
/// that id as a separate argument, so the buffer has to be split before it can
/// be handed to IOKit.
///
/// Only the darwin backend needs this split. The Windows and Linux backends
/// write the buffer through unchanged, because both HID write APIs
/// (WriteFile on a HID device, write(2) on a hidraw node) define the first
/// byte of the buffer as the report number themselves.
enum UsbHidReportFraming {
    /// A HID output report ready for IOHIDDeviceSetReport.
    struct OutgoingReport: Equatable {
        let reportId: UInt8
        let payload: [UInt8]
    }

    /// Splits a libdivecomputer write buffer into its report id and payload.
    ///
    /// A report id of zero means the device does not use numbered reports, so
    /// the id is not part of the wire format and is dropped. A non-zero id
    /// stays at the front of the payload: Apple requires the id byte to lead
    /// the report data for numbered reports, and hidapi's macOS backend
    /// (mac/hid.c, set_report) does the same.
    ///
    /// Returns nil only for an empty buffer, which carries no report id at all.
    /// libdivecomputer refuses a zero-length write before it reaches the
    /// transport, so this is defence against a future caller rather than a
    /// path taken today.
    static func outgoingReport(from buffer: [UInt8]) -> OutgoingReport? {
        guard let reportId = buffer.first else { return nil }
        let payload = reportId == 0 ? Array(buffer.dropFirst()) : buffer
        return OutgoingReport(reportId: reportId, payload: payload)
    }

    /// The buffer size to use for one report.
    ///
    /// Taken from the device when it publishes a usable maximum, so hardware
    /// with reports wider than the Uwatec family's 64 bytes is not truncated.
    /// A device that publishes nothing, zero, or a negative size falls back to
    /// the caller's value.
    static func reportSize(deviceMaximum: Int?, fallback: Int) -> Int {
        guard let maximum = deviceMaximum, maximum > 0 else { return fallback }
        return max(maximum, fallback)
    }
}
