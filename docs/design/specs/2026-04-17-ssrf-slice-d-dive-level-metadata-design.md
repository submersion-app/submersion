# SSRF Slice D — Dive-Level Metadata + Provenance Fill-Out (Design)

**Date:** 2026-04-17
**Status:** Draft
**Relates to:** Issue #155 (follow-up). Closes three medium-priority SSRF gaps identified in the import-gap tracker: dive-level deco metadata, surface pressure, source provenance snapshot.

## Purpose

Parse three categories of dive-level metadata from SSRF divecomputer children (`<extradata>` keys + `<surface>` attribute + `<divecomputer model>` attribute) and populate the existing backend columns that have been waiting for them. No schema work; all target columns exist on `Dives` and `DiveDataSources`. No cross-dive derivations; altitude and surface interval stay deferred.

## Scope

**In scope:**

1. **Dive computer identity** — parse `<divecomputer model='...'>` attribute + `<extradata key='Serial'>` + `<extradata key='FW Version'>`, populate `Dives.diveComputerModel/Serial/Firmware` and `DiveDataSources.computerModel/Serial` (firmware field absent on DiveDataSources — Dives-only).
2. **Deco metadata** — parse `<extradata key='Deco model' value='GF X/Y'>` string, split into `decoAlgorithm='buhlmann'` + `gradientFactorLow=X` + `gradientFactorHigh=Y` on both Dives and DiveDataSources. Non-GF formats stored as raw lowercased algo string without GFs.
3. **Surface pressure** — parse `<surface pressure='X bar'/>` nested in `<divecomputer>`, populate `Dives.surfacePressure` (DiveDataSources has no matching field — Dives-only).
4. **Tests** — targeted parser tests for each mapping + end-to-end importer test using `dual-cylinder.ssrf` fixture to verify the full chain.
5. **Tracker update** — three rows flip from `Partial`/`No` closer to `Yes` on SSRF; Slice D notes bullet.

**Explicitly out of scope:**

