# Shearwater Swift GPS Entry/Exit Points Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read the Shearwater Swift's GPS entry and exit fixes from the dive-computer binary during direct download, store them per-dive, and display them as header-map pins + drift line and an opt-in "Surface GPS" collapsible section.

**Architecture:** A single optional pair of GPS points threaded additively through existing layers: patch vendored libdivecomputer so `DC_FIELD_LOCATION` honors its `flags` arg (0=entry/`opening[9]`, 1=exit/`closing[9]`) → read both in the shared C wrapper into `libdc_parsed_dive_t` → four per-platform converters copy into the Pigeon `ParsedDive` → `parsedDiveToDownloaded` → `importProfile` writes four nullable Drift columns → both `Dive` row→entity mappers hydrate `GeoPoint?` fields → UI.

**Tech Stack:** C (libdivecomputer + wrapper), Pigeon (Dart/Swift/Kotlin/C++/GObject), Drift (SQLite), Flutter/Riverpod, flutter_map.

**Reference spec:** `docs/superpowers/specs/2026-05-22-shearwater-swift-gps-entry-exit-design.md`

**Source of truth:** GPS comes ONLY from direct dive-computer download. The Shearwater Cloud `.db` import path is intentionally NOT touched.

**Refinements vs. the spec (decided during planning, from reading the code):**
- **`GeoPoint` is NOT relocated.** `dive.dart` already imports `DiveSite`, so `GeoPoint` is already in scope for the `Dive` entity — relocating it would touch ~24 files for no architectural gain. (Pre-approved option: "leave it where it is.")
- **`DownloadedDive` and the DB layer carry raw `double?` lat/long, not `GeoPoint`.** Keeps the DTO/DB layers primitive (matching their existing style) and avoids a new `dive_computer → dive_sites` import. `GeoPoint` appears only on the `Dive` domain entity.
- **Source-attribution badge on GPS values is INCLUDED (Phase 5).** Wired through the per-source `DiveDataSource` provenance so it behaves exactly like other imported fields' badges — which means it only displays on **multi-computer dives** (`computeAttribution` returns `{}` for a single source). `attribution['gps']` already exists in the service but is gated on a wearable heuristic and consumed nowhere; Phase 5 re-gates it on actual stored coordinates and renders it.

---

## File Structure

**Phase 1 — native extraction**
- Modify: `packages/libdivecomputer_plugin/third_party/libdivecomputer/src/shearwater_predator_parser.c` (DC_FIELD_LOCATION honors `flags`)
- Create: `packages/libdivecomputer_plugin/patches/0001-shearwater-swift-exit-gps.patch` (tracked copy of the submodule diff)
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` (4 GPS doubles on the struct)
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c` (NAN init + read entry/exit)
- Modify: `packages/libdivecomputer_plugin/test/native/test_dive_converter.c` (GPS sentinel test)
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` (4 `double?` fields on `ParsedDive`) + regenerate
- Modify (converters): `windows/dive_converter.cc`, `linux/dive_converter.c`, `darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift`, `android/src/main/cpp/libdc_jni.cpp`, `android/.../LibdcWrapper.kt`, `android/.../DiveComputerHostApiImpl.kt`

**Phase 2 — persistence**
- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart` (4 `double?` fields)
- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart` (copy GPS, reject invalid)
- Modify: `lib/core/database/database.dart` (4 columns, schemaVersion 72→73, migration step)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`importProfile` params + companion)
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart` (pass GPS through)
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`GeoPoint? entryLocation/exitLocation`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (both mappers)

**Phase 3 — geo utility**
- Create: `lib/core/utils/geo_math.dart` (drift distance/bearing)
- Modify: `lib/core/utils/unit_formatter.dart` (`formatDistance`)

**Phase 4 — UI**
- Modify: `lib/features/dive_log/presentation/providers/dive_detail_ui_providers.dart` (surfaceGps expansion state)
- Modify: `lib/core/constants/dive_detail_sections.dart` (enum + default)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (header markers + Surface GPS section)

**Commit/PR boundaries:** Phase 1 is a natural standalone PR (native plumbing, verified by build + the struct test). Phases 2–4 build on it. Per-task commits throughout.

**Note on native testing:** The native unit test (`test_dive_converter.c`) exercises `libdc_parsed_dive_t` struct semantics only — it does NOT link libdivecomputer, so the parser patch (Task 1.1) and the wrapper reads (Task 1.3) cannot be unit-tested in CI. They are verified by (a) successful build and (b) an integration check against a real Swift dive (Task 1.7). The `closing[9]` offset symmetry is an assumption flagged in the spec; Task 1.7 is where it is confirmed.

**Commit messages:** Use conventional style (`feat(scope): ...`). Do NOT add `Co-Authored-By` trailers.

---

## Phase 1 — Native GPS extraction

### Task 1.1: Patch libdivecomputer so DC_FIELD_LOCATION returns entry OR exit

**Files:**
- Modify: `packages/libdivecomputer_plugin/third_party/libdivecomputer/src/shearwater_predator_parser.c` (the `DC_FIELD_LOCATION` case, currently lines ~875-886)
- Create: `packages/libdivecomputer_plugin/patches/0001-shearwater-swift-exit-gps.patch`

- [ ] **Step 1: Replace the DC_FIELD_LOCATION case.** Find this exact block in `shearwater_predator_parser.c`:

```c
		case DC_FIELD_LOCATION:
			if (parser->opening[9] == UNDEFINED || parser->aimode != AI_ON_GPS)
				return DC_STATUS_UNSUPPORTED;
			latitude  = (signed int) array_uint32_be (data + parser->opening[9] + 21);
			longitude = (signed int) array_uint32_be (data + parser->opening[9] + 25);
			if ((latitude == 0 && longitude == 0) ||
				(latitude == -1 && longitude == -1))
				return DC_STATUS_UNSUPPORTED;
			location->latitude  = latitude  / 100000.0;
			location->longitude = longitude / 100000.0;
			location->altitude  = 0.0;
			break;
```

Replace it with (selects `closing[9]` for `flags == 1`, else `opening[9]`):

```c
		case DC_FIELD_LOCATION: {
			// flags: 0 = entry (opening record 9), 1 = exit (closing record 9).
			// Submersion patch (Swift GPS exit point); see patches/0001-shearwater-swift-exit-gps.patch.
			unsigned int gps_rec = (flags == 1) ? parser->closing[9] : parser->opening[9];
			if (gps_rec == UNDEFINED || parser->aimode != AI_ON_GPS)
				return DC_STATUS_UNSUPPORTED;
			latitude  = (signed int) array_uint32_be (data + gps_rec + 21);
			longitude = (signed int) array_uint32_be (data + gps_rec + 25);
			if ((latitude == 0 && longitude == 0) ||
				(latitude == -1 && longitude == -1))
				return DC_STATUS_UNSUPPORTED;
			location->latitude  = latitude  / 100000.0;
			location->longitude = longitude / 100000.0;
			location->altitude  = 0.0;
			break;
		}
```

(`flags`, `latitude`, `longitude`, `location`, `data`, and `parser` are all already in scope in `shearwater_predator_parser_get_field`.)

- [ ] **Step 2: Capture the diff as a tracked patch.** Run from the submodule dir:

Run:
```bash
cd packages/libdivecomputer_plugin/third_party/libdivecomputer
mkdir -p ../../patches
git diff src/shearwater_predator_parser.c > ../../patches/0001-shearwater-swift-exit-gps.patch
cd -
```
Expected: `packages/libdivecomputer_plugin/patches/0001-shearwater-swift-exit-gps.patch` exists and contains the `DC_FIELD_LOCATION` change. This patch documents the local submodule modification so it can be re-applied after a `git submodule update`.

- [ ] **Step 3: Verify the field constant exists in the vendored headers.**

Run: `rg -n 'DC_FIELD_LOCATION|dc_location_t' packages/libdivecomputer_plugin/third_party/libdivecomputer/include/libdivecomputer/parser.h`
Expected: matches showing `DC_FIELD_LOCATION` (an enum value) and `typedef struct dc_location_t { double latitude; double longitude; double altitude; }`.

- [ ] **Step 4: Commit.**

```bash
git add packages/libdivecomputer_plugin/third_party/libdivecomputer/src/shearwater_predator_parser.c packages/libdivecomputer_plugin/patches/0001-shearwater-swift-exit-gps.patch
git commit -m "feat(libdc): expose Shearwater Swift exit GPS via DC_FIELD_LOCATION flags"
```

---

