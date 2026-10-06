# FTDI-over-raw-USB Transport Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Submersion download from Aeris/Oceanic dive computers whose USB cable is an FTDI chip with a custom product ID that no operating system driver claims (issue #732).

**Architecture:** libdivecomputer is opened through `dc_custom_open` with a plugin-owned eleven-slot callback table, so the byte pipe underneath is replaceable without touching libdivecomputer, the pigeon API or the C bridge. macOS gains a second implementation of that table which speaks the FTDI wire protocol over raw USB via IOKit's `IOUSBLib`, tried after the existing tty candidates are exhausted. Android needs no new transport at all: the vendored `usb-serial-for-android` already ships the chip drivers, so it only needs the custom product IDs registered in a probe table.

**Tech Stack:** Swift 5.9 (pure logic plus IOKit glue), C (IOUSBLib shim), Kotlin (Android probe table), Dart (entitlement file assertion). Tests run through `packages/libdivecomputer_plugin/darwin/run_native_tests.sh` (standalone `swiftc`), Gradle JVM unit tests, and `flutter test`.

**Spec:** `docs/superpowers/specs/2026-08-18-ftdi-usb-transport-design.md`

## Global Constraints

- No em-dashes anywhere, including code comments and commit messages. See the repository writing-style rules.
- No emojis in code, comments or documentation.
- `dart format .` must produce no changes before any commit that touches Dart.
- `flutter analyze` must be clean across the whole project; infos are fatal in CI.
- Swift files that must stay unit-testable are placed in `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/` and symlinked into `macos/Classes/` and `ios/Classes/`. A new shared darwin Swift file needs both symlinks or the CocoaPods build will not see it.
- Target platforms for this plan: macOS (`:osx, '12.0'`) and Android. iOS compiles the new C file to nothing (no USB host). Linux and Windows are not touched.
- Device coverage: macOS covers FTDI `0x0403:0xF460`, `0x0403:0xF680`, `0x0403:0x87D0`. Android covers those three plus Prolific `0x04B8:0x0521`, Prolific `0x04B8:0x0522` and CDC-ACM `0xFFFF:0x0005`.
- Status codes are the `LIBDC_STATUS_*` values from `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h`. They are numerically identical to `dc_status_t`.
- libdivecomputer serial enum values, taken from `third_party/libdivecomputer/include/libdivecomputer/iostream.h`: parity `0` none, `1` odd, `2` even, `3` mark, `4` space; stop bits `0` one, `1` one and a half, `2` two; flow control `0` none, `1` hardware, `2` software; direction `0x01` input, `0x02` output, `0x03` all.

---

## Known pre-existing defect, deliberately not fixed here

`SerialIoStream.performConfigure` and `linux/serial_io_stream.c:190` both map flow-control value `1` to software XON/XOFF and `2` to hardware RTS/CTS. libdivecomputer defines the opposite (`DC_FLOWCONTROL_HARDWARE = 1`, `DC_FLOWCONTROL_SOFTWARE = 2`). This is latent: grepping `third_party/libdivecomputer/src/` shows only the serial backends ever name those constants, so every driver passes `DC_FLOWCONTROL_NONE` and the inversion never executes.

The new FTDI code in Task 1 uses the correct mapping and says so in a comment, so a future reader does not "align" it with its inverted neighbours. Task 9 files a follow-up issue for the existing backends. Do not change `SerialIoStream.swift` or the Linux backend in this plan; Linux is out of scope and the change would be untestable here.

---

## File Structure

Create, under `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/`:

| File | Responsibility |
| --- | --- |
| `FtdiProtocol.swift` | Pure FTDI wire encoding: control request codes, baud divisors, line-control word, modem-control values, reset values, status-header stripping. No I/O. |
| `FtdiReadAccumulator.swift` | Pure read-exactly-N-or-timeout over an injected packet reader, buffering surplus payload between calls. |
| `UsbFtdiDeviceEnumerator.swift` | Dive-cable VID/PID allowlist (pure) plus IOKit USB device enumeration (macOS only). |
| `FtdiUsbIoStream.swift` | Glue: owns the C handle, drives the two pure units, produces `libdc_io_callbacks_t`. |

Create, under `packages/libdivecomputer_plugin/macos/Classes/`:

| File | Responsibility |
| --- | --- |
| `ftdi_usb_darwin.h` | Opaque handle plus six-function C API. Uses only `stdint.h`/`stddef.h` so it is safe in the iOS umbrella header. |
| `ftdi_usb_darwin.c` | IOUSBLib open/claim/control/bulk with timeouts. Compiles to non-macOS stubs off macOS. No FTDI knowledge. |

Create, under `packages/libdivecomputer_plugin/darwin/Tests/`: `FtdiProtocolTests/main.swift`, `FtdiReadAccumulatorTests/main.swift`, `UsbFtdiDeviceEnumeratorTests/main.swift`.

Create, under `packages/libdivecomputer_plugin/android/src/`: `main/kotlin/com/submersion/libdivecomputer/DiveCableIds.kt` and `test/kotlin/com/submersion/libdivecomputer/DiveCableIdsTest.kt`.

Modify: `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`, `darwin/run_native_tests.sh`, `macos/libdivecomputer_plugin.podspec`, `ios/libdivecomputer_plugin.podspec`, `android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt`, `android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`, `macos/Runner/Release.entitlements`, `macos/Runner/DebugProfile.entitlements`, `test/macos_entitlements_test.dart`.

---

## Task 1: FTDI wire protocol encoding

**Files:**
- Create: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiProtocol.swift`
- Test: `packages/libdivecomputer_plugin/darwin/Tests/FtdiProtocolTests/main.swift`
- Modify: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum FtdiProtocol` with nested `Request: UInt8`, `Parity: UInt16`, `StopBits: UInt16`, `FlowControl: UInt16`, `Reset: UInt16`; and statics `requestTypeOut: UInt8`, `portIndex: UInt16`, `statusHeaderLength: Int`, `defaultLatencyTimerMs: UInt16`, `baudDivisor(_ baud: UInt32) -> (value: UInt16, index: UInt16)?`, `dataWord(dataBits: UInt32, parity: Parity, stopBits: StopBits) -> UInt16?`, `parity(fromLibdc: UInt32) -> Parity?`, `stopBits(fromLibdc: UInt32) -> StopBits?`, `flowControl(fromLibdc: UInt32) -> FlowControl?`, `modemControlValue(dtr: Bool) -> UInt16`, `modemControlValue(rts: Bool) -> UInt16`, `resetValues(forDirection: UInt32) -> [UInt16]`, `stripStatusBytes(from: ArraySlice<UInt8>, packetSize: Int) -> [UInt8]`.

- [ ] **Step 1: Write the failing test**

Create `packages/libdivecomputer_plugin/darwin/Tests/FtdiProtocolTests/main.swift`:

```swift
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
```

- [ ] **Step 2: Register the suite in the native test harness**

Append to `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`:

```bash
# FTDI wire-protocol encoding (issue #732). The Aeris/Oceanic cable is an FTDI
# chip with a custom product ID that macOS does not claim, so there is no
# /dev/cu.* node and the chip is driven directly over USB. Divisor vectors come
# from FTDI application note AN232B-05, not from our implementation.
swiftc -o "$BUILD_DIR/ftdi_protocol_tests" \
    Sources/LibDCDarwin/FtdiProtocol.swift \
    Tests/FtdiProtocolTests/main.swift

"$BUILD_DIR/ftdi_protocol_tests"
```

- [ ] **Step 3: Run the suite to verify it fails**

Run: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: FAIL. `swiftc` reports `cannot find 'FtdiProtocol' in scope`, because `Sources/LibDCDarwin/FtdiProtocol.swift` does not exist yet.

- [ ] **Step 4: Write the implementation**

Create `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiProtocol.swift`:

```swift
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

        var divisor = UInt32(divisorEighths >> 3)
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
    /// as 2 (`iostream.h`). The termios backends in this repository have those
    /// two swapped. That is latent, because no driver requests anything but
    /// NONE, but this mapping follows libdivecomputer rather than its
    /// neighbours. Do not "align" it with them.
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
            let packetEnd = raw.index(index, offsetBy: packetSize, limitedBy: raw.endIndex)
                ?? raw.endIndex
            let bodyStart = raw.index(index, offsetBy: statusHeaderLength, limitedBy: packetEnd)
                ?? packetEnd
            payload.append(contentsOf: raw[bodyStart..<packetEnd])
            index = packetEnd
        }

        return payload
    }
}
```

- [ ] **Step 5: Run the suite to verify it passes**

Run: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: PASS, ending with `FtdiProtocolTests: all assertions passed`. Every previously existing suite must still pass.

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiProtocol.swift \
        packages/libdivecomputer_plugin/darwin/Tests/FtdiProtocolTests/main.swift \
        packages/libdivecomputer_plugin/darwin/run_native_tests.sh
git commit -m "feat(dc): FTDI wire-protocol encoding for raw-USB dive cables (#732)"
```

---

## Task 2: Exact-size read accumulation over bulk transfers

**Files:**
- Create: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiReadAccumulator.swift`
- Test: `packages/libdivecomputer_plugin/darwin/Tests/FtdiReadAccumulatorTests/main.swift`
- Modify: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`

**Interfaces:**
- Consumes: `FtdiProtocol.stripStatusBytes(from:packetSize:)` from Task 1.
- Produces: `enum FtdiReadStatus { case success, timeout, io }`, `struct FtdiReadOutcome { let status: FtdiReadStatus; let bytesRead: Int }`, `enum FtdiPacketResult { case packet([UInt8]); case idle; case failure }`, and `final class FtdiReadAccumulator` with `init(packetSize: Int)`, `func read(into: UnsafeMutableRawPointer, size: Int, timeoutMs: Int32, readPacket: (Int32) -> FtdiPacketResult) -> FtdiReadOutcome`, `func discardPending()`, and `var pendingCount: Int`.

- [ ] **Step 1: Write the failing test**

Create `packages/libdivecomputer_plugin/darwin/Tests/FtdiReadAccumulatorTests/main.swift`:

```swift
import Foundation

// Standalone tests for FtdiReadAccumulator, which satisfies libdivecomputer's
// "return exactly N bytes or time out" read contract on top of FTDI bulk-IN
// transfers (issue #732).
//
// This is the same contract serialReadFully enforces for POSIX serial fds.
// Every libdivecomputer driver relies on it: a short success makes the driver
// read a mid-packet byte as a framing trailer, which is precisely how issue
// #334 failed. Here the problem is worse than plain chunking, because each
// bulk packet also carries two modem-status bytes that are not payload.
//
// A scripted packet source stands in for the USB pipe, so no hardware is
// needed. Assertions use precondition() so they survive -O.

private func check(_ condition: Bool, _ message: String) {
    precondition(condition, message)
}

private let packetSize = 8
private let statusHeader: [UInt8] = [0x01, 0x60]

/// Wraps `payload` in as many status-prefixed packets as it needs.
private func packetize(_ payload: [UInt8]) -> [[UInt8]] {
    let bodySize = packetSize - statusHeader.count
    if payload.isEmpty { return [statusHeader] }
    return stride(from: 0, to: payload.count, by: bodySize).map { start in
        statusHeader + Array(payload[start..<min(start + bodySize, payload.count)])
    }
}

/// A non-zero, position-dependent pattern: catches truncation, zero-fill and
/// byte-offset bugs that an all-zero buffer would hide.
private func distinctivePattern(_ count: Int) -> [UInt8] {
    (0..<count).map { UInt8(($0 &* 7 &+ 3) & 0xFF) }
}

/// Hands out scripted packets one call at a time, then reports idle.
private final class ScriptedSource {
    private var queue: [FtdiPacketResult]
    private(set) var callCount = 0

    init(_ queue: [FtdiPacketResult]) { self.queue = queue }

    func next(_ deadlineMs: Int32) -> FtdiPacketResult {
        callCount += 1
        return queue.isEmpty ? .idle : queue.removeFirst()
    }
}

