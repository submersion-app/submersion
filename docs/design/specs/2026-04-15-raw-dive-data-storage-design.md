# Raw Dive Data Storage from Dive Computers

**Issue:** [#176](https://github.com/submersion-app/submersion/issues/176)
**Date:** 2026-04-15

## Problem

When Submersion downloads dives from a dive computer, the native libdivecomputer layer receives the raw per-dive bytes and immediately parses them into structured fields (depth, time, events, gas mixes, etc.). The raw bytes are discarded after parsing. This means:

1. **Parser bug fixes cannot be applied retroactively.** A dive imported with a buggy parser stays buggy forever.
2. **New parser features (e.g., Shearwater entry/exit GPS) cannot backfill old dives.** The user would need to re-download, but old dives may have been overwritten in the DC's rolling memory.
3. **There is no source-of-truth to revert to.** If an import corrupts a dive, the original data is gone.

This was raised by TnT (libdivecomputer developer) on [ScubaBoard](https://scubaboard.com/community/threads/submersion-free-open-source-dive-log-app-all-platforms-looking-for-dive-computer-testers.667061/post-10735581), recommending that dive log applications store raw DC data so users can re-parse when the library improves.

## Goal

Store the raw per-dive bytes from dive computer downloads in the application database, alongside enough metadata to re-parse them at any time without the physical dive computer. Provide user-facing entry points to trigger re-parsing when a new libdivecomputer version is available.

## Scope

- **DC downloads only (v1).** File-based imports (UDDF, FIT, CSV, Shearwater cloud, Subsurface XML) do not populate raw data in v1.
- **Schema is designed to accommodate file imports later.** All new columns are nullable; non-DC adapters can start populating them in a follow-up without schema changes.
- **Manual re-parse only.** No automatic re-parse on libdivecomputer version bump. Users trigger re-parse explicitly.
- **Re-parse entry points:** DC detail page (all dives from that computer) and dive detail page (single dive).
- **Passive backfill:** Users who re-download dives still present on the DC can use the new `replaceSource` wizard choice to capture raw bytes for existing dives.

## Out of Scope

| Item | Rationale |
|------|-----------|
| Multi-select batch re-parse from dive list | UI complexity; machinery supports it trivially when list-view multi-select is ready |
| "Re-parse everything in my log" nuclear option | No concrete use case; trivial to add on settings page later |
| File-import raw source storage | Schema ready; adapters don't populate in v1 |
| Auto-detect libdivecomputer version bump + prompt | Startup prompt UX is fragile; manual button covers the use case |
| Per-field "user-edited" tracking | Only needed if `diveDateTime` overwrite becomes a pain point |
| Compression of raw blobs | Dive blobs are 1-50 KB; compression adds complexity for negligible savings |
| Raw data in UDDF/backup exports | Separate spec when export formats are revisited |

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Storage location | BLOB column on `DiveDataSources` | Single atomic artifact, cascade deletes handle cleanup, no orphan risk. Typical blob is 1-50 KB; 5000 dives ~ 150 MB — manageable for SQLite. |
| Re-parse trigger | Manual button only | YAGNI; avoids startup-prompt edge cases (first install, version downgrade, dismissed prompt re-appearance) |
| Re-parse merge policy | Allowlist of computer-authored fields overwritten; user-authored fields preserved | Allowlist is conservative and ratchets open. Avoids clobbering user edits while still delivering parser bug fixes. |
| Backfill for pre-feature dives | Passive via re-download + `replaceSource` choice in review step | No magic for dives already lost from DC memory; explicit user action for dives still present |
| Dive computer deletion | `onDelete: setNull` on `DiveDataSources.computerId` FK | Preserves raw data and re-parse capability even after computer record is deleted |
| `diveDateTime` on re-parse | Always overwrite from DC clock | Simpler rule; manual clock corrections are rare; user can re-correct after re-parse |
| Tank names on re-parse | Preserved | User-assigned labels and preset associations are user-authored; gas mix, volume, and pressures are computer-authored and overwritten |

## Architecture

### End-to-end Flow

```
libdivecomputer                    (native, C)
    |  dive_callback(data, size, fingerprint, fsize, ...)
    v
libdc_download.c                   (C, per-platform)
    |  NEW: retain raw_bytes + fingerprint_bytes on libdc_parsed_dive_t
    v
Platform wrapper (Swift/Kotlin/C++/GObject)
    |  NEW: copy raw_bytes into ParsedDive
    v
Pigeon API: ParsedDive             (dive_computer_api.g.dart)
    |  NEW fields: rawData, rawFingerprint
    v
DiveComputerService.downloadEvents  (Dart stream)
    |  existing DiveDownloadedEvent carries extended ParsedDive
    v
parsed_dive_mapper.dart
    |  NEW: map raw-bytes fields onto DownloadedDive
    v
dive_import_service.dart -> dive_repository_impl.dart
    |  NEW: on insert, write rawData + descriptor onto DiveDataSources row
    |  NEW: on replaceSource, update existing DiveDataSources row in place
    v
SQLite: DiveDataSources             (new BLOB + descriptor columns)
    ^
    |  Re-parse manual action:
    |  iterates rows -> native parseRawDiveData(vendor, product, model, bytes)
    |  -> applyParsedUpdate: allowlisted fields back to Dives + child tables
```

### Schema Changes

Additions to `DiveDataSources` in `lib/core/database/database.dart`:

```dart
BlobColumn     get rawData                => blob().nullable()();
BlobColumn     get rawFingerprint         => blob().nullable()();
TextColumn     get descriptorVendor       => text().nullable()();
TextColumn     get descriptorProduct      => text().nullable()();
IntColumn      get descriptorModel        => integer().nullable()();
TextColumn     get libdivecomputerVersion => text().nullable()();
DateTimeColumn get lastParsedAt           => dateTime().nullable()();
```

All nullable because: (a) pre-existing rows have no blob; (b) non-DC sources never populate these in v1.

FK change on existing column:

```dart
TextColumn get computerId =>
    text().nullable().references(DiveComputers, #id, onDelete: KeyAction.setNull)();
```

#### Why this shape

- `rawData` + `descriptorVendor`/`descriptorProduct`/`descriptorModel` is exactly the `(Uint8List, vendor, product, model)` tuple required by `DiveComputerHostApi.parseRawDiveData`. Re-parse is a direct call.
- `rawFingerprint` is kept as raw bytes separate from the string fingerprint on `Dives`. Future libdivecomputer versions may derive a different string from the same bytes.
- `libdivecomputerVersion` is diagnostic: "which parser produced this dive's stored values?"
- `lastParsedAt` supports future "re-parse only dives not parsed since version X" optimization.
- No new table. `DiveDataSources` already models "per-source snapshot of a dive."

### Native Capture

#### C layer (`libdc_download.c` and platform equivalents)

Add raw byte fields to the existing `libdc_parsed_dive_t` struct:

```c
typedef struct {
    // ... existing parsed fields ...

    const unsigned char *raw_data;
    unsigned int raw_data_size;
    const unsigned char *raw_fingerprint;
    unsigned int raw_fingerprint_size;
} libdc_parsed_dive_t;
```

In `dive_callback`, after `parse_dive()` succeeds:

```c
dive.raw_data = data;
dive.raw_data_size = size;
dive.raw_fingerprint = fingerprint;
dive.raw_fingerprint_size = fsize;
```

No malloc needed. The pointers are valid for the callback's lifetime. Platform wrappers copy the bytes into their language's native byte-array type before the callback returns.

#### Platform wrappers

Each platform's `on_dive` callback adds two byte-array copies to the Pigeon `ParsedDive`:

- **macOS/iOS (Swift):** `Data(bytes:count:)` -> `FlutterStandardTypedData(bytes:)`
- **Android (Kotlin):** `ByteArray` with `System.arraycopy`
- **Linux (GObject) / Windows (C++):** `std::vector<uint8_t>` copy

No new FFI calls, callbacks, or native entry points.

### Pigeon API Changes

Add two nullable fields to `ParsedDive` in `pigeons/dive_computer_api.dart`:

```dart
class ParsedDive {
  // ... existing fields ...

  final Uint8List? rawData;
  final Uint8List? rawFingerprint;
}
```

Nullable for backwards compatibility (older native code sends null) and for non-DC adapters.

No changes to `parseRawDiveData`. It already accepts `Uint8List data` and returns `ParsedDive`.

### Dart Mapping

`parsed_dive_mapper.dart` passes through the new fields:

```dart
return DownloadedDive(
  // ... existing fields ...
  rawData: parsed.rawData,
  rawFingerprint: parsed.rawFingerprint,
);
```

`DownloadedDive` entity gets two new nullable `Uint8List` fields.

Device descriptor (`vendor`, `product`, `model`) and `libdivecomputerVersion` are session-level, not per-dive. They come from the `DiscoveredDevice` used to start the download and a single `getLibdivecomputerVersion()` call at session start. Written per-row at persistence time.

### Persistence & Import Flow

#### Initial import (new dive)

`_importNewDive()` already creates a `DiveDataSources` row. Extend it to also write:

| Field | Value | Source |
|-------|-------|--------|
| `rawData` | blob from `DownloadedDive.rawData` | Pigeon -> mapper |
| `rawFingerprint` | blob from `DownloadedDive.rawFingerprint` | Pigeon -> mapper |
| `descriptorVendor` | `discoveredDevice.vendor` | Download session |
| `descriptorProduct` | `discoveredDevice.product` | Download session |
| `descriptorModel` | `discoveredDevice.model` | Download session |
| `libdivecomputerVersion` | `getLibdivecomputerVersion()` | Called once at session start |
| `lastParsedAt` | `DateTime.now()` | Timestamp of this parse |

#### Conflict resolution: `replaceSource`

Rename existing `ConflictResolution.replace` to `ConflictResolution.replaceSource`. Update the two internal call sites in `dive_import_service.dart` (line 292 and line 508) and `ImportMode.replace` (line 314).

Flesh out `_updateExistingDive()` to be the proper implementation:

1. **Identify target row:** `SELECT FROM dive_data_sources WHERE diveId = :matchedDiveId AND computerId = :currentComputerId LIMIT 1`
2. **UPDATE that row in place:** blob fields, descriptor fields, source-snapshot fields (`maxDepth`, `avgDepth`, `duration`, `waterTemp`, `entryTime`, `exitTime`, `maxAscentRate`, `maxDescentRate`, `surfaceInterval`, `cns`, `otu`, `decoAlgorithm`, `gradientFactorLow`, `gradientFactorHigh`), `importedAt`, `lastParsedAt`
3. **UPDATE the `Dives` row** with computer-authored allowlist fields (only if target source `isPrimary == true`)
4. **REPLACE child tables** atomically in a transaction: `DiveProfiles` deleted per-source (`WHERE diveId AND computerId`); `DiveProfileEvents`, `GasSwitches`, `TankPressureProfiles` deleted per-dive (no `computerId` column); `DiveTanks` matched by `tankOrder` with user-field carry-over (see allowlist section)

#### Shared update function

```dart
Future<void> applyParsedUpdate({
  required String diveId,
  required String sourceRowId,
  required ParsedDive parsed,
  required String? descriptorVendor,
  required String? descriptorProduct,
  required int? descriptorModel,
  required String? libdivecomputerVersion,
  Uint8List? rawData,
  Uint8List? rawFingerprint,
})
```

Called from two paths:
- **`replaceSource`:** with raw bytes (from fresh download) + descriptor (from session)
- **Manual re-parse:** with `rawData: null` (bytes unchanged in DB) + descriptor from existing row + fresh `ParsedDive` from `parseRawDiveData`

One allowlist, one transaction, two callers.

#### Passive backfill during re-download

| User's choice in review step | Backfills raw bytes? | How |
|------------------------------|---------------------|-----|
| Skip | No | User said "leave it alone" |
| Import as new | Yes (new dive only) | New dive gets its own `DiveDataSources` with raw bytes |
| Replace (`replaceSource`) | Yes (existing dive) | Updates existing source row in place |
| Consolidate | Yes (new source row) | Creates new `DiveDataSources` row with raw bytes |

No hidden behavior. Backfill is an explicit user choice.

### Computer-Authored Field Allowlist

Fields on `Dives` that `applyParsedUpdate` is allowed to overwrite:

| Column | Reason |
|--------|--------|
| `maxDepth` | Sensor reading |
| `avgDepth` | Computed from profile |
| `duration` | Computed from profile |
| `minWaterTemp` / `maxWaterTemp` | Sensor reading |
| `diveMode` | DC-reported (OC, CCR, gauge, etc.) |
| `diveDateTime` | DC clock |
| `surfaceInterval` | DC-computed from prior dive |
| `cns` / `otu` | DC-computed exposure |

Never overwritten:

`notes`, `rating`, `visibility`, `current`, `diveNumber`, `diveSiteId`, `tripId`, `diverId`, `weatherConditions`, `surfaceTemp`, `tags`, `buddies`, `gear`, `customFields`, `diveTypeId`

Child tables replaced:

| Table | Has `computerId`? | Deletion scope | Behavior |
|-------|--------------------|---------------|----------|
| `DiveProfiles` | Yes | Per-source: `WHERE diveId = ? AND computerId = ?` | Delete matching rows, re-insert from fresh parse |
| `DiveProfileEvents` | No | Per-dive: `WHERE diveId = ?` | Delete all, re-insert |
| `GasSwitches` | No | Per-dive: `WHERE diveId = ?` | Delete all, re-insert |
| `TankPressureProfiles` | No | Per-dive: `WHERE diveId = ?` | Delete all, re-insert |
| `DiveTanks` | No | Per-dive with carry-over (see below) | Match old to new by `tankOrder`, overwrite DC fields, preserve user fields |

All within a single database transaction.

**DiveTanks carry-over strategy:** Match old tanks to new tanks by `tankOrder` (the DC's tank index). For each matched pair:
- Overwrite (computer-authored): `volume`, `workingPressure`, `startPressure`, `endPressure`, `o2Percent`, `hePercent`
- Preserve (user-authored): `tankName`, `presetName`, `equipmentId`, `tankRole`, `tankMaterial`
- New tanks (in fresh parse but not in old set): insert with default user-authored values
- Removed tanks (in old set but not in fresh parse): delete

**Multi-source limitation for events/switches/pressure:** `DiveProfileEvents`, `GasSwitches`, and `TankPressureProfiles` lack a `computerId` column, so re-parsing one source replaces ALL event/switch/pressure data for the entire dive. This is an existing limitation shared with the consolidation flow; it only affects multi-source dives and is acceptable for v1.

### UI Surfaces

#### 1. Import wizard: "Replace" choice (conditional)

In the duplicate-review step of the import wizard:

- **Condition:** matched dive has a `DiveDataSources` row where `computerId == <current download session's computer ID>`
- **If true:** show four choices — Skip, Import as new, **Replace**, Consolidate
- **If false:** show three choices — Skip, Import as new, Consolidate (Replace hidden)

Replace label: **"Replace source data"** with explanatory subtitle: *"Update this dive from [computer name]. Refreshes profile and sensor data. Your notes, site, buddies, and other edits are preserved."*

#### 2. DC detail page: "Re-parse all dives" button

On `device_detail_page.dart`, alongside existing download buttons:

- **Visibility:** at least one `DiveDataSources` row exists with `computerId == this computer` AND `rawData IS NOT NULL`
- **Label:** "Re-parse all dives" with count subtitle, e.g., *"47 dives with raw data (23 without)"*
- **Confirmation dialog:** *"Re-run the dive parser on 47 dives that have stored raw data. This updates profile and sensor data but preserves your notes, sites, buddies, and other edits."*
- **Execution:** iterate qualifying rows, call `parseRawDiveData(vendor, product, model, rawData)` for each, feed to `applyParsedUpdate`
- **Progress:** *"Re-parsing dive 12 of 47..."*
- **Error handling:** log per-dive failures, continue, report at end: *"Re-parsed 45 of 47 dives. 2 failed (see details)."*

#### 3. Dive detail page: "Re-parse raw data" menu item

In the dive detail page's overflow menu:

- **Visibility:** dive has at least one `DiveDataSources` row with `rawData IS NOT NULL`
- **No confirmation needed:** single-dive re-parse is fast and reversible (re-parse again to undo)
- **Multi-source dives:** re-parses all sources with blobs; applies primary source's result to `Dives` row
- **Feedback:** snackbar: *"Dive re-parsed successfully"* or *"Re-parse failed: [reason]"*

### Migration

One Drift migration step, all additive:

1. `m.addColumn(diveDataSources, diveDataSources.rawData)`
2. `m.addColumn(diveDataSources, diveDataSources.rawFingerprint)`
3. `m.addColumn(diveDataSources, diveDataSources.descriptorVendor)`
4. `m.addColumn(diveDataSources, diveDataSources.descriptorProduct)`
5. `m.addColumn(diveDataSources, diveDataSources.descriptorModel)`
6. `m.addColumn(diveDataSources, diveDataSources.libdivecomputerVersion)`
7. `m.addColumn(diveDataSources, diveDataSources.lastParsedAt)`
8. Alter FK on `computerId` to add `onDelete: setNull`

No data transformation. All new columns are nullable. Existing rows remain valid with nulls.

### Testing Strategy

**Unit tests (repository/service layer):**

1. **Allowlist enforcement:** Import a dive with user-authored fields set. Run `applyParsedUpdate` with a different `ParsedDive`. Assert user fields unchanged, computer fields updated.
2. **Child table replacement:** Assert old profile rows deleted, new ones match fresh parse. Count rows before/after.
3. **Tank name preservation:** Re-parse a dive with named tanks. Assert names and presets survive; gas mix and pressures updated.
4. **Primary-only Dives update:** For a multi-source dive, re-parse the secondary source. Assert `DiveDataSources` snapshot updated but `Dives` canonical fields unchanged.
5. **Blob persistence round-trip:** Write a known `Uint8List`, read it back, assert byte-for-byte match.
6. **replaceSource idempotency:** Run replaceSource twice with same data. Assert DB identical after both.
7. **FK setNull:** Delete a `DiveComputers` row. Assert `DiveDataSources` rows survive with `computerId = null`. Assert re-parse from dive detail still works.
8. **Skip does nothing:** Import, detect duplicate, resolve as Skip. Assert no `DiveDataSources` changes.
9. **replaceSource conditional visibility:** Assert Replace choice hidden when no same-computer source row exists on matched dive.

**Integration tests:**

10. **Download captures bytes:** Mock DC download producing known raw bytes. Assert `DiveDataSources.rawData` matches mock bytes.
11. **Re-parse produces fresh values:** Store a blob, mock `parseRawDiveData` to return updated maxDepth. Run re-parse. Assert `Dives.maxDepth` updated.
12. **Dive-detail re-parse after computer deletion:** Download, delete computer, re-parse from dive detail. Assert success.
