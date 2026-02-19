# Libdivecomputer Platform Channels Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace flutter_blue_plus and custom Dart BLE protocols with a unified Flutter plugin wrapping libdivecomputer via Pigeon-generated type-safe platform channels.

**Architecture:** Federated Flutter plugin (`packages/libdivecomputer_plugin/`) with Pigeon-generated type-safe channels. Native wrappers per platform call libdivecomputer's C API directly. Desktop platforms use libdivecomputer's native BLE/USB backends. Mobile platforms provide custom `dc_iostream_t` implementations bridging async BLE to libdivecomputer's synchronous I/O via semaphores.

**Tech Stack:** Flutter, Pigeon, libdivecomputer (C), Swift (iOS/macOS), Kotlin + JNI (Android), C++ (Linux/Windows), CMake, CoreBluetooth, Android BLE API

**Design Doc:** `docs/plans/2026-02-18-libdivecomputer-platform-channels-design.md`

---

## Phase 1: Plugin Scaffold and Pigeon API

### Task 1: Create Plugin Package Structure

**Files:**
- Create: `packages/libdivecomputer_plugin/pubspec.yaml`
- Create: `packages/libdivecomputer_plugin/lib/libdivecomputer_plugin.dart`
- Create: `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart`

**Step 1: Create the plugin package directory**

```bash
mkdir -p packages/libdivecomputer_plugin/lib/src/generated
mkdir -p packages/libdivecomputer_plugin/pigeons
mkdir -p packages/libdivecomputer_plugin/test
mkdir -p packages/libdivecomputer_plugin/ios/Classes
mkdir -p packages/libdivecomputer_plugin/macos/Classes
mkdir -p packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer
mkdir -p packages/libdivecomputer_plugin/linux
mkdir -p packages/libdivecomputer_plugin/windows
mkdir -p packages/libdivecomputer_plugin/third_party
```

**Step 2: Write pubspec.yaml**

Create `packages/libdivecomputer_plugin/pubspec.yaml`:

```yaml
name: libdivecomputer_plugin
description: Flutter plugin wrapping libdivecomputer for dive computer communication.
version: 0.1.0

environment:
  sdk: ^3.10.0
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter
  pigeon: ^22.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  plugin:
    platforms:
      ios:
        pluginClass: LibdivecomputerPlugin
      macos:
        pluginClass: LibdivecomputerPlugin
      android:
        package: com.submersion.libdivecomputer
        pluginClass: LibdivecomputerPlugin
      linux:
        pluginClass: LibdivecomputerPlugin
      windows:
        pluginClass: LibdivecomputerPlugin
```

**Step 3: Write the public API barrel file**

Create `packages/libdivecomputer_plugin/lib/libdivecomputer_plugin.dart`:

```dart
export 'src/generated/dive_computer_api.g.dart';
export 'src/dive_computer_service.dart';
```

**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/
git commit -m "feat: scaffold libdivecomputer plugin package"
```

---

### Task 2: Write Pigeon API Schema

**Files:**
- Create: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`

**Step 1: Write the Pigeon schema**

Create `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` with the full API contract from the design doc:

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/dive_computer_api.g.dart',
    swiftOut: 'ios/Classes/DiveComputerApi.g.swift',
    kotlinOut:
        'android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.submersion.libdivecomputer',
    ),
    cppHeaderOut: 'linux/dive_computer_api.g.h',
    cppSourceOut: 'linux/dive_computer_api.g.cc',
    cppOptions: CppOptions(namespace: 'libdivecomputer_plugin'),
  ),
)

// === Enums ===

enum TransportType { ble, usb, serial, infrared }

// === Data Classes ===

class DeviceDescriptor {
  const DeviceDescriptor({
    required this.vendor,
    required this.product,
    required this.model,
    required this.transports,
  });
  final String vendor;
  final String product;
  final int model;
  final List<TransportType> transports;
}

class DiscoveredDevice {
  const DiscoveredDevice({
    required this.vendor,
    required this.product,
    required this.model,
    required this.address,
    this.name,
    required this.transport,
  });
  final String vendor;
  final String product;
  final int model;
  final String address;
  final String? name;
  final TransportType transport;
}

class ProfileSample {
  const ProfileSample({
    required this.timeSeconds,
    required this.depthMeters,
    this.temperatureCelsius,
    this.pressureBar,
    this.tankIndex,
    this.heartRate,
  });
  final int timeSeconds;
  final double depthMeters;
  final double? temperatureCelsius;
  final double? pressureBar;
  final int? tankIndex;
  final double? heartRate;
}

class GasMix {
  const GasMix({
    required this.index,
    required this.o2Percent,
    required this.hePercent,
  });
  final int index;
  final double o2Percent;
  final double hePercent;
}

class TankInfo {
  const TankInfo({
    required this.index,
    required this.gasMixIndex,
    this.volumeLiters,
    this.startPressureBar,
    this.endPressureBar,
  });
  final int index;
  final int gasMixIndex;
  final double? volumeLiters;
  final double? startPressureBar;
  final double? endPressureBar;
}

class DiveEvent {
  const DiveEvent({
    required this.timeSeconds,
    required this.type,
    this.data,
  });
  final int timeSeconds;
  final String type;
  final Map<String?, String?>? data;
}

class ParsedDive {
  const ParsedDive({
    required this.fingerprint,
    required this.dateTimeEpoch,
    required this.maxDepthMeters,
    required this.avgDepthMeters,
    required this.durationSeconds,
    this.minTemperatureCelsius,
    this.maxTemperatureCelsius,
    required this.samples,
    required this.tanks,
    required this.gasMixes,
    required this.events,
    this.diveMode,
  });
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
  const DownloadProgress({
    required this.current,
    required this.total,
    required this.status,
  });
  final int current;
  final int total;
  final String status;
}

class DiveComputerError {
  const DiveComputerError({
    required this.code,
    required this.message,
  });
  final String code;
  final String message;
}

// === Host API (Dart -> Native) ===

@HostApi()
abstract class DiveComputerHostApi {
  @async
  List<DeviceDescriptor> getDeviceDescriptors();

  @async
  void startDiscovery(TransportType transport);

  void stopDiscovery();

