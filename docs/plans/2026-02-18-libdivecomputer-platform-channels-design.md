# Libdivecomputer Platform Channels Architecture

## Overview

Replace the current dual-stack dive computer communication layer (Dart BLE protocols + `dive_computer` FFI package) with a unified Flutter plugin that wraps libdivecomputer in native code via platform channels. This eliminates `flutter_blue_plus`, 4 custom Dart BLE protocol implementations, and the `dive_computer` FFI package in favor of libdivecomputer's battle-tested protocol engine running natively on each platform.

## Motivation

- **Device compatibility:** libdivecomputer supports 300+ dive computer models with community-tested protocol implementations. Using it natively (not bridged through Dart async) minimizes the risk of subtle timing/buffering bugs across devices we cannot individually test.
- **Simplified architecture:** Collapse two communication stacks (Dart BLE + FFI USB) into one unified path.
- **Maintenance:** When libdivecomputer adds a new device or fixes a protocol bug, we get it automatically by updating the submodule.

## Decisions

| Decision | Choice |
|---|---|
| Packaging approach | Federated Flutter plugin + Pigeon type-safe channels |
| Platforms | All 5 simultaneously (macOS, iOS, Android, Windows, Linux) |
| Existing Dart BLE protocols | Delete entirely |
| Existing `dive_computer` FFI package | Replace completely |
| Discovery API | Thin discovery + native download lifecycle |
| Data returned | Parsed structured data (native-side parsing) |
| Device catalog | Use libdivecomputer's `dc_descriptor_iterator` |
| Build integration | Compile libdivecomputer from source per platform (git submodule) |

## Pigeon API Contract

```dart
// pigeons/dive_computer_api.dart

import 'package:pigeon/pigeon.dart';

// === Enums ===

enum TransportType { ble, usb, serial, infrared }

// === Data Classes ===

class DeviceDescriptor {
  final String vendor;
  final String product;
  final int model;
  final List<TransportType> transports;
}

class DiscoveredDevice {
  final DeviceDescriptor descriptor;
  final String address;
  final String? name;
  final TransportType transport;
}

class ProfileSample {
  final int timeSeconds;
  final double depthMeters;
  final double? temperatureCelsius;
  final double? pressureBar;
  final int? tankIndex;
  final double? heartRate;
}

class GasMix {
  final int index;
  final double o2Percent;
  final double hePercent;
}

class TankInfo {
  final int index;
  final GasMix gasMix;
  final double? volumeLiters;
  final double? startPressureBar;
  final double? endPressureBar;
}

class DiveEvent {
  final int timeSeconds;
  final String type;
  final Map<String, String>? data;
}

class ParsedDive {
  final String fingerprint;
  final int dateTimeEpoch;
  final double maxDepthMeters;
  final double avgDepthMeters;
  final int durationSeconds;
  final double? minTemperatureCelsius;
  final double? maxTemperatureCelsius;
  final List<ProfileSample> samples;
  final List<TankInfo> tanks;
  final List<GasMix> gasMixes;
  final List<DiveEvent> events;
  final String? diveMode;
}

class DownloadProgress {
  final int current;
  final int total;
  final String status;
}

class DiveComputerError {
  final String code;
  final String message;
}

// === Host API (Dart -> Native) ===

@HostApi()
abstract class DiveComputerHostApi {
  @async List<DeviceDescriptor> getDeviceDescriptors();
  @async void startDiscovery(TransportType transport);
  void stopDiscovery();
  @async void startDownload(DiscoveredDevice device);
  void cancelDownload();
  String getLibdivecomputerVersion();
}

// === Flutter API (Native -> Dart) ===

@FlutterApi()
abstract class DiveComputerFlutterApi {
  void onDeviceDiscovered(DiscoveredDevice device);
  void onDiscoveryComplete();
  void onDownloadProgress(DownloadProgress progress);
  void onDiveDownloaded(ParsedDive dive);
  void onDownloadComplete(int totalDives);
  void onError(DiveComputerError error);
}
```

### Design Decisions

- All measurements in metric. Dart side handles unit conversion for display.
- Fingerprint as hex string for Dart-side comparison and database storage.
- Streaming callbacks via `@FlutterApi` for real-time progress. No buffering.
- `getDeviceDescriptors()` replaces the hand-curated `device_library.dart`.
- Error codes are strings for extensibility.

## Plugin Package Structure

