# Shearwater Swift GPS Entry/Exit Points

**Date:** 2026-05-22
**Status:** Approved (design) — pending implementation plan
**Topic:** Capture and display per-dive GPS entry/exit coordinates from Shearwater Swift GPS transmitters

## Summary

The Shearwater Swift GPS transmitter records a GPS fix at dive **entry** (start of descent) and **exit** (on surfacing). When paired with a Shearwater computer (Perdix/Petrel/Teric and family), both fixes are written into the dive's binary log. This feature reads those two points during direct dive-computer download, stores them per-dive, and surfaces them in the dive UI: as pins on the dive detail header map (always-on, seamless) and in a dedicated, opt-in "Surface GPS" collapsible section (entry/exit coordinates, drift distance and bearing, and an Open-in-Maps action).

## Background and data-source findings

Two import paths could in principle carry this data; only one is used.

- **Direct dive-computer download (libdivecomputer) — the chosen, sole source.** libdivecomputer added Swift GPS support upstream (commit `4f5abbd`, "Add support for the Shearwater Swift GPS"). Per the maintainer's commit message: *"the GPS location of the dive entry and exit points are stored in the opening and closing record number 9. At the moment only the entry location is reported because the api only supports a single location."*
  - **Entry** is exposed today via `DC_FIELD_LOCATION`, read from `opening[9]` (`shearwater_predator_parser.c`, the `DC_FIELD_LOCATION` case). Layout: signed big-endian int32 latitude at offset `+21`, longitude at `+25`, each divided by `100000.0` (so ~5 decimal places, ~1.1 m resolution). Invalid fixes `(0,0)` and `(-1,-1)` are rejected. Only valid when air-integration mode is `AI_ON_GPS`.
  - **Exit** is present in the data at `closing[9]` (the parser already records `closing[0..9]`) but is **not** exposed, because libdivecomputer's public `dc_field_type_t` has a single `DC_FIELD_LOCATION` value (`include/libdivecomputer/parser.h`).
  - The plugin's Pigeon `ParsedDive` does not carry GPS at all today, so even entry is currently dropped.

- **Shearwater Cloud `.db` import — explicitly dropped.** The existing universal-import reader parses `GnssEntryLocation`/`GnssExitLocation` from the `dive_details` table, but the product owner confirms Shearwater Cloud (the legacy desktop application) does not actually surface/store this data in practice. We will **not** build GPS into the Cloud import path. The dive computer's binary log is the source of truth; an app export is at best a lossy round-trip. The existing Cloud import behavior is left unchanged.

## Decisions

| Question | Decision |
|---|---|
| GPS source | Direct download only (libdivecomputer). Cloud/.db path not used for GPS. |
| Which points | Both entry and exit. |
| Relationship to dive sites | Entry/exit are **per-dive** data, independent of dive sites. Do **not** auto-create or auto-update sites from GPS. |
| Exit extraction | **Patch the vendored libdivecomputer** so `DC_FIELD_LOCATION` honors its `flags` argument (0 = entry/`opening[9]`, 1 = exit/`closing[9]`). |
| UI | (A) Enhance the existing header map with entry/exit pins + drift line; (B) add an opt-in collapsible "Surface GPS" section. |
| Editability | Read-only, device-sourced in v1 (with source attribution). |
| Units | Coordinates in decimal degrees (~5 dp). Drift distance respects the diver's unit setting (m/ft). Bearing in degrees + cardinal, e.g. `042° NE`. |

## Architecture and data flow

A single new value (an optional pair of GPS points) threaded additively through existing layers:

```
Swift transmitter + computer
  binary log: opening[9] = entry fix, closing[9] = exit fix
    │  (direct download, BLE/USB)
    ▼
libdivecomputer  ── PATCH: DC_FIELD_LOCATION honors flags (0=entry, 1=exit)
    ▼
shared C wrapper (libdc_parsed_dive_t)   [+ entry/exit lat,long as double, NAN = absent]
    ▼
per-platform converter (darwin / android / linux / windows)
    ▼
Pigeon ParsedDive                        [+ entryLatitude/Longitude, exitLatitude/Longitude : double?]
    ▼
parsedDiveToDownloaded → DownloadedDive  [+ entry/exit GeoPoint?]
    ▼
dive import service / repository
    ▼
Drift Dives row                          [+ entryLatitude/Longitude, exitLatitude/Longitude : real nullable]
    ▼
Dive domain entity                       [+ GeoPoint? entryLocation, exitLocation]
    ▼
UI: header map (pins + drift polyline)  •  "Surface GPS" collapsible section
```

