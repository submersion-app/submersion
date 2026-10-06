# Platform Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Achieve full dive computer feature parity (14 sample fields, 25 event types, deco model/GF, BLE + serial/USB transport) across macOS, iOS, Android, Windows, and Linux.

**Architecture:** The shared C layer (`libdc_wrapper.c` / `libdc_download.c` in `macos/Classes/`) already parses all data. Each platform needs its mapping layer updated to expose all fields, plus transport implementations for BLE and serial/USB where missing. iOS/macOS share code via a Swift package. Android extends JNI. Windows uses WinRT/Win32. Linux uses BlueZ D-Bus/POSIX.

**Tech Stack:** Swift (iOS/macOS), Kotlin + JNI/C++ (Android), C++/WinRT (Windows), C/GLib + BlueZ D-Bus (Linux), Pigeon code generation, CMake, CocoaPods

**Design Doc:** `docs/plans/2026-02-24-platform-parity-design.md`

**Plugin Root:** `packages/libdivecomputer_plugin/`

---

## Parallel Streams

This plan has 5 independent streams that can run in parallel:

| Stream | Scope | Testable On |
|--------|-------|-------------|
| A | Shared Swift Package + iOS/macOS serial | macOS (local) |
| B | Android JNI + Kotlin mapping | macOS (emulator/CI) |
| C | Windows BLE + serial + mapping | Windows CI |
| D | Linux BLE + serial + mapping | Linux CI |
| E | Testing infrastructure + CI | All runners |

Streams A-D have zero file overlap and can be dispatched to separate agents.

---

## Stream A: Shared Swift Package + iOS Parity

### Task A1: Create the shared Swift package structure

**Files:**

- Create: `darwin/Package.swift`
- Create: `darwin/Sources/LibDCDarwin/.gitkeep` (placeholder until files move)

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LibDCDarwin",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(name: "LibDCDarwin", targets: ["LibDCDarwin"]),
    ],
    targets: [
        .target(
            name: "LibDCDarwin",
            path: "Sources/LibDCDarwin",
            publicHeadersPath: nil,
            cSettings: [
                .headerSearchPath("../../macos/Classes"),
                .headerSearchPath("../../third_party/libdivecomputer/include"),
            ],
            swiftSettings: [
                .unsafeFlags(["-import-objc-header", "../../macos/Classes/libdc_wrapper.h"])
            ]
        ),
    ]
)
```typescript
Note: The exact Swift package setup for bridging C headers may require a `module.modulemap` or an umbrella header depending on how the podspec integrates it. The implementor should verify the C header import path works by building. An alternative is to keep the C header import in the podspec's `SWIFT_INCLUDE_PATHS` and use a bridging header, which is the current pattern.

**Step 2: Verify directory structure**

```bash
ls packages/libdivecomputer_plugin/darwin/
ls packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/
```text
**Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/
git commit -m "feat(plugin): scaffold shared Swift package for iOS/macOS"
```diff
---

### Task A2: Move shared Swift files into the darwin package

**Files:**

- Move: `macos/Classes/DiveComputerHostApiImpl.swift` -> `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`
- Move: `macos/Classes/BleScanner.swift` -> `darwin/Sources/LibDCDarwin/BleScanner.swift`
- Move: `macos/Classes/BleIoStream.swift` -> `darwin/Sources/LibDCDarwin/BleIoStream.swift`
- Delete: `ios/Classes/DiveComputerHostApiImpl.swift`
- Delete: `ios/Classes/BleScanner.swift`
- Delete: `ios/Classes/BleIoStream.swift`

**Step 1: Move files**

```bash
cd packages/libdivecomputer_plugin
mkdir -p darwin/Sources/LibDCDarwin
# Move the macOS versions (they have full mapping)
mv macos/Classes/DiveComputerHostApiImpl.swift darwin/Sources/LibDCDarwin/
mv macos/Classes/BleScanner.swift darwin/Sources/LibDCDarwin/
mv macos/Classes/BleIoStream.swift darwin/Sources/LibDCDarwin/
# Remove the incomplete iOS copies
rm ios/Classes/DiveComputerHostApiImpl.swift
rm ios/Classes/BleScanner.swift
rm ios/Classes/BleIoStream.swift
```typescript
**Step 2: Add conditional import to DiveComputerHostApiImpl.swift**

Replace the first line:

```swift
// OLD:
import FlutterMacOS

// NEW:
#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#endif
```typescript
Similarly update `BleScanner.swift` and `BleIoStream.swift` if they import FlutterMacOS.

**Step 3: Update the error message string**

In `DiveComputerHostApiImpl.swift`, the error message says "macOS". Change it to be platform-aware:

```swift
// OLD:
message: "Transport \(transport) not yet supported on macOS"

// NEW:
#if os(iOS)
message: "Transport \(transport) not yet supported on iOS"
#elseif os(macOS)
message: "Transport \(transport) not yet supported on macOS"
#endif
```text
**Step 4: Create thin entry points**

Create `macos/Classes/LibdivecomputerPlugin.swift` if it doesn't already exist (it likely does as the plugin registration file). Ensure it references the shared code. The key is that `DiveComputerHostApiImpl` is now in the darwin package.

Create `ios/Classes/LibdivecomputerPlugin.swift` similarly.

**Step 5: Update podspecs**

Both `libdivecomputer_plugin.podspec` (macOS) and the iOS podspec need to include the `darwin/Sources/LibDCDarwin/*.swift` files in their source_files.

Example podspec change:

```ruby
s.source_files = 'macos/Classes/**/*.{swift,c,h}',
                 'darwin/Sources/LibDCDarwin/**/*.swift'
```text
And for iOS:

```ruby
s.source_files = 'ios/Classes/**/*.{swift,c,h}',
                 'darwin/Sources/LibDCDarwin/**/*.swift'
```text
**Step 6: Build and verify on macOS**

```bash
cd ../..  # back to project root
flutter build macos --debug 2>&1 | tail -20
```text
Expected: Builds successfully.

**Step 7: Build and verify on iOS simulator**

```bash
flutter build ios --simulator --debug 2>&1 | tail -20
```text
Expected: Builds successfully. iOS now has full 14-field sample mapping, 25 event types, and deco model/GF.