```
packages/libdivecomputer_plugin/
  pubspec.yaml
  pigeons/
    dive_computer_api.dart
  lib/
    libdivecomputer_plugin.dart
    src/
      generated/
      dive_computer_service.dart
  third_party/
    libdivecomputer/                  # git submodule
  ios/
    Classes/
      LibdivecomputerPlugin.swift
      DiveComputerHostApiImpl.swift
      BleTransport.swift              # CoreBluetooth custom dc_iostream
      LibdcWrapper.swift              # libdivecomputer C API calls
      DiveParser.swift                # dc_parser to ParsedDive
    libdivecomputer.xcconfig
  macos/
    Classes/
      LibdivecomputerPlugin.swift
      DiveComputerHostApiImpl.swift   # shared with iOS via symlinks
      BleTransport.swift              # macOS CoreBluetooth variant
    libdivecomputer.xcconfig
  android/
    src/main/kotlin/.../
      LibdivecomputerPlugin.kt
      DiveComputerHostApiImpl.kt
      BleTransport.kt                # Android BLE custom dc_iostream
      UsbTransport.kt                # Android USB host API
      LibdcWrapper.kt                # JNI bridge
      DiveParser.kt
    CMakeLists.txt                    # NDK build for libdivecomputer
  linux/
    libdivecomputer_plugin.cc
    dive_computer_host_api_impl.cc
    CMakeLists.txt
  windows/
    libdivecomputer_plugin.cpp
    dive_computer_host_api_impl.cpp
    CMakeLists.txt
  test/
    libdivecomputer_plugin_test.dart
    mock_dive_computer_api.dart
```

## Native Wrapper Architecture

### Desktop (macOS, Linux, Windows)

Use libdivecomputer's native BLE and USB backends directly. Thin wrapper:

1. `dc_context_new()` - create context
2. `dc_descriptor_iterator()` - find matching descriptor
3. `dc_device_open()` - open device (native backend handles BLE/USB)
4. `dc_device_set_events()` - register event callback
5. `dc_device_set_fingerprint()` - skip already-downloaded dives
6. `dc_device_foreach()` - download loop (blocks until done)
   - Per dive: `dc_parser_new()` -> extract fields -> profile samples -> convert to `ParsedDive` -> send via `FlutterApi`
7. `dc_device_close()` + `dc_context_free()`

Discovery uses `dc_bluetooth_enumerate()` or `dc_usbhid_enumerate()`.

### Mobile (iOS, Android)

Custom `dc_iostream_t` bridging native async BLE to libdivecomputer's synchronous I/O:

- **Download thread** (background): `dc_device_foreach()` calls `dc_iostream_t.read/write`, which block on a semaphore.
- **BLE thread** (main/dispatch queue): CoreBluetooth/Android BLE callbacks append data to buffer and signal the semaphore.

**iOS:** `DispatchSemaphore` for thread synchronization. `CBCentralManager` for discovery, `CBPeripheral` for data transfer.

**Android:** `CountDownLatch` for synchronization. `BluetoothLeScanner` for discovery, `BluetoothGatt` for data transfer. USB via Android USB Host API with file descriptor passed to libdivecomputer.

### Threading Model

| Platform | Download Thread | BLE Thread | Sync Mechanism |
|---|---|---|---|
| macOS | Background DispatchQueue | libdivecomputer internal | N/A |
| iOS | Background DispatchQueue | CBCentralManager queue | DispatchSemaphore |
| Android | ExecutorService thread | BLE callback thread | CountDownLatch |
| Linux | std::thread | libdivecomputer internal (BlueZ) | N/A |
| Windows | std::thread | libdivecomputer internal (WinRT) | N/A |

### Build Integration

| Platform | Build System | Notes |
|---|---|---|
| iOS | Xcode + CMake via podspec script_phase | Cross-compile arm64. Static library. |
| macOS | Xcode + CMake via podspec script_phase | Universal binary (x86_64 + arm64). Native BLE backend. |
| Android | Gradle + NDK CMake | Cross-compile armeabi-v7a, arm64-v8a, x86_64. JNI wrapper. |
| Linux | CMake (Flutter native build) | Links system libusb, BlueZ. |
| Windows | CMake (Flutter native build) | Links WinUSB, WinRT BLE. |

## Dart-Side Architecture

### Deleted

| Component | Reason |
|---|---|
| `shearwater_ble_protocol.dart` | Replaced by libdivecomputer native |
| `suunto_ble_protocol.dart` | Replaced by libdivecomputer native |
| `aqualung_ble_protocol.dart` | Replaced by libdivecomputer native |
| `mares_ble_protocol.dart` | Replaced by libdivecomputer native |
| `bluetooth_connection_manager.dart` | Replaced by plugin discovery |
| `libdc_ffi_download_manager.dart` | Replaced by plugin download |
| `libdc_download_manager.dart` | Replaced by plugin download |
| `libdc_parser_service.dart` | Parsing now native-side |
| `dive_parser.dart` | Parsing now native-side |
| `device_library.dart` | Replaced by `getDeviceDescriptors()` |
| `permissions_service.dart` | Permissions handled by plugin |
| `connection_manager.dart` | Replaced by plugin API |
| `download_manager.dart` | Replaced by plugin API |
| `flutter_blue_plus` dependency | No longer needed |
| `flutter_blue_plus_winrt` + `third_party/` | No longer needed |
| `dive_computer` FFI dependency | No longer needed |

