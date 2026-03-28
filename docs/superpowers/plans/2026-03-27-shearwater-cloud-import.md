# Shearwater Cloud Database Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import dive data from Shearwater Cloud `.db` files with full profile parsing via libdivecomputer.

**Architecture:** A new `ShearwaterCloudParser` (implementing `ImportParser`) opens the SQLite database, queries `dive_details` and `log_data` tables, feeds decompressed binary BLOBs to libdivecomputer via a new `parseRawDiveData()` FFI method, and merges the parsed profile data with user-entered metadata. The result is a standard `ImportPayload` consumed by the existing import wizard.

**Tech Stack:** Flutter/Dart, libdivecomputer (C), Pigeon FFI, sqlite3 FFI (via Drift), gzip decompression

**Spec:** `docs/superpowers/specs/2026-03-27-shearwater-cloud-import-design.md`

**Worktree:** `.worktrees/shearwater-cloud-import` (branch: `feature/shearwater-cloud-import`)

---

## Task 1: Add `libdc_parse_raw_dive()` C Function

Refactor the existing `parse_dive()` to extract shared field-extraction logic, then add a new standalone function that uses `dc_parser_new2()` (no device connection required).

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h`
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c`

- [ ] **Step 1: Extract field extraction into `extract_dive_fields()`**

In `libdc_download.c`, extract lines 262-348 of `parse_dive()` (everything after parser creation, before `dc_parser_destroy`) into a new static function:

```c
// Add after the push_event() function, before parse_dive()

static int extract_dive_fields(dc_parser_t *parser, libdc_parsed_dive_t *dive) {
    // Extract datetime.
    dc_datetime_t dt = {0};
    if (dc_parser_get_datetime(parser, &dt) == DC_STATUS_SUCCESS) {
        dive->year = dt.year;
        dive->month = dt.month;
        dive->day = dt.day;
        dive->hour = dt.hour;
        dive->minute = dt.minute;
        dive->second = dt.second;
        dive->timezone = dt.timezone;
    }

    // Extract summary fields.
    double dval = 0;
    unsigned int uval = 0;

    if (dc_parser_get_field(parser, DC_FIELD_MAXDEPTH, 0, &dval) == DC_STATUS_SUCCESS) {
        dive->max_depth = dval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_AVGDEPTH, 0, &dval) == DC_STATUS_SUCCESS) {
        dive->avg_depth = dval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_DIVETIME, 0, &uval) == DC_STATUS_SUCCESS) {
        dive->duration = uval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_TEMPERATURE_MINIMUM, 0, &dval) == DC_STATUS_SUCCESS) {
        dive->min_temp = dval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_TEMPERATURE_MAXIMUM, 0, &dval) == DC_STATUS_SUCCESS) {
        dive->max_temp = dval;
    }
    if (dc_parser_get_field(parser, DC_FIELD_DIVEMODE, 0, &uval) == DC_STATUS_SUCCESS) {
        dive->dive_mode = uval;
    }

    // Extract decompression model.
    dc_decomodel_t decomodel = {0};
    if (dc_parser_get_field(parser, DC_FIELD_DECOMODEL, 0, &decomodel) == DC_STATUS_SUCCESS) {
        dive->deco_model_type = decomodel.type;
        dive->deco_conservatism = decomodel.conservatism;
        dive->gf_low = decomodel.params.gf.low;
        dive->gf_high = decomodel.params.gf.high;
    }

    // Extract gas mixes.
    unsigned int gasmix_count = 0;
    if (dc_parser_get_field(parser, DC_FIELD_GASMIX_COUNT, 0, &gasmix_count) == DC_STATUS_SUCCESS) {
        if (gasmix_count > LIBDC_MAX_GASMIXES) {
            gasmix_count = LIBDC_MAX_GASMIXES;
        }
        for (unsigned int i = 0; i < gasmix_count; i++) {
            dc_gasmix_t gm = {0};
            if (dc_parser_get_field(parser, DC_FIELD_GASMIX, i, &gm) == DC_STATUS_SUCCESS) {
                dive->gasmixes[i].oxygen = gm.oxygen;
                dive->gasmixes[i].helium = gm.helium;
            }
        }
        dive->gasmix_count = gasmix_count;
    }

    // Extract tanks.
    unsigned int tank_count = 0;
    if (dc_parser_get_field(parser, DC_FIELD_TANK_COUNT, 0, &tank_count) == DC_STATUS_SUCCESS) {
        if (tank_count > LIBDC_MAX_TANKS) {
            tank_count = LIBDC_MAX_TANKS;
        }
        for (unsigned int i = 0; i < tank_count; i++) {
            dc_tank_t tk = {0};
            if (dc_parser_get_field(parser, DC_FIELD_TANK, i, &tk) == DC_STATUS_SUCCESS) {
                dive->tanks[i].gasmix = tk.gasmix;
                dive->tanks[i].volume = tk.volume;
                dive->tanks[i].workpressure = tk.workpressure;
                dive->tanks[i].beginpressure = tk.beginpressure;
                dive->tanks[i].endpressure = tk.endpressure;
            }
        }
        dive->tank_count = tank_count;
    }

    // Extract profile samples.
    sample_state_t sample_state = {0};
    sample_state.dive = dive;
    dc_parser_samples_foreach(parser, sample_callback, &sample_state);
    push_sample(&sample_state);

    return 0;
}
```

- [ ] **Step 2: Update `parse_dive()` to use `extract_dive_fields()`**

Replace the body of `parse_dive()` (lines 236-348) with:

```c
static int parse_dive(download_state_t *state,
                       const unsigned char *data, unsigned int size,
                       const unsigned char *fingerprint, unsigned int fsize,
                       libdc_parsed_dive_t *dive) {
    memset(dive, 0, sizeof(*dive));
    dive->min_temp = NAN;
    dive->max_temp = NAN;
    dive->deco_model_type = 0;
    dive->deco_conservatism = 0;
    dive->gf_low = 0;
    dive->gf_high = 0;
    dive->events = NULL;
    dive->event_count = 0;
    dive->event_capacity = 0;

    // Store fingerprint.
    if (fingerprint != NULL && fsize > 0) {
        unsigned int copy_size = fsize < LIBDC_MAX_FINGERPRINT ?
                                 fsize : LIBDC_MAX_FINGERPRINT;
        memcpy(dive->fingerprint, fingerprint, copy_size);
        dive->fingerprint_size = copy_size;
    }

    // Create parser from device.
    dc_parser_t *parser = NULL;
    dc_status_t status = dc_parser_new(&parser, state->device, data, size);
    if (status != DC_STATUS_SUCCESS || parser == NULL) {
        return -1;
    }

    int result = extract_dive_fields(parser, dive);
    dc_parser_destroy(parser);
    return result;
}
```

- [ ] **Step 3: Add `libdc_parse_raw_dive()` public function**

Add at the end of `libdc_download.c`, before the closing of the file (after `libdc_download_run`):