**Step 8: Commit**

```bash
git add -A packages/libdivecomputer_plugin/darwin/ \
        packages/libdivecomputer_plugin/macos/ \
        packages/libdivecomputer_plugin/ios/
git commit -m "feat(plugin): extract shared Swift package, iOS gains full parity"
```diff
---

### Task A3: Add serial/USB transport to macOS/iOS via shared Swift package

**Files:**

- Create: `darwin/Sources/LibDCDarwin/SerialScanner.swift`
- Create: `darwin/Sources/LibDCDarwin/SerialIoStream.swift`
- Modify: `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`

**Step 1: Create SerialScanner.swift**

This uses IOKit to list serial ports and match against libdivecomputer descriptors.

```swift
import Foundation
import IOKit
import IOKit.serial

class SerialScanner {
    var onDeviceDiscovered: ((DiscoveredDevice) -> Void)?
    var onComplete: (() -> Void)?

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.enumerateSerialPorts()
            DispatchQueue.main.async {
                self?.onComplete?()
            }
        }
    }

    private func enumerateSerialPorts() {
        let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue)
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard kr == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let pathCF = IORegistryEntryCreateCFProperty(
                service,
                kIOCalloutDeviceKey as CFString,
                kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? String else { continue }

            // Extract device name from path for descriptor matching.
            let deviceName = (pathCF as NSString).lastPathComponent

            var info = libdc_descriptor_info_t()
            let matched = libdc_descriptor_match(
                deviceName,
                UInt32(LIBDC_TRANSPORT_SERIAL),
                &info
            )
            guard matched == 1 else { continue }

            let device = DiscoveredDevice(
                vendor: String(cString: info.vendor),
                product: String(cString: info.product),
                model: Int64(info.model),
                address: pathCF,
                name: deviceName,
                transport: .serial
            )

            DispatchQueue.main.async { [weak self] in
                self?.onDeviceDiscovered?(device)
            }
        }
    }
}
```text
Note: IOKit serial access on iOS is limited. Most iOS dive computer connections will be BLE. Serial support primarily benefits macOS (USB-serial adapters).

**Step 2: Create SerialIoStream.swift**

This wraps POSIX serial I/O and implements `libdc_io_callbacks_t`.

```swift
import Foundation

class SerialIoStream {
    private var fileDescriptor: Int32 = -1
    private var timeoutMs: Int32 = 10000

    func open(path: String, baudRate: speed_t = 9600) -> Bool {
        fileDescriptor = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fileDescriptor >= 0 else { return false }

        // Configure serial port.
        var options = termios()
        tcgetattr(fileDescriptor, &options)
        cfsetispeed(&options, baudRate)
        cfsetospeed(&options, baudRate)
        options.c_cflag |= UInt(CS8 | CLOCAL | CREAD)
        options.c_iflag = 0
        options.c_oflag = 0
        options.c_lflag = 0
        tcsetattr(fileDescriptor, TCSANOW, &options)

        // Switch back to blocking.
        let flags = fcntl(fileDescriptor, F_GETFL)
        _ = fcntl(fileDescriptor, F_SETFL, flags & ~O_NONBLOCK)

        return true
    }

    func close() {
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    // Returns libdc_io_callbacks_t filled with function pointers to this stream.
    func makeCallbacks() -> libdc_io_callbacks_t {
        var callbacks = libdc_io_callbacks_t()
        callbacks.userdata = Unmanaged.passUnretained(self).toOpaque()
        callbacks.set_timeout = { userdata, timeout in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            stream.timeoutMs = Int32(timeout)
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        callbacks.read = { userdata, data, size, actual in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.readData(data!, size: size, actual: actual!)
        }
        callbacks.write = { userdata, data, size, actual in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            return stream.writeData(data!, size: size, actual: actual!)
        }
        callbacks.close = { userdata in
            let stream = Unmanaged<SerialIoStream>.fromOpaque(userdata!).takeUnretainedValue()
            stream.close()
            return Int32(LIBDC_STATUS_SUCCESS)
        }
        return callbacks
    }

    private func readData(_ buffer: UnsafeMutableRawPointer, size: Int, actual: UnsafeMutablePointer<Int>) -> Int32 {
        // Use select() for timeout support.
        var readSet = fd_set()
        __darwin_fd_zero(&readSet)
        __darwin_fd_set(fileDescriptor, &readSet)
        var tv = timeval(tv_sec: Int(timeoutMs / 1000), tv_usec: Int32((timeoutMs % 1000) * 1000))

        let ready = select(fileDescriptor + 1, &readSet, nil, nil, &tv)
        if ready <= 0 {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_TIMEOUT)
        }

        let n = Darwin.read(fileDescriptor, buffer, size)
        if n < 0 {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }
        actual.pointee = n
        return Int32(LIBDC_STATUS_SUCCESS)
    }

    private func writeData(_ buffer: UnsafeRawPointer, size: Int, actual: UnsafeMutablePointer<Int>) -> Int32 {
        let n = Darwin.write(fileDescriptor, buffer, size)
        if n < 0 {
            actual.pointee = 0
            return Int32(LIBDC_STATUS_IO)
        }
        actual.pointee = n
        return Int32(LIBDC_STATUS_SUCCESS)
    }
}
```typescript
Note: The `libdc_io_callbacks_t` closure approach requires `@convention(c)` compatibility -- the closures above capture no context (they use `userdata` pointer instead), which is correct for C function pointers.

**Step 3: Wire serial transport into DiveComputerHostApiImpl.swift**

In `startDiscovery()`, add a case for `.serial`:

```swift
case .serial:
    let scanner = SerialScanner()
    scanner.onDeviceDiscovered = { [weak self] device in
        self?.flutterApi.onDeviceDiscovered(device: device) { _ in }
    }
    scanner.onComplete = { [weak self] in
        self?.flutterApi.onDiscoveryComplete { _ in }
    }
    scanner.start()
```text
In `startDownload()`, detect serial transport and use SerialIoStream instead of BleIoStream:

```swift
if device.transport == .serial {
    let serialStream = SerialIoStream()
    guard serialStream.open(path: device.address) else {
        flutterApi.onError(error: DiveComputerError(code: "connect_failed",
            message: "Failed to open serial port")) { _ in }
        return
    }
    var ioCallbacks = serialStream.makeCallbacks()
    // ... proceed with libdc_download_run using ioCallbacks
}
```text
**Step 4: Build and verify**

```bash
flutter build macos --debug 2>&1 | tail -20
```text
**Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/Serial*.swift
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift
git commit -m "feat(plugin): add serial/USB transport for macOS/iOS"
```diff
---

## Stream B: Android JNI + Kotlin Parity

### Task B1: Expand nativeGetDiveSample to return all 14 fields

**Files:**

- Modify: `android/src/main/cpp/libdc_jni.cpp:449-467`

**Step 1: Update the JNI function**

Replace the current `nativeGetDiveSample` implementation:

```cpp
extern "C" JNIEXPORT jdoubleArray JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveSample(
    JNIEnv *env, jclass, jlong divePtr, jint index) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    if (index < 0 || static_cast<unsigned int>(index) >= dive->sample_count) return nullptr;

    const libdc_sample_t *s = &dive->samples[index];
    // Return all 14 fields:
    // [time_ms, depth, temperature, pressure, tank,
    //  heartbeat, setpoint, ppo2, cns, rbt,
    //  deco_type, deco_time, deco_depth, deco_tts]
    // Integer sentinel UINT32_MAX is cast to double for uniform NaN-style checking.
    jdouble values[14] = {
        static_cast<jdouble>(s->time_ms),
        s->depth,
        s->temperature,
        s->pressure,
        static_cast<jdouble>(s->tank),
        static_cast<jdouble>(s->heartbeat),
        s->setpoint,
        s->ppo2,
        s->cns,
        static_cast<jdouble>(s->rbt),
        static_cast<jdouble>(s->deco_type),
        static_cast<jdouble>(s->deco_time),
        s->deco_depth,
        static_cast<jdouble>(s->deco_tts)
    };
    jdoubleArray result = env->NewDoubleArray(14);
    env->SetDoubleArrayRegion(result, 0, 14, values);
    return result;
}
```text
**Step 2: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp
git commit -m "feat(android): expand nativeGetDiveSample to all 14 fields"
```diff
---

### Task B2: Add JNI functions for events and deco model

**Files:**

- Modify: `android/src/main/cpp/libdc_jni.cpp` (append after line 514)

**Step 1: Add event accessors**

```cpp
// ============================================================
// Event Data Access
// ============================================================

extern "C" JNIEXPORT jint JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveEventCount(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return static_cast<jint>(dive->event_count);
}

extern "C" JNIEXPORT jlongArray JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveEvent(
    JNIEnv *env, jclass, jlong divePtr, jint index) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    if (!dive->events || index < 0 ||
        static_cast<unsigned int>(index) >= dive->event_count) return nullptr;

    const libdc_event_t *e = &dive->events[index];
    // Return [time_ms, type, flags, value]
    jlong values[4] = {
        static_cast<jlong>(e->time_ms),
        static_cast<jlong>(e->type),
        static_cast<jlong>(e->flags),
        static_cast<jlong>(e->value)
    };
    jlongArray result = env->NewLongArray(4);
    env->SetLongArrayRegion(result, 0, 4, values);
    return result;
}
```text
**Step 2: Add deco model accessor**

```cpp
// ============================================================
// Decompression Model Access
// ============================================================

extern "C" JNIEXPORT jintArray JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveDecoModel(
    JNIEnv *env, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    // Return [model_type, conservatism, gf_low, gf_high]
    jint values[4] = {
        static_cast<jint>(dive->deco_model_type),
        static_cast<jint>(dive->deco_conservatism),
        static_cast<jint>(dive->gf_low),
        static_cast<jint>(dive->gf_high)
    };
    jintArray result = env->NewIntArray(4);
    env->SetIntArrayRegion(result, 0, 4, values);
    return result;
}
```text
**Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp
git commit -m "feat(android): add JNI accessors for events and deco model"
```diff
---

### Task B3: Update Kotlin declarations and mapping

**Files:**

- Modify: `android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt`
- Modify: `android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`

**Step 1: Add new external declarations to LibdcWrapper.kt**

After line 59 (`nativeGetDiveTank`), add:

```kotlin
// Event data access
external fun nativeGetDiveEventCount(divePtr: Long): Int
external fun nativeGetDiveEvent(divePtr: Long, index: Int): LongArray?

// Decompression model access
external fun nativeGetDiveDecoModel(divePtr: Long): IntArray?
```text
**Step 2: Update convertParsedDive() in DiveComputerHostApiImpl.kt**

Replace the sample mapping (lines 221-231) with:

```kotlin
val sampleCount = LibdcWrapper.nativeGetDiveSampleCount(divePtr)
val samples = (0 until sampleCount).mapNotNull { i ->
    val s = LibdcWrapper.nativeGetDiveSample(divePtr, i) ?: return@mapNotNull null
    ProfileSample(
        timeSeconds = (s[0] / 1000.0).toLong(),
        depthMeters = s[1],
        temperatureCelsius = if (s[2].isNaN()) null else s[2],
        pressureBar = if (s[3].isNaN()) null else s[3],
        tankIndex = if (s[4].toLong() == 0xFFFFFFFFL) null else s[4].toLong(),
        heartRate = if (s[5].toLong() == 0xFFFFFFFFL) null else s[5].toLong(),
        setpoint = if (s[6].isNaN()) null else s[6],
        ppo2 = if (s[7].isNaN()) null else s[7],
        cns = if (s[8].isNaN()) null else s[8],
        rbt = if (s[9].toLong() == 0xFFFFFFFFL) null else s[9].toLong(),
        decoType = if (s[10].toLong() == 0xFFFFFFFFL) null else s[10].toLong(),
        decoTime = if (s[11].toLong() == 0xFFFFFFFFL) null else s[11].toLong(),
        decoDepth = if (s[12].isNaN()) null else s[12],
        tts = if (s[13].toLong() == 0xFFFFFFFFL || s[13].toLong() == 0L) null else s[13].toLong()
    )
}
```text
**Step 3: Add event parsing after tank conversion (before the return statement)**

```kotlin
// Convert events.
val eventCount = LibdcWrapper.nativeGetDiveEventCount(divePtr)
val events = (0 until eventCount).mapNotNull { i ->
    val e = LibdcWrapper.nativeGetDiveEvent(divePtr, i) ?: return@mapNotNull null
    if (e[1] == 0L) return@mapNotNull null  // skip EVENT_NONE
    DiveEvent(
        timeSeconds = e[0] / 1000,
        type = mapEventType(e[1].toInt()),
        data = mapOf("flags" to e[2].toString(), "value" to e[3].toString())
    )
}

