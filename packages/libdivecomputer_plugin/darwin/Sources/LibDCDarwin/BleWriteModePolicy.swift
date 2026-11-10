import Foundation

/// Picks the write mode a BLE stream starts with.
///
/// Most write characteristics that offer both acknowledged writes and writes
/// without response start on the acknowledged write, the safer choice for a
/// computer that drops unacknowledged writes. BleIoStream flips the mode after
/// the first read timeout, so a wrong start costs one retry, not the download.
///
/// Two characteristics start without response instead:
///
///  - Pelagic gen 1 TX, which needs it.
///  - Shearwater (issue #4332). Every block of a dive download is one short
///    request followed by the reply, and an acknowledged write holds the
///    request until the computer's ATT write response arrives, up to a
///    connection interval later, on every block. The Android transport has
///    always sent these requests without response. Each request fits in one
///    20-byte frame, and a lost one surfaces as a read timeout, which the
///    flip above and the Shearwater driver's per-dive retry both recover.
///
/// Pure string logic so it is unit-tested standalone via run_native_tests.sh;
/// pass `CBUUID.uuidString`, which is upper case for 128-bit UUIDs.
enum BleWriteModePolicy {
    static let pelagicGen1Tx = "6606AB42-89D5-4A00-A8CE-4EB5E1414EE0"
    /// The single write/notify characteristic of the Shearwater BLE service
    /// (FE25C237-0ECE-443C-B0AA-E02033E7029D).
    static let shearwaterData = "27B7570B-359E-45A3-91BB-CF7E70049BD2"

    static func prefersWithoutResponse(
        characteristicUuid: String,
        supportsWrite: Bool,
        supportsWriteWithoutResponse: Bool
    ) -> Bool {
        let uuid = characteristicUuid.uppercased()
        if uuid == pelagicGen1Tx {
            return true
        }
        if uuid == shearwaterData {
            return supportsWriteWithoutResponse
        }
        return supportsWriteWithoutResponse && !supportsWrite
    }
}
