import Foundation

// Standalone tests for the FTDI wire-protocol encoding used by the raw-USB
// dive-cable transport (issue #732).
//
// The Aeris/Oceanic cable is an FTDI chip with a custom product ID that macOS
// does not claim, so no /dev/cu.* node exists and the chip has to be driven
// directly. Everything asserted here comes from an external source (FTDI
// application note AN232B-05, or the Linux kernel driver
// drivers/usb/serial/ftdi_sio.c), never from our own implementation, so a
// wrong algorithm cannot make its own test pass.
//
// Assertions use precondition() (not assert(), which the optimizer can elide)
// so a failure aborts the run even if these are ever built with -O.

private func check(_ condition: Bool, _ message: String) {
    precondition(condition, message)
}

// MARK: - Baud rate divisors

// AN232B-05 "Setting Baud Rates" divisor table. The chip divides a 3 MHz
// reference by a divisor with three fractional bits: the integer part lands in
// bits 0..13 and a 3-bit code for the eighths in bits 14..16.
private let an232b05Divisors: [(baud: UInt32, value: UInt16, index: UInt16)] = [
    (300, 0x2710, 0x0000),
    (600, 0x1388, 0x0000),
    (1200, 0x09C4, 0x0000),
    (2400, 0x04E2, 0x0000),
    (4800, 0x0271, 0x0000),
    (9600, 0x4138, 0x0000),
    (19200, 0x809C, 0x0000),
    (38400, 0xC04E, 0x0000),   // the Aeris Epic and most Oceanic Atom2 models
    (115200, 0x001A, 0x0000),  // VTX, i750TC, ProPlusX, i770R
    (230400, 0x000D, 0x0000),
]

for expected in an232b05Divisors {
    guard let actual = FtdiProtocol.baudDivisor(expected.baud) else {
        fatalError("baudDivisor(\(expected.baud)) returned nil")
    }
    check(actual.value == expected.value,
        "baud \(expected.baud): value \(String(actual.value, radix: 16)) != \(String(expected.value, radix: 16))")
    check(actual.index == expected.index,
        "baud \(expected.baud): index \(actual.index) != \(expected.index)")
}

// 57600 is the one rate where AN232B-05 and the kernel disagree, and this test
// pins the kernel's answer because that is the algorithm we implement.
// AN232B-05 truncates to divisor 52 (0x0034), giving 57692 baud, 0.16% error.
// ftdi_sio.c rounds to nearest and gets 52.125 (0xC034), giving 57554 baud,
// 0.08% error. Both are accepted by the chip and the kernel's is more accurate.
// Do NOT "correct" this to 0x0034.
check(FtdiProtocol.baudDivisor(57600)?.value == 0xC034,
    "57600 should encode as the round-to-nearest 0xC034, not the app-note 0x0034")

// Special cases from ftdi_sio.c ftdi_232bm_baud_base_to_divisor: a divisor of
// exactly 1 means 3 Mbaud and is sent as 0; 0x4001 means 2 Mbaud and is sent
// as 1. Without these the chip would be told to divide by 1 or 1.5.
check(FtdiProtocol.baudDivisor(3_000_000)?.value == 0x0000, "3 Mbaud encodes as 0")
check(FtdiProtocol.baudDivisor(2_000_000)?.value == 0x0001, "2 Mbaud encodes as 1")

// Rates the chip cannot express are refused rather than silently mis-encoded.
check(FtdiProtocol.baudDivisor(0) == nil, "zero baud is rejected")
check(FtdiProtocol.baudDivisor(4_000_000) == nil, "above 3 Mbaud is rejected")

// MARK: - Line control

// SET_DATA wValue: data bits in 0..7, parity in 8..10, stop bits in 11..13.
check(FtdiProtocol.dataWord(dataBits: 8, parity: .none, stopBits: .one) == 0x0008,
    "8N1 encodes as 0x0008")
check(FtdiProtocol.dataWord(dataBits: 7, parity: .even, stopBits: .one) == 0x0207,
    "7E1 encodes as 0x0207")
check(FtdiProtocol.dataWord(dataBits: 8, parity: .odd, stopBits: .two) == 0x1108,
    "8O2 encodes as 0x1108")
check(FtdiProtocol.dataWord(dataBits: 5, parity: .none, stopBits: .one) == nil,
    "unsupported data-bit counts are rejected")

// libdivecomputer's numeric codes (iostream.h) map onto the chip encoding.
//
// The `none` cases are written fully qualified on purpose. These functions
// return an Optional, and against an Optional a bare `.none` resolves to
// Optional.none, so `x == .none` silently becomes an is-nil check. Naming the
// type pins it to the enum case. Do not shorten these.
check(FtdiProtocol.parity(fromLibdc: 0) == FtdiProtocol.Parity.none, "libdc 0 is no parity")
check(FtdiProtocol.parity(fromLibdc: 1) == .odd, "libdc 1 is odd parity")
check(FtdiProtocol.parity(fromLibdc: 2) == .even, "libdc 2 is even parity")
check(FtdiProtocol.parity(fromLibdc: 9) == nil, "unknown parity codes are rejected")
check(FtdiProtocol.stopBits(fromLibdc: 0) == .one, "libdc 0 is one stop bit")
check(FtdiProtocol.stopBits(fromLibdc: 2) == .two, "libdc 2 is two stop bits")
check(FtdiProtocol.stopBits(fromLibdc: 9) == nil, "unknown stop-bit codes are rejected")

