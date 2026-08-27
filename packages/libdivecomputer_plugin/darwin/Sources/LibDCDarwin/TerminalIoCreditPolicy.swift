import Foundation

/// Credit accounting for the Telit/Stollmann Terminal I/O (TIO) profile used
/// by the Heinrichs Weikamp BlueMod+SR devices (issue #923).
///
/// The module will not send a byte over the UART bridge until the client has
/// granted it credits, and it spends one credit per notification. A single
/// opening grant therefore only covers the first `initialGrant` packets: an
/// OSTC logbook dump is thousands of notifications, so the client has to top
/// the balance up while the transfer runs.
///
/// Kept as a dependency-free value type (Foundation only) so it can be
/// compiled and unit-tested standalone via run_native_tests.sh, the same way
/// PacketReadBuffer and BleCharacteristicSelector are. The Windows, Linux and
/// Android transports carry line-by-line equivalents.
///
/// The balance is only ever credited once the module has *confirmed* it
/// received a grant, and a grant already in flight suppresses further ones.
/// The invariant that buys is that the balance may be understated but never
/// overstated, and the two errors are not symmetric:
///
///  - Understated: a refill goes out slightly early. Harmless -- the module
///    caps its own balance and the spare credits are simply unused.
///  - Overstated: the client believes the module can still send when it
///    cannot. The module falls silent, no further packets arrive to decrement
///    the balance, so no refill is ever triggered and the transfer stalls for
///    good.
///
/// Crediting when the platform merely *accepts* the write request would
/// produce exactly that overstatement, because acceptance is local: Android
/// reports success from `writeCharacteristic()` and can still fail the write
/// at the ATT layer afterwards.
///
/// Deliberate deviation from Subsurface's core/qt-ble.cpp, otherwise the
/// reference for this handshake: it refills on `hw_credit == MINIMAL`, an
/// exact-equality test that cannot recover if a decrement is ever missed, so
/// the refill here triggers on `<=`.
struct TerminalIoCreditPolicy {
    /// Opening grant. 0xFF is reserved by the TIO protocol, so 254 is the
    /// largest value that means "credits" rather than a control code.
    static let initialGrant: UInt8 = 254
    /// Balance at or below which the client tops the module back up.
    static let refillThreshold = 32
    /// Size of a mid-transfer refill.
    static let refillAmount = UInt8(Int(initialGrant) - refillThreshold)

    private(set) var credits = 0
    private(set) var grantInFlight = false
    /// Whether the opening grant has been confirmed.
    private(set) var isOpen = false

    /// Record the confirmed opening grant, which starts credit accounting.
    ///
    /// Nothing is requested before this, because notifications are already
    /// live by the time the opening grant is written -- the u-blox service in
    /// particular streams with no credits at all. A refill requested in that
    /// window would race the opening grant: two credit writes would be
    /// outstanding on the same characteristic, their completions are
    /// indistinguishable to the transport, and the balance would end up
    /// counting both.
    mutating func opened(with amount: UInt8) {
        isOpen = true
        grantInFlight = false
        credits += Int(amount)
    }

    /// Record a mid-transfer grant the module has confirmed receiving.
    mutating func grantAccepted(_ amount: UInt8) {
        grantInFlight = false
        credits += Int(amount)
    }

    /// Record that a grant never reached the module, so the next packet can
    /// ask again. The balance is left alone precisely because these credits
    /// were never counted in the first place.
    mutating func grantFailed() {
        grantInFlight = false
    }

    /// Account for one received packet.
    ///
    /// Returns the number of credits the caller must now write to Credits RX,
    /// or nil while the balance is healthy or a grant is already outstanding.
    /// The returned grant is not counted until the caller confirms it via
    /// `grantAccepted`.
    mutating func packetReceived() -> UInt8? {
        if credits > 0 {
            credits -= 1
        }
        guard isOpen, !grantInFlight, credits <= Self.refillThreshold else {
            return nil
        }
        grantInFlight = true
        return Self.refillAmount
    }
}