// Convert deco model.
val decoInfo = LibdcWrapper.nativeGetDiveDecoModel(divePtr)
val decoAlgorithm = decoInfo?.let {
    when (it[0]) {
        1 -> "buhlmann"
        2 -> "vpm"
        3 -> "rgbm"
        4 -> "dciem"
        else -> null
    }
}
val gfLow = decoInfo?.let { if (it[2] == 0) null else it[2].toLong() }
val gfHigh = decoInfo?.let { if (it[3] == 0) null else it[3].toLong() }
val decoConservatism = decoInfo?.let { if (it[1] == 0) null else it[1].toLong() }
```text
**Step 4: Update the ParsedDive return to include new fields**

Replace lines 272-285:

```kotlin
return ParsedDive(
    fingerprint = fingerprint,
    dateTimeEpoch = epoch,
    maxDepthMeters = maxDepth,
    avgDepthMeters = avgDepth,
    durationSeconds = LibdcWrapper.nativeGetDiveDuration(divePtr).toLong(),
    minTemperatureCelsius = if (minTemp.isNaN()) null else minTemp,
    maxTemperatureCelsius = if (maxTemp.isNaN()) null else maxTemp,
    samples = samples,
    tanks = tanks,
    gasMixes = gasMixes,
    events = events,
    diveMode = diveMode,
    decoAlgorithm = decoAlgorithm,
    gfLow = gfLow,
    gfHigh = gfHigh,
    decoConservatism = decoConservatism
)
```typescript
**Step 5: Add mapEventType() function to DiveComputerHostApiImpl.kt**

Add as a companion object function or private method:

```kotlin
private fun mapEventType(type: Int): String = when (type) {
    0 -> "none"
    1 -> "deco"
    2 -> "ascent"
    3 -> "ceiling"
    4 -> "workload"
    5 -> "transmitter"
    6 -> "violation"
    7 -> "bookmark"
    8 -> "surface"
    9 -> "safetystop"
    10 -> "gaschange"
    11 -> "safetystop_voluntary"
    12 -> "safetystop_mandatory"
    13 -> "deepstop"
    14 -> "ceiling_safetystop"
    15 -> "floor"
    16 -> "divetime"
    17 -> "maxdepth"
    18 -> "OLF"
    19 -> "PO2"
    20 -> "airtime"
    21 -> "rgbm"
    22 -> "heading"
    23 -> "tissuelevel"
    24 -> "gaschange2"
    else -> "unknown_$type"
}
```text
**Step 6: Build and verify**

```bash
cd packages/libdivecomputer_plugin
flutter build apk --debug 2>&1 | tail -20
```text
**Step 7: Commit**

```bash
git add packages/libdivecomputer_plugin/android/
git commit -m "feat(android): full sample/event/deco parity with macOS"
```swift
---

## Stream C: Windows Full Implementation

### Task C1: Create the dive converter (C struct to Pigeon C++ mapping)

**Files:**

- Create: `windows/dive_converter.h`
- Create: `windows/dive_converter.cc`

**Step 1: Create dive_converter.h**

```cpp
#ifndef DIVE_CONVERTER_H_
#define DIVE_CONVERTER_H_

#include "dive_computer_api.g.h"

extern "C" {
#include "libdc_wrapper.h"
}

namespace libdivecomputer_plugin {

// Converts a parsed dive from the C wrapper into a Pigeon ParsedDive.
ParsedDive ConvertParsedDive(const libdc_parsed_dive_t& dive);

// Maps a libdivecomputer event type to a string name.
std::string MapEventType(unsigned int type);

}  // namespace libdivecomputer_plugin

#endif  // DIVE_CONVERTER_H_
```text
**Step 2: Create dive_converter.cc**

```cpp
#include "dive_converter.h"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <limits>
#include <string>
#include <vector>

