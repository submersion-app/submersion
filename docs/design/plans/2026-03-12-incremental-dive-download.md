# Incremental Dive Download Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Only download new dives from dive computers by passing the last-known fingerprint to libdivecomputer, storing it after successful import, and providing a UI toggle to override.

**Architecture:** Add `lastDiveFingerprint` column to DiveComputers table. Thread hex-encoded fingerprint through Pigeon API to all 5 native platforms. Repurpose existing `newDivesOnly` state field to drive the fingerprint decision. Persist fingerprint only after successful import (safety-first).

**Tech Stack:** Flutter/Dart, Drift ORM, Riverpod, Pigeon codegen, Swift (iOS/macOS), Kotlin+JNI (Android), C++ (Windows), GObject C (Linux), libdivecomputer C library.

**Spec:** `docs/superpowers/specs/2026-03-12-incremental-dive-download-design.md`

---

## Chunk 1: Data Layer (Schema, Entity, Repository, Utility)

### Task 1: Add `selectNewestFingerprint` utility with tests

**Files:**
- Create: `lib/features/dive_computer/data/services/fingerprint_utils.dart`
- Create: `test/features/dive_computer/data/services/fingerprint_utils_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_computer/data/services/fingerprint_utils_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/data/services/fingerprint_utils.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

void main() {
  group('selectNewestFingerprint', () {
    test('returns null for empty list', () {
      expect(selectNewestFingerprint([]), isNull);
    });

    test('returns null when no dives have fingerprints', () {
      final dives = [
        DownloadedDive(
          startTime: DateTime(2026, 1, 1),
          durationSeconds: 3600,
          maxDepth: 20.0,
          profile: [],
        ),
      ];
      expect(selectNewestFingerprint(dives), isNull);
    });

    test('returns fingerprint of the newest dive by startTime', () {
      final dives = [
        DownloadedDive(
          startTime: DateTime(2026, 1, 1, 10, 0),
          durationSeconds: 3600,
          maxDepth: 20.0,
          profile: [],
          fingerprint: 'aabb01',
        ),
        DownloadedDive(
          startTime: DateTime(2026, 1, 3, 14, 0),
          durationSeconds: 2400,
          maxDepth: 25.0,
          profile: [],
          fingerprint: 'ccdd02',
        ),
        DownloadedDive(
          startTime: DateTime(2026, 1, 2, 8, 0),
          durationSeconds: 1800,
          maxDepth: 15.0,
          profile: [],
          fingerprint: 'eeff03',
        ),
      ];
      expect(selectNewestFingerprint(dives), equals('ccdd02'));
    });

    test('skips dives without fingerprints when selecting newest', () {
      final dives = [
        DownloadedDive(
          startTime: DateTime(2026, 1, 5),
          durationSeconds: 3600,
          maxDepth: 30.0,
          profile: [],
          // no fingerprint
        ),
        DownloadedDive(
          startTime: DateTime(2026, 1, 3),
          durationSeconds: 2400,
          maxDepth: 20.0,
          profile: [],
          fingerprint: 'aabb01',
        ),
      ];
      expect(selectNewestFingerprint(dives), equals('aabb01'));
    });

    test('handles single dive with fingerprint', () {
      final dives = [
        DownloadedDive(
          startTime: DateTime(2026, 3, 1),
          durationSeconds: 3000,
          maxDepth: 18.0,
          profile: [],
          fingerprint: 'single01',
        ),
      ];
      expect(selectNewestFingerprint(dives), equals('single01'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_computer/data/services/fingerprint_utils_test.dart`