private func readIntoArray(
    _ accumulator: FtdiReadAccumulator, size: Int, timeoutMs: Int32,
    source: ScriptedSource
) -> (FtdiReadOutcome, [UInt8]) {
    var buffer = [UInt8](repeating: 0, count: size)
    let outcome = buffer.withUnsafeMutableBytes { raw in
        accumulator.read(
            into: raw.baseAddress!, size: size, timeoutMs: timeoutMs,
            readPacket: source.next)
    }
    return (outcome, buffer)
}

// A response spanning several packets must be reassembled into one exact read.
// This is the 140-byte-version-block shape from issue #334.
do {
    let payload = distinctivePattern(20)
    let source = ScriptedSource(packetize(payload).map { .packet($0) })
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    let (outcome, buffer) = readIntoArray(
        accumulator, size: 20, timeoutMs: 1000, source: source)

    check(outcome.status == .success, "a complete multi-packet response succeeds")
    check(outcome.bytesRead == 20, "bytesRead is \(outcome.bytesRead), expected 20")
    check(buffer == payload, "payload was reassembled with status bytes removed")
    check(accumulator.pendingCount == 0, "nothing is left over")
}

// Payload beyond the requested size is kept for the next call rather than
// discarded. Dropping it would lose the head of the next device response.
do {
    let payload = distinctivePattern(12)
    let source = ScriptedSource(packetize(payload).map { .packet($0) })
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)

    let (first, firstBuffer) = readIntoArray(
        accumulator, size: 4, timeoutMs: 1000, source: source)
    check(first.status == .success, "the first short read succeeds")
    check(firstBuffer == Array(payload[0..<4]), "the first read gets the first bytes")
    check(accumulator.pendingCount == 2,
        "surplus from the first packet is retained, got \(accumulator.pendingCount)")

    let callsAfterFirst = source.callCount
    let (second, secondBuffer) = readIntoArray(
        accumulator, size: 2, timeoutMs: 1000, source: source)
    check(second.status == .success, "the second read succeeds")
    check(secondBuffer == Array(payload[4..<6]), "the second read continues the stream")
    check(source.callCount == callsAfterFirst,
        "a read served entirely from the buffer issues no USB transfer")
}

// A response that never completes must report timeout, not a short success.
do {
    let source = ScriptedSource(packetize(distinctivePattern(3)).map { .packet($0) })
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    let (outcome, _) = readIntoArray(
        accumulator, size: 10, timeoutMs: 50, source: source)

    check(outcome.status == .timeout, "an incomplete response times out")
    check(outcome.bytesRead == 3,
        "partial byte count is still reported, got \(outcome.bytesRead)")
}

// Bare keep-alive packets carry no payload and must not be mistaken for data
// or for end-of-stream. They arrive once per latency-timer period whenever the
// device is quiet.
do {
    let payload = distinctivePattern(3)
    var script: [FtdiPacketResult] = [.packet(statusHeader), .packet(statusHeader)]
    script.append(contentsOf: packetize(payload).map { .packet($0) })
    let source = ScriptedSource(script)
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    let (outcome, buffer) = readIntoArray(
        accumulator, size: 3, timeoutMs: 1000, source: source)

    check(outcome.status == .success, "keep-alives are skipped and the read completes")
    check(buffer == payload, "payload survives the keep-alives")
}

// A hard transport error is distinct from a timeout: libdivecomputer retries a
// timeout but not an I/O failure, so an unplugged cable must not look like a
// slow device.
do {
    let source = ScriptedSource([.failure])
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    let (outcome, _) = readIntoArray(
        accumulator, size: 4, timeoutMs: 1000, source: source)

    check(outcome.status == .io, "a transport failure reports io, not timeout")
}

// A zero-length read is a no-op that must not issue a transfer.
do {
    let source = ScriptedSource([])
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    var scratch: UInt8 = 0
    let outcome = withUnsafeMutableBytes(of: &scratch) { raw in
        accumulator.read(
            into: raw.baseAddress!, size: 0, timeoutMs: 1000,
            readPacket: source.next)
    }
    check(outcome.status == .success, "a zero-length read succeeds")
    check(outcome.bytesRead == 0, "a zero-length read transfers nothing")
    check(source.callCount == 0, "a zero-length read issues no USB transfer")
}

// discardPending backs the purge callback: after it, buffered payload from
// before the purge must not surface in a later read.
do {
    let source = ScriptedSource(packetize(distinctivePattern(6)).map { .packet($0) })
    let accumulator = FtdiReadAccumulator(packetSize: packetSize)
    _ = readIntoArray(accumulator, size: 2, timeoutMs: 1000, source: source)
    check(accumulator.pendingCount > 0, "test setup: there should be surplus to discard")

    accumulator.discardPending()
    check(accumulator.pendingCount == 0, "discardPending clears the buffer")
}

print("FtdiReadAccumulatorTests: all assertions passed")
```

- [ ] **Step 2: Register the suite in the native test harness**

Append to `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`:

```bash
# FTDI bulk-IN read accumulation (issue #732). libdivecomputer's contract is
# "exactly N bytes or timeout"; FTDI packets add a two-byte status header on
# top of the USB chunking that broke issue #334. A scripted packet source
# stands in for the USB pipe.
swiftc -o "$BUILD_DIR/ftdi_read_accumulator_tests" \
    Sources/LibDCDarwin/FtdiProtocol.swift \
    Sources/LibDCDarwin/FtdiReadAccumulator.swift \
    Tests/FtdiReadAccumulatorTests/main.swift

"$BUILD_DIR/ftdi_read_accumulator_tests"
```

- [ ] **Step 3: Run the suite to verify it fails**

Run: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: FAIL. `swiftc` reports `cannot find 'FtdiReadAccumulator' in scope`.

- [ ] **Step 4: Write the implementation**

Create `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiReadAccumulator.swift`:

```swift
import Foundation

/// How a read finished, mapped onto a libdivecomputer status by the caller.
enum FtdiReadStatus: Equatable {
    case success
    case timeout
    case io
}

/// Outcome of a read. `bytesRead` is reported even on timeout or error, which
/// matches libdivecomputer's own serial backend (`*actual = nbytes`).
struct FtdiReadOutcome: Equatable {
    let status: FtdiReadStatus
    let bytesRead: Int
}

/// Result of one bulk-IN transfer.
///
/// `idle` and `failure` are kept apart on purpose: libdivecomputer retries a
/// timeout but treats an I/O error as fatal, so an unplugged cable must not be
/// reported as a merely slow device.
enum FtdiPacketResult {
    /// Raw transfer bytes, status header included.
    case packet([UInt8])
    /// Nothing arrived before the transfer's own deadline.
    case idle
    /// The transfer failed at the USB layer.
    case failure
}

/// Accumulates exactly the requested number of payload bytes from FTDI bulk-IN
/// transfers, buffering any surplus for the next call.
///
/// libdivecomputer's read contract, which every driver relies on, is "return
/// exactly `size` bytes or `DC_STATUS_TIMEOUT`" and never a short success. Two
/// separate things make that non-trivial here:
///
/// 1. USB delivers one bulk packet at a time, so a large device response
///    arrives across several transfers. Returning the first one truncates the
///    packet and desyncs the driver's framing, which is what made issue #334
///    fail with "Unexpected packet trailer byte".
/// 2. Each FTDI packet is prefixed with two modem-status bytes that are not
///    payload, so the byte counts at the USB layer and at the driver layer
///    differ, and surplus payload can straddle a packet boundary.
///
/// Reads are always issued one whole packet at a time. Asking for a partial
/// packet risks an overflow condition on the host controller, which is the
/// same constraint the Android side hit in issue #318.
final class FtdiReadAccumulator {
    private let packetSize: Int
    private var pending: [UInt8] = []

    /// - Parameter packetSize: the bulk-IN endpoint's maximum packet size,
    ///   read from the endpoint descriptor (64 on full-speed FTDI parts).
    init(packetSize: Int) {
        self.packetSize = packetSize
    }

    /// Payload bytes buffered from a previous read.
    var pendingCount: Int { pending.count }

    /// Drops buffered payload. Backs the `purge` callback: after libdivecomputer
    /// purges the input direction, bytes received before the purge must not
    /// surface in a later read.
    func discardPending() {
        pending.removeAll(keepingCapacity: true)
    }

    /// Reads exactly `size` payload bytes into `buffer`.
    ///
    /// `timeoutMs` follows libdivecomputer semantics: negative blocks
    /// indefinitely, zero polls without blocking, positive bounds the total
    /// wait across every transfer this call makes.
    ///
    /// - Parameter readPacket: issues one bulk-IN transfer, given the
    ///   milliseconds remaining before the deadline.
    func read(
        into buffer: UnsafeMutableRawPointer, size: Int, timeoutMs: Int32,
        readPacket: (Int32) -> FtdiPacketResult
    ) -> FtdiReadOutcome {
        guard size > 0 else { return FtdiReadOutcome(status: .success, bytesRead: 0) }

        // Absolute monotonic deadline, computed once, so the total wait is
        // bounded no matter how many transfers it takes.
        var deadlineNanos: UInt64 = 0
        var deadlineInitialized = false

        // The loop is labelled because the exits live inside a switch, where a
        // bare `break` would leave the switch and keep looping forever.
        readLoop: while pending.count < size {
            let remainingMs: Int32
            if timeoutMs > 0 {
                let now = DispatchTime.now().uptimeNanoseconds
                if !deadlineInitialized {
                    deadlineNanos = now &+ UInt64(timeoutMs) &* 1_000_000
                    deadlineInitialized = true
                    remainingMs = timeoutMs
                } else if now < deadlineNanos {
                    // Round up to the next millisecond so a transfer is never
                    // issued with a zero deadline while time genuinely remains.
                    let remainingNanos = deadlineNanos - now
                    let millis = (remainingNanos + 999_999) / 1_000_000
                    remainingMs = millis > UInt64(Int32.max) ? Int32.max : Int32(millis)
                } else {
                    remainingMs = 0
                }
                if remainingMs == 0 { break readLoop }
            } else if timeoutMs == 0 {
                remainingMs = 0
            } else {
                remainingMs = -1
            }

            switch readPacket(remainingMs) {
            case .failure:
                let delivered = min(pending.count, size)
                copyOut(to: buffer, count: delivered)
                return FtdiReadOutcome(status: .io, bytesRead: delivered)
            case .idle:
                // Nothing arrived within this transfer's own deadline. With a
                // non-blocking budget there is nothing left to wait for;
                // otherwise loop and let the deadline decide.
                if timeoutMs == 0 { break readLoop }
            case .packet(let raw):
                // A packet carrying only the status header is the chip's
                // keep-alive. It contributes no payload but is not
                // end-of-stream, so keep waiting rather than giving up.
                pending.append(
                    contentsOf: FtdiProtocol.stripStatusBytes(
                        from: raw[...], packetSize: packetSize))
            }
        }

        if pending.count >= size {
            copyOut(to: buffer, count: size)
            return FtdiReadOutcome(status: .success, bytesRead: size)
        }

        // Short read: reported as a timeout, never as a partial success, because
        // libdivecomputer's contract has no partial success and a driver that
        // received one would read a mid-packet byte as a framing trailer. What
        // did arrive is still written out and counted, matching serial_posix.c,
        // which sets *actual even when it returns DC_STATUS_TIMEOUT.
        let delivered = pending.count
        copyOut(to: buffer, count: delivered)
        return FtdiReadOutcome(status: .timeout, bytesRead: delivered)
    }

    /// Moves `count` bytes out of the buffer and into `destination`.
    private func copyOut(to destination: UnsafeMutableRawPointer, count: Int) {
        guard count > 0 else { return }
        pending.withUnsafeBytes { source in
            destination.copyMemory(from: source.baseAddress!, byteCount: count)
        }
        pending.removeFirst(count)
    }
}
```

- [ ] **Step 5: Run the suite to verify it passes**

Run: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: PASS, ending with `FtdiReadAccumulatorTests: all assertions passed`.

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiReadAccumulator.swift \
        packages/libdivecomputer_plugin/darwin/Tests/FtdiReadAccumulatorTests/main.swift \
        packages/libdivecomputer_plugin/darwin/run_native_tests.sh
git commit -m "feat(dc): exact-size read accumulation for FTDI bulk transfers (#732)"
```

