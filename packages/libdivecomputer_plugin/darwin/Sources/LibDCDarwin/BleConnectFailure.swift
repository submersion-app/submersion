import CoreBluetooth
import Foundation

/// Why a BLE connect/discovery attempt was abandoned, and whether another
/// attempt could plausibly do better.
///
/// Apple platforms expose no API for deleting a pairing record, so when the OS
/// and the dive computer disagree about their shared keys the app cannot repair
/// it the way the Android backend does (GATT status 5 -> removeBond -> retry,
/// see BleIoStream.kt). All it can do is recognise the condition and tell the
/// user which switch to throw, which is how the reporter in issue #865 fixed it
/// -- by forgetting the computer in the iPad's Bluetooth settings.
enum BleConnectFailure: Equatable {
    /// The OS holds pairing information the dive computer no longer honours,
    /// typically after the computer was factory reset or paired with another
    /// phone. CoreBluetooth refuses the connection outright.
    case stalePairing

    /// The link came up but the peer never answered service discovery. On a
    /// healthy connection the first callback lands in milliseconds; a silent
    /// stall is the shape a stale bond takes on macOS, where CoreBluetooth
    /// waits forever for an encryption upgrade the peer will not complete
    /// rather than reporting `peerRemovedPairingInformation` the way iOS does.
    case discoveryStalled

    /// Anything else: out of range, powered off, or dropped out of its BLE menu.
    case other

    /// Codes that mean the local pairing record and the peer's disagree.
    private static let stalePairingCodes: Set<Int> = [
        CBError.Code.peerRemovedPairingInformation.rawValue,
        CBError.Code.encryptionTimedOut.rawValue,
    ]

    /// Whether retrying inside the app is pointless.
    ///
    /// Only the user can clear a pairing record on Apple platforms, so a second
    /// attempt fails exactly as the first did -- the iPad log in #865 shows the
    /// retry returning the same error 500 ms later. Stopping early replaces
    /// that dead time with the instruction that actually resolves it.
    var isTerminal: Bool { self == .stalePairing }

    /// The error code handed to the Dart layer, which switches on it in
    /// `DownloadStepWidget._localizedError` to choose the advice to show.
    var errorCode: String {
        switch self {
        case .stalePairing:
            return "stale_pairing"
        case .discoveryStalled:
            return "discovery_stalled"
        case .other:
            return "connect_failed"
        }
    }

    /// Classify the error CoreBluetooth reported to `didFailToConnect`.
    ///
    /// The domain check matters: the pairing codes are small integers that
    /// collide with common POSIX errnos, and sending a user to Bluetooth
    /// settings over an unrelated EFAULT would be a pure red herring.
    static func fromConnectError(_ error: Error?) -> BleConnectFailure {
        guard let error else { return .other }
        let nsError = error as NSError
        guard nsError.domain == CBErrorDomain else { return .other }
        return stalePairingCodes.contains(nsError.code) ? .stalePairing : .other
    }
}