```c
// ============================================================
// Standalone Raw Dive Parsing (no device connection)
// ============================================================

int libdc_parse_raw_dive(
    const char *vendor, const char *product, unsigned int model,
    const unsigned char *data, unsigned int size,
    libdc_parsed_dive_t *result,
    char *error_buf, size_t error_buf_size)
{
    if (vendor == NULL || product == NULL || data == NULL ||
        size == 0 || result == NULL) {
        if (error_buf && error_buf_size > 0) {
            strncpy(error_buf, "Invalid arguments", error_buf_size - 1);
            error_buf[error_buf_size - 1] = '\0';
        }
        return LIBDC_STATUS_INVALIDARGS;
    }

    memset(result, 0, sizeof(*result));
    result->min_temp = NAN;
    result->max_temp = NAN;
    result->events = NULL;
    result->event_count = 0;
    result->event_capacity = 0;

    // Create context.
    dc_context_t *context = NULL;
    dc_status_t status = dc_context_new(&context);
    if (status != DC_STATUS_SUCCESS) {
        if (error_buf && error_buf_size > 0) {
            strncpy(error_buf, "Failed to create context", error_buf_size - 1);
        }
        return (int)status;
    }

    // Find descriptor.
    dc_descriptor_t *descriptor = find_descriptor(vendor, product, model);
    if (descriptor == NULL) {
        dc_context_free(context);
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size,
                     "No descriptor for %s %s (model %u)", vendor, product, model);
        }
        return LIBDC_STATUS_NODEVICE;
    }

    // Create parser from descriptor (no device needed).
    dc_parser_t *parser = NULL;
    status = dc_parser_new2(&parser, context, descriptor, data, size);
    if (status != DC_STATUS_SUCCESS || parser == NULL) {
        dc_descriptor_free(descriptor);
        dc_context_free(context);
        if (error_buf && error_buf_size > 0) {
            snprintf(error_buf, error_buf_size,
                     "Parser creation failed (status %d)", (int)status);
        }
        return (int)status;
    }

    int parse_result = extract_dive_fields(parser, result);

    dc_parser_destroy(parser);
    dc_descriptor_free(descriptor);
    dc_context_free(context);

    if (parse_result != 0 && error_buf && error_buf_size > 0) {
        strncpy(error_buf, "Field extraction failed", error_buf_size - 1);
    }

    return parse_result;
}
```

- [ ] **Step 4: Add function declaration to `libdc_wrapper.h`**

Add after the `libdc_download_run` declaration (after line ~240):

```c
// ============================================================
// Standalone Raw Dive Parsing
// ============================================================

/// Parse raw dive computer binary data without a device connection.
/// Uses dc_parser_new2() with a descriptor looked up by vendor/product/model.
/// Returns 0 on success, negative on failure.
/// The caller must free result->samples and result->events when done.
int libdc_parse_raw_dive(
    const char *vendor, const char *product, unsigned int model,
    const unsigned char *data, unsigned int size,
    libdc_parsed_dive_t *result,
    char *error_buf, size_t error_buf_size);
```

- [ ] **Step 5: Verify compilation**

Run: `cd packages/libdivecomputer_plugin && flutter build macos --debug 2>&1 | tail -20`

Expected: Build succeeds with no errors related to the new C function.

- [ ] **Step 6: Commit**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h \
       packages/libdivecomputer_plugin/macos/Classes/libdc_download.c
git commit -m "feat(libdc): add libdc_parse_raw_dive for standalone binary parsing

Refactor parse_dive() to extract shared field-extraction logic into
extract_dive_fields(), then add libdc_parse_raw_dive() which uses
dc_parser_new2() to parse raw dive data without a device connection."
```

---

## Task 2: Add Pigeon API Method + Platform Bridges

Expose the new C function through Pigeon so Dart can call it.

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`
- Modify: `packages/libdivecomputer_plugin/android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`
- Modify: `packages/libdivecomputer_plugin/windows/dive_computer_host_api_impl.cc`
- Regenerate: `packages/libdivecomputer_plugin/lib/src/generated/dive_computer_api.g.dart`

- [ ] **Step 1: Add `parseRawDiveData` to Pigeon definition**

In `pigeons/dive_computer_api.dart`, add to the `DiveComputerHostApi` class (after `getLibdivecomputerVersion`):

```dart
  @async
  ParsedDive parseRawDiveData(
    String vendor,
    String product,
    int model,
    Uint8List data,
  );
```

Also add the `Uint8List` import at the top of the file:

```dart
import 'dart:typed_data';
```

Note: Check if `Uint8List` is already imported or if Pigeon handles it natively. If Pigeon doesn't support `Uint8List` directly, use `List<int>` instead. Check the generated code after running pigeon.

- [ ] **Step 2: Run Pigeon code generation**

Run: `cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart`

Expected: Regenerates `lib/src/generated/dive_computer_api.g.dart`, `darwin/.../DiveComputerApi.g.swift`, `android/.../DiveComputerApi.g.kt`, `windows/dive_computer_api.g.h`, `windows/dive_computer_api.g.cc`, `linux/dive_computer_api.g.h`, `linux/dive_computer_api.g.cc`.

Verify: Check that `dive_computer_api.g.dart` contains `parseRawDiveData` method.

- [ ] **Step 3: Implement Swift bridge (Darwin - macOS + iOS)**

In `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`, add the new method to the `DiveComputerHostApiImpl` class:

```swift
    // MARK: - Raw Dive Parsing

    func parseRawDiveData(
        vendor: String,
        product: String,
        model: Int64,
        data: FlutterStandardTypedData,
        completion: @escaping (Result<ParsedDive, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            var dive = libdc_parsed_dive_t()
            var errorBuf = [CChar](repeating: 0, count: 256)

            let result = data.data.withUnsafeBytes { rawPtr -> Int32 in
                guard let baseAddress = rawPtr.baseAddress else { return -1 }
                return libdc_parse_raw_dive(
                    vendor,
                    product,
                    UInt32(model),
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    UInt32(data.data.count),
                    &dive,
                    &errorBuf,
                    errorBuf.count
                )
            }

            if result != 0 {
                let errorMsg = String(cString: errorBuf)
                free(dive.samples)
                free(dive.events)
                DispatchQueue.main.async {
                    completion(.failure(PigeonError(
                        code: "PARSE_ERROR",
                        message: "Failed to parse raw dive data: \(errorMsg)",
                        details: nil
                    )))
                }
                return
            }

            let parsedDive = self.convertParsedDive(dive)
            free(dive.samples)
            free(dive.events)

            DispatchQueue.main.async {
                completion(.success(parsedDive))
            }
        }
    }
```

Note: The exact method signature depends on Pigeon codegen output. Check `DiveComputerApi.g.swift` for the expected protocol signature and adjust accordingly. The `data` parameter type may be `FlutterStandardTypedData` or `[UInt8]` depending on Pigeon version.

- [ ] **Step 4: Implement Android stub**

In `android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt`, add:

```kotlin
    override fun parseRawDiveData(
        vendor: String,
        product: String,
        model: Long,
        data: ByteArray,
        callback: (Result<ParsedDive>) -> Unit
    ) {
        callback(Result.failure(FlutterError(
            "UNSUPPORTED",
            "Raw dive parsing not yet implemented on Android",
            null
        )))
    }
```

- [ ] **Step 5: Implement Windows stub**

In `windows/dive_computer_host_api_impl.cc`, add the stub for the new method. Follow the existing patterns in that file -- return an error indicating the method is not yet implemented on Windows.

- [ ] **Step 6: Implement Linux stub**

Check `linux/` for the GObject bridge implementation file. Add a stub that returns an error. Follow the existing GObject patterns.