---

## Task 3: Dive-cable USB device enumeration

**Files:**
- Create: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/UsbFtdiDeviceEnumerator.swift`
- Test: `packages/libdivecomputer_plugin/darwin/Tests/UsbFtdiDeviceEnumeratorTests/main.swift`
- Modify: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `struct UsbFtdiDevice: Equatable { let vendorId: UInt16; let productId: UInt16; let locationId: UInt32; let productName: String; var cableName: String; var displayName: String }` and `enum UsbFtdiDeviceEnumerator` with `static let knownCables: [(vendorId: UInt16, productId: UInt16, cable: String)]`, `static func cableName(vendorId: UInt16, productId: UInt16) -> String?`, `static func isKnownDiveCable(vendorId: UInt16, productId: UInt16) -> Bool`, `static func enumerateDiveCables() -> [UsbFtdiDevice]`.

- [ ] **Step 1: Write the failing test**

Create `packages/libdivecomputer_plugin/darwin/Tests/UsbFtdiDeviceEnumeratorTests/main.swift`:

```swift
import Foundation

// Standalone tests for the dive-cable USB allowlist (issue #732).
//
// Only the classification half is exercised. enumerateDiveCables() walks the
// IOKit registry and needs real hardware, so it is deliberately kept as a thin
// wrapper around these pure functions.
//
// The allowlist is fail-closed on purpose. The raw-USB path opens a device and
// writes dive-computer handshake bytes to it, so it must never touch a device
// that merely happens to be an FTDI part: a user's Arduino, radio programming
// cable or JTAG probe is not a dive computer.
//
// Assertions use precondition() so they survive -O.

private func check(_ condition: Bool, _ message: String) {
    precondition(condition, message)
}

// The three FTDI cables. 0xF460 is the one issue #732 reports; the Linux
// kernel names it FTDI_OCEANIC_PID in drivers/usb/serial/ftdi_sio_ids.h.
check(UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0xF460),
    "the Oceanic/Aeris cable is recognised")
check(UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0xF680),
    "the Suunto cable is recognised")
check(UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0x87D0),
    "the Cressi Leonardo cable is recognised")

// Stock FTDI product IDs are claimed by macOS and appear as /dev/cu.usbserial
// nodes, so they belong to the serial path, not this one. Matching them here
// would mean opening the same hardware twice by two different routes.
check(!UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0x6001),
    "a stock FT232 is left to the serial path")
check(!UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0403, productId: 0x6015),
    "a stock FT231X is left to the serial path")

// Fail closed on everything else, including the right product ID under the
// wrong vendor.
check(!UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x1234, productId: 0xF460),
    "the product ID alone is not enough to match")
check(!UsbFtdiDeviceEnumerator.isKnownDiveCable(vendorId: 0x0000, productId: 0x0000),
    "an unknown device is rejected")

// The cable name is what the download log and the probe log show the user, so
// a matched device is always nameable.
check(UsbFtdiDeviceEnumerator.cableName(vendorId: 0x0403, productId: 0xF460) != nil,
    "a known cable has a name")
check(UsbFtdiDeviceEnumerator.cableName(vendorId: 0x0403, productId: 0x6001) == nil,
    "an unknown cable has no name")

for cable in UsbFtdiDeviceEnumerator.knownCables {
    check(UsbFtdiDeviceEnumerator.isKnownDiveCable(
            vendorId: cable.vendorId, productId: cable.productId),
        "every table entry matches itself: \(cable.cable)")
    check(!cable.cable.isEmpty, "every table entry is named")
}

// displayName prefers the descriptor string the device reports, because that
// is what the user sees on the cable's packaging, and falls back to our own
// label when the device reports nothing.
let named = UsbFtdiDevice(
    vendorId: 0x0403, productId: 0xF460, locationId: 0x14100000,
    productName: "USB Download Interface")
check(named.displayName == "USB Download Interface",
    "a device that names itself keeps its own name")

let anonymous = UsbFtdiDevice(
    vendorId: 0x0403, productId: 0xF460, locationId: 0x14100000, productName: "")
check(anonymous.displayName == anonymous.cableName,
    "a device that names itself nothing falls back to the cable label")
check(!anonymous.displayName.isEmpty, "the fallback is never empty")

print("UsbFtdiDeviceEnumeratorTests: all assertions passed")
```

- [ ] **Step 2: Register the suite in the native test harness**

Append to `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`:

```bash
# Dive-cable USB allowlist (issue #732). -framework IOKit satisfies the IOKit
# references in enumerateDiveCables(); the test itself calls only the pure
# classification functions.
swiftc -framework IOKit -o "$BUILD_DIR/usb_ftdi_device_enumerator_tests" \
    Sources/LibDCDarwin/UsbFtdiDeviceEnumerator.swift \
    Tests/UsbFtdiDeviceEnumeratorTests/main.swift

"$BUILD_DIR/usb_ftdi_device_enumerator_tests"
```

- [ ] **Step 3: Run the suite to verify it fails**

Run: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: FAIL. `swiftc` reports `cannot find 'UsbFtdiDeviceEnumerator' in scope`.

- [ ] **Step 4: Write the implementation**

Create `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/UsbFtdiDeviceEnumerator.swift`:

```swift
import Foundation
#if os(macOS)
import IOKit
import IOKit.usb
#endif

/// A USB device matched against the dive-cable allowlist.
struct UsbFtdiDevice: Equatable {
    let vendorId: UInt16
    let productId: UInt16
    /// IOKit `locationID`, which identifies the physical port. Used to reopen
    /// the same device later, since two identical cables share a product ID.
    let locationId: UInt32
    /// The USB product-name descriptor, empty when the device reports none.
    let productName: String

    /// The dive-cable label from the allowlist.
    var cableName: String {
        UsbFtdiDeviceEnumerator.cableName(vendorId: vendorId, productId: productId)
            ?? "USB device"
    }

    /// What to show in logs and probe messages: the device's own name when it
    /// has one, our label otherwise.
    var displayName: String {
        productName.isEmpty ? cableName : productName
    }
}

/// Finds dive-computer download cables that the operating system has not
/// exposed as serial ports.
///
/// The Aeris/Oceanic cable is an FTDI chip with a custom product ID that
/// Apple's AppleUSBFTDI driver does not claim, so macOS creates no
/// `/dev/cu.usbserial-*` node for it and `SerialPortEnumerator` finds nothing
/// (issue #732). The device is still present in the IOKit registry, and
/// because nothing has claimed it, it can be opened directly.
///
/// The classification is pure so it can be unit-tested standalone; only
/// `enumerateDiveCables()` touches IOKit, and only on macOS. This mirrors
/// `SerialPortEnumerator`.
enum UsbFtdiDeviceEnumerator {
    /// USB identifiers of dive-computer download cables driven over raw USB.
    ///
    /// Fail-closed by design. This path opens a device and writes dive-computer
    /// handshake bytes to it, so it must never match a device that merely
    /// happens to use an FTDI chip.
    ///
    /// Stock FTDI product IDs (0x6001, 0x6010, 0x6011, 0x6014, 0x6015) are
    /// deliberately absent: macOS claims those and publishes them as serial
    /// ports, so they belong to `SerialPortEnumerator`. Only the reprogrammed
    /// dive-vendor IDs are listed. macOS currently claims 0xF680 and 0x87D0
    /// too, so in practice only 0xF460 reaches this path today; the other two
    /// are here because Apple's list has changed between OS releases before.
    static let knownCables: [(vendorId: UInt16, productId: UInt16, cable: String)] = [
        // Linux names this FTDI_OCEANIC_PID in drivers/usb/serial/ftdi_sio_ids.h.
        (0x0403, 0xF460, "Oceanic / Aeris / Sherwood / Hollis cable"),
        (0x0403, 0xF680, "Suunto Sports Instrument cable"),
        (0x0403, 0x87D0, "Cressi Leonardo cable"),
    ]

    /// The cable label for a USB identifier pair, or nil if it is not one of
    /// ours.
    static func cableName(vendorId: UInt16, productId: UInt16) -> String? {
        knownCables.first {
            $0.vendorId == vendorId && $0.productId == productId
        }?.cable
    }

    /// True if this identifier pair names a dive-computer download cable.
    static func isKnownDiveCable(vendorId: UInt16, productId: UInt16) -> Bool {
        cableName(vendorId: vendorId, productId: productId) != nil
    }

    #if os(macOS)
    /// Lists attached dive cables, reporting every USB device considered
    /// through `log`.
    ///
    /// The reporting is not incidental. Nobody working on this has the
    /// hardware, so a user's debug log has to distinguish "the cable is not
    /// enumerating at all" from "it enumerated but the allowlist rejected it"
    /// without another round trip.
    ///
    /// Logging goes through an injected closure rather than `NativeLogger`
    /// because `NativeLogger` holds a Pigeon `DiveComputerFlutterApi`, which
    /// only exists inside the CocoaPods build. Depending on it here would make
    /// this file impossible to compile standalone, and standalone compilation
    /// is the whole reason the allowlist lives in its own file.
    ///
    /// Matches on the legacy `IOUSBDevice` class name rather than
    /// `IOUSBHostDevice`. Devices are registered under both, and `IOUSBDevice`
    /// is what libusb's Darwin backend matches on, so it is the better-proven
    /// spelling across macOS releases.
    static func enumerateDiveCables(log: ((String) -> Void)? = nil) -> [UsbFtdiDevice] {
        guard let matching = IOServiceMatching("IOUSBDevice") else { return [] }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == KERN_SUCCESS else {
            log?("IOServiceGetMatchingServices failed: \(kr)")
            return []
        }
        defer { IOObjectRelease(iterator) }

        var devices: [UsbFtdiDevice] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let vendorId = numberProperty(service, "idVendor").map({ UInt16($0 & 0xFFFF) }),
                  let productId = numberProperty(service, "idProduct").map({ UInt16($0 & 0xFFFF) })
            else { continue }

            let locationId = UInt32(numberProperty(service, "locationID") ?? 0)
            let productName = stringProperty(service, "USB Product Name") ?? ""

            let idText = String(format: "0x%04X:0x%04X", vendorId, productId)
            if isKnownDiveCable(vendorId: vendorId, productId: productId) {
                log?("USB \(idText) '\(productName)' matched the dive-cable allowlist")
                devices.append(UsbFtdiDevice(
                    vendorId: vendorId, productId: productId,
                    locationId: locationId, productName: productName))
            } else {
                log?("USB \(idText) '\(productName)' is not a known dive cable")
            }
        }

