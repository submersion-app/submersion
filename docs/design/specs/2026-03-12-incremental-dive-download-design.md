# Incremental Dive Download

## Problem

When downloading dives from a dive computer, Submersion currently downloads every dive stored on the device. Dive computers can store hundreds of dives, making each download slow and wasteful when the user only needs the latest few. Other dive log applications (Subsurface, MacDive) solve this by tracking which dives have already been synced and only downloading new ones.

## Solution

Use libdivecomputer's built-in fingerprint mechanism to implement incremental downloads. After each successful import, store the newest dive's fingerprint on the `DiveComputer` record. On subsequent downloads, pass that fingerprint to the native layer so libdivecomputer stops downloading once it reaches a known dive.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Fingerprint storage location | `DiveComputers` table | Simplest option; aligns with existing `lastDownloadTimestamp` pattern |
| Which fingerprint to store | Newest dive by date | Acts as a "high water mark" for libdivecomputer's reverse-chronological download |
| When to persist fingerprint | After successful import | Conservative: avoids silently skipping dives if import fails or is cancelled |
| Transport format | Hex-encoded string | Pigeon handles strings cleanly across all platforms; avoids raw byte array complexity |
| Full download option | User-facing toggle | Recovery path if fingerprint is stale or user wants to re-sync everything |

## Architecture

### 1. Data Layer

#### Schema Migration

Add a nullable text column to the `DiveComputers` table:

```sql
DiveComputers table:
  ... existing columns ...
  + lastDiveFingerprint  TEXT  nullable
```

#### Domain Entity

Add `lastDiveFingerprint` (String?) to the `DiveComputer` entity with `copyWith` support and `Equatable` props.

#### Repository

Add method to `DiveComputerRepository`:

```dart
Future<void> updateLastFingerprint(String computerId, String fingerprint);
```

Called after successful import with the newest dive's fingerprint from the imported batch.

#### Fingerprint Selection Logic

From a batch of **successfully imported** dives, select the fingerprint of the dive with the most recent `startTime`. This is a pure top-level function (not a class method):

```dart
String? selectNewestFingerprint(List<DownloadedDive> dives);
```

Returns null if the list is empty or no dives have fingerprints.

**Important:** This function must operate on `importResult.importedDives` (the successfully persisted subset), NOT on the full `state.downloadedDives` list. If a partial import fails on some dives, we must not store a fingerprint for a dive that was never persisted -- that would cause it to be silently skipped on the next download.

### 2. Pigeon API & Native Bridge

#### Pigeon Definition Change

```dart
@HostApi()
abstract class DiveComputerHostApi {
  @async
  void startDownload(
    DiscoveredDevice device,
    String? fingerprint,  // hex-encoded, null = download all
  );
}
```

#### Native Platform Changes

Each platform implementation receives the optional fingerprint and passes it to `libdc_download_run()`:

**iOS/macOS (Swift):**
- Receive `fingerprint: String?` from Pigeon-generated method signature
- If non-null: decode hex string to `[UInt8]`, pass pointer and count to `libdc_download_run()`
- If null: pass `nil, 0` (existing behavior)

**Android (Kotlin + JNI):**

Three layers must be updated on Android:

1. `DiveComputerHostApiImpl.kt` `performDownload()`: receive `fingerprint: String?` from Pigeon, decode hex to `ByteArray?`
2. `LibdcWrapper.nativeDownloadRun()` Kotlin external declaration: add `fingerprint: ByteArray?` parameter
3. `libdc_jni.cpp` JNI function `Java_..._nativeDownloadRun`: accept `jbyteArray fingerprint`, convert to `unsigned char*` + size, pass to `libdc_download_run()`

If fingerprint is null at any layer: pass `null/nil, 0` (existing behavior).

**Windows/Linux:**
- Same pattern as above, adapted to the platform's native bridge

### 3. Download Flow & State Management

#### DownloadNotifier Changes

`DownloadState` already has a `newDivesOnly` field (default `true`) and `DownloadNotifier` already has a `setNewDivesOnly()` method. Rather than adding a conflicting `downloadAll` parameter, repurpose `newDivesOnly` to drive the fingerprint decision. No new parameter on `startDownload()` is needed.

**Flow:**

1. Determine fingerprint to send:
   - If `state.newDivesOnly == false` -> fingerprint = null (user toggled "Download all")
   - Else if `computer?.lastDiveFingerprint != null` -> fingerprint = computer.lastDiveFingerprint
   - Else -> fingerprint = null (first-time download, no stored fingerprint)
2. Call native `startDownload(device, fingerprint)` via `DiveComputerService`
3. Native `libdc_download_run()` stops at fingerprint match (or downloads all if null)
4. Dives arrive via stream events (unchanged)
5. On `DownloadCompleteEvent`, trigger auto-import (unchanged)
6. After successful import:
   - Select newest fingerprint from `importResult.importedDives` via `selectNewestFingerprint()`
   - Call `diveComputerRepository.updateLastFingerprint(computerId, fingerprint)`
7. If import fails or is cancelled: fingerprint is NOT updated

