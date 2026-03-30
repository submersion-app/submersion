# CSV Import Rearchitect Design

## Overview

Complete rearchitect of the CSV import system to be comprehensive, flexible, and easy for users when the source application is known. Replaces the current dual-parser approach (legacy `CsvImportService` + modern `CsvImportParser`) with a single staged pipeline that supports all entity types, multi-file imports, user-saveable presets, and robust time/unit handling.

## Motivation

### GitHub Issues

| Issue | Problem |
|-------|---------|
| #58 | Column mapping UI not shown for "Import by Format" path (two code paths diverge) |
| #59 | LF line endings (Linux CSV) break parsing entirely |
| #61 | Informal time values ("am"/"pm"/"night") rejected instead of assigned defaults |
| #63 | AM/PM indicator in 12-hour times ignored (02:00:00 PM treated as 02:00) |
| #64 | No option to import times as local wall-clock (UTC conversion produces wrong results) |
| #62 | UDDF export shows "no dives" immediately after CSV import (provider refresh) |

### ScubaBoard Feedback

- CSV import described as "immature" -- developer recommends Subsurface as intermediary
- User with 1,500 historical dives (1978-2017) cannot bulk import via CSV
- Diving Log and Shearwater CSV exports "don't transfer data well"
- Multi-tank data gets lost on import
- Timezone/time-shift is the #1 reported issue across all import paths

### Subsurface CSV Structure

Subsurface exports three separate CSV files:

1. **dive_list.csv** -- summary data: dive number, date, time, duration, SAC, depths, up to 6 tanks with gas mixes, location with GPS, buddy, suit, rating, visibility, notes, weight, tags
2. **dive_computer_dive_profile.csv** -- raw profile: sample-by-sample depth, temperature, pressure, heartrate per dive
3. **computed_profile_panel_data.csv** -- computed deco model data (NDL, TTS, ceiling, GF, tissue loading). Not needed -- Submersion can recompute this from the raw profile data.

The current single-file-per-import model cannot handle this.

## Architecture: Staged Pipeline

All CSV imports flow through a seven-stage pipeline. Each stage is a pure function (input to output) except Import (side effect). Errors at any stage produce warnings that carry forward.

```
Parse --> Detect --> Configure --> Transform --> Correlate --> Preview --> Import
```

### Stage 1: Parse

Raw CSV parsing only. No interpretation. Runs first because both Detect (header matching) and Configure (sample value display) need parsed data.

