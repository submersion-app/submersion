# Universal Import Wizard -- Design Document

**Date:** 2026-02-09
**Scope:** Sections 13.2 (Interoperability) and 13.3 (Universal Import)
**Phase:** v1.5 smart wizard + format detection; v2.0 native parsers for additional apps

---

## Overview

A unified import wizard that replaces the current separate import flows (UDDF, CSV, FIT) with a single intelligent pipeline. The user picks any file, the system auto-detects the format and source app, then presents a consistent review-and-select experience regardless of format -- the same tabbed entity selection UI used by the existing UDDF import wizard.

## Design Decisions

1. **Auto-detect first** -- User picks a file, system identifies format and source app automatically. No upfront app selection required.
2. **Confidence-based detection** -- Detection returns a confidence score. Above 0.85, show result and let user confirm. Below 0.85, show result with "Not right? Select manually" fallback.
3. **Unified review experience** -- All import formats produce the same `ImportPayload` structure. The review step dynamically shows tabs only for entity types that have data (dives, sites, buddies, etc.). A FIT import shows one "Dives" tab; a full Submersion UDDF backup shows all 11 tabs.
4. **Per-item selection with duplicate detection** -- Every item can be individually selected/deselected. Duplicates are auto-detected and auto-deselected with "Likely duplicate" / "Possible duplicate" badges. Bulk select/deselect controls at the top of each tab.
5. **Batch tagging** -- All imported items get tagged with an auto-generated label (e.g., "MacDive Import 2026-02-09") for easy filtering and management. User can edit or clear the tag before import.
6. **Phased approach** -- v1.5 ships format detection for 12 formats across 10 source apps, but only implements parsers for CSV, UDDF, FIT, and Subsurface XML. Unsupported formats show helpful instructions to export as UDDF/CSV. v2.0 adds native parsers for remaining apps.

---

## Architecture

### Pipeline

```
File Selection -> Format Detection -> Source Confirmation ->
Field Mapping (CSV only) -> Review & Select -> Import -> Summary
```

### Key Components

| Component | Responsibility |
|-----------|----------------|
| `FormatDetector` | Inspects file contents to identify format and source app. Returns `DetectionResult` with confidence score. |
| `ImportParser` (abstract) | Base interface for all parsers. Produces unified `ImportPayload`. |
| `FieldMappingEngine` | CSV-specific: maps source columns to Submersion fields using app presets or user-defined mappings. |
| `ValueTransforms` | Unit conversions (ft->m, F->C, psi->bar), date parsing, scale normalization. |
| `ImportPreviewService` | Runs duplicate detection across all entity types. Produces initial selection with duplicates deselected. |
| `UniversalImportPage` | Multi-step wizard widget orchestrating the flow. |

---

## Format Detection Engine

The `FormatDetector` reads the first few KB of a file and runs a chain of detectors ordered by specificity:

### Detection Chain

**1. Binary / Magic Bytes:**
- FIT (Garmin): `0x2E464954` magic -> 1.0 confidence
- SQLite: `SQLite format 3\000` header -> then inspect tables:
  - Shearwater Cloud DB: `dive_log`, `dive_log_record` tables (0.95)
  - Suunto DM5: `Dive`, `DiveProfile` tables (0.95)
  - Scubapro LogTRAK/ASD: specific table schema (0.90)
  - Unknown SQLite: "unrecognized database" (0.3)

**2. XML Inspection (~4KB peek):**
- `<uddf>` root -> UDDF (0.95)
- `<divelog program="subsurface">` -> Subsurface XML (0.98)
- `<DivingLog>` root -> Diving Log XML (0.95)
- `<sml>` root -> Suunto SML (0.95)
- DAN DL7 header markers (0.90)
- Unknown XML with dive keywords -> Generic XML (0.5)

**3. CSV Header Analysis:**
Score against known app signatures:
- MacDive: `"Dive No"`, `"Max. Depth"`, `"Bottom Temp"`
- Diving Log: `"Divelog"` prefix columns
- DiveMate: `"DiveMate"` in headers or characteristic columns
- Subsurface CSV: `"divesiteid"`, `"cylindertype"`
- SSI MyDiveGuide: SSI-specific column patterns
- Garmin Connect CSV: `"Activity Type"`, `"Max Depth"` (Garmin naming)
- Shearwater Cloud CSV: Shearwater-specific headers
- Generic dive CSV: keyword matching on standard terms (`depth`, `duration`, `temp`, etc.)