**Both UI flows share this code path.** `DownloadNotifier._persistDeviceInfoAndImport()` is called by both `DeviceDownloadPage` and `DeviceDiscoveryPage`. The fingerprint persistence logic lives here, so the first-time discovery wizard download will also store the fingerprint after its initial successful import. On discovery, `_autoImportComputer` is set during `_persistDeviceInfoAndImport()` (the computer is created/updated as part of that method), so the computer ID is available for `updateLastFingerprint()`.

**Edge Cases:**

- **First-time download:** `lastDiveFingerprint` is null, all dives downloaded. Fingerprint stored after first successful import.
- **Computer memory reset:** Stored fingerprint won't match any dive. libdivecomputer handles this gracefully by downloading all dives (same as null fingerprint). Fingerprint is then updated to the new newest dive.
- **Zero new dives:** libdivecomputer's first dive matches the fingerprint, returns immediately with 0 dives. No fingerprint update needed (it's already current).

### 4. UI Changes

#### DeviceDownloadPage

- Wire the existing `newDivesOnly` toggle to `DownloadNotifier.setNewDivesOnly()` with label "Download new dives only" and subtitle: "Only downloads dives added since your last sync"
- Default: on (incremental)
- Hidden/disabled when `lastDiveFingerprint` is null (full download happens regardless)

#### DeviceDiscoveryPage

No UI changes. First-time setup always downloads all dives (no stored fingerprint). Fingerprint persistence happens automatically via the shared `DownloadNotifier._persistDeviceInfoAndImport()` code path after the first successful import.

#### Download Completion Messaging

- **Incremental download with results:** "N new dives downloaded"
- **Incremental download with no results:** "No new dives found -- your log is up to date"
- **Full download:** Existing behavior (shows total count)

### 5. Testing Strategy

#### Unit Tests

- **`selectNewestFingerprint()`** -- given dives with various dates and fingerprints, verify the newest dive's fingerprint is selected. Edge cases: empty list, dives without fingerprints, dives with same date.
- **DownloadNotifier** -- verify fingerprint is passed when available, null when `newDivesOnly` is false, null when no stored fingerprint exists.
- **DiveComputer entity** -- `copyWith` with `lastDiveFingerprint`, Equatable props include the new field.
- **Repository** -- `updateLastFingerprint()` persists correctly, retrieved on next load.

#### Integration Tests

- **Full incremental flow** -- save a computer with a fingerprint, start download, verify fingerprint is passed through to the Pigeon call.
- **Full download override** -- same setup but with `newDivesOnly: false`, verify null is passed to native.
- **Fingerprint persistence after import** -- download completes, import succeeds, verify computer record updated with newest fingerprint.
- **Import failure safety** -- download completes, import fails, verify fingerprint is NOT updated (critical safety test).
- **Zero new dives** -- stored fingerprint matches newest dive, no dives returned, verify "up to date" message displayed.

#### Out of Scope for Testing

- libdivecomputer's internal fingerprint matching -- library responsibility
- Hex encoding/decoding on native platforms -- straightforward utility

## Files Affected

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | Add `lastDiveFingerprint` column to `DiveComputers` table, bump schema version |
| `lib/features/dive_log/domain/entities/dive_computer.dart` | Add `lastDiveFingerprint` field |
| `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | Add `updateLastFingerprint()`, update mapping |
| `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` | Add `fingerprint` param to `startDownload()` |
| `packages/libdivecomputer_plugin/lib/src/dive_computer_service.dart` | Add `fingerprint` param to `startDownload()`, forward to `_hostApi` |
| `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` | Decode hex fingerprint, pass to `libdc_download_run()` |
| `packages/libdivecomputer_plugin/android/src/main/kotlin/.../DiveComputerHostApiImpl.kt` | Decode hex fingerprint, pass to `nativeDownloadRun()` |
| `packages/libdivecomputer_plugin/android/src/main/kotlin/.../LibdcWrapper.kt` | Add `fingerprint: ByteArray?` param to `nativeDownloadRun()` external declaration |
| `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` | Accept `jbyteArray` fingerprint, convert and pass to `libdc_download_run()` |
| `lib/features/dive_computer/presentation/providers/download_providers.dart` | Fingerprint logic in `startDownload()`, persist after import in `_persistDeviceInfoAndImport()` |
| `lib/features/dive_computer/presentation/pages/device_download_page.dart` | Wire `newDivesOnly` toggle, completion messages |
| `lib/features/dive_computer/data/services/fingerprint_utils.dart` | New file: top-level `selectNewestFingerprint()` pure function |

**Pigeon codegen note:** Changing the `startDownload()` signature in `dive_computer_api.dart` requires re-running `flutter pub run pigeon`. This regenerates platform-specific files for all 5 targets (iOS, macOS, Android, Windows, Linux) plus the Dart bindings. All output paths are defined in the `@ConfigurePigeon` annotation at the top of that file.

## Dependencies

- No new packages required
- libdivecomputer already supports fingerprint-based selective download
- Pigeon code generation must be re-run after API changes