  @async
  void startDownload(DiscoveredDevice device);

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

**Step 2: Run Pigeon code generation**

```bash
cd packages/libdivecomputer_plugin
dart run pigeon --input pigeons/dive_computer_api.dart
```

This generates:
- `lib/src/generated/dive_computer_api.g.dart` (Dart)
- `ios/Classes/DiveComputerApi.g.swift` (Swift)
- `android/src/main/kotlin/.../DiveComputerApi.g.kt` (Kotlin)
- `linux/dive_computer_api.g.h` + `dive_computer_api.g.cc` (C++)

**Step 3: Verify generated code compiles**

```bash
cd packages/libdivecomputer_plugin
dart analyze lib/
```

Expected: No errors.

**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/pigeons/ packages/libdivecomputer_plugin/lib/src/generated/
git add packages/libdivecomputer_plugin/ios/Classes/DiveComputerApi.g.swift
git add packages/libdivecomputer_plugin/android/src/main/kotlin/
git add packages/libdivecomputer_plugin/linux/dive_computer_api.g.*
git commit -m "feat: add Pigeon API schema and generated code"
```

---

### Task 3: Write Dart-side DiveComputerService

**Files:**
- Create: `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart`
- Create: `packages/libdivecomputer_plugin/test/dive_computer_service_test.dart`

**Step 1: Write the failing test**

Create `packages/libdivecomputer_plugin/test/dive_computer_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/src/dive_computer_service.dart';
import 'package:libdivecomputer_plugin/src/generated/dive_computer_api.g.dart';

/// Mock implementation of DiveComputerHostApi for testing.
class MockDiveComputerHostApi implements DiveComputerHostApi {
  List<DeviceDescriptor> descriptorsToReturn = [];
  String versionToReturn = '0.0.0';
  bool startDiscoveryCalled = false;
  bool stopDiscoveryCalled = false;
  bool startDownloadCalled = false;
  bool cancelDownloadCalled = false;
  TransportType? lastDiscoveryTransport;
  DiscoveredDevice? lastDownloadDevice;

  @override
  Future<List<DeviceDescriptor>> getDeviceDescriptors() async {
    return descriptorsToReturn;
  }

  @override
  Future<void> startDiscovery(TransportType transport) async {
    startDiscoveryCalled = true;
    lastDiscoveryTransport = transport;
  }

  @override
  void stopDiscovery() {
    stopDiscoveryCalled = true;
  }

  @override
  Future<void> startDownload(DiscoveredDevice device) async {
    startDownloadCalled = true;
    lastDownloadDevice = device;
  }

  @override
  void cancelDownload() {
    cancelDownloadCalled = true;
  }

  @override
  String getLibdivecomputerVersion() {
    return versionToReturn;
  }
}

void main() {
  late MockDiveComputerHostApi mockHostApi;
  late DiveComputerService service;

  setUp(() {
    mockHostApi = MockDiveComputerHostApi();
    service = DiveComputerService(hostApi: mockHostApi);
  });

  tearDown(() {
    service.dispose();
  });

  group('getDeviceDescriptors', () {
    test('returns device descriptors from host API', () async {
      mockHostApi.descriptorsToReturn = [
        DeviceDescriptor(
          vendor: 'Shearwater',
          product: 'Perdix',
          model: 1,
          transports: [TransportType.ble],
        ),
      ];

      final descriptors = await service.getDeviceDescriptors();

      expect(descriptors, hasLength(1));
      expect(descriptors.first.vendor, 'Shearwater');
      expect(descriptors.first.product, 'Perdix');
    });
  });

  group('getVersion', () {
    test('returns libdivecomputer version', () {
      mockHostApi.versionToReturn = '0.8.0';
      expect(service.getVersion(), '0.8.0');
    });
  });

  group('discovery', () {
    test('startDiscovery calls host API with transport', () async {
      await service.startDiscovery(TransportType.ble);
      expect(mockHostApi.startDiscoveryCalled, isTrue);
      expect(mockHostApi.lastDiscoveryTransport, TransportType.ble);
    });

    test('stopDiscovery calls host API', () {
      service.stopDiscovery();
      expect(mockHostApi.stopDiscoveryCalled, isTrue);
    });

    test('discoveredDevices stream emits devices', () async {
      final device = DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 1,
        address: '00:11:22:33:44:55',
        name: 'Perdix 12345',
        transport: TransportType.ble,
      );

      // Simulate a device discovered callback
      expectLater(
        service.discoveredDevices,
        emits(device),
      );

      service.handleDeviceDiscovered(device);
    });
  });

  group('download', () {
    test('startDownload calls host API', () async {
      final device = DiscoveredDevice(
        vendor: 'Shearwater',
        product: 'Perdix',
        model: 1,
        address: '00:11:22:33:44:55',
        transport: TransportType.ble,
      );

      await service.startDownload(device);
      expect(mockHostApi.startDownloadCalled, isTrue);
      expect(mockHostApi.lastDownloadDevice?.vendor, 'Shearwater');
    });

    test('cancelDownload calls host API', () {
      service.cancelDownload();
      expect(mockHostApi.cancelDownloadCalled, isTrue);
    });

    test('downloadEvents stream emits progress', () async {
      final progress = DownloadProgress(
        current: 1,
        total: 5,
        status: 'Downloading dive 1 of 5',
      );

      expectLater(
        service.downloadEvents,
        emits(isA<DownloadProgressEvent>()),
      );

      service.handleDownloadProgress(progress);
    });

    test('downloadEvents stream emits dives', () async {
      final dive = ParsedDive(
        fingerprint: 'abc123',
        dateTimeEpoch: 1700000000,
        maxDepthMeters: 30.0,
        avgDepthMeters: 15.0,
        durationSeconds: 3600,
        samples: [],
        tanks: [],
        gasMixes: [],
        events: [],
      );

      expectLater(
        service.downloadEvents,
        emits(isA<DiveDownloadedEvent>()),
      );

      service.handleDiveDownloaded(dive);
    });
  });
}
```

**Step 2: Run the test to verify it fails**

```bash
cd packages/libdivecomputer_plugin
flutter test test/dive_computer_service_test.dart
```

Expected: FAIL (DiveComputerService not defined).

**Step 3: Write DiveComputerService implementation**

Create `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart`:

```dart
import 'dart:async';
import 'package:libdivecomputer_plugin/src/generated/dive_computer_api.g.dart';

/// Events emitted during a download.
sealed class DownloadEvent {}

class DownloadProgressEvent extends DownloadEvent {
  final DownloadProgress progress;
  DownloadProgressEvent(this.progress);
}

class DiveDownloadedEvent extends DownloadEvent {
  final ParsedDive dive;
  DiveDownloadedEvent(this.dive);
}

class DownloadCompleteEvent extends DownloadEvent {
  final int totalDives;
  DownloadCompleteEvent(this.totalDives);
}

class DownloadErrorEvent extends DownloadEvent {
  final DiveComputerError error;
  DownloadErrorEvent(this.error);
}

/// High-level Dart service wrapping the Pigeon DiveComputerHostApi.
///
/// Provides a Stream-based interface over the callback-based Pigeon API.
/// Also implements DiveComputerFlutterApi to receive native callbacks.
class DiveComputerService implements DiveComputerFlutterApi {
  final DiveComputerHostApi _hostApi;

  final _discoveredDevicesController =
      StreamController<DiscoveredDevice>.broadcast();
  final _discoveryCompleteController = StreamController<void>.broadcast();
  final _downloadEventsController =
      StreamController<DownloadEvent>.broadcast();

