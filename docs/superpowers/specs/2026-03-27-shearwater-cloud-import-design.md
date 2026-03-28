# Shearwater Cloud Database Import

**Date:** 2026-03-27
**Status:** Draft

## Overview

Import dive data from Shearwater Cloud desktop application SQLite databases (`.db` files) into Submersion. Uses the existing libdivecomputer FFI integration to parse binary dive profile data, combined with rich metadata from the Shearwater Cloud database tables.

## Goals

- Import all available data from Shearwater Cloud `.db` files
- Full dive profile parsing (depth, temp, ppO2, CNS, NDL, ceiling, TTS, tank pressure, ascent rate, RBT) via libdivecomputer
- Rich metadata import (location, site, buddy, notes, conditions, weather, tank info, GPS)
- Integrate into the existing universal import wizard flow
- Graceful fallback to metadata-only import when binary parsing fails

## Non-Goals

- Shearwater Desktop format (old `dive_logs`/`dive_log_records` tables) -- target Cloud format only
- Direct Shearwater Cloud API integration (cloud sync)
- Parsing the `sw-pnf` binary format from scratch -- use libdivecomputer instead

## Shearwater Cloud Database Schema

The database contains 12 tables. The three data tables relevant to import are:

### dive_details

User-entered metadata and computed summary values per dive. Joined to `log_data` via `DiveId = log_id`.

