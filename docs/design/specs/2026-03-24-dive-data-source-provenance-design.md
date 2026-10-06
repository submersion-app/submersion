# Dive Data Source Provenance

Track and display the origin of every dive's data, from manual entry to multi-computer consolidation.

## Problem

Dives enter the system from multiple sources (manual entry, UDDF files, FIT files, HealthKit, Bluetooth), but provenance is not surfaced in the UI. Existing field names (`wearableSource`, `DiveComputerReading`) are misleading now that sources extend well beyond wearables and dive computers. When multiple computers' data is consolidated into one dive, there is no clear way to see which source contributed which values.

## Goals

1. Every dive displays a Data Source section showing where its data came from.
2. Multi-source dives show per-source cards with individual metrics, enabling comparison.
3. Field-level attribution badges indicate which source provided each metric value.
4. Original import filename and file format are preserved and displayed.
5. Misleading entity/field names are corrected to reflect the broader concept of "data sources."

## Non-Goals

- Per-field provenance table (audit trail for every field change). Attribution is computed at display time.
- Tracking manual user edits as a distinct source. If needed later, provenance can be layered on.
- New import format parsers (CSV, Subsurface .ssrf). The schema supports them; parsers are separate work.

## Approach: Computed Attribution

Field-level attribution is derived at display time by comparing `DiveDataSource` records against the dive's canonical values. No dedicated provenance table.

- Single-source dives: every field attributed to that source (badges hidden -- see below).
- Multi-source dives: primary source's values are canonical; "best available" logic applies to heart rate (prefer HR sensor) and GPS (prefer GPS-equipped source).
- Viewing mode: user taps a secondary card to temporarily swap displayed values; badges update to reflect the viewed source.

## Data Model Changes

### Renames

| Current | New | Scope |
|---------|-----|-------|
| `dive_computer_data` (table) | `dive_data_sources` | Database |
| `DiveComputerData` (Drift class) | `DiveDataSources` | Drift |
| `DiveComputerReading` (entity) | `DiveDataSource` | Domain |
| `wearableSource` (on Dive) | `importSource` | Dive entity + dives table |
| `wearableId` (on Dive) | `importId` | Dive entity + dives table |
| `getComputerReadings()` | `getDataSources()` | Repository |
| `hasMultipleComputers()` | `hasMultipleDataSources()` | Repository |
| `setPrimaryComputer()` | `setPrimaryDataSource()` | Repository |
| `backfillPrimaryComputerReading()` | `backfillPrimaryDataSource()` | Repository |
| `DiveComputersSection` | `DataSourcesSection` | UI widget |
| `dive_computers_section.dart` | `data_sources_section.dart` | File |

**Kept as-is:**

- `dive_computers` table (physical device inventory) -- these are computers.
- `computerId` FK on `dive_profiles` -- correctly links profile points to a physical device.
- `ImportSource` enum values (`appleWatch`, `garmin`, `suunto`, `uddf`) -- ecosystem identifiers, not affected by rename.

### New Columns on `dive_data_sources`

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `source_file_name` | TEXT | Yes | Original filename (e.g., `Suunto_DM5_Export.uddf`) |
| `source_file_format` | TEXT | Yes | File format identifier: `uddf`, `fit`, `csv`, `ssrf`, `xml`, `healthkit`, `bluetooth` |

### Migration

Single schema migration (v55 or next available):

1. Rename table `dive_computer_data` to `dive_data_sources`.
2. Rename columns on `dives`: `wearable_source` to `import_source`, `wearable_id` to `import_id`.
3. Add `source_file_name` (TEXT, nullable) to `dive_data_sources`.
4. Add `source_file_format` (TEXT, nullable) to `dive_data_sources`.

### DiveDataSource Entity

Updated fields on the domain entity (renamed from `DiveComputerReading`):

```dart
class DiveDataSource extends Equatable {
  final String id;
  final String diveId;
  final String? computerId;
  final bool isPrimary;
  final String? computerModel;
  final String? computerSerial;
  final String? sourceFormat;      // existing: ecosystem (e.g., "suunto")
  final String? sourceFileName;    // new: original filename
  final String? sourceFileFormat;  // new: file format (e.g., "uddf")
  final double? maxDepth;
  final double? avgDepth;
  final int? duration;
  final double? waterTemp;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final double? maxAscentRate;
  final double? maxDescentRate;
  final int? surfaceInterval;
  final double? cns;
  final double? otu;
  final String? decoAlgorithm;
  final int? gradientFactorLow;
  final int? gradientFactorHigh;
  final DateTime importedAt;
  final DateTime createdAt;
  // ... copyWith, Equatable props
}
```