  DiveComputerService({DiveComputerHostApi? hostApi})
      : _hostApi = hostApi ?? DiveComputerHostApi();

  /// Stream of discovered devices during scanning.
  Stream<DiscoveredDevice> get discoveredDevices =>
      _discoveredDevicesController.stream;

  /// Stream that emits when discovery is complete.
  Stream<void> get discoveryComplete => _discoveryCompleteController.stream;

  /// Stream of download events (progress, dives, complete, error).
  Stream<DownloadEvent> get downloadEvents =>
      _downloadEventsController.stream;

  /// Get all known device descriptors from libdivecomputer.
  Future<List<DeviceDescriptor>> getDeviceDescriptors() {
    return _hostApi.getDeviceDescriptors();
  }

  /// Get the libdivecomputer version string.
  String getVersion() {
    return _hostApi.getLibdivecomputerVersion();
  }

  /// Start scanning for dive computers.
  Future<void> startDiscovery(TransportType transport) {
    return _hostApi.startDiscovery(transport);
  }

  /// Stop scanning.
  void stopDiscovery() {
    _hostApi.stopDiscovery();
  }

  /// Start downloading dives from a discovered device.
  Future<void> startDownload(DiscoveredDevice device) {
    return _hostApi.startDownload(device);
  }

  /// Cancel an ongoing download.
  void cancelDownload() {
    _hostApi.cancelDownload();
  }

  // === DiveComputerFlutterApi callbacks (called from native) ===

  @override
  void onDeviceDiscovered(DiscoveredDevice device) {
    handleDeviceDiscovered(device);
  }

  @override
  void onDiscoveryComplete() {
    _discoveryCompleteController.add(null);
  }

  @override
  void onDownloadProgress(DownloadProgress progress) {
    handleDownloadProgress(progress);
  }

  @override
  void onDiveDownloaded(ParsedDive dive) {
    handleDiveDownloaded(dive);
  }

  @override
  void onDownloadComplete(int totalDives) {
    _downloadEventsController.add(DownloadCompleteEvent(totalDives));
  }

  @override
  void onError(DiveComputerError error) {
    _downloadEventsController.add(DownloadErrorEvent(error));
  }

  // === Test helpers (also used internally by callbacks) ===

  void handleDeviceDiscovered(DiscoveredDevice device) {
    _discoveredDevicesController.add(device);
  }

  void handleDownloadProgress(DownloadProgress progress) {
    _downloadEventsController.add(DownloadProgressEvent(progress));
  }

  void handleDiveDownloaded(ParsedDive dive) {
    _downloadEventsController.add(DiveDownloadedEvent(dive));
  }

  /// Dispose of all stream controllers.
  void dispose() {
    _discoveredDevicesController.close();
    _discoveryCompleteController.close();
    _downloadEventsController.close();
  }
}
```

**Step 4: Run tests to verify they pass**

```bash
cd packages/libdivecomputer_plugin
flutter test test/dive_computer_service_test.dart
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart
git add packages/libdivecomputer_plugin/test/
git commit -m "feat: add DiveComputerService with stream-based API and tests"
```

---

## Phase 2: libdivecomputer Submodule and macOS Build

### Task 4: Add libdivecomputer Git Submodule

**Step 1: Add the submodule**

```bash
cd packages/libdivecomputer_plugin
git submodule add https://github.com/libdivecomputer/libdivecomputer.git third_party/libdivecomputer
```

**Step 2: Verify the submodule**

```bash
ls packages/libdivecomputer_plugin/third_party/libdivecomputer/include/libdivecomputer/
```

Expected: Header files like `context.h`, `device.h`, `descriptor.h`, `parser.h`, `iostream.h`, etc.

**Step 3: Add .gitmodules entry and commit**

```bash
git add .gitmodules packages/libdivecomputer_plugin/third_party/libdivecomputer
git commit -m "chore: add libdivecomputer as git submodule"
```

---

### Task 5: macOS Build Configuration

**Files:**
- Create: `packages/libdivecomputer_plugin/macos/libdivecomputer_plugin.podspec`
- Create: `packages/libdivecomputer_plugin/macos/Classes/LibdivecomputerPlugin.swift`
- Modify: `packages/libdivecomputer_plugin/macos/CMakeLists.txt` (if needed)

**Step 1: Create the podspec**

Create `packages/libdivecomputer_plugin/macos/libdivecomputer_plugin.podspec`:

```ruby
Pod::Spec.new do |s|
  s.name             = 'libdivecomputer_plugin'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin wrapping libdivecomputer'
  s.homepage         = 'https://github.com/submersion/submersion'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Submersion' => 'dev@submersion.app' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '12.0'
  s.swift_version    = '5.9'

  # Build libdivecomputer from source
  s.preserve_paths   = '../third_party/libdivecomputer/**/*'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../third_party/libdivecomputer/include"',
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../third_party/libdivecomputer/.libs"',
    'OTHER_LDFLAGS' => '-ldivecomputer',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
  }

  # Script phase to build libdivecomputer
  s.script_phase = {
    :name => 'Build libdivecomputer',
    :script => <<-SCRIPT
      cd "${PODS_TARGET_SRCROOT}/../third_party/libdivecomputer"
      if [ ! -f .libs/libdivecomputer.a ]; then
        autoreconf --install
        ./configure --disable-shared --enable-static --disable-examples
        make -j$(sysctl -n hw.ncpu)
      fi
    SCRIPT
    :execution_position => :before_compile,
  }
end
```

**Step 2: Create minimal plugin registration**

Create `packages/libdivecomputer_plugin/macos/Classes/LibdivecomputerPlugin.swift`:

```swift
import FlutterMacOS

public class LibdivecomputerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger
        let api = DiveComputerHostApiImpl(messenger: messenger)
        DiveComputerHostApiSetup.setUp(binaryMessenger: messenger, api: api)
    }
}
```

**Step 3: Create a minimal HostApi implementation that returns the version**

Create `packages/libdivecomputer_plugin/macos/Classes/DiveComputerHostApiImpl.swift`:

```swift
import FlutterMacOS

class DiveComputerHostApiImpl: DiveComputerHostApi {
    private let messenger: FlutterBinaryMessenger
    private let flutterApi: DiveComputerFlutterApi

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        self.flutterApi = DiveComputerFlutterApi(binaryMessenger: messenger)
    }

    func getDeviceDescriptors(completion: @escaping (Result<[DeviceDescriptor], any Error>) -> Void) {
        // TODO: Implement with dc_descriptor_iterator
        completion(.success([]))
    }

    func startDiscovery(transport: TransportType, completion: @escaping (Result<Void, any Error>) -> Void) {
        // TODO: Implement with dc_bluetooth_enumerate or dc_usbhid_enumerate
        completion(.success(()))
    }

    func stopDiscovery() {
        // TODO: Stop discovery
    }

    func startDownload(device: DiscoveredDevice, completion: @escaping (Result<Void, any Error>) -> Void) {
        // TODO: Implement download lifecycle
        completion(.success(()))
    }

    func cancelDownload() {
        // TODO: Cancel download
    }

    func getLibdivecomputerVersion() -> String {
        // TODO: Call dc_version() via C interop
        return "0.0.0-stub"
    }
}
```

**Step 4: Add plugin dependency to main app**

Modify `pubspec.yaml` to add the plugin:

```yaml
# In dependencies section, add:
  libdivecomputer_plugin:
    path: packages/libdivecomputer_plugin
