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

    /// The chosen write/notify pair within the winning service.
    struct Selection: Equatable {
        let serviceUUID: CBUUID
        let writeUUID: CBUUID
        let notifyUUID: CBUUID
        let score: Int
    }

    static let preferredServiceUUIDs: Set<CBUUID> = [
        CBUUID(string: "CB3C4555-D670-4670-BC20-B61DBC851E9A"),
    ]

    static let preferredWriteUUIDs: Set<CBUUID> = [
        // Pelagic gen1 (Aqualung i330R / Apeks DSX) command characteristic.
        CBUUID(string: "6606AB42-89D5-4A00-A8CE-4EB5E1414EE0"),
        // Halcyon Symbios Tx: the app sends commands here. Its Rx counterpart
        // (00000101) also advertises write and ties on raw score, so without
        // this bias the scorer writes to Rx and the device never answers
        // (issue #288).
        CBUUID(string: "00000201-8C3B-4F2C-A59E-8C08224F3253"),
    ]

    static let preferredNotifyUUIDs: Set<CBUUID> = [
        CBUUID(string: "A60B8E5C-B267-44D7-9764-837CAF96489E"),
        // Halcyon Symbios Rx: the device sends replies here via indications.
        CBUUID(string: "00000101-8C3B-4F2C-A59E-8C08224F3253"),
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
    /// Ties (equal scores) resolve to the first characteristic in discovery
    /// order, matching CoreBluetooth handle ordering.
    static func select(services: [Service]) -> Selection? {
        var best: Selection?
        for service in services {
            var bestWrite: (uuid: CBUUID, score: Int)?
            var bestNotify: (uuid: CBUUID, score: Int)?

            for characteristic in service.characteristics {
                if let score = writeScore(characteristic),
                    bestWrite == nil || score > bestWrite!.score {
                    bestWrite = (characteristic.uuid, score)
                }
                if let score = notifyScore(characteristic),
                    bestNotify == nil || score > bestNotify!.score {
                    bestNotify = (characteristic.uuid, score)
                }
            }

            guard let write = bestWrite, let notify = bestNotify else { continue }

            var serviceScore = write.score + notify.score
            if preferredServiceUUIDs.contains(service.uuid) { serviceScore += 1000 }

            if let existing = best, existing.score >= serviceScore { continue }
            best = Selection(
                serviceUUID: service.uuid,
                writeUUID: write.uuid,
                notifyUUID: notify.uuid,
                score: serviceScore
            )
        }
        return best
    }
}
