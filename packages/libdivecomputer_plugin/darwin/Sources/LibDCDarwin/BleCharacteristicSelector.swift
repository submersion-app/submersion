import CoreBluetooth
import Foundation

/// Picks the write and notify/indicate characteristics for a BLE dive
/// computer from its discovered services.
///
/// Kept dependency-free (CoreBluetooth + Foundation only, no Flutter modules)
/// so it can be compiled and unit-tested standalone via run_native_tests.sh,
/// the same way PacketReadBuffer is. BleIoStream adapts its live
/// CBCharacteristic objects into the value types below and delegates here, so
/// the scoring has a single source of truth that the tests exercise directly.
///
/// Scoring rationale: write and notify candidates are scored independently so
/// devices that split commands and responses across two characteristics pick
/// the correct pair instead of collapsing onto one. Higher raw scores prefer
/// write-without-response and notify over indicate. A preferred-UUID match adds
/// a large bias (+1000) so an explicit per-device mapping always wins over the
/// generic property heuristic and over handle-order tie-breaking.
enum BleCharacteristicSelector {
    /// One characteristic's identity and capabilities, decoupled from
    /// CBCharacteristic (which cannot be constructed in unit tests).
    struct Characteristic {
        let uuid: CBUUID
        let properties: CBCharacteristicProperties
    }

    /// A discovered service and its characteristics.
    struct Service {
        let uuid: CBUUID
        let characteristics: [Characteristic]
    }

    /// The chosen write/notify pair, identified by position in the input.
    ///
    /// Indices (rather than UUIDs) are returned so the caller resolves the
    /// exact live characteristics: BLE peripherals may legally expose multiple
    /// service instances with the same UUID, or repeated characteristic UUIDs,
    /// which UUID-only matching cannot disambiguate.
    struct Selection: Equatable {
        let serviceIndex: Int
        let writeIndex: Int
        let notifyIndex: Int
        let score: Int
    }

    static let preferredServiceUUIDs: Set<CBUUID> = [
        CBUUID(string: "CB3C4555-D670-4670-BC20-B61DBC851E9A"),
    ]

    static let preferredWriteUUIDs: Set<CBUUID> = [
        // Pelagic gen1 (Aqualung i330R / Apeks DSX) command characteristic.
        CBUUID(string: "6606AB42-89D5-4A00-A8CE-4EB5E1414EE0"),
        // Halcyon Symbios: the app writes commands to the device's Rx endpoint
        // (00000101). Both Symbios characteristics advertise read+write+indicate
        // and tie on raw score, so a preferred UUID is required to tell them
        // apart. The Tx/Rx names are device-centric: Subsurface's qt-ble.cpp
        // writes commands to 00000101 ("Rx") and reads replies from 00000201
        // ("Tx"). PR #356 mapped these backwards -- it wrote to 00000201, which
        // the device accepts at the ATT layer but never answers -- so downloads
        // timed out with result=-7 (issue #288).
        CBUUID(string: "00000101-8C3B-4F2C-A59E-8C08224F3253"),
    ]

    static let preferredNotifyUUIDs: Set<CBUUID> = [
        CBUUID(string: "A60B8E5C-B267-44D7-9764-837CAF96489E"),
        // Halcyon Symbios: the device transmits replies on its Tx endpoint
        // (00000201) via indications; the app writes commands on 00000101 (see
        // preferredWriteUUIDs and issue #288).
        CBUUID(string: "00000201-8C3B-4F2C-A59E-8C08224F3253"),
    ]

    /// Score a write candidate, or nil if the characteristic cannot be written.
    static func writeScore(_ characteristic: Characteristic) -> Int? {
        let properties = characteristic.properties
        guard properties.contains(.write) || properties.contains(.writeWithoutResponse) else {
            return nil
        }
        var score = 0
        if properties.contains(.writeWithoutResponse) { score += 4 }
        if properties.contains(.write) { score += 2 }
        if preferredWriteUUIDs.contains(characteristic.uuid) { score += 1000 }
        return score
    }

    /// Score a notify candidate, or nil if the characteristic cannot notify.
    static func notifyScore(_ characteristic: Characteristic) -> Int? {
        let properties = characteristic.properties
        guard properties.contains(.notify) || properties.contains(.indicate) else {
            return nil
        }
        var score = 0
        if properties.contains(.notify) { score += 4 }
        if properties.contains(.indicate) { score += 2 }
        if preferredNotifyUUIDs.contains(characteristic.uuid) { score += 1000 }
        return score
    }

    /// Choose the best write/notify pair across all services, or nil if no
    /// service has both a writable and a notify/indicate characteristic.
    ///
    /// Ties (equal scores) resolve to the earliest candidate in the input
    /// order the caller supplies. BleIoStream builds that order from BLE
    /// discovery (service-callback completion order, plus the characteristic
    /// order CoreBluetooth returns), which is not guaranteed to match GATT
    /// handle order -- so device-specific cases that must not depend on
    /// ordering use a preferred UUID rather than relying on the tie-break.
    static func select(services: [Service]) -> Selection? {
        var best: Selection?
        for (serviceIndex, service) in services.enumerated() {
            var bestWrite: (index: Int, score: Int)?
            var bestNotify: (index: Int, score: Int)?

            for (index, characteristic) in service.characteristics.enumerated() {
                if let score = writeScore(characteristic),
                    bestWrite == nil || score > bestWrite!.score {
                    bestWrite = (index, score)
                }
                if let score = notifyScore(characteristic),
                    bestNotify == nil || score > bestNotify!.score {
                    bestNotify = (index, score)
                }
            }

            guard let write = bestWrite, let notify = bestNotify else { continue }

            var serviceScore = write.score + notify.score
            if preferredServiceUUIDs.contains(service.uuid) { serviceScore += 1000 }

            if let existing = best, existing.score >= serviceScore { continue }
            best = Selection(
                serviceIndex: serviceIndex,
                writeIndex: write.index,
                notifyIndex: notify.index,
                score: serviceScore
            )
        }
        return best
    }
}
