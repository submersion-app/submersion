import Foundation

/// FTDI wire-protocol encoding for the FT232 family of USB-to-serial bridges.
///
/// Pure by design: no IOKit, no Flutter, no I/O, so it compiles and runs
/// standalone under `darwin/run_native_tests.sh`. Every constant here comes
/// from FTDI application note AN232B-05 or from the Linux kernel driver
/// `drivers/usb/serial/ftdi_sio.c`, never from observing one particular cable.
///
/// Why this exists at all: the Aeris/Oceanic download cable is an FTDI chip
/// whose EEPROM carries a custom product ID (0x0403:0xF460). Apple's
/// AppleUSBFTDI driver does not claim that ID, so macOS never creates a
/// `/dev/cu.usbserial-*` node and the serial path has nothing to open
/// (issue #732). Talking to the chip directly is the only self-contained fix.
enum FtdiProtocol {
    // MARK: - Control transfers

    /// `bRequest` values for FTDI vendor control transfers.
    enum Request: UInt8 {
        case reset = 0x00
        case setModemControl = 0x01
        case setFlowControl = 0x02
        case setBaudRate = 0x03
        case setData = 0x04
        case setLatencyTimer = 0x09
    }

    /// `bmRequestType` for a host-to-device vendor request addressed to the
    /// device: direction out, type vendor, recipient device.
    static let requestTypeOut: UInt8 = 0x40

    /// `wIndex` naming the chip's first (and, on every dive cable, only) port.
    /// Multi-port parts such as the FT2232 would pass an interface number here.
    static let portIndex: UInt16 = 1

    /// Latency timer in milliseconds, applied on configure.
    ///
    /// The chip's default is 16 ms, which it waits before shipping a partial
    /// buffer. The Oceanic Atom2 driver runs many small request/response
    /// transactions against a 1000 ms timeout, so the default would add 16 ms
    /// to nearly every one of them.
    static let defaultLatencyTimerMs: UInt16 = 1

    // MARK: - Baud rate

    /// Encoding table for the fractional part of the divisor, indexed by the
    /// remainder in eighths (`divfrac` in ftdi_sio.c). The codes are not in
    /// numeric order, which is why this is a table and not arithmetic.
    static let divisorFractionCodes: [UInt32] = [0, 3, 2, 4, 1, 5, 6, 7]

    /// Encodes `baud` as the `(wValue, wIndex)` pair for a SET_BAUD_RATE
    /// request, or nil if the chip cannot express that rate.
    ///
    /// The chip divides a 3 MHz reference by a divisor carrying three
    /// fractional bits. The divisor is therefore computed in eighths and then
    /// split: integer part into bits 0..13, fractional code into bits 14..16.
    /// This mirrors `ftdi_232bm_baud_base_to_divisor` in ftdi_sio.c with
    /// base 48000000, including its round-to-nearest, which is why 57600
    /// encodes as 0xC034 here and as 0x0034 in AN232B-05's table. Both are
    /// valid; round-to-nearest is the more accurate of the two.
    static func baudDivisor(_ baud: UInt32) -> (value: UInt16, index: UInt16)? {
        guard baud > 0 else { return nil }

        // 48 MHz / 2 = 24 MHz, which is eight times the 3 MHz reference, so
        // this quotient is the divisor expressed in eighths.
        let denominator = UInt64(baud) * 2
        let divisorEighths = (UInt64(48_000_000) + denominator / 2) / denominator

        // Below eight eighths the divisor would be less than 1, which the chip
        // cannot represent. 3 Mbaud is exactly eight eighths.
        guard divisorEighths >= 8 else { return nil }

        var divisor =
            UInt32(divisorEighths >> 3)
            | (divisorFractionCodes[Int(divisorEighths & 7)] << 14)

        // Documented special cases for the two highest rates. A divisor of 1
        // means 3 Mbaud and is sent as 0; 0x4001 means 2 Mbaud and is sent as
        // 1. Without these the chip would be asked to divide by 1 or by 1.5.
        if divisor == 1 {
            divisor = 0
        } else if divisor == 0x4001 {
            divisor = 1
        }

        return (
            value: UInt16(divisor & 0xFFFF),
            index: UInt16((divisor >> 16) & 0xFFFF)
        )
    }

    // MARK: - Line control

    /// Parity, encoded in bits 8..10 of the SET_DATA value.
    enum Parity: UInt16 {
        case none = 0
        case odd = 1
        case even = 2
        case mark = 3
        case space = 4
    }

    /// Stop bits, encoded in bits 11..13 of the SET_DATA value.
    enum StopBits: UInt16 {
        case one = 0
        case onePointFive = 1
        case two = 2
    }

    /// Flow control, encoded in the high byte of the SET_FLOW_CTRL index.
    enum FlowControl: UInt16 {
        case none = 0x0000
        case rtsCts = 0x0100
        case dtrDsr = 0x0200
        case xonXoff = 0x0400
    }