- [ ] **Step 7: Verify build**

Run: `cd packages/libdivecomputer_plugin && flutter build macos --debug 2>&1 | tail -20`

Expected: Build succeeds.

- [ ] **Step 8: Commit**

```bash
git add packages/libdivecomputer_plugin/pigeons/ \
       packages/libdivecomputer_plugin/lib/src/generated/ \
       packages/libdivecomputer_plugin/darwin/ \
       packages/libdivecomputer_plugin/android/ \
       packages/libdivecomputer_plugin/windows/ \
       packages/libdivecomputer_plugin/linux/ \
       packages/libdivecomputer_plugin/macos/ \
       packages/libdivecomputer_plugin/ios/
git commit -m "feat(libdc): add parseRawDiveData Pigeon API with platform bridges

Exposes libdc_parse_raw_dive() to Dart via Pigeon. Full implementation
on macOS/iOS, stubs on Android/Windows/Linux."
```

---

## Task 3: Shearwater Filename Parser (TDD)

Parse Shearwater Cloud log_data filenames to extract dive computer model and serial number.

**Files:**
- Create: `test/features/universal_import/data/services/shearwater_filename_parser_test.dart`
- Create: `lib/features/universal_import/data/services/shearwater_filename_parser.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_filename_parser.dart';

void main() {
  group('ShearwaterFilenameParser', () {
    group('parseFilename', () {
      test('extracts Teric model and serial', () {
        final result = ShearwaterFilenameParser.parse(
          'Teric[8629AC48]#1 2025-9-20 7-42-35.swlogzp',
        );
        expect(result.model, 'Teric');
        expect(result.serial, '8629AC48');
        expect(result.diveNumber, 1);
      });

      test('extracts Perdix model and serial', () {
        final result = ShearwaterFilenameParser.parse(
          'Perdix[ABCD1234]#15 2025-12-01 10-30-00.swlogzp',
        );
        expect(result.model, 'Perdix');
        expect(result.serial, 'ABCD1234');
        expect(result.diveNumber, 15);
      });

      test('extracts Petrel 3 with space in name', () {
        final result = ShearwaterFilenameParser.parse(
          'Petrel 3[11223344]#7 2025-6-15 14-00-00.swlogzp',
        );
        expect(result.model, 'Petrel 3');
        expect(result.serial, '11223344');
        expect(result.diveNumber, 7);
      });

      test('extracts Peregrine', () {
        final result = ShearwaterFilenameParser.parse(
          'Peregrine[DEADBEEF]#100 2025-1-1 0-0-0.swlogzp',
        );
        expect(result.model, 'Peregrine');
        expect(result.serial, 'DEADBEEF');
        expect(result.diveNumber, 100);
      });

      test('returns unknown for unrecognized format', () {
        final result = ShearwaterFilenameParser.parse('random_file.db');
        expect(result.model, isNull);
        expect(result.serial, isNull);
        expect(result.diveNumber, isNull);
      });

      test('returns unknown for empty string', () {
        final result = ShearwaterFilenameParser.parse('');
        expect(result.model, isNull);
        expect(result.serial, isNull);
      });
    });

    group('vendorProduct', () {
      test('maps known models to vendor/product', () {
        expect(
          ShearwaterFilenameParser.vendorProduct('Teric'),
          ('Shearwater', 'Teric'),
        );
        expect(
          ShearwaterFilenameParser.vendorProduct('Perdix'),
          ('Shearwater', 'Perdix'),
        );
        expect(
          ShearwaterFilenameParser.vendorProduct('Petrel 3'),
          ('Shearwater', 'Petrel 3'),
        );
      });

      test('returns null for unknown model', () {
        expect(ShearwaterFilenameParser.vendorProduct('Unknown'), isNull);
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/shearwater_filename_parser_test.dart`

Expected: FAIL -- file not found.

- [ ] **Step 3: Write implementation**

```dart
/// Parsed result from a Shearwater Cloud log_data filename.
class ShearwaterFilenameInfo {
  final String? model;
  final String? serial;
  final int? diveNumber;

  const ShearwaterFilenameInfo({this.model, this.serial, this.diveNumber});
}

/// Parses Shearwater Cloud log_data filenames to extract model, serial, and dive number.
///
/// Filename format: "ModelName[HexSerial]#DiveNum YYYY-M-D H-M-S.swlogzp"
/// Examples:
///   "Teric[8629AC48]#1 2025-9-20 7-42-35.swlogzp"
///   "Petrel 3[11223344]#7 2025-6-15 14-00-00.swlogzp"
class ShearwaterFilenameParser {
  static final _pattern = RegExp(r'^(.+?)\[([A-Fa-f0-9]+)\]#(\d+)\s');

  /// Known Shearwater model names mapped to libdivecomputer vendor/product.
  static const _knownModels = {
    'Teric': ('Shearwater', 'Teric'),
    'Perdix': ('Shearwater', 'Perdix'),
    'Perdix 2': ('Shearwater', 'Perdix 2'),
    'Perdix AI': ('Shearwater', 'Perdix AI'),
    'Peregrine': ('Shearwater', 'Peregrine'),
    'Petrel': ('Shearwater', 'Petrel'),
    'Petrel 2': ('Shearwater', 'Petrel 2'),
    'Petrel 3': ('Shearwater', 'Petrel 3'),
    'Tern': ('Shearwater', 'Tern'),
    'NERD': ('Shearwater', 'NERD'),
    'NERD 2': ('Shearwater', 'NERD 2'),
  };

  static ShearwaterFilenameInfo parse(String filename) {
    final match = _pattern.firstMatch(filename);
    if (match == null) {
      return const ShearwaterFilenameInfo();
    }
    return ShearwaterFilenameInfo(
      model: match.group(1),
      serial: match.group(2),
      diveNumber: int.tryParse(match.group(3) ?? ''),
    );
  }

  /// Returns (vendor, product) for a known Shearwater model name.
  /// Returns null if the model is not recognized.
  static (String, String)? vendorProduct(String model) {
    return _knownModels[model];
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/shearwater_filename_parser_test.dart`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/services/shearwater_filename_parser.dart \
       test/features/universal_import/data/services/shearwater_filename_parser_test.dart
git commit -m "feat: add Shearwater Cloud filename parser with tests