### Modified

| Component | Change |
|---|---|
| `device_model.dart` | Simplify to thin wrapper around Pigeon `DeviceDescriptor` |
| `discovery_providers.dart` | Rewrite to consume plugin discovery stream |
| `download_providers.dart` | Rewrite to consume plugin download callbacks |
| `device_discovery_page.dart` | Adapt to new provider shape (UI stays similar) |
| `device_download_page.dart` | Adapt to new provider shape |
| `dive_computer_repository_impl.dart` | Map `ParsedDive` to domain `Dive` |

### Unchanged

| Component | Why |
|---|---|
| `dive_import_service.dart` | Duplicate detection is transport-agnostic |
| `device_list_page.dart` | Saved computers UI unchanged |
| `device_detail_page.dart` | Device info display unchanged |
| All wearable import code | Completely separate flow |
| `dive_computer.dart` entity | Domain entity unchanged |

### New Data Flow

```
Plugin: DiveComputerFlutterApi callbacks
    |
DiveComputerService (plugin package)
    - discoverDevices() -> Stream<DiscoveredDevice>
    - downloadDives(device) -> Stream<DownloadEvent>
    |
Riverpod Providers
    - deviceDescriptorsProvider: FutureProvider<List<DeviceDescriptor>>
    - discoveryProvider: StreamNotifierProvider
    - downloadProvider: StreamNotifierProvider
    |
ParsedDive -> Dive mapping (DiveComputerRepository)
    |
DiveImportService (duplicate detection)
    |
DiveRepository -> Drift database
```

## Dependency Changes

### Removed

```yaml
flutter_blue_plus: ^2.1.0
dive_computer: ^0.1.0-dev.2
```

```
third_party/flutter_blue_plus_winrt/   # directory deleted
```

### Added

```yaml
dependencies:
  libdivecomputer_plugin:
    path: packages/libdivecomputer_plugin

dev_dependencies:
  pigeon: ^22.0.0
```

```
packages/libdivecomputer_plugin/
packages/libdivecomputer_plugin/third_party/libdivecomputer/  # git submodule
```

### Platform Configuration

| Platform | Changes |
|---|---|
| iOS | Add Bluetooth background mode, `NSBluetoothAlwaysUsageDescription` |
| macOS | Add Bluetooth entitlement, USB entitlement, App Sandbox Bluetooth |
| Android | Add `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`, USB host feature, NDK CMake |
| Linux | Link libusb-1.0, bluez dev libraries |
| Windows | Link WinUSB, WinRT BLE APIs |

## Testing Strategy

### Layer 1: Dart Unit Tests

- Mock Pigeon `DiveComputerHostApi`
- Test `DiveComputerService` stream behavior
- Test `ParsedDive` to domain `Dive` mapping
- Test provider state transitions
- Test duplicate detection with fingerprints
- Run: `flutter test`

### Layer 2: Native Unit Tests

- Test `DiveParser`: feed known binary data through `dc_parser_*`, verify `ParsedDive` output
- Test `LibdcWrapper`: mock C API calls, verify lifecycle
- Test `BleTransport` (mobile): mock BLE callbacks, verify synchronization
- Run: XCTest (Apple), JUnit (Android), Google Test (Linux/Windows)

### Layer 3: Integration Tests

- Use libdivecomputer's sample binary dumps from its test suite
- Feed through full native pipeline, verify `ParsedDive` output
- Validates compilation, linking, and correctness per platform
- Runs in CI without physical hardware

### Layer 4: Manual Device Testing

- Test with available physical dive computers
- Verify discovery, pairing, download, data correctness
- Document verified devices

## Scope Boundaries

### In Scope

- Plugin package with all 5 platform implementations
- Pigeon API contract and code generation
- libdivecomputer git submodule and per-platform build
- Dart-side service, providers, and repository changes
- Deletion of replaced Dart code and dependencies
- Tests for all 4 layers

### Out of Scope

- Wearable import flows (HealthKit, FIT, UDDF) -- unchanged
- Universal import flows (CSV, UDDF file import) -- unchanged
- Database schema changes -- none needed
- UI redesign -- existing wizard pages adapt to new providers
- Cloud API support (Garmin Connect, Shearwater Cloud) -- future work
- Background auto-download -- future work