**4. Fallback:** Unknown format -> confidence 0.0, prompt manual selection

### Models

```dart
enum ImportFormat {
  csv, uddf, subsurfaceXml, divingLogXml, suuntoSml,
  suuntoDm5, fit, shearwaterDb, scubapro,
  danDl7, sqlite, unknown
}

enum SourceApp {
  submersion, subsurface, macdive, divingLog, diveMate,
  shearwater, suunto, garminConnect, scubapro,
  ssiMyDiveGuide, dan, generic
}

class DetectionResult {
  final ImportFormat format;
  final SourceApp? sourceApp;
  final double confidence;            // 0.0 - 1.0
  final Map<String, String>? suggestedMapping;  // CSV: detected column -> field
  final List<String> warnings;
}
```

---

## Parser Layer

### Abstract Interface

```dart
abstract class ImportParser {
  Future<ImportPayload> parse(Uint8List fileBytes, {ImportOptions? options});
  List<ImportFormat> get supportedFormats;
}
```

### Unified Import Payload

All parsers produce the same structure, mapping directly to the entity type tabs in the review UI:

```dart
class ImportPayload {
  final Map<ImportEntityType, List<Map<String, dynamic>>> entities;
  final List<ImportWarning> warnings;
  final Map<String, dynamic> metadata;  // source app version, export date, etc.
}

enum ImportEntityType {
  dives, sites, trips, equipment, equipmentSets,
  buddies, diveCenters, certifications, courses, tags, diveTypes
}
```

This mirrors the existing `UddfEntityType` enum -- we generalize it to `ImportEntityType` shared across all formats.

### Parser Implementations (v1.5)

| Parser | Formats | Entity types produced |
|--------|---------|---------------------|
| `CsvImportParser` | CSV (all apps) | Dives, Sites (if location columns present) |
| `UddfImportParser` | UDDF, Subsurface XML | All entity types (depending on source richness) |
| `FitImportParser` | FIT (Garmin) | Dives only |
| `PlaceholderParser` | All others | Returns error with instructions to export as UDDF/CSV |

Existing parsers (`CsvImportService`, `UddfFullImportService`, `FitParserService`) are refactored behind the `ImportParser` interface, converting their output to the unified `ImportPayload` format.

### v2.0 Native Parsers (Future)

| Parser | Formats |
|--------|---------|
| `ShearwaterParser` | Shearwater Cloud SQLite DB |
| `SuuntoParser` | Suunto DM5 SQLite, SML XML |
| `ScubaproParser` | Scubapro ASD files |
| `DanDl7Parser` | DAN DL7 format |

---

## CSV Field Mapping

For CSV imports, a mapping step appears between detection and review.

### Preset Mappings

Ship with built-in presets for known apps:

```dart
class FieldMapping {
  final String name;              // e.g., "MacDive Default"
  final SourceApp? sourceApp;
  final List<ColumnMapping> columns;
}

class ColumnMapping {
  final String sourceColumn;      // CSV header name
  final String targetField;       // Submersion field name
  final ValueTransform? transform;
  final String? defaultValue;
}
```

### Value Transforms

| Transform | Input Example | Output | When Applied |
|-----------|--------------|--------|--------------|
| `feetToMeters` | `98.4` | `30.0` | Depth from imperial apps |
| `fahrenheitToCelsius` | `78.8` | `26.0` | Temperature fields |
| `psiToBar` | `3000` | `206.8` | Tank pressures |
| `cubicFeetToLiters` | `80` | `11.1` | Tank volumes |
| `minutesToSeconds` | `45` | `2700` | Duration stored as minutes |
| `hmsToSeconds` | `0:45:30` | `2730` | Duration in H:M:S format |
| `dateTimeParse` | Various | `DateTime` | Per-app date format strings |
| `visibilityScale` | `"Good"` / `"3"` | Normalized enum | App-specific scales |
| `diveTypeMap` | `"Shore"` / `"Boat"` | Submersion enum | Standardize labels |
| `ratingScale` | `1-10` or `1-5` | `1-5` | Normalize ratings |

