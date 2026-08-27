# Raw Dive Data Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store raw per-dive bytes from dive computer downloads in the database so future parser improvements can be applied retroactively without re-downloading.

**Architecture:** Add BLOB columns to `DiveDataSources` for raw bytes and device descriptor. Capture raw bytes in native `dive_callback`, pass through Pigeon/Dart layers to persistence. Add `replaceSource` conflict resolution for backfill. Add manual re-parse from DC detail page and dive detail page, using a shared `applyParsedUpdate` function that enforces a computer-authored-fields allowlist.

**Tech Stack:** Flutter/Dart, Drift ORM, Pigeon (platform channels), C (libdivecomputer native), Swift (Darwin), Kotlin (Android), C++ (Windows), GObject/C (Linux), Riverpod (state management)

**Spec:** `docs/superpowers/specs/2026-04-15-raw-dive-data-storage-design.md`

---

## File Structure

### New files

| File | Responsibility |
|------|---------------|
| `lib/features/dive_computer/data/services/reparse_service.dart` | Re-parse orchestration: single-dive, batch-by-computer, shared `applyParsedUpdate` |
| `lib/features/dive_computer/presentation/providers/reparse_providers.dart` | Riverpod providers for re-parse state and actions |
| `test/features/dive_computer/data/services/reparse_service_test.dart` | Unit tests for re-parse logic and allowlist enforcement |
| `test/features/dive_computer/data/services/raw_data_persistence_test.dart` | Tests for blob round-trip, FK setNull, replaceSource |

### Modified files

| File | Change |
|------|--------|
| `lib/core/database/database.dart` | Schema: 7 new columns on `DiveDataSources`, FK change, migration v66 |
| `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` | Add `rawData`, `rawFingerprint` to `ParsedDive` |
| `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` | Add `raw_data`, `raw_data_size`, `raw_fingerprint`, `raw_fingerprint_size` to `libdc_parsed_dive_t` |
| `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c` | Retain raw pointers in `dive_callback` |
| `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` | Copy raw bytes into `ParsedDive` in `convertParsedDive` |
| `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt` | Copy raw bytes in `convertParsedDive` |
| `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` | Expose raw data fields via JNI |
| `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc` | Copy raw bytes in `convert_parsed_dive` |
| `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc` | Copy raw bytes in `ConvertParsedDive` |
| `lib/features/dive_computer/domain/entities/downloaded_dive.dart` | Add `rawData`, `rawFingerprint` fields to `DownloadedDive` |
| `lib/features/dive_computer/data/services/parsed_dive_mapper.dart` | Map `rawData`/`rawFingerprint` from `ParsedDive` to `DownloadedDive` |
| `lib/features/dive_computer/data/services/dive_import_service.dart` | Rename `replace` -> `replaceSource`, flesh out `_updateExistingDive` |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Add `applyParsedUpdate`, `getRawDataCount`, blob persistence methods |
| `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` | Pass raw bytes + session descriptor through import flow |
| `lib/features/import_wizard/domain/models/duplicate_action.dart` | Add `DuplicateAction.replaceSource` enum value |
| `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart` | Render `replaceSource` badge conditionally |
| `lib/features/dive_computer/presentation/pages/device_detail_page.dart` | Add "Re-parse all dives" button |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Add "Re-parse raw data" overflow menu item |

---

## Task 1: Database Schema Migration

**Files:**
- Modify: `lib/core/database/database.dart:948-979` (DiveDataSources table)
- Modify: `lib/core/database/database.dart:1312` (schema version)
- Modify: `lib/core/database/database.dart:1317-1381` (migrationVersions list)
- Modify: `lib/core/database/database.dart:3049` (after last migration block)

- [ ] **Step 1: Add new columns to `DiveDataSources` table definition**

In `lib/core/database/database.dart`, inside the `DiveDataSources` class (after line 975, before the `@override` primaryKey line):

```dart
  BlobColumn get rawData => blob().nullable()();
  BlobColumn get rawFingerprint => blob().nullable()();
  TextColumn get descriptorVendor => text().nullable()();
  TextColumn get descriptorProduct => text().nullable()();
  IntColumn get descriptorModel => integer().nullable()();
  TextColumn get libdivecomputerVersion => text().nullable()();
  DateTimeColumn get lastParsedAt => dateTime().nullable()();
```

- [ ] **Step 2: Change FK on `computerId` to add `onDelete: setNull`**

In `lib/core/database/database.dart`, replace the `computerId` column definition in `DiveDataSources` (line ~952):

```dart
  TextColumn get computerId =>
      text().nullable().references(DiveComputers, #id, onDelete: KeyAction.setNull)();
```

- [ ] **Step 3: Increment schema version and add migration**

Change `currentSchemaVersion` from `65` to `66` (line 1312).

Append `66` to the `migrationVersions` list (after line 1381, before `];`).

Add migration block after line 3049 (before `beforeOpen`):

```dart
        if (from < 66) {
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN raw_data BLOB',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN raw_fingerprint BLOB',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN descriptor_vendor TEXT',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN descriptor_product TEXT',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN descriptor_model INTEGER',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN libdivecomputer_version TEXT',
          );
          await customStatement(
            'ALTER TABLE dive_data_sources ADD COLUMN last_parsed_at INTEGER',
          );
        }
        if (from < 66) await reportProgress();
```

Note: The FK `onDelete: setNull` change on `computerId` takes effect for new databases created via `onCreate`. For existing databases, SQLite does not support `ALTER TABLE ... ALTER COLUMN` to change FK constraints — the existing constraint behavior is preserved. This is acceptable because Drift uses `PRAGMA foreign_keys = ON` which enforces the constraint as defined at table creation time, and existing installations already have the FK with default `NO ACTION`. A full table rebuild migration can be added later if needed.

- [ ] **Step 4: Run Drift code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`

Expected: Clean build producing updated `database.g.dart` with new `DiveDataSourcesData` fields.

- [ ] **Step 5: Verify generated code compiles**

Run: `flutter analyze lib/core/database/`

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat(db): add raw data columns to DiveDataSources (schema v66)

Add rawData, rawFingerprint, descriptorVendor, descriptorProduct,
descriptorModel, libdivecomputerVersion, lastParsedAt columns for
storing raw dive computer bytes. All nullable for backwards compat."
```

---