```

**Step 5: Run flutter pub get and verify macOS builds**

```bash
flutter pub get
flutter build macos --debug 2>&1 | head -50
```

Expected: Build succeeds (or at least plugin is recognized). libdivecomputer may not build yet -- that's OK at this step, focus on Flutter plugin registration.

**Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/
git add pubspec.yaml
git commit -m "feat: macOS plugin scaffold with podspec and stub HostApi"
```

---

### Task 6: Build libdivecomputer on macOS and Wire Up dc_version()

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/DiveComputerHostApiImpl.swift`
- Create: `packages/libdivecomputer_plugin/macos/Classes/LibdcBridge.h` (bridging header)

**Step 1: Create a bridging header to import libdivecomputer C API**

Create `packages/libdivecomputer_plugin/macos/Classes/LibdcBridge.h`:

```c
#ifndef LibdcBridge_h
#define LibdcBridge_h

#include <libdivecomputer/context.h>
#include <libdivecomputer/descriptor.h>
#include <libdivecomputer/device.h>
#include <libdivecomputer/parser.h>
#include <libdivecomputer/iostream.h>
#include <libdivecomputer/bluetooth.h>
#include <libdivecomputer/usbhid.h>
#include <libdivecomputer/version.h>

#endif
```

**Step 2: Update DiveComputerHostApiImpl to call dc_version()**

Update `getLibdivecomputerVersion()` in `DiveComputerHostApiImpl.swift`:

```swift
func getLibdivecomputerVersion() -> String {
    guard let version = dc_version_string() else {
        return "unknown"
    }
    return String(cString: version)
}
```

**Step 3: Build and test**

```bash
flutter build macos --debug
flutter run -d macos
```

In the app, add a temporary test to call `getLibdivecomputerVersion()` and verify it returns a real version string (e.g., "0.8.0").

**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/
git commit -m "feat: wire up dc_version() on macOS via C bridging header"
```

---

## Phase 3: macOS Native Implementation

### Task 7: Implement Device Descriptor Enumeration (macOS)

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/DiveComputerHostApiImpl.swift`
- Create: `packages/libdivecomputer_plugin/macos/Classes/LibdcWrapper.swift`

**Step 1: Write LibdcWrapper with descriptor enumeration**

Create `packages/libdivecomputer_plugin/macos/Classes/LibdcWrapper.swift`:

```swift
import Foundation

/// Wraps libdivecomputer C API calls with Swift-friendly types.
class LibdcWrapper {

    /// Enumerate all known device descriptors from libdivecomputer.
    static func getDeviceDescriptors() -> [DeviceDescriptor] {
        var descriptors: [DeviceDescriptor] = []

        var iterator: OpaquePointer? = nil
        var status = dc_descriptor_iterator(&iterator)
        guard status == DC_STATUS_SUCCESS, let iter = iterator else {
            return descriptors
        }
        defer { dc_iterator_free(iter) }

        var descriptor: OpaquePointer? = nil
        while dc_iterator_next(iter, &descriptor) == DC_STATUS_SUCCESS {
            guard let desc = descriptor else { continue }
            defer { dc_descriptor_free(desc) }

            let vendor = String(cString: dc_descriptor_get_vendor(desc))
            let product = String(cString: dc_descriptor_get_product(desc))
            let model = Int64(dc_descriptor_get_model(desc))

            // Get supported transports
            var transports: [TransportType] = []
            let transport = dc_descriptor_get_transports(desc)
            if transport & UInt32(DC_TRANSPORT_BLE.rawValue) != 0 {
                transports.append(.ble)
            }
            if transport & UInt32(DC_TRANSPORT_USB.rawValue) != 0 {
                transports.append(.usb)
            }
            if transport & UInt32(DC_TRANSPORT_SERIAL.rawValue) != 0 {
                transports.append(.serial)
            }
            if transport & UInt32(DC_TRANSPORT_IRDA.rawValue) != 0 {
                transports.append(.infrared)
            }

            descriptors.append(DeviceDescriptor(
                vendor: vendor,
                product: product,
                model: model,
                transports: transports
            ))
        }

        return descriptors
    }
}
```

Note: The exact C API names (`dc_descriptor_get_transports`, `DC_TRANSPORT_BLE`, etc.) must be verified against libdivecomputer's headers. Check `third_party/libdivecomputer/include/libdivecomputer/descriptor.h` for the actual function signatures and transport type constants.

**Step 2: Wire into HostApi**

Update `DiveComputerHostApiImpl.swift`:

```swift
func getDeviceDescriptors(completion: @escaping (Result<[DeviceDescriptor], any Error>) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let descriptors = LibdcWrapper.getDeviceDescriptors()
        completion(.success(descriptors))
    }
}
```

**Step 3: Test by calling from Dart**

Write a quick integration test or run the app and call `getDeviceDescriptors()`. Verify it returns 300+ entries.

**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/
git commit -m "feat: implement device descriptor enumeration on macOS"
```

---

### Task 8: Implement Discovery and Download on macOS

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/DiveComputerHostApiImpl.swift`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/LibdcWrapper.swift`
- Create: `packages/libdivecomputer_plugin/macos/Classes/DiveParser.swift`

This is the largest single task. The macOS implementation uses libdivecomputer's native BLE and USB backends.

**Step 1: Implement discovery in LibdcWrapper**

Add to `LibdcWrapper.swift`:

```swift
/// Start BLE discovery using libdivecomputer's native backend.
///
/// Calls dc_bluetooth_enumerate() on a background thread.
/// Discovered devices are reported via the callback.
static func startBleDiscovery(
    callback: @escaping (DiscoveredDevice) -> Void,
    completion: @escaping () -> Void
) {
    DispatchQueue.global(qos: .userInitiated).async {
        // Implementation uses dc_bluetooth_enumerate()
        // Each discovered device calls the callback
        // When enumeration completes, call completion()

        // Note: Exact API depends on libdivecomputer version.
        // Check dc_bluetooth_enumerate() signature in bluetooth.h
        completion()
    }
}
```

**Step 2: Implement download lifecycle in LibdcWrapper**

Add to `LibdcWrapper.swift`:

```swift
/// Download dives from a connected device.
///
/// This runs on a background thread and blocks until complete.
/// Progress and dive data are reported via callbacks.
static func downloadDives(
    vendor: String,
    product: String,
    model: Int,
    address: String,
    transport: TransportType,
    onProgress: @escaping (DownloadProgress) -> Void,
    onDive: @escaping (ParsedDive) -> Void,
    onComplete: @escaping (Int) -> Void,
    onError: @escaping (DiveComputerError) -> Void
) {
    DispatchQueue.global(qos: .userInitiated).async {
        var context: OpaquePointer? = nil
        var status = dc_context_new(&context)
        guard status == DC_STATUS_SUCCESS, let ctx = context else {
            onError(DiveComputerError(code: "context", message: "Failed to create context"))
            return
        }
        defer { dc_context_free(ctx) }

        // 1. Find matching descriptor
        // dc_descriptor_iterator -> match vendor/product/model
        // 2. Open device connection
        // dc_device_open(&device, ctx, descriptor, iostream)
        // 3. Set callbacks
        // dc_device_set_events(device, DC_EVENT_PROGRESS, eventCallback, userData)
        // 4. Download
        // dc_device_foreach(device, diveCallback, userData)
        //   - diveCallback: dc_parser_new -> extract fields -> onDive()
        // 5. Cleanup
        // dc_device_close(device)
    }
}
```

**Step 3: Implement DiveParser.swift**

Create `packages/libdivecomputer_plugin/macos/Classes/DiveParser.swift`:

```swift
import Foundation

/// Parses raw dive data from libdivecomputer into ParsedDive Pigeon objects.
class DiveParserSwift {

    /// Parse a single dive's binary data using libdivecomputer's parser.
    ///
    /// - Parameters:
    ///   - descriptor: The device descriptor for parser creation
    ///   - data: Raw dive binary data
    ///   - size: Size of the data
    /// - Returns: ParsedDive if parsing succeeds, nil otherwise
    static func parseDive(
        descriptor: OpaquePointer,
        data: UnsafePointer<UInt8>,
        size: Int
    ) -> ParsedDive? {
        var parser: OpaquePointer? = nil
        let status = dc_parser_new(&parser, descriptor)
        guard status == DC_STATUS_SUCCESS, let p = parser else { return nil }
        defer { dc_parser_destroy(p) }

        dc_parser_set_data(p, data, size)

        // Extract summary fields via dc_parser_get_field()
        // - DC_FIELD_DATETIME -> dateTimeEpoch
        // - DC_FIELD_MAXDEPTH -> maxDepthMeters
        // - DC_FIELD_AVGDEPTH -> avgDepthMeters
        // - DC_FIELD_DIVETIME -> durationSeconds
        // - DC_FIELD_TEMPERATURE_MINIMUM -> minTemperatureCelsius
        // - DC_FIELD_TEMPERATURE_MAXIMUM -> maxTemperatureCelsius
        // - DC_FIELD_DIVEMODE -> diveMode
        // - DC_FIELD_GASMIX_COUNT + DC_FIELD_GASMIX -> gasMixes
        // - DC_FIELD_TANK_COUNT + DC_FIELD_TANK -> tanks

        // Extract profile via dc_parser_samples_foreach()
        // Each sample callback receives time, depth, temperature, pressure, etc.

        // Build and return ParsedDive
        return nil // Placeholder
    }
}
```

Note: The actual implementation requires careful C interop. The field extraction pattern is:
```swift
var maxDepth: Double = 0
dc_parser_get_field(parser, DC_FIELD_MAXDEPTH, 0, &maxDepth)
```

Consult `third_party/libdivecomputer/include/libdivecomputer/parser.h` for exact field IDs and callback signatures.

**Step 4: Wire discovery and download into HostApi**

Update `DiveComputerHostApiImpl.swift` to call `LibdcWrapper.startBleDiscovery()` and `LibdcWrapper.downloadDives()`, forwarding results through `flutterApi` callbacks.

**Step 5: Build and test on macOS**

```bash
flutter build macos --debug
flutter run -d macos
```

Test with a physical dive computer if available, or verify the code compiles and the stub paths work.

**Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/
git commit -m "feat: implement discovery and download on macOS"
```

---

## Phase 4: iOS Native Implementation

### Task 9: iOS Build Configuration and BLE Transport

**Files:**
- Create: `packages/libdivecomputer_plugin/ios/libdivecomputer_plugin.podspec`
- Create: `packages/libdivecomputer_plugin/ios/Classes/LibdivecomputerPlugin.swift`
- Create: `packages/libdivecomputer_plugin/ios/Classes/DiveComputerHostApiImpl.swift`
- Create: `packages/libdivecomputer_plugin/ios/Classes/BleTransport.swift`
- Create: `packages/libdivecomputer_plugin/ios/Classes/LibdcBridge.h`
- Symlink or copy: `LibdcWrapper.swift`, `DiveParser.swift` from macOS

**Step 1: Create iOS podspec**

Similar to macOS but targeting iOS 15.0+, cross-compiling for arm64.

**Step 2: Create BleTransport implementing custom dc_iostream_t**

Create `packages/libdivecomputer_plugin/ios/Classes/BleTransport.swift`:

This is the key iOS-specific file. It implements a custom `dc_iostream_t` that bridges CoreBluetooth's async callbacks to libdivecomputer's synchronous read/write calls using `DispatchSemaphore`.

Key structure:
```swift
class BleTransport: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let centralManager: CBCentralManager
    private var peripheral: CBPeripheral?
    private let readSemaphore = DispatchSemaphore(value: 0)
    private let writeSemaphore = DispatchSemaphore(value: 0)
    private var readBuffer = Data()
    private var timeout: TimeInterval = 10.0

    // dc_iostream_t callbacks
    func read(count: Int) -> Data? {
        while readBuffer.count < count {
            let result = readSemaphore.wait(timeout: .now() + timeout)
            if result == .timedOut { return nil }
        }
        let data = readBuffer.prefix(count)
        readBuffer.removeFirst(count)
        return Data(data)
    }

    func write(data: Data) -> Bool {
        guard let peripheral = peripheral, let characteristic = writeCharacteristic else {
            return false
        }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        return writeSemaphore.wait(timeout: .now() + timeout) == .success
    }

    // CBPeripheralDelegate
    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        if let value = c.value {
            readBuffer.append(value)
            readSemaphore.signal()
        }
    }

    func peripheral(_ p: CBPeripheral, didWriteValueFor c: CBCharacteristic, error: Error?) {
        writeSemaphore.signal()
    }
}
```

Note: The custom `dc_iostream_t` must be registered with C function pointers. This requires bridging Swift closures to C callbacks, typically via a thin C or Objective-C wrapper. Check libdivecomputer's `iostream.h` for the `dc_custom_io_t` structure.

**Step 3: Share common Swift code with macOS**

Symlink `LibdcWrapper.swift` and `DiveParser.swift` from macOS:

```bash
cd packages/libdivecomputer_plugin/ios/Classes
ln -s ../../macos/Classes/LibdcWrapper.swift LibdcWrapper.swift
ln -s ../../macos/Classes/DiveParser.swift DiveParser.swift
ln -s ../../macos/Classes/LibdcBridge.h LibdcBridge.h
```

Or, if symlinks cause issues with CocoaPods, copy the files and note they must stay in sync.

**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/ios/
git commit -m "feat: iOS plugin with CoreBluetooth BLE transport"
```