**Auto-inference:** The `FieldMappingEngine` inspects sample values to suggest transforms (depth > 100 with "ft" hint -> feet; temp > 50 -> Fahrenheit; pressure > 500 -> PSI). Shown to user as "Detected imperial units -- converting to metric" with override option.

**Side-by-side preview:** In the mapping step, show original and converted values so the user can spot bad conversions before proceeding.

---

## Review & Select (Unified)

The review step is the **same UI for all import formats**, generalized from the existing UDDF import wizard's Step 1.

### Behavior

1. Tabs appear dynamically for each `ImportEntityType` that has data
2. Each tab shows `"N of M selected"` with Select All / Deselect All
3. Each item has a checkbox for individual select/deselect
4. Duplicates are auto-detected and auto-deselected:
   - **Likely duplicate** (score >= 0.7): red badge, auto-deselected
   - **Possible duplicate** (score 0.5-0.7): amber badge, auto-selected but flagged
5. Dive cards show: date/time, site name, max depth, duration, duplicate badge
6. Other entity cards show: name, subtitle (type, location, agency, etc.), duplicate badge
7. Bottom bar shows total selected count and Import button

### Duplicate Detection

Reuses the existing `UddfDuplicateChecker` scoring logic:
- **Dives**: fuzzy match on date/time (within 1 hour), max depth (within 10%), duration (within 10%)
- **Sites**: name matching (normalized)
- **Equipment, Buddies, etc.**: name + type matching

No merge functionality in v1.5 -- strictly import-or-skip per item.

---

## Batch Tagging

Before import begins, the user sees an auto-generated tag field:

- Default: `"<SourceApp> Import <YYYY-MM-DD>"` (e.g., "MacDive Import 2026-02-09")
- User can edit or clear the tag
- Applied to all imported entities via the existing `tags` / `dive_tags` tables
- No schema changes needed -- uses the existing tag infrastructure
- The tag serves as an implicit import batch ID for filtering and bulk operations

---

## Wizard UI Flow

Route: `/transfer/import-wizard` (accessible from Transfer hub)

| Step | Name | Description |
|------|------|-------------|
| 0 | File Selection | Pick a file via file_picker. FormatDetector runs automatically. |
| 1 | Source Confirmation | Show detection result with confidence. User confirms or overrides. If unsupported format, show instructions to export as UDDF/CSV. |
| 2 | Field Mapping | CSV only -- skipped for UDDF/FIT/XML. Two-column mapping table with transform indicators. |
| 3 | Review & Select | Unified tabbed entity selection (see above). Batch tag field. |
| 4 | Importing | Progress indicator with phase label and count. |
| 5 | Summary | Import complete with per-entity-type counts. "View imported dives" button. |

Step indicator shows 4 dots for non-CSV (Select, Review, Import, Done) or 5 dots for CSV (Select, Map, Review, Import, Done). The Source Confirmation step is visually merged into File Selection for simplicity.

### Widget Structure

- `UniversalImportPage` -- StatefulWidget with step management
- `FileSelectionStep` -- File picker + auto-detection
- `SourceConfirmationStep` -- Detection result display + override
- `FieldMappingStep` -- CSV column mapping (conditional)
- `ImportReviewStep` -- Unified tabbed entity selection (generalized from UDDF wizard)
- `ImportProgressStep` -- Progress indicator
- `ImportSummaryStep` -- Results with counts

---

## Error Handling & Validation

| Check | Severity | Behavior |
|-------|----------|----------|
| Missing required field (date) | Error | Item excluded from import, shown in warnings |
| Missing optional field (site, temp) | Info | Imported with null, noted in review |
| Duplicate detected | Warning | Shown with badge, auto-deselected (likely) or flagged (possible) |
| Invalid value (negative depth) | Error | Item excluded, highlighted in review |
| Date out of reasonable range | Warning | Flagged but importable |
| Unrecognized CSV column | Info | Shown as "unmapped" in field mapping step |
| File too large (>50MB) | Error | Shown before parsing begins |
| Corrupt/unreadable file | Error | Shown at detection step with helpful message |
| Unsupported format detected | Info | Show format name + instructions to export as UDDF/CSV |