namespace libdivecomputer_plugin {

std::string MapEventType(unsigned int type) {
    switch (type) {
        case 0: return "none";
        case 1: return "deco";
        case 2: return "ascent";
        case 3: return "ceiling";
        case 4: return "workload";
        case 5: return "transmitter";
        case 6: return "violation";
        case 7: return "bookmark";
        case 8: return "surface";
        case 9: return "safetystop";
        case 10: return "gaschange";
        case 11: return "safetystop_voluntary";
        case 12: return "safetystop_mandatory";
        case 13: return "deepstop";
        case 14: return "ceiling_safetystop";
        case 15: return "floor";
        case 16: return "divetime";
        case 17: return "maxdepth";
        case 18: return "OLF";
        case 19: return "PO2";
        case 20: return "airtime";
        case 21: return "rgbm";
        case 22: return "heading";
        case 23: return "tissuelevel";
        case 24: return "gaschange2";
        default: return "unknown_" + std::to_string(type);
    }
}

ParsedDive ConvertParsedDive(const libdc_parsed_dive_t& dive) {
    // Convert fingerprint to hex.
    char hex[LIBDC_MAX_FINGERPRINT * 2 + 1] = {0};
    for (unsigned int i = 0; i < dive.fingerprint_size; i++) {
        snprintf(hex + i * 2, 3, "%02x", dive.fingerprint[i]);
    }

    // Convert datetime to epoch.
    struct tm t = {};
    t.tm_year = dive.year - 1900;
    t.tm_mon = dive.month - 1;
    t.tm_mday = dive.day;
    t.tm_hour = dive.hour;
    t.tm_min = dive.minute;
    t.tm_sec = dive.second;
    t.tm_isdst = 0;
    // Use _mkgmtime on Windows for UTC.
    int64_t epoch = static_cast<int64_t>(_mkgmtime(&t));

    // Convert samples.
    // Note: The exact Pigeon C++ constructor signatures depend on the
    // generated dive_computer_api.g.h. The implementor must check the
    // generated constructors and adjust the nullable parameter passing
    // pattern (nullptr vs std::optional vs pointer) per Pigeon version.
    flutter::EncodableList samples;
    if (dive.samples) {
        for (unsigned int i = 0; i < dive.sample_count; i++) {
            const libdc_sample_t& s = dive.samples[i];
            // Build ProfileSample with all 14 fields.
            // Map NaN -> null for doubles, UINT32_MAX -> null for ints.
            // Map TTS=0 -> null (dive computers report 0 when not in deco).
            // Consult dive_computer_api.g.h for exact constructor.
            // The pattern matches macOS Swift: sentinel -> null.
            samples.push_back(/* ProfileSample(...) */);
        }
    }

    // Convert gas mixes.
    flutter::EncodableList gas_mixes;
    for (unsigned int i = 0; i < dive.gasmix_count; i++) {
        gas_mixes.push_back(/* GasMix(i, o2*100, he*100) */);
    }

    // Convert tanks.
    flutter::EncodableList tanks;
    for (unsigned int i = 0; i < dive.tank_count; i++) {
        tanks.push_back(/* TankInfo(i, gasmix, volume, begin, end) */);
    }

    // Convert events.
    flutter::EncodableList events;
    if (dive.events) {
        for (unsigned int i = 0; i < dive.event_count; i++) {
            const libdc_event_t& e = dive.events[i];
            if (e.type == 0) continue;  // skip EVENT_NONE
            events.push_back(/* DiveEvent(time, type_name, data_map) */);
        }
    }

    // Map dive mode.
    std::optional<std::string> dive_mode;
    switch (dive.dive_mode) {
        case 0: dive_mode = "freedive"; break;
        case 1: dive_mode = "gauge"; break;
        case 2: dive_mode = "open_circuit"; break;
        case 3: dive_mode = "ccr"; break;
        case 4: dive_mode = "scr"; break;
    }

    // Map deco model.
    std::optional<std::string> deco_algorithm;
    switch (dive.deco_model_type) {
        case 1: deco_algorithm = "buhlmann"; break;
        case 2: deco_algorithm = "vpm"; break;
        case 3: deco_algorithm = "rgbm"; break;
        case 4: deco_algorithm = "dciem"; break;
    }

    // Build and return ParsedDive.
    // GF: 0 means unknown -> null.
    // Conservatism: 0 means unknown/neutral -> null.
    return ParsedDive(/* ... all fields ... */);
}

}  // namespace libdivecomputer_plugin
```text
Note: The sample/tank/event/ParsedDive constructors above use placeholder comments because the exact Pigeon-generated C++ API varies. The implementor must read `dive_computer_api.g.h` to fill in the correct constructors. The mapping logic (which fields, which sentinels) is identical to the macOS Swift version.

**Step 3: Update CMakeLists.txt**

Add `dive_converter.cc` to the plugin sources:

```cmake
add_library(${PLUGIN_NAME} SHARED
    libdivecomputer_plugin_c_api.cc
    dive_computer_host_api_impl.cc
    dive_converter.cc
    dive_computer_api.g.cc
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
)
```text
**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/windows/dive_converter.*
git add packages/libdivecomputer_plugin/windows/CMakeLists.txt
git commit -m "feat(windows): add dive converter for full sample/event/deco mapping"
```diff
---

### Task C2: Implement Windows BLE scanner (WinRT)

**Files:**

- Create: `windows/ble_scanner.h`
- Create: `windows/ble_scanner.cc`

This task implements BLE device discovery using Windows Runtime APIs.

**Key WinRT types:**

- `Windows::Devices::Bluetooth::Advertisement::BluetoothLEAdvertisementWatcher`
- `Windows::Devices::Bluetooth::Advertisement::BluetoothLEAdvertisementReceivedEventArgs`

**Architecture:**

1. Create a `BleScanner` class wrapping the watcher
2. On `Received` event, extract `LocalName` from advertisement
3. Call `libdc_descriptor_match()` on the name
4. Report matches via callback (which the host API impl forwards to Pigeon)
5. On `Stopped` event, report completion

**Implementation notes for the implementor:**

- Requires `#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>`
- WinRT events are asynchronous; callbacks arrive on a thread pool thread
- Use `flutter::TaskRunner` or `PostMessage` to marshal back to Flutter's platform thread
- The watcher must be started/stopped carefully to avoid resource leaks
- Include `<winrt/base.h>` and link against `WindowsApp.lib`

**CMakeLists.txt additions:**

```cmake
# Add C++/WinRT support
set(CMAKE_CXX_STANDARD 20)
target_compile_options(${PLUGIN_NAME} PRIVATE /await)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin divecomputer WindowsApp.lib)
```text
**Step: Implement, build on Windows CI, commit**

```bash
git add packages/libdivecomputer_plugin/windows/ble_scanner.*
git commit -m "feat(windows): implement BLE scanner via WinRT"
```dart
---

### Task C3: Implement Windows BLE I/O stream (WinRT GATT)

**Files:**

- Create: `windows/ble_io_stream.h`
- Create: `windows/ble_io_stream.cc`

**Key WinRT types:**

- `Windows::Devices::Bluetooth::BluetoothLEDevice::FromBluetoothAddressAsync`
- `Windows::Devices::Bluetooth::GenericAttributeProfile::GattDeviceService`
- `Windows::Devices::Bluetooth::GenericAttributeProfile::GattCharacteristic`

**Architecture:**
Same semaphore-based synchronous bridge as macOS/iOS:

1. Connect via BLE address
2. Discover GATT services matching known dive computer UUIDs
3. Subscribe to notifications on the RX characteristic
4. `read()`: Block on `std::condition_variable` until notification data arrives
5. `write()`: Write to TX characteristic, block until acknowledged
6. Implements `libdc_io_callbacks_t`

**Implementation notes:**

