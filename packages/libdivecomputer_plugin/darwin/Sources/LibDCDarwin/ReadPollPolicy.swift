import Foundation

/// Decides when a read-poll BLE transport puts a GATT read on the wire.
///
/// Some dive computers expose a data characteristic that can be read but can
/// neither notify nor indicate (the Seac Tablet, issue #1454), so every reply
/// has to be asked for. libdivecomputer only says when it wants bytes, by
/// calling read(); this policy turns that into GATT reads under three rules:
///
///  - At most one read is in flight. A read still outstanding when
///    libdivecomputer's timeout fires is adopted by the next read() rather
///    than doubled. The Tablet can answer seconds late (libdivecomputer
///    15d6f6c measured up to 5.6 s), and a second request stacked behind the
///    first is what corrupted the retry that commit describes. Android also
///    refuses a second GATT operation outright.
///  - An empty value or a failed read is retried after `retryDelayMs`, never
///    at once. `dc_packet_read` loops until it has every byte it asked for, so
///    a transport that answered an empty value with zero-byte success would
///    make it hammer the characteristic with no timeout ever firing.
///  - purge() discards the value of a read already in flight, because that
///    value answers a command libdivecomputer has abandoned.
///
/// A plain value type with an injected millisecond clock, so it is unit-tested
/// standalone via run_native_tests.sh; BleIoStream guards it with a lock.
/// Mirrored in Kotlin by ReadPollPolicy.kt.
struct ReadPollPolicy {
    enum Action: Equatable {
        /// Put one GATT read on the wire now.
        case issueRead
        /// A read is in flight or backing off; wait for data, then ask again.
        case wait
        /// The link is gone; fail the read.
        case closed
    }

    /// Delay before re-reading after an empty value or a failed read.
    static let retryDelayMs: UInt64 = 100
    /// Longest a waiting reader sleeps before asking the policy again.
    static let waitSliceMs: UInt64 = 100

    private(set) var readInFlight = false
    private var discardInFlight = false
    private var retryNotBeforeMs: UInt64 = 0
    private var isClosed = false

    /// What a reader with an empty queue should do now.
    mutating func next(nowMs: UInt64) -> Action {
        if isClosed { return .closed }
        if readInFlight || nowMs < retryNotBeforeMs { return .wait }
        readInFlight = true
        return .issueRead
    }

    /// The platform refused the read that next() asked for, so no completion
    /// is coming. Back off rather than retry in a tight loop.
    mutating func issueFailed(nowMs: UInt64) {
        readInFlight = false
        retryNotBeforeMs = nowMs + Self.retryDelayMs
    }

    /// A read completed. Returns true when its value should be queued for
    /// libdivecomputer; `hasData` is false for an empty value or a failed read.
    mutating func completed(hasData: Bool, nowMs: UInt64) -> Bool {
        readInFlight = false
        if isClosed { return false }
        if discardInFlight {
            discardInFlight = false
            return false
        }
        if !hasData {
            retryNotBeforeMs = nowMs + Self.retryDelayMs
            return false
        }
        return true
    }

    /// libdivecomputer purged its input: whatever is already on the wire
    /// answers a command it has given up on.
    mutating func purge() {
        if readInFlight { discardInFlight = true }
    }

    /// The link is going away. Every later read fails and late completions
    /// are ignored.
    mutating func close() {
        isClosed = true
        readInFlight = false
        discardInFlight = false
    }
}