### Task 1.2: Add GPS fields to the shared struct + a sentinel test

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h:177-222` (`libdc_parsed_dive_t`)
- Test: `packages/libdivecomputer_plugin/test/native/test_dive_converter.c`

- [ ] **Step 1: Write the failing test.** In `test_dive_converter.c`, add this function next to `test_temperature_sentinels`:

```c
static void test_gps_sentinels(void) {
    libdc_parsed_dive_t dive = {0};
    dive.entry_latitude = NAN;
    dive.entry_longitude = NAN;
    dive.exit_latitude = 12.34567;
    dive.exit_longitude = -98.76543;

    assert(isnan(dive.entry_latitude));
    assert(isnan(dive.entry_longitude));
    assert(!isnan(dive.exit_latitude));
    assert(dive.exit_latitude == 12.34567);
    assert(dive.exit_longitude == -98.76543);
    printf("PASS: test_gps_sentinels\n");
}
```

And register it in `main()` (add the call before `printf("\nAll tests passed.\n");`):

```c
    test_temperature_sentinels();
    test_gps_sentinels();
```

- [ ] **Step 2: Run test to verify it fails.**

Run:
```bash
cd packages/libdivecomputer_plugin
cmake -B build/test test/native && cmake --build build/test && ctest --test-dir build/test --output-on-failure
cd -
```
Expected: FAIL — compile error, `libdc_parsed_dive_t` has no member named `entry_latitude`.

- [ ] **Step 3: Add the struct fields.** In `libdc_wrapper.h`, inside `typedef struct { ... } libdc_parsed_dive_t;`, immediately after the `double max_temp;` line, add:

```c
    // GPS entry/exit fixes (Shearwater Swift). Decimal degrees, NAN if unavailable.
    double entry_latitude;
    double entry_longitude;
    double exit_latitude;
    double exit_longitude;
```

- [ ] **Step 4: Run test to verify it passes.**

Run:
```bash
cd packages/libdivecomputer_plugin
cmake --build build/test && ctest --test-dir build/test --output-on-failure
cd -
```
Expected: PASS — `PASS: test_gps_sentinels` and `All tests passed.`

- [ ] **Step 5: Commit.**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h packages/libdivecomputer_plugin/test/native/test_dive_converter.c
git commit -m "feat(libdc-plugin): add GPS entry/exit fields to parsed-dive struct"
```

---

### Task 1.3: Read entry/exit GPS in the shared wrapper

**Files:**
- Modify: `packages/libdivecomputer_plugin/macos/Classes/libdc_download.c` (`parse_dive` ~322-340 init; `extract_dive_fields` ~237-320 reads; the `libdc_parse_raw_dive` path ~707)

- [ ] **Step 1: NAN-initialize the new fields.** In `libdc_download.c`, in `parse_dive`, just after the existing `dive->max_temp = NAN;` line, add:

```c
    dive->entry_latitude = NAN;
    dive->entry_longitude = NAN;
    dive->exit_latitude = NAN;
    dive->exit_longitude = NAN;
```

- [ ] **Step 2: Confirm/repair the raw-parse path init.** Inspect `libdc_parse_raw_dive` (the `dc_parser_new2` entrypoint used by `parseRawDiveData`).

Run: `rg -n 'libdc_parse_raw_dive|memset\(dive|->min_temp = NAN' packages/libdivecomputer_plugin/macos/Classes/libdc_download.c`
- If `libdc_parse_raw_dive` does its own `memset(dive, 0, ...)` + sentinel init (rather than calling `parse_dive`), add the same four `NAN` assignments there too, right after its `dive->max_temp = NAN;`.
- If it delegates to `parse_dive`, no change needed.

- [ ] **Step 3: Add the GPS reads.** In `extract_dive_fields`, immediately after the decompression-model extraction block (the `if (dc_parser_get_field(parser, DC_FIELD_DECOMODEL, 0, &decomodel) == DC_STATUS_SUCCESS) { ... }` block) and before the gas-mix extraction, add:

```c
    // Extract GPS entry/exit fixes (Shearwater Swift). flags: 0=entry, 1=exit.
    // Patched libdivecomputer maps these to opening[9]/closing[9] record 9.
    dc_location_t loc = {0};
    if (dc_parser_get_field(parser, DC_FIELD_LOCATION, 0, &loc) == DC_STATUS_SUCCESS) {
        dive->entry_latitude = loc.latitude;
        dive->entry_longitude = loc.longitude;
    }
    if (dc_parser_get_field(parser, DC_FIELD_LOCATION, 1, &loc) == DC_STATUS_SUCCESS) {
        dive->exit_latitude = loc.latitude;
        dive->exit_longitude = loc.longitude;
    }
```

- [ ] **Step 4: Verify the wrapper still compiles** (struct test build links `libdc_wrapper.h` only, so build the macOS plugin or at least compile `libdc_download.c` via the host app in Task 1.7; here just re-run the struct test to ensure no header breakage).

Run:
```bash
cd packages/libdivecomputer_plugin && cmake --build build/test && ctest --test-dir build/test --output-on-failure ; cd -
```
Expected: PASS (struct test unaffected; this step guards against a typo in the header include path).

- [ ] **Step 5: Commit.**

```bash
git add packages/libdivecomputer_plugin/macos/Classes/libdc_download.c
git commit -m "feat(libdc-plugin): read Swift GPS entry/exit into parsed-dive struct"
```

---

### Task 1.4: Add GPS fields to the Pigeon ParsedDive and regenerate

**Files:**
- Modify: `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` (`ParsedDive`, ~119-170)

- [ ] **Step 1: Add the fields.** In `ParsedDive`, add four parameters to the constructor at the end (after `this.rawFingerprint,`):

```dart
    this.entryLatitude,
    this.entryLongitude,
    this.exitLatitude,
    this.exitLongitude,
```

And add four field declarations at the end of the class (after `final Uint8List? rawFingerprint;`):

```dart
  // GPS entry/exit fixes (Shearwater Swift); decimal degrees, null if unavailable.
  final double? entryLatitude;
  final double? entryLongitude;
  final double? exitLatitude;
  final double? exitLongitude;
```

- [ ] **Step 2: Regenerate Pigeon bindings.**

Run:
```bash
cd packages/libdivecomputer_plugin && dart run pigeon --input pigeons/dive_computer_api.dart ; cd -
```
Expected: regenerates `lib/src/generated/dive_computer_api.g.dart`, `ios/Classes/DiveComputerApi.g.swift`, `android/.../DiveComputerApi.g.kt`, `linux/dive_computer_api.g.{h,cc}`, `windows/dive_computer_api.g.{h,cc}`. No errors.

- [ ] **Step 3: Sync the macOS generated Swift.** `macos/Classes/DiveComputerApi.g.swift` is NOT a Pigeon output target (only `ios/` is). Copy the regenerated iOS file over it:

Run:
```bash
cp packages/libdivecomputer_plugin/ios/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/macos/Classes/DiveComputerApi.g.swift
```
Expected: the two files are identical (`diff` reports nothing).

- [ ] **Step 4: Verify analysis passes.**

Run: `cd packages/libdivecomputer_plugin && dart analyze lib/src/generated/dive_computer_api.g.dart ; cd -`
Expected: No issues (the generated Dart now has the four `double?` getters).

- [ ] **Step 5: Commit.**

```bash
git add packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart packages/libdivecomputer_plugin/lib/src/generated/dive_computer_api.g.dart packages/libdivecomputer_plugin/ios/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/macos/Classes/DiveComputerApi.g.swift packages/libdivecomputer_plugin/android packages/libdivecomputer_plugin/linux packages/libdivecomputer_plugin/windows
git commit -m "feat(libdc-plugin): add GPS entry/exit to Pigeon ParsedDive"
```

---

### Task 1.5: Map struct GPS → Pigeon in all four converters

**Files:**
- Modify: `packages/libdivecomputer_plugin/windows/dive_converter.cc` (~218-265)
- Modify: `packages/libdivecomputer_plugin/linux/dive_converter.c` (~218-254)
- Modify: `packages/libdivecomputer_plugin/darwin/Sources/LibDCDarwin/DiveComputerHostApiImpl.swift` (~546-575)
- Modify: `packages/libdivecomputer_plugin/android/src/main/cpp/libdc_jni.cpp` (~719-731), `android/src/main/kotlin/com/submersion/libdivecomputer/LibdcWrapper.kt` (~53-54), `android/src/main/kotlin/com/submersion/libdivecomputer/DiveComputerHostApiImpl.kt` (~345-346, ~391-392)

Because the GPS fields were appended LAST in the Pigeon class (Task 1.4), the regenerated constructors take the four GPS values as the LAST four parameters. Each converter passes them last.

- [ ] **Step 1: Windows.** In `dive_converter.cc`, after the `max_temp` optional locals, add:

```cpp
    std::optional<double> entry_lat =
        std::isnan(dive.entry_latitude) ? std::nullopt
                                        : std::optional<double>(dive.entry_latitude);
    std::optional<double> entry_lon =
        std::isnan(dive.entry_longitude) ? std::nullopt
                                         : std::optional<double>(dive.entry_longitude);
    std::optional<double> exit_lat =
        std::isnan(dive.exit_latitude) ? std::nullopt
                                       : std::optional<double>(dive.exit_latitude);
    std::optional<double> exit_lon =
        std::isnan(dive.exit_longitude) ? std::nullopt
                                        : std::optional<double>(dive.exit_longitude);
```

Then in the `return ParsedDive(...)` call, add these as the final four arguments (after the existing last `raw_fingerprint` argument):

```cpp
        entry_lat ? &*entry_lat : nullptr,
        entry_lon ? &*entry_lon : nullptr,
        exit_lat ? &*exit_lat : nullptr,
        exit_lon ? &*exit_lon : nullptr
```

- [ ] **Step 2: Linux.** In `dive_converter.c`, after the `max_temp` pointer locals, add:

```c
    double entry_lat_val = dive->entry_latitude;
    double* entry_lat = isnan(entry_lat_val) ? NULL : &entry_lat_val;
    double entry_lon_val = dive->entry_longitude;
    double* entry_lon = isnan(entry_lon_val) ? NULL : &entry_lon_val;
    double exit_lat_val = dive->exit_latitude;
    double* exit_lat = isnan(exit_lat_val) ? NULL : &exit_lat_val;
    double exit_lon_val = dive->exit_longitude;
    double* exit_lon = isnan(exit_lon_val) ? NULL : &exit_lon_val;
```

Then add `entry_lat, entry_lon, exit_lat, exit_lon` as the final four arguments to the `libdivecomputer_plugin_parsed_dive_new(...)` call (after `raw_fp_length`).

- [ ] **Step 3: Darwin (iOS/macOS).** In `DiveComputerHostApiImpl.swift`, in the `return ParsedDive(...)` initializer, add these labeled args at the end (after `rawFingerprint:`):

```swift
            entryLatitude: dive.entry_latitude.isNaN ? nil : dive.entry_latitude,
            entryLongitude: dive.entry_longitude.isNaN ? nil : dive.entry_longitude,
            exitLatitude: dive.exit_latitude.isNaN ? nil : dive.exit_latitude,
            exitLongitude: dive.exit_longitude.isNaN ? nil : dive.exit_longitude
```

- [ ] **Step 4: Android JNI getters.** In `libdc_jni.cpp`, after `nativeGetDiveMaxTemp`, add:

```cpp
extern "C" JNIEXPORT jdouble JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveEntryLatitude(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->entry_latitude;
}

extern "C" JNIEXPORT jdouble JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveEntryLongitude(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->entry_longitude;
}

extern "C" JNIEXPORT jdouble JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveExitLatitude(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->exit_latitude;
}

extern "C" JNIEXPORT jdouble JNICALL
Java_com_submersion_libdivecomputer_LibdcWrapper_nativeGetDiveExitLongitude(
    JNIEnv *, jclass, jlong divePtr) {
    auto *dive = reinterpret_cast<const libdc_parsed_dive_t *>(divePtr);
    return dive->exit_longitude;
}
```

- [ ] **Step 5: Android Kotlin externs.** In `LibdcWrapper.kt`, after `nativeGetDiveMaxTemp`, add:

```kotlin
    external fun nativeGetDiveEntryLatitude(divePtr: Long): Double
    external fun nativeGetDiveEntryLongitude(divePtr: Long): Double
    external fun nativeGetDiveExitLatitude(divePtr: Long): Double
    external fun nativeGetDiveExitLongitude(divePtr: Long): Double
```

- [ ] **Step 6: Android assembly site.** In `DiveComputerHostApiImpl.kt`, where `minTemp`/`maxTemp` are fetched, add:

```kotlin
        val entryLat = LibdcWrapper.nativeGetDiveEntryLatitude(divePtr)
        val entryLon = LibdcWrapper.nativeGetDiveEntryLongitude(divePtr)
        val exitLat = LibdcWrapper.nativeGetDiveExitLatitude(divePtr)
        val exitLon = LibdcWrapper.nativeGetDiveExitLongitude(divePtr)
```

And in the `ParsedDive(...)` construction, after `maxTemperatureCelsius = ...,`, add:

```kotlin
            entryLatitude = if (entryLat.isNaN()) null else entryLat,
            entryLongitude = if (entryLon.isNaN()) null else entryLon,
            exitLatitude = if (exitLat.isNaN()) null else exitLat,
            exitLongitude = if (exitLon.isNaN()) null else exitLon,
```

- [ ] **Step 7: Build the host app on the dev platform to verify converters compile.**

Run: `flutter build macos --debug` (or the platform you develop on)
Expected: build succeeds (darwin converter + regenerated bindings compile).

- [ ] **Step 8: Commit.**

```bash
git add packages/libdivecomputer_plugin/windows/dive_converter.cc packages/libdivecomputer_plugin/linux/dive_converter.c packages/libdivecomputer_plugin/darwin packages/libdivecomputer_plugin/android
git commit -m "feat(libdc-plugin): map GPS entry/exit through all platform converters"
```

---

### Task 1.6: (No code) Phase-1 review checkpoint

- [ ] **Step 1:** Confirm `flutter analyze` is clean for the plugin and the app: `flutter analyze`. Expected: No issues.
- [ ] **Step 2:** Confirm the native struct test still passes (Task 1.2 Step 4 command).

---

### Task 1.7: Integration verification against a real Swift dive (manual)

This is the ground-truth check the spec flagged: the `closing[9]` offset symmetry is assumed, not proven.

- [ ] **Step 1:** With a real Swift-equipped dive downloaded (or a saved raw blob re-parsed), add a temporary debug print in `parsedDiveToDownloaded` (Phase 2) or inspect the stored row, and confirm: (a) entry latitude/longitude match the dive's known entry location; (b) exit latitude/longitude differ from entry and match the known exit; (c) a non-Swift dive yields null for all four.
- [ ] **Step 2:** If exit values look wrong (e.g. equal to entry, or implausible coordinates), the `closing[9]` offsets differ from `opening[9]`; capture the raw `closing[9]` bytes and adjust the `+21`/`+25` offsets in Task 1.1, then re-run. Remove the temporary debug print before committing.

---

## Phase 2 — Persistence

### Task 2.1: Carry GPS on DownloadedDive and map it from ParsedDive

**Files:**
- Modify: `lib/features/dive_computer/domain/entities/downloaded_dive.dart` (~85-169)
- Modify: `lib/features/dive_computer/data/services/parsed_dive_mapper.dart`
- Test: `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`

- [ ] **Step 1: Write the failing test.** Create `test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/features/dive_computer/data/services/parsed_dive_mapper.dart';

pigeon.ParsedDive _base({
  double? entryLat,
  double? entryLon,
  double? exitLat,
  double? exitLon,
}) {
  return pigeon.ParsedDive(
    fingerprint: 'fp',
    dateTimeYear: 2026,
    dateTimeMonth: 5,
    dateTimeDay: 22,
    dateTimeHour: 9,
    dateTimeMinute: 14,
    dateTimeSecond: 0,
    maxDepthMeters: 30.0,
    avgDepthMeters: 0.0,
    durationSeconds: 2280,
    samples: const [],
    tanks: const [],
    gasMixes: const [],
    events: const [],
    entryLatitude: entryLat,
    entryLongitude: entryLon,
    exitLatitude: exitLat,
    exitLongitude: exitLon,
  );
}

void main() {
  group('parsedDiveToDownloaded GPS', () {
    test('copies entry and exit coordinates', () {
      final d = parsedDiveToDownloaded(
        _base(entryLat: 12.34567, entryLon: 98.76543, exitLat: 12.34612, exitLon: 98.76489),
      );
      expect(d.entryLatitude, 12.34567);
      expect(d.entryLongitude, 98.76543);
      expect(d.exitLatitude, 12.34612);
      expect(d.exitLongitude, 98.76489);
    });

    test('null when absent', () {
      final d = parsedDiveToDownloaded(_base());
      expect(d.entryLatitude, isNull);
      expect(d.exitLatitude, isNull);
    });

    test('rejects sentinel (0,0) and (-1,-1) coordinates', () {
      final zero = parsedDiveToDownloaded(_base(entryLat: 0.0, entryLon: 0.0));
      expect(zero.entryLatitude, isNull);
      expect(zero.entryLongitude, isNull);
      final neg = parsedDiveToDownloaded(_base(exitLat: -1.0, exitLon: -1.0));
      expect(neg.exitLatitude, isNull);
      expect(neg.exitLongitude, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`
Expected: FAIL — `DownloadedDive` has no getter `entryLatitude` (compile error).

- [ ] **Step 3: Add fields to DownloadedDive.** In `downloaded_dive.dart`, add field declarations after `maxTemperature` (line ~108):