- Use `std::mutex` + `std::condition_variable` (Windows equivalent of Apple's semaphores)
- WinRT async operations use `co_await` with C++/WinRT coroutines
- The I/O callbacks are called from libdivecomputer's download thread (blocking)
- Characteristic UUIDs should match the same set used by BleIoStream.swift

**Step: Implement, build on Windows CI, commit**

```bash
git add packages/libdivecomputer_plugin/windows/ble_io_stream.*
git commit -m "feat(windows): implement BLE I/O stream via WinRT GATT"
```diff
---

### Task C4: Implement Windows serial scanner and I/O stream

**Files:**

- Create: `windows/serial_scanner.h`
- Create: `windows/serial_scanner.cc`
- Create: `windows/serial_io_stream.h`
- Create: `windows/serial_io_stream.cc`

**Serial Scanner:**

1. Use `SetupDiGetClassDevs(GUID_DEVINTERFACE_COMPORT, ...)` to list COM ports
2. For each port, get the friendly name via `SetupDiGetDeviceRegistryProperty`
3. Call `libdc_descriptor_match()` with the device name
4. Report matched devices

**Serial I/O Stream:**

1. Open COM port via `CreateFile("\\\\.\\COMx", ...)`
2. Configure via `SetCommState` (baud rate, 8N1)
3. Set timeouts via `SetCommTimeouts`
4. `read()`: `ReadFile` with overlapped I/O for timeout support
5. `write()`: `WriteFile`
6. Implements `libdc_io_callbacks_t`

**Step: Implement, build on Windows CI, commit**

```bash
git add packages/libdivecomputer_plugin/windows/serial_scanner.* \
        packages/libdivecomputer_plugin/windows/serial_io_stream.*
git commit -m "feat(windows): implement serial scanner and I/O stream"
```diff
---

### Task C5: Wire everything into Windows DiveComputerHostApiImpl

**Files:**

- Modify: `windows/dive_computer_host_api_impl.h`
- Modify: `windows/dive_computer_host_api_impl.cc`
- Modify: `windows/CMakeLists.txt`

**Step 1: Update the header**

Add member variables for scanner, download state:

```cpp
#include "ble_scanner.h"
#include "ble_io_stream.h"
#include "serial_scanner.h"
#include "serial_io_stream.h"
#include "dive_converter.h"

// ... in private section:
std::unique_ptr<BleScanner> ble_scanner_;
std::unique_ptr<SerialScanner> serial_scanner_;
libdc_download_session_t* download_session_ = nullptr;
std::thread download_thread_;
```text
**Step 2: Implement StartDiscovery**

Replace the stub with transport routing:

```cpp
void DiveComputerHostApiImpl::StartDiscovery(
    const TransportType& transport,
    std::function<void(std::optional<FlutterError> reply)> result) {
  switch (transport) {
    case TransportType::kBle:
      ble_scanner_ = std::make_unique<BleScanner>();
      ble_scanner_->SetOnDeviceDiscovered([this](DiscoveredDevice device) {
        flutter_api_->OnDeviceDiscovered(device, [](auto) {});
      });
      ble_scanner_->SetOnComplete([this]() {
        flutter_api_->OnDiscoveryComplete([](auto) {});
      });
      ble_scanner_->Start();
      result(std::nullopt);
      break;
    case TransportType::kSerial:
    case TransportType::kUsb:
      serial_scanner_ = std::make_unique<SerialScanner>();
      // ... similar callback wiring
      serial_scanner_->Start();
      result(std::nullopt);
      break;
    default:
      result(FlutterError("unsupported_transport",
                          "Transport not yet supported on Windows"));
  }
}
```text
**Step 3: Implement StartDownload**

Replace the stub. Route to BLE or serial I/O stream based on transport:

```cpp
void DiveComputerHostApiImpl::StartDownload(
    const DiscoveredDevice& device,
    std::function<void(std::optional<FlutterError> reply)> result) {
  result(std::nullopt);  // Acknowledge start immediately.

  download_thread_ = std::thread([this, device]() {
    auto* session = libdc_download_session_new();
    if (!session) {
      // Report error via flutter_api_
      return;
    }
    download_session_ = session;

    // Set up I/O callbacks based on transport.
    libdc_io_callbacks_t io_callbacks = {};
    // ... create BleIoStream or SerialIoStream, fill io_callbacks

    // Set up download callbacks.
    libdc_download_callbacks_t dl_callbacks = {};
    dl_callbacks.on_dive = [](const libdc_parsed_dive_t* dive, void* ud) {
      auto parsed = ConvertParsedDive(*dive);
      // Marshal to Flutter thread, call flutter_api_->OnDiveDownloaded
    };
    dl_callbacks.userdata = this;

    char error_buf[256] = {};
    int rc = libdc_download_run(session, /* ... */);

    // Report completion or error, cleanup.
    libdc_download_session_free(session);
    download_session_ = nullptr;
  });
}
```text
**Step 4: Update CMakeLists.txt with all new source files**

```cmake
add_library(${PLUGIN_NAME} SHARED
    libdivecomputer_plugin_c_api.cc
    dive_computer_host_api_impl.cc
    dive_converter.cc
    ble_scanner.cc
    ble_io_stream.cc
    serial_scanner.cc
    serial_io_stream.cc
    dive_computer_api.g.cc
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
)
```text
**Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/windows/
git commit -m "feat(windows): wire BLE + serial into host API, full download flow"
```swift
---

## Stream D: Linux Full Implementation

### Task D1: Create the dive converter (C struct to Pigeon GObject mapping)

**Files:**

- Create: `linux/dive_converter.h`
- Create: `linux/dive_converter.c`

**Step 1: Create dive_converter.h**

```c
#ifndef DIVE_CONVERTER_H_
#define DIVE_CONVERTER_H_

#include <flutter_linux/flutter_linux.h>
#include "dive_computer_api.g.h"
#include "libdc_wrapper.h"

G_BEGIN_DECLS

// Converts a parsed dive from the C wrapper into a Pigeon GObject ParsedDive.
LibdivecomputerPluginParsedDive* convert_parsed_dive(const libdc_parsed_dive_t* dive);

// Maps a libdivecomputer event type to a string name.
const char* map_event_type(unsigned int type);

G_END_DECLS

#endif  // DIVE_CONVERTER_H_
```typescript
**Step 2: Create dive_converter.c**

This follows the same pattern as the Windows converter but uses GObject/FlValue APIs.

The mapping logic is identical:

- Fingerprint hex encoding
- DateTime to epoch via `timegm()`
- 14 sample fields with NaN/UINT32_MAX sentinel checks
- 25 event type string mapping
- Deco model/GF with 0-means-unknown sentinel
- TTS=0 filter

Uses Pigeon-generated GObject constructors like:

- `libdivecomputer_plugin_profile_sample_new(...)`
- `libdivecomputer_plugin_dive_event_new(...)`
- `libdivecomputer_plugin_parsed_dive_new(...)`

The implementor should read `dive_computer_api.g.h` to confirm the exact constructor signatures for the GObject types.

**Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/linux/dive_converter.*
git commit -m "feat(linux): add dive converter for full sample/event/deco mapping"
```diff
---

### Task D2: Implement Linux BLE scanner (BlueZ D-Bus)

**Files:**

- Create: `linux/ble_scanner.h`
- Create: `linux/ble_scanner.c`

**Architecture:**

1. Get system D-Bus via `g_bus_get_sync(G_BUS_TYPE_SYSTEM, ...)`
2. Find the BlueZ adapter object (typically `/org/bluez/hci0`)
3. Set discovery filter: `org.bluez.Adapter1.SetDiscoveryFilter({"Transport": "le"})`
4. Start discovery: `org.bluez.Adapter1.StartDiscovery`
5. Subscribe to `InterfacesAdded` on `org.freedesktop.DBus.ObjectManager`
6. For each new `org.bluez.Device1`, read `Name` property
7. Call `libdc_descriptor_match(name, LIBDC_TRANSPORT_BLE, &info)`
8. Report matches via callback

**Key GLib/D-Bus functions:**

- `g_dbus_connection_call_sync()` for method calls
- `g_dbus_connection_signal_subscribe()` for signals
- `g_variant_new()` / `g_variant_get()` for D-Bus variant handling

**Threading:**

- BLE scanner runs on GLib main loop (GMainContext)
- Callbacks naturally arrive on the main thread

**Step: Implement, build on Linux CI, commit**

```bash
git add packages/libdivecomputer_plugin/linux/ble_scanner.*
git commit -m "feat(linux): implement BLE scanner via BlueZ D-Bus"
```diff
---

### Task D3: Implement Linux BLE I/O stream (BlueZ D-Bus GATT)

**Files:**

- Create: `linux/ble_io_stream.h`
- Create: `linux/ble_io_stream.c`

**Architecture:**
Same synchronous bridge pattern, but using GMutex/GCond instead of semaphores:

1. Connect: `org.bluez.Device1.Connect`
2. Discover GATT characteristics under the device object path
3. Subscribe: `org.bluez.GattCharacteristic1.StartNotify`
4. `read()`: Block on `g_cond_wait_until()` until `PropertiesChanged` signal delivers data
5. `write()`: `org.bluez.GattCharacteristic1.WriteValue` with options dict
6. Implements `libdc_io_callbacks_t`

**Key detail:** D-Bus property changes arrive as `PropertiesChanged` signals on `org.freedesktop.DBus.Properties`. The data is in the `Value` property of the GATT characteristic.

**Step: Implement, build on Linux CI, commit**

```bash
git add packages/libdivecomputer_plugin/linux/ble_io_stream.*
git commit -m "feat(linux): implement BLE I/O stream via BlueZ D-Bus GATT"
```sql
---

### Task D4: Implement Linux serial scanner and I/O stream

**Files:**

- Create: `linux/serial_scanner.h`
- Create: `linux/serial_scanner.c`
- Create: `linux/serial_io_stream.h`
- Create: `linux/serial_io_stream.c`

**Serial Scanner:**

1. Scan `/dev/ttyUSB*` and `/dev/ttyACM*` via `opendir`/`readdir` on `/dev/`
2. For each matching device, read metadata from `/sys/class/tty/<name>/device/`
3. Call `libdc_descriptor_match()` with device info
4. Report matched devices

**Serial I/O Stream:**

1. Open device via `open("/dev/ttyUSBx", O_RDWR | O_NOCTTY)`
2. Configure via `tcsetattr()` (baud, 8N1, raw mode)
3. `read()`: Use `select()` or `poll()` for timeout, then `read()`
4. `write()`: `write()` with retry
5. Implements `libdc_io_callbacks_t`

**Step: Implement, build on Linux CI, commit**

```bash
git add packages/libdivecomputer_plugin/linux/serial_scanner.* \
        packages/libdivecomputer_plugin/linux/serial_io_stream.*
git commit -m "feat(linux): implement serial scanner and I/O stream"
```diff
---

### Task D5: Wire everything into Linux DiveComputerHostApiImpl

**Files:**

- Modify: `linux/dive_computer_host_api_impl.cc`
- Modify: `linux/dive_computer_host_api_impl.h`
- Modify: `linux/CMakeLists.txt`

**Step 1: Update handle_start_discovery**

Replace the stub with transport routing (BLE via BlueZ, serial via enumeration).

**Step 2: Update handle_start_download**

Replace the stub. Create a `GThread` for the blocking download, route to BLE or serial I/O based on transport.

**Step 3: Add HostApiContext fields**

```c
struct HostApiContext {
    FlBinaryMessenger* messenger;
    LibdivecomputerPluginDiveComputerFlutterApi* flutter_api;
    BleScanner* ble_scanner;
    SerialScanner* serial_scanner;
    libdc_download_session_t* session;
    GThread* download_thread;
};
```text
**Step 4: Update CMakeLists.txt**

```cmake
# Add gio-2.0 for GDBusConnection
find_package(PkgConfig REQUIRED)
pkg_check_modules(GIO REQUIRED gio-2.0)

add_library(${PLUGIN_NAME} SHARED
    libdivecomputer_plugin.cc
    dive_computer_host_api_impl.cc
    dive_converter.c
    ble_scanner.c
    ble_io_stream.c
    serial_scanner.c
    serial_io_stream.c
    dive_computer_api.g.cc
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
)

target_include_directories(${PLUGIN_NAME} PRIVATE ${GIO_INCLUDE_DIRS})
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter divecomputer ${GIO_LIBRARIES})
```text
**Step 5: Commit**

```bash
git add packages/libdivecomputer_plugin/linux/
git commit -m "feat(linux): wire BLE + serial into host API, full download flow"
```diff
---

## Stream E: Testing Infrastructure + CI

### Task E1: Create shared C wrapper unit tests

**Files:**

- Create: `test/native/CMakeLists.txt`
- Create: `test/native/test_dive_converter.c`

**Step 1: Create test CMakeLists.txt**

```cmake
cmake_minimum_required(VERSION 3.18)
project(libdc_wrapper_tests LANGUAGES C CXX)

set(WRAPPER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../macos/Classes")
set(LIBDC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/libdivecomputer")
set(CONFIG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../macos/config")

# Test the wrapper struct definitions and sentinel conventions
add_executable(test_dive_converter
    test_dive_converter.c
)
target_include_directories(test_dive_converter PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)

enable_testing()
add_test(NAME test_dive_converter COMMAND test_dive_converter)
```text
**Step 2: Create test_dive_converter.c**

Test that sentinel values (NaN, UINT32_MAX) map correctly:

```c
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include "libdc_wrapper.h"

static void test_sample_sentinels(void) {
    libdc_sample_t sample = {0};
    sample.time_ms = 60000;
    sample.depth = 10.5;
    sample.temperature = NAN;        // should map to null
    sample.pressure = NAN;           // should map to null
    sample.tank = UINT32_MAX;        // should map to null
    sample.heartbeat = UINT32_MAX;   // should map to null
    sample.setpoint = NAN;
    sample.ppo2 = 1.2;              // valid value
    sample.cns = 45.0;              // valid value
    sample.rbt = 600;               // valid value
    sample.deco_type = 0;           // NDL (valid)
    sample.deco_time = 300;
    sample.deco_depth = NAN;
    sample.deco_tts = 0;            // should map to null (tts=0 filter)

    assert(sample.time_ms == 60000);
    assert(sample.depth == 10.5);
    assert(isnan(sample.temperature));
    assert(sample.tank == UINT32_MAX);
    assert(sample.heartbeat == UINT32_MAX);
    assert(sample.ppo2 == 1.2);
    assert(sample.cns == 45.0);
    assert(sample.rbt == 600);
    assert(sample.deco_tts == 0);
    printf("PASS: test_sample_sentinels\n");
}

static void test_deco_model_sentinels(void) {
    libdc_parsed_dive_t dive = {0};
    dive.deco_model_type = 1;  // buhlmann
    dive.gf_low = 30;
    dive.gf_high = 70;
    dive.deco_conservatism = 0;  // means "unknown" or "neutral"

    assert(dive.deco_model_type == 1);
    assert(dive.gf_low == 30);
    assert(dive.gf_high == 70);
    assert(dive.deco_conservatism == 0);
    printf("PASS: test_deco_model_sentinels\n");
}

static void test_fingerprint_hex(void) {
    libdc_parsed_dive_t dive = {0};
    dive.fingerprint[0] = 0xAB;
    dive.fingerprint[1] = 0xCD;
    dive.fingerprint[2] = 0xEF;
    dive.fingerprint_size = 3;

    char hex[LIBDC_MAX_FINGERPRINT * 2 + 1] = {0};
    for (unsigned int i = 0; i < dive.fingerprint_size; i++) {
        snprintf(hex + i * 2, 3, "%02x", dive.fingerprint[i]);
    }
    assert(strcmp(hex, "abcdef") == 0);
    printf("PASS: test_fingerprint_hex\n");
}

static void test_event_count(void) {
    libdc_parsed_dive_t dive = {0};
    dive.event_count = 0;
    dive.events = NULL;
    assert(dive.event_count == 0);
    assert(dive.events == NULL);
    printf("PASS: test_event_count\n");
}

int main(void) {
    test_sample_sentinels();
    test_deco_model_sentinels();
    test_fingerprint_hex();
    test_event_count();
    printf("\nAll tests passed.\n");
    return 0;
}
```text
**Step 3: Build and run tests**

```bash
cd packages/libdivecomputer_plugin
cmake -B build/test test/native
cmake --build build/test
ctest --test-dir build/test --output-on-failure
```text
**Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/test/native/
git commit -m "test: add C wrapper unit tests for sentinel mapping"
```diff
---

### Task E2: Add CI workflows

**Files:**

- Create or modify: `.github/workflows/native-plugin-tests.yml`

**Step 1: Create CI workflow**

```yaml
name: Native Plugin Tests

on:
  push:
    paths:
      - 'packages/libdivecomputer_plugin/**'
  pull_request:
    paths:
      - 'packages/libdivecomputer_plugin/**'

jobs:
  c-wrapper-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Build and run C wrapper tests
        run: |
          cd packages/libdivecomputer_plugin
          cmake -B build/test test/native
          cmake --build build/test
          ctest --test-dir build/test --output-on-failure

  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter build macos --debug

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter build ios --simulator --debug --no-codesign

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter build windows --debug

  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: |
          sudo apt-get update
          sudo apt-get install -y libgtk-3-dev ninja-build libglib2.0-dev
      - run: flutter build linux --debug
```text
**Step 2: Commit**

```bash
git add .github/workflows/native-plugin-tests.yml
git commit -m "ci: add native plugin build verification for all platforms"
```

---

## Verification Checklist

After all streams complete, verify:

- [ ] `flutter build macos --debug` passes
- [ ] `flutter build ios --simulator --debug` passes
- [ ] `flutter build windows --debug` passes (CI)
- [ ] `flutter build linux --debug` passes (CI)
- [ ] C wrapper unit tests pass
- [ ] macOS download produces ParsedDive with all 14 sample fields (manual test with real device)
- [ ] iOS download produces identical ParsedDive to macOS (manual test)
- [ ] Platform parity table shows all "Full" across the board
