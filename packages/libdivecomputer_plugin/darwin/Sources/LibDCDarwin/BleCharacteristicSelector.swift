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

    /// The credit characteristics of the selected service, as positions in the
    /// same input the write/notify indices address.
    struct TerminalIoCredits: Equatable {
        /// Credits RX: the client writes its credit grants here.
        let writeIndex: Int
        /// Credits TX: the server indicates its own credits here. The client
        /// must subscribe even though the payload is not consumed -- a Telit
        /// module keeps the UART bridge closed until it is. On the u-blox
        /// serial service both roles are the same characteristic.
        let notifyIndex: Int
        /// Whether a failed handshake should fail the connection.
        ///
        /// True for Telit, whose bridge carries nothing at all until credits
        /// are granted. False for u-blox, where flow control is optional: the
        /// OSTC nano downloads today with no handshake whatsoever (#280,
        /// #394), so a rejected grant there falls back to running without
        /// credits rather than breaking a device that already works.
        let required: Bool
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
        /// Non-nil only when the selected service exposes the full 4-characteristic
        /// Telit layout, in which case the caller must run the credit handshake.
        let terminalIoCredits: TerminalIoCredits?
    }

    // MARK: - Telit/Stollmann Terminal I/O (TIO)
    //
    // Heinrichs Weikamp computers built on the Telit (formerly Stollmann)
    // BlueMod+SR module -- the OSTC 2/3/4/Sport/cR/Plus family -- expose a
    // serial bridge behind service 0xFEFB that uses credit-based flow control
    // (Telit "TIO Implementation Guide" r04). The bridge does not carry data
    // until the client subscribes to UART Credits TX and grants initial
    // credits on UART Credits RX, so a plain write/notify pair is not enough:
    // the first command write fails and libdivecomputer reports "Failed to
    // send the command" (issue #923, OSTC4 on Windows).
    //
    // Subsurface implements the same handshake in core/qt-ble.cpp, applying it
    // to every Heinrichs Weikamp device across two module families, and both
    // are handled here:
    //
    //  - Telit (service 0xFEFB, four characteristics). Credits are mandatory:
    //    the bridge carries nothing until they are granted.
    //  - u-blox serial service (0x...d701, two characteristics: one carries
    //    data in both directions, one carries credits in both directions).
    //    Flow control there is optional -- the OSTC nano downloads today with
    //    no handshake at all (#280, #394) -- so a rejected grant falls back to
    //    running without credits instead of failing a working device. See the
    //    `required` flag on TerminalIoCredits.
    //
    // The credits the module indicates back on Credits TX -- its budget for
    // what the client may send -- are subscribed to but not consumed or
    // accounted for, matching Subsurface. Commands are a handful of bytes sent
    // rarely, so that budget is never the constraint in practice; the
    // subscription exists because the module requires it before opening the
    // bridge at all.

    /// 16-bit service 0xFEFB in its 128-bit form.
    static let terminalIoServiceUUID = CBUUID(
        string: "0000FEFB-0000-1000-8000-00805F9B34FB")
    /// UART Data RX: the client writes commands here (write-without-response).
    static let terminalIoDataRxUUID = CBUUID(
        string: "00000001-0000-1000-8000-008025000000")
    /// UART Data TX: the server notifies replies here.
    static let terminalIoDataTxUUID = CBUUID(
        string: "00000002-0000-1000-8000-008025000000")
    /// UART Credits RX: the client writes credit grants here (with response).
    static let terminalIoCreditsRxUUID = CBUUID(
        string: "00000003-0000-1000-8000-008025000000")
    /// UART Credits TX: the server indicates its credits here.
    static let terminalIoCreditsTxUUID = CBUUID(
        string: "00000004-0000-1000-8000-008025000000")

    /// u-blox serial service, the other Heinrichs Weikamp module family.
    static let ubloxServiceUUID = CBUUID(
        string: "2456E1B9-26E2-8F83-E744-F34F01E9D701")
    /// u-blox FIFO: one characteristic carries data in both directions.
    static let ubloxDataUUID = CBUUID(
        string: "2456E1B9-26E2-8F83-E744-F34F01E9D703")
    /// u-blox credits: one characteristic carries credits in both directions.
    static let ubloxCreditsUUID = CBUUID(
        string: "2456E1B9-26E2-8F83-E744-F34F01E9D704")

    static let preferredServiceUUIDs: Set<CBUUID> = [
        CBUUID(string: "CB3C4555-D670-4670-BC20-B61DBC851E9A"),
        // Telit Terminal I/O. Biased so the serial bridge always beats the
        // Stollmann vendor service the same devices also advertise, whose
        // characteristics can tie on raw score and win on discovery order.
        terminalIoServiceUUID,
        ubloxServiceUUID,
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
        // Telit UART Data RX. Raw scoring already prefers it over UART Credits
        // RX (write-without-response +4 beats write +2), but commands written
        // to the credits characteristic would be silently swallowed, so the
        // pair is pinned rather than left to the heuristic.
        terminalIoDataRxUUID,
        // u-blox FIFO, pinned over the credits characteristic for the same
        // reason: both are writable and would otherwise tie on raw score.
        ubloxDataUUID,
    ]

    static let preferredNotifyUUIDs: Set<CBUUID> = [
        CBUUID(string: "A60B8E5C-B267-44D7-9764-837CAF96489E"),
        // Halcyon Symbios: the device transmits replies on its Tx endpoint
        // (00000201) via indications; the app writes commands on 00000101 (see
        // preferredWriteUUIDs and issue #288).
        CBUUID(string: "00000201-8C3B-4F2C-A59E-8C08224F3253"),
        // Telit UART Data TX (see preferredWriteUUIDs).
        terminalIoDataTxUUID,
        // u-blox FIFO carries data in both directions, so it is the notify
        // candidate as well as the write one.
        ubloxDataUUID,
    ]

    /// Locate the credit characteristics in a service.
    ///
    /// Returns nil unless a complete known layout is present, so the handshake
    /// is only attempted on the two module families it was written for and
    /// every other device keeps today's plain write/notify behaviour.
    static func terminalIoCredits(in service: Service) -> TerminalIoCredits? {
        func index(of uuid: CBUUID) -> Int? {
            service.characteristics.firstIndex { $0.uuid == uuid }
        }

        // Telit: four separate UART characteristics, credits mandatory.
        if index(of: terminalIoDataRxUUID) != nil,
            index(of: terminalIoDataTxUUID) != nil,
            let creditsWrite = index(of: terminalIoCreditsRxUUID),
            let creditsNotify = index(of: terminalIoCreditsTxUUID) {
            return TerminalIoCredits(
                writeIndex: creditsWrite, notifyIndex: creditsNotify, required: true)
        }

        // u-blox: one data characteristic and one credits characteristic, each
        // used in both directions. Flow control is optional here.
        if index(of: ubloxDataUUID) != nil, let credits = index(of: ubloxCreditsUUID) {
            return TerminalIoCredits(
                writeIndex: credits, notifyIndex: credits, required: false)
        }

        return nil
    }

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
                score: serviceScore,
                terminalIoCredits: terminalIoCredits(in: service)
            )
        }
        return best
    }
}