        return devices
    }

    private static func numberProperty(_ service: io_service_t, _ key: String) -> UInt64? {
        guard let value = IORegistryEntryCreateCFProperty(
            service, key as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? NSNumber else { return nil }
        return value.uint64Value
    }

    private static func stringProperty(_ service: io_service_t, _ key: String) -> String? {
        IORegistryEntryCreateCFProperty(
            service, key as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String
    }
    #else
    /// Raw USB host access is not available on iOS.
    static func enumerateDiveCables() -> [UsbFtdiDevice] { [] }
    #endif
}
```

- [ ] **Step 5: Confirm the file has no Flutter dependency**

The suite compiles `UsbFtdiDeviceEnumerator.swift` on its own, and the `#if os(macOS)` branch is live when building on macOS, so anything that branch references must also compile standalone.

Run: `grep -n "NativeLogger\|Flutter\|Pigeon" packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/UsbFtdiDeviceEnumerator.swift`

Expected: no matches. `NativeLogger` holds a `DiveComputerFlutterApi`, a Pigeon type that only exists inside the CocoaPods build, so referencing it here would break the standalone compile. That is why `enumerateDiveCables` takes a `log` closure instead; Task 6 supplies one that forwards to `NativeLogger`.

- [ ] **Step 6: Run the suite to verify it passes**

Run: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: PASS, ending with `UsbFtdiDeviceEnumeratorTests: all assertions passed`.

- [ ] **Step 7: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/UsbFtdiDeviceEnumerator.swift \
        packages/libdivecomputer_plugin/darwin/Tests/UsbFtdiDeviceEnumeratorTests/main.swift \
        packages/libdivecomputer_plugin/darwin/run_native_tests.sh
git commit -m "feat(dc): enumerate dive-computer USB cables macOS leaves unclaimed (#732)"
```

---

## Task 4: IOUSBLib transport shim

**Files:**
- Create: `packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.h`
- Create: `packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.c`
- Create: `packages/libdivecomputer_plugin/ios/Classes/ftdi_usb_darwin.c` (symlink)
- Create: `packages/libdivecomputer_plugin/ios/Classes/ftdi_usb_darwin.h` (symlink)
- Modify: `packages/libdivecomputer_plugin/macos/libdivecomputer_plugin.podspec`
- Modify: `packages/libdivecomputer_plugin/ios/libdivecomputer_plugin.podspec`

**Interfaces:**
- Consumes: nothing.
- Produces: opaque `ftdi_usb_handle_t` plus `int ftdi_usb_open(uint32_t location_id, ftdi_usb_handle_t **out_handle)`, `int ftdi_usb_control(ftdi_usb_handle_t *handle, uint8_t request_type, uint8_t request, uint16_t value, uint16_t index, uint32_t timeout_ms)`, `int ftdi_usb_bulk_read(ftdi_usb_handle_t *handle, void *buffer, size_t size, size_t *actual, uint32_t timeout_ms)`, `int ftdi_usb_bulk_write(ftdi_usb_handle_t *handle, const void *buffer, size_t size, size_t *actual, uint32_t timeout_ms)`, `size_t ftdi_usb_max_packet_size(const ftdi_usb_handle_t *handle)`, `void ftdi_usb_close(ftdi_usb_handle_t *handle)`. All `int` returns are `IOReturn` values, so `0` (`kIOReturnSuccess`) means success.

There is no unit test for this task. It is pure IOKit plumbing that cannot run without the physical cable, which is exactly why every decision with logic in it lives in Tasks 1 to 3. Verification here is "it compiles and links into a real app build".

- [ ] **Step 1: Write the header**

Create `packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.h`:

```c
#ifndef FTDI_USB_DARWIN_H
#define FTDI_USB_DARWIN_H

#include <stddef.h>
#include <stdint.h>

// Raw USB access to an FTDI USB-to-serial bridge that no operating system
// driver has claimed.
//
// The Aeris/Oceanic dive-computer cable is an FTDI chip carrying a custom USB
// product ID. Apple's AppleUSBFTDI driver does not match it, so macOS creates
// no /dev/cu.* node and the serial transport has nothing to open (issue #732).
// Nothing having claimed the device is also what lets this code claim it.
//
// This layer knows nothing about FTDI. It moves bytes and control requests;
// the wire protocol lives in FtdiProtocol.swift, where it can be unit-tested.
//
// Deliberately free of IOKit types and headers so the declarations are safe in
// the iOS umbrella header. On platforms without USB host support every
// function is a stub returning kIOReturnUnsupported.
//
// All functions return an IOReturn value: 0 (kIOReturnSuccess) means success.

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ftdi_usb_handle ftdi_usb_handle_t;

// Opens the USB device at `location_id`, claims its first interface and
// resolves the bulk IN and OUT pipes. On success stores a handle the caller
// must release with ftdi_usb_close.
int ftdi_usb_open(uint32_t location_id, ftdi_usb_handle_t **out_handle);

// Sends a vendor control request with no data stage.
int ftdi_usb_control(ftdi_usb_handle_t *handle, uint8_t request_type,
                     uint8_t request, uint16_t value, uint16_t index,
                     uint32_t timeout_ms);

// Reads from the bulk IN pipe. `size` should be a whole number of maximum-size
// packets; a partial-packet request risks an overflow on the host controller.
// Returns kIOReturnTimeout with *actual set to 0 when nothing arrives.
int ftdi_usb_bulk_read(ftdi_usb_handle_t *handle, void *buffer, size_t size,
                       size_t *actual, uint32_t timeout_ms);

// Writes to the bulk OUT pipe.
int ftdi_usb_bulk_write(ftdi_usb_handle_t *handle, const void *buffer,
                        size_t size, size_t *actual, uint32_t timeout_ms);

// Maximum packet size of the bulk IN endpoint, from its descriptor. Returns 0
// for a null handle.
size_t ftdi_usb_max_packet_size(const ftdi_usb_handle_t *handle);

// Closes the interface and device and frees the handle. Safe on NULL.
void ftdi_usb_close(ftdi_usb_handle_t *handle);

#ifdef __cplusplus
}
#endif

#endif  // FTDI_USB_DARWIN_H
```

- [ ] **Step 2: Write the implementation**

Create `packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.c`:

```c
#include "ftdi_usb_darwin.h"

#include <TargetConditionals.h>

#if TARGET_OS_OSX

#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <stdlib.h>
#include <string.h>

struct ftdi_usb_handle {
    IOUSBDeviceInterface300 **device;
    IOUSBInterfaceInterface300 **interface;
    UInt8 pipe_in;
    UInt8 pipe_out;
    UInt16 max_packet_size;
};

// Resolves the io_service_t for the USB device at `location_id`.
// Returns 0 when no such device is present.
static io_service_t find_device(uint32_t location_id) {
    CFMutableDictionaryRef matching = IOServiceMatching("IOUSBDevice");
    if (matching == NULL) {
        return 0;
    }

    io_iterator_t iterator = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
            != KERN_SUCCESS) {
        return 0;
    }

    io_service_t found = 0;
    io_service_t service;
    while ((service = IOIteratorNext(iterator)) != 0) {
        CFTypeRef value = IORegistryEntryCreateCFProperty(
            service, CFSTR("locationID"), kCFAllocatorDefault, 0);
        uint32_t candidate = 0;
        if (value != NULL) {
            if (CFGetTypeID(value) == CFNumberGetTypeID()) {
                CFNumberGetValue((CFNumberRef)value, kCFNumberSInt32Type, &candidate);
            }
            CFRelease(value);
        }
        if (candidate == location_id) {
            found = service;
            break;
        }
        IOObjectRelease(service);
    }

    IOObjectRelease(iterator);
    return found;
}

// Opens the device's first interface and resolves its bulk pipes.
static IOReturn open_interface(ftdi_usb_handle_t *handle) {
    IOUSBFindInterfaceRequest request;
    request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting = kIOUSBFindInterfaceDontCare;

    io_iterator_t iterator = 0;
    IOReturn rc = (*handle->device)->CreateInterfaceIterator(
        handle->device, &request, &iterator);
    if (rc != kIOReturnSuccess) {
        return rc;
    }

    io_service_t usb_interface = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (usb_interface == 0) {
        return kIOReturnNoDevice;
    }

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;
    rc = IOCreatePlugInInterfaceForService(
        usb_interface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID,
        &plugin, &score);
    IOObjectRelease(usb_interface);
    if (rc != kIOReturnSuccess || plugin == NULL) {
        return rc == kIOReturnSuccess ? kIOReturnNoResources : rc;
    }

    HRESULT hr = (*plugin)->QueryInterface(
        plugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID300),
        (LPVOID *)&handle->interface);
    (*plugin)->Release(plugin);
    if (hr != S_OK || handle->interface == NULL) {
        return kIOReturnNoResources;
    }

    // Claims the interface exclusively. This is the call the App Sandbox gates
    // behind com.apple.security.device.usb; without that entitlement it fails
    // rather than returning bad data, so the error is worth surfacing verbatim.
    rc = (*handle->interface)->USBInterfaceOpen(handle->interface);
    if (rc != kIOReturnSuccess) {
        return rc;
    }

    UInt8 endpoint_count = 0;
    rc = (*handle->interface)->GetNumEndpoints(handle->interface, &endpoint_count);
    if (rc != kIOReturnSuccess) {
        return rc;
    }

    // Pipe 0 is the default control pipe, so data endpoints start at 1.
    for (UInt8 pipe = 1; pipe <= endpoint_count; pipe++) {
        UInt8 direction = 0;
        UInt8 number = 0;
        UInt8 transfer_type = 0;
        UInt16 packet_size = 0;
        UInt8 interval = 0;
        rc = (*handle->interface)->GetPipeProperties(
            handle->interface, pipe, &direction, &number, &transfer_type,
            &packet_size, &interval);
        if (rc != kIOReturnSuccess || transfer_type != kUSBBulk) {
            continue;
        }
        if (direction == kUSBIn && handle->pipe_in == 0) {
            handle->pipe_in = pipe;
            handle->max_packet_size = packet_size;
        } else if (direction == kUSBOut && handle->pipe_out == 0) {
            handle->pipe_out = pipe;
        }
    }

    if (handle->pipe_in == 0 || handle->pipe_out == 0) {
        return kIOReturnNotFound;
    }
    return kIOReturnSuccess;
}

int ftdi_usb_open(uint32_t location_id, ftdi_usb_handle_t **out_handle) {
    if (out_handle == NULL) {
        return kIOReturnBadArgument;
    }
    *out_handle = NULL;

    io_service_t service = find_device(location_id);
    if (service == 0) {
        return kIOReturnNoDevice;
    }

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;
    IOReturn rc = IOCreatePlugInInterfaceForService(
        service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin,
        &score);
    IOObjectRelease(service);
    if (rc != kIOReturnSuccess || plugin == NULL) {
        return rc == kIOReturnSuccess ? kIOReturnNoResources : rc;
    }

    ftdi_usb_handle_t *handle = calloc(1, sizeof(*handle));
    if (handle == NULL) {
        (*plugin)->Release(plugin);
        return kIOReturnNoMemory;
    }

    HRESULT hr = (*plugin)->QueryInterface(
        plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID300),
        (LPVOID *)&handle->device);
    (*plugin)->Release(plugin);
    if (hr != S_OK || handle->device == NULL) {
        free(handle);
        return kIOReturnNoResources;
    }

    rc = (*handle->device)->USBDeviceOpen(handle->device);
    if (rc != kIOReturnSuccess) {
        (*handle->device)->Release(handle->device);
        free(handle);
        return rc;
    }

    // An unclaimed device may still be unconfigured, because macOS sets the
    // configuration when a driver matches and no driver matched this one.
    UInt8 configuration = 0;
    if ((*handle->device)->GetConfiguration(handle->device, &configuration)
            == kIOReturnSuccess && configuration == 0) {
        IOUSBConfigurationDescriptorPtr descriptor = NULL;
        if ((*handle->device)->GetConfigurationDescriptorPtr(
                handle->device, 0, &descriptor) == kIOReturnSuccess
            && descriptor != NULL) {
            (*handle->device)->SetConfiguration(
                handle->device, descriptor->bConfigurationValue);
        }
    }

    rc = open_interface(handle);
    if (rc != kIOReturnSuccess) {
        ftdi_usb_close(handle);
        return rc;
    }

    *out_handle = handle;
    return kIOReturnSuccess;
}

int ftdi_usb_control(ftdi_usb_handle_t *handle, uint8_t request_type,
                     uint8_t request, uint16_t value, uint16_t index,
                     uint32_t timeout_ms) {
    if (handle == NULL || handle->device == NULL) {
        return kIOReturnNotOpen;
    }

    IOUSBDevRequestTO req;
    memset(&req, 0, sizeof(req));
    req.bmRequestType = request_type;
    req.bRequest = request;
    req.wValue = value;
    req.wIndex = index;
    req.wLength = 0;
    req.pData = NULL;
    req.noDataTimeout = timeout_ms;
    req.completionTimeout = timeout_ms;

    return (*handle->device)->DeviceRequestTO(handle->device, &req);
}

int ftdi_usb_bulk_read(ftdi_usb_handle_t *handle, void *buffer, size_t size,
                       size_t *actual, uint32_t timeout_ms) {
    if (actual != NULL) {
        *actual = 0;
    }
    if (handle == NULL || handle->interface == NULL) {
        return kIOReturnNotOpen;
    }
    if (size == 0) {
        return kIOReturnSuccess;
    }

    UInt32 transferred = (UInt32)size;
    IOReturn rc = (*handle->interface)->ReadPipeTO(
        handle->interface, handle->pipe_in, buffer, &transferred, timeout_ms,
        timeout_ms);
    // A timeout still reports whatever arrived before it expired.
    if (rc == kIOReturnSuccess || rc == kIOReturnTimeout) {
        if (actual != NULL) {
            *actual = (size_t)transferred;
        }
    }
    return rc;
}