Expected: FAIL (import not found)

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/dive_computer/data/services/fingerprint_utils.dart`:

```dart
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// Select the fingerprint of the newest dive (by startTime) from a list.
///
/// Only considers dives that have a non-null fingerprint.
/// Returns null if the list is empty or no dives have fingerprints.
///
/// IMPORTANT: Call this with only successfully imported dives
/// (importResult.importedDives), not all downloaded dives.
String? selectNewestFingerprint(List<DownloadedDive> dives) {
  if (dives.isEmpty) return null;

  final divesWithFingerprints =
      dives.where((d) => d.fingerprint != null).toList();

  if (divesWithFingerprints.isEmpty) return null;

  divesWithFingerprints.sort((a, b) => b.startTime.compareTo(a.startTime));
  return divesWithFingerprints.first.fingerprint;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_computer/data/services/fingerprint_utils_test.dart`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_computer/data/services/fingerprint_utils.dart test/features/dive_computer/data/services/fingerprint_utils_test.dart
git commit -m "feat: add selectNewestFingerprint utility for incremental download"
```

### Task 2: Add `lastDiveFingerprint` to DiveComputer entity

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive_computer.dart`

- [ ] **Step 1: Add the field to the entity class**

In `lib/features/dive_log/domain/entities/dive_computer.dart`:

1. Add field after `lastDownload`:
```dart
  /// Fingerprint of the newest dive from the last successful import.
  /// Used for incremental downloads -- libdivecomputer stops at this dive.
  final String? lastDiveFingerprint;
```

2. Add to constructor after `this.lastDownload`:
```dart
    this.lastDiveFingerprint,
```

3. Add to `copyWith` parameters after `DateTime? lastDownload`:
```dart
    String? lastDiveFingerprint,
```

4. Add to `copyWith` return body after `lastDownload: lastDownload ?? this.lastDownload`:
```dart
      lastDiveFingerprint: lastDiveFingerprint ?? this.lastDiveFingerprint,
```

5. Add to `props` list after `lastDownload`:
```dart
    lastDiveFingerprint,
```

- [ ] **Step 2: Verify no compile errors**

Run: `dart analyze lib/features/dive_log/domain/entities/dive_computer.dart`
Expected: No errors (warnings about unused field are acceptable at this stage)

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/domain/entities/dive_computer.dart
git commit -m "feat: add lastDiveFingerprint field to DiveComputer entity"
```

### Task 3: Add schema migration and update repository mapping

**Files:**
- Modify: `lib/core/database/database.dart` (line 861-882, line 1166)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (lines 1171-1191, add new method)

- [ ] **Step 1: Add column to DiveComputers table**

In `lib/core/database/database.dart`, inside `class DiveComputers extends Table`, add after the `bluetoothAddress` column (line 871):

```dart
  TextColumn get lastDiveFingerprint => text().nullable()();
```

- [ ] **Step 2: Bump schema version and add migration**

In `lib/core/database/database.dart`:

1. Change `schemaVersion => 46` to `schemaVersion => 47` (line 1166)

2. Add migration block after the `from < 46` block (after line ~2140):

```dart
        if (from < 47) {
          // Add lastDiveFingerprint column for incremental dive download
          final dcInfo = await customSelect(
            'PRAGMA table_info(dive_computers)',
          ).get();
          final dcCols = dcInfo
              .map((r) => r.read<String>('name'))
              .toSet();
          if (!dcCols.contains('last_dive_fingerprint')) {
            await customStatement(
              'ALTER TABLE dive_computers ADD COLUMN last_dive_fingerprint TEXT',
            );
          }
        }
```

- [ ] **Step 3: Update `_mapRowToComputer` in repository**

In `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`, update `_mapRowToComputer` (line 1171) to include the new field. Add after `bluetoothAddress: row.bluetoothAddress,`:

```dart
      lastDiveFingerprint: row.lastDiveFingerprint,
```

- [ ] **Step 4: Add `updateLastFingerprint` method to repository**

In `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`, add after the `updateLastDownload` method (after line ~320):

```dart
  /// Update the last dive fingerprint after a successful import.
  ///
  /// This fingerprint is passed to libdivecomputer on the next download
  /// to enable incremental downloads (only new dives).
  Future<void> updateLastFingerprint(
    String id,
    String fingerprint,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.diveComputers,
      )..where((t) => t.id.equals(id))).write(
        DiveComputersCompanion(
          lastDiveFingerprint: Value(fingerprint),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveComputers',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update last fingerprint for: $id',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 5: Do NOT add `lastDiveFingerprint` to `updateComputer`**

The `updateComputer` method is called from multiple places (including `_persistDeviceInfoAndImport` which runs BEFORE import). If we include `lastDiveFingerprint` there, any call with a stale entity (where `lastDiveFingerprint` is null) would erase a previously stored fingerprint. The fingerprint is managed exclusively by the dedicated `updateLastFingerprint` method — keep it that way. No changes needed to `updateComputer`.

- [ ] **Step 6: Run build_runner to regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Build completes successfully, `database.g.dart` regenerated with `lastDiveFingerprint` column.

- [ ] **Step 7: Verify compilation**

Run: `dart analyze lib/core/database/database.dart lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart
git commit -m "feat: add lastDiveFingerprint schema column and repository support"
```

---

## Chunk 2: Pigeon API & Native Platforms

### Task 4: Update Pigeon API definition

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` (line 186)

- [ ] **Step 1: Add fingerprint parameter to startDownload**

In `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`, change line 186 from:

```dart
  void startDownload(DiscoveredDevice device);
```

to:

```dart
  void startDownload(DiscoveredDevice device, String? fingerprint);
```

- [ ] **Step 2: Regenerate Pigeon code**

Run from the plugin directory:

```bash
cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart
```

Expected: Generates updated files for all platforms:
- `lib/src/generated/dive_computer_api.g.dart`
- `ios/Classes/DiveComputerApi.g.swift`
- `android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerApi.g.kt`
- `linux/dive_computer_api.g.h` and `linux/dive_computer_api.g.cc`
- `windows/dive_computer_api.g.h` and `windows/dive_computer_api.g.cc`

- [ ] **Step 3: Commit Pigeon changes (including macOS generated file)**

Note: Pigeon generates Swift to `ios/Classes/DiveComputerApi.g.swift`. The macOS target uses a separate identical copy at `macos/Classes/DiveComputerApi.g.swift` (NOT auto-generated by Pigeon). After running Pigeon, copy the iOS output to macOS:

```bash
cp packages/libdivecomputer_plugin/ios/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/macos/Classes/DiveComputerApi.g.swift
```

```bash
git add packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart packages/libdivecomputer_plugin/lib/src/generated/ packages/libdivecomputer_plugin/ios/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/macos/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerApi.g.kt packages/libdivecomputer_plugin/linux/dive_computer_api.g.h packages/libdivecomputer_plugin/linux/dive_computer_api.g.cc packages/libdivecomputer_plugin/windows/dive_computer_api.g.h packages/libdivecomputer_plugin/windows/dive_computer_api.g.cc
git commit -m "feat: add fingerprint parameter to Pigeon startDownload API"
```

### Task 5: Update DiveComputerService Dart wrapper

**Files:**
- Modify: `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart` (line 86-88)

- [ ] **Step 1: Add fingerprint parameter to startDownload**

In `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart`, change lines 86-88 from:

```dart
  Future<void> startDownload(DiscoveredDevice device) {
    return _hostApi.startDownload(device);
  }
```

to:

```dart
  Future<void> startDownload(DiscoveredDevice device, {String? fingerprint}) {
    return _hostApi.startDownload(device, fingerprint);
  }
```

- [ ] **Step 2: Verify compilation**

Run: `dart analyze packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart
git commit -m "feat: add fingerprint parameter to DiveComputerService.startDownload"
```

### Task 6: Update iOS/macOS native implementation (Swift)

**Files:**
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` (lines 136-142, 158, 223-228)

- [ ] **Step 1: Update startDownload to accept and pass fingerprint**

After Pigeon regeneration, the generated protocol will require `startDownload(device:fingerprint:completion:)`. Update the implementation:

1. Change `startDownload` (line 136) to match the new Pigeon signature:

```swift
    func startDownload(device: DiscoveredDevice, fingerprint: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.performDownload(device: device, fingerprint: fingerprint)
        }
    }