```dart
  /// GPS entry fix latitude/longitude in decimal degrees (Shearwater Swift), if available
  final double? entryLatitude;
  final double? entryLongitude;

  /// GPS exit fix latitude/longitude in decimal degrees (Shearwater Swift), if available
  final double? exitLatitude;
  final double? exitLongitude;
```

And add to the constructor (after `this.maxTemperature,`):

```dart
    this.entryLatitude,
    this.entryLongitude,
    this.exitLatitude,
    this.exitLongitude,
```

- [ ] **Step 4: Map them in parsedDiveToDownloaded.** In `parsed_dive_mapper.dart`, add a private helper at the bottom of the file:

```dart
/// Returns the value unless it is null or a libdivecomputer sentinel
/// (0,0) / (-1,-1) invalid-fix marker (checked as a lat/long pair).
double? _validCoord(double? value, double? other) {
  if (value == null || other == null) return null;
  if (value == 0.0 && other == 0.0) return null;
  if (value == -1.0 && other == -1.0) return null;
  return value;
}
```

Then inside the `return DownloadedDive(` invocation, after `maxTemperature: maxTemp,`, add:

```dart
    entryLatitude: _validCoord(parsed.entryLatitude, parsed.entryLongitude),
    entryLongitude: _validCoord(parsed.entryLongitude, parsed.entryLatitude),
    exitLatitude: _validCoord(parsed.exitLatitude, parsed.exitLongitude),
    exitLongitude: _validCoord(parsed.exitLongitude, parsed.exitLatitude),
```

- [ ] **Step 5: Run test to verify it passes.**

Run: `flutter test test/features/dive_computer/data/services/parsed_dive_mapper_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit.**

```bash
git add lib/features/dive_computer/domain/entities/downloaded_dive.dart lib/features/dive_computer/data/services/parsed_dive_mapper.dart test/features/dive_computer/data/services/parsed_dive_mapper_test.dart
git commit -m "feat(dive-computer): carry GPS entry/exit on DownloadedDive"
```

---

### Task 2.2: Add Drift columns + migration (schema 72 → 73)

**Files:**
- Modify: `lib/core/database/database.dart` (`Dives` table ~108-252; `currentSchemaVersion` :1450; `migrationVersions` :1455-1526; `onUpgrade` end)
- Test: `test/core/database/migration_v73_gps_test.dart`

- [ ] **Step 1: Add the columns to the Dives table.** In `database.dart`, in `class Dives extends Table`, after the `weatherFetchedAt` column (line ~242), add:

```dart
  // GPS entry/exit fixes from dive computer (Shearwater Swift). Decimal degrees.
  RealColumn get entryLatitude => real().nullable()();
  RealColumn get entryLongitude => real().nullable()();
  RealColumn get exitLatitude => real().nullable()();
  RealColumn get exitLongitude => real().nullable()();
```

- [ ] **Step 2: Bump the schema version.** Change line 1450 from:

```dart
  static const int currentSchemaVersion = 72;
```
to:
```dart
  static const int currentSchemaVersion = 73;
```

- [ ] **Step 3: Append to migrationVersions.** In the `migrationVersions` list (ends with `72,` near line 1525), add `73,` after it.

- [ ] **Step 4: Add the migration step.** At the END of the `onUpgrade` block (after the last `if (from < 72) await reportProgress();`), add:

```dart
        if (from < 73) {
          await customStatement(
            'ALTER TABLE dives ADD COLUMN entry_latitude REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN entry_longitude REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN exit_latitude REAL',
          );
          await customStatement(
            'ALTER TABLE dives ADD COLUMN exit_longitude REAL',
          );
        }
        if (from < 73) await reportProgress();
```

- [ ] **Step 5: Regenerate Drift code.**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `lib/core/database/database.g.dart` with the new columns on `Dive` (row) and `DivesCompanion`. No errors.

- [ ] **Step 6: Write the migration test.** Create `test/core/database/migration_v73_gps_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v73 adds GPS columns and a dive round-trips them', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'gps-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
            entryLatitude: const Value(12.34567),
            entryLongitude: const Value(98.76543),
            exitLatitude: const Value(12.34612),
            exitLongitude: const Value(98.76489),
          ),
        );

    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('gps-1'))).getSingle();
    expect(row.entryLatitude, 12.34567);
    expect(row.exitLongitude, 98.76489);
  });
}
```

Note: verify the test DB constructor name. If `AppDatabase.forTesting` does not exist, use the in-memory constructor the existing DB tests use — check with `rg -n 'AppDatabase\\(|forTesting|NativeDatabase.memory' test/core/database` and mirror that pattern. Also confirm the class name (`AppDatabase`) via `rg -n 'class .*extends .*GeneratedDatabase|@DriftDatabase' lib/core/database/database.dart`.

- [ ] **Step 7: Run test to verify it passes.**

Run: `flutter test test/core/database/migration_v73_gps_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit.**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v73_gps_test.dart
git commit -m "feat(db): add GPS entry/exit columns to dives (schema v73)"
```

---

### Task 2.3: Thread GPS through importProfile into the dive row

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`importProfile` signature ~804-827; `DivesCompanion` insert ~866-890)
- Modify: `lib/features/dive_computer/data/services/dive_import_service.dart` (`_importNewDive` ~461-484)
- Test: add a case to the existing dive-computer repository import test (find via `rg -n 'importProfile' test`)

- [ ] **Step 1: Write the failing test.** Locate the existing import test that calls `importProfile` (`rg -ln 'importProfile' test`). Add a test that imports a `DownloadedDive` (or calls `importProfile` directly) with entry/exit coordinates and asserts the stored `dives` row has them. Example (adapt imports/fixtures to the existing test file's helpers):

```dart
test('importProfile persists GPS entry/exit', () async {
  final diveId = await repository.importProfile(
    computerId: computerId,
    profileStartTime: DateTime.utc(2026, 5, 22, 9, 14),
    points: const [],
    durationSeconds: 2280,
    maxDepth: 30.0,
    entryLatitude: 12.34567,
    entryLongitude: 98.76543,
    exitLatitude: 12.34612,
    exitLongitude: 98.76489,
  );

  final row = await (db.select(db.dives)..where((t) => t.id.equals(diveId))).getSingle();
  expect(row.entryLatitude, 12.34567);
  expect(row.exitLongitude, 98.76489);
});
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `flutter test <path to that test file>`
Expected: FAIL — `importProfile` has no named parameter `entryLatitude`.

- [ ] **Step 3: Add parameters to importProfile.** In `dive_computer_repository_impl.dart`, add to the `importProfile({...})` parameter list (after `libdivecomputerVersion,`):

```dart
    double? entryLatitude,
    double? entryLongitude,
    double? exitLatitude,
    double? exitLongitude,
```

- [ ] **Step 4: Write them into the companion.** In the `DivesCompanion(...)` insert, after `updatedAt: Value(now),`, add:

```dart
                entryLatitude: Value(entryLatitude),
                entryLongitude: Value(entryLongitude),
                exitLatitude: Value(exitLatitude),
                exitLongitude: Value(exitLongitude),
```

- [ ] **Step 5: Pass through from the import service.** In `dive_import_service.dart`, in the `_repository.importProfile(...)` call inside `_importNewDive`, after `libdivecomputerVersion: libdivecomputerVersion,`, add:

```dart
      entryLatitude: dive.entryLatitude,
      entryLongitude: dive.entryLongitude,
      exitLatitude: dive.exitLatitude,
      exitLongitude: dive.exitLongitude,
```

- [ ] **Step 6: Run test to verify it passes.**

Run: `flutter test <path to that test file>`
Expected: PASS.

- [ ] **Step 7: Commit.**

```bash
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart lib/features/dive_computer/data/services/dive_import_service.dart test/<path>
git commit -m "feat(import): persist Swift GPS entry/exit on downloaded dives"
```

---

### Task 2.4: Expose GPS on the Dive entity and hydrate both mappers

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (fields ~36, constructor ~147, copyWith ~478 + ~563, props ~629-714)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`_mapRowToDive` return ~2388-2600 AND `_mapRowToDiveWithPreloadedData` construction ~2046)
- Test: `test/features/dive_log/domain/entities/dive_gps_test.dart`