int ftdi_usb_bulk_write(ftdi_usb_handle_t *handle, const void *buffer,
                        size_t size, size_t *actual, uint32_t timeout_ms) {
    if (actual != NULL) {
        *actual = 0;
    }
    if (handle == NULL || handle->interface == NULL) {
        return kIOReturnNotOpen;
    }
    if (size == 0) {
        return kIOReturnSuccess;
    }

    IOReturn rc = (*handle->interface)->WritePipeTO(
        handle->interface, handle->pipe_out, (void *)buffer, (UInt32)size,
        timeout_ms, timeout_ms);
    if (rc == kIOReturnSuccess && actual != NULL) {
        *actual = size;
    }
    return rc;
}

size_t ftdi_usb_max_packet_size(const ftdi_usb_handle_t *handle) {
    return handle == NULL ? 0 : (size_t)handle->max_packet_size;
}

void ftdi_usb_close(ftdi_usb_handle_t *handle) {
    if (handle == NULL) {
        return;
    }
    if (handle->interface != NULL) {
        (*handle->interface)->USBInterfaceClose(handle->interface);
        (*handle->interface)->Release(handle->interface);
    }
    if (handle->device != NULL) {
        (*handle->device)->USBDeviceClose(handle->device);
        (*handle->device)->Release(handle->device);
    }
    free(handle);
}

#else  // TARGET_OS_OSX

// iOS and every other Apple platform have no USB host support. The stubs keep
// the symbols resolvable so callers need no conditional compilation.

#include <IOKit/IOReturn.h>

int ftdi_usb_open(uint32_t location_id, ftdi_usb_handle_t **out_handle) {
    (void)location_id;
    if (out_handle != NULL) {
        *out_handle = NULL;
    }
    return kIOReturnUnsupported;
}

int ftdi_usb_control(ftdi_usb_handle_t *handle, uint8_t request_type,
                     uint8_t request, uint16_t value, uint16_t index,
                     uint32_t timeout_ms) {
    (void)handle; (void)request_type; (void)request;
    (void)value; (void)index; (void)timeout_ms;
    return kIOReturnUnsupported;
}

int ftdi_usb_bulk_read(ftdi_usb_handle_t *handle, void *buffer, size_t size,
                       size_t *actual, uint32_t timeout_ms) {
    (void)handle; (void)buffer; (void)size; (void)timeout_ms;
    if (actual != NULL) {
        *actual = 0;
    }
    return kIOReturnUnsupported;
}

int ftdi_usb_bulk_write(ftdi_usb_handle_t *handle, const void *buffer,
                        size_t size, size_t *actual, uint32_t timeout_ms) {
    (void)handle; (void)buffer; (void)size; (void)timeout_ms;
    if (actual != NULL) {
        *actual = 0;
    }
    return kIOReturnUnsupported;
}

size_t ftdi_usb_max_packet_size(const ftdi_usb_handle_t *handle) {
    (void)handle;
    return 0;
}

void ftdi_usb_close(ftdi_usb_handle_t *handle) {
    (void)handle;
}

#endif  // TARGET_OS_OSX
```

If `IOKit/IOReturn.h` is not available on the iOS SDK, replace the stub include with `#define kIOReturnUnsupported 0xE00002C7` and a comment naming it as IOKit's `kIOReturnUnsupported`.

- [ ] **Step 3: Create the iOS symlinks**

The iOS pod compiles the same C sources through symlinks, matching how `libdc_download.c` is shared:

```bash
cd packages/libdivecomputer_plugin/ios/Classes
ln -s ../../macos/Classes/ftdi_usb_darwin.c ftdi_usb_darwin.c
ln -s ../../macos/Classes/ftdi_usb_darwin.h ftdi_usb_darwin.h
cd -
ls -la packages/libdivecomputer_plugin/ios/Classes/ftdi_usb_darwin.*
```

Expected: both entries are symlinks resolving into `macos/Classes/`.

- [ ] **Step 4: Expose the header and link IOKit**

In `packages/libdivecomputer_plugin/macos/libdivecomputer_plugin.podspec`, change the public header line and add the framework:

```ruby
  s.public_header_files = 'Classes/{libdc_wrapper,ftdi_usb_darwin}.h'
  s.frameworks       = 'IOKit'
```

Swift can only see a C declaration that is in the pod's umbrella header, which CocoaPods builds from `public_header_files`. Leaving the new header out would make `FtdiUsbIoStream.swift` in Task 5 fail to compile. `IOKit` must be named explicitly because a C file gets no autolink directive the way a Swift `import IOKit` does.

In `packages/libdivecomputer_plugin/ios/libdivecomputer_plugin.podspec`, change only the header line:

```ruby
  s.public_header_files = 'Classes/{libdc_wrapper,ftdi_usb_darwin}.h'
```

Do not add `IOKit` to the iOS podspec; it is not a public iOS framework and the file compiles to stubs there.

- [ ] **Step 5: Verify it compiles standalone**

Before involving CocoaPods, check the C on its own:

Run:
```bash
clang -fsyntax-only -framework IOKit \
  packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.c
```
Expected: no output, exit status 0.

- [ ] **Step 6: Verify it builds in the app**

Because a new file was added to `Classes/`, CocoaPods must regenerate the pod target or Xcode will not see it.

Run:
```bash
cd macos && pod install && cd -
flutter build macos --debug
```
Expected: the build succeeds and links.

If the build fails with a missing `ftdi_usb_darwin.h`, the umbrella header was not regenerated: remove `macos/Pods` and `macos/Podfile.lock`, then run `pod install` again.

- [ ] **Step 7: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.c \
        packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.h \
        packages/libdivecomputer_plugin/ios/Classes/ftdi_usb_darwin.c \
        packages/libdivecomputer_plugin/ios/Classes/ftdi_usb_darwin.h \
        packages/libdivecomputer_plugin/macos/libdivecomputer_plugin.podspec \
        packages/libdivecomputer_plugin/ios/libdivecomputer_plugin.podspec
git commit -m "feat(dc): IOUSBLib shim for unclaimed FTDI dive cables (#732)"
```

---

## Task 5: The FTDI iostream

**Files:**
- Create: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiUsbIoStream.swift`
- Create: `packages/libdivecomputer_plugin/macos/Classes/FtdiProtocol.swift`, `FtdiReadAccumulator.swift`, `UsbFtdiDeviceEnumerator.swift`, `FtdiUsbIoStream.swift` (symlinks)
- Create: the same four symlinks under `packages/libdivecomputer_plugin/ios/Classes/`

**Interfaces:**
- Consumes: `FtdiProtocol` (Task 1), `FtdiReadAccumulator` (Task 2), `UsbFtdiDevice` (Task 3), the C API from Task 4.
- Produces: `final class FtdiUsbIoStream` with `func open(device: UsbFtdiDevice) -> String?` (nil on success, otherwise the reason) and `func close()` and `func makeCallbacks() -> libdc_io_callbacks_t`.

This task has no standalone test: it is glue over a C API that needs hardware. Its logic lives in Tasks 1 and 2, which are tested.

- [ ] **Step 1: Write the implementation**

Create `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiUsbIoStream.swift`:

```swift
import Foundation

/// A libdivecomputer byte pipe backed by an FTDI chip driven over raw USB.
///
/// Serves dive-computer cables that no operating system driver claims, so no
/// serial device node exists for `SerialIoStream` to open (issue #732).
/// libdivecomputer is unaware of the difference: this fills the same
/// `libdc_io_callbacks_t` table, and the session is still opened with
/// `LIBDC_TRANSPORT_SERIAL`.
///
/// The caller must keep the stream alive while the callbacks are in use; the
/// userdata pointer is unretained, matching `SerialIoStream`.
final class FtdiUsbIoStream {
    private var handle: OpaquePointer?
    private var accumulator: FtdiReadAccumulator?
    private var packetSize = 64
    private var timeoutMs: Int32 = 10000

    deinit {
        close()
    }

    /// Opens `device` and puts the chip into a known state. Returns nil on
    /// success, or a human-readable reason the open failed.
    func open(device: UsbFtdiDevice) -> String? {
        var opened: OpaquePointer?
        let rc = ftdi_usb_open(device.locationId, &opened)
        guard rc == 0, let opened else {
            return "IOKit refused the USB device (IOReturn 0x\(String(format: "%08X", rc)))"
        }
        handle = opened

        let reported = ftdi_usb_max_packet_size(opened)
        // Fall back to the full-speed bulk maximum if the descriptor is
        // unreadable; a zero packet size would make every read a no-op.
        packetSize = reported > 0 ? Int(reported) : 64
        accumulator = FtdiReadAccumulator(packetSize: packetSize)

        // Reset the UART so the chip does not start mid-frame from whatever a
        // previous session left behind.
        if let failure = sendControl(.reset, value: 0) {
            close()
            return "Failed to reset the FTDI cable: \(failure)"
        }
        if let failure = sendControl(
            .setLatencyTimer, value: FtdiProtocol.defaultLatencyTimerMs
        ) {
            // Not fatal: the chip works at its 16 ms default, just slower.
            NativeLogger.w("FtdiUsb", category: "USB",
                "Could not set the latency timer: \(failure)")
        }

        NativeLogger.i("FtdiUsb", category: "USB",
            "Opened \(device.displayName) at location "
            + "0x\(String(format: "%08X", device.locationId)), "
            + "packet size \(packetSize)")
        return nil
    }

    func close() {
        if let handle {
            ftdi_usb_close(handle)
        }
        handle = nil
        accumulator = nil
    }

    /// Returns the callback table libdivecomputer drives this stream through.
    ///
    /// Every serial line-control slot is filled. The bridge in
    /// `libdc_download.c` silently no-ops a NULL slot, and the Oceanic Atom2
    /// driver pulses RTS with DTR held high before it will talk at all
    /// (`oceanic_atom2.c`), so a missing slot would look like a dead cable
    /// rather than a bug. This is the shape of issue #334.
    func makeCallbacks() -> libdc_io_callbacks_t {
        var callbacks = libdc_io_callbacks_t()
        callbacks.userdata = Unmanaged.passUnretained(self).toOpaque()
        callbacks.set_timeout = { userdata, timeout in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            stream.timeoutMs = Int32(timeout)
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.read = { userdata, data, size, actual in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performRead(data!, size: size, actual: actual!)
        }
        callbacks.write = { userdata, data, size, actual in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performWrite(data!, size: size, actual: actual!)
        }
        callbacks.close = { userdata in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            stream.close()
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.purge = { userdata, direction in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performPurge(direction)
        }
        callbacks.sleep = { _, milliseconds in
            Thread.sleep(forTimeInterval: Double(milliseconds) / 1000.0)
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.configure = { userdata, baudrate, databits, parity, stopbits, flowcontrol in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.performConfigure(
                baudRate: baudrate, dataBits: databits, parity: parity,
                stopBits: stopbits, flowControl: flowcontrol)
        }
        callbacks.set_dtr = { userdata, value in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.sendControl(
                .setModemControl,
                value: FtdiProtocol.modemControlValue(dtr: value != 0)
            ) == nil ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_IO)
        }
        callbacks.set_rts = { userdata, value in
            let stream = Unmanaged<FtdiUsbIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.sendControl(
                .setModemControl,
                value: FtdiProtocol.modemControlValue(rts: value != 0)
            ) == nil ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_IO)
        }
        // poll and ioctl are left NULL, as they are in the Windows backend.
        return callbacks
    }

    /// Sends a vendor control request. Returns nil on success or a description
    /// of the IOKit failure.
    private func sendControl(
        _ request: FtdiProtocol.Request, value: UInt16,
        index: UInt16 = FtdiProtocol.portIndex
    ) -> String? {
        guard let handle else { return "the cable is not open" }
        let rc = ftdi_usb_control(
            handle, FtdiProtocol.requestTypeOut, request.rawValue, value, index,
            UInt32(max(timeoutMs, 0)))
        return rc == 0 ? nil : "IOReturn 0x\(String(format: "%08X", rc))"
    }

    private func performRead(
        _ buffer: UnsafeMutableRawPointer, size: Int,
        actual: UnsafeMutablePointer<Int>
    ) -> Int32 {
        guard let handle, let accumulator else {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }

        let packetSize = self.packetSize
        let outcome = accumulator.read(
            into: buffer, size: size, timeoutMs: timeoutMs
        ) { remainingMs in
            var packet = [UInt8](repeating: 0, count: packetSize)
            var transferred = 0
            let rc = packet.withUnsafeMutableBytes { raw in
                ftdi_usb_bulk_read(
                    handle, raw.baseAddress, packetSize, &transferred,
                    UInt32(max(remainingMs, 0)))
            }
            // kIOReturnTimeout is the pipe having nothing to say right now,
            // which is normal between device replies. Anything else is a real
            // transport failure and must not be retried as if it were slow.
            if rc != 0 && rc != Int32(bitPattern: 0xE00002D6) {
                return .failure
            }
            return transferred > 0 ? .packet(Array(packet[0..<transferred])) : .idle
        }

        actual.pointee = outcome.bytesRead
        switch outcome.status {
        case .success: return Int32(LIBDC_STATUS_SUCCESS)
        case .timeout: return Int32(LIBDC_STATUS_TIMEOUT)
        case .io: return Int32(LIBDC_STATUS_IO)
        }
    }

    private func performWrite(
        _ buffer: UnsafeRawPointer, size: Int,
        actual: UnsafeMutablePointer<Int>
    ) -> Int32 {
        guard let handle else {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }

        var transferred = 0
        let rc = ftdi_usb_bulk_write(
            handle, buffer, size, &transferred, UInt32(max(timeoutMs, 0)))
        actual.pointee = transferred
        return rc == 0 ? Int32(LIBDC_STATUS_SUCCESS) : Int32(LIBDC_STATUS_IO)
    }

    private func performPurge(_ direction: UInt32) -> Int32 {
        guard handle != nil else { return Int32(LIBDC_STATUS_IO) }

        // Drop bytes already pulled off the pipe as well as the chip's own
        // buffers. Purging only the chip would leave pre-purge payload sitting
        // in the accumulator, to surface in the next read.
        if direction & 0x01 != 0 {
            accumulator?.discardPending()
        }
        for value in FtdiProtocol.resetValues(forDirection: direction) {
            if let failure = sendControl(.reset, value: value) {
                NativeLogger.w("FtdiUsb", category: "USB", "Purge failed: \(failure)")
                return Int32(LIBDC_STATUS_IO)
            }
        }
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func performConfigure(
        baudRate: UInt32, dataBits: UInt32, parity: UInt32,
        stopBits: UInt32, flowControl: UInt32
    ) -> Int32 {
        guard handle != nil else { return Int32(LIBDC_STATUS_IO) }

        guard let divisor = FtdiProtocol.baudDivisor(baudRate),
              let parityCode = FtdiProtocol.parity(fromLibdc: parity),
              let stopBitsCode = FtdiProtocol.stopBits(fromLibdc: stopBits),
              let flowControlCode = FtdiProtocol.flowControl(fromLibdc: flowControl),
              let dataWord = FtdiProtocol.dataWord(
                  dataBits: dataBits, parity: parityCode, stopBits: stopBitsCode)
        else {
            NativeLogger.e("FtdiUsb", category: "USB",
                "Unsupported line settings: \(baudRate) baud, \(dataBits) data bits, "
                + "parity \(parity), stop bits \(stopBits), flow control \(flowControl)")
            return Int32(LIBDC_STATUS_INVALIDARGS)
        }

        // SET_BAUD_RATE is the one request that does not put the port number in
        // wIndex: on single-port parts the field carries the divisor's high
        // bits instead (libftdi's ftdi_convert_baudrate, and ftdi_sio.c's
        // change_speed, which only ORs in an interface number for the
        // multi-port FT2232 family). Passing portIndex here would corrupt the
        // divisor.
        if let failure = sendControl(
            .setBaudRate, value: divisor.value, index: divisor.index
        ) {
            NativeLogger.e("FtdiUsb", category: "USB", "Failed to set baud rate: \(failure)")
            return Int32(LIBDC_STATUS_IO)
        }
        if let failure = sendControl(.setData, value: dataWord) {
            NativeLogger.e("FtdiUsb", category: "USB", "Failed to set line format: \(failure)")
            return Int32(LIBDC_STATUS_IO)
        }
        if let failure = sendControl(
            .setFlowControl, value: 0,
            index: flowControlCode.rawValue | FtdiProtocol.portIndex
        ) {
            NativeLogger.e("FtdiUsb", category: "USB", "Failed to set flow control: \(failure)")
            return Int32(LIBDC_STATUS_IO)
        }

        NativeLogger.i("FtdiUsb", category: "USB",
            "Configured \(baudRate) baud, \(dataBits) data bits, parity \(parity), "
            + "stop bits \(stopBits)")
        return Int32(LIBDC_STATUS_SUCCESS)
    }
}
```

- [ ] **Step 2: Replace the timeout literal with a helper**

`LIBDC_STATUS_INVALIDARGS` used above is real: it is `-2` in `macos/Classes/libdc_wrapper.h:40`. No change needed there.

The `0xE00002D6` literal in `performRead` is a placeholder for `kIOReturnTimeout` and must not survive. A bare hex IOKit code in Swift is exactly the sort of thing that rots silently. Add a helper to `ftdi_usb_darwin.h`, after `ftdi_usb_max_packet_size`:

```c
// True when `status` reports that nothing arrived before the deadline, as
// opposed to a real transport failure. The distinction matters upstream:
// libdivecomputer retries a timeout but treats an I/O error as fatal.
int ftdi_usb_status_is_timeout(int status);
```

In the macOS section of `ftdi_usb_darwin.c`:

```c
int ftdi_usb_status_is_timeout(int status) {
    return status == kIOReturnTimeout ? 1 : 0;
}
```

and in the stub section:

```c
int ftdi_usb_status_is_timeout(int status) {
    (void)status;
    return 0;
}
```

Then in `performRead`, replace

```swift
            if rc != 0 && rc != Int32(bitPattern: 0xE00002D6) {
                return .failure
            }
```

with

```swift
            if rc != 0 && ftdi_usb_status_is_timeout(rc) == 0 {
                return .failure
            }
```

- [ ] **Step 3: Create the symlinks for all four new Swift files**

A shared darwin Swift file is invisible to the CocoaPods build until it is symlinked into both platform `Classes/` directories:

```bash
cd packages/libdivecomputer_plugin/macos/Classes
for f in FtdiProtocol FtdiReadAccumulator UsbFtdiDeviceEnumerator FtdiUsbIoStream; do
  ln -s "../../darwin/Sources/LibDCDarwin/$f.swift" "$f.swift"
done
cd ../../ios/Classes
for f in FtdiProtocol FtdiReadAccumulator UsbFtdiDeviceEnumerator FtdiUsbIoStream; do
  ln -s "../../darwin/Sources/LibDCDarwin/$f.swift" "$f.swift"
done
cd -
ls -la packages/libdivecomputer_plugin/macos/Classes/Ftdi* \
       packages/libdivecomputer_plugin/ios/Classes/Ftdi*
```

Expected: eight symlinks in total, all resolving into `darwin/Sources/LibDCDarwin/`.

- [ ] **Step 4: Verify the app builds**

Run:
```bash
cd macos && pod install && cd -
flutter build macos --debug
```
Expected: success. A "cannot find `ftdi_usb_open` in scope" error means the header is not in the pod umbrella; re-check Task 4 Step 4.

- [ ] **Step 5: Run the native tests to confirm nothing regressed**

Run: `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
Expected: every suite passes.

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiUsbIoStream.swift \
        packages/libdivecomputer_plugin/macos/Classes/Ftdi*.swift \
        packages/libdivecomputer_plugin/macos/Classes/UsbFtdiDeviceEnumerator.swift \
        packages/libdivecomputer_plugin/ios/Classes/Ftdi*.swift \
        packages/libdivecomputer_plugin/ios/Classes/UsbFtdiDeviceEnumerator.swift \
        packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.h
git commit -m "feat(dc): libdivecomputer iostream over raw-USB FTDI cables (#732)"
```

---

## Task 6: Try raw-USB cables when no serial port works

**Files:**
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:379-500` (`performSerialDownload`)

**Interfaces:**
- Consumes: `UsbFtdiDeviceEnumerator.enumerateDiveCables()`, `FtdiUsbIoStream`, `SerialPortEnumerator`, `SerialIoStream`.
- Produces: `private enum DownloadCandidate` local to the file. No public surface changes.

- [ ] **Step 1: Read the current implementation**

Run: `sed -n '379,500p' packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`

Note the three behaviours that must survive: a single candidate reports the real open failure as `connect_failed`; multiple candidates buffer dives so a wrong port cannot leak phantom dives; a cancellation still flushes what was downloaded.

- [ ] **Step 2: Add the candidate abstraction**

Insert immediately above `performSerialDownload`:

```swift
    /// One thing worth trying as the byte pipe for a serial-transport download.
    ///
    /// Serial ports come first because they are what works today. Raw-USB
    /// cables are the fallback for hardware the operating system never
    /// published as a serial port at all: the Aeris/Oceanic cable is an FTDI
    /// chip with a custom product ID that Apple's driver does not claim, so no
    /// /dev/cu.* node exists for it (issue #732).
    private enum DownloadCandidate {
        case serialPort(String)
        case ftdiUsb(UsbFtdiDevice)

        /// Label for logs and the probe report shown to the user.
        var label: String {
            switch self {
            case .serialPort(let path): return path
            case .ftdiUsb(let device): return "\(device.displayName) (USB)"
            }
        }
    }

    /// Opens a candidate. Returns the stream plus its callbacks on success, or
    /// the reason it could not be opened.
    ///
    /// The stream is returned as AnyObject only to keep it alive; the caller
    /// stores it for the duration of the run because the callback userdata
    /// pointer is unretained.
    private func openCandidate(
        _ candidate: DownloadCandidate
    ) -> (stream: AnyObject, callbacks: libdc_io_callbacks_t, close: () -> Void)? {
        switch candidate {
        case .serialPort(let path):
            let stream = SerialIoStream()
            if let failure = stream.open(path: path) {
                NativeLogger.e("DiveComputerHost", category: "SER",
                    "Failed to open \(path) (errno=\(failure.errnoValue)): \(failure.reason)")
                lastCandidateFailure = failure.reason
                return nil
            }
            NativeLogger.i("DiveComputerHost", category: "SER", "Opened serial port: \(path)")
            return (stream, stream.makeCallbacks(), stream.close)
        case .ftdiUsb(let device):
            let stream = FtdiUsbIoStream()
            if let reason = stream.open(device: device) {
                NativeLogger.e("DiveComputerHost", category: "USB",
                    "Failed to open \(device.displayName): \(reason)")
                lastCandidateFailure = reason
                return nil
            }
            return (stream, stream.makeCallbacks(), stream.close)
        }
    }
```

Add the backing property next to `activeSerialStream`:

```swift
    /// Why the most recent candidate could not be opened, for the error the
    /// user sees when nothing opens at all.
    private var lastCandidateFailure = ""