Extracts dive computer model, serial number, and dive number from
Shearwater Cloud log_data filenames."
```

---

## Task 4: Shearwater DB Reader (TDD)

Opens the SQLite database, validates the Shearwater Cloud fingerprint, queries tables, and extracts/decompresses binary BLOBs.

**Files:**
- Create: `test/features/universal_import/data/services/shearwater_db_reader_test.dart`
- Create: `lib/features/universal_import/data/services/shearwater_db_reader.dart`

- [ ] **Step 1: Write failing tests**

Tests use the real database fixture at `third_party/shearwater_cloud_database.db`. Create a helper to find the project root for test fixtures.

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';

void main() {
  late Uint8List dbBytes;

  setUpAll(() {
    // Load the test fixture database.
    final file = File('third_party/shearwater_cloud_database.db');
    if (!file.existsSync()) {
      fail('Test fixture not found: third_party/shearwater_cloud_database.db');
    }
    dbBytes = file.readAsBytesSync();
  });

  group('ShearwaterDbReader', () {
    test('isShearwaterCloudDb returns true for valid database', () async {
      final result = await ShearwaterDbReader.isShearwaterCloudDb(dbBytes);
      expect(result, isTrue);
    });

    test('isShearwaterCloudDb returns false for non-SQLite bytes', () async {
      final result = await ShearwaterDbReader.isShearwaterCloudDb(
        Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(result, isFalse);
    });

    test('readDives returns all dives from database', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      expect(dives, hasLength(28));
    });

    test('dive has metadata from dive_details', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      // Find a dive with known metadata.
      final dive = dives.firstWhere(
        (d) => d.diveId == '1676633251758354277',
      );
      expect(dive.location, 'Shark River, NJ, USA');
      expect(dive.site, 'Maclearie Park');
      expect(dive.buddy, 'Kiyan Griffin');
      expect(dive.notes, 'PADI Open Water certification dive 1');
      expect(dive.environment, 'Ocean/Sea');
    });

    test('dive has binary data decompressed from log_data', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.decompressedLogData, isNotNull);
      expect(dive.decompressedLogData, isNotEmpty);
    });

    test('dive has filename from log_data', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.fileName, contains('Teric'));
      expect(dive.fileName, contains('.swlogzp'));
    });

    test('dive has TankProfileData parsed as JSON', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.tankProfileData, isNotNull);
      expect(dive.tankProfileData!['GasProfiles'], isList);
      expect(dive.tankProfileData!['TankData'], isList);
    });

    test('dive has calculatedValues from log_data', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.calculatedValues, isNotNull);
      expect(dive.calculatedValues!['AverageDepth'], isA<num>());
    });

    test('dive has footer JSON from data_bytes_3', () async {
      final dives = await ShearwaterDbReader.readDives(dbBytes);
      final dive = dives.first;
      expect(dive.footerJson, isNotNull);
      expect(dive.footerJson!['UnitSystem'], isA<int>());
      expect(dive.footerJson!['DiveTimeInSeconds'], isA<int>());
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/shearwater_db_reader_test.dart`

Expected: FAIL -- file not found.

- [ ] **Step 3: Write the `ShearwaterRawDive` data class**

```dart
import 'dart:typed_data';

/// Raw dive data extracted from a Shearwater Cloud database.
/// Contains metadata from dive_details, binary data from log_data,
/// and parsed JSON fields.
class ShearwaterRawDive {
  final String diveId;
  final String? diveDate;
  final double? depth; // meters
  final double? averageDepth;
  final int? diveLengthTime; // seconds
  final String? diveNumber;
  final String? serialNumber;
  final String? location;
  final String? site;
  final String? buddy;
  final String? notes;
  final String? environment;
  final String? visibility;
  final String? weather;
  final String? conditions;
  final String? airTemperature;
  final String? weight;
  final String? dress;
  final String? apparatus;
  final String? thermalComfort;
  final String? workload;
  final String? problems;
  final String? malfunctions;
  final String? symptoms;
  final String? gnssEntryLocation;
  final String? gnssExitLocation;
  final String? gasNotes;
  final String? gearNotes;
  final String? issueNotes;
  final double? endGF99;

  // From log_data
  final String? fileName;
  final Uint8List? decompressedLogData;
  final Map<String, dynamic>? tankProfileData;
  final Map<String, dynamic>? calculatedValues;
  final Map<String, dynamic>? headerJson; // data_bytes_2
  final Map<String, dynamic>? footerJson; // data_bytes_3

  const ShearwaterRawDive({
    required this.diveId,
    this.diveDate,
    this.depth,
    this.averageDepth,
    this.diveLengthTime,
    this.diveNumber,
    this.serialNumber,
    this.location,
    this.site,
    this.buddy,
    this.notes,
    this.environment,
    this.visibility,
    this.weather,
    this.conditions,
    this.airTemperature,
    this.weight,
    this.dress,
    this.apparatus,
    this.thermalComfort,
    this.workload,
    this.problems,
    this.malfunctions,
    this.symptoms,
    this.gnssEntryLocation,
    this.gnssExitLocation,
    this.gasNotes,
    this.gearNotes,
    this.issueNotes,
    this.endGF99,
    this.fileName,
    this.decompressedLogData,
    this.tankProfileData,
    this.calculatedValues,
    this.headerJson,
    this.footerJson,
  });
}
```

- [ ] **Step 4: Write the `ShearwaterDbReader` implementation**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';

// ShearwaterRawDive class defined above (in same file or imported)

class ShearwaterDbReader {
  /// Check if the given bytes are a Shearwater Cloud database.
  /// Writes to a temp file, opens as SQLite, checks for required tables.
  static Future<bool> isShearwaterCloudDb(Uint8List bytes) async {
    return _withTempDb(bytes, (db) {
      final result = db.select(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name IN ('dive_details', 'log_data')",
      );
      return result.length == 2;
    });
  }

  /// Read all dives from the Shearwater Cloud database.
  static Future<List<ShearwaterRawDive>> readDives(Uint8List bytes) async {
    return _withTempDb(bytes, (db) {
      final rows = db.select('''
        SELECT
          dd.DiveId, dd.DiveDate, dd.Depth, dd.AverageDepth,
          dd.DiveLengthTime, dd.DiveNumber, dd.SerialNumber,
          dd.Location, dd.Site, dd.Buddy, dd.Notes,
          dd.Environment, dd.Visibility, dd.Weather, dd.Conditions,
          dd.AirTemperature, dd.Weight, dd.Dress, dd.Apparatus,
          dd.ThermalComfort, dd.Workload, dd.Problems,
          dd.Malfunctions, dd.Symptoms,
          dd.GnssEntryLocation, dd.GnssExitLocation,
          dd.TankProfileData,
          dd.GasNotes, dd.GearNotes, dd.IssueNotes, dd.EndGF99,
          ld.file_name, ld.data_bytes_1, ld.data_bytes_2,
          ld.data_bytes_3, ld.calculated_values_from_samples
        FROM dive_details dd
        LEFT JOIN log_data ld ON dd.DiveId = ld.log_id
        ORDER BY dd.DiveDate
      ''');

      return rows.map((row) {
        // Decompress data_bytes_1: skip 4-byte header, gzip decompress.
        Uint8List? decompressed;
        final rawBytes = row['data_bytes_1'] as Uint8List?;
        if (rawBytes != null && rawBytes.length > 4) {
          try {
            final gzipData = rawBytes.sublist(4);
            decompressed = Uint8List.fromList(
              gzip.decode(gzipData),
            );
          } catch (_) {
            // Decompression failed -- leave null for fallback.
          }
        }

        return ShearwaterRawDive(
          diveId: row['DiveId'] as String,
          diveDate: row['DiveDate'] as String?,
          depth: _toDouble(row['Depth']),
          averageDepth: _toDouble(row['AverageDepth']),
          diveLengthTime: _toInt(row['DiveLengthTime']),
          diveNumber: _nonEmpty(row['DiveNumber']),
          serialNumber: _nonEmpty(row['SerialNumber']),
          location: _nonEmpty(row['Location']),
          site: _nonEmpty(row['Site']),
          buddy: _nonEmpty(row['Buddy']),
          notes: _nonEmpty(row['Notes']),
          environment: _nonEmpty(row['Environment']),
          visibility: _nonEmpty(row['Visibility']),
          weather: _nonEmpty(row['Weather']),
          conditions: _nonEmpty(row['Conditions']),
          airTemperature: _nonEmpty(row['AirTemperature']),
          weight: _nonEmpty(row['Weight']),
          dress: _nonEmpty(row['Dress']),
          apparatus: _nonEmpty(row['Apparatus']),
          thermalComfort: _nonEmpty(row['ThermalComfort']),
          workload: _nonEmpty(row['Workload']),
          problems: _nonEmpty(row['Problems']),
          malfunctions: _nonEmpty(row['Malfunctions']),
          symptoms: _nonEmpty(row['Symptoms']),
          gnssEntryLocation: _nonEmpty(row['GnssEntryLocation']),
          gnssExitLocation: _nonEmpty(row['GnssExitLocation']),
          gasNotes: _nonEmpty(row['GasNotes']),
          gearNotes: _nonEmpty(row['GearNotes']),
          issueNotes: _nonEmpty(row['IssueNotes']),
          endGF99: _toDouble(row['EndGF99']),
          fileName: row['file_name'] as String?,
          decompressedLogData: decompressed,
          tankProfileData: _parseJson(row['TankProfileData']),
          calculatedValues: _parseJson(
            row['calculated_values_from_samples'],
          ),
          headerJson: _parseJsonBlob(row['data_bytes_2']),
          footerJson: _parseJsonBlob(row['data_bytes_3']),
        );
      }).toList();
    });
  }