- [ ] **Step 1: Write the failing test.** Create `test/features/dive_log/domain/entities/dive_gps_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  test('Dive carries entry/exit GeoPoints and copyWith preserves them', () {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026, 5, 22, 9, 14),
      entryLocation: const GeoPoint(12.34567, 98.76543),
      exitLocation: const GeoPoint(12.34612, 98.76489),
    );
    expect(dive.entryLocation, const GeoPoint(12.34567, 98.76543));
    expect(dive.exitLocation, const GeoPoint(12.34612, 98.76489));

    final copy = dive.copyWith(maxDepth: 30);
    expect(copy.entryLocation, const GeoPoint(12.34567, 98.76543));
    expect(copy.exitLocation, const GeoPoint(12.34612, 98.76489));
  });
}
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `flutter test test/features/dive_log/domain/entities/dive_gps_test.dart`
Expected: FAIL — `Dive` has no named parameter `entryLocation`.

- [ ] **Step 3: Add fields to the Dive entity.** `dive.dart` already imports `DiveSite` (so `GeoPoint` is in scope). Add field declarations after `final double? avgDepth;` (line ~25):

```dart
  // GPS entry/exit fixes from the dive computer (Shearwater Swift)
  final GeoPoint? entryLocation;
  final GeoPoint? exitLocation;
```

Add to the constructor (after `this.avgDepth,`):

```dart
    this.entryLocation,
    this.exitLocation,
```

Add to the `copyWith` parameter list (after `double? avgDepth,`):

```dart
    GeoPoint? entryLocation,
    GeoPoint? exitLocation,
```

Add to the `copyWith` return (after `avgDepth: avgDepth ?? this.avgDepth,`):

```dart
      entryLocation: entryLocation ?? this.entryLocation,
      exitLocation: exitLocation ?? this.exitLocation,