```

2. Update `performDownload` signature (line 158) to accept fingerprint:

```swift
    private func performDownload(device: DiscoveredDevice, fingerprint: String?) {
```

3. Replace the `libdc_download_run` call (lines 223-233). Change from `nil, 0` to the decoded fingerprint:

```swift
        // Decode fingerprint from hex string if provided.
        var fingerprintBytes: [UInt8]? = nil
        if let hex = fingerprint, !hex.isEmpty {
            fingerprintBytes = stride(from: 0, to: hex.count, by: 2).compactMap { i in
                let start = hex.index(hex.startIndex, offsetBy: i)
                let end = hex.index(start, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
                return UInt8(hex[start..<end], radix: 16)
            }
        }

        // Run the download (blocks until complete).
        var serial: UInt32 = 0
        var firmware: UInt32 = 0
        var errorBuf = [CChar](repeating: 0, count: 256)
        let result: Int32
        if let fp = fingerprintBytes, !fp.isEmpty {
            result = fp.withUnsafeBufferPointer { buf in
                libdc_download_run(
                    session,
                    device.vendor, device.product, UInt32(device.model),
                    transportValue,
                    &ioCallbacks,
                    buf.baseAddress, UInt32(buf.count),
                    &downloadCallbacks,
                    &serial,
                    &firmware,
                    &errorBuf, errorBuf.count
                )
            }
        } else {
            result = libdc_download_run(
                session,
                device.vendor, device.product, UInt32(device.model),
                transportValue,
                &ioCallbacks,
                nil, 0,
                &downloadCallbacks,
                &serial,
                &firmware,
                &errorBuf, errorBuf.count
            )
        }
```

- [ ] **Step 2: Verify compilation on macOS**

Run: `flutter build macos --debug 2>&1 | head -20` (or check Xcode build output)
Expected: Compiles without errors

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift
git commit -m "feat(darwin): pass fingerprint to libdc_download_run for incremental download"
```

### Task 7: Update Android native implementation (Kotlin + JNI)

**Files:**
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt` (line ~222-230)
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` (line 29-39)
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` (line 429-436, 484-490)

- [ ] **Step 1: Update LibdcWrapper.nativeDownloadRun external declaration**

In `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt`, change lines 29-39 from:

```kotlin
    external fun nativeDownloadRun(
        sessionPtr: Long,
        vendor: String,
        product: String,
        model: Int,
        transport: Int,
        ioHandler: BleIoHandler,
        devName: String?,
        downloadCallback: DownloadCallback,
        errorBuf: ByteArray
    ): Int
```

to:

```kotlin
    external fun nativeDownloadRun(
        sessionPtr: Long,
        vendor: String,
        product: String,
        model: Int,
        transport: Int,
        ioHandler: BleIoHandler,
        devName: String?,
        fingerprint: ByteArray?,
        downloadCallback: DownloadCallback,
        errorBuf: ByteArray
    ): Int
```

- [ ] **Step 2: Update DiveComputerHostApiImpl to decode and pass fingerprint**

In `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`:

1. Update the `startDownload` override (Pigeon-generated interface will now require a `fingerprint: String?` parameter). Change from:

```kotlin
    override fun startDownload(device: DiscoveredDevice, callback: (Result<Unit>) -> Unit) {
        callback(Result.success(Unit))
        executor.execute { performDownload(device) }
    }
```

to:

```kotlin
    override fun startDownload(device: DiscoveredDevice, fingerprint: String?, callback: (Result<Unit>) -> Unit) {
        callback(Result.success(Unit))
        executor.execute { performDownload(device, fingerprint) }
    }
```

2. Update `performDownload` signature to accept fingerprint:

```kotlin
    private fun performDownload(device: DiscoveredDevice, fingerprint: String? = null, isRetry: Boolean = false) {
```

3. Update the GATT retry call (line 254) to forward the fingerprint:

```kotlin
// Before:
                performDownload(device, isRetry = true)
// After:
                performDownload(device, fingerprint, isRetry = true)
```

3. Before the `nativeDownloadRun` call (around line 222), decode the hex fingerprint:

```kotlin
        // Decode hex fingerprint to ByteArray for libdivecomputer.
        val fingerprintBytes: ByteArray? = fingerprint?.takeIf { it.isNotEmpty() }?.let { hex ->
            hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        }
```

3. Update the `nativeDownloadRun` call (line 224) to pass `fingerprintBytes` after `device.name`:

```kotlin
            LibdcWrapper.nativeDownloadRun(
                sessionPtr,
                device.vendor, device.product,
                device.model.toInt(), transportValue,
                bleStream, device.name,
                fingerprintBytes,
                downloadCallback, errorBuf
            )
```

- [ ] **Step 3: Update JNI C++ function to accept fingerprint**

In `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`, update the function signature at line 429. Change from:

```cpp
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDownloadRun(
    JNIEnv *env, jclass,
    jlong sessionPtr,
    jstring vendor, jstring product, jint model, jint transport,
    jobject ioHandler,
    jstring devName,
    jobject downloadCallback,
    jbyteArray errorBuf) {
```

to:

```cpp
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeDownloadRun(
    JNIEnv *env, jclass,
    jlong sessionPtr,
    jstring vendor, jstring product, jint model, jint transport,
    jobject ioHandler,
    jstring devName,
    jbyteArray fingerprint,
    jobject downloadCallback,
    jbyteArray errorBuf) {
```

Then replace the `libdc_download_run` call (lines 484-493). Change from `nullptr, 0` to the fingerprint:

```cpp
    // Decode fingerprint from Java byte array.
    unsigned char *fp_data = nullptr;
    unsigned int fp_size = 0;
    if (fingerprint != nullptr) {
        fp_size = static_cast<unsigned int>(env->GetArrayLength(fingerprint));
        if (fp_size > 0) {
            fp_data = new unsigned char[fp_size];
            env->GetByteArrayRegion(fingerprint, 0, fp_size,
                reinterpret_cast<jbyte *>(fp_data));
        }
    }

    // Run the download.
    char error_buf[256] = {0};
    int result = libdc_download_run(
        session,
        vendorStr, productStr,
        static_cast<unsigned int>(model),
        static_cast<unsigned int>(transport),
        &io_callbacks,
        fp_data, fp_size,
        &dl_callbacks,
        nullptr, nullptr,
        error_buf, sizeof(error_buf));

    // Cleanup fingerprint.
    delete[] fp_data;
```

- [ ] **Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp
git commit -m "feat(android): pass fingerprint through JNI to libdc_download_run"
```

### Task 8: Update Windows native implementation (C++)

**Files:**
- Modify: `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc` (lines 119-133, 253-266)

- [ ] **Step 1: Update StartDownload and PerformDownload**

After Pigeon regen, `StartDownload` will receive a `const std::string* fingerprint` (nullable pointer for optional). Update:

1. `StartDownload` to pass fingerprint to `PerformDownload`:

```cpp
void DiveComputerHostApiImpl::StartDownload(
    const DiscoveredDevice& device,
    const std::string* fingerprint,
    std::function<void(std::optional<FlutterError> reply)> result) {
    result(std::nullopt);

    if (download_thread_.joinable()) {
        download_thread_.join();
    }

    DiscoveredDevice device_copy = device;
    std::optional<std::string> fp_copy =
        fingerprint ? std::optional<std::string>(*fingerprint) : std::nullopt;
    download_thread_ = std::thread(
        [this, dev = std::move(device_copy), fp = std::move(fp_copy)]() {
            PerformDownload(dev, fp);
        });
}
```

2. Update `PerformDownload` signature and decode fingerprint:

Add parameter: `const std::optional<std::string>& fingerprint`

Before `libdc_download_run` call (line 257), decode the hex string:

```cpp
    // Decode fingerprint.
    std::vector<unsigned char> fp_bytes;
    if (fingerprint.has_value() && !fingerprint->empty()) {
        const auto& hex = *fingerprint;
        for (size_t i = 0; i + 1 < hex.size(); i += 2) {
            fp_bytes.push_back(
                static_cast<unsigned char>(std::stoi(hex.substr(i, 2), nullptr, 16)));
        }
    }

    int rc = libdc_download_run(
        session,
        device.vendor().c_str(), device.product().c_str(),
        static_cast<unsigned int>(device.model()),
        transport_value,
        &io_callbacks,
        fp_bytes.empty() ? nullptr : fp_bytes.data(),
        static_cast<unsigned int>(fp_bytes.size()),
        &dl_callbacks,
        &serial, &firmware,
        error_buf, sizeof(error_buf));
```

- [ ] **Step 2: Update header if needed**

Check `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.h` for `PerformDownload` declaration and update its signature to match.

- [ ] **Step 3: Commit**

```bash
git add packages/libdivecomputer_plugin/windows/
git commit -m "feat(windows): pass fingerprint to libdc_download_run"
```

### Task 9: Update Linux native implementation (GObject C)

**Files:**
- Modify: `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc` (lines 414-436, 258-266)

- [ ] **Step 1: Update handle_start_download and download thread**

After Pigeon regen, `handle_start_download` will receive the fingerprint as a **separate parameter** (not part of DiscoveredDevice). The generated callback signature will change from:

```c
static void handle_start_download(
    LibdivecomputerPluginDiscoveredDevice* device,
    LibdivecomputerPluginDiveComputerHostApiResponseHandle* response_handle,
    gpointer user_data)
```

to something like:

```c
static void handle_start_download(
    LibdivecomputerPluginDiscoveredDevice* device,
    const gchar* fingerprint,
    LibdivecomputerPluginDiveComputerHostApiResponseHandle* response_handle,
    gpointer user_data)
```

**Important:** Check the generated `dive_computer_api.g.h` after Pigeon regen to confirm the exact parameter name and type. The fingerprint is a separate function parameter, NOT a field on the device object.

Update:

1. Add a `gchar* fingerprint` field to the `DownloadThreadData` struct.

2. In `handle_start_download`, copy the fingerprint from the function parameter:

```c
  td->fingerprint = (fingerprint != NULL) ? g_strdup(fingerprint) : NULL;
```

2. Before `libdc_download_run` (line 258), decode the hex fingerprint:

```cpp
  // Decode fingerprint.
  unsigned char* fp_data = NULL;
  unsigned int fp_size = 0;
  if (td->fingerprint != NULL && td->fingerprint[0] != '\0') {
      size_t hex_len = strlen(td->fingerprint);
      fp_size = (unsigned int)(hex_len / 2);
      fp_data = (unsigned char*)g_malloc(fp_size);
      for (unsigned int i = 0; i < fp_size; i++) {
          char byte_str[3] = { td->fingerprint[i*2], td->fingerprint[i*2+1], '\0' };
          fp_data[i] = (unsigned char)strtol(byte_str, NULL, 16);
      }
  }

  int rc = libdc_download_run(
      ctx->session,
      td->vendor, td->product, td->model,
      transport_flag,
      &io_callbacks,
      fp_data, fp_size,
      &dl_callbacks,
      &serial_number, &firmware_version,
      error_buf, sizeof(error_buf));

  g_free(fp_data);
```

3. Free `td->fingerprint` in the thread data cleanup.

- [ ] **Step 2: Commit**

```bash
git add packages/libdivecomputer_plugin/linux/
git commit -m "feat(linux): pass fingerprint to libdc_download_run"
```

---

## Chunk 3: Download Flow, UI, and Integration

### Task 10: Wire fingerprint logic into DownloadNotifier

**Files:**
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart` (lines 135-161, 211-241, 260-295)

- [ ] **Step 1: Add fingerprint_utils import**

Add at the top of `download_providers.dart`:

```dart
import 'package:submersion/features/dive_computer/data/services/fingerprint_utils.dart';
```

- [ ] **Step 2: Update startDownload to pass fingerprint to native**

In `startDownload` (line 155), change:

```dart
      await _service.startDownload(device.toPigeon());
```

to:

```dart
      // Determine fingerprint for incremental download.
      String? fingerprint;
      if (state.newDivesOnly && computer?.lastDiveFingerprint != null) {
        fingerprint = computer!.lastDiveFingerprint;
      }

      await _service.startDownload(device.toPigeon(), fingerprint: fingerprint);
```

- [ ] **Step 3: Persist fingerprint after successful import**

In the `importDives` method (around line 278, after `await _repository.updateLastDownload(computer.id);`), add:

```dart
      // Persist the newest fingerprint for incremental downloads.
      final newestFingerprint = selectNewestFingerprint(result.importedDives);
      if (newestFingerprint != null) {
        await _repository.updateLastFingerprint(computer.id, newestFingerprint);
      }
```

- [ ] **Step 4: Verify compilation**

Run: `dart analyze lib/features/dive_computer/presentation/providers/download_providers.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_computer/presentation/providers/download_providers.dart
git commit -m "feat: wire fingerprint logic into DownloadNotifier for incremental download"
```

### Task 11: Add UI toggle and completion messages to DeviceDownloadPage

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_download_page.dart`

- [ ] **Step 1: Add "Download new dives only" toggle**

In `_buildContent` method (around line 298), add a toggle before the download content. After the scanning and error phases but before the download content section, when the download hasn't started yet and the computer has a fingerprint, show the toggle.

The best place is in `_buildDownloadContent` at the top of the column (before the progress indicator, around line 414). Add a conditional toggle widget:

```dart
          // Incremental download toggle (only when computer has a fingerprint)
          if (_computer?.lastDiveFingerprint != null &&
              !state.isDownloading &&
              !state.isComplete &&
              !state.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SwitchListTile(
                title: Text(
                  'Download new dives only',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  'Only downloads dives added since your last sync',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                value: state.newDivesOnly,
                onChanged: (value) {
                  ref
                      .read(downloadNotifierProvider.notifier)
                      .setNewDivesOnly(value);
                },
              ),
            ),
```

- [ ] **Step 2: Update completion messaging**

In `_buildImportResults` method (around line 694), update to show contextual messages. Add before the existing content, when import result shows 0 imported and 0 skipped (no new dives):

```dart
    // Show "up to date" message when incremental download finds nothing new
    if (result.imported == 0 && result.skipped == 0 && result.updated == 0) {
      return Card(
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No new dives found -- your log is up to date',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }
```

Note: This replaces the existing `SizedBox.shrink()` return when all counts are 0.

- [ ] **Step 3: Update status text for incremental context**

In `_statusText` (line 525), update to show "N new dives" during import when in incremental mode:

```dart
  String _statusText(BuildContext context, DownloadState state) {
    if (state.phase == DownloadPhase.processing) {
      final count = state.downloadedDives.length;
      if (state.newDivesOnly && count > 0) {
        return 'Importing $count new dives...';
      }
      return 'Importing $count dives...';
    }
    return state.progress?.status ??
        context.l10n.diveComputer_download_preparing;
  }
```

- [ ] **Step 4: Verify compilation**

Run: `dart analyze lib/features/dive_computer/presentation/pages/device_download_page.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_computer/presentation/pages/device_download_page.dart
git commit -m "feat: add incremental download toggle and completion messages to download page"
```

### Task 12: Handle zero-dive download completion

**Files:**
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart`

- [ ] **Step 1: Update _persistDeviceInfoAndImport for zero-dive case**

In `_persistDeviceInfoAndImport` (line 230), the existing code skips import if `downloadedDives.isEmpty`. For incremental downloads, this is the expected "up to date" case. Update to set a meaningful import result:

Change:

```dart
      // Auto-import dives if any were downloaded.
      if (state.downloadedDives.isNotEmpty) {
        await importDives(
          computer: _autoImportComputer!,
          mode: ImportMode.newOnly,
          defaultResolution: ConflictResolution.skip,
          diverId: _autoImportDiverId,
        );
      }
```

to:

```dart
      // Auto-import dives if any were downloaded.
      if (state.downloadedDives.isNotEmpty) {
        await importDives(
          computer: _autoImportComputer!,
          mode: ImportMode.newOnly,
          defaultResolution: ConflictResolution.skip,
          diverId: _autoImportDiverId,
        );
      } else {
        // Zero new dives (incremental download found nothing new).
        // Set an empty import result so the UI can show "up to date".
        state = state.copyWith(
          importResult: ImportResult.success(
            imported: 0,
            skipped: 0,
            updated: 0,
            importedDiveIds: [],
            importedDives: [],
          ),
        );
      }
```

- [ ] **Step 2: Verify compilation**

Run: `dart analyze lib/features/dive_computer/presentation/providers/download_providers.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_computer/presentation/providers/download_providers.dart
git commit -m "feat: handle zero-dive incremental download with up-to-date message"
```

### Task 13: Format and analyze all changed code

**Files:**
- All modified files

- [ ] **Step 1: Format all Dart code**

Run: `dart format lib/ test/ packages/libdivecomputer_plugin/lib/ packages/libdivecomputer_plugin/pigeons/`
Expected: All files formatted

- [ ] **Step 2: Run full analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Run existing tests**

Run: `flutter test`
Expected: All existing tests pass (no regressions)

- [ ] **Step 4: Commit any formatting changes**

```bash
git add -A
git commit -m "chore: format code for incremental dive download feature"
```

---

## Chunk 4: Integration Testing

### Task 14: Write DownloadNotifier fingerprint integration tests

**Files:**
- Create: `test/features/dive_computer/presentation/providers/download_notifier_fingerprint_test.dart`

- [ ] **Step 1: Write integration tests for fingerprint logic**

Create `test/features/dive_computer/presentation/providers/download_notifier_fingerprint_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

@GenerateMocks([
  DiveComputerRepository,
  DiveImportService,
  pigeon.DiveComputerService,
])
import 'download_notifier_fingerprint_test.mocks.dart';

void main() {
  late MockDiveComputerRepository mockRepository;
  late MockDiveImportService mockImportService;
  late MockDiveComputerService mockService;
  late DownloadNotifier notifier;

  setUp(() {
    mockRepository = MockDiveComputerRepository();
    mockImportService = MockDiveImportService();
    mockService = MockDiveComputerService();

    when(mockService.downloadEvents)
        .thenAnswer((_) => const Stream.empty());

    notifier = DownloadNotifier(
      service: mockService,
      importService: mockImportService,
      repository: mockRepository,
    );
  });

  tearDown(() {
    notifier.dispose();
  });

  group('fingerprint logic in startDownload', () {
    final testDevice = pigeon.DiscoveredDevice(
      vendor: 'Shearwater',
      product: 'Perdix',
      model: 1,
      address: '00:11:22:33:44:55',
      transport: pigeon.TransportType.ble,
    );

    // Note: We cannot easily verify the fingerprint parameter passed
    // to _service.startDownload because it calls device.toPigeon() which
    // is an extension method. Instead we verify the broader flow.

    test('newDivesOnly defaults to true', () {
      expect(notifier.state.newDivesOnly, isTrue);
    });

    test('setNewDivesOnly updates state', () {
      notifier.setNewDivesOnly(false);
      expect(notifier.state.newDivesOnly, isFalse);

      notifier.setNewDivesOnly(true);
      expect(notifier.state.newDivesOnly, isTrue);
    });
  });

  group('fingerprint persistence after import', () {
    test('updateLastFingerprint is called after successful import', () async {
      final computer = DiveComputer(
        id: 'comp-1',
        name: 'Test Computer',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final importedDives = [
        DownloadedDive(
          startTime: DateTime(2026, 3, 1, 10, 0),
          durationSeconds: 3600,
          maxDepth: 20.0,
          profile: [],
          fingerprint: 'abc123',
        ),
        DownloadedDive(
          startTime: DateTime(2026, 3, 2, 14, 0),
          durationSeconds: 2400,
          maxDepth: 25.0,
          profile: [],
          fingerprint: 'def456',
        ),
      ];

      when(mockImportService.importDives(
        dives: anyNamed('dives'),
        computer: anyNamed('computer'),
        mode: anyNamed('mode'),
        defaultResolution: anyNamed('defaultResolution'),
        diverId: anyNamed('diverId'),
      )).thenAnswer((_) async => ImportResult.success(
        imported: 2,
        skipped: 0,
        updated: 0,
        importedDiveIds: ['d1', 'd2'],
        importedDives: importedDives,
      ));

      when(mockRepository.incrementDiveCount(any, by: anyNamed('by')))
          .thenAnswer((_) async {});
      when(mockRepository.updateLastDownload(any))
          .thenAnswer((_) async {});
      when(mockRepository.updateLastFingerprint(any, any))
          .thenAnswer((_) async {});

      // Simulate having downloaded dives in state
      // We call importDives directly since we can't easily mock the
      // native download stream
      await notifier.importDives(computer: computer);

      // Verify newest fingerprint was persisted (def456 is from March 2)
      verify(mockRepository.updateLastFingerprint('comp-1', 'def456'))
          .called(1);
    });

    test('updateLastFingerprint is NOT called when import fails', () async {
      final computer = DiveComputer(
        id: 'comp-1',
        name: 'Test Computer',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      when(mockImportService.importDives(
        dives: anyNamed('dives'),
        computer: anyNamed('computer'),
        mode: anyNamed('mode'),
        defaultResolution: anyNamed('defaultResolution'),
        diverId: anyNamed('diverId'),
      )).thenThrow(Exception('Database error'));

      await notifier.importDives(computer: computer);

      verifyNever(mockRepository.updateLastFingerprint(any, any));
    });

    test('updateLastFingerprint is NOT called when no dives have fingerprints', () async {
      final computer = DiveComputer(
        id: 'comp-1',
        name: 'Test Computer',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      when(mockImportService.importDives(
        dives: anyNamed('dives'),
        computer: anyNamed('computer'),
        mode: anyNamed('mode'),
        defaultResolution: anyNamed('defaultResolution'),
        diverId: anyNamed('diverId'),
      )).thenAnswer((_) async => ImportResult.success(
        imported: 1,
        skipped: 0,
        updated: 0,
        importedDiveIds: ['d1'],
        importedDives: [
          DownloadedDive(
            startTime: DateTime(2026, 3, 1),
            durationSeconds: 3600,
            maxDepth: 20.0,
            profile: [],
            // no fingerprint
          ),
        ],
      ));

      when(mockRepository.incrementDiveCount(any, by: anyNamed('by')))
          .thenAnswer((_) async {});
      when(mockRepository.updateLastDownload(any))
          .thenAnswer((_) async {});

      await notifier.importDives(computer: computer);

      verifyNever(mockRepository.updateLastFingerprint(any, any));
    });
  });
}
```

- [ ] **Step 2: Generate mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/dive_computer/presentation/providers/download_notifier_fingerprint_test.dart`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add test/features/dive_computer/presentation/providers/download_notifier_fingerprint_test.dart test/features/dive_computer/presentation/providers/download_notifier_fingerprint_test.mocks.dart
git commit -m "test: add integration tests for fingerprint persistence in DownloadNotifier"
```

### Task 15: Final verification

- [ ] **Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 2: Run format check**

Run: `dart format --set-exit-if-changed lib/ test/`
Expected: No formatting changes needed

- [ ] **Step 3: Run full analysis**

Run: `flutter analyze`
Expected: No errors or warnings

- [ ] **Step 4: Final commit if any remaining changes**

```bash
git status
# If any unstaged changes:
git add -A
git commit -m "chore: final cleanup for incremental dive download feature"
```