| Column | Type | Description | Submersion mapping |
|--------|------|-------------|-------------------|
| DiveId | varchar PK | Unique dive identifier | importId |
| DiveDate | datetime | Dive start timestamp (UTC) | diveDateTime |
| Depth | varchar | Max depth in meters | maxDepth |
| AverageDepth | float | Average depth in meters | avgDepth |
| AverageTemp | float | Average water temp (in user's unit system) | waterTemp (convert F->C if imperial) |
| MinTemp | float | Minimum water temp | (profile data preferred) |
| MaxTemp | float | Maximum water temp | (profile data preferred) |
| DiveLengthTime | varchar | Duration in seconds | duration |
| DiveNumber | varchar | Sequential dive number | diveNumber |
| SerialNumber | varchar | Hex serial of dive computer | diveComputerSerial |
| Location | varchar | Region/country (e.g., "Shark River, NJ, USA") | site.region + site.country |
| Site | varchar | Site name (e.g., "Maclearie Park") | site.name |
| Buddy | varchar | Buddy name | buddy |
| Notes | varchar | User notes | notes |
| Environment | varchar | "Ocean/Sea", "Pool", etc. | waterType mapping |
| Visibility | varchar | Numeric value | visibility mapping |
| Weather | varchar | "Sunny", "Cloudy", "Windy" | cloudCover / notes |
| Conditions | varchar | "Current", "Surge" | currentStrength / notes |
| AirTemperature | varchar | Air temperature | airTemp (with unit conversion) |
| Weight | varchar | Weight in lbs/kg | weightAmount |
| Dress | varchar | "Wet Suit", "Dry Suit", etc. | notes (no direct mapping) |
| Apparatus | varchar | "Single Tank", "Doubles", etc. | informational |
| ThermalComfort | varchar | "Warm/Neutral", "Cold", etc. | notes |
| Workload | varchar | "Resting", "Moderate", etc. | notes |
| GnssEntryLocation | varchar | GPS entry coordinates | site.latitude/longitude |
| GnssExitLocation | varchar | GPS exit coordinates | (stored in notes) |
| TankProfileData | varchar | Rich JSON (see below) | tanks, gas mixes |
| Tank1-4PressureStart | varchar | Start pressure (PSI) | tank.startPressure |
| Tank1-4PressureEnd | varchar | End pressure (PSI) | tank.endPressure |
| AverageSAC | varchar | SAC rate | (computed from profile) |
| TankSize | varchar | Tank size | (from TankProfileData) |
| Problems | varchar | Dive problems | notes |
| Malfunctions | varchar | Equipment malfunctions | notes |
| Symptoms | varchar | Post-dive symptoms | notes |
| GasNotes | varchar | Gas-related notes | notes |
| GearNotes | varchar | Equipment notes | notes |
| IssueNotes | varchar | Issue notes | notes |
| EndGF99 | float | End-of-dive GF99 | (informational) |

### TankProfileData JSON Structure

Rich JSON field in `dive_details` containing gas profiles and tank data:

```json
{
  "GasProfiles": [{
    "profileIndex": 0,
    "O2Percent": 32,
    "HePercent": 0,
    "CircuitMode": 1,
    "CircuitSwitchType": 0,
    "StartTimeInSeconds": 0.0,
    "EndTimeInSeconds": 1764.0,
    "AverageDepthInMeters": 19.45
  }],
  "TankData": [{
    "StartPressurePSI": "2960",
    "EndPressurePSI": "1088",
    "GasProfile": { ... },
    "DiveTransmitter": {
      "TankIndex": 0,
      "IsOn": true,
      "UnformattedSerialNumber": "830122",
      "Name": "T1",
      "DefaultScriptTerm": "dive_details/tank_1"
    },
    "SurfacePressureMBar": 1015.0,
    "Salinity": 1030
  }]
}
```

Mapping:
- `GasProfiles[].O2Percent/HePercent` -> tank.gasMix (o2/he)
- `GasProfiles[].CircuitMode` -> diveMode (1=OC, 2=CCR)
- `TankData[].StartPressurePSI/EndPressurePSI` -> tank.startPressure/endPressure (convert PSI to bar)
- `TankData[].DiveTransmitter.Name` -> tank.name ("T1", "T2", etc.)
- `TankData[].DiveTransmitter.IsOn` -> filter to only active tanks
- `TankData[].SurfacePressureMBar` -> surfacePressure (convert mbar to bar)

### log_data

Raw dive computer data with binary BLOBs and JSON metadata. One row per dive.

| Column | Type | Description |
|--------|------|-------------|
| log_id | varchar PK | Matches dive_details.DiveId |
| file_name | varchar | e.g., "Teric[8629AC48]#1 2025-9-20 7-42-35.swlogzp" |
| format | varchar | Always "sw-pnf" for Cloud format |
| data_bytes_1 | blob | 4-byte header + gzip-compressed raw device log |
| data_bytes_2 | blob | JSON header: dive number, start time, DB version |
| data_bytes_3 | blob | JSON footer: mode, unit system, dive time, max depth, memory layout |
| calculated_values_from_samples | varchar | JSON: AverageDepth (ft if imperial), AverageTemp/MinTemp/MaxTemp (F if imperial), EndGF99, MinNDL, MaxDecoObligation |

### data_bytes_2 JSON (header)

```json
{
  "DIVE_NUMBER_KEY": 1,
  "HARDWARE_TYPE_KEY": "",
  "DIVE_START_TIME": 1758354155,
  "DIVE_END_TIME": 0,
  "DB_VERSION": 12
}
```

### data_bytes_3 JSON (footer)

```json
{
  "AutoIncrementValue": 640,
  "Mode": 6,
  "Temperature": 3,
  "Version": 2,
  "DiveNumber": 23,
  "StartTime": 1766844068,
  "EndTime": 1766845832,
  "DiveTimeInSeconds": 1764,
  "MaxDepth": 87.9,
  "AverageDepth": 0.0,
  "OpeningRecordAddress": 676192,
  "ClosingRecordAddress": 705952,
  "UnitSystem": 1,
  "ComputerSerial": 0,
  "RawBytes": "...",
  "MemorySize": 33944
}
```

Note: `MaxDepth` in footer is in feet when `UnitSystem=1`. Use `dive_details.Depth` (always meters) instead.

### Other Tables (not imported)

- `StoredDiveComputer` -- Dive computer JSON data (empty in sample DB)
- `CustomDiveComputer` -- Custom computer settings (empty)
- `DeletedLogs` -- Soft-deleted dive IDs
- `SWC_TableVersion` -- Schema version tracking
- `SyncV3Metadata*` -- Cloud sync metadata
- `dive_logs` / `dive_log_records` -- Old Desktop format tables (empty in Cloud exports)

## Architecture

### Data Flow

```
Shearwater Cloud .db file (Uint8List)
  |
  v
ShearwaterCloudParser (implements ImportParser)
  |-- Write bytes to temp file
  |-- Open as read-only SQLite via sqlite3 FFI
  |-- Query dive_details + log_data (joined on DiveId/log_id)
  |
  |-- For each dive:
  |     |-- Extract data_bytes_1 -> strip 4-byte prefix -> gzip decompress
  |     |-- Parse file_name -> extract model name + serial number
  |     |-- Call DiveComputerHostApi.parseRawDiveData(vendor, product, model, bytes)
  |     |     -> dc_parser_new2() in C -> full ParsedDive with 14-field samples
  |     |-- Parse TankProfileData JSON from dive_details
  |     |-- Parse calculated_values_from_samples from log_data
  |     |-- Merge: libdivecomputer profile + dive_details metadata + tank JSON
  |     |-- Convert to ImportPayload entity maps
  |
  v
ImportPayload -> existing review/import/summary wizard flow
```

### Three Layers of Work

#### Layer 1: FFI Extension

Expose `dc_parser_new2()` as a new Pigeon API method for standalone binary parsing.

**Pigeon addition:**
```dart
@HostApi()
abstract class DiveComputerHostApi {
  @async
  ParsedDive parseRawDiveData(
    String vendor,
    String product,
    int model,
    Uint8List data,
  );
}
```

**C wrapper addition (`libdc_wrapper.h`):**
```c
int libdc_parse_raw_dive(
    const char *vendor,
    const char *product,
    unsigned int model,
    const unsigned char *data,
    unsigned int size,
    libdc_parsed_dive_t *result
);
```

Implementation:
1. Create `dc_context_t`
2. Iterate descriptors to find matching vendor + product
3. Call `dc_parser_new2(&parser, context, descriptor, data, size)`
4. Reuse existing `parse_dive()` extraction logic
5. Populate `libdc_parsed_dive_t` struct
6. Return through Pigeon serialization

Platform wiring needed for: macOS, iOS, Linux, Windows, Android.

#### Layer 2: SQLite Reader

Opens the imported `.db` file and extracts data from Shearwater Cloud tables.

**Key responsibilities:**
- Write `Uint8List` to temp file, open as read-only SQLite
- Validate Shearwater Cloud fingerprint (check for `dive_details` + `log_data` tables)
- Query and join tables
- Extract and decompress binary BLOBs (gzip)
- Parse JSON fields (TankProfileData, calculated_values_from_samples, data_bytes_2/3)
- Clean up temp file after parsing

**Dependencies:** `sqlite3` FFI package (already available via Drift), `dart:io` for gzip decompression.

#### Layer 3: Parser + Mapper

Merges libdivecomputer's parsed profile data with Shearwater Cloud metadata to produce a complete `ImportPayload`.

**Model identification from filename:**

| Filename prefix | Vendor | Product |
|----------------|--------|---------|
| Teric | Shearwater | Teric |
| Perdix | Shearwater | Perdix |
| Peregrine | Shearwater | Peregrine |
| Petrel | Shearwater | Petrel |
| Petrel 3 | Shearwater | Petrel 3 |
| Tern | Shearwater | Tern |
| NERD | Shearwater | NERD 2 |

Serial number extracted from bracketed hex value: `Teric[8629AC48]` -> `8629AC48`.

### Format Detection

**Two-stage approach:**

1. **Stage 1 (FormatDetector):** Detects SQLite magic bytes. Returns `ImportFormat.sqlite` with 0.5 confidence. Fast, no file I/O.

2. **Stage 2 (Adapter pre-validation):** Before showing the source confirmation screen, the UniversalAdapter opens the SQLite file and checks for Shearwater tables:
   ```sql
   SELECT name FROM sqlite_master
   WHERE type='table' AND name IN ('dive_details', 'log_data')
   ```
   If both found: update detection to `ImportFormat.shearwaterDb` / `SourceApp.shearwater` with 0.95 confidence. User sees "Shearwater Cloud" on the confirmation screen.

**PlaceholderParser update:** Remove `ImportFormat.shearwaterDb` from the placeholder's supported formats. The parser registry routes `shearwaterDb` to `ShearwaterCloudParser` instead.

### Conditions Mapping

| Shearwater field | Submersion field | Mapping |
|-----------------|-----------------|---------|
| Environment: "Ocean/Sea" | waterType | `WaterType.salt` |
| Environment: "Pool" | waterType | `WaterType.fresh` |
| Environment: "Lake" | waterType | `WaterType.fresh` |
| Weather: "Sunny" | cloudCover | `CloudCover.clear` |
| Weather: "Cloudy" | cloudCover | `CloudCover.mostlyCloudy` |
| Weather: "Windy" | (appended to notes) | No direct enum mapping |
| Conditions: "Current" | currentStrength | `CurrentStrength.moderate` |
| Conditions: "Surge" | (appended to notes) | No direct enum mapping |
| Visibility: numeric | visibility | Convert to meters if imperial (ft * 0.3048), then: >=30m: excellent, 15-29m: good, 5-14m: moderate, <5m: poor |
| Dress | (appended to notes) | No direct equipment mapping |
| ThermalComfort | (appended to notes) | Informational |
| Workload | (appended to notes) | Informational |

Fields without direct Submersion enum mappings are collected into a structured notes section:
```
[Shearwater Cloud]
Weather: Windy
Conditions: Surge
Dress: Wet Suit
Thermal Comfort: Warm/Neutral
Workload: Resting
```

### Unit Conversions

| Field | Source unit (imperial) | Target unit | Conversion |
|-------|----------------------|-------------|------------|
| Tank pressures (TankProfileData) | PSI | bar | / 14.5038 |
| Air temperature | Fahrenheit | Celsius | (F - 32) * 5/9 |
| Weight | lbs | kg | * 0.453592 |
| SAC rate | cu ft/min | L/min | * 28.3168 |
| Surface pressure (TankProfileData) | mbar | bar | / 1000 |
| Depth (dive_details.Depth) | meters | meters | No conversion needed |
| Visibility (dive_details) | feet (if imperial) | meters | * 0.3048 (then map to enum) |
| Temperatures (calculated_values) | Fahrenheit (if imperial) | Celsius | (F - 32) * 5/9 |
| AverageDepth (calculated_values) | feet (if imperial) | meters | * 0.3048 |
| libdivecomputer output | metric | metric | No conversion needed |

Unit system determined from `log_data.data_bytes_3` footer JSON field `UnitSystem` (0=metric, 1=imperial).

### Deduplication

- Each imported dive gets `importSource = "shearwater_cloud"` and `importId` set to the Shearwater `DiveId` (e.g., `"1033943841758354155"`)
- Existing `ImportDuplicateChecker` handles fuzzy matching on date/time, depth, and duration
- Re-importing the same `.db` file flags all dives as "likely duplicates"

## Error Handling

### Binary parsing failures
If `dc_parser_new2()` fails for a specific dive (corrupt data, unrecognized firmware version):
- Import that dive using metadata-only from `dive_details` + `calculated_values_from_samples`
- No profile data for that dive
- Add per-dive warning: "Could not parse dive profile for dive #N. Metadata imported successfully."

### Gzip decompression failures
Same fallback as binary parsing failure.

### Unrecognized model names
If filename prefix doesn't match known Shearwater models:
- Attempt generic "Shearwater" descriptor lookup
- If that fails, metadata-only fallback with warning

### Missing or empty fields
- Empty strings and NULL treated identically: field omitted from import
- No crashes on sparse `dive_details` rows (early dives often have no metadata)

### Database validation
- Missing `dive_details` or `log_data` tables: return empty payload with error message
- Mismatched row counts between tables: import only dives present in both tables, warn about orphans

### Old Desktop format databases
If `dive_logs` has rows but `log_data` is empty (old Desktop format):
- Return empty payload with message: "This appears to be a Shearwater Desktop database. Please sync your dives to Shearwater Cloud and export from there."

## Testing Strategy

### Unit tests
- Metadata extraction: all `dive_details` fields map correctly
- JSON parsing: TankProfileData, calculated_values_from_samples, data_bytes_2/3
- Filename parsing: model name + serial extraction for all known Shearwater models
- Unit conversions: PSI->bar, F->C, lbs->kg, cu ft/min->L/min, mbar->bar
- Conditions mapping: Environment->waterType, Weather->cloudCover, etc.
- Empty/null field handling: no crashes on sparse rows
- Metadata-only fallback: correct payload when binary parsing fails

### FFI integration tests
- `parseRawDiveData()` with known good binary data: verify ParsedDive has expected sample count, depth range, gas mixes
- Invalid/corrupt binary: verify graceful failure without crash
- Model descriptor lookup for each known Shearwater model name

### Format detection tests
- SQLite with `dive_details` + `log_data` tables: detected as Shearwater Cloud
- SQLite without those tables: not identified as Shearwater
- Non-SQLite files: unaffected

### End-to-end integration test
- Full import: .db file -> parser -> ImportPayload -> verify entity counts (28 dives from test fixture)
- Verify profile data present for dives where binary parsing succeeds
- Verify tanks, gas mixes, sites populated correctly
- Verify duplicate detection works on re-import

### Test fixtures
- Real `third_party/shearwater_cloud_database.db` for integration tests
- Minimal synthetic .db (2-3 dives) for fast unit tests

## Files to Create/Modify

### New files
- `lib/features/universal_import/data/parsers/shearwater_cloud_parser.dart` -- Main parser
- `lib/features/universal_import/data/services/shearwater_db_reader.dart` -- SQLite reader + decompression
- `lib/features/universal_import/data/services/shearwater_dive_mapper.dart` -- Merge libdc + metadata into ImportPayload
- `packages/libdivecomputer_plugin/macos/Classes/libdc_parse_raw.c` -- C implementation of standalone parser
- Platform bridge files for iOS, Linux, Windows, Android
- Test files for each new Dart file

### Modified files
- `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` -- Add `parseRawDiveData()` method
- `packages/libdivecomputer_plugin/lib/src/generated/dive_computer_api.g.dart` -- Regenerated
- `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h` -- Add raw parse function signature
- `lib/features/universal_import/data/models/import_enums.dart` -- Mark `shearwaterDb` as supported
- `lib/features/universal_import/data/parsers/placeholder_parser.dart` -- Remove `shearwaterDb` from supported formats
- `lib/features/universal_import/data/services/format_detector.dart` -- Enhanced SQLite app detection
- `lib/features/import_wizard/data/adapters/universal_adapter.dart` -- Route shearwaterDb to new parser, add pre-validation
- `lib/features/universal_import/presentation/providers/universal_import_providers.dart` -- Add `ImportFormat.shearwaterDb` case to parser selection switch (line ~404-408)