---

## Phase 5: Android Native Implementation

### Task 10: Android Build Configuration and JNI Wrapper

**Files:**
- Create: `packages/libdivecomputer_plugin/android/build.gradle`
- Create: `packages/libdivecomputer_plugin/android/CMakeLists.txt`
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/.../LibdivecomputerPlugin.kt`
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/.../DiveComputerHostApiImpl.kt`
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/.../BleTransport.kt`
- Create: `packages/libdivecomputer_plugin/android/src/main/kotlin/.../UsbTransport.kt`
- Create: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`

**Step 1: Create build.gradle with NDK CMake integration**

The `build.gradle` must configure the NDK to build libdivecomputer from source via CMake, and link the resulting `.so` into the Kotlin plugin.

**Step 2: Create CMakeLists.txt for NDK build**

```cmake
cmake_minimum_required(VERSION 3.18)
project(libdivecomputer_plugin)

# Build libdivecomputer
add_subdirectory(../third_party/libdivecomputer libdivecomputer)

# JNI wrapper
add_library(libdc_jni SHARED src/main/cpp/libdc_jni.cpp)
target_link_libraries(libdc_jni divecomputer)
target_include_directories(libdc_jni PRIVATE ../third_party/libdivecomputer/include)
```

Note: libdivecomputer uses autotools, not CMake natively. You may need to write a custom `CMakeLists.txt` that builds libdivecomputer's source files directly, or use a script phase to run autotools first.

**Step 3: Create JNI wrapper**

Create `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`:

The JNI wrapper exposes libdivecomputer C functions to Kotlin. Key functions:
- `Java_com_submersion_libdivecomputer_LibdcWrapper_getVersion()`
- `Java_com_submersion_libdivecomputer_LibdcWrapper_getDescriptors()`
- `Java_com_submersion_libdivecomputer_LibdcWrapper_startDownload()`

**Step 4: Create BleTransport.kt**

Similar to iOS's BleTransport but using Android BLE APIs:
- `BluetoothLeScanner.startScan()` for discovery
- `BluetoothGatt` + `BluetoothGattCallback` for data transfer
- `CountDownLatch` or `Semaphore` for synchronization

**Step 5: Create UsbTransport.kt**

For Android USB support:
- `UsbManager.openDevice()` → get file descriptor
- Pass file descriptor to libdivecomputer via `dc_usb_open()` with custom I/O

**Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/android/
git commit -m "feat: Android plugin with BLE and USB transports"
```

---

## Phase 6: Desktop Linux and Windows

### Task 11: Linux Native Implementation

**Files:**
- Create: `packages/libdivecomputer_plugin/linux/libdivecomputer_plugin.cc`
- Modify: `packages/libdivecomputer_plugin/linux/CMakeLists.txt`

**Step 1: Write CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.18)
set(PROJECT_NAME "libdivecomputer_plugin")
project(${PROJECT_NAME} LANGUAGES CXX C)

# Build libdivecomputer
# (Add libdivecomputer source files or use find_library for system install)

# Plugin shared library
add_library(${PROJECT_NAME} SHARED
  libdivecomputer_plugin.cc
  dive_computer_host_api_impl.cc
  dive_computer_api.g.cc
)

target_link_libraries(${PROJECT_NAME} PRIVATE flutter divecomputer usb-1.0 bluetooth)
target_include_directories(${PROJECT_NAME} PRIVATE
  "${CMAKE_SOURCE_DIR}/../third_party/libdivecomputer/include"
)
```

**Step 2: Implement C++ HostApi**

Create `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc` implementing the Pigeon-generated C++ interface. Uses libdivecomputer's native BlueZ and libusb backends directly.

**Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/linux/
git commit -m "feat: Linux plugin with BlueZ BLE and libusb backends"
```

---

### Task 12: Windows Native Implementation

**Files:**
- Create: `packages/libdivecomputer_plugin/windows/libdivecomputer_plugin.cpp`
- Modify: `packages/libdivecomputer_plugin/windows/CMakeLists.txt`

Similar to Linux but linking WinUSB and WinRT BLE APIs instead of libusb/BlueZ.

**Step 1: Write CMakeLists.txt**

**Step 2: Implement C++ HostApi**

**Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/windows/
git commit -m "feat: Windows plugin with WinRT BLE and WinUSB backends"
```

---

## Phase 7: Dart-Side Integration

### Task 13: Update DeviceModel Entity

**Files:**
- Modify: `lib/features/dive_computer/domain/entities/device_model.dart`

**Step 1: Write test for new DeviceModel creation from DeviceDescriptor**

Create or update test file to verify `DeviceModel.fromDescriptor()`:

```dart
test('creates DeviceModel from Pigeon DeviceDescriptor', () {
  final descriptor = DeviceDescriptor(
    vendor: 'Shearwater',
    product: 'Perdix',
    model: 1,
    transports: [TransportType.ble, TransportType.usb],
  );

  final model = DeviceModel.fromDescriptor(descriptor);

  expect(model.manufacturer, 'Shearwater');
  expect(model.model, 'Perdix');
  expect(model.supportsBle, isTrue);
  expect(model.supportsUsb, isTrue);
});
```

**Step 2: Update DeviceModel**

Add a factory constructor:

```dart
factory DeviceModel.fromDescriptor(DeviceDescriptor descriptor) {
  return DeviceModel(
    id: '${descriptor.vendor}_${descriptor.product}_${descriptor.model}',
    manufacturer: descriptor.vendor,
    model: descriptor.product,
    connectionTypes: descriptor.transports.map((t) {
      switch (t) {
        case TransportType.ble: return DeviceConnectionType.ble;
        case TransportType.usb: return DeviceConnectionType.usb;
        case TransportType.serial: return DeviceConnectionType.usb; // Map serial to USB
        case TransportType.infrared: return DeviceConnectionType.infrared;
      }
    }).toList(),
    dcModel: descriptor.model,
  );
}
```

Similarly, update `DiscoveredDevice` to be constructable from the Pigeon type.

**Step 3: Run tests**

```bash
flutter test test/features/dive_computer/
```

**Step 4: Commit**

```bash
git add lib/features/dive_computer/domain/entities/device_model.dart
git add test/features/dive_computer/
git commit -m "feat: add DeviceModel.fromDescriptor() factory"
```

---

### Task 14: Rewrite Discovery Providers

**Files:**
- Modify: `lib/features/dive_computer/presentation/providers/discovery_providers.dart`

**Step 1: Rewrite providers to use DiveComputerService**

Replace `BluetoothConnectionManager` and `DeviceLibrary` providers with `DiveComputerService`-based providers:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';