```

- [ ] **Step 3: Build the candidate list**

Replace the opening of `performSerialDownload`, that is

```swift
        let transportValue = UInt32(LIBDC_TRANSPORT_SERIAL)
        let available = SerialPortEnumerator.enumerateUsbSerialPaths()
        let candidates = SerialPortEnumerator.candidatePorts(
            address: device.address, available: available)

        if candidates.isEmpty {
```

with

```swift
        let transportValue = UInt32(LIBDC_TRANSPORT_SERIAL)
        let available = SerialPortEnumerator.enumerateUsbSerialPaths()
        var candidates = SerialPortEnumerator.candidatePorts(
            address: device.address, available: available)
            .map { DownloadCandidate.serialPort($0) }

        // Cables the operating system never published as a serial port. Tried
        // after the serial ports so nothing that works today changes: a real
        // /dev node is always the better path when one exists. An explicit
        // /dev address means the user picked a specific port, so raw USB is
        // not second-guessed into the list.
        if !device.address.hasPrefix("/dev/") {
            // The log closure is how the enumerator reports what it saw; it
            // takes one rather than calling NativeLogger itself so the file
            // stays compilable outside the CocoaPods build. Every USB device is
            // reported, matched or not, so a user's debug log distinguishes a
            // cable that is not enumerating from one the allowlist rejected.
            let found = UsbFtdiDeviceEnumerator.enumerateDiveCables { message in
                NativeLogger.i("DiveComputerHost", category: "USB", message)
            }
            candidates.append(contentsOf: found.map { DownloadCandidate.ftdiUsb($0) })
        }

        if candidates.isEmpty {
```

Leave the `no_serial_ports` error and its message exactly as they are. It now fires only when there is neither a serial port nor a raw-USB cable, which is still "nothing to talk to", so the existing localized string remains accurate.

- [ ] **Step 4: Generalise the single-candidate path**

Replace the body of the `if candidates.count == 1` branch with:

```swift
        if candidates.count == 1 {
            let candidate = candidates[0]
            guard let opened = openCandidate(candidate) else {
                reportError(
                    code: "connect_failed",
                    message: "Failed to open \(candidate.label): \(lastCandidateFailure)")
                return
            }
            self.activeSerialStream = opened.stream
            let result = runOnce(
                session: session, device: device, transportValue: transportValue,
                ioCallbacks: opened.callbacks, fingerprint: fingerprint,
                downloadCallbacks: downloadCallbacks)
            opened.close()
            self.activeSerialStream = nil
            reportDownloadResult(result)
            return
        }
```

`activeSerialStream` is declared as `SerialIoStream?` today. Widen it to `AnyObject?` and check every other use:

Run: `grep -n "activeSerialStream" packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`

If any use calls a `SerialIoStream` method, keep two properties instead (`activeSerialStream` and `activeFtdiStream`) rather than casting. Do not force-cast.

- [ ] **Step 5: Generalise the probe loop**

In the multi-candidate loop, replace

```swift
        for port in candidates {
```

through the `stream.close()` and `self.activeSerialStream = nil` lines with:

```swift
        for candidate in candidates {
            diveBufferLock.lock()
            bufferedDives.removeAll()
            diveBufferLock.unlock()

            guard let opened = openCandidate(candidate) else {
                probeLog += "  \(candidate.label): \(lastCandidateFailure)\n"
                continue
            }
            anyOpened = true
            NativeLogger.i("DiveComputerHost", category: "SER",
                "Probing \(candidate.label)")
            self.activeSerialStream = opened.stream
            let result = runOnce(
                session: session, device: device, transportValue: transportValue,
                ioCallbacks: opened.callbacks, fingerprint: fingerprint,
                downloadCallbacks: downloadCallbacks)
            lastResult = result
            opened.close()
            self.activeSerialStream = nil

            if result.rc == 0 || result.rc == Int32(LIBDC_STATUS_CANCELLED) {
                break
            }
            probeLog += "  \(candidate.label): download failed (rc=\(result.rc))\n"
            NativeLogger.w("DiveComputerHost", category: "SER",
                "Probe failed on \(candidate.label) rc=\(result.rc)")
        }
```

Everything after the loop (the dive-buffer flush, `anyOpened`, the two `connect_failed` reports and `reportDownloadResult`) is unchanged.

- [ ] **Step 6: Update the doc comment**

Replace the comment above `performSerialDownload` with:

```swift
    /// Serial-transport download with auto-probe, mirroring the Linux/Windows
    /// backends.
    ///
    /// Candidates are the USB serial ports the operating system published,
    /// followed by any dive-computer USB cable it left unclaimed (issue #732:
    /// the Aeris/Oceanic cable is an FTDI chip with a custom product ID that
    /// Apple's driver does not match, so it never becomes a /dev/cu.* node).
    /// Serial ports come first, so a cable that already works keeps working.
    ///
    /// A single candidate is opened and run directly so the real failure is
    /// reported. Multiple candidates are each tried with a full download,
    /// buffering dives so a wrong candidate cannot leak phantom dives.
```

- [ ] **Step 7: Verify it builds and nothing regressed**

Run:
```bash
flutter build macos --debug
packages/libdivecomputer_plugin/darwin/run_native_tests.sh
```
Expected: both succeed.

- [ ] **Step 8: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift
git commit -m "feat(dc): fall back to raw-USB cables when no serial port answers (#732)"
```

---

## Task 7: The USB sandbox entitlement

**Files:**
- Modify: `macos/Runner/Release.entitlements`
- Modify: `macos/Runner/DebugProfile.entitlements`
- Test: `test/macos_entitlements_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing test**

In `test/macos_entitlements_test.dart`, inside the `for (final path in sandboxedEntitlements)` loop, add after the existing serial-port test:

```dart
      test('$path enables the USB device entitlement (issue #732)', () {
        // Some dive-computer cables are FTDI chips carrying a custom USB
        // product ID that macOS does not claim, so no /dev/cu.* node is ever
        // created and the serial entitlement above cannot help. Those cables
        // are driven over raw USB instead, which the sandbox gates on this
        // key: application.sb grants IOUSBDeviceUserClientV2 and
        // IOUSBInterfaceUserClientV3 only when it is present.
        expect(
          typesOf(path)['com.apple.security.device.usb'],
          'true',
          reason:
              'Sandboxed macOS builds cannot open a USB device directly '
              'without com.apple.security.device.usb. Removing it, or setting '
              'it to false, silently breaks downloads from dive computers '
              'whose cable macOS does not expose as a serial port (issue '
              '#732).',
        );
      });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/macos_entitlements_test.dart`
Expected: FAIL on both entitlement files, reporting `<null>` is not `'true'`.

- [ ] **Step 3: Add the entitlement**

In both `macos/Runner/Release.entitlements` and `macos/Runner/DebugProfile.entitlements`, add immediately after the `com.apple.security.device.serial` entry:

```xml
	<key>com.apple.security.device.usb</key>
	<true/>
```

Do not touch `macos/Runner/ReleaseNoSandbox.entitlements`: the sandbox is off there, so hardware entitlements are inert.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/macos_entitlements_test.dart`
Expected: PASS.

- [ ] **Step 5: Confirm the entitlement reaches a real build**

An entitlement is only real once it is in the signed bundle.

Run:
```bash
flutter build macos --debug
codesign -d --entitlements - --xml build/macos/Build/Products/Debug/*.app | plutil -p - | grep -i usb
```
Expected: `"com.apple.security.device.usb" => 1`.

If the key is absent, Xcode is using a stale entitlements file; clean with `flutter clean` and rebuild.

- [ ] **Step 6: Commit**

```bash
git add macos/Runner/Release.entitlements macos/Runner/DebugProfile.entitlements \
        test/macos_entitlements_test.dart
git commit -m "feat(macos): request the USB device entitlement for raw-USB cables (#732)"
```

---

## Task 8: Android dive-cable probe table

**Files:**
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveCableIds.kt`
- Test: `packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/DiveCableIdsTest.kt`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt:62`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt:506`

**Interfaces:**
- Consumes: the vendored `com.hoho.android.usbserial.driver` package.
- Produces: `object DiveCableIds` with `data class Cable(val vendorId: Int, val productId: Int, val driver: Class<out UsbSerialDriver>, val description: String)`, `val cables: List<Cable>`, `fun find(vendorId: Int, productId: Int): Cable?`, and `fun prober(): UsbSerialProber`.

- [ ] **Step 1: Write the failing test**

Create `packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/DiveCableIdsTest.kt`:

```kotlin
package com.submersion.libdivecomputer

import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
import com.hoho.android.usbserial.driver.FtdiSerialDriver
import com.hoho.android.usbserial.driver.ProlificSerialDriver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Dive-computer download cables use USB identifiers that no default probe
 * table lists, because the vendors reprogrammed stock bridge chips with their
 * own product IDs. On Android there is no kernel driver to fall back on, so an
 * unlisted cable is simply invisible (issue #732).
 *
 * These are plain-data assertions rather than driver instantiations: the
 * module has JUnit but no Robolectric, so android.hardware.usb.UsbDevice
 * cannot be constructed here.
 */
class DiveCableIdsTest {

    @Test
    fun `recognises the Oceanic and Aeris FTDI cable`() {
        // The Linux kernel names this FTDI_OCEANIC_PID in
        // drivers/usb/serial/ftdi_sio_ids.h. It is the cable from issue #732.
        val cable = DiveCableIds.find(0x0403, 0xF460)
        assertNotNull("0x0403:0xF460 must be a known cable", cable)
        assertEquals(FtdiSerialDriver::class.java, cable!!.driver)
    }

    @Test
    fun `recognises the other reprogrammed FTDI cables`() {
        assertEquals(FtdiSerialDriver::class.java, DiveCableIds.find(0x0403, 0xF680)?.driver)
        assertEquals(FtdiSerialDriver::class.java, DiveCableIds.find(0x0403, 0x87D0)?.driver)
    }

    @Test
    fun `recognises the non-FTDI cables with their own chip drivers`() {
        assertEquals(ProlificSerialDriver::class.java, DiveCableIds.find(0x04B8, 0x0521)?.driver)
        assertEquals(ProlificSerialDriver::class.java, DiveCableIds.find(0x04B8, 0x0522)?.driver)
        assertEquals(CdcAcmSerialDriver::class.java, DiveCableIds.find(0xFFFF, 0x0005)?.driver)
    }

    @Test
    fun `does not claim unrelated devices`() {
        assertNull("an unknown device is not a dive cable", DiveCableIds.find(0x1234, 0x5678))
        // The product ID alone must not be enough to match.
        assertNull("the vendor ID is part of the match", DiveCableIds.find(0x1234, 0xF460))
    }

    @Test
    fun `has no duplicate entries`() {
        // Subsurface's own table lists 0x04B8:0x0521 twice and never lists
        // 0x0522, so the Zeagle cable does not work there. Guard against
        // copying that.
        val keys = DiveCableIds.cables.map { it.vendorId to it.productId }
        assertEquals("every cable appears exactly once", keys.size, keys.toSet().size)
    }

    @Test
    fun `every entry is described`() {
        // The description is what an unfamiliar reader uses to decide whether
        // an entry is still needed.
        assertTrue(DiveCableIds.cables.isNotEmpty())
        assertTrue(
            "every cable carries a description",
            DiveCableIds.cables.all { it.description.isNotBlank() }
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/libdivecomputer_plugin/android && ./gradlew test --tests '*DiveCableIdsTest*'`

If the plugin module has no gradle wrapper, run it from the example or host app instead:
`cd android && ./gradlew :libdivecomputer_plugin:testDebugUnitTest`

Expected: FAIL to compile, `unresolved reference: DiveCableIds`.

- [ ] **Step 3: Write the implementation**

Create `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveCableIds.kt`:

```kotlin
package com.submersion.libdivecomputer

import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
import com.hoho.android.usbserial.driver.FtdiSerialDriver
import com.hoho.android.usbserial.driver.ProlificSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialProber

/**
 * USB identifiers of dive-computer download cables, and the bridge-chip driver
 * each one needs.
 *
 * Dive-computer vendors buy stock USB-to-serial bridge chips and reprogram
 * them with their own product IDs, so a default probe table does not recognise
 * them. On desktop platforms a kernel or vendor driver usually picks them up
 * anyway; on Android there is none, so an unlisted cable is invisible to the
 * app no matter what the user does (issue #732).
 *
 * Registering an identifier here is additive: it can only make a device
 * recognised that previously was not.
 */
object DiveCableIds {

    data class Cable(
        val vendorId: Int,
        val productId: Int,
        val driver: Class<out UsbSerialDriver>,
        val description: String,
    )

    val cables: List<Cable> = listOf(
        // FTDI chips with reprogrammed product IDs. The Linux kernel names the
        // first of these FTDI_OCEANIC_PID in drivers/usb/serial/ftdi_sio_ids.h.
        Cable(0x0403, 0xF460, FtdiSerialDriver::class.java,
            "Oceanic / Aeris / Sherwood / Hollis cable"),
        Cable(0x0403, 0xF680, FtdiSerialDriver::class.java,
            "Suunto Sports Instrument cable"),
        Cable(0x0403, 0x87D0, FtdiSerialDriver::class.java,
            "Cressi Leonardo cable"),

        // Seiko/Epson bridge chips, handled by the Prolific driver.
        Cable(0x04B8, 0x0521, ProlificSerialDriver::class.java,
            "Mares Nemo and Cressi cable"),
        Cable(0x04B8, 0x0522, ProlificSerialDriver::class.java,
            "Zeagle cable"),

        // The Mares Icon HD presents a CDC-ACM interface under a placeholder
        // vendor ID.
        Cable(0xFFFF, 0x0005, CdcAcmSerialDriver::class.java,
            "Mares Icon HD cable"),
    )

    /** The cable with these USB identifiers, or null if it is not one of ours. */
    fun find(vendorId: Int, productId: Int): Cable? =
        cables.firstOrNull { it.vendorId == vendorId && it.productId == productId }

    /**
     * A prober that knows the stock identifiers plus every dive cable above.
     *
     * Built fresh on each call, because [UsbSerialProber.getDefaultProbeTable]
     * returns a new table each time and mutating a shared one would compound
     * entries.
     */
    fun prober(): UsbSerialProber {
        val table = UsbSerialProber.getDefaultProbeTable()
        for (cable in cables) {
            table.addProduct(cable.vendorId, cable.productId, cable.driver)
        }
        return UsbSerialProber(table)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd packages/libdivecomputer_plugin/android && ./gradlew test --tests '*DiveCableIdsTest*'`
Expected: PASS, six tests.

If `UsbSerialProber.getDefaultProbeTable()` turns out not to be public in the vendored v3.9.0, build the table with `ProbeTable()` and call `addProduct` for both the dive cables and the stock identifiers from `UsbSerialProber.getDefaultProbeTable`'s source. Do not modify the vendored sources: see `android/third_party/usb-serial-for-android/VENDORED.md`.

- [ ] **Step 5: Use the prober at both call sites**

In `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt`, replace

```kotlin
            UsbSerialProber.getDefaultProber().findAllDrivers(it)
```

with

```kotlin
            // Not getDefaultProber(): its table lists only stock bridge-chip
            // identifiers, so a dive cable with a reprogrammed product ID is
            // invisible (issue #732).
            DiveCableIds.prober().findAllDrivers(it)
```

Make the identical change in `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`.

Then remove the now-unused `UsbSerialProber` import from each file if nothing else in it uses the type:

Run: `grep -n "UsbSerialProber" packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/*.kt`

- [ ] **Step 6: Verify the Android build**

Run: `flutter build apk --debug`
Expected: success.

- [ ] **Step 7: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveCableIds.kt \
        packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/DiveCableIdsTest.kt \
        packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt \
        packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt
git commit -m "feat(dc): recognise reprogrammed dive-cable USB IDs on Android (#732)"
```

---

## Task 9: Verify, document the limits, and open the pull request

**Files:**
- No source changes expected. Fix whatever verification turns up.

**Interfaces:**
- Consumes: everything above.
- Produces: a pull request and a follow-up issue.

- [ ] **Step 1: Format and analyse**

Run:
```bash
dart format .
flutter analyze
```
Expected: `dart format` reports no changed files, `flutter analyze` reports no issues. Infos are fatal in CI, so treat any output as a failure.

- [ ] **Step 2: Run every test suite**

Run each separately and read each result; do not pipe through `tail` or `head`, which masks a non-zero exit status:
```bash
flutter test
packages/libdivecomputer_plugin/darwin/run_native_tests.sh
cmake -B build/test packages/libdivecomputer_plugin/test/native && ctest --test-dir build/test --output-on-failure
cd packages/libdivecomputer_plugin/android && ./gradlew test && cd -
```
Expected: all green.

If `flutter test` reports failures in `saved_plans_sheet`, or two `split('-')` recovery-code tests, or a security-settings recovery dialog, check whether they fail on `main` too before investigating. Those are known pre-existing flakes and are not caused by this work.

- [ ] **Step 3: Build every affected platform**

Run:
```bash
flutter build macos --debug
flutter build apk --debug
flutter build ios --debug --no-codesign
```
Expected: all succeed. The iOS build is the one that proves the new C file's non-macOS stubs compile.

- [ ] **Step 4: File the flow-control follow-up**

The inversion described at the top of this plan is real but latent, and fixing it belongs in its own change:

```bash
gh issue create --repo submersion-app/submersion \
  --title "Serial backends invert DC_FLOWCONTROL_HARDWARE and DC_FLOWCONTROL_SOFTWARE" \
  --body "libdivecomputer defines DC_FLOWCONTROL_HARDWARE as 1 and DC_FLOWCONTROL_SOFTWARE as 2 (third_party/libdivecomputer/include/libdivecomputer/iostream.h). Two of our serial backends map them the other way round:

- packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/SerialIoStream.swift, performConfigure
- packages/libdivecomputer_plugin/linux/serial_io_stream.c:190

Both treat 1 as software XON/XOFF and 2 as hardware RTS/CTS, so a request for hardware flow control would enable software flow control and the other way round.

This is latent today: grepping third_party/libdivecomputer/src/ shows only the serial backends ever name those constants, so every driver passes DC_FLOWCONTROL_NONE and neither branch is ever taken. It becomes a real bug the moment a driver asks for flow control, and it is the kind of thing that is much harder to diagnose later than to fix now.

Found while adding the raw-USB FTDI transport (#732), whose FtdiProtocol.flowControl(fromLibdc:) deliberately uses the correct mapping and carries a comment saying why it differs from its neighbours.

Not fixed in #732 because the Linux backend is outside that change's scope and neither branch can be exercised by a test today."
```

- [ ] **Step 5: Push and open the pull request**

```bash
git push -u origin worktree-issue-732-ftdi-usb
gh pr create --repo submersion-app/submersion \
  --title "Support dive-computer USB cables that macOS and Android do not claim (#732)" \
  --body "$(cat <<'BODY'
Fixes #732.

## The problem

The Aeris Epic downloads over an FTDI cable carrying a custom USB product ID, 0x0403:0xF460. The Linux kernel names it FTDI_OCEANIC_PID; Apple's AppleUSBFTDI driver does not claim it. With no driver bound, macOS never creates a /dev/cu.* node, so the serial transport has nothing to open and every attempt fails immediately with `no_serial_ports`. Android is broken for the same family of cables for a different reason: it has no kernel driver for any of them, and the vendored usb-serial-for-android probe table lists only stock product IDs.

Linux and Windows already work, so they are untouched: ftdi_sio carries the product ID, and the Windows enumerator already accepts FTDIBUS hardware IDs.

## The change

macOS gains a second implementation of the plugin's existing eleven-slot iostream callback table, speaking the FTDI wire protocol over raw USB through IOKit's IOUSBLib. libdivecomputer is unaware of the difference: the session is still opened with `dc_custom_open` and `LIBDC_TRANSPORT_SERIAL`, so no libdivecomputer, pigeon or C-bridge change was needed. Serial ports are still tried first, and raw USB only after they are exhausted, so nothing that works today changes.

The sandbox permits this with `com.apple.security.device.usb`, a plain hardware entitlement needing no Apple approval. `application.sb` grants exactly the two IOKit user-client classes involved.

Android needs no new transport at all, only the reprogrammed product IDs registered in a probe table, since the vendored library already ships the chip drivers. No vendored source was modified.

Every part of this with logic in it is pure and unit-tested standalone: the wire encoding, the exact-size read accumulation across packets, and the device allowlist. Baud divisors are asserted against FTDI application note AN232B-05 rather than against our own implementation.

## Line control is not optional

The Oceanic Atom2 driver pulses RTS with DTR held high and then purges before it will talk (oceanic_atom2.c). The C bridge silently no-ops a NULL callback slot, so a transport implementing only read and write would look like a dead cable rather than a bug. That is the shape of #334, and all of configure, set_dtr, set_rts, purge, sleep and set_timeout are implemented here.

## Verification

Unit tests, native tests and builds for macOS, iOS and Android all pass.

**This needs hardware confirmation before the issue is closed.** Nobody working on it has an Aeris cable, so the IOKit path and the real handshake are unverified against the device. The enumerator logs every USB device it sees with its vendor and product ID and whether the allowlist matched, so the next debug log will distinguish "the cable is not enumerating" from "it enumerated and was rejected" without another round trip.

## Not fixed here

The two termios backends invert DC_FLOWCONTROL_HARDWARE and DC_FLOWCONTROL_SOFTWARE. It is latent, since no driver requests either, and it is filed separately rather than changed inside a transport PR. The new code uses the correct mapping and says so in a comment.
BODY
)"
```

- [ ] **Step 6: Ask the reporter to test**

```bash
gh issue comment 732 --repo submersion-app/submersion \
  -b "Confirmed the cause and put up a fix. Your cable is an FTDI chip carrying a custom USB product ID (0x0403:0xF460) that macOS's built-in FTDI driver does not recognise, so the system never creates a serial port for it and Submersion had nothing to open. The fix talks to the cable directly over USB instead of going through a serial port, which is the same approach Subsurface takes.

I do not have one of these cables, so this needs your help to confirm. Once the build reaches you, please try the download again and attach a fresh debug log whether it works or not: the log now lists every USB device it sees along with its identifiers, so it will show exactly where things stand either way."
```

---

## Self-review notes

Checked against the spec, section by section:

- Root cause and the custom product ID: Tasks 1, 3 and 6.
- macOS raw-USB transport with all five components: Tasks 1, 2, 3, 4, 5.
- Line control mandatory (configure, set_dtr, set_rts, purge, sleep, set_timeout): Task 5, Step 1.
- Candidate ordering, tty before raw USB, `no_serial_ports` unchanged: Task 6, Step 3.
- Diagnostic logging of every enumerated device: Task 3, Step 4.
- `com.apple.security.device.usb` plus the file assertion: Task 7.
- Android probe table over the full six-cable list: Task 8.
- Baud vectors from AN232B-05, including the documented 57600 divergence: Task 1, Step 1.
- Linux, Windows and iOS untouched apart from the iOS stub compile: Task 4 and Task 9, Step 3.
- Hardware verification called out as gating the issue: Task 9, Steps 5 and 6.

Four traps were found while reviewing this plan against itself and are already handled in the code above. They are recorded here because each one would have produced a test that passes while asserting the wrong thing, or code that compiles and then misbehaves:

1. **`.none` against an Optional.** `FtdiProtocol.Parity` and `FlowControl` both have a `none` case, and both mapping functions return an Optional. A bare `x == .none` resolves to `Optional.none`, quietly turning an enum comparison into an is-nil check. The tests write those two comparisons fully qualified, with a comment saying not to shorten them.
2. **`break` inside a `switch` inside a loop.** In `FtdiReadAccumulator.read` the loop exits live inside a `switch`, where a bare `break` leaves the switch and loops forever. The loop is labelled and the exits use `break readLoop`.
3. **`NativeLogger` is not standalone-compilable.** It holds a Pigeon `DiveComputerFlutterApi`, which exists only in the CocoaPods build. `UsbFtdiDeviceEnumerator` therefore takes a `log` closure instead of calling it, or its test suite could not compile. `FtdiUsbIoStream` uses `NativeLogger` freely, since it has no standalone suite.
4. **`wIndex` on SET_BAUD_RATE.** Every other FTDI control request puts the port number in `wIndex`; SET_BAUD_RATE puts the divisor's high bits there on single-port parts. Passing the port number would corrupt the divisor.

One value is still left to the implementer rather than asserted here: the real `kIOReturnTimeout`, which Task 5 Step 2 moves behind a C helper so the constant never reaches Swift as a literal.
</content>