- **Altitude from barometric pressure** (no direct SSRF signal; requires derivation)
- **Surface interval computation** (requires cross-dive context the parser doesn't have)
- **UDDF parity** (separate slice)
- **Deco conservatism** (Subsurface doesn't commonly emit this; `decoConservatism` column stays null)
- **Battery info, Logversion, Device ID** (no meaningful user-facing field to map to; left in raw XML if anyone wants them later)
- **Non-GF deco algo normalization** (store as raw string rather than invent a `vpm-b` canonical form)
- **Schema work** (every target column already exists)

## Architecture Changes

**Files modified (code):**
- `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart` — add `_parseDiveComputerMetadata` helper + `_parseDecoModel` sub-helper; call from `_parseDive` to merge metadata into the dive map.
- `lib/features/dive_import/data/services/uddf_entity_importer.dart` — extend the Dive construction path to read the new keys (`decoAlgorithm`, `gradientFactorLow`, `gradientFactorHigh`, `surfacePressure`, `diveComputerModel`, `diveComputerSerial`, `diveComputerFirmware`) from `diveData` and pass to the `Dives` insert companion. Extend the `DiveDataSources` construction path to mirror the subset of fields that has columns there.

**Files modified (tests):**
- `test/features/universal_import/data/parsers/subsurface_xml_parser_test.dart` — new `dive-level metadata` group with parser-focused tests.
- `test/features/dive_import/data/services/uddf_entity_importer_test.dart` — one end-to-end test using `dual-cylinder.ssrf` or synthetic inline XML to assert persistence.

**Files modified (docs):**
- `docs/superpowers/specs/2026-04-05-imported-profile-gap-priority-tracker.md` — three row updates + Slice D bullet.

**No schema migration. No new columns. No new domain entities.**

## Detailed Changes

### 1. `_parseDecoModel` helper

New file-level private function (or static method, matching existing style in the parser):

```dart
/// Parses a Subsurface "Deco model" extradata value into algorithm + gradient
/// factors. Subsurface emits strings like `'GF 40/85'` for Bühlmann-with-GF.
/// Non-GF formats (e.g., `'VPM-B +2'`) are preserved as the raw lowercased
/// algorithm string with no GF extraction.
///
/// Returns a map with optional keys:
///   - `'decoAlgorithm'`: String
///   - `'gradientFactorLow'`: int
///   - `'gradientFactorHigh'`: int
Map<String, dynamic> _parseDecoModel(String? value) {
  if (value == null || value.trim().isEmpty) return const {};
  final trimmed = value.trim();
  final gfMatch = RegExp(r'^GF\s+(\d+)\s*/\s*(\d+)$').firstMatch(trimmed);
  if (gfMatch != null) {
    return {
      'decoAlgorithm': 'buhlmann',
      'gradientFactorLow': int.parse(gfMatch.group(1)!),
      'gradientFactorHigh': int.parse(gfMatch.group(2)!),
    };
  }
  return {'decoAlgorithm': trimmed.toLowerCase()};
}
```

### 2. `_parseDiveComputerMetadata` helper

New private method that consolidates all dive-level metadata extraction from a `<divecomputer>` element:

```dart
Map<String, dynamic> _parseDiveComputerMetadata(XmlElement divecomputer) {
  final result = <String, dynamic>{};

  // Dive computer identity from the element's own attributes
  final model = divecomputer.getAttribute('model');
  if (model != null && model.isNotEmpty) result['diveComputerModel'] = model;

  // Surface pressure from the `<surface>` child
  final surface = divecomputer.findElements('surface').firstOrNull;
  if (surface != null) {
    final pressure = _parseDouble(surface.getAttribute('pressure'));
    if (pressure != null) result['surfacePressure'] = pressure;
  }

  // Extradata children — build a name→value map once, then look up keys of
  // interest. O(n) pass rather than n-by-k lookups.
  final extradata = <String, String>{};
  for (final ed in divecomputer.findElements('extradata')) {
    final key = ed.getAttribute('key');
    final value = ed.getAttribute('value');
    if (key != null && value != null) extradata[key] = value;
  }

  final serial = extradata['Serial'];
  if (serial != null && serial.isNotEmpty) result['diveComputerSerial'] = serial;

  final fwVersion = extradata['FW Version'];
  if (fwVersion != null && fwVersion.isNotEmpty) {
    result['diveComputerFirmware'] = fwVersion;
  }

  final decoModel = extradata['Deco model'];
  if (decoModel != null) {
    result.addAll(_parseDecoModel(decoModel));
  }

  return result;
}
```

Called from `_parseDive` and its result is merged into the per-dive result map. Exact merge call:

```dart
    if (divecomputer != null) {
      result.addAll(_parseDiveComputerMetadata(divecomputer));
    }
```

### 3. Importer changes (`uddf_entity_importer.dart`)

**Discovery required**: the plan phase must open `_importDives` (or whatever method builds the `Dives` insert companion from `diveData`) and verify exactly which of these keys are currently being read:

- `diveComputerModel`
- `diveComputerSerial`
- `diveComputerFirmware`
- `decoAlgorithm`
- `gradientFactorLow`
- `gradientFactorHigh`
- `surfacePressure`

Most are likely NOT currently consumed. The plan adds them to the `DivesCompanion(...)` construction where missing.

Similarly for `DiveDataSources` — audit current construction, add:
- `computerModel`
- `computerSerial`
- `decoAlgorithm`
- `gradientFactorLow`
- `gradientFactorHigh`

(No firmware or surfacePressure on DiveDataSources — those stay Dives-only.)

### 4. Tests

**Parser-level tests** in `subsurface_xml_parser_test.dart` — new `group('dive-level metadata', ...)`:

```dart
group('dive-level metadata', () {
  test('parses divecomputer model attribute', () async { /* ... */ });

  test('parses Serial extradata into diveComputerSerial', () async { /* ... */ });

  test('parses FW Version extradata into diveComputerFirmware', () async { /* ... */ });

  test('parses Deco model "GF 40/85" into buhlmann + GF values', () async {
    // result['decoAlgorithm'] == 'buhlmann'
    // result['gradientFactorLow'] == 40
    // result['gradientFactorHigh'] == 85
  });

  test('parses Deco model non-GF format as lowercased algo string', () async {
    // `<extradata key='Deco model' value='VPM-B +2'/>`
    // result['decoAlgorithm'] == 'vpm-b +2'
    // no gradient factor fields set
  });

  test('parses surface pressure attribute', () async {
    // `<surface pressure='1.012 bar'/>`
    // result['surfacePressure'] == 1.012
  });

  test('ignores unrelated extradata keys', () async {
    // Battery type, Logversion, Battery at end, etc. — all silently skipped
  });

  test('all metadata absent yields no keys (no null-value noise)', () async {
    // Parser should not write `null` values for missing metadata;
    // instead omit the key entirely.
  });
});
```

**Importer-level end-to-end** in `uddf_entity_importer_test.dart`:

```dart
test('SSRF dive-level metadata persists end-to-end from dual-cylinder.ssrf fixture', () async {
  // Load the dual-cylinder.ssrf fixture, parse it, run through importer.
  // Assert the persisted Dives row has:
  //   diveComputerModel == 'Shearwater Peregrine'
  //   diveComputerSerial == '98d09a47'
  //   diveComputerFirmware == '86'
  //   decoAlgorithm == 'buhlmann'
  //   gradientFactorLow == 40
  //   gradientFactorHigh == 85
  //   surfacePressure == 1.012
  //
  // Assert the persisted DiveDataSources row mirrors:
  //   computerModel == 'Shearwater Peregrine'
  //   computerSerial == '98d09a47'
  //   decoAlgorithm == 'buhlmann'
  //   gradientFactorLow == 40
  //   gradientFactorHigh == 85
});
```

### 5. Tracker updates

- **Combined table `Dive-level deco metadata`**: SSRF Support `No` → `Partial` (we cover algo + GFs but not conservatism). Fixed stays `[ ]`.
- **Combined table `Surface pressure / altitude / surface interval`**: SSRF Support `No` → `Partial` (we cover surface pressure only; altitude and interval are deferred). Fixed stays `[ ]`.
- **Combined table `Source provenance snapshot (DiveDataSources)`**: SSRF Support `Partial` → `Yes` (model, serial, algo, GFs now landed; no outstanding SSRF-side gaps).
- **SSRF sub-table rows** for each of the above — update Why cells.
- **Slice D bullet** in Notes section.

## Required Plan-Phase Discovery

The plan must begin with a Discovery task that pins:

1. **Current Dive insert companion**: grep `uddf_entity_importer.dart` for the `DivesCompanion(...)` construction. List which dive-level fields are already populated vs. which will be added in this slice. Record line numbers.

2. **Current DiveDataSources insert companion**: same exercise. Identify whether an existing data-sources-build site exists, or whether we need to confirm one is already being populated at import time.

3. **`dual-cylinder.ssrf` fixture content verification**: confirm the exact attribute values we'll assert against in the end-to-end test (`model='Shearwater Peregrine'`, `Serial='98d09a47'`, `FW Version='86'`, `Deco model='GF 40/85'`, `pressure='1.012 bar'`).

## Data Flow

```
SSRF XML
    │
    ▼
SubsurfaceXmlParser._parseDive
    │
    ├── existing: profile, tanks, events, gasSwitches (Slice A/C/C.2)
    │
    └── NEW: _parseDiveComputerMetadata
        └── emits result keys:
            diveComputerModel, diveComputerSerial, diveComputerFirmware,
            decoAlgorithm, gradientFactorLow, gradientFactorHigh,
            surfacePressure
    │
    ▼
uddf_entity_importer._importDives
    │
    ├── DivesCompanion ← read the new keys, populate matching columns
    ├── DiveDataSourcesCompanion ← mirror the subset with matching columns
    │
    ▼
DB rows: Dives + DiveDataSources
```

## Error Handling / Edge Cases

- **Malformed numeric values**: `_parseDouble` returns null → key is omitted (no error, no null-value noise).
- **GF regex mismatch**: falls through to raw-string preservation. Caller treats `decoAlgorithm` as a free-form string.
- **Extradata key casing**: Subsurface emits `'Serial'`, `'FW Version'`, `'Deco model'` with specific capitalization. Parser matches exactly — if Subsurface ever changes casing, a test regression will catch it.
- **Missing `<surface>` element**: `surfacePressure` key absent; existing Dives row gets null in that column.
- **`<divecomputer model>` empty string**: treated as absent (existing `isNotEmpty` guard).

## Risks

- **DiveDataSources construction path may not exist where expected**: if the importer doesn't currently build a `DiveDataSources` row per SSRF import, this slice would either need to introduce that construction (scope creep) or defer the DiveDataSources mirror fields. Plan-phase Discovery must verify.
- **Existing importer fields may already consume some of these keys** via paths not audited during brainstorming. Plan phase must read `_importDives` end-to-end.
- **Fixture assertions coupled to specific values**: if `dual-cylinder.ssrf` is ever edited (e.g., serial number changed for privacy), the end-to-end test breaks. Acceptable trade-off for proving real round-trip.

## Follow-Up Slices

- **Altitude derivation**: from surface pressure via the standard barometric formula. Separate slice — has its own test shape (pressure-to-altitude calculation correctness, not XML parsing).
- **Surface interval derivation**: from consecutive dives' start/end times. Cross-dive computation requires list-of-dives context in the importer.
- **UDDF parity for dive-level metadata**: mirror the parser extraction work on the UDDF side. Separate slice.
- **Deco conservatism**: if a dive computer's export format surfaces this field (Subsurface doesn't commonly), wire it through.
- **Fuller DC provenance**: `descriptorVendor`, `descriptorProduct`, `descriptorModel`, `libdivecomputerVersion` on `DiveDataSources` — populated automatically during native DC imports today, but SSRF's `<divecomputer>` doesn't carry this shape directly. Could be mapped from the `model` string with a lookup table in a future slice.

## Why This Is a Single-Slice Fix

All three fields in scope share:
- Same source location (SSRF `<divecomputer>` element and its children)
- Same target surface (Dives + DiveDataSources columns that already exist)
- Same parser helper shape (attribute extraction + extradata map lookup)
- Same test pattern (assert specific attribute values after import)

Splitting into three slices would triple the ceremony without isolating meaningfully different risk. Keeping them together gives one plan, one PR, one review.