/// Provider for the DiveComputerService singleton.
final diveComputerServiceProvider = Provider<DiveComputerService>((ref) {
  final service = DiveComputerService();
  // Register as FlutterApi callback handler
  DiveComputerFlutterApi.setUp(service);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for all known device descriptors from libdivecomputer.
final deviceDescriptorsProvider =
    FutureProvider<List<DeviceDescriptor>>((ref) async {
  final service = ref.watch(diveComputerServiceProvider);
  return service.getDeviceDescriptors();
});

/// Stream provider for discovered devices during scanning.
final discoveredDevicesProvider = StreamProvider<DiscoveredDevice>((ref) {
  final service = ref.watch(diveComputerServiceProvider);
  return service.discoveredDevices;
});

/// Provider for the libdivecomputer version string.
final libdcVersionProvider = Provider<String>((ref) {
  final service = ref.watch(diveComputerServiceProvider);
  return service.getVersion();
});

// Keep: DiscoveryState, DiscoveryNotifier (rewrite internals to use service)
// Keep: DiscoveryStep enum
// Delete: deviceLibraryProvider, permissionsServiceProvider,
//         bluetoothConnectionManagerProvider, connectionStateProvider,
//         usbDeviceScannerProvider, usbDeviceModelsProvider,
//         usbDevicesByManufacturerProvider, bluetoothAvailabilityProvider,
//         hasPermissionsProvider, deviceManufacturersProvider,
//         devicesByManufacturerProvider
```

Rewrite `DiscoveryNotifier` to use `DiveComputerService.startDiscovery()` and `stopDiscovery()` instead of `BluetoothConnectionManager`.

**Step 2: Run tests and fix compilation**

```bash
flutter analyze
flutter test
```

Fix any compilation errors from removed providers referenced elsewhere.

**Step 3: Commit**

```bash
git add lib/features/dive_computer/presentation/providers/discovery_providers.dart
git commit -m "refactor: rewrite discovery providers to use DiveComputerService"
```

---

### Task 15: Rewrite Download Providers

**Files:**
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart`

**Step 1: Rewrite providers**

Replace `DownloadManager`-based providers with `DiveComputerService`-based ones:

```dart
/// Provider for download events stream.
final downloadEventsProvider = StreamProvider<DownloadEvent>((ref) {
  final service = ref.watch(diveComputerServiceProvider);
  return service.downloadEvents;
});
```

Rewrite `DownloadNotifier` to:
1. Call `service.startDownload(device)` instead of `downloadManager.downloadDives()`
2. Listen to `service.downloadEvents` stream for progress/dives/completion
3. Map `ParsedDive` to `DownloadedDive` (or update import service to accept `ParsedDive` directly)

Keep `DiveImportService` integration, `DiveComputerRepository` usage, PIN entry dialog, import mode handling.

**Step 2: Run tests**

```bash
flutter test
```

**Step 3: Commit**

```bash
git add lib/features/dive_computer/presentation/providers/download_providers.dart
git commit -m "refactor: rewrite download providers to use DiveComputerService"
```

---

### Task 16: Update DiveImportService and Repository Mapping

**Files:**
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`

**Step 1: Add ParsedDive -> DownloadedDive mapping**

Either:
A. Update `DiveImportService` to accept `ParsedDive` directly (cleaner), or
B. Add a mapper from `ParsedDive` to `DownloadedDive` (less disruptive)

Option B (less disruptive):

```dart
/// Convert a Pigeon ParsedDive to the app's DownloadedDive format.
DownloadedDive parsedDiveToDownloaded(ParsedDive parsed) {
  return DownloadedDive(
    startTime: DateTime.fromMillisecondsSinceEpoch(parsed.dateTimeEpoch * 1000),
    durationSeconds: parsed.durationSeconds,
    maxDepth: parsed.maxDepthMeters,
    avgDepth: parsed.avgDepthMeters,
    minTemperature: parsed.minTemperatureCelsius,
    maxTemperature: parsed.maxTemperatureCelsius,
    fingerprint: parsed.fingerprint,
    profile: parsed.samples.map((s) => ProfileSample(
      timeSeconds: s.timeSeconds,
      depth: s.depthMeters,
      temperature: s.temperatureCelsius,
      pressure: s.pressureBar,
      tankIndex: s.tankIndex,
      heartRate: s.heartRate?.toInt(),
    )).toList(),
    tanks: parsed.tanks.map((t) {
      final gasMix = parsed.gasMixes.firstWhere(
        (g) => g.index == t.gasMixIndex,
        orElse: () => GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
      );
      return DownloadedTank(
        index: t.index,
        o2Percent: gasMix.o2Percent,
        hePercent: gasMix.hePercent,
        startPressure: t.startPressureBar,
        endPressure: t.endPressureBar,
        volumeLiters: t.volumeLiters,
      );
    }).toList(),
  );
}
```

**Step 2: Write tests for the mapping**

```dart
test('converts ParsedDive to DownloadedDive correctly', () {
  final parsed = ParsedDive(
    fingerprint: 'abc123',
    dateTimeEpoch: 1700000000,
    maxDepthMeters: 30.0,
    avgDepthMeters: 15.5,
    durationSeconds: 3600,
    minTemperatureCelsius: 18.0,
    maxTemperatureCelsius: 22.0,
    samples: [
      ProfileSample(timeSeconds: 0, depthMeters: 0.0),
      ProfileSample(timeSeconds: 60, depthMeters: 10.0, temperatureCelsius: 20.0),
    ],
    tanks: [
      TankInfo(index: 0, gasMixIndex: 0, startPressureBar: 200.0, endPressureBar: 50.0),
    ],
    gasMixes: [
      GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
    ],
    events: [],
  );

  final downloaded = parsedDiveToDownloaded(parsed);

  expect(downloaded.maxDepth, 30.0);
  expect(downloaded.durationSeconds, 3600);
  expect(downloaded.profile, hasLength(2));
  expect(downloaded.tanks.first.o2Percent, 32.0);
  expect(downloaded.fingerprint, 'abc123');
});
```

**Step 3: Run tests**

```bash
flutter test
```

**Step 4: Commit**

```bash
git add lib/features/dive_computer/data/services/
git add test/
git commit -m "feat: add ParsedDive to DownloadedDive mapping"
```

---

### Task 17: Update UI Pages

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_discovery_page.dart`
- Modify: `lib/features/dive_computer/presentation/pages/device_download_page.dart`
- Modify: `lib/features/dive_computer/presentation/widgets/scan_step_widget.dart`
- Modify: `lib/features/dive_computer/presentation/widgets/download_step_widget.dart`

**Step 1: Update imports and provider references**

Replace references to old providers (`bluetoothConnectionManagerProvider`, `deviceLibraryProvider`, etc.) with new ones (`diveComputerServiceProvider`, `deviceDescriptorsProvider`, `discoveredDevicesProvider`).

The UI layout stays the same -- only the data source changes.

**Step 2: Update scan step to use new discovery stream**

The `scan_step_widget.dart` needs to:
- Watch `discoveredDevicesProvider` (now a `StreamProvider<DiscoveredDevice>` instead of `StreamProvider<List<DiscoveredDevice>>`)
- Accumulate discovered devices in a local list or use a `StateNotifier`

**Step 3: Update download step to use new download events**

The `download_step_widget.dart` needs to:
- Watch `downloadEventsProvider` for progress and dive events
- Map `DownloadProgressEvent` to existing progress UI
- Accumulate `DiveDownloadedEvent` for the dive count display

**Step 4: Verify the app compiles and runs**

```bash
flutter analyze
flutter run -d macos
```

**Step 5: Commit**

```bash
git add lib/features/dive_computer/presentation/
git commit -m "refactor: update UI pages to use new plugin providers"
```

---

## Phase 8: Cleanup

### Task 18: Delete Old Code and Dependencies

**Files to delete:**
- `lib/features/dive_computer/data/services/shearwater_ble_protocol.dart`
- `lib/features/dive_computer/data/services/suunto_ble_protocol.dart`
- `lib/features/dive_computer/data/services/aqualung_ble_protocol.dart`
- `lib/features/dive_computer/data/services/mares_ble_protocol.dart`
- `lib/features/dive_computer/data/services/bluetooth_connection_manager.dart`
- `lib/features/dive_computer/data/services/libdc_ffi_download_manager.dart`
- `lib/features/dive_computer/data/services/libdc_download_manager.dart`
- `lib/features/dive_computer/data/services/libdc_parser_service.dart`
- `lib/features/dive_computer/data/services/dive_parser.dart`
- `lib/features/dive_computer/data/services/permissions_service.dart`
- `lib/features/dive_computer/data/services/usb_device_scanner.dart`
- `lib/features/dive_computer/data/device_library.dart`
- `lib/features/dive_computer/domain/services/connection_manager.dart`
- `lib/features/dive_computer/domain/services/download_manager.dart`
- `third_party/flutter_blue_plus_winrt/` (entire directory)

**Step 1: Delete the files**

```bash
rm lib/features/dive_computer/data/services/shearwater_ble_protocol.dart
rm lib/features/dive_computer/data/services/suunto_ble_protocol.dart
rm lib/features/dive_computer/data/services/aqualung_ble_protocol.dart
rm lib/features/dive_computer/data/services/mares_ble_protocol.dart
rm lib/features/dive_computer/data/services/bluetooth_connection_manager.dart
rm lib/features/dive_computer/data/services/libdc_ffi_download_manager.dart
rm lib/features/dive_computer/data/services/libdc_download_manager.dart
rm lib/features/dive_computer/data/services/libdc_parser_service.dart
rm lib/features/dive_computer/data/services/dive_parser.dart
rm lib/features/dive_computer/data/services/permissions_service.dart
rm lib/features/dive_computer/data/services/usb_device_scanner.dart
rm lib/features/dive_computer/data/device_library.dart
rm lib/features/dive_computer/domain/services/connection_manager.dart
rm lib/features/dive_computer/domain/services/download_manager.dart
rm -rf third_party/flutter_blue_plus_winrt/
```

**Step 2: Remove dependencies from pubspec.yaml**

Remove these lines from `pubspec.yaml`:

```yaml
# Remove from dependencies:
  flutter_blue_plus: ^2.1.0
  flutter_blue_plus_winrt: 0.0.10
  dive_computer: ^0.1.0-dev.2

# Remove from dependency_overrides:
  flutter_blue_plus_winrt:
    path: third_party/flutter_blue_plus_winrt
```

**Step 3: Remove ffi dependency if no longer used elsewhere**

Check if `ffi: ^2.1.0` is used anywhere else. If only by `dive_computer`, remove it too.

```bash
grep -r "import.*ffi" lib/ --include="*.dart" | grep -v dive_computer
```

If no results, remove `ffi: ^2.1.0` from pubspec.yaml.

**Step 4: Run pub get and fix any remaining import errors**

```bash
flutter pub get
flutter analyze
```

Fix any files that still import deleted modules.

**Step 5: Delete tests for removed code**

Remove test files that tested the deleted BLE protocols, connection manager, etc.

```bash
find test/ -name "*shearwater*" -o -name "*suunto*" -o -name "*aqualung*" -o -name "*mares*" -o -name "*bluetooth_connection*" -o -name "*device_library*" -o -name "*libdc_download*" -o -name "*libdc_ffi*" -o -name "*usb_device_scanner*" | xargs rm -f
```

**Step 6: Run full test suite**

```bash
flutter test
```

Fix any failures.

**Step 7: Run dart format**

```bash
dart format lib/ test/
```

**Step 8: Commit**

```bash
git add -A
git commit -m "refactor: delete old BLE protocols, connection manager, and flutter_blue_plus dependency"
```

---

## Phase 9: Final Verification

### Task 19: Full Build and Test Verification

**Step 1: Clean rebuild**

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

**Step 2: Analyze**

```bash
flutter analyze
```

Expected: No errors, no warnings.

**Step 3: Format check**

```bash
dart format --set-exit-if-changed lib/ test/
```

Expected: No formatting changes needed.

**Step 4: Run all tests**

```bash
flutter test
```

Expected: All tests pass.

**Step 5: Build for each platform**

```bash
flutter build macos --debug
flutter build ios --debug --no-codesign  # if on macOS
flutter build apk --debug               # Android
flutter build linux --debug              # if on Linux
flutter build windows --debug            # if on Windows
```

Expected: All targeted platform builds succeed.

**Step 6: Manual smoke test**

Run the app on macOS, navigate to Transfer > Dive Computers, verify:
- The device list page loads (pulls descriptors from libdivecomputer)
- BLE scanning starts and shows a scanning indicator
- The app doesn't crash

**Step 7: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup and verification"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-3 | Plugin scaffold, Pigeon API, Dart service + tests |
| 2 | 4-6 | libdivecomputer submodule, macOS build, dc_version() |
| 3 | 7-8 | macOS native implementation (descriptors, discovery, download) |
| 4 | 9 | iOS implementation (BleTransport + shared Swift code) |
| 5 | 10 | Android implementation (JNI + BLE + USB transports) |
| 6 | 11-12 | Linux and Windows C++ implementations |
| 7 | 13-17 | Dart-side integration (entities, providers, import, UI) |
| 8 | 18 | Delete old code and dependencies |
| 9 | 19 | Full build and test verification |

**Key risk areas:**
- Building libdivecomputer from source on each platform (autotools vs CMake)
- C interop from Swift/Kotlin (bridging headers, JNI)
- Custom dc_iostream_t on iOS/Android (semaphore-based BLE bridge)
- Pigeon code generation for C++ (less mature than Swift/Kotlin)
