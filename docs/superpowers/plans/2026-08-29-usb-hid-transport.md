# USB HID Transport Implementation Plan

**Goal:** Let Submersion download from USB HID dive computers (Scubapro G2
family and Aladin Square, Suunto EON Steel family) under the USB transfer mode
on macOS, Windows and Linux (issue #1271).

**Spec:** `docs/superpowers/specs/2026-08-29-usb-hid-transport-design.md`

**Architecture:** libdivecomputer is opened through `dc_custom_open` with a
plugin-owned eleven-slot callback table, so a new byte pipe needs no change to
libdivecomputer, its build, or the Pigeon API. Each desktop platform gains a HID
implementation of that table plus a device enumerator, and the HID device joins
the existing ordered candidate probe that already tries serial ports and raw
FTDI cables.

## Global Constraints

- No em-dashes anywhere, including code comments and commit messages.
- No emojis in code, comments or documentation.
- `dart format .` must produce no changes before any commit touching Dart.
- `flutter analyze` must be clean across the whole project; infos are fatal.
- Swift files that must stay unit-testable live in
  `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/` and are
  symlinked into `macos/Classes/` and `ios/Classes/`. A new shared darwin Swift
  file needs both symlinks or the CocoaPods build will not see it.
- Status codes are the `LIBDC_STATUS_*` values from
  `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h`, numerically
  identical to `dc_status_t`.
- `libdc_wrapper.c` and `libdc_download.c` under `macos/Classes/` are shared:
  the Windows, Linux and Android builds all compile them. A change there is a
  change on every platform.
- Android and iOS keep USBHID suppressed. `DiveComputerHostApiImpl.swift` is
  shared between macOS and iOS, so its mapping change is `#if os(macOS)`.

## Contract for the byte pipe

From `third_party/libdivecomputer/src/usbhid.c:707-790`:

- **write:** `data[0]` is the HID report id. If it is zero, strip it and send
  `size - 1` bytes; report `size` as written either way.
- **read:** return one input report, at most `size` bytes, within the timeout
  set by `set_timeout`. A timeout returns zero bytes and success, not an error.
- `configure`, `set_dtr`, `set_rts` and `purge` are meaningless for HID.

Report sizes come from the device (max input/output report length), falling
back to 64 bytes.

## File Structure

Create under `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/`:

| File | Responsibility |
| --- | --- |
| `UsbHidReportFraming.swift` | Pure report-id framing and buffer sizing. No I/O. |
| `DescriptorTransportMapping.swift` | Pure bitmask-to-transfer-mode mapping. Extracted from the host API because it is where the bug lived and it had no test at any layer. |
| `UsbHidDeviceEnumerator.swift` | IOHIDManager enumeration of HID devices with their VID/PID. |
| `UsbHidIoStream.swift` | Glue: owns the IOHIDDevice, queues input reports, produces `libdc_io_callbacks_t`. |

Create under `packages/libdivecomputer_plugin/darwin/Tests/`:
`UsbHidReportFramingTests/main.swift`,
`DescriptorTransportMappingTests/main.swift`.

Create under `packages/libdivecomputer_plugin/windows/`:
`usbhid_io_stream.{h,cc}`, `usbhid_enumerator.{h,cc}`.

Create under `packages/libdivecomputer_plugin/linux/`:
`usbhid_io_stream.{h,c}`, `usbhid_enumerator.{h,c}`.

Create under `packages/libdivecomputer_plugin/test/native/`:
`test_usbhid_descriptor_match.c`.

Modify: `macos/Classes/libdc_wrapper.{h,c}`,
`darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`,
`darwin/run_native_tests.sh`,
`windows/dive_computer_host_api_impl.cc`, `windows/CMakeLists.txt`,
`linux/dive_computer_host_api_impl.cc`, `linux/CMakeLists.txt`,
`test/native/CMakeLists.txt`.

---

## Task 1: Descriptor queries in the shared C wrapper

Ask libdivecomputer whether a model speaks USB HID, and whether a plugged-in
VID/PID belongs to it. Keeps the VID/PID allowlist upstream instead of copying
it into plugin code.

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.{h,c}`
- Test: `packages/libdivecomputer_plugin/test/native/test_usbhid_descriptor_match.c`
- Modify: `packages/libdivecomputer_plugin/test/native/CMakeLists.txt`

**Produces:**
- `unsigned int libdc_descriptor_transports(const char *vendor, const char *product, unsigned int model)`
- `int libdc_usbhid_match(const char *vendor, const char *product, unsigned int model, unsigned short vid, unsigned short pid)`

- [x] **Step 1: Write the failing test.** Assert the Uwatec pairs
  (`0x2e6c:0x3201` G2 and G2 TEK, `0x2e6c:0x3211` G2 Console, `0x2e6c:0x4201`
  G2 HUD, `0xc251:0x2006` Aladin Square) and the Suunto pairs (`0x1493:0x0030`,
  `0x0033`, `0x0035`, `0x0036`) match their own descriptors; that a G2 TEK
  rejects the Suunto D5 pair; that a Shearwater Perdix (BLE and serial, no
  USBHID) matches nothing; and that
  `libdc_descriptor_transports("Scubapro", "G2 TEK", 0x31)` has the USBHID bit
  and not the SERIAL bit. Vectors come from `descriptor.c`, not from the new
  code.
- [x] **Step 2: Implement** over `dc_descriptor_iterator` plus
  `dc_descriptor_filter(descriptor, DC_TRANSPORT_USBHID, &desc)`.
- [x] **Step 3: Verify** via `test/native/` CMake build.

## Task 2: Per-candidate transport on darwin

Refactor only. The probe currently runs every candidate with
`LIBDC_TRANSPORT_SERIAL`; a HID candidate needs `LIBDC_TRANSPORT_USBHID`.

**Files:** `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`

- [x] Give `DownloadCandidate` a `transportValue: UInt32` (`SERIAL` for both
  existing cases) and use it in both the single-candidate and multi-candidate
  paths instead of the function-level constant.
- [x] Verify no behaviour change: `flutter build macos --debug`.

## Task 3: HID report framing (pure, tested)

**Files:**
- Create: `darwin/Sources/LibDCDarwin/UsbHidReportFraming.swift`
- Test: `darwin/Tests/UsbHidReportFramingTests/main.swift`
- Modify: `darwin/run_native_tests.sh`

**Produces:** `enum UsbHidReportFraming` with
`outgoingReport(from: [UInt8]) -> (reportId: UInt8, payload: [UInt8])?` and
`reportSize(deviceMaximum: Int?, fallback: Int) -> Int`.

- [x] **Step 1: Failing test.** A 33-byte buffer whose first byte is zero
  yields report id 0 and a 32-byte payload; a non-zero first byte yields that
  id and keeps all remaining bytes; an empty buffer yields nil. Vectors from
  `usbhid.c:745-790`.
- [x] **Step 2: Implement.**
- [x] **Step 3:** `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`.

## Task 4: macOS HID enumeration and byte pipe

**Files:**
- Create: `darwin/Sources/LibDCDarwin/UsbHidDeviceEnumerator.swift`,
  `darwin/Sources/LibDCDarwin/UsbHidIoStream.swift`
- Symlink both into `macos/Classes/` and `ios/Classes/`

- [x] `UsbHidDevice` value type (vid, pid, product name, `IOHIDDevice`) and an
  `enumerate(log:)` that reports every HID device it sees, matched or not, so a
  user's debug log distinguishes "not enumerating" from "rejected".
- [x] `UsbHidIoStream`: open with `IOHIDDeviceOpen`, register an input report
  callback on a dedicated run loop, queue reports, `IOHIDDeviceSetReport` for
  write, and `makeCallbacks()` returning `libdc_io_callbacks_t`.
- [x] Guard the whole file body with `#if os(macOS)` so the iOS build compiles
  it to nothing.

## Task 5: Wire HID into the macOS download

**Files:** `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`

- [x] Add `case usbHid(UsbHidDevice)` to `DownloadCandidate` with transport
  `LIBDC_TRANSPORT_USBHID` and log category `"HID"`.
- [x] In `performSerialDownload`, when
  `libdc_descriptor_transports(...) & LIBDC_TRANSPORT_USBHID`, enumerate HID
  devices, keep those `libdc_usbhid_match` accepts, and prepend them.
- [x] Replace the bare "No USB serial ports found" when the model is HID-capable
  and nothing matched.
- [x] Surface USBHID as `.usb` in `mapTransports`, `#if os(macOS)` only, and
  rewrite the #143 comment to say what is now true.

## Task 6: Windows HID

**Files:** `windows/usbhid_io_stream.{h,cc}`, `windows/usbhid_enumerator.{h,cc}`,
`windows/dive_computer_host_api_impl.cc`, `windows/CMakeLists.txt`

- [x] Enumerate with `SetupDiGetClassDevs(GUID_DEVINTERFACE_HID)` +
  `HidD_GetAttributes` + `HidD_GetProductString`; buffer sizes from
  `HidP_GetCaps`.
- [x] Overlapped `ReadFile` with `WaitForSingleObject` for the timeout, and
  `WriteFile` for output reports.
- [x] Same candidate ordering and mapping changes as Task 5.
- [x] Link `hid.lib` (SetupAPI.lib is already linked).

## Task 7: Linux HID

**Files:** `linux/usbhid_io_stream.{h,c}`, `linux/usbhid_enumerator.{h,c}`,
`linux/dive_computer_host_api_impl.cc`, `linux/CMakeLists.txt`

- [x] Enumerate `/dev/hidraw*`, VID/PID from `HIDIOCGRAWINFO`, name from
  `HIDIOCGRAWNAME`. No libudev, no libusb.
- [x] `poll()` + `read()` for the timeout contract, `write()` for output
  reports.
- [x] Same candidate ordering and mapping changes as Task 5. Note the Linux
  backend currently forces USB to SERIAL at
  `linux/dive_computer_host_api_impl.cc:372`; that becomes per-candidate.

## Task 8: Dart coverage and l10n

- [x] Test that `usbDeviceModelsProvider` keeps a descriptor whose only
  transport is `usb` (the shape a HID device now arrives in).
- [x] Any new user-facing string goes through `lib/l10n/arb/` for every locale.

## Findings during implementation

- **The two HID families frame reports differently, and both directions
  matter.** The Uwatec family writes report id 0 (`uwatec_smart.c:287`), which
  is stripped before it goes on the wire. The Suunto EON Steel family writes
  report type `0x3f` (`suunto_eonsteel.c:242`) and rejects any reply whose
  first byte is not `0x3f` (`:156`), so its id byte must stay. Treating "strip
  the first byte" as unconditional would have worked for the G2 and failed
  every EON Steel packet. Both cases are pinned by tests.
- **A HID-only model must not fall through to the serial probe.** It has no
  serial port to find, and probing writes dive-computer handshake bytes at
  whatever else is plugged in. The candidate list stops at HID when the
  descriptor declares no serial or bulk-USB transport.
- **No Pigeon change was needed.** Surfacing USB HID as the existing `usb`
  transport and dispatching from the descriptor inside the download path also
  keeps a saved computer working: `dive_computers.connection_type` stores the
  string `"usb"` either way, so a G2 registered today comes back as a plain USB
  device tomorrow. A new enum value would only have handled a fresh selection.

## Task 9: Verification

- [x] `packages/libdivecomputer_plugin/darwin/run_native_tests.sh`
- [x] `test/native/` CMake suite
- [x] `flutter analyze` clean, `dart format .` clean
- [x] Full `flutter test` run
- [x] `flutter build macos --debug` and a smoke run of the USB tab, confirming
  Scubapro and Suunto models are listed
- [x] CI must build Windows and Linux green
- [x] Reply on issue #1271 offering a build to test
