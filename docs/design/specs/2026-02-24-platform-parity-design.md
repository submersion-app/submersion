# Platform Parity Design: Full Dive Computer Support on All Platforms

## Overview

Achieve full feature parity for the libdivecomputer plugin across all five platforms
(macOS, iOS, Android, Windows, Linux) for both BLE and serial/USB transports.

## Current State

The shared C wrapper (`libdc_wrapper.c` / `libdc_download.c`) already parses all data.
The gaps are entirely in the platform-specific mapping layers above it.

| Platform | Language   | Download    | Samples    | Events     | Deco/GF    |
|----------|-----------|-------------|------------|------------|------------|
| macOS    | Swift     | Full (BLE)  | Full (14)  | Full (25)  | Full       |
| iOS      | Swift     | Full (BLE)  | Partial (5)| Missing    | Missing    |
| Android  | Kotlin/JNI| Full (BLE)  | Partial (5)| Missing    | Missing    |
| Windows  | C++       | Stubbed     | N/A        | N/A        | N/A        |
| Linux    | C/GLib    | Stubbed     | N/A        | N/A        | N/A        |

## Decisions

| Question              | Answer                                          |
|-----------------------|-------------------------------------------------|
| Transports            | BLE + serial/USB on all platforms               |
| Priority              | All platforms in parallel                       |
| Windows BLE           | WinRT APIs (C++/WinRT)                          |
| Linux BLE             | BlueZ D-Bus via GLib GDBusConnection            |
| Serial/USB UX         | Auto-detect with descriptor matching            |
| iOS/macOS duplication | Shared Swift package                            |
| Testing               | CI for Windows/Linux, unit test mapping on macOS|
| Architecture          | Extend current per-platform mapping (Approach A)|

## Architecture

Three layers. Layer 1 (shared C) is complete. Work is in Layers 2 and 3.

```text
Layer 3: Pigeon Contract (Dart <-> Native)
  dive_computer_api.dart -> generated per-platform code
  ParsedDive, ProfileSample, DiveEvent (no changes needed)

Layer 2: Platform Mapping + Transport (per-platform)
  macOS/iOS: Swift (shared package)
  Android:   Kotlin + JNI
  Windows:   C++ / WinRT
  Linux:     C / GLib
  Each implements: HostApi, BLE scanner/stream, serial scanner/stream, convertParsedDive()

Layer 1: Shared C Wrapper (all platforms)
  libdc_wrapper.c + libdc_download.c
  Parses all 14 sample fields, 25 events, deco model
  COMPLETE - no changes needed
```

## Section 1: Shared Swift Package (iOS/macOS)

Extract common Swift code into a local Swift package to prevent drift.

### Structure

```text
packages/libdivecomputer_plugin/
  darwin/
    Package.swift
    Sources/LibDCDarwin/
      DiveComputerHostApiImpl.swift   (moved from macos/Classes/)
      BleScanner.swift                (moved from macos/Classes/)
      BleIoStream.swift               (moved from macos/Classes/)
      SerialIoStream.swift            (NEW)
  macos/Classes/
    LibdivecomputerPlugin.swift       (thin entry point, imports LibDCDarwin)
    libdc_wrapper.c                   (stays, shared C)
    libdc_download.c                  (stays)
    libdc_wrapper.h                   (stays)
  ios/Classes/
    LibdivecomputerPlugin.swift       (thin entry point, imports LibDCDarwin)
    (no more duplicated Swift files)
```

### Conditional Import

```swift
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
```dart
Both podspecs reference the shared darwin/ sources. iOS immediately gets full parity
by sharing the exact same Swift code as macOS.

## Section 2: Android Parity (JNI + Kotlin)

The C layer already parses everything. The JNI bridge only exposes 5 of 14 sample
fields and has no accessors for events or deco model.

### New JNI Functions (libdc_jni.cpp)

1. **Expand `nativeGetDiveSample`** from DoubleArray[5] to DoubleArray[14]:
   `[time_ms, depth, temp, pressure, tank, heartbeat, setpoint, ppo2, cns, rbt,
   deco_type, deco_time, deco_depth, deco_tts]`
   Uses NaN for unavailable doubles, UINT32_MAX cast to double for unavailable ints.

2. **Add `nativeGetDiveEventCount(divePtr)`** returns event_count

3. **Add `nativeGetDiveEvent(divePtr, index)`** returns LongArray[4]:
   `[time_ms, type, flags, value]`

4. **Add `nativeGetDiveDecoModel(divePtr)`** returns IntArray[4]:
   `[model_type, conservatism, gf_low, gf_high]`

### Kotlin Changes

- `LibdcWrapper.kt`: Add 3 new external function declarations
- `DiveComputerHostApiImpl.kt`: Expand `convertParsedDive()` to map all 14 sample
  fields, parse events, map deco model. Add `mapEventType()` with 25-type switch.

## Section 3: Windows Implementation (C++/WinRT)

### New Files

| File               | Purpose                                       |
|--------------------|-----------------------------------------------|
| ble_scanner.cc     | WinRT BluetoothLEAdvertisementWatcher          |
| ble_io_stream.cc   | WinRT GATT read/write with sync semaphore bridge|
| serial_scanner.cc  | SetupDiGetClassDevs COM port enumeration       |
| serial_io_stream.cc| Win32 CreateFile/ReadFile/WriteFile on COM port |
| dive_converter.cc  | libdc_parsed_dive_t -> Pigeon ParsedDive C++   |

### BLE Flow