## UI Design

### Data Sources Section

Replaces the existing `DiveComputersSection`. Always visible on the dive detail page (not conditional on 2+ sources).

**Section header:** "Data Source" (singular) for single-source dives, "Data Sources" (plural) for multi-source.

#### Scenario A: Manually Entered Dive

- Single card with pen icon, "Manual Entry" label, "Manual" badge.
- Shows creation date only.
- No overflow menu.

#### Scenario B: Single Imported Source

- Single card with device icon, computer model name.
- Details grid: serial, firmware, entry time, exit time, import date, format.
- Original filename displayed at bottom of card.
- Overflow menu available (for future actions).

#### Scenario C: Manual Entry + Consolidated Computer

When a manually entered dive later has a computer log consolidated into it:

- Two cards: the computer source (now primary, with rich data) and the original manual entry (secondary, sparse).
- Each card shows its own metrics row (max depth, duration, temp, CNS).
- Manual entry card shows the values the user originally typed, with `--` for fields they left empty.

#### Scenario D: Multi-Source (N sources)

- Cards stack vertically, no limit on source count.
- Primary card: green left border, "Primary" badge.
- Secondary cards: muted styling, "Secondary" badge.
- Each card shows: device icon, model name, serial, firmware (if available), entry/exit times, import date, format, filename, and a metrics row.
- Overflow menu on each card: "Set as primary" (secondary cards only), "Unlink."

### Tap-to-View Interaction

- Tapping a secondary card temporarily activates it as the viewed source.
- The tapped card gets a blue highlight and "Viewing" badge.
- Main dive metrics update to show the viewed source's values.
- Field-level attribution badges update accordingly.
- The profile chart switches to the viewed source's depth profile.
- This is view-only and resets when leaving the page.
- "Set as primary" in the overflow menu commits the change permanently.

### Field-Level Attribution Badges

Small inline badges on dive metric values indicating which source provided each value.

**Rules:**

- Only shown when the dive has 2+ data sources.
- Shown on all imported metrics by default.
- "Best available" logic: heart rate badge shows the HR sensor source (e.g., Apple Watch); GPS shows the GPS-equipped source. All other fields show the primary (or viewed) source.
- When viewing a secondary source, badges update to reflect the viewed source.
- Fields the viewed source lacks show `--`.

**Settings toggle:**

- Setting: "Show data source badges" (boolean, default: on).
- Located in the Display or Dive Details settings group.
- Only affects field-level badges; the Data Sources section itself always appears.

## Import Pipeline Changes

### File Imports (UDDF, FIT, CSV, .ssrf, XML)

1. Parser services already receive the file path.
2. Extract filename: `path.split('/').last` (or platform path utility).
3. Extract format from file extension.
4. Add `sourceFileName` and `sourceFileFormat` to `ImportedDive` entity.
5. `ImportedDiveConverter` maps these fields to the `DiveDataSource` record.

### Non-File Imports

| Source | `sourceFileName` | `sourceFileFormat` |
|--------|------------------|--------------------|
| Apple Watch (HealthKit) | null | `healthkit` |
| Bluetooth (direct download) | null | `bluetooth` |

### Backfill on Merge/Consolidation

When `backfillPrimaryDataSource()` creates a record from an existing dive's fields:

- If the dive has `importSource` set, infer format from it.
- If the dive was manual entry, both `sourceFileName` and `sourceFileFormat` are null.

### ImportedDive Entity Changes

```dart
class ImportedDive {
  final ImportSource source;
  final String? sourceId;
  final String? sourceFileName;    // new
  final String? sourceFileFormat;  // new
  // ... existing fields
}
```

## Testing Strategy

- **Unit tests:** Computed attribution logic (single source, multi-source, best-available HR/GPS).
- **Unit tests:** `DiveDataSource` entity creation, `copyWith`, equality.
- **Integration tests:** Import pipeline end-to-end -- verify filename and format persisted.
- **Integration tests:** Merge/consolidation -- verify backfill creates correct records.
- **Widget tests:** `DataSourcesSection` rendering for all scenarios (manual, single, multi).
- **Widget tests:** Field badge visibility (hidden for single source, shown for multi, respects setting).
- **Widget tests:** Tap-to-view interaction -- verify metric values swap and badges update.
- **Migration test:** Schema migration v55 applies cleanly, existing data preserved.
