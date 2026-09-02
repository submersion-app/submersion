# USB HID Transport Design

**Issue:** [#1271](https://github.com/submersion-app/submersion/issues/1271) ScubaPro G2 TEK USB Import

## Problem

A Scubapro G2 TEK can be downloaded over Bluetooth on a phone, but a Windows
desktop without Bluetooth has no way to reach it. The USB tab of the dive
computer wizard lists no Scubapro model at all, even though the same hardware
imports fine in Subsurface over USB.

## Why the device is missing

libdivecomputer already knows the G2 family speaks USB HID
(`third_party/libdivecomputer/src/descriptor.c:171-180`):

```c
{"Scubapro", "Aladin Square", DC_FAMILY_UWATEC_SMART, 0x22, DC_TRANSPORT_USBHID, dc_filter_uwatec},
{"Scubapro", "G2 TEK",        DC_FAMILY_UWATEC_SMART, 0x31, DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, dc_filter_uwatec},
{"Scubapro", "G2",            DC_FAMILY_UWATEC_SMART, 0x32, DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, dc_filter_uwatec},
{"Scubapro", "G2 Console",    DC_FAMILY_UWATEC_SMART, 0x32, DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, dc_filter_uwatec},
{"Scubapro", "G3",            DC_FAMILY_UWATEC_SMART, 0x34, DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, dc_filter_uwatec},
{"Scubapro", "G2 HUD",        DC_FAMILY_UWATEC_SMART, 0x42, DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, dc_filter_uwatec},
```

Every native backend then drops that bit on the floor when it converts
libdivecomputer's transport bitmask into the Pigeon `TransportType` list. The
suppression is deliberate and carries the same comment on all four platforms,
for example
`packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:77-81`:

> USBHID is deliberately NOT surfaced as USB: no platform build implements a USB
> HID transport (HAVE_HIDAPI is off), so advertising it sent HID-only devices
> (Suunto EON Steel family) into the serial path's "No USB serial ports found"
> dead end (#143). BLE is the working path for those devices.

That is accurate. Commit `73ea1433bf2` added it because simply advertising USB
made the device selectable and then failed at download time. So the fix is not
to flip the filter; it is to build the transport the comment says is missing,
and then flip the filter.

## Key architectural fact

**The plugin never uses libdivecomputer's own transport backends.** Every
download opens `dc_custom_open` with a plugin-owned eleven-slot callback table
(`packages/libdivecomputer_plugin/macos/Classes/libdc_download.c:849-869`), and
the bytes move through platform code: `BleIoStream`, `SerialIoStream`,
`FtdiUsbIoStream` on darwin, and their C/C++/Kotlin equivalents elsewhere.

Two consequences:

1. `HAVE_HIDAPI` being undefined in every `config/config.h` does not matter.
   Nothing calls `dc_usbhid_open`. There is no need to vendor hidapi or libusb,
   and no build-system risk from doing so.
2. `dc_custom_open` takes the transport as an argument and stores it on the
   iostream (`third_party/libdivecomputer/src/custom.c:74-84`). Passing
   `DC_TRANSPORT_USBHID` is enough to make the Uwatec Smart driver use its HID
   code paths.

That second point carries most of the protocol work. `uwatec_smart.c` branches
purely on `dc_iostream_get_transport()`:

| Location | Behaviour under `DC_TRANSPORT_USBHID` |
| --- | --- |
| `uwatec_smart.c:279-285` | TX packet size `PACKETSIZE_USBHID_TX + 1` = 33 bytes |
| `uwatec_smart.c:300-303` | writes the full 33-byte buffer, leading report id included |
| `uwatec_smart.c:318-327` | RX packet size `PACKETSIZE_USBHID_RX` = 64 bytes |
| `uwatec_smart.c:377-379` | clamps the payload length to the packet's first byte |
| `uwatec_smart.c:502-518` | `DC_TRANSPORT_USBHID` is an accepted, fully supported case |

So the plugin has to supply a byte pipe with exactly the semantics
libdivecomputer's own `usbhid.c` provides, and nothing more.

## The contract a HID byte pipe must honour

Taken from `third_party/libdivecomputer/src/usbhid.c:707-790`, which is the
reference implementation these drivers were written against:

**Write.** The first byte of the buffer is the HID report id. A report id of
zero is not part of the wire format, so it is stripped and the remaining
`size - 1` bytes are sent as the output report; `actual` still reports the full
`size` the caller passed. A non-zero report id is transmitted.

**Read.** One input report is returned per call, up to `size` bytes, subject to
the timeout most recently set by `set_timeout`. A timeout yields zero bytes and
`DC_STATUS_SUCCESS`, not an error; `uwatec_smart_usbhid_receive` treats a short
read as a protocol error itself.

Everything else in the callback table is inert for HID: `configure`, `set_dtr`
and `set_rts` are serial line control, and `purge` has no meaning for a report
pipe.

## Design

### Where HID devices enter the download

The macOS backend already probes an ordered candidate list for the USB and
serial transports, because hardware can be reachable in more than one way
(`DiveComputerHostApiImpl.swift:400-424`): a `/dev/cu.*` node first, then a raw
FTDI cable the operating system never claimed (issue #732). USB HID is a third
kind of candidate on the same list, and Windows and Linux gain the equivalent.

Two changes to the candidate machinery:

1. **Transport becomes per-candidate.** Today the whole probe runs with a single
   `transportValue` of `LIBDC_TRANSPORT_SERIAL`. A HID candidate must be run
   with `LIBDC_TRANSPORT_USBHID` or the Uwatec driver frames its packets as
   serial and the handshake fails. Serial-port and FTDI candidates keep
   `LIBDC_TRANSPORT_SERIAL`.
2. **HID candidates come first** when the selected model declares USBHID.
   Nothing that works today changes: a model with no USBHID bit gets an
   unchanged candidate list.

Putting HID candidates on the existing probe list, rather than behind a new
Pigeon transport value, is what makes a *saved* computer keep working. The
`dive_computers.connection_type` column stores the string `"usb"`
(`lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:228-231`),
so a G2 registered today comes back as `DeviceConnectionType.usb` tomorrow. A
download path that discovers HID from the descriptor handles both the fresh
selection and the saved one; a path keyed on a new enum value would only handle
the fresh one.

### Matching a plugged-in device to the selected model

libdivecomputer keeps the VID/PID allowlist inside its filter functions
(`descriptor.c:666-671` for Uwatec, `:697-702` for Suunto) and exposes
`dc_descriptor_filter()` publicly (`include/libdivecomputer/descriptor.h:125`).
The shared C wrapper gains one function that asks libdivecomputer the question
directly:

```c
int libdc_usbhid_match(const char *vendor, const char *product,
                       unsigned int model,
                       unsigned short vid, unsigned short pid);
```

No hand-maintained VID/PID table in plugin code. When libdivecomputer is next
updated, new HID hardware is picked up with no plugin change. This matters:
the descriptor list already contains a `G3` row whose USB ids are not yet in
`dc_filter_uwatec`, and that is upstream's business to fix, not ours to
second-guess.

The wrapper also gains a transport query, so the download path can ask whether
the selected model is HID-capable before enumerating anything:

```c
unsigned int libdc_descriptor_transports(const char *vendor, const char *product,
                                         unsigned int model);
```

### Per-platform byte pipe

| Platform | API | Notes |
| --- | --- | --- |
| macOS | `IOHIDManager` / `IOHIDDevice` (IOKit) | Swift. Input reports arrive on a run loop callback and queue into the existing `PacketReadBuffer`. Output via `IOHIDDeviceSetReport`. The podspec already declares `s.frameworks = 'IOKit'` and both sandboxed entitlement files already grant `com.apple.security.device.usb`. |
| Windows | `SetupDiGetClassDevs` + `HidD_*` + overlapped `ReadFile`/`WriteFile` | C++. `hid.lib` and `setupapi.lib` ship in the Windows SDK; `SetupAPI.lib` is already linked. |
| Linux | `/dev/hidraw*` + `HIDIOCGRAWINFO` | C. No libudev and no libusb: the ioctl reports VID/PID directly, so enumeration is a `readdir` over `/dev`. |

iOS and Android keep USBHID suppressed. iOS has no USB host role at all, and
Android would need `UsbDeviceConnection` HID transfers, which is separate work
against separate hardware; both already reach these computers over BLE.

Because darwin's `DiveComputerHostApiImpl.swift` is shared between macOS and
iOS, the mapping change there is guarded with `#if os(macOS)`.

### Report sizes are read from the device, not assumed

`uwatec_smart` asks for 64 bytes on read and writes 33. Suunto EON Steel uses
64 both ways. Rather than hard-code either, each backend asks the HID device
for its maximum input and output report lengths (`kIOHIDMaxInputReportSizeKey`
on macOS, `HidP_GetCaps` on Windows, the report descriptor size on Linux) and
sizes its buffers from that, clamped to what the caller asked for. A device
that reports nothing usable falls back to 64.

## What becomes visible

Surfacing the bit makes these selectable under USB for the first time, on
macOS, Windows and Linux:

- Scubapro G2, G2 TEK, G2 Console, G2 HUD, G3
- Scubapro Aladin Square, which is USBHID-only and therefore currently
  unreachable in the app by any route
- Suunto EON Steel, EON Core, D5, EON Steel Black, which today are BLE-only in
  the app and were the specific regression behind issue #143

## Failure messages

The existing dead end the #143 comment describes is "No USB serial ports found.
Is the dive computer connected and powered on?". A HID-only model that finds no
matching HID device must not say that, because the user has no serial port to
go looking for. The probe reports, in order of specificity:

- HID-capable model, no matching HID device, no serial candidates either: a
  message naming the model and asking whether it is connected and powered on.
- Candidates existed but none opened: the existing `connect_failed` probe
  report, now including HID candidates in the tried list.

## Testing

- **Native C** (`packages/libdivecomputer_plugin/test/native/`, run in CI by
  `native-plugin-tests.yml`): `libdc_usbhid_match` accepts the four Uwatec and
  four Suunto VID/PID pairs against their own descriptors, rejects a mismatched
  pair, and rejects a VID/PID whose descriptor does not declare USBHID.
  `libdc_descriptor_transports` reports the USBHID bit for a G2 TEK.
- **Swift** (`packages/libdivecomputer_plugin/darwin/run_native_tests.sh`): the
  report framing unit, driven by vectors taken from `usbhid.c`, not from our
  own implementation.
- **Dart**: `usbDeviceModelsProvider` includes a descriptor whose only
  transport is USB, and the existing `DeviceModel.fromDescriptor` mapping tests
  continue to pass unchanged.

End-to-end verification needs the hardware. The issue reporter has a G2 TEK and
offered to test builds.