**Input:** File bytes (from the universal wizard's file picker).
**Output:** `ParsedCsv` -- headers as `List<String>`, rows as `List<List<String>>`.

Responsibilities:

- Decode bytes as UTF-8 (with `allowMalformed`)
- Normalize line endings: `\r\n` to `\n`, bare `\r` to `\n` (fixes #59)
- Parse with CSV library using normalized `\n` EOL
- Extract headers from first row
- Return raw string data -- no type conversion

### Stage 2: Detect

Match parsed headers against the PresetRegistry to identify the source application.

**Input:** `ParsedCsv` (headers + sample rows).
**Output:** `DetectionResult` -- detected source app, confidence score, matched preset, file roles.

The detection runs automatically after the universal wizard's `FormatDetector` identifies the file as CSV and the Parse stage completes. If a multi-file preset is matched, this triggers the additional files prompt (step 3a in the wizard). Additional files go through their own Parse stage before continuing.

### Stage 3: Configure

Based on detection results, either auto-apply the preset (known app fast path) or present the full field mapping UI (unknown CSV). Uses parsed headers and sample row values for display.

**Input:** `DetectionResult` + `ParsedCsv` + user selections (preset overrides, additional files, time/unit settings).
**Output:** `ImportConfiguration` -- field mappings, transforms, time interpretation, unit settings, entity types to extract.

**Known app fast path:** Preset mapping auto-applied. User sees import settings summary (units, time interpretation, entity types) with a "Customize field mapping..." expander for power users. One tap to continue.

**Unknown CSV full path:** Auto-detector fills what it can from keyword matching. User maps remaining columns via dropdowns. Each row shows the CSV column name, sample values from the first few parsed rows, and a dropdown of target fields (with "-- Skip --" option). A "Save as preset..." button lets the user persist their mapping for reuse.

### Stage 4: Transform

Apply the import configuration to parsed data. This is where type conversion, unit detection, time resolution, and field mapping happen.

**Input:** `ParsedCsv` + `ImportConfiguration`.
**Output:** `TransformedRows` -- typed maps with standardized field names and values.

Sub-steps:
1. Map CSV columns to target fields using the configuration's field mappings
2. Resolve times (see Time Handling section)
3. Detect and convert units (see Unit Detection section)
4. Coerce types (strings to numbers, dates, durations, enums)
5. Apply value transforms (visibility scale, rating scale, dive type mapping)

### Stage 5: Correlate

Multi-file merging and entity extraction.

**Input:** `TransformedRows` (from all files) + `ImportConfiguration`.
**Output:** `CorrelatedPayload` -- separate entity collections linked by generated IDs.

Responsibilities:
- If multiple files were loaded, match data across files (e.g., profile samples to dives by dive number + date/time)
- Run entity extractors to decompose rows into typed entity streams
- Deduplicate entities (e.g., same site name across rows produces one site)
- Link entities (dive to tanks, dive to site, dive to buddies)
- Run duplicate detection against existing database

### Stage 6: Preview

Display to user for review. This uses the existing universal wizard preview infrastructure.

**Input:** `CorrelatedPayload`.
**Output:** `ImportSelection` -- user's choices about what to import.

Shows:
- Entity counts (dives, sites, tanks, profile samples, buddies, tags, gear)
- Dive table with per-dive checkboxes, tank count, profile indicator
- Warnings panel (non-blocking)
- Duplicate detection results

### Stage 7: Import

Write selected entities to database.

**Input:** `ImportSelection`.
**Output:** Import results (counts, errors).

Reuses existing `UddfEntityImporter` infrastructure which already handles all entity types. After database writes, invalidates relevant Riverpod providers (fixes #62).

## Universal Wizard Integration

The CSV pipeline plugs into the existing universal import wizard. It does not replace the wizard's file selection step.

```
Universal Wizard                    CSV Pipeline
---                                 ---
1. Pick file                   -->
2. Format detected as CSV      -->  Parse (decode, normalize, split)
                               -->  Detect (header analysis, preset matching)
3. Source confirmation         <--  "Detected: Subsurface CSV"
                               -->
3a. Additional files (NEW)     <--  "Add dive profile CSV?" (only for multi-file presets)
                               -->  Parse additional files
4. Configure                   <--  Fast path or full mapper (with sample values)
5. Preview                     <--  Transform + Correlate + entity preview
6. Import                      <--  Write to database
```

Step 3a is the only new wizard step -- a conditional prompt that only fires when the detected preset declares multiple file roles. For single-file presets and generic CSV, the user never sees it.

## Preset Registry

### Preset Data Model

```dart
class CsvPreset {
  final String id;                          // 'subsurface', 'user_my-club-log'
  final String name;                        // 'Subsurface CSV'
  final PresetSource source;                // builtIn, userSaved
  final SourceApp? sourceApp;               // links to existing SourceApp enum

  // Detection
  final List<String> signatureHeaders;      // headers that identify this app
  final double matchThreshold;              // % of signature headers required

  // File expectations
  final List<PresetFileRole> fileRoles;     // single file, or multi-file spec

  // Field mapping per file role
  final Map<String, List<FieldMapping>> mappings; // fileRole -> column mappings

  // Transform hints
  final UnitSystem? expectedUnits;          // metric, imperial, or null (auto-detect)
  final TimeFormat? expectedTimeFormat;     // 24h, 12h, informal, or null

  // Entity extraction hints
  final Set<ImportEntityType> supportedEntities; // what this preset can produce
}
```

### PresetFileRole

For multi-file sources like Subsurface:

```dart
class PresetFileRole {
  final String roleId;                      // 'dive_list', 'dive_profile'
  final String label;                       // 'Dive list CSV', 'Dive profile CSV'
  final bool required;                      // dive_list required, profile optional
  final List<String> signatureHeaders;      // headers that identify this file
}
```

### Registry Structure

```
PresetRegistry
  Built-in presets (immutable, loaded at startup)
    subsurface (multi-file: dive_list + dive_profile)
    macdive
    diving_log
    divemate
    garmin_connect
    shearwater_cloud
    submersion
  User presets (mutable, loaded from database)
    user_*
  Methods
    detectPreset(headers) -> ranked matches with confidence
    getPreset(id) -> CsvPreset
    saveUserPreset(CsvPreset) -> persists to DB
    deleteUserPreset(id)
```

### Detection Flow

When a CSV is loaded, the registry scores each preset against the file's headers. A preset with 90% of its signature headers present ranks higher than one with 60%. If a preset scores above its `matchThreshold`, it is offered as the detected source. Multiple matches are ranked and presented to the user.

### Adding a New Preset

Adding a new built-in preset is a data-only change: define a const `CsvPreset` with signature headers, field mappings, and transforms. Register it in the built-in list. No logic changes required.

### User-Saveable Presets

When a user configures a custom mapping in the full mapper, they can save it via "Save as preset..." for reuse. Saved presets appear alongside built-in presets in the source selection and detection ranking.

## Entity Extraction System

### Extractors

Each extractor pulls one entity type from transformed row data:

```
EntityExtractor (interface)
  DiveExtractor       -- core dive fields (date, depth, duration, etc.)
  TankExtractor       -- repeating tank groups (volume, pressures, gas mix)
  ProfileExtractor    -- sample-by-sample data from profile CSV
  SiteExtractor       -- site name + GPS, deduplicated by name
  BuddyExtractor      -- comma-separated buddy lists, split into individuals
  TagExtractor        -- comma-separated tags, split and normalized
  GearExtractor       -- suit/equipment mentions
  TripExtractor       -- trip grouping (if source provides it)
```

### Tank Extraction

Subsurface exports repeating column groups for up to 6 tanks:

```
cylinder size (N) [l], startpressure (N) [bar], endpressure (N) [bar], o2 (N) [%], he (N) [%]
```

The `TankExtractor`:
1. Detects repeating column groups in the mapping (pattern: `fieldName (N)`)
2. For each row, iterates groups 1-6 and emits a `DiveTank` entity for each non-empty group
3. Links each tank to its parent dive

### Profile Extraction

Works on the second Subsurface CSV file (`dive_computer_dive_profile.csv`):

```
dive number, date, time, sample time (min), sample depth (m), sample temperature (C), sample pressure (bar), sample heartrate
```

Each row is one sample. Samples grouped by dive (dive number + date + time) produce a `List<DiveProfile>` per dive. The Correlate stage matches these to dive entities from the dive list file.

### Buddy Extraction

Handles edge cases like Subsurface's format where buddy values may have leading commas (e.g., `", Kiyan Griffin"`):
1. Split on commas
2. Trim whitespace
3. Filter empty strings
4. Deduplicate across all rows

### Extraction Pipeline Per Row

All extractors receive the same row and produce their entity type independently. The Correlate stage links them via generated IDs.

## Time Handling

### Core Principle

A dive time is a wall-clock time at the dive site. If a diver logged "2:00 PM" in Honduras, they see "2:00 PM" regardless of their current timezone. Stored as UTC-encoded-wall-time.

### Time Resolution Pipeline

```
Raw value from CSV
  |
  v
1. Format Detection
   - ISO 8601 with offset ("2025-11-15T09:17:19-04:00") -> extract wall-clock
   - 24-hour time ("14:30", "09:17:19") -> use as-is
   - 12-hour time ("2:00:00 PM", "9:17 am") -> convert to 24h  [fixes #63]
   - Informal token ("am", "pm", "night", "morning") -> assign defaults [fixes #61]
   - Empty/missing -> assign noon (12:00) default
   - Unparseable -> warning, skip row or use default
  |
  v
2. Date + Time Combining
   - Single dateTime column -> parse directly
   - Separate date + time columns -> combine
   - Date only, no time column -> use default (12:00)
  |
  v
3. Timezone Interpretation (user-configurable)
   - "Local wall-clock" (default) -> store value as-is in UTC encoding
   - "UTC" -> value is already UTC, store directly
   - "Specific offset" -> apply offset, then store as wall-clock UTC
  |
  v
4. Store with importVersion = 2
```

### Time Format Priority (fixes #63)

Formats tried in order:
1. `h:mm:ss a` / `hh:mm:ss a` -- "2:00:00 PM", "02:00:00 PM"
2. `h:mm a` / `hh:mm a` -- "2:00 PM", "02:00 PM"
3. `HH:mm:ss` -- "14:00:00"
4. `HH:mm` / `H:mm` -- "14:30", "9:17"
5. ISO 8601 fallback -- `DateTime.tryParse()`

### Informal Time Resolver (fixes #61)

Groups rows by date, assigns incrementing times based on keyword tokens:

| Token(s) | 1st dive that day | 2nd dive | 3rd dive |
|----------|-------------------|----------|----------|
| "am", "morning" | 09:00 | 11:00 | 12:00 |
| "pm", "afternoon" | 14:00 | 16:00 | 17:00 |
| "night", "evening" | 19:00 | 21:00 | 22:00 |
| empty / unparseable | 12:00 | 14:00 | 16:00 |

Runs as a pre-pass before individual row transformation since it needs all rows for a date.

### Timezone Interpretation (fixes #64)

Configure step shows a dropdown:
- Local wall-clock (default, recommended)
- Times are in UTC
- Specific timezone offset...

Preview shows sample times so users can verify. If times look shifted, they go back and change interpretation.

### importVersion Tracking

- `null` -- pre-fix imports (may have shifted times)
- `1` -- first UTC wall-time fix (issue #60)
- `2` -- new pipeline with full time handling

## Unit Detection & Conversion

### Detection Priority

1. **Header-declared units** -- parse bracketed suffix: `maxdepth [m]`, `watertemp [F]`, `startpressure (1) [psi]`. Authoritative.
2. **Preset-declared units** -- if preset specifies `expectedUnits: metric`, trust it.
3. **Value heuristics** -- analyze first 10-20 rows:
   - Depth > 100 -> likely feet; < 80 -> likely meters; 80-100 -> ambiguous, flagged
   - Temperature > 50 -> likely Fahrenheit; < 45 -> likely Celsius
   - Pressure > 300 -> likely PSI; < 300 -> likely bar
   - Volume > 20 -> likely cubic feet; < 20 -> likely liters
4. **User override** -- always shown in Configure step.

### Per-Column Detection

Units are detected per column, not globally. A CSV could have depth in meters but temperature in Fahrenheit.

```dart
class ColumnUnitDetection {
  final String columnName;
  final UnitType unitType;      // depth, temperature, pressure, volume
  final DetectedUnit detected;  // meters, feet, celsius, fahrenheit, etc.
  final UnitSource source;      // header, preset, heuristic, userOverride
  final double confidence;      // 0.0-1.0 for heuristic detection
}
```

### Conversions

All stored values are metric (database convention):

| From | To | Formula |
|------|----|---------|
| feet | meters | x * 0.3048 |
| Fahrenheit | Celsius | (x - 32) * 5/9 |
| PSI | bar | x * 0.0689476 |
| cubic feet | liters | x * 28.3168 |
| pounds | kg | x * 0.453592 |

## Bug Fix Mapping

| Issue | Root Cause | Fix Location |
|-------|-----------|--------------|
| #58 | Two code paths; "Import by Format" hits legacy parser | Legacy `CsvImportService` deleted. All CSV goes through universal wizard pipeline. |
| #59 | Legacy parser hardcodes `\r\n` EOL | Parse stage normalizes all line endings before CSV parsing. |
| #60 | Already closed | Pipeline continues wall-clock-as-UTC convention with `importVersion = 2`. |
| #61 | Invalid time values cause row skip | Transform stage `InformalTimeResolver` assigns sensible defaults. |
| #62 | Provider not refreshed after CSV import | Import stage invalidates relevant Riverpod providers after database writes. |
| #63 | Missing `h:mm:ss a` time format | Transform stage expanded format list tries 12-hour-with-seconds first. |
| #64 | No user control over timezone interpretation | Configure stage offers wall-clock / UTC / offset dropdown. |

## File Organization

### Deleted

```
lib/core/services/export/csv/csv_import_service.dart
test/core/services/export/csv/csv_import_service_test.dart
```

Export side (`csv_export_service.dart`, `csv_export_dialog.dart`) stays untouched.

### Replaced (rewritten)

```
lib/features/universal_import/data/parsers/csv_import_parser.dart   -- thin adapter to pipeline
lib/features/universal_import/data/services/field_mapping_engine.dart -- replaced by PresetRegistry
lib/features/universal_import/data/services/value_transforms.dart    -- replaced by transform pipeline
```

### New Files

```
lib/features/universal_import/data/csv/
  pipeline/
    csv_pipeline.dart              -- orchestrator: runs stages in sequence
    csv_detector.dart              -- Stage 1: header analysis, preset matching
    csv_parser.dart                -- Stage 3: raw CSV parsing, encoding, line endings
    csv_transformer.dart           -- Stage 4: apply mappings, types, units, times
    csv_correlator.dart            -- Stage 5: multi-file merge, entity linking
  presets/
    preset_registry.dart           -- registry: built-in + user presets
    csv_preset.dart                -- preset data model
    built_in_presets.dart          -- all 7 preset definitions as const data
  extractors/
    entity_extractor.dart          -- interface
    dive_extractor.dart
    tank_extractor.dart
    profile_extractor.dart
    site_extractor.dart
    buddy_extractor.dart
    tag_extractor.dart
    gear_extractor.dart
  transforms/
    time_resolver.dart             -- format detection, AM/PM, informal times
    unit_detector.dart             -- header parsing, heuristics, per-column detection
    value_converter.dart           -- unit conversions, type coercion
  models/
    detection_result.dart
    import_configuration.dart
    parsed_csv.dart
    transformed_rows.dart
    correlated_payload.dart
```

### Test Structure

Mirrors source under `test/features/universal_import/data/csv/`.

### Wizard Provider Changes

`universal_import_providers.dart` gets a new wizard step (`additionalFiles`) between source confirmation and field mapping. CSV-specific logic moves from the provider into the pipeline.

### Database Change

New table for user-saved presets:

```sql
CREATE TABLE csv_presets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  preset_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

## Testing Strategy

- Each pipeline stage has unit tests with known inputs/outputs
- Each extractor has unit tests covering normal cases and edge cases (empty tanks, leading-comma buddies, etc.)
- Time resolver tests cover all format variations including AM/PM with seconds, informal tokens, and timezone interpretation modes
- Unit detector tests cover header parsing, heuristic detection, and mixed-unit CSVs
- Integration tests use the three Subsurface sample CSV files as golden test data
- Existing test scenarios from the deleted legacy parser are preserved as regression tests in the new structure
- Preset detection tests verify ranking and threshold behavior