```

Add to `props` (the `List<Object?> get props => [...]` at ~629): add `entryLocation,` and `exitLocation,` to the list.

- [ ] **Step 4: Run the entity test to verify it passes.**

Run: `flutter test test/features/dive_log/domain/entities/dive_gps_test.dart`
Expected: PASS.

- [ ] **Step 5: Hydrate in `_mapRowToDive`.** In `dive_repository_impl.dart`, in the `return domain.Dive(` block, after `avgDepth: row.avgDepth,` add:

```dart
      entryLocation: row.entryLatitude != null && row.entryLongitude != null
          ? domain.GeoPoint(row.entryLatitude!, row.entryLongitude!)
          : null,
      exitLocation: row.exitLatitude != null && row.exitLongitude != null
          ? domain.GeoPoint(row.exitLatitude!, row.exitLongitude!)
          : null,
```

- [ ] **Step 6: Hydrate in `_mapRowToDiveWithPreloadedData`.** Find the `domain.Dive(` construction in this second mapper (~2046) and add the SAME two `entryLocation:`/`exitLocation:` lines after its `avgDepth:` argument. (Both mappers must set it — `getAllDives` uses the preloaded variant.)

- [ ] **Step 7: Write a hydration test.** Add to `test/features/dive_log/data/repositories/` (mirror an existing repository test's setup) a test that inserts a dives row with the four GPS columns and asserts `getDiveById` returns a `Dive` whose `entryLocation`/`exitLocation` match. If a suitable repository test harness exists, extend it; otherwise create `dive_repository_gps_test.dart` modeled on the nearest existing repository test (`rg -ln '_mapRowToDive|getDiveById' test`).

- [ ] **Step 8: Run tests.**

Run: `flutter test test/features/dive_log/`
Expected: PASS (including the new hydration test).

- [ ] **Step 9: Commit.**

```bash
git add lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/domain/entities/dive_gps_test.dart test/features/dive_log/data/repositories/
git commit -m "feat(dive-log): expose GPS entry/exit on Dive entity and hydrate from DB"
```

---

## Phase 3 — Geo utility (drift distance + bearing)

### Task 3.1: Haversine distance + bearing helpers

**Files:**
- Create: `lib/core/utils/geo_math.dart`
- Test: `test/core/utils/geo_math_test.dart`

- [ ] **Step 1: Write the failing test.** Create `test/core/utils/geo_math_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('geo_math', () {
    test('distanceMeters: ~111m for 0.001 deg of longitude at equator', () {
      final d = distanceMeters(const GeoPoint(0, 0), const GeoPoint(0, 0.001));
      expect(d, closeTo(111.3, 1.0));
    });

    test('distanceMeters: zero for identical points', () {
      expect(distanceMeters(const GeoPoint(10, 20), const GeoPoint(10, 20)), closeTo(0, 0.001));
    });

    test('initialBearingDegrees: due north is 0', () {
      expect(initialBearingDegrees(const GeoPoint(0, 0), const GeoPoint(1, 0)), closeTo(0, 0.5));
    });

    test('initialBearingDegrees: due east is 90', () {
      expect(initialBearingDegrees(const GeoPoint(0, 0), const GeoPoint(0, 1)), closeTo(90, 0.5));
    });

    test('formatBearing: zero-padded degrees + 8-point cardinal', () {
      expect(formatBearing(0), '000° N');
      expect(formatBearing(42), '042° NE');
      expect(formatBearing(90), '090° E');
      expect(formatBearing(225), '225° SW');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `flutter test test/core/utils/geo_math_test.dart`
Expected: FAIL — `geo_math.dart` does not exist.

- [ ] **Step 3: Implement the utility.** Create `lib/core/utils/geo_math.dart`:

```dart
import 'dart:math' as math;

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

const double _earthRadiusMeters = 6371000.0;

double _toRadians(double degrees) => degrees * math.pi / 180.0;

/// Great-circle distance between two points in meters (Haversine).
double distanceMeters(GeoPoint a, GeoPoint b) {
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLon = _toRadians(b.longitude - a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return _earthRadiusMeters * c;
}

/// Initial (forward) bearing from [a] to [b] in degrees, normalized to 0-360.
double initialBearingDegrees(GeoPoint a, GeoPoint b) {
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final dLon = _toRadians(b.longitude - a.longitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final bearing = math.atan2(y, x) * 180.0 / math.pi;
  return (bearing + 360.0) % 360.0;
}

const List<String> _cardinals = [
  'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW',
];

/// Formats a bearing as zero-padded degrees + 8-point cardinal, e.g. "042° NE".
String formatBearing(double degrees) {
  final normalized = (degrees % 360 + 360) % 360;
  final index = (((normalized + 22.5) % 360) ~/ 45);
  final padded = normalized.round().toString().padLeft(3, '0');
  return '$padded° ${_cardinals[index]}';
}
```

- [ ] **Step 4: Run test to verify it passes.**

Run: `flutter test test/core/utils/geo_math_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit.**

```bash
git add lib/core/utils/geo_math.dart test/core/utils/geo_math_test.dart
git commit -m "feat(core): add geo distance/bearing helpers for dive drift"
```

---

### Task 3.2: formatDistance on UnitFormatter

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart` (~20-36)
- Test: `test/core/utils/unit_formatter_distance_test.dart`

- [ ] **Step 1: Write the failing test.** Create `test/core/utils/unit_formatter_distance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  test('formatDistance respects depth unit (meters/feet)', () {
    final metric = UnitFormatter(const AppSettings(depthUnit: DepthUnit.meters));
    expect(metric.formatDistance(120), '120m');

    final imperial = UnitFormatter(const AppSettings(depthUnit: DepthUnit.feet));
    expect(imperial.formatDistance(120), '394ft');
  });
}
```

Note: confirm `AppSettings` has a const constructor with a `depthUnit` named parameter (`rg -n 'class AppSettings|const AppSettings|depthUnit' lib/features/settings/presentation/providers/settings_providers.dart` and the file it re-exports). If `AppSettings` requires more params, build it via its existing test helper / `copyWith` instead, matching how other unit_formatter tests construct it (`rg -ln 'UnitFormatter(' test`).

- [ ] **Step 2: Run test to verify it fails.**

Run: `flutter test test/core/utils/unit_formatter_distance_test.dart`
Expected: FAIL — `formatDistance` is not defined.

- [ ] **Step 3: Implement formatDistance.** In `unit_formatter.dart`, after `convertDepth` (line ~36), add:

```dart
  /// Format a horizontal distance (meters) in the diver's depth unit (m/ft).
  /// Used for surface drift between GPS entry and exit points.
  String formatDistance(double meters, {int decimals = 0}) {
    final converted = DepthUnit.meters.convert(meters, settings.depthUnit);
    return '${converted.toStringAsFixed(decimals)}${settings.depthUnit.symbol}';
  }
```

- [ ] **Step 4: Run test to verify it passes.**

Run: `flutter test test/core/utils/unit_formatter_distance_test.dart`
Expected: PASS (120 m → `120m`; 120 m × 3.28084 = 393.7 → `394ft`).

- [ ] **Step 5: Commit.**

```bash
git add lib/core/utils/unit_formatter.dart test/core/utils/unit_formatter_distance_test.dart
git commit -m "feat(core): add formatDistance for drift readout"
```

---

## Phase 4 — UI

### Task 4.1: Add Surface GPS expansion state to the UI provider

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_detail_ui_providers.dart`
- Test: `test/features/dive_log/presentation/providers/dive_detail_ui_providers_test.dart` (extend if present)

- [ ] **Step 1: Write the failing test.** Create/extend `test/features/dive_log/presentation/providers/dive_detail_ui_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';

void main() {
  test('CollapsibleSectionState defaults surfaceGps to collapsed', () {
    const s = CollapsibleSectionState();
    expect(s.surfaceGpsExpanded, false);
  });

  test('copyWith updates surfaceGpsExpanded', () {
    const s = CollapsibleSectionState();
    expect(s.copyWith(surfaceGpsExpanded: true).surfaceGpsExpanded, true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `flutter test test/features/dive_log/presentation/providers/dive_detail_ui_providers_test.dart`
Expected: FAIL — `surfaceGpsExpanded` not defined.

- [ ] **Step 3: Extend the provider.** In `dive_detail_ui_providers.dart`:

Add a key in `DiveDetailUiKeys`:
```dart
  static const String surfaceGpsSectionExpanded =
      'dive_detail_surface_gps_expanded';
```

Add the field + default in `CollapsibleSectionState` (after `tideExpanded`):
```dart
  final bool surfaceGpsExpanded;
```
In the constructor (after `this.tideExpanded = true,`):
```dart
    this.surfaceGpsExpanded = false,
```
In `copyWith` params (after `bool? tideExpanded,`):
```dart
    bool? surfaceGpsExpanded,
```
In `copyWith` body (after `tideExpanded: tideExpanded ?? this.tideExpanded,`):
```dart
      surfaceGpsExpanded: surfaceGpsExpanded ?? this.surfaceGpsExpanded,
```

In `_loadState` (after the `tideExpanded:` line):
```dart
      surfaceGpsExpanded:
          _prefs.getBool(DiveDetailUiKeys.surfaceGpsSectionExpanded) ?? false,
```

Add the setter (after `setTideExpanded`):
```dart
  Future<void> setSurfaceGpsExpanded(bool expanded) async {
    state = state.copyWith(surfaceGpsExpanded: expanded);
    await _prefs.setBool(DiveDetailUiKeys.surfaceGpsSectionExpanded, expanded);
  }
```

Add the convenience provider (after `tideSectionExpandedProvider`):
```dart
final surfaceGpsSectionExpandedProvider = Provider<bool>((ref) {
  return ref.watch(
    collapsibleSectionProvider.select((s) => s.surfaceGpsExpanded),
  );
});
```

- [ ] **Step 4: Run test to verify it passes.**

Run: `flutter test test/features/dive_log/presentation/providers/dive_detail_ui_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/features/dive_log/presentation/providers/dive_detail_ui_providers.dart test/features/dive_log/presentation/providers/dive_detail_ui_providers_test.dart
git commit -m "feat(dive-log): add Surface GPS section expansion state"
```

---

### Task 4.2: Register the Surface GPS section id

**Files:**
- Modify: `lib/core/constants/dive_detail_sections.dart` (enum :9-26; defaults :152-173)
- Test: `test/core/constants/dive_detail_sections_test.dart` (extend if present)

- [ ] **Step 1: Write the failing test.** Create/extend `test/core/constants/dive_detail_sections_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';

void main() {
  test('surfaceGps is a known section and present in defaults', () {
    expect(DiveDetailSectionId.values.contains(DiveDetailSectionId.surfaceGps), true);
    expect(
      DiveDetailSectionConfig.defaultSections.any((c) => c.id == DiveDetailSectionId.surfaceGps),
      true,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `flutter test test/core/constants/dive_detail_sections_test.dart`
Expected: FAIL — `surfaceGps` is not a member of `DiveDetailSectionId`.

- [ ] **Step 3: Add the enum value + default.** In `dive_detail_sections.dart`, add `surfaceGps,` to the `DiveDetailSectionId` enum (place it after `tide,` so it appears near the other map/condition sections by default):

```dart
  tide,
  surfaceGps,
```

And in `defaultSections`, add after the `tide` entry:

```dart
    DiveDetailSectionConfig(id: DiveDetailSectionId.surfaceGps, visible: true),
```

(`ensureAllSections` already appends any missing enum value as `visible: true`, so existing users' saved configs gain the section automatically — no migration needed.)

- [ ] **Step 4: Run test to verify it passes.**

Run: `flutter test test/core/constants/dive_detail_sections_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/core/constants/dive_detail_sections.dart test/core/constants/dive_detail_sections_test.dart
git commit -m "feat(dive-log): register Surface GPS dive-detail section"
```

---

### Task 4.3: Header map — entry/exit markers + drift polyline

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_buildHeaderSection` ~739-993)
- Test: `test/features/dive_log/presentation/pages/dive_header_gps_test.dart`

The header currently shows a map only when `dive.site?.location != null`, centered on the site, with a single site marker, wrapped in an InkWell that navigates to the site. We broaden it to also show when GPS exists, add entry/exit markers + a dotted drift polyline, and keep site navigation only when a site exists.

- [ ] **Step 1: Write the failing widget test.** Create `test/features/dive_log/presentation/pages/dive_header_gps_test.dart`. Model the harness (ProviderScope overrides, MaterialApp, pumping the detail page or the header widget) on the nearest existing dive_detail widget test (`rg -ln 'dive_detail' test/features/dive_log/presentation`). The assertions:

```dart
// Pump the dive detail page for a dive that has entryLocation + exitLocation
// but NO site, then:
expect(find.byType(FlutterMap), findsOneWidget);          // map shows without a site
expect(find.byKey(const ValueKey('gps-entry-marker')), findsOneWidget);
expect(find.byKey(const ValueKey('gps-exit-marker')), findsOneWidget);

// Pump a dive with neither site nor GPS:
expect(find.byType(FlutterMap), findsNothing);
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `flutter test test/features/dive_log/presentation/pages/dive_header_gps_test.dart`
Expected: FAIL — no map / no markers for the GPS-only dive (current code keys off the site only).

- [ ] **Step 3: Broaden the show condition.** In `_buildHeaderSection`, change:

```dart
    final hasLocation = dive.site?.location != null;
```
to:
```dart
    final hasSiteLocation = dive.site?.location != null;
    final hasGps = dive.entryLocation != null || dive.exitLocation != null;
    final hasLocation = hasSiteLocation || hasGps;
```

- [ ] **Step 4: Compute center + markers + polyline.** Replace the `final site = dive.site!;` / `final siteLocation = LatLng(...)` block (the part after the `if (!hasLocation) { return Card(...); }` early-return) with logic that does not assume a site exists:

```dart
    final entry = dive.entryLocation;
    final exit = dive.exitLocation;
    final siteLoc = dive.site?.location;

    // Center preference: entry, else exit, else site.
    final LatLng mapCenter = entry != null
        ? LatLng(entry.latitude, entry.longitude)
        : exit != null
            ? LatLng(exit.latitude, exit.longitude)
            : LatLng(siteLoc!.latitude, siteLoc.longitude);

    final markers = <Marker>[
      if (siteLoc != null && !hasGps)
        Marker(
          point: LatLng(siteLoc.latitude, siteLoc.longitude),
          width: 32,
          height: 32,
          child: _mapPin(colorScheme, Icons.scuba_diving, colorScheme.primary),
        ),
      if (entry != null)
        Marker(
          key: const ValueKey('gps-entry-marker'),
          point: LatLng(entry.latitude, entry.longitude),
          width: 28,
          height: 28,
          child: _mapPin(colorScheme, Icons.south, const Color(0xFF34C759)),
        ),
      if (exit != null)
        Marker(
          key: const ValueKey('gps-exit-marker'),
          point: LatLng(exit.latitude, exit.longitude),
          width: 28,
          height: 28,
          child: _mapPin(colorScheme, Icons.north, const Color(0xFFFF9F0A)),
        ),
    ];
```

Add this private helper method to the State class (near the other `_build*` helpers):

```dart
  Widget _mapPin(ColorScheme colorScheme, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.onPrimary, width: 2),
      ),
      child: Center(
        child: Icon(icon, size: 14, color: colorScheme.onPrimary),
      ),
    );
  }
```

- [ ] **Step 5: Update the FlutterMap children.** In the `FlutterMap` widget, change `initialCenter: siteLocation,` to `initialCenter: mapCenter,`. Replace the existing single-marker `MarkerLayer(markers: [ Marker(...) ])` with `MarkerLayer(markers: markers),`, and add a polyline layer BEFORE the `MarkerLayer` (so the line sits under the pins) when both points exist:

```dart
                    if (entry != null && exit != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              LatLng(entry.latitude, entry.longitude),
                              LatLng(exit.latitude, exit.longitude),
                            ],
                            strokeWidth: 3.0,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            pattern: const StrokePattern.dotted(),
                          ),
                        ],
                      ),
```

- [ ] **Step 6: Guard the site-only interactions.** The InkWell `onTap: () => context.push('/sites/${site.id}')`, the `Semantics` label using `site.name`, and the "View Site" button all assume a site. Wrap the navigation/`Semantics`/button so they only apply when `dive.site != null`. Concretely: change `final site = dive.site!;` usages to a nullable `final site = dive.site;` and guard:
  - `onTap: site != null ? () => context.push('/sites/${site.id}') : null`
  - The `Semantics(button: site != null, label: site != null ? '...${site.name}' : '', child: ...)`
  - Wrap the "View Site" `Positioned(...)` button in `if (site != null) ...`.

Confirm the `LatLng` and `PolylineLayer`/`StrokePattern` imports are present (flutter_map + latlong2 are already imported in this file for the existing map).

- [ ] **Step 7: Run test to verify it passes.**

Run: `flutter test test/features/dive_log/presentation/pages/dive_header_gps_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit.**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_header_gps_test.dart
git commit -m "feat(dive-log): show entry/exit pins and drift line on header map"
```

---

### Task 4.4: "Surface GPS" collapsible section

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_sectionBuilders` ~238-417; add `_buildSurfaceGpsSection`)
- Test: `test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart`

- [ ] **Step 1: Write the failing widget test.** Create `test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart`. Model the harness on an existing dive_detail section test. Assertions:

```dart
// Dive with entry+exit GPS, section expanded:
expect(find.text('Surface GPS'), findsOneWidget);
expect(find.textContaining('Drift'), findsWidgets);     // "Drift" detail-row label (expanded)
expect(find.text('Open in Maps'), findsOneWidget);

// Dive with NO GPS: the section is absent.
expect(find.text('Surface GPS'), findsNothing);
```

- [ ] **Step 2: Run test to verify it fails.**

Run: `flutter test test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart`
Expected: FAIL — no "Surface GPS" text (section not built yet).

- [ ] **Step 3: Register the section builder.** In `_sectionBuilders`, add an entry (place it after the `tide` entry to match the enum order):

```dart
      DiveDetailSectionId.surfaceGps: () {
        if (dive.entryLocation == null && dive.exitLocation == null) return [];
        return [
          const SizedBox(height: 24),
          _buildSurfaceGpsSection(context, ref, dive, units),
        ];
      },
```

- [ ] **Step 4: Implement the section builder.** Add this method to the State class. It mirrors `_buildTideCard`'s `CollapsibleCardSection` usage and uses `surfaceGpsSectionExpandedProvider` / `setSurfaceGpsExpanded`:

```dart
  Widget _buildSurfaceGpsSection(
    BuildContext context,
    WidgetRef ref,
    Dive dive,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isExpanded = ref.watch(surfaceGpsSectionExpandedProvider);

    final entry = dive.entryLocation;
    final exit = dive.exitLocation;

    String? driftText;
    if (entry != null && exit != null) {
      final dist = distanceMeters(entry, exit);
      final bearing = initialBearingDegrees(entry, exit);
      driftText = '${units.formatDistance(dist)} · ${formatBearing(bearing)}';
    }

    final collapsedSubtitle = driftText != null
        ? '${context.l10n.diveLog_detail_label_drift}: $driftText'
        : (entry != null
              ? context.l10n.diveLog_detail_surfaceGps_entryOnly
              : context.l10n.diveLog_detail_surfaceGps_exitOnly);

    return CollapsibleCardSection(
      title: context.l10n.diveLog_detail_section_surfaceGps,
      icon: Icons.my_location,
      collapsedSubtitle: collapsedSubtitle,
      isExpanded: isExpanded,
      onToggle: (expanded) {
        ref
            .read(collapsibleSectionProvider.notifier)
            .setSurfaceGpsExpanded(expanded);
      },
      contentBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            if (entry != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_entry,
                '${entry.latitude.toStringAsFixed(5)}, ${entry.longitude.toStringAsFixed(5)}',
              ),
            if (exit != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_exit,
                '${exit.latitude.toStringAsFixed(5)}, ${exit.longitude.toStringAsFixed(5)}',
              ),
            if (driftText != null)
              _buildDetailRow(
                context,
                context.l10n.diveLog_detail_label_drift,
                driftText,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(context.l10n.diveLog_detail_openInMaps),
                onPressed: () => _openInMaps(entry ?? exit!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInMaps(GeoPoint point) async {
    final uri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=${point.latitude}&mlon=${point.longitude}#map=16/${point.latitude}/${point.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
```

- [ ] **Step 5: Add l10n strings + imports.** Add the new ARB keys used above to the app's localization (`rg -n 'diveLog_detail_section_tide' lib` to find the ARB file, then add alongside): `diveLog_detail_section_surfaceGps` ("Surface GPS"), `diveLog_detail_label_entry` ("Entry"), `diveLog_detail_label_exit` ("Exit"), `diveLog_detail_label_drift` ("Drift"), `diveLog_detail_surfaceGps_entryOnly` ("Entry point recorded"), `diveLog_detail_surfaceGps_exitOnly` ("Exit point recorded"), `diveLog_detail_openInMaps` ("Open in Maps"). Regenerate l10n (`flutter gen-l10n` or the build step the repo uses — `rg -n 'gen-l10n|l10n.yaml' .`). Ensure these imports are present at the top of `dive_detail_page.dart`: `package:url_launcher/url_launcher.dart`, `package:submersion/core/utils/geo_math.dart`, and `dive_detail_ui_providers.dart` (the existing collapsible providers import already covers the last).

- [ ] **Step 6: Run test to verify it passes.**

Run: `flutter test test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the full affected suites + analyze + format.**

Run:
```bash
flutter analyze
dart format lib/ test/
flutter test test/features/dive_log/ test/core/
```
Expected: analyze clean; format makes no further changes after committing; tests pass.

- [ ] **Step 8: Commit.**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/l10n test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart
git commit -m "feat(dive-log): add Surface GPS collapsible section with drift and open-in-maps"
```

---

## Phase 5 — GPS source attribution badge

Runs after Phases 2 and 4. Stores GPS on the per-source `DiveDataSource` provenance and renders the existing attribution badge on the Surface GPS values. Self-contained schema bump (v74) so it does not disturb Phase 2.

### Task 5.1: Add GPS columns to dive_data_sources (schema v74)

**Files:**
- Modify: `lib/core/database/database.dart` (`DiveDataSources` table ~1067-1110; `currentSchemaVersion` :1450; `migrationVersions`; `onUpgrade`)
- Test: `test/core/database/migration_v74_datasource_gps_test.dart`

- [ ] **Step 1: Add the columns.** In `class DiveDataSources extends Table`, after `RealColumn get waterTemp => real().nullable()();` (line ~1086), add:

```dart
  RealColumn get entryLatitude => real().nullable()();
  RealColumn get entryLongitude => real().nullable()();
  RealColumn get exitLatitude => real().nullable()();
  RealColumn get exitLongitude => real().nullable()();
```

- [ ] **Step 2: Bump schema version** 73 → 74:

```dart
  static const int currentSchemaVersion = 74;
```
and append `74,` to `migrationVersions`.

- [ ] **Step 3: Add the migration** at the end of `onUpgrade` (mirrors the migration-70 PRAGMA-guard precedent):

```dart
        if (from < 74) {
          final cols = await customSelect(
            "PRAGMA table_info('dive_data_sources')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('entry_latitude')) {
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN entry_latitude REAL',
              );
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN entry_longitude REAL',
              );
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN exit_latitude REAL',
              );
              await customStatement(
                'ALTER TABLE dive_data_sources ADD COLUMN exit_longitude REAL',
              );
            }
          }
        }
        if (from < 74) await reportProgress();
```

- [ ] **Step 4: Regenerate Drift code.** Run: `dart run build_runner build --delete-conflicting-outputs`. Expected: `DiveDataSourcesCompanion` / `DiveDataSourcesData` gain the four columns.

- [ ] **Step 5: Write + run a migration test** modeled on `test/core/database/migration_v73_gps_test.dart` (Task 2.2): insert a `DiveDataSourcesData` row with the four GPS columns and read them back. Run: `flutter test test/core/database/migration_v74_datasource_gps_test.dart`. Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v74_datasource_gps_test.dart
git commit -m "feat(db): add GPS columns to dive_data_sources (schema v74)"
```

### Task 5.2: Add GPS to the DiveDataSource entity + hydration

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive_data_source.dart` (fields :13-22, constructor :30-56, `copyWith` :61-115, `props` :118-144)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`_mapRowToDataSource` :4186-4214)
- Test: `test/features/dive_log/domain/entities/dive_data_source_gps_test.dart`

- [ ] **Step 1: Write the failing test.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

void main() {
  test('DiveDataSource carries GPS and copyWith preserves it', () {
    final s = DiveDataSource(
      id: 's1', diveId: 'd1', isPrimary: true,
      entryLatitude: 12.34567, entryLongitude: 98.76543,
      importedAt: DateTime(2026), createdAt: DateTime(2026),
    );
    expect(s.entryLatitude, 12.34567);
    expect(s.copyWith(maxDepth: 30).entryLongitude, 98.76543);
  });
}
```

- [ ] **Step 2: Run to verify it fails.** Run: `flutter test test/features/dive_log/domain/entities/dive_data_source_gps_test.dart`. Expected: FAIL — no named parameter `entryLatitude`.

- [ ] **Step 3: Add the fields.** In `dive_data_source.dart`, after `final double? waterTemp;` add:

```dart
  final double? entryLatitude;
  final double? entryLongitude;
  final double? exitLatitude;
  final double? exitLongitude;
```
Add to the constructor (after `this.waterTemp,`): `this.entryLatitude, this.entryLongitude, this.exitLatitude, this.exitLongitude,`.
Add the same four to the `copyWith` parameter list and its return body (`entryLatitude: entryLatitude ?? this.entryLatitude,` etc.), and add all four to `props`.

- [ ] **Step 4: Hydrate in `_mapRowToDataSource`.** In `dive_repository_impl.dart`, in the `return DiveDataSource(` block, after `waterTemp: row.waterTemp,` add:

```dart
      entryLatitude: row.entryLatitude,
      entryLongitude: row.entryLongitude,
      exitLatitude: row.exitLatitude,
      exitLongitude: row.exitLongitude,
```

- [ ] **Step 5: Run to verify it passes.** Run the Step-2 command. Expected: PASS.

- [ ] **Step 6: Commit.**

```bash
git add lib/features/dive_log/domain/entities/dive_data_source.dart lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/domain/entities/dive_data_source_gps_test.dart
git commit -m "feat(dive-log): carry GPS on DiveDataSource provenance"
```

### Task 5.3: Populate provenance GPS during import

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (the `DiveDataSourcesCompanion.insert` at :917-946)

This reuses the `importProfile` GPS params added in Task 2.3 (no new signature change).

- [ ] **Step 1: Write GPS into the provenance companion.** In the `DiveDataSourcesCompanion.insert(...)`, after `waterTemp: Value(minWaterTemp),`, add:

```dart
                entryLatitude: Value(entryLatitude),
                entryLongitude: Value(entryLongitude),
                exitLatitude: Value(exitLatitude),
                exitLongitude: Value(exitLongitude),
```

- [ ] **Step 2: Extend the importProfile test (Task 2.3)** to also assert the `dive_data_sources` row for the dive has the GPS values:

```dart
final src = await (db.select(db.diveDataSources)..where((t) => t.diveId.equals(diveId))).getSingle();
expect(src.entryLatitude, 12.34567);
expect(src.exitLongitude, 98.76489);
```

- [ ] **Step 3: Run to verify it passes.** Run that test file. Expected: PASS.

- [ ] **Step 4: Commit.**

```bash
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart test/<importProfile test path>
git commit -m "feat(import): record GPS on the dive data-source provenance"
```

### Task 5.4: Gate attribution['gps'] on stored coordinates

**Files:**
- Modify: `lib/features/dive_log/domain/services/field_attribution_service.dart` (:13 unused set; :52-57 gps block)
- Test: `test/features/dive_log/domain/services/field_attribution_gps_test.dart`

- [ ] **Step 1: Write the failing test.**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/services/field_attribution_service.dart';

DiveDataSource _src(String id, {required bool primary, double? lat}) => DiveDataSource(
  id: id, diveId: 'd1', isPrimary: primary, computerModel: 'Perdix $id',
  entryLatitude: lat, entryLongitude: lat,
  importedAt: DateTime(2026), createdAt: DateTime(2026),
);

void main() {
  test("gps attributed to active source only when it has coordinates", () {
    final withGps = FieldAttributionService.computeAttribution(
      [_src('A', primary: true, lat: 12.3), _src('B', primary: false)],
    );
    expect(withGps['gps'], 'Perdix A');

    final noGps = FieldAttributionService.computeAttribution(
      [_src('A', primary: true), _src('B', primary: false)],
    );
    expect(noGps.containsKey('gps'), false);
  });
}
```

- [ ] **Step 2: Run to verify it fails.** Run: `flutter test test/features/dive_log/domain/services/field_attribution_gps_test.dart`. Expected: FAIL — current code always sets `attribution['gps']` from the wearable heuristic.

- [ ] **Step 3: Replace the gps block.** In `field_attribution_service.dart`, delete the existing best-available GPS block:

```dart
    // Best-available: GPS — prefer GPS-capable source
    final gpsSource = sources.firstWhere(
      (s) => _gpsCapableSources.contains(s.sourceFormat),
      orElse: () => activeSource,
    );
    attribution['gps'] = gpsSource.displayName;
```
and replace it with (consistent with the `maxDepth`/`waterTemp` non-null gating):

```dart
    // GPS — attributed to the active source only when it actually has coordinates.
    if (activeSource.entryLatitude != null ||
        activeSource.exitLatitude != null) {
      attribution['gps'] = name;
    }
```
Then delete the now-unused `static const _gpsCapableSources = {...};` (line 12-13) to keep analysis clean. If any existing test asserts the old always-present `gps` behavior, update it to the gated behavior.

- [ ] **Step 4: Run to verify it passes** + analyze. Run: `flutter test test/features/dive_log/domain/services/ && flutter analyze lib/features/dive_log/domain/services/field_attribution_service.dart`. Expected: PASS, no analyzer issues (no unused field).

- [ ] **Step 5: Commit.**

```bash
git add lib/features/dive_log/domain/services/field_attribution_service.dart test/features/dive_log/domain/services/field_attribution_gps_test.dart
git commit -m "feat(dive-log): attribute GPS to the source that recorded it"
```

### Task 5.5: Render the attribution badge on the Surface GPS section

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (the `surfaceGps` entry in `_sectionBuilders`; `_buildSurfaceGpsSection` from Task 4.4)

- [ ] **Step 1: Compute attribution in the section builder.** Replace the `DiveDetailSectionId.surfaceGps` closure (Task 4.4 Step 3) with one that computes attribution like the Details section:

```dart
      DiveDetailSectionId.surfaceGps: () {
        if (dive.entryLocation == null && dive.exitLocation == null) return [];
        return [
          const SizedBox(height: 24),
          ValueListenableBuilder<String?>(
            valueListenable: _viewedSourceIdNotifier,
            builder: (context, viewedSourceId, _) {
              final dataSources = computerReadingsAsync.valueOrNull ?? [];
              final attribution = FieldAttributionService.computeAttribution(
                dataSources,
                viewedSourceId: viewedSourceId,
              );
              final showBadges =
                  settings.showDataSourceBadges && attribution.isNotEmpty;
              return _buildSurfaceGpsSection(
                context,
                ref,
                dive,
                units,
                sourceName: showBadges ? attribution['gps'] : null,
              );
            },
          ),
        ];
      },
```

- [ ] **Step 2: Thread sourceName into the section.** Change `_buildSurfaceGpsSection`'s signature to add `{String? sourceName}` and pass `sourceName: sourceName` into the entry and exit `_buildDetailRow(...)` calls (the `_buildDetailRow` helper already supports an optional `sourceName` that renders a `FieldAttributionBadge`).

- [ ] **Step 3: Extend the widget test (Task 4.4)** with a multi-source case: a dive with two `DiveDataSource`s where the primary has entry coordinates and `settings.showDataSourceBadges` is true renders a `FieldAttributionBadge`; a single-source dive renders none.

```dart
expect(find.byType(FieldAttributionBadge), findsWidgets); // multi-source w/ GPS
// single-source dive:
expect(find.byType(FieldAttributionBadge), findsNothing);
```

- [ ] **Step 4: Run, analyze, format.** Run: `flutter analyze && flutter test test/features/dive_log/presentation/`. Expected: clean + PASS.

- [ ] **Step 5: Commit.**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_surface_gps_section_test.dart
git commit -m "feat(dive-log): show source-attribution badge on Surface GPS values"
```

---

## Final verification

- [ ] `flutter analyze` — no issues.
- [ ] `dart format --set-exit-if-changed lib/ test/` — no changes.
- [ ] `flutter test` — full suite green (or run targeted suites per the test-timeout preference: `flutter test test/features/dive_log/ test/features/dive_computer/ test/core/`).
- [ ] Native struct test green (Task 1.2 command).
- [ ] Manual: download/re-parse a real Swift dive (Task 1.7) and confirm entry/exit pins appear on the header map and the Surface GPS section shows correct coordinates + drift; confirm a non-Swift dive shows no GPS UI.
