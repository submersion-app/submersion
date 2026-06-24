# Dive Site Location Fields: City, Island & Body of Water

**Issue:** [#344](https://github.com/submersion-app/submersion/issues/344) — Add City/Island and Body of Water as fields for dive sites
**Date:** 2026-06-19
**Branch:** `worktree-dive-site-location-fields`

## Problem

Dive sites are located today with a `Country` + `Region` pair. That is too coarse
for archipelagos and large regions: several distinct sites can share the same
country and region (e.g. multiple islands off Cebu, Philippines) yet be far
apart and on different islands or near different towns. Divers cannot record or
tell those sites apart at a glance.

This adds three location attributes to a dive site:

- **City** (new)
- **Island** (new)
- **Body of Water** (e.g. "Visayan Sea") — already stored, but invisible

### Key finding: Body of Water is a "ghost column"

`dive_sites.body_of_water` already exists. It is written by the MacDive (XML +
SQLite) and UDDF importers and deliberately preserved on update, but
`SiteRepositoryImpl._toEntity()` never maps it into the `DiveSite` domain
entity. It has therefore been invisible in the app since the column was added.

Consequences for this work:

- **Body of Water** is primarily a *surfacing* task: add it to the entity, map
  it in the repository read path, and show it in the UI. Existing MacDive users
  will immediately see location data they already imported.
- **City and Island** are genuinely new end-to-end: no column, no importer
  source, no entity field.

## Goals

Bring all three fields to **full parity with `Region`**:

- Editable in the site edit form
- Shown on the site detail view (hidden when empty)
- Available as opt-in, sortable table/list columns
- Backed by country-filtered autocomplete suggestions
- Included in site full-text search
- Synced across devices
- Localized in all supported locales

## Non-goals (YAGNI)

- **Site de-dup matching** (`site_matcher`) stays unchanged, to keep matching
  behavior stable.
- **Filter sheet** gains no new filters.
- **Importer source mapping for City/Island.** MacDive/UDDF expose a body of
  water but no clean city/island source field; no new import parsing is added.
  (Body of Water import already exists and is untouched.)

## Design

### 1. Data model

| Field | DB column | Status |
| --- | --- | --- |
| City | `city` | new |
| Island | `island` | new |
| Body of Water | `body_of_water` | already exists (no schema change) |

**Schema migration** (`lib/core/database/database.dart`):

- Bump `currentSchemaVersion` 89 → 90.
- Add a `from < 90` block following the established v89 pattern: read
  `PRAGMA table_info('dive_sites')`, and for each of `city`, `island` that is
  absent, run `ALTER TABLE dive_sites ADD COLUMN <name> TEXT`. PRAGMA-guarded so
  a healthy DB no-ops and existing rows read as NULL. Call `reportProgress()`
  after the block, matching surrounding blocks.
- `body_of_water` already has its own migration — not touched.

**`DiveSite` entity** (`domain/entities/dive_site.dart`):

- Add three nullable fields: `final String? city;`, `final String? island;`,
  `final String? bodyOfWater;`.
- Thread them through the constructor, `copyWith`, and `props`.

### 2. Repository (`data/repositories/site_repository_impl.dart`)

- `_toEntity()`: add `city: row.city`, `island: row.island`,
  `bodyOfWater: row.bodyOfWater`. This is the line that makes existing
  imported `bodyOfWater` data visible.
- All write paths — create, update, and merge/import companions (around lines
  70, 123, 493, 709) — set `city`, `island`, `bodyOfWater` from the entity.
- Remove the now-obsolete "preserve on update" passthrough note for
  `bodyOfWater`; it is a first-class mapped field now.
- Search query (around line 609): add
  `| t.city.contains(query) | t.island.contains(query) | t.bodyOfWater.contains(query)`.

### 3. Compact location string (`locationString` getter)

```
locality = city (preferred) ?? island
base     = [region, country].where((s) => s != null && s.isNotEmpty).join(', ')

locality non-empty AND base non-empty -> "$locality · $base"   // "Malapascua · Cebu, Philippines"
locality non-empty, base empty        -> "$locality"
otherwise                             -> base                  // unchanged
```

- City is preferred over Island when both are set.
- Body of Water is **not** part of this one-liner (detail-only) to keep list
  tiles and map popups tight.
- List tiles, map callouts, and the detail header consume `locationString` and
  inherit this automatically.

### 4. Edit form (`presentation/pages/site_edit_page.dart`)

Three new `SuggestionField`s in the location `FormSection`, following the
existing Country/Region pattern:

- Add `_cityController`, `_islandController`, `_bodyOfWaterController`.
- Register `_onFieldChanged` listeners; dispose; populate in `_loadSite`.
- Wire suggestions (section 6) and reactive filtering off the country (and, for
  city, region) controllers, mirroring how Region rebuilds on country change.

Suggested field order in the location section: Country, Region, City, Island,
Body of Water.

### 5. Detail view (`presentation/pages/site_detail_page.dart`)

Add three rows to `_buildLocationSection`, each hidden-when-empty exactly like
the existing Country and Region rows, using the new localized labels.

### 6. Autocomplete (`domain/services/site_suggestions.dart`)

Three helpers mirroring `suggestedRegions(sites, country)` — distinct,
alpha-sorted, parent-filtered, falling back to all distinct values when the
parent is empty:

- `suggestedCities(sites, country, region)` — filtered by country **and** region
- `suggestedIslands(sites, country)` — filtered by country
- `suggestedBodiesOfWater(sites, country)` — filtered by country

### 7. Table columns (`domain/constants/site_field.dart`)

Add `city`, `island`, `bodyOfWater` enum values in the `core` category. Fully
implement every `SiteField` member for them:

- `displayName`: "City", "Island", "Body of Water"
- `shortLabel`: "City", "Island", "Water Body"
- `icon`: `Icons.location_city`, `Icons.landscape`, `Icons.waves`
- `defaultWidth` / `minWidth`: sized like Region (~100 / 60), Body of Water a
  little wider (~120)
- `sortable`: true
- `isRightAligned`: false
- `SiteFieldAdapter.extractValue`: return `site.city` / `site.island` /
  `site.bodyOfWater`
- `SiteFieldAdapter.formatValue`: string passthrough (`-- ` when null)

### 8. Localization

Add six keys and translate into **all** non-en locales (no English fallbacks),
then regenerate:

- `diveSites_edit_field_city_label`, `..._island_label`, `..._bodyOfWater_label`
- `diveSites_detail_location_city`, `..._island`, `..._bodyOfWater`

### 9. Sync

New columns serialize automatically through Drift's generic `toJson`/`fromJson`
sync path (the same mechanism that carried the prior-dive-experience columns).
The `currentSchemaVersion` bump is the only sync-relevant change. Verify there
is no explicit per-column allowlist in the sync serializer rather than assume.

## Testing (TDD)

Write tests first for each unit:

- **Entity** — `copyWith` and `props` cover `city`, `island`, `bodyOfWater`.
- **`locationString`** — city-preferred, island-fallback, base-only, both-empty,
  locality-without-base cases produce the expected strings.
- **Suggestions** — each new helper: parent filtering, fallback-to-all,
  de-duplication, alpha sort.
- **Repository round-trip** — write/read all three fields; plus an explicit
  regression test that a row with `body_of_water` set (as an importer writes)
  now reads back through `_toEntity` (proves the ghost-column fix).
- **`SiteField`** — `extractValue` and `formatValue` for the three fields,
  including null handling.

Target: maintain the project's 80% coverage minimum; run `flutter analyze` and
`dart format .` clean.

## Implementation order

1. Schema migration + codegen (`build_runner`).
2. Entity fields + `locationString`.
3. Repository read/write/search mapping.
4. Suggestions helpers.
5. `SiteField` columns.
6. Edit form + detail view.
7. Localization (template + all locales + regen).
8. Sync verification.
9. Tests throughout (TDD per unit).

## Files touched

- `lib/core/database/database.dart` (migration, schema version)
- `lib/features/dive_sites/domain/entities/dive_site.dart`
- `lib/features/dive_sites/data/repositories/site_repository_impl.dart`
- `lib/features/dive_sites/domain/services/site_suggestions.dart`
- `lib/features/dive_sites/domain/constants/site_field.dart`
- `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
- l10n ARB files (all locales) + generated localizations
- Corresponding test files under `test/`