  static Future<T> _withTempDb<T>(
    Uint8List bytes,
    T Function(Database db) action,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'sw_import_${DateTime.now().millisecondsSinceEpoch}.db');
    final tempFile = File(tempPath);

    try {
      await tempFile.writeAsBytes(bytes);
      final db = sqlite3.open(tempPath, mode: OpenMode.readOnly);
      try {
        return action(db);
      } finally {
        db.dispose();
      }
    } finally {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  }

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    return s.isEmpty ? null : s;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static Map<String, dynamic>? _parseJson(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseJsonBlob(dynamic value) {
    if (value == null) return null;
    if (value is Uint8List) {
      try {
        final s = utf8.decode(value);
        return jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return _parseJson(value);
  }
}
```

Note: The `sqlite3` package import path may need adjustment. Check the project's existing Drift setup to determine if `package:sqlite3/sqlite3.dart` is the correct import, or if a different FFI binding is used. Also, `path_provider` may not work in unit tests -- use `Directory.systemTemp` as a fallback in test environments.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/shearwater_db_reader_test.dart`

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/universal_import/data/services/shearwater_db_reader.dart \
       test/features/universal_import/data/services/shearwater_db_reader_test.dart
git commit -m "feat: add Shearwater Cloud database reader with tests

Opens .db file as SQLite, queries dive_details and log_data tables,
decompresses binary BLOBs, parses JSON fields."
```

---

## Task 5: Unit Conversions + Conditions Mapping (TDD)

Map Shearwater Cloud field values to Submersion enums and convert units.

**Files:**
- Create: `test/features/universal_import/data/services/shearwater_value_mapper_test.dart`
- Create: `lib/features/universal_import/data/services/shearwater_value_mapper.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_value_mapper.dart';

void main() {
  group('ShearwaterValueMapper', () {
    group('unit conversions', () {
      test('converts PSI to bar', () {
        expect(ShearwaterValueMapper.psiToBar(2960), closeTo(204.1, 0.1));
      });

      test('converts Fahrenheit to Celsius', () {
        expect(ShearwaterValueMapper.fahrenheitToCelsius(72), closeTo(22.2, 0.1));
        expect(ShearwaterValueMapper.fahrenheitToCelsius(32), closeTo(0, 0.1));
      });

      test('converts lbs to kg', () {
        expect(ShearwaterValueMapper.lbsToKg(14), closeTo(6.35, 0.01));
      });

      test('converts feet to meters', () {
        expect(ShearwaterValueMapper.feetToMeters(30), closeTo(9.14, 0.01));
      });

      test('converts mbar to bar', () {
        expect(ShearwaterValueMapper.mbarToBar(1015), closeTo(1.015, 0.001));
      });
    });

    group('conditions mapping', () {
      test('maps environment to waterType', () {
        expect(
          ShearwaterValueMapper.mapWaterType('Ocean/Sea'),
          WaterType.salt,
        );
        expect(ShearwaterValueMapper.mapWaterType('Pool'), WaterType.fresh);
        expect(ShearwaterValueMapper.mapWaterType('Lake'), WaterType.fresh);
        expect(ShearwaterValueMapper.mapWaterType(null), isNull);
        expect(ShearwaterValueMapper.mapWaterType(''), isNull);
      });

      test('maps weather to cloudCover', () {
        expect(
          ShearwaterValueMapper.mapCloudCover('Sunny'),
          CloudCover.clear,
        );
        expect(
          ShearwaterValueMapper.mapCloudCover('Cloudy'),
          CloudCover.mostlyCloudy,
        );
        expect(ShearwaterValueMapper.mapCloudCover('Windy'), isNull);
      });

      test('maps conditions to currentStrength', () {
        expect(
          ShearwaterValueMapper.mapCurrentStrength('Current'),
          CurrentStrength.moderate,
        );
        expect(ShearwaterValueMapper.mapCurrentStrength('Surge'), isNull);
        expect(ShearwaterValueMapper.mapCurrentStrength(null), isNull);
      });

      test('maps visibility to enum', () {
        // Imperial (feet)
        expect(
          ShearwaterValueMapper.mapVisibility('100', isImperial: true),
          Visibility.excellent,
        );
        expect(
          ShearwaterValueMapper.mapVisibility('30', isImperial: true),
          Visibility.moderate,
        );
        expect(
          ShearwaterValueMapper.mapVisibility('10', isImperial: true),
          Visibility.poor,
        );
        // Metric (meters)
        expect(
          ShearwaterValueMapper.mapVisibility('30', isImperial: false),
          Visibility.excellent,
        );
        expect(ShearwaterValueMapper.mapVisibility(null), isNull);
      });
    });

    group('buildExtraNotes', () {
      test('collects unmapped fields into structured notes', () {
        final notes = ShearwaterValueMapper.buildExtraNotes(
          weather: 'Windy',
          conditions: 'Surge',
          dress: 'Wet Suit',
          thermalComfort: 'Warm/Neutral',
          workload: 'Resting',
          problems: null,
          malfunctions: null,
          symptoms: null,
          gasNotes: null,
          gearNotes: null,
          issueNotes: null,
        );
        expect(notes, contains('[Shearwater Cloud]'));
        expect(notes, contains('Weather: Windy'));
        expect(notes, contains('Dress: Wet Suit'));
      });

      test('returns null when no extra fields present', () {
        final notes = ShearwaterValueMapper.buildExtraNotes();
        expect(notes, isNull);
      });
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/shearwater_value_mapper_test.dart`

Expected: FAIL.

- [ ] **Step 3: Write implementation**

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Maps Shearwater Cloud field values to Submersion enums and units.
class ShearwaterValueMapper {
  // -- Unit conversions (all return metric) --

  static double psiToBar(num psi) => psi / 14.5038;

  static double fahrenheitToCelsius(num f) => (f - 32) * 5 / 9;

  static double lbsToKg(num lbs) => lbs * 0.453592;

  static double feetToMeters(num feet) => feet * 0.3048;

  static double mbarToBar(num mbar) => mbar / 1000;

  // -- Conditions mapping --

  static WaterType? mapWaterType(String? environment) {
    if (environment == null || environment.isEmpty) return null;
    return switch (environment) {
      'Ocean/Sea' => WaterType.salt,
      'Pool' || 'Lake' || 'Quarry' || 'River' => WaterType.fresh,
      'Brackish' => WaterType.brackish,
      _ => null,
    };
  }

  static CloudCover? mapCloudCover(String? weather) {
    if (weather == null || weather.isEmpty) return null;
    return switch (weather) {
      'Sunny' || 'Clear' => CloudCover.clear,
      'Partly Cloudy' => CloudCover.partlyCloudy,
      'Cloudy' || 'Overcast' => CloudCover.mostlyCloudy,
      _ => null,
    };
  }

  static CurrentStrength? mapCurrentStrength(String? conditions) {
    if (conditions == null || conditions.isEmpty) return null;
    return switch (conditions) {
      'Current' => CurrentStrength.moderate,
      'Strong Current' => CurrentStrength.strong,
      'Light Current' => CurrentStrength.light,
      _ => null,
    };
  }

  static Visibility? mapVisibility(String? value, {bool isImperial = true}) {
    if (value == null || value.isEmpty) return null;
    final numValue = double.tryParse(value);
    if (numValue == null) return null;

    final meters = isImperial ? feetToMeters(numValue) : numValue;
    if (meters >= 30) return Visibility.excellent;
    if (meters >= 15) return Visibility.good;
    if (meters >= 5) return Visibility.moderate;
    return Visibility.poor;
  }

  /// Builds a structured notes section from unmapped Shearwater fields.
  /// Returns null if no fields have data.
  static String? buildExtraNotes({
    String? weather,
    String? conditions,
    String? dress,
    String? thermalComfort,
    String? workload,
    String? problems,
    String? malfunctions,
    String? symptoms,
    String? gasNotes,
    String? gearNotes,
    String? issueNotes,
  }) {
    // Only include fields that have no direct Submersion mapping.
    // Weather is included if mapCloudCover returns null (e.g., "Windy").
    final entries = <String>[];
    if (weather != null && mapCloudCover(weather) == null) {
      entries.add('Weather: $weather');
    }
    if (conditions != null && mapCurrentStrength(conditions) == null) {
      entries.add('Conditions: $conditions');
    }
    if (dress != null) entries.add('Dress: $dress');
    if (thermalComfort != null) entries.add('Thermal Comfort: $thermalComfort');
    if (workload != null) entries.add('Workload: $workload');
    if (problems != null) entries.add('Problems: $problems');
    if (malfunctions != null) entries.add('Malfunctions: $malfunctions');
    if (symptoms != null) entries.add('Symptoms: $symptoms');
    if (gasNotes != null) entries.add('Gas Notes: $gasNotes');
    if (gearNotes != null) entries.add('Gear Notes: $gearNotes');
    if (issueNotes != null) entries.add('Issue Notes: $issueNotes');

    if (entries.isEmpty) return null;
    return '[Shearwater Cloud]\n${entries.join('\n')}';
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/shearwater_value_mapper_test.dart`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/services/shearwater_value_mapper.dart \
       test/features/universal_import/data/services/shearwater_value_mapper_test.dart
git commit -m "feat: add Shearwater Cloud value mapper with unit conversions

Maps Shearwater environment/weather/conditions to Submersion enums.
Converts PSI->bar, F->C, lbs->kg, ft->m."
```

---

## Task 6: Shearwater Dive Mapper (TDD)

Merges libdivecomputer's ParsedDive with Shearwater metadata into ImportPayload entity maps.

**Files:**
- Create: `test/features/universal_import/data/services/shearwater_dive_mapper_test.dart`
- Create: `lib/features/universal_import/data/services/shearwater_dive_mapper.dart`

- [ ] **Step 1: Write failing tests**

Test the mapper's ability to produce correct entity maps from ShearwaterRawDive + ParsedDive. Use mock/stub ParsedDive objects since FFI won't be available in unit tests.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_mix.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_dive_mapper.dart';

void main() {
  group('ShearwaterDiveMapper', () {
    test('maps dive metadata to entity map', () {
      final rawDive = ShearwaterRawDive(
        diveId: 'test123',
        diveDate: '2025-12-27 14:01:08',
        depth: 26.80,
        averageDepth: 19.45,
        diveLengthTime: 1764,
        diveNumber: '23',
        serialNumber: '69FE56D7',
        location: 'Shark River, NJ, USA',
        site: 'Maclearie Park',
        buddy: 'John Doe',
        notes: 'Great dive',
        environment: 'Ocean/Sea',
        visibility: '30',
        weather: 'Sunny',
        conditions: 'Current',
        airTemperature: '72',
        weight: '14',
        dress: 'Wet Suit',
        footerJson: {'UnitSystem': 1, 'DiveTimeInSeconds': 1764},
        tankProfileData: {
          'GasProfiles': [
            {'O2Percent': 32, 'HePercent': 0, 'CircuitMode': 1},
          ],
          'TankData': [
            {
              'StartPressurePSI': '2960',
              'EndPressurePSI': '1088',
              'GasProfile': {'O2Percent': 32, 'HePercent': 0},
              'DiveTransmitter': {
                'TankIndex': 0,
                'IsOn': true,
                'Name': 'T1',
              },
              'SurfacePressureMBar': 1015.0,
            },
          ],
        },
      );

      final result = ShearwaterDiveMapper.mapDiveMetadata(rawDive);

      expect(result['importSource'], 'shearwater_cloud');
      expect(result['importId'], 'test123');
      expect(result['dateTime'], isA<DateTime>());
      expect(result['maxDepth'], 26.80);
      expect(result['notes'], contains('Great dive'));
      expect(result['diveNumber'], 23);
      expect(result['siteName'], 'Maclearie Park');
    });

    test('maps tanks from TankProfileData JSON', () {
      final rawDive = ShearwaterRawDive(
        diveId: 'test123',
        footerJson: {'UnitSystem': 1},
        tankProfileData: {
          'TankData': [
            {
              'StartPressurePSI': '2960',
              'EndPressurePSI': '1088',
              'GasProfile': {'O2Percent': 32, 'HePercent': 0},
              'DiveTransmitter': {'TankIndex': 0, 'IsOn': true, 'Name': 'T1'},
              'SurfacePressureMBar': 1015.0,
            },
            {
              'StartPressurePSI': '',
              'EndPressurePSI': '',
              'GasProfile': {'O2Percent': 21, 'HePercent': 0},
              'DiveTransmitter': {
                'TankIndex': 1,
                'IsOn': false,
                'Name': 'T2',
              },
              'SurfacePressureMBar': 1015.0,
            },
          ],
        },
      );

      final tanks = ShearwaterDiveMapper.mapTanks(rawDive);

      // Only active tanks (IsOn: true) should be included.
      expect(tanks, hasLength(1));
      expect((tanks[0]['gasMix'] as GasMix).o2, 32);
      expect(tanks[0]['startPressure'], closeTo(204.1, 0.5));
      expect(tanks[0]['endPressure'], closeTo(75.0, 0.5));
      expect(tanks[0]['name'], 'T1');
    });

    test('maps site from location and site fields', () {
      final rawDive = ShearwaterRawDive(
        diveId: 'test123',
        location: 'Shark River, NJ, USA',
        site: 'Maclearie Park',
      );

      final sites = ShearwaterDiveMapper.mapSites([rawDive]);

      expect(sites, hasLength(1));
      expect(sites[0]['name'], 'Maclearie Park');
    });

    test('deduplicates sites by name', () {
      final dives = [
        ShearwaterRawDive(diveId: '1', site: 'Same Site', location: 'NJ'),
        ShearwaterRawDive(diveId: '2', site: 'Same Site', location: 'NJ'),
        ShearwaterRawDive(diveId: '3', site: 'Other Site', location: 'FL'),
      ];

      final sites = ShearwaterDiveMapper.mapSites(dives);
      expect(sites, hasLength(2));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/services/shearwater_dive_mapper_test.dart`

Expected: FAIL.

- [ ] **Step 3: Write implementation**

Create the mapper that converts `ShearwaterRawDive` + optional `ParsedDive` into `ImportPayload` entity maps. The mapper handles:

- Date parsing from `dive_details.DiveDate` string
- Unit detection from `footerJson.UnitSystem` (0=metric, 1=imperial)
- Tank extraction from `TankProfileData` JSON (filter active tanks, convert PSI to bar)
- Site deduplication by name
- Conditions mapping via `ShearwaterValueMapper`
- Notes assembly (user notes + extra unmapped fields)
- Profile sample mapping from `ParsedDive` to the standard `Map<String, dynamic>` format

Key entity map field names to use (matching existing convention):
- `'dateTime'`, `'maxDepth'`, `'avgDepth'`, `'runtime'` (Duration)
- `'waterTemp'`, `'airTemp'`, `'visibility'`, `'rating'`
- `'notes'`, `'buddy'`, `'diveNumber'`
- `'profile'` (List of maps with `'timestamp'`, `'depth'`, `'temperature'`, `'pressure'`)
- `'tanks'` (List of maps with `'gasMix'` as GasMix object, `'startPressure'`, `'endPressure'`, `'name'`)
- `'site'` (Map with `'name'`), `'siteName'`
- `'importSource'`, `'importId'`
- `'diveComputerModel'`, `'diveComputerSerial'`
- `'waterType'`, `'currentStrength'`, `'cloudCover'`
- `'surfacePressure'`, `'weightAmount'`
- `'diveMode'`, `'gradientFactorLow'`, `'gradientFactorHigh'`, `'decoAlgorithm'`

Refer to the Subsurface XML parser and FIT parser for exact conventions.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/services/shearwater_dive_mapper_test.dart`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/services/shearwater_dive_mapper.dart \
       test/features/universal_import/data/services/shearwater_dive_mapper_test.dart
git commit -m "feat: add Shearwater dive mapper for metadata-to-payload conversion

Merges Shearwater Cloud metadata with libdivecomputer parsed profiles
into ImportPayload entity maps."
```

---

## Task 7: ShearwaterCloudParser (TDD)

The main parser class orchestrating the full import flow.

**Files:**
- Create: `test/features/universal_import/data/parsers/shearwater_cloud_parser_test.dart`
- Create: `lib/features/universal_import/data/parsers/shearwater_cloud_parser.dart`

- [ ] **Step 1: Write failing test**

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/parsers/shearwater_cloud_parser.dart';

void main() {
  late Uint8List dbBytes;

  setUpAll(() {
    final file = File('third_party/shearwater_cloud_database.db');
    if (!file.existsSync()) {
      fail('Test fixture not found: third_party/shearwater_cloud_database.db');
    }
    dbBytes = file.readAsBytesSync();
  });

  group('ShearwaterCloudParser', () {
    test('supportedFormats includes shearwaterDb', () {
      final parser = ShearwaterCloudParser();
      expect(parser.supportedFormats, contains(ImportFormat.shearwaterDb));
    });

    test('parse returns payload with 28 dives', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        dbBytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      expect(payload.isNotEmpty, isTrue);
      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(28));
    });

    test('parse includes sites', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        dbBytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      final sites = payload.entitiesOf(ImportEntityType.sites);
      expect(sites, isNotEmpty);
    });

    test('dive entities have required fields', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        dbBytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final dive = dives.firstWhere(
        (d) => d['importId'] == '1676633251758354277',
      );
      expect(dive['dateTime'], isA<DateTime>());
      expect(dive['maxDepth'], isA<double>());
      expect(dive['importSource'], 'shearwater_cloud');
      expect(dive['notes'], contains('PADI Open Water'));
    });

    test('parse returns empty payload for non-Shearwater SQLite', () async {
      // Create a minimal SQLite file without Shearwater tables.
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(Uint8List.fromList([1, 2, 3]));
      expect(payload.isEmpty, isTrue);
      expect(payload.warnings, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/shearwater_cloud_parser_test.dart`

Expected: FAIL.

- [ ] **Step 3: Write implementation**

The parser orchestrates:
1. `ShearwaterDbReader.isShearwaterCloudDb()` validation
2. `ShearwaterDbReader.readDives()` to get raw dive data
3. For each dive: parse filename, attempt FFI call to `parseRawDiveData()`, catch errors for fallback
4. `ShearwaterDiveMapper` to produce entity maps
5. Collect sites and dives into `ImportPayload`

For FFI: instantiate `DiveComputerHostApi()` (the Pigeon bridge). In test environments where native code isn't available, the FFI call will fail -- the fallback path produces metadata-only dives. Tests verify the metadata path; integration tests verify the FFI path.

```dart
import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_dive_mapper.dart';

class ShearwaterCloudParser implements ImportParser {
  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.shearwaterDb];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    // 1. Validate database.
    final isValid = await ShearwaterDbReader.isShearwaterCloudDb(fileBytes);
    if (!isValid) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'File is not a valid Shearwater Cloud database. '
                'Expected dive_details and log_data tables.',
          ),
        ],
      );
    }

    // 2. Read raw dives.
    final rawDives = await ShearwaterDbReader.readDives(fileBytes);
    if (rawDives.isEmpty) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.info,
            message: 'Shearwater Cloud database contains no dives.',
          ),
        ],
      );
    }

    // 3. Map dives to ImportPayload entities.
    final warnings = <ImportWarning>[];
    final diveEntities = <Map<String, dynamic>>[];

    for (final rawDive in rawDives) {
      // Attempt FFI parsing for profile data.
      // ParsedDive is passed to mapper when available.
      final diveMap = await ShearwaterDiveMapper.mapDive(
        rawDive,
        warnings: warnings,
      );
      diveEntities.add(diveMap);
    }

    // 4. Extract unique sites.
    final sites = ShearwaterDiveMapper.mapSites(rawDives);

    // 5. Build payload.
    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (diveEntities.isNotEmpty) {
      entities[ImportEntityType.dives] = diveEntities;
    }
    if (sites.isNotEmpty) {
      entities[ImportEntityType.sites] = sites;
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {'source': 'shearwater_cloud', 'diveCount': rawDives.length},
    );
  }
}
```

Note: The FFI integration (calling `DiveComputerHostApi.parseRawDiveData`) should be attempted inside `ShearwaterDiveMapper.mapDive()`. If it fails (throws `MissingPluginException` in tests, or parse error at runtime), fall back to metadata-only. This keeps the parser testable without native code.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/parsers/shearwater_cloud_parser_test.dart`

