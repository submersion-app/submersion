# FTDI-over-raw-USB dive computer transport (issue #732)

Date: 2026-08-18
Issue: [#732](https://github.com/submersion-app/submersion/issues/732)
Status: design approved, implementation pending

## Problem

A user cannot download from an Aeris Epic over its USB cable on macOS 14.6.1.
Every attempt fails immediately with the same log line:

```
[LDC] [ERROR] Download failed (no_serial_ports): No USB serial ports found.
```

Subsurface downloads from the same cable on the same machine.

### Root cause

The Aeris/Oceanic/Pelagic download cable is an FTDI chip whose EEPROM has been
reprogrammed with a custom product ID, `0x0403:0xF460`. The Linux kernel names
it directly:

```c
/* drivers/usb/serial/ftdi_sio_ids.h */
#define FTDI_OCEANIC_PID  0xF460  /* Oceanic dive instrument */
```

Apple's built-in FTDI driver does not claim that PID. Dumping all 97
`IOKitPersonalities` from
`/System/Library/DriverExtensions/com.apple.DriverKit-AppleUSBFTDI.dext` shows
that under vendor `0x0403` macOS claims `0x6001`, `0x6010`, `0x6011`, `0x6014`,
`0x6015`, plus two dive-specific PIDs Apple was persuaded to add over the years
(`0x87D0` Cressi Leonardo and `0xF680` Suunto). `0xF460` is absent.

Because no driver claims the device, macOS never creates a `/dev/cu.usbserial-*`
node. `SerialPortEnumerator.enumerateUsbSerialPaths()` therefore returns an
empty list, `candidatePorts()` returns empty, and
`DiveComputerHostApiImpl.performSerialDownload` reports `no_serial_ports`
(`darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:398`). The app is
working exactly as designed; the device node it is looking for does not exist.

This is a different failure from issue #291 (Suunto Vyper Air). There the node
existed and `open(2)` failed with EPERM for want of
`com.apple.security.device.serial`. Here there is nothing to open.

### Why only macOS and Android are affected

| Platform | State | Why |
| --- | --- | --- |
| macOS | Broken | `AppleUSBFTDI` does not claim `0xF460`, so no tty node exists. |
| Android | Broken | No kernel VCP driver exists at all; the app drives USB serial through the vendored `usb-serial-for-android`, whose default probe table lists only stock PIDs. |
| Linux | Works | `ftdi_sio` carries `FTDI_OCEANIC_PID`, so `/dev/ttyUSB*` appears. |
| Windows | Works | The vendor's FTDI driver claims the PID, and `EnumerateAvailableSerialPorts()` already accepts `FTDIBUS\` hardware IDs (`windows/serial_scanner.cc:46`). |

Linux and Windows are therefore out of scope. Routing them through raw USB
would regress users whose kernel or vendor driver already works.

### Why there is no macOS workaround worth shipping

Editing Apple's driver extension is impossible since the signed system volume
landed. Asking users to install FTDI's own system extension depends on a
third-party dext they must approve and reboot for, and it could not be
confirmed that the current FTDI dext even lists `0xF460`. Shipping our own
DriverKit extension needs `com.apple.developer.driverkit*` entitlements, which
do require Apple approval, and burdens every user with an extension approval.
Reprogramming the cable's EEPROM breaks it for the vendor's own software.

The only self-contained fix is the one Subsurface uses: talk to the FTDI chip
over raw USB and never involve a tty node.

## Approach

libdivecomputer never sees a file descriptor. `libdc_download_run` opens the
device through

```c
dc_custom_open(&iostream, session->context, (dc_transport_t)actual_transport,
               &custom_cbs, &io_cbs_copy);
```

(`macos/Classes/libdc_download.c:856`), where `custom_cbs` is a table of
`bridge_*` thunks that forward to the plugin's own eleven-slot
`libdc_io_callbacks_t` (`macos/Classes/libdc_wrapper.h:95-126`). The Oceanic
driver only ever sees a `dc_iostream_t`. Supplying a different byte pipe
therefore requires no change to libdivecomputer, no change to the pigeon API,
and no change to the C bridge. This is the same seam Subsurface uses
(`core/serial_ftdi.cpp` calls `dc_custom_open(..., DC_TRANSPORT_SERIAL, ...)`).

Subsurface reaches that seam through libusb plus libftdi. We will implement the
FTDI wire protocol directly instead. It is small: six vendor control requests
and a two-byte status header on each bulk-IN packet. Vendoring two LGPL
libraries to build, bundle, sign and notarize per platform is a poor trade for
roughly three hundred lines, and static linking LGPL code is a Mac App Store
problem. Hand-rolling also keeps the protocol logic in pure Swift, where this
repository already has a working standalone unit-test harness
(`darwin/run_native_tests.sh`).

### Sandbox feasibility

`/System/Library/Sandbox/Profiles/application.sb` grants, under the plain
`com.apple.security.device.usb` entitlement, exactly the two IOKit user-client
classes needed:

```scheme
(when (entitlement "com.apple.security.device.usb")
      (allow iokit-open-user-client
             (iokit-user-client-class
               "IOUSBDeviceUserClientV2"
               "IOUSBInterfaceUserClientV3")))
```

Those are the classes `IOUSBLib` opens via
`IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID, ...)`
and `kIOUSBInterfaceUserClientTypeID`. `com.apple.security.device.usb` is an
ordinary App Sandbox hardware entitlement, not a restricted one: no
provisioning-profile entry and no Apple approval, exactly like the
`com.apple.security.device.serial` key added for issue #291.

Note the profile allows `IOUSBInterfaceUserClientV3` but not `V2`.
`kIOUSBInterfaceUserClientTypeID` should resolve to V3 on current macOS, but
this has not been verified empirically under the sandbox and is called out as a
risk below.

`IOUSBHost`, the newer Objective-C/Swift framework, is deliberately not used:
its user clients are not named in the sandbox profile and no Apple statement
confirms they are permitted to sandboxed apps.

One consequence of the root cause works in our favour. Because nothing claims
`0x0403:0xF460`, claiming the interface will not fail with
`kIOReturnExclusiveAccess`. The unclaimed state that breaks the serial path is
what makes the raw-USB path clean.

### Line control is mandatory

`oceanic_atom2.c:896-941` does not simply open a pipe:

```c
dc_iostream_configure (device->iostream, baudrate, 8, DC_PARITY_NONE,
                       DC_STOPBITS_ONE, DC_FLOWCONTROL_NONE);
dc_iostream_set_timeout (device->iostream, 1000);
dc_iostream_set_dtr (device->iostream, 1);
dc_iostream_set_rts (device->iostream, 0);
dc_iostream_sleep (device->iostream, 100);
dc_iostream_set_rts (device->iostream, 1);
dc_iostream_sleep (device->iostream, 100);
dc_iostream_purge (device->iostream, DC_DIRECTION_ALL);
```

The RTS pulse wakes the cable. A transport that implements only `read` and
`write` and leaves the line-control slots NULL would reproduce issue #334
exactly: the C bridge silently no-ops NULL slots
(`libdc_download.c:647-728`), the device never answers, and the failure looks
like a hardware fault. `configure`, `set_dtr`, `set_rts`, `purge`, `sleep` and
`set_timeout` are all required.

The Epic runs at 38400 8N1 (`oceanic_atom2.c:890-893`; only VTX, i750TC,
ProPlusX and i770R use 115200).

## Scope

### In scope

- macOS: a raw-USB FTDI transport, tried after tty candidates are exhausted.
- macOS: `com.apple.security.device.usb` in the sandboxed entitlements.
- Android: custom probe-table entries for the known dive-cable USB IDs.

### Out of scope

- Linux and Windows transports (their kernel/vendor drivers already work).
- iOS (no USB host support).
- Non-FTDI chips on macOS. The macOS transport speaks FTDI, so it covers the
  three FTDI custom PIDs. The Prolific (`0x04B8:0x0521`, `0x04B8:0x0522`) and
  CDC-ACM (`0xFFFF:0x0005`) dive cables would each need a separate chip
  protocol written from scratch. On Android they cost nothing, because
  `usb-serial-for-android` already ships `ProlificSerialDriver` and
  `CdcAcmSerialDriver`, so Android takes the full list.
- Active USB discovery in the UI. The "USB cable" tab is a filtered descriptor
  list, not a scan (`discovery_providers.dart:51-62`), and manual model
  selection plus native auto-probe is sufficient.

### Device coverage

| Chip | VID:PID | Cable | macOS | Android |
| --- | --- | --- | --- | --- |
| FTDI | `0x0403:0xF460` | Oceanic / Aeris / Sherwood / Hollis | yes | yes |
| FTDI | `0x0403:0xF680` | Suunto Sports Instrument | yes | yes |
| FTDI | `0x0403:0x87D0` | Cressi Leonardo | yes | yes |
| Prolific | `0x04B8:0x0521` | Mares Nemo / Cressi | no | yes |
| Prolific | `0x04B8:0x0522` | Zeagle | no | yes |
| CDC-ACM | `0xFFFF:0x0005` | Mares Icon HD | no | yes |

`0xF680` and `0x87D0` are already claimed by macOS today, so on macOS they are
redundancy against Apple dropping a personality in a future release rather than
a fix for a live report. Subsurface's own table lists `0x04B8:0x0521` twice and
never lists `0x0522`; that is an upstream bug and is not copied.

## Design: macOS

### Component breakdown

Five new units. The split exists so that everything with interesting logic is
pure and testable, and the part that cannot be tested without hardware is as
dumb as possible.

#### `FtdiProtocol.swift` (pure)

No IOKit, no Flutter, no I/O. Owns every piece of FTDI wire knowledge:

- Request codes: `reset` `0x00`, `setModemCtrl` `0x01`, `setFlowCtrl` `0x02`,
  `setBaudRate` `0x03`, `setData` `0x04`, `setLatencyTimer` `0x09`.
- `baudDivisor(_ baud: UInt32) -> (value: UInt16, index: UInt16)?`, the
  FT232BM/FT232R encoding: `divisor3 = round(48_000_000 / (2 * baud))`,
  `divisor = (divisor3 >> 3) | (divfrac[divisor3 & 7] << 14)` with
  `divfrac = [0, 3, 2, 4, 1, 5, 6, 7]`, then the two documented special cases
  (`divisor == 1` becomes `0`, `divisor == 0x4001` becomes `1`). `value` is the
  low sixteen bits, `index` the high sixteen.
- `dataWord(dataBits:parity:stopBits:) -> UInt16`: data bits in bits 0-7,
  parity in bits 8-10 (none/odd/even/mark/space), stop bits in bits 11-13.
- `modemCtrlValue(dtr:)` and `modemCtrlValue(rts:)`: `0x0101`/`0x0100` and
  `0x0202`/`0x0200`.
- `resetValue(for direction:)`: `0` full reset, `1` purge RX, `2` purge TX.
- `stripStatusBytes(from:packetSize:) -> [UInt8]`: every bulk-IN packet begins
  with two modem-status bytes that are not payload. Dropping them correctly
  across packet boundaries is the single most bug-prone part of the protocol,
  and it is pure, so it is unit-tested directly.

#### `FtdiReadAccumulator.swift` (pure)

libdivecomputer's contract is "return exactly `size` bytes or
`DC_STATUS_TIMEOUT`", and every driver relies on it. This mirrors
`SerialReadLoop.serialReadFully` for the USB bulk case: accumulate payload
across bulk transfers against a monotonic deadline, buffer surplus payload for
the next call, and report a short read as timeout. It takes a "read one packet"
closure so tests can drive it without hardware, the way `SerialReadLoopTests`
uses a socketpair.

Keeping this separate from `FtdiUsbIoStream` matters: it is where the #334
class of bug lives.

#### `UsbFtdiDeviceEnumerator.swift`

The allowlist of `(vendorId, productId)` dive cables plus an IOKit walk over
`IOServiceMatching(kIOUSBDeviceClassName)` returning
`(vendorId, productId, locationId, name)`. The classification and
candidate-selection half is pure and testable; only the enumeration touches
IOKit, matching the shape of `SerialPortEnumerator`.

Fail-closed: only allowlisted VID/PID pairs are ever returned, so no unrelated
FTDI hardware on the user's desk is opened or written to.

#### `macos/Classes/ftdi_usb_darwin.c` and `.h`

A deliberately dumb IOUSBLib shim with no FTDI knowledge:

```c
int    ftdi_usb_enumerate(ftdi_usb_device_info_t *out, size_t max, size_t *count);
int    ftdi_usb_open(uint32_t location_id, ftdi_usb_handle_t **out);
int    ftdi_usb_control(ftdi_usb_handle_t *, uint8_t request_type, uint8_t request,
                        uint16_t value, uint16_t index, void *data,
                        uint16_t length, uint32_t timeout_ms);
int    ftdi_usb_bulk_read(ftdi_usb_handle_t *, void *buf, size_t size,
                          size_t *actual, uint32_t timeout_ms);
int    ftdi_usb_bulk_write(ftdi_usb_handle_t *, const void *buf, size_t size,
                           size_t *actual, uint32_t timeout_ms);
size_t ftdi_usb_max_packet_size(ftdi_usb_handle_t *);
void   ftdi_usb_close(ftdi_usb_handle_t *);
```

`ftdi_usb_open` performs `IOCreatePlugInInterfaceForService` on the device,
`USBDeviceOpen`, interface iteration, `USBInterfaceOpen`, and pipe discovery
for the bulk IN/OUT endpoints. Transfers use `ControlRequestTO`, `ReadPipeTO`
and `WritePipeTO` so a stuck device cannot hang a download thread.

The whole body compiles out under `#if !TARGET_OS_OSX`, since iOS has no USB
host. Following the existing convention, the file lives in `macos/Classes/` and
is symlinked from `ios/Classes/` (see `libdc_download.c`).

#### `FtdiUsbIoStream.swift`

Glue. Holds the C handle, drives `FtdiProtocol` and `FtdiReadAccumulator`, and
exposes `makeCallbacks() -> libdc_io_callbacks_t` using the established
`Unmanaged.passUnretained(self).toOpaque()` userdata pattern. Slot mapping:

| Slot | Implementation |
| --- | --- |
| `configure` | `setBaudRate` control request, then `setData`, then `setFlowCtrl` |
| `set_dtr` / `set_rts` | `setModemCtrl` control request |
| `purge` | `reset` control request with the direction value, plus dropping the accumulator's buffered payload |
| `read` | `FtdiReadAccumulator` over `ftdi_usb_bulk_read` with status-byte stripping |
| `write` | `ftdi_usb_bulk_write` |
| `set_timeout` | stored, applied to subsequent transfers |
| `sleep` | monotonic sleep |
| `close` | `ftdi_usb_close` |
| `poll`, `ioctl` | NULL (the bridge no-ops them, matching the Windows stream) |

`configure` additionally sets the latency timer to 1 ms. The FTDI default of
16 ms adds latency to every short reply, and the Oceanic driver's timeout is
1000 ms with many small transactions.

### Wiring into the download path

`performSerialDownload`
(`DiveComputerHostApiImpl.swift:379-500`) currently hardcodes the assumption
that a candidate is a `/dev` path string, in two places: a single-candidate
fast path that reports precise open errors, and a multi-candidate probe loop
that buffers dives so a wrong port cannot leak phantom dives.

Introduce

```swift
enum DownloadCandidate {
    case serialPort(String)
    case ftdiUsb(UsbFtdiDevice)
}
```

and generalise both paths over it, with candidate opening behind a small
factory that returns either a `SerialIoStream` or an `FtdiUsbIoStream` along
with a failure reason. The structure, the dive buffering and the error codes
stay as they are; only the element type changes. This is a targeted improvement
to code the change has to touch anyway, not a speculative refactor.

Candidate ordering:

1. tty candidates from `SerialPortEnumerator` (today's behaviour, unchanged).
2. raw-USB FTDI candidates from `UsbFtdiDeviceEnumerator`.

tty first means nothing that works today changes. Raw USB is tried only after
the tty candidates are exhausted, which also covers the case where an unrelated
USB-serial adapter is plugged in alongside the dive cable: the adapter is tried,
fails to handshake, and the FTDI candidate is reached.

`no_serial_ports` is reported only when both lists are empty, so the existing
`diveComputer_download_noSerialPortsFound` string and its translations are
untouched.

### Diagnostics

No Aeris cable is available for development, so the next debug log from the
reporter must be decisive. `UsbFtdiDeviceEnumerator` logs every USB device it
sees with vendor ID, product ID and product name, and states for each whether
it matched the allowlist. A log showing `0x0403:0xF460` present but rejected,
or absent entirely, distinguishes an allowlist miss from an enumeration or
entitlement problem without another round trip.

### Entitlements

Add `com.apple.security.device.usb` to `macos/Runner/Release.entitlements` and
`macos/Runner/DebugProfile.entitlements`. `ReleaseNoSandbox.entitlements` needs
nothing, as the sandbox is off there.

## Design: Android

`SerialDownloadRunner.kt:62` and the in-process twin at
`DiveComputerHostApiImpl.kt:506` both call
`UsbSerialProber.getDefaultProber()`, whose table lists only stock PIDs.

Add one small Kotlin file holding the dive-cable ID table as plain data and a
`prober()` factory that folds it into `UsbSerialProber.getDefaultProbeTable()`
via the public `ProbeTable.addProduct(vendorId, productId, driverClass)`. Both
call sites use it, so the table has one home.

No vendored `usb-serial-for-android` source is modified, per
`third_party/usb-serial-for-android/VENDORED.md`. `findAllDrivers` needs no USB
permission, and the existing runtime `requestPermission` flow in
`UsbSerialIoStream.open()` is unchanged.

Adding IDs is additive: it can only cause devices to be recognised that
previously were not.

## Testing

### Pure Swift, via `darwin/run_native_tests.sh`

The harness compiles each file standalone with `swiftc`, so each suite is one
block. Three new suites:

- `FtdiProtocolTests`: baud divisors checked against externally published
  values rather than against our own implementation, so a wrong algorithm
  cannot pass. These match FTDI application note AN232B-05 exactly:

  | Baud | `value` | Baud | `value` |
  | --- | --- | --- | --- |
  | 300 | `0x2710` | 9600 | `0x4138` |
  | 600 | `0x1388` | 19200 | `0x809C` |
  | 1200 | `0x09C4` | 38400 | `0xC04E` (the Epic) |
  | 2400 | `0x04E2` | 115200 | `0x001A` (VTX, i750TC, ProPlusX, i770R) |
  | 4800 | `0x0271` | 230400 | `0x000D` |

  57600 is the one documented divergence and is tested as such. AN232B-05
  lists `0x0034` (divisor 52, giving 57692 baud, 0.16% error); the kernel's
  round-to-nearest yields `0xC034` (divisor 52.125, giving 57554 baud, 0.08%
  error). Both are accepted by the hardware, and the kernel value is the more
  accurate one. The test asserts `0xC034`, matching the algorithm we
  implement, with the divergence noted in a comment so a future reader does
  not "correct" it to the app-note value.

  Also covered: the two high-rate special cases, the `dataWord` encoding for
  8N1, the modem-control values, and `stripStatusBytes` across exact, partial
  and multi-packet inputs.
- `FtdiReadAccumulatorTests`: exact-size reads spanning several packets, short
  read reported as timeout, surplus payload carried into the next call, and
  deadline behaviour, driven through an injected packet-reader closure.
- `UsbFtdiDeviceEnumeratorTests`: allowlist accept and reject, and candidate
  ordering (tty candidates before raw USB).

### Android, JVM

`android/build.gradle` has JUnit but no Robolectric, and
`ProbeTable.findDriver` takes a framework `UsbDevice`. So the ID table stays
plain data with a pure lookup, and the test asserts the table contents and the
lookup rather than instantiating Android framework classes.

### Dart

Extend `test/macos_entitlements_test.dart` with a file assertion for
`com.apple.security.device.usb`, in both sandboxed entitlement files, exactly
as `com.apple.security.device.serial` is guarded today. Nothing in CI can
enforce an entitlement at runtime; the file assertion is the available guard.

### Not testable here

The IOKit shim and the real handshake need the physical cable. The pull request
will state that it requires hardware confirmation from the reporter before the
issue is closed, and the diagnostic logging above exists to make that
confirmation a single round trip.

## Risks

| Risk | Mitigation |
| --- | --- |
| `kIOUSBInterfaceUserClientTypeID` may resolve to `IOUSBInterfaceUserClientV2`, which the sandbox profile does not allow. | The shim reports the IOKit error verbatim, so a sandbox denial is legible rather than looking like a cable fault. If it does occur, the DMG build (sandbox off) still works and gives a fallback answer while the sandboxed path is fixed. |
| Hand-rolled FTDI protocol may be subtly wrong. | Every piece of protocol logic is pure and unit-tested against externally published values, not against our own implementation. |
| No hardware for verification. | Per-device diagnostic logging; the PR is explicit that hardware confirmation gates closing the issue. |
| Refactoring `performSerialDownload` could regress the working Mares Puck Pro path. | Candidate ordering puts tty first and the structure, error codes and dive buffering are preserved; `SerialPortEnumeratorTests` and `serial_transport_test.dart` continue to cover it. |
| Mac App Store review questioning the USB entitlement. | It is a plain sandbox hardware entitlement requiring no approval, and the app already ships `com.apple.security.device.serial` and `.bluetooth` for the same feature. |

## Files

Create:

- `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiProtocol.swift`
- `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiReadAccumulator.swift`
- `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/UsbFtdiDeviceEnumerator.swift`
- `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/FtdiUsbIoStream.swift`
- `packages/libdivecomputer_plugin/darwin/Tests/FtdiProtocolTests/main.swift`
- `packages/libdivecomputer_plugin/darwin/Tests/FtdiReadAccumulatorTests/main.swift`
- `packages/libdivecomputer_plugin/darwin/Tests/UsbFtdiDeviceEnumeratorTests/main.swift`
- `packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.c`
- `packages/libdivecomputer_plugin/macos/Classes/ftdi_usb_darwin.h`
- `packages/libdivecomputer_plugin/macos/Classes/FtdiProtocol.swift` (symlink)
- `packages/libdivecomputer_plugin/macos/Classes/FtdiReadAccumulator.swift` (symlink)
- `packages/libdivecomputer_plugin/macos/Classes/UsbFtdiDeviceEnumerator.swift` (symlink)
- `packages/libdivecomputer_plugin/macos/Classes/FtdiUsbIoStream.swift` (symlink)
- `packages/libdivecomputer_plugin/ios/Classes/*` (matching symlinks)
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveCableIds.kt`
- `packages/libdivecomputer_plugin/android/src/test/kotlin/com/submersion/libdivecomputer/DiveCableIdsTest.kt`

Modify:

- `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`
- `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/SerialDownloadRunner.kt`
- `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`
- `macos/Runner/Release.entitlements`
- `macos/Runner/DebugProfile.entitlements`
- `test/macos_entitlements_test.dart`

Unchanged, deliberately: the pigeon API, `libdc_download.c`, the
libdivecomputer submodule, all l10n strings, and the Linux and Windows
backends.

## References

- Linux `drivers/usb/serial/ftdi_sio_ids.h`, `FTDI_OCEANIC_PID`
- Linux `drivers/usb/serial/ftdi_sio.c`, `ftdi_232bm_baud_base_to_divisor`
- Subsurface `core/serial_ftdi.cpp` (probe table, `dc_custom_open` usage)
- Subsurface `android-mobile/src/org/subsurfacedivelog/mobile/AndroidSerial.java`
  (`ProbeTable.addProduct` usage)
- libdivecomputer `src/descriptor.c:207` (Aeris Epic, `DC_TRANSPORT_SERIAL`)
- libdivecomputer `src/oceanic_atom2.c:890-941` (baud rate, DTR/RTS pulse)
- `/System/Library/Sandbox/Profiles/application.sb:115-123`
- Issue #291 and `com.apple.security.device.serial`; issue #334 and the
  exact-size read contract
</content>