// DC_FLOWCONTROL_HARDWARE is 1 and DC_FLOWCONTROL_SOFTWARE is 2. The existing
// termios backends have these two swapped; that is latent because no driver
// asks for anything but NONE, but this transport uses the correct mapping.
check(FtdiProtocol.flowControl(fromLibdc: 0) == FtdiProtocol.FlowControl.none,
    "libdc 0 is no flow control")
check(FtdiProtocol.flowControl(fromLibdc: 1) == FtdiProtocol.FlowControl.rtsCts,
    "libdc 1 is HARDWARE flow control, i.e. RTS/CTS")
check(FtdiProtocol.flowControl(fromLibdc: 2) == FtdiProtocol.FlowControl.xonXoff,
    "libdc 2 is SOFTWARE flow control, i.e. XON/XOFF")

// MARK: - Modem control

// The high byte of SET_MODEM_CTRL is a write mask, so DTR and RTS can be set
// independently. The Oceanic Atom2 handshake pulses RTS with DTR held high.
check(FtdiProtocol.modemControlValue(dtr: true) == 0x0101, "DTR on is 0x0101")
check(FtdiProtocol.modemControlValue(dtr: false) == 0x0100, "DTR off is 0x0100")
check(FtdiProtocol.modemControlValue(rts: true) == 0x0202, "RTS on is 0x0202")
check(FtdiProtocol.modemControlValue(rts: false) == 0x0200, "RTS off is 0x0200")

// MARK: - Reset and purge

// DC_DIRECTION_INPUT is 0x01, OUTPUT is 0x02, ALL is the union 0x03.
// libftdi 1.5 renamed its purge helpers to ftdi_tciflush/ftdi_tcoflush
// precisely because the older PURGE_RX/PURGE_TX names were read from the
// wrong end of the link. Host input is value 2, host output is value 1.
check(FtdiProtocol.resetValues(forDirection: 0x01) == [2],
    "input purge sends value 2")
check(FtdiProtocol.resetValues(forDirection: 0x02) == [1],
    "output purge sends value 1")
check(FtdiProtocol.resetValues(forDirection: 0x03) == [2, 1],
    "purging both directions sends both values")

// MARK: - Status header stripping

// Every bulk-IN packet begins with two modem-status bytes that are not
// payload. The chip emits one header per packet even when it has nothing to
// say, which is the keep-alive that arrives every latency-timer period.
let emptyKeepAlive: [UInt8] = [0x01, 0x60]
check(FtdiProtocol.stripStatusBytes(from: emptyKeepAlive[...], packetSize: 64).isEmpty,
    "a bare status header carries no payload")

let onePartialPacket: [UInt8] = [0x01, 0x60, 0xAA, 0xBB, 0xCC]
check(FtdiProtocol.stripStatusBytes(from: onePartialPacket[...], packetSize: 64) == [0xAA, 0xBB, 0xCC],
    "a short packet yields its payload")

// Two full 8-byte packets back to back: the header must be dropped at the
// start of each, not only at the start of the buffer. Getting this wrong
// silently injects two junk bytes mid-stream, which desyncs the framing the
// way issue #334 did.
let twoFullPackets: [UInt8] = [
    0x01, 0x60, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15,
    0x01, 0x60, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25,
]
check(FtdiProtocol.stripStatusBytes(from: twoFullPackets[...], packetSize: 8)
        == [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25],
    "each packet's header is dropped, not just the first")

// A full packet followed by a partial one.
let fullThenPartial: [UInt8] = [
    0x01, 0x60, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15,
    0x01, 0x60, 0x20,
]
check(FtdiProtocol.stripStatusBytes(from: fullThenPartial[...], packetSize: 8)
        == [0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x20],
    "a trailing partial packet is handled")

let emptyTransfer: [UInt8] = []
check(FtdiProtocol.stripStatusBytes(from: emptyTransfer[...], packetSize: 64).isEmpty,
    "an empty transfer yields no payload")

// Slices that do not start at index 0 must be handled: the accumulator passes
// sub-slices of a larger buffer.
let offsetSlice = twoFullPackets[8...]
check(FtdiProtocol.stripStatusBytes(from: offsetSlice, packetSize: 8)
        == [0x20, 0x21, 0x22, 0x23, 0x24, 0x25],
    "a slice with a non-zero start index is handled")

print("FtdiProtocolTests: all assertions passed")