## Task 2: Pigeon API — Add Raw Data Fields

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart:119-166`

- [ ] **Step 1: Add `rawData` and `rawFingerprint` to `ParsedDive`**

In `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`, add two fields to the `ParsedDive` constructor and class body (after `decoConservatism`, before the closing `}`):

```dart
class ParsedDive {
  const ParsedDive({
    // ... existing params ...
    this.decoConservatism,
    this.rawData,
    this.rawFingerprint,
  });
  // ... existing fields ...
  final int? decoConservatism;
  final Uint8List? rawData;
  final Uint8List? rawFingerprint;
}
```

- [ ] **Step 2: Run Pigeon code generation**

Run: `cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart`

Expected: Regenerated files in:
- `lib/src/generated/dive_computer_api.g.dart`
- `ios/Classes/DiveComputerApi.g.swift`
- `android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerApi.g.kt`
- `linux/dive_computer_api.g.h` and `.g.cc`
- `windows/dive_computer_api.g.h` and `.g.cc`

- [ ] **Step 3: Verify Pigeon-generated code compiles**

Run: `cd packages/libdivecomputer_plugin && flutter analyze lib/`

Expected: No errors (the new fields are nullable, so all existing call sites remain valid — they pass `null` by default).

- [ ] **Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/pigeons/ packages/libdivecomputer_plugin/lib/src/generated/ packages/libdivecomputer_plugin/ios/ packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerApi.g.kt packages/libdivecomputer_plugin/linux/dive_computer_api.g.h packages/libdivecomputer_plugin/linux/dive_computer_api.g.cc packages/libdivecomputer_plugin/windows/dive_computer_api.g.h packages/libdivecomputer_plugin/windows/dive_computer_api.g.cc
git commit -m "feat(plugin): add rawData/rawFingerprint to ParsedDive Pigeon API"
```

---

## Task 3: Native C — Retain Raw Bytes in Struct and Callback

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h:177-216`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c:358-380`

- [ ] **Step 1: Add raw data fields to `libdc_parsed_dive_t`**

In `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h`, add four fields at the end of the `libdc_parsed_dive_t` struct (before the closing `}`):

```c
    // Raw dive data for archival (not malloc'd — valid only during callback)
    const unsigned char *raw_data;
    unsigned int raw_data_size;
    const unsigned char *raw_fingerprint;
    unsigned int raw_fingerprint_size;
} libdc_parsed_dive_t;
```

- [ ] **Step 2: Initialize raw fields in `parse_dive`**

In `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c`, at the start of the `parse_dive` function (around line 200), after the existing `memset` or initialization of the dive struct, ensure the raw fields are zeroed:

```c
dive->raw_data = NULL;
dive->raw_data_size = 0;
dive->raw_fingerprint = NULL;
dive->raw_fingerprint_size = 0;
```

- [ ] **Step 3: Retain raw bytes in `dive_callback`**

In `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c`, in the `dive_callback` function (line 358-380), after `parse_dive` succeeds and before `state->callbacks->on_dive`, set the raw pointers:

```c
static int dive_callback(const unsigned char *data, unsigned int size,
                          const unsigned char *fingerprint, unsigned int fsize,
                          void *userdata) {
    download_state_t *state = (download_state_t *)userdata;

    if (state->session->cancelled) {
        return 0;
    }

    libdc_parsed_dive_t dive;
    if (parse_dive(state, data, size, fingerprint, fsize, &dive) == 0) {
        // Retain raw bytes for archival (pointers valid for this callback scope)
        dive.raw_data = data;
        dive.raw_data_size = size;
        dive.raw_fingerprint = fingerprint;
        dive.raw_fingerprint_size = fsize;

        if (state->callbacks->on_dive != NULL) {
            state->callbacks->on_dive(&dive, state->callbacks->userdata);
        }
        state->dive_count++;
    }

    // Free dynamically allocated data.
    free(dive.samples);
    free(dive.events);

    return 1;  // continue
}
```

- [ ] **Step 4: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h packages/libdivecomputer_plugin/macos/Classes/libdc_download.c
git commit -m "feat(native): retain raw dive bytes in libdc_parsed_dive_t

Add raw_data/raw_fingerprint pointer fields to the parsed dive struct.
Set in dive_callback after parse_dive succeeds. Pointers borrow from
libdivecomputer's callback scope — platform wrappers copy before return."
```

---

## Task 4: Platform Wrappers — Copy Raw Bytes to Pigeon ParsedDive

**Files:**
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift:423-559`
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt:279`
- Modify: `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc:189`
- Modify: `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc`

- [ ] **Step 1: Swift (Darwin) — copy raw bytes in `convertParsedDive`**

In `DiveComputerHostApiImpl.swift`, at the end of `convertParsedDive` (before the `return ParsedDive(...)` call), create the byte arrays:

```swift
let rawData: FlutterStandardTypedData?
if dive.raw_data != nil && dive.raw_data_size > 0 {
    rawData = FlutterStandardTypedData(bytes: Data(bytes: dive.raw_data, count: Int(dive.raw_data_size)))
} else {
    rawData = nil
}

let rawFingerprint: FlutterStandardTypedData?
if dive.raw_fingerprint != nil && dive.raw_fingerprint_size > 0 {
    rawFingerprint = FlutterStandardTypedData(bytes: Data(bytes: dive.raw_fingerprint, count: Int(dive.raw_fingerprint_size)))
} else {
    rawFingerprint = nil
}
```

Then pass `rawData: rawData, rawFingerprint: rawFingerprint` to the `ParsedDive` constructor.

- [ ] **Step 2: Android (JNI) — expose raw data fields**

In `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp`, add JNI functions to extract `raw_data` and `raw_fingerprint` from the `libdc_parsed_dive_t` pointer, returning `jbyteArray`. Follow the existing pattern used for fingerprint/sample extraction.

- [ ] **Step 3: Android (Kotlin) — copy raw bytes in `convertParsedDive`**

In `DiveComputerHostApiImpl.kt`, in `convertParsedDive` (line 279+), after the existing field extraction, add:

```kotlin
val rawData = LibdcWrapper.nativeGetDiveRawData(divePtr)
val rawFingerprint = LibdcWrapper.nativeGetDiveRawFingerprint(divePtr)
```

Pass these to the `ParsedDive` constructor.

- [ ] **Step 4: Linux (GObject) — copy raw bytes in `convert_parsed_dive`**

In `packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc`, in the `convert_parsed_dive` function, after existing field assignments, add:

```c
if (dive->raw_data != NULL && dive->raw_data_size > 0) {
    libdivecomputer_plugin_parsed_dive_set_raw_data(
        parsed, dive->raw_data, dive->raw_data_size);
}
if (dive->raw_fingerprint != NULL && dive->raw_fingerprint_size > 0) {
    libdivecomputer_plugin_parsed_dive_set_raw_fingerprint(
        parsed, dive->raw_fingerprint, dive->raw_fingerprint_size);
}
```

The setter functions are generated by Pigeon and accept `(obj, data, length)`.

- [ ] **Step 5: Windows (C++) — copy raw bytes in `ConvertParsedDive`**

In `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc`, in the `ConvertParsedDive` function, add:

```cpp
if (dive->raw_data != nullptr && dive->raw_data_size > 0) {
    parsed.set_raw_data(std::vector<uint8_t>(
        dive->raw_data, dive->raw_data + dive->raw_data_size));
}
if (dive->raw_fingerprint != nullptr && dive->raw_fingerprint_size > 0) {
    parsed.set_raw_fingerprint(std::vector<uint8_t>(
        dive->raw_fingerprint, dive->raw_fingerprint + dive->raw_fingerprint_size));
}
```

- [ ] **Step 6: Build on at least one platform to verify**

Run: `flutter build macos --debug` (or whichever platform is available)

Expected: Clean compile with no native errors.

- [ ] **Step 7: Commit**

```bash
git add packages/libdivecomputer_plugin/darwin/ packages/libdivecomputer_plugin/android/ packages/libdivecomputer_plugin/linux/dive_computer_host_api_impl.cc packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc
git commit -m "feat(native): copy raw dive bytes to Pigeon ParsedDive on all platforms