    /// Builds the `wValue` for a SET_DATA request, or nil for a frame the chip
    /// cannot produce. Data bits occupy bits 0..7.
    ///
    /// Only 7 and 8 data bits are accepted. The FT232 datasheet lists 7 and 8
    /// as supported; shorter frames are not, and every libdivecomputer serial
    /// driver asks for 8.
    static func dataWord(dataBits: UInt32, parity: Parity, stopBits: StopBits) -> UInt16? {
        guard dataBits == 7 || dataBits == 8 else { return nil }
        return UInt16(dataBits) | (parity.rawValue << 8) | (stopBits.rawValue << 11)
    }

    /// Maps libdivecomputer's `dc_parity_t` numeric value onto the chip
    /// encoding, or nil if it is not a value libdivecomputer defines.
    static func parity(fromLibdc value: UInt32) -> Parity? {
        guard value <= 4 else { return nil }
        return Parity(rawValue: UInt16(value))
    }

    /// Maps libdivecomputer's `dc_stopbits_t` numeric value onto the chip
    /// encoding, or nil if it is not a value libdivecomputer defines.
    static func stopBits(fromLibdc value: UInt32) -> StopBits? {
        guard value <= 2 else { return nil }
        return StopBits(rawValue: UInt16(value))
    }

    /// Maps libdivecomputer's `dc_flowcontrol_t` numeric value onto the chip
    /// encoding, or nil if it is not a value libdivecomputer defines.
    ///
    /// Note the ordering: libdivecomputer defines HARDWARE as 1 and SOFTWARE
    /// as 2 (`iostream.h`), which reads as the wrong way round to anyone who
    /// thinks of XON/XOFF as the simpler case. The termios and DCB backends
    /// once had the two swapped (issue #1155); they now share the
    /// `LIBDC_FLOWCONTROL_*` constants in `libdc_wrapper.h`, which this file
    /// cannot use because it is compiled standalone by `run_native_tests.sh`.
    static func flowControl(fromLibdc value: UInt32) -> FlowControl? {
        switch value {
        case 0: return FlowControl.none
        case 1: return .rtsCts
        case 2: return .xonXoff
        default: return nil
        }
    }

    // MARK: - Modem control

    /// `wValue` asserting or clearing DTR. The high byte is a write mask, so
    /// DTR and RTS are set independently and one does not clobber the other.
    static func modemControlValue(dtr: Bool) -> UInt16 {
        dtr ? 0x0101 : 0x0100
    }

    /// `wValue` asserting or clearing RTS. See `modemControlValue(dtr:)` for
    /// why the high byte is set.
    static func modemControlValue(rts: Bool) -> UInt16 {
        rts ? 0x0202 : 0x0200
    }

    // MARK: - Reset and purge

    /// `wValue` values for the RESET request that purge the requested
    /// direction, in the order they should be sent.
    ///
    /// `direction` is a `dc_direction_t` bitmask: 0x01 input, 0x02 output,
    /// 0x03 both. The mapping to chip values looks inverted because the
    /// datasheet names the buffers from the chip's end of the link. libftdi
    /// 1.5 deprecated its `ftdi_usb_purge_rx_buffer` and
    /// `ftdi_usb_purge_tx_buffer` helpers in favour of `ftdi_tciflush` and
    /// `ftdi_tcoflush` for exactly this reason: flushing the host's input
    /// sends 2, flushing the host's output sends 1.
    static func resetValues(forDirection direction: UInt32) -> [UInt16] {
        var values: [UInt16] = []
        if direction & 0x01 != 0 { values.append(2) }
        if direction & 0x02 != 0 { values.append(1) }
        return values
    }

    // MARK: - Bulk IN framing

    /// Number of modem-status bytes the chip prefixes to every bulk-IN packet.
    static let statusHeaderLength = 2

    /// Removes the per-packet modem-status header from a bulk-IN transfer.
    ///
    /// The chip prepends two status bytes to every packet it sends, including
    /// packets with no payload at all: with no data to report it still emits a
    /// bare two-byte keep-alive once per latency-timer period. Payload is
    /// therefore the transfer minus two bytes for every whole or partial
    /// packet in it, not minus two bytes overall. Dropping only the leading
    /// header injects two junk bytes into the middle of every multi-packet
    /// response, which desyncs libdivecomputer's framing the same way the
    /// truncated reads in issue #334 did.
    static func stripStatusBytes(from raw: ArraySlice<UInt8>, packetSize: Int) -> [UInt8] {
        guard packetSize > statusHeaderLength else { return [] }

        var payload: [UInt8] = []
        payload.reserveCapacity(raw.count)

        var index = raw.startIndex
        while index < raw.endIndex {
            let packetEnd =
                raw.index(index, offsetBy: packetSize, limitedBy: raw.endIndex)
                ?? raw.endIndex
            let bodyStart =
                raw.index(index, offsetBy: statusHeaderLength, limitedBy: packetEnd)
                ?? packetEnd
            payload.append(contentsOf: raw[bodyStart..<packetEnd])
            index = packetEnd
        }

        return payload
    }
}