Expected: All tests PASS (using metadata fallback path since FFI is not available in test environment).

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/parsers/shearwater_cloud_parser.dart \
       test/features/universal_import/data/parsers/shearwater_cloud_parser_test.dart
git commit -m "feat: add ShearwaterCloudParser implementing ImportParser

Orchestrates DB reading, FFI profile parsing, and metadata mapping
into standard ImportPayload for the import wizard."
```

---

## Task 8: Format Detection + Provider Wiring

Update format detection, import enums, and provider routing.

**Files:**
- Modify: `lib/features/universal_import/data/models/import_enums.dart`
- Modify: `lib/features/universal_import/data/parsers/placeholder_parser.dart`
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart`

- [ ] **Step 1: Mark shearwaterDb as supported in import_enums.dart**

Change the `isSupported` getter:

```dart
  bool get isSupported => switch (this) {
    csv || uddf || subsurfaceXml || fit || shearwaterDb => true,
    _ => false,
  };
```

- [ ] **Step 2: Remove shearwaterDb from PlaceholderParser**

In `placeholder_parser.dart`, remove `ImportFormat.shearwaterDb` from the `supportedFormats` list.

- [ ] **Step 3: Add parser case in universal_import_providers.dart**

In the `_parserFor` method (~line 401-408), add the shearwaterDb case:

```dart
  ImportParser _parserFor(ImportFormat format) {
    return switch (format) {
      ImportFormat.csv => CsvImportParser(customMapping: state.fieldMapping),
      ImportFormat.uddf => UddfImportParser(),
      ImportFormat.subsurfaceXml => SubsurfaceXmlParser(),
      ImportFormat.fit => const FitImportParser(),
      ImportFormat.shearwaterDb => ShearwaterCloudParser(),
      _ => const PlaceholderParser(),
    };
  }
```

Add the import at the top of the file:

```dart
import 'package:submersion/features/universal_import/data/parsers/shearwater_cloud_parser.dart';
```

- [ ] **Step 4: Add SQLite pre-validation in UniversalAdapter**

In `universal_adapter.dart`, find where the format detection result is processed after file selection. Add a check: if the detected format is `ImportFormat.sqlite`, write bytes to temp file, call `ShearwaterDbReader.isShearwaterCloudDb()`, and if true, upgrade the detection result to `ImportFormat.shearwaterDb` / `SourceApp.shearwater` with confidence 0.95.

The exact location and method name depends on the adapter implementation. Look for where `FormatDetector.detect()` result is stored/processed and add the refinement there. This should happen before the source confirmation step is shown to the user.

- [ ] **Step 5: Remove Shearwater export instructions (no longer needed)**

