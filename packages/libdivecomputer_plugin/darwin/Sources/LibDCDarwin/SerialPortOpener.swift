import Foundation

/// Why a serial callout device could not be opened.
///
/// Carries the raw `errno` alongside an actionable description. The errno is
/// kept because the numeric value is what makes a bug report diagnosable when
/// the prose turns out to be wrong.
struct SerialOpenFailure: Equatable {
    let errnoValue: Int32
    let reason: String
}

/// Result of opening a serial callout device: an owned file descriptor the
/// caller must close, or a failure describing why the open was refused.
enum SerialOpenResult {
    case success(Int32)
    case failure(SerialOpenFailure)
}

/// Translates an `errno` from `open(2)` on a `/dev/cu.*` device into text a
/// user can act on.
///
/// The EPERM case is the reason this function exists. On macOS the App Sandbox
/// splits serial access in two: IOKit enumeration
/// (`SerialPortEnumerator.enumerateUsbSerialPaths`) is always permitted, but
/// `open(2)` on the resulting device node is denied with EPERM unless the app
/// declares `com.apple.security.device.serial`. The app therefore reports the
/// exact port path it just discovered and then fails to open it, which reads as
/// a cable or driver fault. Issue #291 (Suunto Vyper Air over an FTDI cable)
/// spent two months being diagnosed as a driver problem for exactly this
/// reason, because the old code discarded errno and logged only "Failed to open
/// serial port".
func serialOpenFailureReason(errnoValue: Int32) -> String {
    let systemText = String(cString: strerror(errnoValue))
    switch errnoValue {
    case EPERM:
        return "\(systemText): macOS denied access to the serial port. This "
            + "build is missing the serial-port entitlement "
            + "(com.apple.security.device.serial)."
    case EACCES:
        return "\(systemText): the current user does not have permission to "
            + "open this serial device."
    case EBUSY:
        return "\(systemText): the port is already open in another application."
    case ENOENT:
        return "\(systemText): the port no longer exists. Was the cable "
            + "unplugged?"
    default:
        return systemText
    }
}

/// Opens a serial callout device for dive-computer I/O.
///
/// Uses the flags libdivecomputer's own POSIX serial backend uses: `O_NOCTTY`
/// so the port never becomes the controlling terminal, and `O_NONBLOCK` so the
/// open returns immediately instead of waiting on carrier detect. The caller
/// switches the descriptor back to blocking mode after configuring the line.
func openSerialPort(path: String) -> SerialOpenResult {
    let fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
    guard fd >= 0 else {
        // Capture errno before anything else can perturb it.
        let code = errno
        return .failure(
            SerialOpenFailure(
                errnoValue: code, reason: serialOpenFailureReason(errnoValue: code)))
    }
    return .success(fd)
}