The plugin's seam keeps the GPS *logic* in one place (the shared wrapper) and reduces the per-platform work to mechanical struct-to-Pigeon copying in four converters.

## Detailed design

### 1. libdivecomputer patch (exit extraction)

Modify the `DC_FIELD_LOCATION` case in `packages/libdivecomputer_plugin/third_party/libdivecomputer/src/shearwater_predator_parser.c` to select the record by the existing `flags` parameter (already used to index gas mixes/tanks), defaulting to entry:

```c
case DC_FIELD_LOCATION: {
    unsigned int rec = (flags == 1) ? parser->closing[9] : parser->opening[9];
    if (rec == UNDEFINED || parser->aimode != AI_ON_GPS)
        return DC_STATUS_UNSUPPORTED;
    latitude  = (signed int) array_uint32_be (data + rec + 21);
    longitude = (signed int) array_uint32_be (data + rec + 25);
    if ((latitude == 0 && longitude == 0) ||
        (latitude == -1 && longitude == -1))
        return DC_STATUS_UNSUPPORTED;
    location->latitude  = latitude  / 100000.0;
    location->longitude = longitude / 100000.0;
    location->altitude  = 0.0;
    break;
}
```

- The patch is tracked as a documented `.patch` applied to the submodule during setup/build (or via a thin fork), and is a candidate for upstream contribution (after which the local patch can be dropped).
- **Correctness caveat to verify during implementation:** the `closing[9]` field offsets (`+21`/`+25`) are assumed symmetric with `opening[9]` based on the maintainer's "opening and closing record number 9" note. Confirm against a real Swift dive's raw bytes (the captured fix should match the computer's reported entry/exit) before relying on it. The `(0,0)`/`(-1,-1)` rejection makes a wrong offset fail safe (no pin) rather than render a bogus location, but ground-truth verification is required.

### 2. Shared wrapper struct and population

In the shared wrapper (`libdc_parsed_dive_t`, declared in `packages/libdivecomputer_plugin/macos/Classes/libdc_wrapper.h`, populated by the shared wrapper implementation), add four `double` fields following the struct's existing `NAN = unavailable` convention:

```c
double entry_latitude;   // decimal degrees, NAN if unavailable
double entry_longitude;
double exit_latitude;
double exit_longitude;
```

Where the dive is parsed, call the field getter twice and store results (leaving NAN on `DC_STATUS_UNSUPPORTED`):

```c
dc_location_t loc;
if (dc_parser_get_field(parser, DC_FIELD_LOCATION, 0, &loc) == DC_STATUS_SUCCESS) {
    out->entry_latitude = loc.latitude; out->entry_longitude = loc.longitude;
}
if (dc_parser_get_field(parser, DC_FIELD_LOCATION, 1, &loc) == DC_STATUS_SUCCESS) {
    out->exit_latitude = loc.latitude; out->exit_longitude = loc.longitude;
}
```

### 3. Per-platform converters and Pigeon

- Add nullable fields to the Pigeon `ParsedDive` class in `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`: `double? entryLatitude, entryLongitude, exitLatitude, exitLongitude`. Regenerate Pigeon output.
- Update each converter to map struct `double` (NAN → null) into the Pigeon fields:
  - `windows/dive_converter.cc` (`ConvertParsedDive`)
  - `android/src/main/cpp/libdc_jni.cpp`
  - `darwin/Sources/...` (Swift/ObjC bridge)
  - `linux/...`
- Extend the native test `packages/libdivecomputer_plugin/test/native/test_dive_converter.c` to assert entry/exit values (and NAN→absent) convert correctly.

### 4. Dart domain, mapping, persistence

- **`GeoPoint` relocation:** move the existing `GeoPoint` value object (currently in `lib/features/dive_sites/domain/entities/dive_site.dart`, lines ~171-183) to a shared location (e.g. `lib/core/domain/value_objects/geo_point.dart`) so both `dive_sites` and `dive_log` can use it without a cross-feature domain dependency. Update imports. No behavior change.
- **`DownloadedDive`** (`lib/features/dive_computer/domain/entities/downloaded_dive.dart`): add `GeoPoint? entryLocation`, `GeoPoint? exitLocation`.
- **`parsedDiveToDownloaded`** (`lib/features/dive_computer/data/services/parsed_dive_mapper.dart`): build `GeoPoint?` from the Pigeon nullable doubles; treat null/`(0,0)`/`(-1,-1)` as absent.
- **Drift schema** (`lib/core/database/database.dart`, `Dives` table): add `entryLatitude`, `entryLongitude`, `exitLatitude`, `exitLongitude` as `real().nullable()`. Bump `schemaVersion` and add an `addColumn` migration step for each new column. (Confirm the current `schemaVersion` when writing the plan.)
- **Import/repository** (`lib/features/dive_computer/data/services/dive_import_service.dart` and the repository it calls): persist the new columns when importing a downloaded dive.
- **`Dive` entity** (`lib/features/dive_log/domain/entities/dive.dart`): add `GeoPoint? entryLocation`, `GeoPoint? exitLocation` with `copyWith` support; hydrate from the Drift row.

### 5. Geo utility (drift)

A pure-Dart utility (e.g. `lib/core/utils/geo_math.dart`), independently unit-tested:

- `double distanceMeters(GeoPoint a, GeoPoint b)` — Haversine.
- `double initialBearingDegrees(GeoPoint a, GeoPoint b)` — 0–360.
- `String formatBearing(double deg)` — degrees + 8-point cardinal, e.g. `042° NE`.
- Distance is converted to the diver's unit (m/ft) at the display layer via existing unit settings, never hard-coded.

### 6. UI

**A. Header map enhancement** (`lib/features/dive_log/presentation/pages/dive_detail_page.dart`, `_buildHeaderSection` / its map overlay, around line 739):
- Broaden the "show map" condition from `dive.site?.location != null` to also include `dive.entryLocation != null || dive.exitLocation != null`.
- Render an entry marker (green) and exit marker (orange), and a dashed `PolylineLayer` between them when both exist. Fit the map bounds to the available points.
- Fallback: when there is no entry/exit GPS, retain today's site-pin behavior.

**B. "Surface GPS" collapsible section:**
- Add a value to `DiveDetailSectionId` (`lib/core/constants/dive_detail_sections.dart`), register it in `_sectionBuilders` and the section defaults, so users can reorder/hide it like other sections.
- Build with `CollapsibleCardSection` (`lib/features/dive_log/presentation/widgets/collapsible_section.dart`).
  - **Collapsed:** one summary line, e.g. `Entry & exit · 120 m drift` (or partial text when only one point exists).
  - **Expanded:** the map (same markers/line), entry and exit coordinates (decimal degrees), drift distance + bearing, and an **Open in Maps** button (via `url_launcher` — confirm it is already a dependency; add if not).
- Apply the existing source-attribution badge to the GPS values, consistent with other imported fields.
- The section auto-hides when the dive has neither point (matching how other empty sections behave).

## Edge cases

- **Entry only / exit only:** render the available point; omit the drift line and drift readout (which require both).
- **Neither point:** header falls back to site/no-map; Surface GPS section is hidden.
- **Invalid coordinates:** rejected at the parser and again defensively in the Dart mapper (`(0,0)`, `(-1,-1)`, nulls) so no spurious pin renders.
- **Non-Swift / non-GPS dives:** Pigeon GPS fields are null; nothing changes for these dives.
- **Re-import / re-parse:** because the value is derived purely from the binary, re-parsing a stored raw dive repopulates the same points.

## Testing strategy (TDD)

- **Native (C):** extend `test_dive_converter.c` to assert entry and exit extraction (flags 0/1) and NAN→absent mapping into `ParsedDive`.
- **Dart unit:** geo utility against known coordinate pairs (distance and bearing); `parsedDiveToDownloaded` propagation for full / entry-only / exit-only / missing / invalid inputs; the Drift migration (open at prior schema version, migrate, assert columns).
- **Widget:** header map shows entry/exit markers and drift line when present and falls back without GPS; Surface GPS section collapsed/expanded states, partial-data rendering, and drift-distance unit conversion (m vs ft).

## Out of scope (YAGNI)

- GPS via Shearwater Cloud / `.db` import (dropped).
- Auto-matching or auto-creating dive sites from entry/exit GPS.
- Manual entry/editing of GPS points (read-only in v1).
- Per-sample GPS track (only entry/exit fixes exist).
- Degrees-minutes-seconds coordinate display toggle (decimal degrees only in v1).

## Implementation notes to confirm during planning

These are file/value confirmations, not open design questions:

- Exact path/name of the shared wrapper implementation file that populates `libdc_parsed_dive_t`.
- Current Drift `schemaVersion` in `lib/core/database/database.dart`.
- Whether `url_launcher` is already a dependency.
- The four converter files' exact GPS-mapping insertion points.
- Ground-truth verification of the `closing[9]` byte offsets against a real Swift dive.