1. Start `BluetoothLEAdvertisementWatcher`
2. On `Received` event, extract device name
3. Call `libdc_descriptor_match()` from shared C wrapper
4. Report matches via Pigeon `onDeviceDiscovered`
5. I/O stream uses `BluetoothLEDevice::FromBluetoothAddressAsync` for GATT access

### Serial Flow

1. Enumerate COM ports via `SetupDiGetClassDevs(GUID_DEVINTERFACE_COMPORT)`
2. Match against `libdc_descriptor_match()` with LIBDC_TRANSPORT_SERIAL
3. I/O stream wraps Win32 serial API, implements `libdc_io_callbacks_t`

### Build Changes

- Add `cppwinrt` NuGet package and `WindowsApp.lib`
- Add `/await` compiler flag for C++/WinRT coroutines
- Add new source files to CMakeLists.txt

### Threading

- BLE scanner on WinRT thread pool (coroutines)
- Download on background `std::thread`
- Callbacks dispatch to Flutter platform thread via `flutter::TaskRunner`

## Section 4: Linux Implementation (C/GLib + BlueZ D-Bus)

### New Files

| File               | Purpose                                        |
|--------------------|------------------------------------------------|
| ble_scanner.c      | BlueZ D-Bus discovery via GDBusConnection      |
| ble_io_stream.c    | BlueZ GATT read/write with GMutex/GCond bridge |
| serial_scanner.c   | Scan /dev/ttyUSB*, /dev/ttyACM* + udev metadata|
| serial_io_stream.c | POSIX serial open/read/write/tcsetattr          |
| dive_converter.c   | libdc_parsed_dive_t -> Pigeon GObject types     |

### BLE Flow

1. Get system bus via `g_bus_get_sync(G_BUS_TYPE_SYSTEM, ...)`
2. Call `org.bluez.Adapter1.SetDiscoveryFilter` with `{"Transport": "le"}`
3. Call `org.bluez.Adapter1.StartDiscovery`
4. Subscribe to `InterfacesAdded` signal on ObjectManager
5. For each device, read `Name` from `org.bluez.Device1`
6. Call `libdc_descriptor_match()`, report matches
7. I/O stream uses `GMutex`/`GCond` to bridge async D-Bus signals to sync callbacks

### Serial Flow

1. Scan `/dev/ttyUSB*` and `/dev/ttyACM*`
2. Read device info via udev or sysfs
3. Match against descriptors, report matches
4. I/O stream wraps POSIX serial, implements `libdc_io_callbacks_t`

### Build Changes

- Add `gio-2.0` to `pkg_check_modules` in CMakeLists.txt
- Add new source files

### Threading

- BLE scanner integrates with GLib main loop (GMainContext)
- Download on `GThread`
- Callbacks dispatch via `g_idle_add()`

### Permissions

BlueZ requires user in `bluetooth` group. Report clear error if D-Bus access denied.

## Section 5: Serial/USB Auto-Detection

Same UX as BLE discovery. User taps scan, platform enumerates ports, matches against
descriptors, reports recognized devices.

### Per-Platform Enumeration

| Platform  | Method                                    | Paths                    |
|-----------|-------------------------------------------|--------------------------|
| macOS/iOS | IOKit IOServiceMatching                   | /dev/cu.usbserial-*      |
| Android   | UsbManager.getDeviceList()                | USB file descriptors     |
| Windows   | SetupDiGetClassDevs(COMPORT GUID)         | \\.\COM3 etc.           |
| Linux     | Scan /dev/ttyUSB*, /dev/ttyACM* + udev   | /dev/ttyUSB0 etc.        |

### Matching Strategy

1. **USB VID/PID matching** for devices with known vendor/product IDs
2. **Fallback**: list unrecognized serial devices, let user manually associate with a
   known dive computer model. May require a `startDownloadManual(portPath, descriptor)`
   Pigeon method (deferred to follow-up).

### Android USB Specifics

Android USB Host API requires `UsbManager.requestPermission()` and
`UsbDeviceConnection.claimInterface()`. I/O callbacks wrap `bulkTransfer()` instead of
POSIX read/write.

## Section 6: Testing Strategy

### Layer 1: Shared C Wrapper Tests (macOS CI)

```text

test/native/
  test_sample_callback.c     - synthetic DC_SAMPLE_* values -> libdc_sample_t
  test_event_callback.c      - synthetic DC_SAMPLE_EVENT -> libdc_event_t
  test_deco_parsing.c        - synthetic DC_FIELD_DECOMODEL -> parsed fields
  test_descriptor_match.c    - BLE name -> descriptor matching
  CMakeLists.txt             - builds and runs via ctest

```

### Layer 2: Platform Mapping Tests

| Platform   | Framework              | Approach                              |
|------------|------------------------|---------------------------------------|
| macOS/iOS  | XCTest (Swift package) | Create libdc_parsed_dive_t, verify convertParsedDive() output |
| Android    | JUnit + Robolectric    | Mock JNI returns, verify Kotlin mapping|
| Windows    | Google Test            | Create struct, verify C++ mapping (CI) |
| Linux      | Google Test            | Create struct, verify C mapping (CI)   |

### Layer 3: Integration Tests (Dart)

Existing Dart test suite exercises ParsedDive consumption. No platform-specific changes.

### CI Pipeline

- macOS runner: shared C wrapper tests (ctest) + Swift package XCTests
- Windows runner: `flutter build windows` (compilation verification)
- Linux runner: `flutter build linux` with `libgtk-3-dev libbluez-dev` (compilation verification)

### Not Tested (by design)

- Actual BLE communication (requires physical hardware)
- WinRT/BlueZ API calls (mocking system APIs is fragile and low-value)