Swift, Kotlin/JNI, GObject, and C++ wrappers now copy raw_data and
raw_fingerprint byte arrays from the C struct into the Pigeon message."
```

---

## Task 5: Dart Entity and Mapper — Pass Raw Bytes Through

**Files:**
- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart:86-152`
- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart`

- [ ] **Step 1: Add raw data fields to `DownloadedDive`**

In `lib/features/dive_computer/domain/entities/downloaded_dive.dart`, add to the `DownloadedDive` class:

```dart
import 'dart:typed_data';
```

Add fields (after `events`):

```dart
  /// Raw dive data bytes from libdivecomputer (for re-parse)
  final Uint8List? rawData;

  /// Raw fingerprint bytes from libdivecomputer
  final Uint8List? rawFingerprint;
```

Add to constructor (after `this.events = const []`):

```dart
    this.rawData,
    this.rawFingerprint,
```

- [ ] **Step 2: Update `parsed_dive_mapper.dart`**

In `lib/features/dive_computer/data/services/parsed_dive_mapper.dart`, add the new fields to the `parsedDiveToDownloaded` return:

```dart
  return DownloadedDive(
    // ... existing fields ...
    events: parsed.events
        .map(/* existing mapping */)
        .toList(),
    rawData: parsed.rawData,
    rawFingerprint: parsed.rawFingerprint,
  );
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/features/dive_computer/`

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_computer/domain/entities/downloaded_dive.dart lib/features/dive_computer/data/services/parsed_dive_mapper.dart
git commit -m "feat: add rawData/rawFingerprint fields to DownloadedDive entity and mapper"
```

---

## Task 6: Blob Persistence Tests (TDD)

**Files:**
- Create: `test/features/dive_computer/data/services/raw_data_persistence_test.dart`