In `import_enums.dart`, the `SourceApp.shearwater` case in `exportInstructions` can be updated or removed since native import is now supported. Change it to:

```dart
    shearwater => null,  // Native .db import now supported
```

- [ ] **Step 6: Run full test suite**

Run: `flutter test`

Expected: All tests pass (3001+ tests).

- [ ] **Step 7: Commit**

```bash
git add lib/features/universal_import/data/models/import_enums.dart \
       lib/features/universal_import/data/parsers/placeholder_parser.dart \
       lib/features/universal_import/presentation/providers/universal_import_providers.dart \
       lib/features/import_wizard/data/adapters/universal_adapter.dart
git commit -m "feat: wire Shearwater Cloud parser into import wizard

Mark shearwaterDb as supported, route to ShearwaterCloudParser in
provider, add SQLite pre-validation for Shearwater detection."
```

---

## Task 9: Format and Verify

Run formatting and analysis on all new/modified code.

- [ ] **Step 1: Format code**

Run: `dart format lib/features/universal_import/data/services/shearwater_filename_parser.dart lib/features/universal_import/data/services/shearwater_db_reader.dart lib/features/universal_import/data/services/shearwater_value_mapper.dart lib/features/universal_import/data/services/shearwater_dive_mapper.dart lib/features/universal_import/data/parsers/shearwater_cloud_parser.dart`

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`

Expected: No analysis issues on new files.

- [ ] **Step 3: Run full test suite**

Run: `flutter test`

Expected: All tests pass.

- [ ] **Step 4: Commit any formatting fixes**

```bash
git add -A
git commit -m "style: format Shearwater Cloud import code"
```

---

## Task 10: Integration Test with Real Database

Verify the full end-to-end flow on macOS with real FFI.

**Files:**
- Create: `test/features/universal_import/data/parsers/shearwater_cloud_parser_integration_test.dart`

- [ ] **Step 1: Write integration test**

This test must be run on macOS (not in CI without native build). It tests the full flow including FFI parsing.

```dart
@TestOn('mac-os')
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/parsers/shearwater_cloud_parser.dart';

void main() {
  late Uint8List dbBytes;

  setUpAll(() {
    final file = File('third_party/shearwater_cloud_database.db');
    dbBytes = file.readAsBytesSync();
  });

  group('ShearwaterCloudParser integration', () {
    test('parses all 28 dives with profile data', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        dbBytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      expect(dives, hasLength(28));

      // At least some dives should have profile data from FFI.
      final divesWithProfiles = dives.where(
        (d) => d['profile'] != null && (d['profile'] as List).isNotEmpty,
      );
      expect(divesWithProfiles, isNotEmpty,
          reason: 'Expected some dives to have profile data from FFI parsing');

      // Check profile sample structure.
      final profileDive = divesWithProfiles.first;
      final samples = profileDive['profile'] as List;
      final firstSample = samples.first as Map<String, dynamic>;
      expect(firstSample['timestamp'], isA<int>());
      expect(firstSample['depth'], isA<double>());
    });

    test('dives with metadata have correct fields', () async {
      final parser = ShearwaterCloudParser();
      final payload = await parser.parse(
        dbBytes,
        options: const ImportOptions(
          sourceApp: SourceApp.shearwater,
          format: ImportFormat.shearwaterDb,
        ),
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final dive = dives.firstWhere(
        (d) => d['importId'] == '1676633251766844068',
      );

      // This is a 1764-second dive to 26.8m with EAN32.
      expect(dive['maxDepth'], closeTo(26.8, 0.5));
      expect((dive['runtime'] as Duration).inSeconds, closeTo(1764, 10));

      // Tank data.
      final tanks = dive['tanks'] as List?;
      expect(tanks, isNotEmpty);
    });
  });
}
```

Note: This test can only run on macOS with the native plugin built. Mark with `@TestOn('mac-os')` or skip in CI. Consider running with `flutter test --platform chrome` excluded.

- [ ] **Step 2: Run the integration test**

Run: `flutter test test/features/universal_import/data/parsers/shearwater_cloud_parser_integration_test.dart`

If FFI is not available in the test runner (common limitation), run a manual verification instead:
1. `flutter run -d macos`
2. Navigate to Import > Select the `.db` file
3. Verify dives appear in the review screen with profile data

- [ ] **Step 3: Commit**

```bash
git add test/features/universal_import/data/parsers/shearwater_cloud_parser_integration_test.dart
git commit -m "test: add Shearwater Cloud parser integration test

Verifies full end-to-end parsing including FFI profile extraction
against the real test fixture database."
```