### Partial Import Recovery

Each item is imported in its own transaction. If import fails mid-way:
- Already-imported items are committed
- Summary shows "N of M imported, 1 failed, K remaining"
- "Retry remaining" option available
- Batch tag makes partial imports easy to identify and clean up

---

## File Structure

### New Files

```
lib/features/universal_import/
  data/
    services/
      format_detector.dart              # Format detection engine
      field_mapping_engine.dart          # CSV column mapping + presets
      value_transforms.dart             # Unit/format conversions
      import_duplicate_checker.dart     # Generalized duplicate detection
    models/
      detection_result.dart             # DetectionResult, ImportFormat, SourceApp
      import_payload.dart               # ImportPayload, ImportEntityType
      import_warning.dart               # ImportWarning model
      field_mapping.dart                # FieldMapping, ColumnMapping
      import_options.dart               # Import config (tag, etc.)
    parsers/
      import_parser.dart                # Abstract base
      csv_import_parser.dart            # Refactored from CsvImportService
      uddf_import_parser.dart           # Refactored from UddfFullImportService
      fit_import_parser.dart            # Refactored from FitParserService
      placeholder_parser.dart           # "Not yet supported" fallback
    presets/
      macdive_preset.dart               # MacDive CSV field mapping
      diving_log_preset.dart            # Diving Log CSV field mapping
      subsurface_csv_preset.dart        # Subsurface CSV field mapping
      divemate_preset.dart              # DiveMate CSV field mapping
  presentation/
    pages/
      universal_import_page.dart        # Main wizard page
    widgets/
      file_selection_step.dart
      source_confirmation_step.dart
      field_mapping_step.dart
      import_review_step.dart           # Generalized from UDDF review step
      import_progress_step.dart
      import_summary_step.dart
      import_entity_card.dart           # Generalized from UddfEntityCard
      import_dive_card.dart             # Dive-specific card with metrics
      duplicate_badge.dart              # Duplicate indicator badge
      batch_tag_field.dart              # Editable import tag
  providers/
    universal_import_providers.dart     # Riverpod providers + state notifier
```

### Files to Modify

- `app_router.dart` -- Add `/transfer/import-wizard` route
- `transfer_page.dart` -- Add "Universal Import" entry point (eventually replaces individual import options)

### No Schema Changes

Uses existing `tags` and `dive_tags` tables for batch tagging. No new database tables required.

---

## Testing Strategy

| Test Type | What | Priority |
|-----------|------|----------|
| Unit | `FormatDetector` with sample files for each format | Critical |
| Unit | `ValueTransforms` -- all conversion functions | Critical |
| Unit | `FieldMappingEngine` -- preset matching, custom mapping | High |
| Unit | Each parser's `parse()` method with known inputs | High |
| Unit | `ImportDuplicateChecker` -- scoring across entity types | High |
| Integration | Full pipeline: file -> detect -> parse -> review -> import | High |
| Widget | Wizard navigation, step transitions, state management | Medium |
| Widget | Review step: tab rendering, selection, duplicate badges | Medium |
| E2E | Import a real Subsurface UDDF export end-to-end | Medium |
| E2E | Import a MacDive CSV export end-to-end | Medium |

Test fixtures: Small sample export files (2-3 dives each) from each supported app, stored in `test/fixtures/imports/`.

---

## Implementation Phases

### v1.5: Smart Wizard (This Implementation)

- Format detection for all 12 formats
- Parser implementations for CSV, UDDF, FIT, Subsurface XML
- Unified review step with tabbed entity selection
- CSV field mapping with app presets (MacDive, Diving Log, DiveMate, Subsurface)
- Value transforms (unit conversions, date parsing)
- Batch tagging
- Duplicate detection across all entity types
- Placeholder messages for unsupported formats

### v2.0: Native Parsers (Future)

- Shearwater Cloud SQLite parser
- Suunto DM5/SML parsers
- Scubapro ASD parser
- DAN DL7 parser
- Garmin Connect API integration
- Saved user-defined mapping templates
- Import merge capability (merge duplicate fields rather than skip/import)