- [ ] **Step 1: Write failing tests for blob persistence and FK behavior**

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'dart:typed_data';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('DiveDataSources raw data columns', () {
    test('stores and retrieves rawData blob', () async {
      // Create prerequisite rows
      final diverId = 'diver-1';
      await db.into(db.divers).insert(DiversCompanion.insert(
        id: diverId, name: 'Test Diver',
        createdAt: 1000, updatedAt: 1000,
      ));
      final diveId = 'dive-1';
      await db.into(db.dives).insert(DivesCompanion.insert(
        id: Value(diveId), diveDateTime: 1000,
        createdAt: 1000, updatedAt: 1000,
      ));

      final testBlob = Uint8List.fromList([1, 2, 3, 4, 5, 0xFF, 0xFE]);
      final sourceId = 'source-1';

      await db.into(db.diveDataSources).insert(DiveDataSourcesCompanion.insert(
        id: sourceId, diveId: diveId,
        importedAt: DateTime.now(), createdAt: DateTime.now(),
        rawData: Value(testBlob),
        descriptorVendor: const Value('Shearwater'),
        descriptorProduct: const Value('Perdix'),
        descriptorModel: const Value(42),
        libdivecomputerVersion: const Value('0.8.0'),
      ));

      final row = await (db.select(db.diveDataSources)
        ..where((t) => t.id.equals(sourceId))).getSingle();

      expect(row.rawData, equals(testBlob));
      expect(row.descriptorVendor, equals('Shearwater'));
      expect(row.descriptorProduct, equals('Perdix'));
      expect(row.descriptorModel, equals(42));
      expect(row.libdivecomputerVersion, equals('0.8.0'));
    });

    test('rawData is nullable — null by default', () async {
      final diveId = 'dive-2';
      await db.into(db.dives).insert(DivesCompanion.insert(
        id: Value(diveId), diveDateTime: 2000,
        createdAt: 2000, updatedAt: 2000,
      ));

      await db.into(db.diveDataSources).insert(DiveDataSourcesCompanion.insert(
        id: 'source-2', diveId: diveId,
        importedAt: DateTime.now(), createdAt: DateTime.now(),
      ));

      final row = await (db.select(db.diveDataSources)
        ..where((t) => t.id.equals('source-2'))).getSingle();

      expect(row.rawData, isNull);
      expect(row.descriptorVendor, isNull);
    });

    test('FK setNull: deleting computer sets computerId to null', () async {
      final computerId = 'comp-1';
      await db.into(db.diveComputers).insert(DiveComputersCompanion.insert(
        id: computerId, name: 'Test DC',
        createdAt: 1000, updatedAt: 1000,
      ));

      final diveId = 'dive-3';
      await db.into(db.dives).insert(DivesCompanion.insert(
        id: Value(diveId), diveDateTime: 3000,
        createdAt: 3000, updatedAt: 3000,
      ));

      final testBlob = Uint8List.fromList([10, 20, 30]);
      await db.into(db.diveDataSources).insert(DiveDataSourcesCompanion.insert(
        id: 'source-3', diveId: diveId,
        computerId: Value(computerId),
        importedAt: DateTime.now(), createdAt: DateTime.now(),
        rawData: Value(testBlob),
      ));

      // Delete the computer
      await (db.delete(db.diveComputers)
        ..where((t) => t.id.equals(computerId))).go();

      // Source row should survive with null computerId
      final row = await (db.select(db.diveDataSources)
        ..where((t) => t.id.equals('source-3'))).getSingle();

      expect(row.computerId, isNull);
      expect(row.rawData, equals(testBlob));
    });

    test('cascade delete: deleting dive removes data source', () async {
      final diveId = 'dive-4';
      await db.into(db.dives).insert(DivesCompanion.insert(
        id: Value(diveId), diveDateTime: 4000,
        createdAt: 4000, updatedAt: 4000,
      ));

      await db.into(db.diveDataSources).insert(DiveDataSourcesCompanion.insert(
        id: 'source-4', diveId: diveId,
        importedAt: DateTime.now(), createdAt: DateTime.now(),
        rawData: Value(Uint8List.fromList([1, 2, 3])),
      ));

      await (db.delete(db.dives)..where((t) => t.id.equals(diveId))).go();

      final rows = await (db.select(db.diveDataSources)
        ..where((t) => t.id.equals('source-4'))).get();

      expect(rows, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail (schema not yet generated)**

Run: `flutter test test/features/dive_computer/data/services/raw_data_persistence_test.dart`

Expected: FAIL — compilation errors if `rawData` column doesn't exist in generated code yet (if Task 1 codegen hasn't been run), or PASS if Task 1 is already complete.

- [ ] **Step 3: Run tests to verify they pass (after Task 1)**

Run: `flutter test test/features/dive_computer/data/services/raw_data_persistence_test.dart`

Expected: All 4 tests PASS.

Note: The FK setNull test may fail if the existing database schema was created without `onDelete: setNull`. The in-memory database used in tests creates the schema from scratch via `onCreate`, so it will have the new FK constraint. This correctly tests the desired behavior for new installations.

- [ ] **Step 4: Commit**

```bash
git add test/features/dive_computer/data/services/raw_data_persistence_test.dart
git commit -m "test: add blob persistence and FK setNull tests for DiveDataSources"
```

---

## Task 7: Re-parse Service with Allowlist (TDD)

**Files:**
- Create: `lib/features/dive_computer/data/services/reparse_service.dart`
- Create: `test/features/dive_computer/data/services/reparse_service_test.dart`

- [ ] **Step 1: Write failing tests for `applyParsedUpdate` allowlist**

Create `test/features/dive_computer/data/services/reparse_service_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'dart:typed_data';

void main() {
  late AppDatabase db;
  late ReparseService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = ReparseService(db: db);
  });

  tearDown(() => db.close());

  Future<String> insertTestDive({
    String diveId = 'dive-1',
    String? notes = 'User notes',
    double maxDepth = 30.0,
    int diveDateTime = 1000000,
    int? rating = 5,
    String? siteId,
  }) async {
    await db.into(db.dives).insert(DivesCompanion.insert(
      id: Value(diveId),
      diveDateTime: diveDateTime,
      maxDepth: Value(maxDepth),
      avgDepth: const Value(15.0),
      notes: Value(notes ?? ''),
      rating: Value(rating),
      siteId: Value(siteId),
      waterTemp: const Value(22.0),
      diveMode: const Value('oc'),
      createdAt: 1000, updatedAt: 1000,
    ));
    return diveId;
  }

  Future<String> insertTestSource({
    String sourceId = 'source-1',
    String diveId = 'dive-1',
    String? computerId,
    bool isPrimary = true,
    Uint8List? rawData,
  }) async {
    await db.into(db.diveDataSources).insert(DiveDataSourcesCompanion.insert(
      id: sourceId, diveId: diveId,
      computerId: Value(computerId),
      isPrimary: Value(isPrimary),
      importedAt: DateTime.now(), createdAt: DateTime.now(),
      rawData: Value(rawData),
      descriptorVendor: const Value('Shearwater'),
      descriptorProduct: const Value('Perdix'),
      descriptorModel: const Value(42),
    ));
    return sourceId;
  }

  group('applyParsedUpdate allowlist enforcement', () {
    test('overwrites computer-authored fields', () async {
      final diveId = await insertTestDive(maxDepth: 30.0);
      final sourceId = await insertTestSource(diveId: diveId);

      final freshParse = pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeYear: 2026, dateTimeMonth: 4, dateTimeDay: 15,
        dateTimeHour: 10, dateTimeMinute: 30, dateTimeSecond: 0,
        maxDepthMeters: 42.5,
        avgDepthMeters: 21.0,
        durationSeconds: 3600,
        samples: [], tanks: [], gasMixes: [], events: [],
      );

      await service.applyParsedUpdate(
        diveId: diveId,
        sourceRowId: sourceId,
        parsed: freshParse,
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );

      final dive = await (db.select(db.dives)
        ..where((t) => t.id.equals(diveId))).getSingle();

      expect(dive.maxDepth, equals(42.5));
      expect(dive.avgDepth, equals(21.0));
    });

    test('preserves user-authored fields', () async {
      final diveId = await insertTestDive(
        notes: 'My favorite dive!',
        rating: 5,
        siteId: 'site-123',
      );
      final sourceId = await insertTestSource(diveId: diveId);

      final freshParse = pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeYear: 2026, dateTimeMonth: 4, dateTimeDay: 15,
        dateTimeHour: 10, dateTimeMinute: 30, dateTimeSecond: 0,
        maxDepthMeters: 42.5,
        avgDepthMeters: 21.0,
        durationSeconds: 3600,
        samples: [], tanks: [], gasMixes: [], events: [],
      );

      await service.applyParsedUpdate(
        diveId: diveId,
        sourceRowId: sourceId,
        parsed: freshParse,
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );

      final dive = await (db.select(db.dives)
        ..where((t) => t.id.equals(diveId))).getSingle();

      expect(dive.notes, equals('My favorite dive!'));
      expect(dive.rating, equals(5));
      expect(dive.siteId, equals('site-123'));
    });

    test('only updates Dives row when source isPrimary', () async {
      final diveId = await insertTestDive(maxDepth: 30.0);
      final sourceId = await insertTestSource(
        diveId: diveId, isPrimary: false,
      );

      final freshParse = pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeYear: 2026, dateTimeMonth: 4, dateTimeDay: 15,
        dateTimeHour: 10, dateTimeMinute: 30, dateTimeSecond: 0,
        maxDepthMeters: 42.5,
        avgDepthMeters: 21.0,
        durationSeconds: 3600,
        samples: [], tanks: [], gasMixes: [], events: [],
      );

      await service.applyParsedUpdate(
        diveId: diveId,
        sourceRowId: sourceId,
        parsed: freshParse,
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );

      final dive = await (db.select(db.dives)
        ..where((t) => t.id.equals(diveId))).getSingle();

      // maxDepth should NOT be updated because source is not primary
      expect(dive.maxDepth, equals(30.0));
    });

    test('updates DiveDataSources snapshot fields', () async {
      final diveId = await insertTestDive();
      final sourceId = await insertTestSource(diveId: diveId);

      final freshParse = pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeYear: 2026, dateTimeMonth: 4, dateTimeDay: 15,
        dateTimeHour: 10, dateTimeMinute: 30, dateTimeSecond: 0,
        maxDepthMeters: 42.5,
        avgDepthMeters: 21.0,
        durationSeconds: 3600,
        minTemperatureCelsius: 18.0,
        maxTemperatureCelsius: 24.0,
        samples: [], tanks: [], gasMixes: [], events: [],
      );

      await service.applyParsedUpdate(
        diveId: diveId,
        sourceRowId: sourceId,
        parsed: freshParse,
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );

      final source = await (db.select(db.diveDataSources)
        ..where((t) => t.id.equals(sourceId))).getSingle();

      expect(source.maxDepth, equals(42.5));
      expect(source.avgDepth, equals(21.0));
      expect(source.duration, equals(3600));
      expect(source.lastParsedAt, isNotNull);
    });

    test('is idempotent — same result after two runs', () async {
      final diveId = await insertTestDive(notes: 'Keep me');
      final sourceId = await insertTestSource(diveId: diveId);

      final freshParse = pigeon.ParsedDive(
        fingerprint: 'abc123',
        dateTimeYear: 2026, dateTimeMonth: 4, dateTimeDay: 15,
        dateTimeHour: 10, dateTimeMinute: 30, dateTimeSecond: 0,
        maxDepthMeters: 42.5,
        avgDepthMeters: 21.0,
        durationSeconds: 3600,
        samples: [], tanks: [], gasMixes: [], events: [],
      );

      final params = (
        diveId: diveId,
        sourceRowId: sourceId,
        parsed: freshParse,
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );

      await service.applyParsedUpdate(
        diveId: params.diveId, sourceRowId: params.sourceRowId,
        parsed: params.parsed,
        descriptorVendor: params.descriptorVendor,
        descriptorProduct: params.descriptorProduct,
        descriptorModel: params.descriptorModel,
        libdivecomputerVersion: params.libdivecomputerVersion,
      );

      final afterFirst = await (db.select(db.dives)
        ..where((t) => t.id.equals(diveId))).getSingle();

      await service.applyParsedUpdate(
        diveId: params.diveId, sourceRowId: params.sourceRowId,
        parsed: params.parsed,
        descriptorVendor: params.descriptorVendor,
        descriptorProduct: params.descriptorProduct,
        descriptorModel: params.descriptorModel,
        libdivecomputerVersion: params.libdivecomputerVersion,
      );

      final afterSecond = await (db.select(db.dives)
        ..where((t) => t.id.equals(diveId))).getSingle();

      expect(afterSecond.maxDepth, equals(afterFirst.maxDepth));
      expect(afterSecond.notes, equals(afterFirst.notes));
      expect(afterSecond.notes, equals('Keep me'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_computer/data/services/reparse_service_test.dart`

Expected: FAIL — `ReparseService` not found.

- [ ] **Step 3: Implement `ReparseService`**

Create `lib/features/dive_computer/data/services/reparse_service.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/database/database.dart';

class ReparseService {
  final AppDatabase db;

  ReparseService({required this.db});

  /// Computer-authored columns on the Dives table that applyParsedUpdate
  /// is allowed to overwrite. Everything else is user-authored and preserved.
  static const _diveAllowlist = <String>{
    'max_depth',
    'avg_depth',
    'bottom_time',
    'runtime',
    'water_temp',
    'dive_mode',
    'dive_date_time',
    'surface_interval_seconds',
    'cns_end',
    'otu',
    'gradient_factor_low',
    'gradient_factor_high',
    'deco_algorithm',
    'deco_conservatism',
  };

  Future<void> applyParsedUpdate({
    required String diveId,
    required String sourceRowId,
    required pigeon.ParsedDive parsed,
    required String? descriptorVendor,
    required String? descriptorProduct,
    required int? descriptorModel,
    required String? libdivecomputerVersion,
    Uint8List? rawData,
    Uint8List? rawFingerprint,
  }) async {
    await db.transaction(() async {
      // 1. Update DiveDataSources snapshot fields
      final now = DateTime.now();
      await (db.update(db.diveDataSources)
        ..where((t) => t.id.equals(sourceRowId)))
        .write(DiveDataSourcesCompanion(
          maxDepth: Value(parsed.maxDepthMeters),
          avgDepth: Value(parsed.avgDepthMeters != 0 ? parsed.avgDepthMeters : null),
          duration: Value(parsed.durationSeconds),
          waterTemp: Value(parsed.minTemperatureCelsius),
          descriptorVendor: Value(descriptorVendor),
          descriptorProduct: Value(descriptorProduct),
          descriptorModel: Value(descriptorModel),
          libdivecomputerVersion: Value(libdivecomputerVersion),
          lastParsedAt: Value(now),
          importedAt: Value(now),
          rawData: rawData != null ? Value(rawData) : const Value.absent(),
          rawFingerprint: rawFingerprint != null ? Value(rawFingerprint) : const Value.absent(),
          decoAlgorithm: Value(parsed.decoAlgorithm),
          gradientFactorLow: Value(parsed.gfLow),
          gradientFactorHigh: Value(parsed.gfHigh),
        ));

      // 2. Check if source is primary
      final source = await (db.select(db.diveDataSources)
        ..where((t) => t.id.equals(sourceRowId))).getSingle();

      if (source.isPrimary) {
        // 3. Update allowlisted Dives columns
        final entryTime = DateTime.utc(
          parsed.dateTimeYear, parsed.dateTimeMonth, parsed.dateTimeDay,
          parsed.dateTimeHour, parsed.dateTimeMinute, parsed.dateTimeSecond,
        );
        final diveDateTime = entryTime.millisecondsSinceEpoch ~/ 1000;

        await (db.update(db.dives)
          ..where((t) => t.id.equals(diveId)))
          .write(DivesCompanion(
            maxDepth: Value(parsed.maxDepthMeters),
            avgDepth: Value(parsed.avgDepthMeters != 0 ? parsed.avgDepthMeters : null),
            runtime: Value(parsed.durationSeconds),
            diveDateTime: Value(diveDateTime),
            waterTemp: Value(parsed.minTemperatureCelsius),
            diveMode: Value(_mapDiveMode(parsed.diveMode)),
            cnsEnd: Value(null),
            otu: Value(null),
            gradientFactorLow: Value(parsed.gfLow),
            gradientFactorHigh: Value(parsed.gfHigh),
            decoAlgorithm: Value(parsed.decoAlgorithm),
            decoConservatism: Value(parsed.decoConservatism),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          ));
      }

      // 4. Replace DiveProfiles for this source
      final computerId = source.computerId;
      if (computerId != null) {
        await (db.delete(db.diveProfiles)
          ..where((t) => t.diveId.equals(diveId) & t.computerId.equals(computerId)))
          .go();
      } else {
        await (db.delete(db.diveProfiles)
          ..where((t) => t.diveId.equals(diveId) & t.computerId.isNull()))
          .go();
      }

      // Re-insert profile samples from fresh parse
      for (final sample in parsed.samples) {
        await db.into(db.diveProfiles).insert(DiveProfilesCompanion.insert(
          id: _uuid(),
          diveId: diveId,
          computerId: Value(computerId),
          isPrimary: Value(source.isPrimary),
          timestamp: sample.timeSeconds,
          depth: sample.depthMeters,
          temperature: Value(sample.temperatureCelsius),
          heartRate: Value(sample.heartRate),
          setpoint: Value(sample.setpoint),
          ppO2: Value(sample.ppo2),
          cns: Value(sample.cns),
          tts: Value(sample.tts),
          rbt: Value(sample.rbt),
          decoType: Value(sample.decoType),
          ndl: Value(sample.decoType == 0 ? sample.decoTime : null),
          ceiling: Value(sample.decoType != null && sample.decoType != 0
              ? sample.decoDepth : null),
        ));
      }

      // 5. Replace per-dive child tables (no computerId column)
      await (db.delete(db.diveProfileEvents)
        ..where((t) => t.diveId.equals(diveId))).go();
      await (db.delete(db.gasSwitches)
        ..where((t) => t.diveId.equals(diveId))).go();
      await (db.delete(db.tankPressureProfiles)
        ..where((t) => t.diveId.equals(diveId))).go();

      // Re-insert events
      for (final event in parsed.events) {
        await db.into(db.diveProfileEvents).insert(
          DiveProfileEventsCompanion.insert(
            id: _uuid(),
            diveId: diveId,
            timestamp: event.timeSeconds,
            eventType: event.type,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
      }

      // 6. DiveTanks — carry over user fields by tankOrder
      final existingTanks = await (db.select(db.diveTanks)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([(t) => OrderingTerm(expression: t.tankOrder)]))
        .get();

      final existingByOrder = {for (final t in existingTanks) t.tankOrder: t};

      await (db.delete(db.diveTanks)
        ..where((t) => t.diveId.equals(diveId))).go();

      for (final tank in parsed.tanks) {
        final gasMix = parsed.gasMixes.firstWhere(
          (g) => g.index == tank.gasMixIndex,
          orElse: () => pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
        );
        final existing = existingByOrder[tank.index];

        await db.into(db.diveTanks).insert(DiveTanksCompanion.insert(
          id: _uuid(),
          diveId: diveId,
          volume: Value(tank.volumeLiters),
          startPressure: Value(tank.startPressureBar),
          endPressure: Value(tank.endPressureBar),
          o2Percent: Value(gasMix.o2Percent),
          hePercent: Value(gasMix.hePercent),
          tankOrder: Value(tank.index),
          // Carry over user-authored fields from existing tank
          tankName: Value(existing?.tankName),
          presetName: Value(existing?.presetName),
          equipmentId: Value(existing?.equipmentId),
          tankRole: Value(existing?.tankRole ?? 'backGas'),
          tankMaterial: Value(existing?.tankMaterial),
        ));
      }
    });
  }

  /// Count sources with raw data for a given computer.
  Future<({int withRawData, int withoutRawData})> getRawDataCounts(
    String computerId,
  ) async {
    final all = await (db.select(db.diveDataSources)
      ..where((t) => t.computerId.equals(computerId))).get();

    final withData = all.where((r) => r.rawData != null).length;
    return (withRawData: withData, withoutRawData: all.length - withData);
  }

  /// Check if a dive has any source with raw data.
  Future<bool> hasRawData(String diveId) async {
    final sources = await (db.select(db.diveDataSources)
      ..where((t) => t.diveId.equals(diveId) & t.rawData.isNotNull())).get();
    return sources.isNotEmpty;
  }

  String _mapDiveMode(String? mode) {
    switch (mode) {
      case 'open_circuit': return 'oc';
      case 'ccr': return 'ccr';
      case 'scr': return 'scr';
      case 'gauge': return 'oc';
      case 'freedive': return 'oc';
      default: return 'oc';
    }
  }

  static int _counter = 0;
  String _uuid() => 'reparse-${DateTime.now().millisecondsSinceEpoch}-${_counter++}';
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_computer/data/services/reparse_service_test.dart`

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_computer/data/services/reparse_service.dart test/features/dive_computer/data/services/reparse_service_test.dart
git commit -m "feat: add ReparseService with applyParsedUpdate and allowlist enforcement

Shared function for both replaceSource and manual re-parse paths.
Computer-authored fields overwritten, user-authored preserved.
DiveTanks matched by tankOrder with user-field carry-over."
```

---

## Task 8: Import Service — Rename `replace` to `replaceSource` and Wire Blob Writes

**Files:**
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart`
- Modify: `lib/features/import_wizard/domain/models/duplicate_action.dart`
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`

- [ ] **Step 1: Add `replaceSource` to `DuplicateAction` enum**

In `lib/features/import_wizard/domain/models/duplicate_action.dart`, add:

```dart
enum DuplicateAction {
  skip,
  importAsNew,
  consolidate,
  replaceSource,
}
```

- [ ] **Step 2: Rename `ConflictResolution.replace` to `replaceSource`**

In `lib/features/dive_computer/data/services/dive_import_service.dart`, rename:

```dart
enum ConflictResolution {
  skip,
  replaceSource,  // was: replace
  importAsNew,
  askUser,
  consolidate,
}
```

Update the two internal references:
- Line ~292: `defaultResolution == ConflictResolution.replaceSource`
- Line ~508: `case ConflictResolution.replaceSource:`

Rename `ImportMode.replace` to `ImportMode.replaceSource`:

```dart
enum ImportMode {
  newOnly,
  all,
  replaceSource,  // was: replace
}
```

Update line ~314: `mode == ImportMode.replaceSource`

- [ ] **Step 3: Add raw data fields to `_importNewDive` path**

The `DownloadedDive` now has `rawData` and `rawFingerprint`. The adapter needs to pass session-level descriptor info. Add parameters to `_importNewDive` and the `DiveDataSourcesCompanion` insert to include:

```dart
rawData: Value(dive.rawData),
rawFingerprint: Value(dive.rawFingerprint),
descriptorVendor: Value(descriptorVendor),
descriptorProduct: Value(descriptorProduct),
descriptorModel: Value(descriptorModel),
libdivecomputerVersion: Value(libdivecomputerVersion),
lastParsedAt: Value(DateTime.now()),
```

This requires the import service to receive descriptor info from the adapter. Add fields to `DiveImportService`:

```dart
String? descriptorVendor;
String? descriptorProduct;
int? descriptorModel;
String? libdivecomputerVersion;
```

Set these from the adapter at download-session start.

- [ ] **Step 4: Wire `replaceSource` to `ReparseService.applyParsedUpdate`**

In `_updateExistingDive`, replace the stub with a call to `ReparseService.applyParsedUpdate` using the downloaded dive's raw bytes. Convert `DownloadedDive` back to `pigeon.ParsedDive` format or extract the needed fields directly.

The cleanest approach: have `_updateExistingDive` look up the target `DiveDataSources` row by `(diveId, computerId)`, then write the blob fields and call the shared update.

- [ ] **Step 5: Fix all compilation errors from the rename**

Run: `flutter analyze lib/`

Fix any remaining references to `ConflictResolution.replace` or `ImportMode.replace`.

- [ ] **Step 6: Run existing import service tests**

Run: `flutter test test/features/dive_computer/data/services/dive_import_service_test.dart`

Expected: PASS (after fixing any enum references in tests).

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_computer/data/services/dive_import_service.dart lib/features/import_wizard/domain/models/duplicate_action.dart lib/features/import_wizard/data/adapters/dive_computer_adapter.dart
git commit -m "feat: rename replace to replaceSource, wire raw data persistence

ConflictResolution.replace -> replaceSource across import service.
Initial import now writes rawData/descriptor to DiveDataSources.
replaceSource delegates to ReparseService.applyParsedUpdate."
```

---

## Task 9: DiveComputerAdapter — Pass Session Descriptor and Raw Bytes

**Files:**
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`
- Modify: `lib/features/dive_computer/presentation/providers/download_providers.dart`

- [ ] **Step 1: Capture session-level descriptor in adapter**

In `DiveComputerAdapter`, add fields for the session descriptor:

```dart
String? _descriptorVendor;
String? _descriptorProduct;
int? _descriptorModel;
String? _libdivecomputerVersion;
```

In `ensureComputer` or at download start, capture from the `DiscoveredDevice`:

```dart
_descriptorVendor = device.vendor;
_descriptorProduct = device.product;
_descriptorModel = device.model;
```

Read `libdivecomputerVersion` from the `libdcVersionProvider` (or call `diveComputerService.getVersion()` at session start).

- [ ] **Step 2: Pass descriptor to import service**

Set the import service's descriptor fields when creating or configuring the service for this download session:

```dart
_importService.descriptorVendor = _descriptorVendor;
_importService.descriptorProduct = _descriptorProduct;
_importService.descriptorModel = _descriptorModel;
_importService.libdivecomputerVersion = _libdivecomputerVersion;
```

- [ ] **Step 3: Handle `replaceSource` in the adapter's `performImport`**

In `DiveComputerAdapter.performImport`, add handling for `DuplicateAction.replaceSource` alongside the existing `skip`, `importAsNew`, and `consolidate` branches:

```dart
} else if (action == DuplicateAction.replaceSource) {
  // Find matching source row and update in place
  await _importService.resolveConflict(
    conflict,
    ConflictResolution.replaceSource,
    computer!.id,
    diverId: _diverId,
  );
  updated++;
}
```

- [ ] **Step 4: Add `replaceSource` to `supportedDuplicateActions`**

In `DiveComputerAdapter.supportedDuplicateActions` (line ~226), add conditionally:

```dart
@override
Set<DuplicateAction> get supportedDuplicateActions => const {
  DuplicateAction.skip,
  DuplicateAction.importAsNew,
  DuplicateAction.consolidate,
  DuplicateAction.replaceSource,
};
```

Note: The visibility logic (only show when same-computer source exists) is handled in the UI layer (Task 11), not here. The adapter declares support; the UI filters availability per-dive.

- [ ] **Step 5: Verify compilation**

Run: `flutter analyze lib/features/import_wizard/ lib/features/dive_computer/`

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/import_wizard/data/adapters/dive_computer_adapter.dart lib/features/dive_computer/presentation/providers/download_providers.dart
git commit -m "feat: pass session descriptor through DiveComputerAdapter, support replaceSource"
```

---

## Task 10: Re-parse Providers

**Files:**
- Create: `lib/features/dive_computer/presentation/providers/reparse_providers.dart`

- [ ] **Step 1: Create Riverpod providers for re-parse actions**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';

final reparseServiceProvider = Provider<ReparseService>((ref) {
  final db = ref.watch(databaseProvider);
  return ReparseService(db: db);
});

final rawDataCountProvider = FutureProvider.family<
    ({int withRawData, int withoutRawData}), String>(
  (ref, computerId) {
    final service = ref.watch(reparseServiceProvider);
    return service.getRawDataCounts(computerId);
  },
);

final diveHasRawDataProvider = FutureProvider.family<bool, String>(
  (ref, diveId) {
    final service = ref.watch(reparseServiceProvider);
    return service.hasRawData(diveId);
  },
);
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/features/dive_computer/presentation/providers/reparse_providers.dart`

Expected: No errors (may need to locate `databaseProvider` — it likely lives in a core providers file).

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_computer/presentation/providers/reparse_providers.dart
git commit -m "feat: add Riverpod providers for re-parse service and raw data counts"
```

---

## Task 11: UI — Import Wizard `replaceSource` Choice

**Files:**
- Modify: `lib/features/import_wizard/presentation/widgets/duplicate_action_card.dart`

- [ ] **Step 1: Add `replaceSource` badge rendering**

In `duplicate_action_card.dart`, in the `_ActionBadge` section (lines ~280-311), add a case for `DuplicateAction.replaceSource`:

```dart
DuplicateAction.replaceSource => (
    icon: Icons.sync,
    label: 'Replace',
    color: Colors.blue.shade700,
  ),
```

- [ ] **Step 2: Conditionally include `replaceSource` in available actions**

The `availableActions` set is passed from the adapter to the review step. The conditional logic (only show Replace when a same-computer source exists) needs to happen per-dive in the review list. In `entity_review_list.dart` or the widget that renders each duplicate card, filter `availableActions` based on whether the matched dive has a `DiveDataSources` row with the current computer's ID.

This requires a provider or query that checks `DiveDataSources` for the matched dive. Add this check in the duplicate card builder:

```dart
final hasSameComputerSource = await ref.read(
  hasSameComputerSourceProvider((
    diveId: existingDiveId,
    computerId: currentComputerId,
  )).future,
);

final filteredActions = hasSameComputerSource
    ? availableActions
    : availableActions.difference({DuplicateAction.replaceSource});
```

- [ ] **Step 3: Verify the wizard renders correctly**

Run the app, connect to a dive computer (or use a mock), and navigate to the import wizard duplicate review step. Verify:
- Replace badge appears when expected (same-computer source exists)
- Replace badge is hidden when no same-computer source
- Selecting Replace resolves the conflict correctly

- [ ] **Step 4: Commit**

```bash
git add lib/features/import_wizard/
git commit -m "feat(ui): add Replace source data choice to import wizard duplicate review"
```

---

## Task 12: UI — DC Detail Page "Re-parse All Dives" Button

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_detail_page.dart:279-315`

- [ ] **Step 1: Add re-parse button to `_buildActionsCard`**

In `device_detail_page.dart`, inside `_buildActionsCard` (after the "Re-import all dives" button block at line ~310, before the closing `]`):

```dart
Consumer(
  builder: (context, ref, _) {
    final counts = ref.watch(rawDataCountProvider(computer.id));
    return counts.when(
      data: (c) {
        if (c.withRawData == 0) return const SizedBox.shrink();
        return Column(
          children: [
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _confirmReparseAll(context, ref, computer, c),
              icon: const Icon(Icons.refresh),
              label: Text('Re-parse all dives'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${c.withRawData} dives with raw data'
                '${c.withoutRawData > 0 ? ' (${c.withoutRawData} without)' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  },
),
```

- [ ] **Step 2: Add `_confirmReparseAll` method**

```dart
Future<void> _confirmReparseAll(
  BuildContext context,
  WidgetRef ref,
  DiveComputer computer,
  ({int withRawData, int withoutRawData}) counts,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Re-parse all dives'),
      content: Text(
        'Re-run the dive parser on ${counts.withRawData} dives that have '
        'stored raw data. This updates profile and sensor data but preserves '
        'your notes, sites, buddies, and other edits.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Re-parse'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await _executeReparseAll(context, ref, computer.id);
  }
}
```

- [ ] **Step 3: Add `_executeReparseAll` method**

```dart
Future<void> _executeReparseAll(
  BuildContext context,
  WidgetRef ref,
  String computerId,
) async {
  final service = ref.read(reparseServiceProvider);
  final dcService = ref.read(diveComputerServiceProvider);

  // Get all sources with raw data for this computer
  final db = ref.read(databaseProvider);
  final sources = await (db.select(db.diveDataSources)
    ..where((t) => t.computerId.equals(computerId) & t.rawData.isNotNull()))
    .get();

  if (sources.isEmpty) return;

  int succeeded = 0;
  int failed = 0;

  // Show progress
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Re-parsing ${sources.length} dives...')),
    );
  }

  for (final source in sources) {
    try {
      final parsed = await dcService.parseRawDiveData(
        source.descriptorVendor!,
        source.descriptorProduct!,
        source.descriptorModel!,
        source.rawData!,
      );
      await service.applyParsedUpdate(
        diveId: source.diveId,
        sourceRowId: source.id,
        parsed: parsed,
        descriptorVendor: source.descriptorVendor,
        descriptorProduct: source.descriptorProduct,
        descriptorModel: source.descriptorModel,
        libdivecomputerVersion: source.libdivecomputerVersion,
      );
      succeeded++;
    } catch (e) {
      failed++;
    }
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failed == 0
          ? 'Re-parsed $succeeded dives successfully'
          : 'Re-parsed $succeeded of ${succeeded + failed} dives. $failed failed.'),
    ));
  }

  // Invalidate providers to refresh UI
  ref.invalidate(rawDataCountProvider(computerId));
}
```

- [ ] **Step 4: Add required imports**

```dart
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
```

- [ ] **Step 5: Test in the app**

Run: `flutter run -d macos`

Navigate to a dive computer detail page. Verify:
- Button is hidden when no raw data exists
- Button shows with counts when raw data is present
- Confirmation dialog appears on tap
- Re-parse runs and shows progress/result

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_computer/presentation/pages/device_detail_page.dart
git commit -m "feat(ui): add Re-parse all dives button to dive computer detail page"
```

---

## Task 13: UI — Dive Detail Page "Re-parse Raw Data" Menu Item

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:502-546`

- [ ] **Step 1: Add re-parse menu item to standalone overflow menu**

In `dive_detail_page.dart`, in the `PopupMenuButton` `itemBuilder` (around line 530), add a re-parse option before the delete item:

```dart
Consumer(
  builder: (context, ref, _) {
    final hasRawData = ref.watch(diveHasRawDataProvider(dive.id));
    return hasRawData.when(
      data: (has) => has
          ? PopupMenuItem(
              value: 'reparse',
              child: ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Re-parse raw data'),
              ),
            )
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  },
),
```

Note: `PopupMenuButton.itemBuilder` returns `List<PopupMenuEntry>`, so the Consumer approach may need adjustment. An alternative is to pre-load the `hasRawData` state and conditionally include the item.

- [ ] **Step 2: Handle the 'reparse' action in `onSelected`**

```dart
case 'reparse':
  await _reparseDive(context, ref, dive);
```

- [ ] **Step 3: Add `_reparseDive` method**

```dart
Future<void> _reparseDive(
  BuildContext context,
  WidgetRef ref,
  Dive dive,
) async {
  final service = ref.read(reparseServiceProvider);
  final dcService = ref.read(diveComputerServiceProvider);
  final db = ref.read(databaseProvider);

  final sources = await (db.select(db.diveDataSources)
    ..where((t) => t.diveId.equals(dive.id) & t.rawData.isNotNull()))
    .get();

  if (sources.isEmpty) return;

  try {
    for (final source in sources) {
      final parsed = await dcService.parseRawDiveData(
        source.descriptorVendor!,
        source.descriptorProduct!,
        source.descriptorModel!,
        source.rawData!,
      );
      await service.applyParsedUpdate(
        diveId: dive.id,
        sourceRowId: source.id,
        parsed: parsed,
        descriptorVendor: source.descriptorVendor,
        descriptorProduct: source.descriptorProduct,
        descriptorModel: source.descriptorModel,
        libdivecomputerVersion: source.libdivecomputerVersion,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dive re-parsed successfully')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Re-parse failed: $e')),
      );
    }
  }
}
```

- [ ] **Step 4: Add the same menu item to the embedded mode overflow menu (line ~634)**

Replicate the re-parse item in the embedded mode `PopupMenuButton` section.

- [ ] **Step 5: Test in the app**

Run: `flutter run -d macos`

Open a dive detail page. Verify:
- Menu item is hidden for dives without raw data
- Menu item appears for dives with raw data
- Tapping re-parses and shows snackbar feedback
- After re-parse, the dive detail refreshes with updated values

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "feat(ui): add Re-parse raw data menu item to dive detail page"
```

---

## Task 14: Format, Analyze, and Final Test Pass

**Files:** All modified files

- [ ] **Step 1: Format all Dart code**

Run: `dart format lib/ test/`

- [ ] **Step 2: Run full analysis**

Run: `flutter analyze`

Expected: No errors, no warnings.

- [ ] **Step 3: Run all tests**

Run: `flutter test test/features/dive_computer/`

Expected: All tests pass.

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`

Expected: No regressions.

- [ ] **Step 5: Commit any formatting fixes**

```bash
git add -u
git commit -m "chore: format and fix lint issues for raw dive data storage"
```
